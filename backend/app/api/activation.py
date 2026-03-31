from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.exceptions import BadRequestException
from app.dependencies import get_current_user
from app.models.user import User
from app.models.face_data import FaceData

router = APIRouter(prefix="/activation", tags=["首次激活"])


@router.post("/complete")
def complete_activation(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.status == "active":
        raise BadRequestException("账户已激活")

    # 检查是否已修改密码
    if current_user.must_change_password:
        raise BadRequestException("请先修改密码")

    # 检查是否已注册人脸
    has_face = db.query(FaceData).filter(
        FaceData.user_id == current_user.id,
        FaceData.is_active == True,
    ).first()
    if not has_face:
        raise BadRequestException("请先注册人脸")

    current_user.status = "active"
    db.commit()

    return {"message": "账户激活成功"}
