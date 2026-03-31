from datetime import datetime
from pydantic import BaseModel


class LeaveRequestCreate(BaseModel):
    leave_type: str  # personal/sick/annual/comp/other
    start_date: str  # "2026-03-28"
    end_date: str
    days: float
    reason: str


class LeaveApproveRequest(BaseModel):
    action: str  # "approve" or "reject"
    remark: str = ""


class LeaveRequestResponse(BaseModel):
    id: str
    user_id: str
    user_name: str | None = None
    leave_type: str
    leave_type_label: str = ""
    start_date: str
    end_date: str
    days: float
    reason: str
    status: str
    status_label: str = ""
    approver_name: str | None
    approve_remark: str | None
    approved_at: datetime | None
    created_at: datetime

    class Config:
        from_attributes = True


class LeaveListResponse(BaseModel):
    total: int
    items: list[LeaveRequestResponse]


class LeaveBalanceResponse(BaseModel):
    leave_type: str
    leave_type_label: str
    total_days: float
    used_days: float
    remaining_days: float
