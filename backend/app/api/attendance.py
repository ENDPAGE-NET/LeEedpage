import json
import os
import uuid as uuid_lib
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, Form, Query, UploadFile
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.config import settings
from app.core.database import get_db
from app.core.exceptions import BadRequestException, ServiceUnavailableException
from app.dependencies import get_admin_user, get_current_user
from app.models.attendance import AttendanceRecord
from app.models.checkin_rule import CheckinRule
from app.models.face_data import FaceData
from app.models.user import User
from app.schemas.attendance import (
    AttendanceListResponse,
    AttendanceResponse,
    AttendanceStatistics,
)
from app.services.face_service import (
    FaceEngineUnavailableError,
    FaceServiceError,
    verify_face,
)
from app.services.location_service import calculate_distance

router = APIRouter(prefix="/attendance", tags=["考勤"])

_WEB_TEST_DEVICE = "Web/Test Upload"


def _record_to_response(record: AttendanceRecord, user_name: str | None = None) -> AttendanceResponse:
    return AttendanceResponse(
        id=record.id,
        user_id=record.user_id,
        user_name=user_name,
        record_date=record.record_date,
        record_type=record.record_type,
        face_verified=record.face_verified,
        face_score=record.face_score,
        location_verified=record.location_verified,
        latitude=record.latitude,
        longitude=record.longitude,
        distance_m=record.distance_m,
        is_late=record.is_late,
        is_early_leave=record.is_early_leave,
        device_info=record.device_info,
        recorded_at=record.recorded_at,
    )


def _allow_test_mode(device_info: str | None) -> bool:
    return device_info == _WEB_TEST_DEVICE


def _load_reference_face_bytes(face_data: FaceData) -> bytes | None:
    if not face_data.image_path:
        return None
    if not os.path.exists(face_data.image_path):
        return None
    with open(face_data.image_path, "rb") as file_obj:
        return file_obj.read()


@router.get("/today")
def get_today_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    now_time = datetime.now(timezone.utc).strftime("%H:%M")

    checkin_record = db.query(AttendanceRecord).filter(
        AttendanceRecord.user_id == current_user.id,
        AttendanceRecord.record_date == today,
        AttendanceRecord.record_type == "checkin",
    ).first()
    checkout_record = db.query(AttendanceRecord).filter(
        AttendanceRecord.user_id == current_user.id,
        AttendanceRecord.record_date == today,
        AttendanceRecord.record_type == "checkout",
    ).first()
    rule = db.query(CheckinRule).filter(CheckinRule.user_id == current_user.id).first()

    work_days = [1, 2, 3, 4, 5]
    is_work_day = True
    if rule:
        try:
            work_days = json.loads(rule.work_days)
        except (json.JSONDecodeError, TypeError):
            work_days = [1, 2, 3, 4, 5]
        is_work_day = datetime.now(timezone.utc).isoweekday() in work_days

    return {
        "date": today,
        "current_time": now_time,
        "is_work_day": is_work_day,
        "checkin": {
            "done": checkin_record is not None,
            "time": checkin_record.recorded_at.isoformat() if checkin_record else None,
            "is_late": checkin_record.is_late if checkin_record else None,
        },
        "checkout": {
            "done": checkout_record is not None,
            "time": checkout_record.recorded_at.isoformat() if checkout_record else None,
            "is_early_leave": checkout_record.is_early_leave if checkout_record else None,
        },
        "rule": {
            "has_rule": rule is not None,
            "location_required": rule.location_required if rule else False,
            "location_name": rule.location_name if rule else None,
            "location_address": rule.location_address if rule else None,
            "latitude": rule.latitude if rule else None,
            "longitude": rule.longitude if rule else None,
            "allowed_radius_m": rule.allowed_radius_m if rule else None,
            "time_required": rule.time_required if rule else False,
            "checkin_start": rule.checkin_start if rule else None,
            "checkin_end": rule.checkin_end if rule else None,
            "checkout_start": rule.checkout_start if rule else None,
            "checkout_end": rule.checkout_end if rule else None,
        }
        if rule
        else {"has_rule": False},
    }


