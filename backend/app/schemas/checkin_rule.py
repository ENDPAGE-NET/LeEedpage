from pydantic import BaseModel, Field


class CheckinRuleCreate(BaseModel):
    location_required: bool = False
    location_name: str | None = None
    location_address: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    allowed_radius_m: int = 200

    time_required: bool = False
    checkin_start: str | None = None
    checkin_end: str | None = None
    checkout_start: str | None = None
    checkout_end: str | None = None

    work_days: list[int] = Field(default_factory=lambda: [1, 2, 3, 4, 5])


class CheckinRuleBatchFilters(BaseModel):
    search: str = ""
    status: str = ""


class CheckinRuleBatchApplyRequest(BaseModel):
    filters: CheckinRuleBatchFilters = Field(default_factory=CheckinRuleBatchFilters)
    rule: CheckinRuleCreate


class CheckinRuleBatchPreviewResponse(BaseModel):
    matched_count: int
    configured_count: int
    distinct_rule_count: int
    preview_source: str
    preview_user_name: str | None = None
    rule: CheckinRuleCreate | None = None


class CheckinRuleBatchApplyResponse(BaseModel):
    matched_count: int
    updated_count: int
    unchanged_count: int


class CheckinRuleResponse(BaseModel):
    id: str
    user_id: str
    location_required: bool
    location_name: str | None
    location_address: str | None
    latitude: float | None
    longitude: float | None
    allowed_radius_m: int
    time_required: bool
    checkin_start: str | None
    checkin_end: str | None
    checkout_start: str | None
    checkout_end: str | None
    work_days: list[int]

    class Config:
        from_attributes = True
