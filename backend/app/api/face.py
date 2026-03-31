import os
import uuid as uuid_lib

from fastapi import APIRouter, Depends, File, Form, UploadFile
from sqlalchemy.orm import Session

from app.config import settings
from app.core.database import get_db
from app.core.exceptions import BadRequestException, ServiceUnavailableException
from app.dependencies import get_current_user
from app.models.face_data import FaceData
from app.models.user import User
from app.services.face_service import (
    FaceEngineUnavailableError,
    FaceServiceError,
    register_face_from_images,
)

router = APIRouter(prefix="/face", tags=["人脸管理"])

_WEB_TEST_DEVICE = "Web/Test Upload"


def _allow_test_mode(device_info: str | None) -> bool:
    return device_info == _WEB_TEST_DEVICE


@router.post("/register")
async def register_face(
    images: list[UploadFile] = File(..., description="上传 1-3 张人脸照片"),
    device_info: str | None = Form(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if len(images) < 1 or len(images) > 3:
        raise BadRequestException("请上传 1-3 张人脸照片")

    image_bytes_list: list[bytes] = []
    for image in images:
        image_bytes_list.append(await image.read())

    try:
        embedding_bytes = register_face_from_images(
            image_bytes_list,
            allow_test_mode=_allow_test_mode(device_info),
        )
    except FaceEngineUnavailableError as exc:
        raise ServiceUnavailableException(str(exc)) from exc
    except FaceServiceError as exc:
        raise BadRequestException(str(exc)) from exc

    saved_paths: list[str] = []
    for content in image_bytes_list:
        filename = f"{uuid_lib.uuid4()}.jpg"
        path = os.path.join(settings.UPLOAD_DIR, "faces", filename)
        with open(path, "wb") as file_obj:
            file_obj.write(content)
        saved_paths.append(path)

    db.query(FaceData).filter(
        FaceData.user_id == current_user.id,
        FaceData.is_active == True,
    ).update({"is_active": False})

    db.add(
        FaceData(
            user_id=current_user.id,
            embedding=embedding_bytes,
            image_path=saved_paths[0],
            is_active=True,
        )
    )
    db.commit()

    return {
        "message": "人脸注册成功",
        "images_count": len(saved_paths),
        "mode": "web_test" if _allow_test_mode(device_info) else "formal",
    }
