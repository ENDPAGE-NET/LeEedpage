from fastapi import APIRouter

from app.api.auth import router as auth_router
from app.api.users import router as users_router
from app.api.rules import router as rules_router
from app.api.attendance import router as attendance_router
from app.api.activation import router as activation_router
from app.api.face import router as face_router
from app.api.audit import router as audit_router
from app.api.leave import router as leave_router

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(auth_router)
api_router.include_router(users_router)
api_router.include_router(rules_router)
api_router.include_router(attendance_router)
api_router.include_router(activation_router)
api_router.include_router(face_router)
api_router.include_router(audit_router)
api_router.include_router(leave_router)
