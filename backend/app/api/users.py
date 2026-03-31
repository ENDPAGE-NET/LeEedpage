from pathlib import Path

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.config import settings
from app.core.database import get_db
from app.core.exceptions import BadRequestException, NotFoundException
from app.core.security import hash_password
from app.dependencies import get_admin_user, get_current_user
from app.models.face_data import FaceData
from app.models.user import User
from app.schemas.user import UserCreate, UserListResponse, UserResponse, UserUpdate
from app.services.audit_service import log_action

router = APIRouter(prefix="/users", tags=["用户管理"])


def _to_upload_url(image_path: str | None) -> str | None:
    if not image_path:
        return None

    uploads_dir = Path(settings.UPLOAD_DIR).resolve()
    candidate = Path(image_path).resolve()
    try:
        relative_path = candidate.relative_to(uploads_dir)
    except ValueError:
        normalized = image_path.replace("\\", "/")
        marker = "/uploads/"
        if marker in normalized:
            return normalized[normalized.index(marker):]
        return None
    return f"/uploads/{relative_path.as_posix()}"


def _get_active_face(user: User) -> FaceData | None:
    for face in user.face_data:
        if face.is_active:
            return face
    return None


def _user_to_response(user: User) -> UserResponse:
    active_face = _get_active_face(user)
    image_url = _to_upload_url(active_face.image_path if active_face else None)
    return UserResponse(
        id=user.id,
        username=user.username,
        full_name=user.full_name,
        phone=user.phone,
        email=user.email,
        role=user.role,
        status=user.status,
        must_change_password=user.must_change_password,
        has_face=active_face is not None,
        avatar_url=image_url,
        face_image_url=image_url,
        created_at=user.created_at,
        updated_at=user.updated_at,
    )


@router.get("", response_model=UserListResponse)
def list_users(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    search: str = Query("", description="搜索用户名或姓名"),
    status: str = Query("", description="按状态筛选"),
    role: str = Query("", description="按角色筛选"),
    admin: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    query = db.query(User)
    if search:
        query = query.filter((User.username.contains(search)) | (User.full_name.contains(search)))
    if status:
        query = query.filter(User.status == status)
    if role:
        query = query.filter(User.role == role)

    total = query.count()
    users = (
        query.order_by(User.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )

    return UserListResponse(total=total, items=[_user_to_response(u) for u in users])


@router.post("", response_model=UserResponse, status_code=201)
def create_user(
    req: UserCreate,
    admin: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    existing = db.query(User).filter(User.username == req.username).first()
    if existing:
        raise BadRequestException("用户名已存在")

    if req.role not in ("admin", "employee"):
        raise BadRequestException("角色必须是 admin 或 employee")

    user = User(
        username=req.username,
        hashed_password=hash_password(req.password),
        full_name=req.full_name,
        phone=req.phone,
        email=req.email,
        role=req.role,
        status="pending",
        must_change_password=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    log_action(
        db,
        "user.create",
        actor_id=admin.id,
        actor_name=admin.full_name,
        target_type="user",
        target_id=user.id,
        details={"username": user.username, "role": user.role},
    )

    return _user_to_response(user)


@router.get("/me", response_model=UserResponse)
def get_current_user_info(current_user: User = Depends(get_current_user)):
    return _user_to_response(current_user)


@router.get("/{user_id}", response_model=UserResponse)
def get_user(
    user_id: str,
    admin: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise NotFoundException("用户不存在")
    return _user_to_response(user)


@router.put("/{user_id}", response_model=UserResponse)
def update_user(
    user_id: str,
    req: UserUpdate,
    admin: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise NotFoundException("用户不存在")

    if req.full_name is not None:
        user.full_name = req.full_name
    if req.phone is not None:
        user.phone = req.phone
    if req.email is not None:
        user.email = req.email
    if req.role is not None:
        if req.role not in ("admin", "employee"):
            raise BadRequestException("角色必须是 admin 或 employee")
        user.role = req.role
    if req.status is not None:
        if req.status not in ("pending", "active", "disabled"):
            raise BadRequestException("状态无效")
        user.status = req.status

    db.commit()
    db.refresh(user)

    return _user_to_response(user)


@router.delete("/{user_id}")
def delete_user(
    user_id: str,
    admin: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise NotFoundException("用户不存在")
    if user.id == admin.id:
        raise BadRequestException("不能禁用自己")

    user.status = "disabled"
    db.commit()

    log_action(
        db,
        "user.disable",
        actor_id=admin.id,
        actor_name=admin.full_name,
        target_type="user",
        target_id=user.id,
        details={"username": user.username},
    )

    return {"message": "用户已禁用"}


@router.post("/{user_id}/reset-password")
def reset_password(
    user_id: str,
    admin: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise NotFoundException("用户不存在")

    temp_password = user.username + "123"
    user.hashed_password = hash_password(temp_password)
    user.must_change_password = True
    db.commit()

    log_action(
        db,
        "password.reset",
        actor_id=admin.id,
        actor_name=admin.full_name,
        target_type="user",
        target_id=user.id,
        details={"username": user.username},
    )

    return {"message": "密码已重置", "temp_password": temp_password}


@router.delete("/{user_id}/face")
def reset_face(
    user_id: str,
    admin: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise NotFoundException("用户不存在")

    db.query(FaceData).filter(FaceData.user_id == user_id, FaceData.is_active == True).update(
        {"is_active": False}
    )
    user.status = "pending"
    db.commit()

    log_action(
        db,
        "face.reset",
        actor_id=admin.id,
        actor_name=admin.full_name,
        target_type="user",
        target_id=user.id,
        details={"username": user.username},
    )

    return {"message": "人脸数据已重置，用户需要重新注册人脸"}
