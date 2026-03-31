from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.exceptions import BadRequestException, NotFoundException, ForbiddenException
from app.dependencies import get_admin_user, get_current_user
from app.models.user import User
from app.models.leave import LeaveRequest, LeaveBalance, LeaveType
from app.schemas.leave import (
    LeaveRequestCreate, LeaveApproveRequest,
    LeaveRequestResponse, LeaveListResponse, LeaveBalanceResponse,
)
from app.services.audit_service import log_action

router = APIRouter(prefix="/leave", tags=["请假管理"])

STATUS_LABELS = {
    "pending": "待审批",
    "approved": "已批准",
    "rejected": "已拒绝",
    "cancelled": "已取消",
}


def _to_response(req: LeaveRequest, user_name: str | None = None) -> LeaveRequestResponse:
    return LeaveRequestResponse(
        id=req.id,
        user_id=req.user_id,
        user_name=user_name,
        leave_type=req.leave_type,
        leave_type_label=LeaveType.LABELS.get(req.leave_type, req.leave_type),
        start_date=req.start_date,
        end_date=req.end_date,
        days=req.days,
        reason=req.reason,
        status=req.status,
        status_label=STATUS_LABELS.get(req.status, req.status),
        approver_name=req.approver_name,
        approve_remark=req.approve_remark,
        approved_at=req.approved_at,
        created_at=req.created_at,
    )


