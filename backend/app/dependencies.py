from fastapi import Depends, Header
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import decode_token
from app.core.exceptions import CredentialsException, ForbiddenException
from app.models.user import User


def get_current_user(
    authorization: str = Header(..., description="Bearer token"),
    db: Session = Depends(get_db),
) -> User:
    if not authorization.startswith("Bearer "):
        raise CredentialsException("无效的认证头")

    token = authorization[7:]
    payload = decode_token(token)
    if payload is None or payload.get("type") != "access":
        raise CredentialsException("令牌无效或已过期")

    user_id = payload.get("sub")
    if user_id is None:
        raise CredentialsException("令牌无效")

    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise CredentialsException("用户不存在")
    if user.status == "disabled":
        raise CredentialsException("账户已禁用")

    return user


def get_admin_user(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != "admin":
        raise ForbiddenException("需要管理员权限")
    return current_user
