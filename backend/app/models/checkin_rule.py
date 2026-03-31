import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class CheckinRule(Base):
    __tablename__ = "checkin_rules"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True
    )

    location_required: Mapped[bool] = mapped_column(Boolean, default=False)
    location_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    location_address: Mapped[str | None] = mapped_column(String(500), nullable=True)
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    allowed_radius_m: Mapped[int] = mapped_column(Integer, default=200)

    time_required: Mapped[bool] = mapped_column(Boolean, default=False)
    checkin_start: Mapped[str | None] = mapped_column(String(5), nullable=True)
    checkin_end: Mapped[str | None] = mapped_column(String(5), nullable=True)
    checkout_start: Mapped[str | None] = mapped_column(String(5), nullable=True)
    checkout_end: Mapped[str | None] = mapped_column(String(5), nullable=True)

    work_days: Mapped[str] = mapped_column(String(50), default="[1,2,3,4,5]")

    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
    )

    user = relationship("User", back_populates="checkin_rule")
