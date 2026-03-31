import io
import logging
from pathlib import Path

import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)

_face_app = None
_face_engine_error: str | None = None
_TEST_FACE_PREFIX = b"TESTFACE1:"
_TEST_FACE_MATCH_THRESHOLD = 0.94


class FaceServiceError(Exception):
    pass


class FaceEngineUnavailableError(FaceServiceError):
    pass


def is_test_face_embedding(data: bytes) -> bool:
    return data.startswith(_TEST_FACE_PREFIX)


def _get_face_app():
    global _face_app, _face_engine_error
    if _face_app is not None:
        return _face_app
    if _face_engine_error is not None:
        raise FaceEngineUnavailableError(_face_engine_error)

    try:
        from insightface.app import FaceAnalysis

        models_dir = str(Path(__file__).parent.parent.parent / "models")
        face_app = FaceAnalysis(name="buffalo_l", root=models_dir)
        face_app.prepare(ctx_id=-1, det_size=(640, 640))
        _face_app = face_app
        logger.info("InsightFace model loaded successfully")
        return _face_app
    except Exception as exc:
        _face_engine_error = (
            "人脸识别引擎不可用，请先正确安装并加载 InsightFace 模型后再进行正式人脸识别。"
            f" 当前错误: {exc}"
        )
        logger.exception("Failed to initialize InsightFace")
        raise FaceEngineUnavailableError(_face_engine_error) from exc


def _image_bytes_to_bgr(image_bytes: bytes) -> np.ndarray:
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    image_array = np.array(image)
    return image_array[:, :, ::-1]


def _normalize_embedding(embedding: np.ndarray) -> np.ndarray:
    norm = np.linalg.norm(embedding)
    if norm <= 0:
        raise FaceServiceError("无法生成有效的人脸特征，请重新拍摄或上传更清晰的单人正脸照片")
    return (embedding / norm).astype(np.float32)


def _extract_test_embedding(image_bytes: bytes) -> np.ndarray:
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    width, height = image.size
    side = min(width, height)
    left = max((width - side) // 2, 0)
    top = max((height - side) // 2, 0)
    image = image.crop((left, top, left + side, top + side)).resize((32, 32))
    image_array = np.asarray(image, dtype=np.float32) / 255.0
    image_array = image_array - float(image_array.mean())
    return _normalize_embedding(image_array.reshape(-1))


def extract_embedding(image_bytes: bytes) -> np.ndarray:
    app = _get_face_app()
    faces = app.get(_image_bytes_to_bgr(image_bytes))
    if not faces:
        raise FaceServiceError("未检测到人脸，请确保图片中有清晰的单人正脸")
    if len(faces) > 1:
        raise FaceServiceError("检测到多张人脸，请确保画面中只有一人")
    return _normalize_embedding(faces[0].embedding)


def compute_similarity(embedding1: np.ndarray, embedding2: np.ndarray) -> float:
    dot = np.dot(embedding1, embedding2)
    norm1 = np.linalg.norm(embedding1)
    norm2 = np.linalg.norm(embedding2)
    if norm1 == 0 or norm2 == 0:
        return 0.0
    similarity = dot / (norm1 * norm2)
    return float(max(0.0, similarity))


def embedding_to_bytes(embedding: np.ndarray) -> bytes:
    return embedding.astype(np.float32).tobytes()


def bytes_to_embedding(data: bytes) -> np.ndarray:
    return np.frombuffer(data, dtype=np.float32).copy()


def test_embedding_to_bytes(embedding: np.ndarray) -> bytes:
    return _TEST_FACE_PREFIX + embedding_to_bytes(embedding)


def test_bytes_to_embedding(data: bytes) -> np.ndarray:
    if not is_test_face_embedding(data):
        raise FaceServiceError("当前人脸样本不是 Web 测试模式生成的数据")
    return bytes_to_embedding(data[len(_TEST_FACE_PREFIX):])


def register_face_from_images(image_bytes_list: list[bytes], allow_test_mode: bool = False) -> bytes:
    if not image_bytes_list:
        raise FaceServiceError("至少需要一张有效的人脸照片")

    try:
        _get_face_app()
        embeddings = [extract_embedding(image_bytes) for image_bytes in image_bytes_list]
        average_embedding = np.mean(embeddings, axis=0).astype(np.float32)
        return embedding_to_bytes(_normalize_embedding(average_embedding))
    except FaceEngineUnavailableError:
        if not allow_test_mode:
            raise

    test_embeddings = [_extract_test_embedding(image_bytes) for image_bytes in image_bytes_list]
    average_test_embedding = np.mean(test_embeddings, axis=0).astype(np.float32)
    return test_embedding_to_bytes(_normalize_embedding(average_test_embedding))


def verify_test_face(
    image_bytes: bytes,
    stored_embedding_bytes: bytes,
    threshold: float = _TEST_FACE_MATCH_THRESHOLD,
) -> tuple[bool, float]:
    candidate_embedding = _extract_test_embedding(image_bytes)
    stored_embedding = test_bytes_to_embedding(stored_embedding_bytes)
    score = compute_similarity(candidate_embedding, stored_embedding)
    return score >= threshold, score


def verify_face_with_test_reference(
    image_bytes: bytes,
    reference_image_bytes: bytes,
    threshold: float = _TEST_FACE_MATCH_THRESHOLD,
) -> tuple[bool, float]:
    candidate_embedding = _extract_test_embedding(image_bytes)
    reference_embedding = _extract_test_embedding(reference_image_bytes)
    score = compute_similarity(candidate_embedding, reference_embedding)
    return score >= threshold, score


def verify_face(
    image_bytes: bytes,
    stored_embedding_bytes: bytes,
    threshold: float = 0.45,
    allow_test_mode: bool = False,
    fallback_reference_image_bytes: bytes | None = None,
) -> tuple[bool, float]:
    if is_test_face_embedding(stored_embedding_bytes):
        if not allow_test_mode:
            raise FaceServiceError("当前人脸样本仅用于 Web 测试，请在 Android/iOS 真机重新注册")
        return verify_test_face(image_bytes, stored_embedding_bytes)

    try:
        candidate_embedding = extract_embedding(image_bytes)
        stored_embedding = bytes_to_embedding(stored_embedding_bytes)
        score = compute_similarity(candidate_embedding, stored_embedding)
        return score >= threshold, score
    except FaceEngineUnavailableError:
        if allow_test_mode and fallback_reference_image_bytes:
            return verify_face_with_test_reference(image_bytes, fallback_reference_image_bytes)
        raise
