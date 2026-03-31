from pathlib import Path

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    SECRET_KEY: str = "dev-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    DATABASE_URL: str = "sqlite:///./attendance.db"
    UPLOAD_DIR: str = "./uploads"
    FACE_MATCH_THRESHOLD: float = 0.45

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()

Path(settings.UPLOAD_DIR).mkdir(parents=True, exist_ok=True)
Path(settings.UPLOAD_DIR, "faces").mkdir(parents=True, exist_ok=True)
Path(settings.UPLOAD_DIR, "checkins").mkdir(parents=True, exist_ok=True)
