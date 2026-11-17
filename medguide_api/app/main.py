from contextlib import asynccontextmanager
from datetime import UTC, datetime
from http import HTTPStatus
from importlib.util import find_spec
import json
import logging
import shutil
from uuid import uuid4

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.config import get_settings
from app.database import initialize_database
from app.middleware import InMemoryUploadLimitMiddleware
from app.routers import appointments, auth, exams, medications, privacy

settings = get_settings()
logger = logging.getLogger("medguide.api")

FIELD_LABELS = {
    "name": "nome",
    "email": "e-mail",
    "password": "senha",
    "crm": "CRM",
    "specialty": "especialidade",
    "login": "login",
    "date_time": "data e horário",
    "symptoms": "motivo da consulta",
    "doctor_id": "profissional",
    "medication_name": "nome do medicamento",
    "medication_dosage": "dosagem",
    "medication_frequency": "frequência",
    "medication_duration": "duração",
    "times": "horários",
}

ERROR_CODES = {
    400: ("REQUEST_INVALID", "Confira os dados informados e tente novamente."),
    401: ("AUTH_REQUIRED", "Entre novamente para continuar."),
    403: ("AUTH_FORBIDDEN", "Seu perfil não tem permissão para esta ação."),
    404: ("RESOURCE_NOT_FOUND", "O item solicitado não foi encontrado."),
    405: ("REQUEST_METHOD_NOT_ALLOWED", "Esta ação não está disponível neste endereço."),
    409: ("BUSINESS_CONFLICT", "O estado atual não permite esta alteração."),
    413: ("REQUEST_TOO_LARGE", "O arquivo excede o tamanho permitido."),
    415: ("REQUEST_UNSUPPORTED_MEDIA", "O formato enviado não é compatível."),
    422: ("VALIDATION_INVALID_FIELD", "Revise os dados informados."),
    429: ("REQUEST_RATE_LIMITED", "Aguarde um pouco e tente novamente."),
    503: ("SERVICE_UNAVAILABLE", "Este serviço está temporariamente indisponível."),
}
ERROR_ACTIONS = {
    "REQUEST_INVALID": "Confira os campos e tente novamente.",
    "AUTH_SESSION_EXPIRED": "Entre novamente.",
    "AUTH_REQUIRED": "Entre na sua conta e tente novamente.",
    "AUTH_CREDENTIALS_INVALID": "Confira o e-mail e a senha.",
    "AUTH_FORBIDDEN": "Use um perfil autorizado para esta ação.",
    "RESOURCE_NOT_FOUND": "Atualize a tela e confirme se o item ainda existe.",
    "REQUEST_METHOD_NOT_ALLOWED": "Confira a ação disponível e tente novamente.",
    "BUSINESS_CONFLICT": "Atualize a tela antes de tentar novamente.",
    "REQUEST_TOO_LARGE": "Escolha um arquivo menor.",
    "REQUEST_UNSUPPORTED_MEDIA": "Envie um arquivo em formato compatível.",
    "VALIDATION_INVALID_FIELD": "Corrija os campos indicados e tente novamente.",
    "REQUEST_RATE_LIMITED": "Aguarde alguns instantes.",
    "SERVICE_UNAVAILABLE": "Tente novamente mais tarde.",
    "SERVER_INTERNAL": "Tente novamente em instantes. Se o problema continuar, informe o código de referência ao suporte.",
}


def _error_response(code: str, message: str, request_id: str, status_code: int, headers: dict | None = None):
    return JSONResponse(
        status_code=status_code,
        headers={**(headers or {}), "X-Request-ID": request_id},
        content={
            "success": False,
            "error": {
                "code": code,
                "message": message,
                "action": ERROR_ACTIONS.get(code, "Tente novamente."),
                "request_id": request_id,
            },
        },
    )


def _log_api_error(request: Request, request_id: str, code: str, **context):
    logger.warning(json.dumps({
        "timestamp": datetime.now(UTC).isoformat(),
        "code": code,
        "request_id": request_id,
        "method": request.method,
        "route": request.url.path,
        "user_id": getattr(request.state, "user_id", None),
        **context,
    }, ensure_ascii=False))


@asynccontextmanager
async def lifespan(_: FastAPI):
    initialize_database()
    yield


app = FastAPI(
    title="MedGuide API",
    description="API MedGuide para gestão de consultas e processamento controlado de documentos de saúde.",
    version="2.0.0",
    lifespan=lifespan,
)


@app.exception_handler(RequestValidationError)
async def request_validation_error_handler(request: Request, exc: RequestValidationError):
    fields = {
        FIELD_LABELS[location[-1]]
        for error in exc.errors()
        if (location := error.get("loc"))
        and str(location[-1]) in FIELD_LABELS
    }
    message = (
        f"Confira estes campos: {', '.join(sorted(fields))}."
        if fields
        else "Alguns dados estão inválidos ou incompletos. Revise os campos e tente novamente."
    )
    request_id = str(uuid4())
    code = "VALIDATION_INVALID_FIELD"
    _log_api_error(request, request_id, code, fields=sorted(fields))
    return _error_response(code, message, request_id, status.HTTP_422_UNPROCESSABLE_CONTENT)


@app.exception_handler(StarletteHTTPException)
async def http_error_handler(request: Request, exc: StarletteHTTPException):
    code, fallback = ERROR_CODES.get(exc.status_code, ("REQUEST_FAILED", "Não foi possível concluir a solicitação."))
    if exc.status_code == status.HTTP_401_UNAUTHORIZED:
        if request.url.path.endswith("/login"):
            code = "AUTH_CREDENTIALS_INVALID"
        elif isinstance(exc.detail, str) and ("inválido" in exc.detail.lower() or "expirado" in exc.detail.lower()):
            code = "AUTH_SESSION_EXPIRED"
    try:
        default_detail = HTTPStatus(exc.status_code).phrase
    except ValueError:
        default_detail = None
    message = exc.detail if isinstance(exc.detail, str) and exc.detail != default_detail else fallback
    request_id = str(uuid4())
    _log_api_error(request, request_id, code, status_code=exc.status_code)
    return _error_response(code, message, request_id, exc.status_code, exc.headers)


@app.exception_handler(Exception)
async def unexpected_error_handler(request: Request, exc: Exception):
    # Log route and exception type only; never include request bodies or clinical text.
    request_id = str(uuid4())
    code = "SERVER_INTERNAL"
    logger.error(json.dumps({
        "timestamp": datetime.now(UTC).isoformat(),
        "code": code,
        "request_id": request_id,
        "method": request.method,
        "route": request.url.path,
        "user_id": getattr(request.state, "user_id", None),
        "exception_type": type(exc).__name__,
    }, ensure_ascii=False))
    return _error_response(
        code,
        "O serviço encontrou um problema inesperado.",
        request_id,
        status.HTTP_500_INTERNAL_SERVER_ERROR,
    )

app.add_middleware(InMemoryUploadLimitMiddleware, max_bytes=settings.max_upload_bytes)
if settings.app_env == "development":
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
        allow_credentials=False,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-Privacy-Consent"],
    )
else:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=False,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
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
