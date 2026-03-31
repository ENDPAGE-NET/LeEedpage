from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.router import api_router
from app.config import settings
from app.core.database import Base, SessionLocal, engine
from app.core.security import hash_password
from app.models.attendance import AttendanceRecord
from app.models.audit_log import AuditLog
from app.models.checkin_rule import CheckinRule
from app.models.face_data import FaceData
from app.models.leave import LeaveBalance, LeaveRequest
from app.models.user import User
from app.services.schema_compat import ensure_runtime_schema_compat

app = FastAPI(
    title="焰页云枢打卡系统",
    description="ENDPAGE 企业考勤管理系统 API",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")
app.include_router(api_router)


@app.on_event("startup")
def on_startup():
    Base.metadata.create_all(bind=engine)
    ensure_runtime_schema_compat(engine)

    db = SessionLocal()
    try:
        admin = db.query(User).filter(User.username == "admin").first()
        if not admin:
            admin = User(
                username="admin",
                hashed_password=hash_password("admin123"),
                full_name="系统管理员",
                role="admin",
                status="active",
                must_change_password=False,
            )
            db.add(admin)
            db.commit()
            print("默认管理员已创建: admin / admin123")
    finally:
        db.close()


@app.get("/")
def root():
    return {"message": "焰页云枢打卡系统 API", "version": "1.0.0"}


@app.get("/health")
def health():
    return {"status": "ok"}
