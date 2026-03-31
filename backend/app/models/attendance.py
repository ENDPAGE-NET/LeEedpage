import uuid
from datetime import datetime, timezone

from sqlalchemy import String, DateTime, Date, ForeignKey, Boolean, Float, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class AttendanceRecord(Base):
    __tablename__ = "attendance_records"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    record_date: Mapped[str] = mapped_column(String(10), nullable=False)  # "2026-03-27"
    record_type: Mapped[str] = mapped_column(String(10), nullable=False)  # "checkin" | "checkout"

    # 验证结果
    face_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    face_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    location_verified: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    distance_m: Mapped[float | None] = mapped_column(Float, nullable=True)

    # 时间状态
    is_late: Mapped[bool] = mapped_column(Boolean, default=False)
    is_early_leave: Mapped[bool] = mapped_column(Boolean, default=False)

    # 审计
    device_info: Mapped[str | None] = mapped_column(String(255), nullable=True)
    photo_path: Mapped[str | None] = mapped_column(String(500), nullable=True)

    recorded_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), server_default=func.now()
    )

    user = relationship("User", back_populates="attendance_records")