# ============================================================
# 员工：提交请假申请
# ============================================================
@router.post("/request", response_model=LeaveRequestResponse, status_code=201)
def create_leave_request(
    req: LeaveRequestCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if req.leave_type not in LeaveType.ALL:
        raise BadRequestException(f"无效的请假类型，可选: {', '.join(LeaveType.ALL)}")
    if req.days <= 0:
        raise BadRequestException("请假天数必须大于0")
    if req.start_date > req.end_date:
        raise BadRequestException("开始日期不能晚于结束日期")
    if not req.reason.strip():
        raise BadRequestException("请填写请假原因")

    # 检查余额（年假和调休需要检查）
    if req.leave_type in ("annual", "comp"):
        year = int(req.start_date[:4])
        balance = db.query(LeaveBalance).filter(
            LeaveBalance.user_id == current_user.id,
            LeaveBalance.year == year,
            LeaveBalance.leave_type == req.leave_type,
        ).first()
        if balance:
            remaining = balance.total_days - balance.used_days
            if req.days > remaining:
                type_label = LeaveType.LABELS.get(req.leave_type, "")
                raise BadRequestException(f"{type_label}余额不足（剩余 {remaining} 天，申请 {req.days} 天）")

    # 检查日期是否有重叠的请假
    overlap = db.query(LeaveRequest).filter(
        LeaveRequest.user_id == current_user.id,
        LeaveRequest.status.in_(["pending", "approved"]),
        LeaveRequest.start_date <= req.end_date,
        LeaveRequest.end_date >= req.start_date,
    ).first()
    if overlap:
        raise BadRequestException(f"该日期范围与已有请假记录冲突（{overlap.start_date} ~ {overlap.end_date}）")

    leave = LeaveRequest(
        user_id=current_user.id,
        leave_type=req.leave_type,
        start_date=req.start_date,
        end_date=req.end_date,
        days=req.days,
        reason=req.reason.strip(),
        status="pending",
    )
    db.add(leave)
    db.commit()
    db.refresh(leave)

    return _to_response(leave, current_user.full_name)


# ============================================================
# 员工：查看自己的请假记录
# ============================================================
@router.get("/my", response_model=LeaveListResponse)
def my_leave_requests(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status: str = Query("", description="按状态筛选"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(LeaveRequest).filter(LeaveRequest.user_id == current_user.id)
    if status:
        query = query.filter(LeaveRequest.status == status)

    total = query.count()
    items = query.order_by(LeaveRequest.created_at.desc()).offset((page - 1) * page_size).limit(page_size).all()

    return LeaveListResponse(
        total=total,
        items=[_to_response(r, current_user.full_name) for r in items],
    )


# ============================================================
# 员工：取消请假（仅 pending 状态可取消）
# ============================================================
@router.post("/{leave_id}/cancel")
def cancel_leave_request(
    leave_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    leave = db.query(LeaveRequest).filter(LeaveRequest.id == leave_id).first()
    if not leave:
        raise NotFoundException("请假记录不存在")
    if leave.user_id != current_user.id:
        raise ForbiddenException("只能取消自己的请假申请")
    if leave.status != "pending":
        raise BadRequestException("只能取消待审批的请假申请")

    leave.status = "cancelled"
    db.commit()

    return {"message": "请假申请已取消"}


# ============================================================
# 员工：查看自己的请假余额
# ============================================================
@router.get("/balance", response_model=list[LeaveBalanceResponse])
def my_leave_balance(
    year: int = Query(0, description="年份，默认当前年"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if year <= 0:
        year = datetime.now().year

    balances = db.query(LeaveBalance).filter(
        LeaveBalance.user_id == current_user.id,
        LeaveBalance.year == year,
    ).all()

    # 如果没有余额记录，返回默认值
    result = []
    for lt in LeaveType.ALL:
        bal = next((b for b in balances if b.leave_type == lt), None)
        total = bal.total_days if bal else (0 if lt in ("personal", "sick", "other") else 0)
        used = bal.used_days if bal else 0
        result.append(LeaveBalanceResponse(
            leave_type=lt,
            leave_type_label=LeaveType.LABELS.get(lt, lt),
            total_days=total,
            used_days=used,
            remaining_days=total - used,
        ))

    return result


# ============================================================
# 管理员：查看所有请假申请
# ============================================================
@router.get("/requests", response_model=LeaveListResponse)
def list_leave_requests(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status: str = Query("", description="按状态筛选"),
    user_id: str = Query("", description="按用户筛选"),
    admin: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    query = db.query(LeaveRequest, User.full_name).join(User, LeaveRequest.user_id == User.id)
    if status:
        query = query.filter(LeaveRequest.status == status)
    if user_id:
        query = query.filter(LeaveRequest.user_id == user_id)

    total = query.count()
    results = query.order_by(LeaveRequest.created_at.desc()).offset((page - 1) * page_size).limit(page_size).all()

    return LeaveListResponse(
        total=total,
        items=[_to_response(r, name) for r, name in results],
    )


# ============================================================
# 管理员：审批请假
# ============================================================
@router.post("/{leave_id}/approve")
def approve_leave_request(
    leave_id: str,
    req: LeaveApproveRequest,
    admin: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    leave = db.query(LeaveRequest).filter(LeaveRequest.id == leave_id).first()
    if not leave:
        raise NotFoundException("请假记录不存在")
    if leave.status != "pending":
        raise BadRequestException("该请假申请已处理，无法再次审批")

    if req.action not in ("approve", "reject"):
        raise BadRequestException("操作必须是 approve 或 reject")

    if req.action == "approve":
        leave.status = "approved"
        # 扣除余额
        if leave.leave_type in ("annual", "comp"):
            year = int(leave.start_date[:4])
            balance = db.query(LeaveBalance).filter(
                LeaveBalance.user_id == leave.user_id,
                LeaveBalance.year == year,
                LeaveBalance.leave_type == leave.leave_type,
            ).first()
            if balance:
                balance.used_days += leave.days
    else:
        leave.status = "rejected"

    leave.approver_id = admin.id
    leave.approver_name = admin.full_name
    leave.approve_remark = req.remark
    leave.approved_at = datetime.now(timezone.utc)
    db.commit()

    action_label = "批准" if req.action == "approve" else "拒绝"
    log_action(db, f"leave.{req.action}", actor_id=admin.id, actor_name=admin.full_name,
               target_type="leave", target_id=leave.id,
               details={"user_id": leave.user_id, "days": leave.days})

    return {"message": f"请假申请已{action_label}"}


# ============================================================
# 管理员：设置用户请假余额
# ============================================================
@router.put("/balance/{user_id}")
def set_leave_balance(
    user_id: str,
    year: int = Query(..., description="年份"),
    leave_type: str = Query(..., description="假期类型"),
    total_days: float = Query(..., description="总天数"),
    admin: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise NotFoundException("用户不存在")
    if leave_type not in LeaveType.ALL:
        raise BadRequestException("无效的假期类型")

    balance = db.query(LeaveBalance).filter(
        LeaveBalance.user_id == user_id,
        LeaveBalance.year == year,
        LeaveBalance.leave_type == leave_type,
    ).first()

    if balance:
        balance.total_days = total_days
    else:
        balance = LeaveBalance(
            user_id=user_id,
            year=year,
            leave_type=leave_type,
            total_days=total_days,
            used_days=0,
        )
        db.add(balance)

    db.commit()

    return {"message": f"已设置 {LeaveType.LABELS.get(leave_type, leave_type)} 余额为 {total_days} 天"}
