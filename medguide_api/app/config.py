from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_env: str = "development"
    jwt_secret: str = ""
    database_path: str = "./data/medguide.sqlite3"
    allowed_origins: str = "http://localhost:3000,http://127.0.0.1:3000"
    tesseract_cmd: str = ""
    tesseract_languages: str = "por+eng"
    max_upload_bytes: int = 8 * 1024 * 1024
    min_ocr_confidence: float = 0.55
    max_residual_risk: float = 0.2

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def database_file(self) -> Path:
        return Path(self.database_path).expanduser().resolve()

    @property
    def cors_origins(self) -> list[str]:
        return [origin.strip() for origin in self.allowed_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    settings = Settings()
    if len(settings.jwt_secret) < 32 or settings.jwt_secret.startswith("replace-"):
        raise RuntimeError("Defina JWT_SECRET com pelo menos 32 caracteres aleatórios em .env")
    if not 0 <= settings.max_residual_risk <= 1:
        raise RuntimeError("MAX_RESIDUAL_RISK deve estar entre 0 e 1")
    if not 0 <= settings.min_ocr_confidence <= 1:
        raise RuntimeError("MIN_OCR_CONFIDENCE deve estar entre 0 e 1")
    return settings
