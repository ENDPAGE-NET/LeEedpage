import json

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.exceptions import BadRequestException, NotFoundException
from app.dependencies import get_admin_user, get_current_user
from app.models.checkin_rule import CheckinRule
from app.models.user import User
from app.schemas.checkin_rule import (
    CheckinRuleBatchApplyRequest,
    CheckinRuleBatchApplyResponse,
    CheckinRuleBatchPreviewResponse,
    CheckinRuleCreate,
    CheckinRuleResponse,
)

router = APIRouter(prefix="/rules", tags=["打卡规则"])


def _rule_to_response(rule: CheckinRule) -> CheckinRuleResponse:
    return CheckinRuleResponse(
        id=rule.id,
        user_id=rule.user_id,
        location_required=rule.location_required,
        location_name=rule.location_name,
        location_address=rule.location_address,
        latitude=rule.latitude,
        longitude=rule.longitude,
        allowed_radius_m=rule.allowed_radius_m,
        time_required=rule.time_required,
        checkin_start=rule.checkin_start,
        checkin_end=rule.checkin_end,
        checkout_start=rule.checkout_start,
        checkout_end=rule.checkout_end,
        work_days=json.loads(rule.work_days),
    )


def _rule_to_payload(rule: CheckinRule) -> CheckinRuleCreate:
    return CheckinRuleCreate(
        location_required=rule.location_required,
        location_name=rule.location_name,
        location_address=rule.location_address,
        latitude=rule.latitude,
        longitude=rule.longitude,
        allowed_radius_m=rule.allowed_radius_m,
        time_required=rule.time_required,
        checkin_start=rule.checkin_start,
        checkin_end=rule.checkin_end,
        checkout_start=rule.checkout_start,
        checkout_end=rule.checkout_end,
        work_days=json.loads(rule.work_days),
    )


def _rule_signature(payload: CheckinRuleCreate) -> str:
    return json.dumps(payload.model_dump(mode="json"), sort_keys=True, ensure_ascii=False)


def _validate_rule_payload(payload: CheckinRuleCreate) -> None:
    if payload.location_required:
        if payload.latitude is None or payload.longitude is None:
            raise BadRequestException("启用地点要求时必须提供经纬度")
        if payload.allowed_radius_m <= 0:
            raise BadRequestException("允许半径必须大于 0")

    if not payload.work_days:
        raise BadRequestException("至少需要选择一个工作日")


def _apply_rule(rule: CheckinRule, payload: CheckinRuleCreate) -> None:
    rule.location_required = payload.location_required
    rule.location_name = payload.location_name
    rule.location_address = payload.location_address
    rule.latitude = payload.latitude
    rule.longitude = payload.longitude
    rule.allowed_radius_m = payload.allowed_radius_m
    rule.time_required = payload.time_required
    rule.checkin_start = payload.checkin_start
    rule.checkin_end = payload.checkin_end
    rule.checkout_start = payload.checkout_start
    rule.checkout_end = payload.checkout_end
    rule.work_days = json.dumps(payload.work_days, ensure_ascii=False)


def _clean_filters(search: str = "", status: str = "") -> tuple[str, str]:
    return search.strip(), status.strip()


def _employee_query(db: Session, search: str = "", status: str = ""):
    query = db.query(User).filter(User.role == "employee")
    if search:
        query = query.filter(
            (User.username.contains(search)) | (User.full_name.contains(search))
        )
    if status:
        query = query.filter(User.status == status)
    return query


