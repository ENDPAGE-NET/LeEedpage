import uuid
from datetime import datetime, timezone

from sqlalchemy import String, DateTime, Float, Integer, Text, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class LeaveType:
    PERSONAL = "personal"   # 事假
    SICK = "sick"           # 病假
    ANNUAL = "annual"       # 年假
    COMP = "comp"           # 调休
    OTHER = "other"         # 其他

    ALL = [PERSONAL, SICK, ANNUAL, COMP, OTHER]
    LABELS = {
        PERSONAL: "事假",
        SICK: "病假",
        ANNUAL: "年假",
        COMP: "调休",
        OTHER: "其他",
    }


class LeaveRequest(Base):
    __tablename__ = "leave_requests"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    leave_type: Mapped[str] = mapped_column(String(20), nullable=False)  # personal/sick/annual/comp/other
    start_date: Mapped[str] = mapped_column(String(10), nullable=False)  # "2026-03-28"
    end_date: Mapped[str] = mapped_column(String(10), nullable=False)
    days: Mapped[float] = mapped_column(Float, nullable=False)  # 天数（支持0.5天）
    reason: Mapped[str] = mapped_column(Text, nullable=False)

    # 审批状态
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="pending")
    # pending=待审批, approved=已批准, rejected=已拒绝, cancelled=已取消
    approver_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    approver_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    approve_remark: Mapped[str | None] = mapped_column(Text, nullable=True)
    approved_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc), server_default=func.now()
    )

    user = relationship("User", backref="leave_requests")


class LeaveBalance(Base):
    __tablename__ = "leave_balances"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    year: Mapped[int] = mapped_column(Integer, nullable=False)  # 年份
    leave_type: Mapped[str] = mapped_column(String(20), nullable=False)
    total_days: Mapped[float] = mapped_column(Float, nullable=False, default=0)
    used_days: Mapped[float] = mapped_column(Float, nullable=False, default=0)

    user = relationship("User", backref="leave_balances")