@router.post("/checkin", response_model=AttendanceResponse)
async def checkin(
    face_image: UploadFile = File(...),
    latitude: float | None = Form(None),
    longitude: float | None = Form(None),
    device_info: str | None = Form(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.status != "active":
        raise BadRequestException("账户未激活，请先完成首次登录设置")

    return await _do_attendance(
        record_type="checkin",
        face_image=face_image,
        latitude=latitude,
        longitude=longitude,
        device_info=device_info,
        user=current_user,
        db=db,
    )


@router.post("/checkout", response_model=AttendanceResponse)
async def checkout(
    face_image: UploadFile = File(...),
    latitude: float | None = Form(None),
    longitude: float | None = Form(None),
    device_info: str | None = Form(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.status != "active":
        raise BadRequestException("账户未激活，请先完成首次登录设置")

    return await _do_attendance(
        record_type="checkout",
        face_image=face_image,
        latitude=latitude,
        longitude=longitude,
        device_info=device_info,
        user=current_user,
        db=db,
    )


async def _do_attendance(
    record_type: str,
    face_image: UploadFile,
    latitude: float | None,
    longitude: float | None,
    device_info: str | None,
    user: User,
    db: Session,
) -> AttendanceResponse:
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    now_time = datetime.now(timezone.utc).strftime("%H:%M")

    existing = db.query(AttendanceRecord).filter(
        AttendanceRecord.user_id == user.id,
        AttendanceRecord.record_date == today,
        AttendanceRecord.record_type == record_type,
    ).first()
    if existing:
        time_str = existing.recorded_at.strftime("%H:%M") if existing.recorded_at else ""
        action_label = "签到" if record_type == "checkin" else "签退"
        raise BadRequestException(f"今天已{action_label}（{time_str}），无需重复{action_label}")

    if record_type == "checkout":
        checkin_exists = db.query(AttendanceRecord).filter(
            AttendanceRecord.user_id == user.id,
            AttendanceRecord.record_date == today,
            AttendanceRecord.record_type == "checkin",
        ).first()
        if not checkin_exists:
            raise BadRequestException("请先签到后再签退")

    rule = db.query(CheckinRule).filter(CheckinRule.user_id == user.id).first()
    weekday = datetime.now(timezone.utc).isoweekday()
    if rule:
        try:
            work_days = json.loads(rule.work_days)
        except (json.JSONDecodeError, TypeError):
            work_days = [1, 2, 3, 4, 5]
        if weekday not in work_days:
            raise BadRequestException("今天不是工作日，无需打卡")

    if rule and rule.time_required:
        if record_type == "checkin" and rule.checkin_start and now_time < rule.checkin_start:
            raise BadRequestException(f"签到时间未到，最早签到时间为 {rule.checkin_start}")
        if record_type == "checkout" and rule.checkout_end and now_time > rule.checkout_end:
            raise BadRequestException(f"签退时间已过，最晚签退时间为 {rule.checkout_end}")

    content = await face_image.read()

    face_data = db.query(FaceData).filter(
        FaceData.user_id == user.id,
        FaceData.is_active == True,
    ).first()
    if not face_data:
        raise BadRequestException("未注册人脸，请先在设置中完成人脸注册")

    try:
        face_verified, face_score = verify_face(
            content,
            face_data.embedding,
            settings.FACE_MATCH_THRESHOLD,
            allow_test_mode=_allow_test_mode(device_info),
            fallback_reference_image_bytes=_load_reference_face_bytes(face_data),
        )
    except FaceEngineUnavailableError as exc:
        raise ServiceUnavailableException(str(exc)) from exc
    except FaceServiceError as exc:
        raise BadRequestException(str(exc)) from exc

    if not face_verified:
        raise BadRequestException(
            f"人脸验证未通过（相似度: {face_score:.0%}），请确保使用本人照片并保持画面清晰"
        )

    location_verified = None
    distance_m = None
    if rule and rule.location_required:
        if latitude is None or longitude is None:
            raise BadRequestException("打卡要求提供位置信息，请授权定位权限后重试")
        if rule.latitude is not None and rule.longitude is not None:
            distance_m = calculate_distance(latitude, longitude, rule.latitude, rule.longitude)
            location_verified = distance_m <= rule.allowed_radius_m
            if not location_verified:
                raise BadRequestException(
                    f"不在打卡范围内（距离 {distance_m:.0f} 米，允许 {rule.allowed_radius_m} 米）"
                )

    is_late = False
    is_early_leave = False
    if rule and rule.time_required:
        if record_type == "checkin" and rule.checkin_end:
            is_late = now_time > rule.checkin_end
        if record_type == "checkout" and rule.checkout_start:
            is_early_leave = now_time < rule.checkout_start

    photo_filename = f"{uuid_lib.uuid4()}.jpg"
    photo_path = os.path.join(settings.UPLOAD_DIR, "checkins", photo_filename)
    with open(photo_path, "wb") as file_obj:
        file_obj.write(content)

    record = AttendanceRecord(
        user_id=user.id,
        record_date=today,
        record_type=record_type,
        face_verified=face_verified,
        face_score=face_score,
        location_verified=location_verified,
        latitude=latitude,
        longitude=longitude,
        distance_m=distance_m,
        is_late=is_late,
        is_early_leave=is_early_leave,
        device_info=device_info,
        photo_path=photo_path,
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return _record_to_response(record, user.full_name)


@router.get("/me", response_model=AttendanceListResponse)
def my_attendance(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    date_from: str = Query("", description="起始日期 YYYY-MM-DD"),
    date_to: str = Query("", description="结束日期 YYYY-MM-DD"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(AttendanceRecord).filter(AttendanceRecord.user_id == current_user.id)
    if date_from:
        query = query.filter(AttendanceRecord.record_date >= date_from)
    if date_to:
        query = query.filter(AttendanceRecord.record_date <= date_to)

    total = query.count()
    records = (
        query.order_by(AttendanceRecord.recorded_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return AttendanceListResponse(
        total=total,
        items=[_record_to_response(record, current_user.full_name) for record in records],
    )


@router.get("", response_model=AttendanceListResponse)
def list_attendance(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user_id: str = Query("", description="按用户筛选"),
    date_from: str = Query("", description="起始日期"),
    date_to: str = Query("", description="结束日期"),
    admin: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    query = db.query(AttendanceRecord, User.full_name).join(User, AttendanceRecord.user_id == User.id)
    if user_id:
        query = query.filter(AttendanceRecord.user_id == user_id)
    if date_from:
        query = query.filter(AttendanceRecord.record_date >= date_from)
    if date_to:
        query = query.filter(AttendanceRecord.record_date <= date_to)

    total = query.count()
    results = (
        query.order_by(AttendanceRecord.recorded_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return AttendanceListResponse(
        total=total,
        items=[_record_to_response(record, name) for record, name in results],
    )


@router.get("/statistics", response_model=AttendanceStatistics)
def get_statistics(
    date_from: str = Query(..., description="起始日期"),
    date_to: str = Query(..., description="结束日期"),
    admin: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    row = db.execute(
        text(
            """
            SELECT
                COUNT(*) AS total_records,
                SUM(CASE WHEN record_type = 'checkin' THEN 1 ELSE 0 END) AS total_checkins,
                SUM(CASE WHEN record_type = 'checkout' THEN 1 ELSE 0 END) AS total_checkouts,
                SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS late_count,
                SUM(CASE WHEN is_early_leave = 1 THEN 1 ELSE 0 END) AS early_leave_count
            FROM attendance_records
            WHERE record_date >= :date_from AND record_date <= :date_to
            """
        ),
        {"date_from": date_from, "date_to": date_to},
    ).first()

    return AttendanceStatistics(
        total_records=row[0] or 0,
        total_checkins=row[1] or 0,
        total_checkouts=row[2] or 0,
        late_count=row[3] or 0,
        early_leave_count=row[4] or 0,
        date_range_start=date_from,
        date_range_end=date_to,
    )


@router.get("/statistics/daily")
def get_daily_statistics(
    date_from: str = Query(..., description="起始日期"),
    date_to: str = Query(..., description="结束日期"),
    admin: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    result = db.execute(
        text(
            """
            SELECT
                record_date,
                COUNT(*) as total,
                SUM(CASE WHEN record_type = 'checkin' THEN 1 ELSE 0 END) as checkins,
                SUM(CASE WHEN record_type = 'checkout' THEN 1 ELSE 0 END) as checkouts,
                SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) as late_count,
                SUM(CASE WHEN is_early_leave = 1 THEN 1 ELSE 0 END) as early_leave_count
            FROM attendance_records
            WHERE record_date >= :date_from AND record_date <= :date_to
            GROUP BY record_date
            ORDER BY record_date
            """
        ),
        {"date_from": date_from, "date_to": date_to},
    ).fetchall()

    return [
        {
            "date": row[0],
            "total": row[1],
            "checkins": row[2],
            "checkouts": row[3],
            "late_count": row[4],
            "early_leave_count": row[5],
        }
        for row in result
    ]