@router.get("/users/{user_id}", response_model=CheckinRuleResponse | None)
def get_user_rule(
    user_id: str,
    admin: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise NotFoundException("用户不存在")

    rule = db.query(CheckinRule).filter(CheckinRule.user_id == user_id).first()
    if not rule:
        return None
    return _rule_to_response(rule)


@router.put("/users/{user_id}", response_model=CheckinRuleResponse)
def set_user_rule(
    user_id: str,
    req: CheckinRuleCreate,
    admin: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    _validate_rule_payload(req)

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise NotFoundException("用户不存在")

    rule = db.query(CheckinRule).filter(CheckinRule.user_id == user_id).first()
    if rule is None:
        rule = CheckinRule(user_id=user_id)
        db.add(rule)

    _apply_rule(rule, req)
    db.commit()
    db.refresh(rule)
    return _rule_to_response(rule)


@router.get("/batch-preview", response_model=CheckinRuleBatchPreviewResponse)
def get_batch_rule_preview(
    search: str = Query(default=""),
    status: str = Query(default=""),
    admin: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    clean_search, clean_status = _clean_filters(search, status)
    users = _employee_query(db, search=clean_search, status=clean_status).all()
    matched_count = len(users)

    if matched_count == 0:
        return CheckinRuleBatchPreviewResponse(
            matched_count=0,
            configured_count=0,
            distinct_rule_count=0,
            preview_source="default",
            preview_user_name=None,
            rule=None,
        )

    user_ids = [user.id for user in users]
    existing_rules = (
        db.query(CheckinRule)
        .filter(CheckinRule.user_id.in_(user_ids))
        .order_by(CheckinRule.updated_at.desc(), CheckinRule.created_at.desc())
        .all()
    )
    configured_count = len(existing_rules)

    if configured_count == 0:
        return CheckinRuleBatchPreviewResponse(
            matched_count=matched_count,
            configured_count=0,
            distinct_rule_count=0,
            preview_source="default",
            preview_user_name=None,
            rule=None,
        )

    user_name_map = {user.id: user.full_name for user in users}
    signatures: dict[str, CheckinRuleCreate] = {}
    for rule in existing_rules:
        payload = _rule_to_payload(rule)
        signatures[_rule_signature(payload)] = payload

    distinct_rule_count = len(signatures)
    latest_rule = existing_rules[0]
    preview_rule = (
        next(iter(signatures.values()))
        if distinct_rule_count == 1
        else _rule_to_payload(latest_rule)
    )

    return CheckinRuleBatchPreviewResponse(
        matched_count=matched_count,
        configured_count=configured_count,
        distinct_rule_count=distinct_rule_count,
        preview_source="uniform" if distinct_rule_count == 1 else "latest",
        preview_user_name=user_name_map.get(latest_rule.user_id),
        rule=preview_rule,
    )


@router.post("/batch-apply", response_model=CheckinRuleBatchApplyResponse)
def batch_apply_rule(
    req: CheckinRuleBatchApplyRequest,
    admin: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    _validate_rule_payload(req.rule)
    clean_search, clean_status = _clean_filters(req.filters.search, req.filters.status)
    users = _employee_query(db, search=clean_search, status=clean_status).all()

    matched_count = len(users)
    if matched_count == 0:
        return CheckinRuleBatchApplyResponse(
            matched_count=0,
            updated_count=0,
            unchanged_count=0,
        )

    user_ids = [user.id for user in users]
    existing_rules = db.query(CheckinRule).filter(CheckinRule.user_id.in_(user_ids)).all()
    existing_rule_map = {rule.user_id: rule for rule in existing_rules}
    target_signature = _rule_signature(req.rule)

    updated_count = 0
    unchanged_count = 0

    for user in users:
        rule = existing_rule_map.get(user.id)
        if rule is None:
            rule = CheckinRule(user_id=user.id)
            db.add(rule)
            _apply_rule(rule, req.rule)
            updated_count += 1
            continue

        if _rule_signature(_rule_to_payload(rule)) == target_signature:
            unchanged_count += 1
            continue

        _apply_rule(rule, req.rule)
        updated_count += 1

    if updated_count:
        db.commit()

    return CheckinRuleBatchApplyResponse(
        matched_count=matched_count,
        updated_count=updated_count,
        unchanged_count=unchanged_count,
    )


@router.get("/me", response_model=CheckinRuleResponse | None)
def get_my_rule(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rule = db.query(CheckinRule).filter(CheckinRule.user_id == current_user.id).first()
    if not rule:
        return None
    return _rule_to_response(rule)
