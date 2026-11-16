from contextlib import asynccontextmanager
from importlib.util import find_spec
import shutil

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.database import initialize_database
from app.middleware import InMemoryUploadLimitMiddleware
from app.routers import appointments, auth, exams, medications, privacy

settings = get_settings()


@asynccontextmanager
async def lifespan(_: FastAPI):
    initialize_database()
    yield


app = FastAPI(
    title="MedGuide API",
    description="API do protótipo acadêmico e ingestão efêmera de documentos de saúde.",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(InMemoryUploadLimitMiddleware, max_bytes=settings.max_upload_bytes)
if settings.app_env == "development":
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
        allow_credentials=False,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-Privacy-Consent"],
    )
else:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=False,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-Privacy-Consent"],
    )

app.include_router(auth.router)
app.include_router(appointments.router)
app.include_router(medications.router)
app.include_router(exams.router)
app.include_router(privacy.router)


@app.get("/api/health", tags=["Sistema"])
def health():
    tess_cmd = settings.tesseract_cmd or "tesseract"
    return {
        "success": True,
        "data": {
            "api": "ok",
            "ocr_binary_available": bool(shutil.which(tess_cmd)),
            "portuguese_ner_model_available": find_spec("pt_core_news_sm") is not None,
            "privacy_pipeline": "ready" if shutil.which(tess_cmd) and find_spec("pt_core_news_sm") else "dependencies_missing",
        },
    }
