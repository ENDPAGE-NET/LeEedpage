from datetime import datetime
from pydantic import BaseModel


class AttendanceResponse(BaseModel):
    id: str
    user_id: str
    user_name: str | None = None
    record_date: str
    record_type: str
    face_verified: bool
    face_score: float | None
    location_verified: bool | None
    latitude: float | None
    longitude: float | None
    distance_m: float | None
    is_late: bool
    is_early_leave: bool
    device_info: str | None
    recorded_at: datetime

    class Config:
        from_attributes = True


class AttendanceListResponse(BaseModel):
    total: int
    items: list[AttendanceResponse]


class AttendanceStatistics(BaseModel):
    total_records: int
    total_checkins: int
    total_checkouts: int
    late_count: int
    early_leave_count: int
    date_range_start: str
    date_range_end: str
