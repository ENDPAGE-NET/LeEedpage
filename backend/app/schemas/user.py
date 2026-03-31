from datetime import datetime

from pydantic import BaseModel


class UserCreate(BaseModel):
    username: str
    password: str
    full_name: str
    phone: str | None = None
    email: str | None = None
    role: str = "employee"


class UserUpdate(BaseModel):
    full_name: str | None = None
    phone: str | None = None
    email: str | None = None
    role: str | None = None
    status: str | None = None


class UserResponse(BaseModel):
    id: str
    username: str
    full_name: str
    phone: str | None
    email: str | None
    role: str
    status: str
    must_change_password: bool
    has_face: bool = False
    avatar_url: str | None = None
    face_image_url: str | None = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class UserListResponse(BaseModel):
    total: int
    items: list[UserResponse]
