from datetime import UTC, datetime
from importlib.util import find_spec
import shutil
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from starlette.concurrency import run_in_threadpool

from app.config import get_settings
from app.database import transaction
from app.privacy.pipeline import (
    assess_residual_risk,
    extract_text,
    mask_text,
    sanitize_image_bytes,
)
from app.schemas import IngestionResult
from app.security import new_id, require_role

router = APIRouter(prefix="/api/privacy", tags=["Proteção de documentos"])
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}


@router.post("/ingest", response_model=IngestionResult)
async def ingest_document(
    request: Request,
    user: Annotated[dict, Depends(require_role("patient"))],
    document_type: str = "receita",
    consent: Annotated[str | None, Header(alias="X-Privacy-Consent")] = None,
):
    if consent != "true":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Confirme a autorização para processar o documento")
    if document_type not in {"receita", "exame", "laudo"}:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Tipo de documento não permitido")
    media_type = request.headers.get("content-type", "").split(";")[0].lower()
    if media_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, "Envie uma imagem JPEG, PNG ou WEBP")

    tess_cmd = get_settings().tesseract_cmd or "tesseract"
    if not shutil.which(tess_cmd) or find_spec("pt_core_news_sm") is None:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "OCR ou modelo NER não está instalado")

    raw_image = await request.body()
    settings = get_settings()
    if not raw_image or len(raw_image) > settings.max_upload_bytes:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "Arquivo vazio ou acima do limite permitido")

    try:
        clean_image = await run_in_threadpool(sanitize_image_bytes, raw_image)
        ocr = await run_in_threadpool(extract_text, clean_image)
        if not ocr.text:
            return IngestionResult(
                success=False,
                decision="blocked",
                risk_score=1.0,
                ocr_confidence=ocr.confidence,
                findings=["TEXTO_NAO_EXTRAIDO"],
                message="Não foi possível ler o documento com segurança. Nenhum dado foi armazenado.",
            )
        masked = await run_in_threadpool(mask_text, ocr.text)
        risk = await run_in_threadpool(assess_residual_risk, masked.text)
    except RuntimeError as exc:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, str(exc)) from None
    except Exception:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "Não foi possível processar a imagem. Nenhum arquivo foi armazenado.",
        ) from None

    if ocr.confidence < settings.min_ocr_confidence:
        return IngestionResult(
            success=False,
            decision="review",
            masked_text=masked.text,
            risk_score=1.0,
            ocr_confidence=ocr.confidence,
            findings=["CONFIANCA_OCR_BAIXA", *masked.categories],
            message="A leitura ficou abaixo do limite. O resultado não foi persistido.",
        )

    if risk.score > settings.max_residual_risk:
        return IngestionResult(
            success=False,
            decision="blocked",
            masked_text=masked.text,
            risk_score=risk.score,
            ocr_confidence=ocr.confidence,
            findings=list(risk.findings),
            message="O Gatekeeper identificou risco residual. O resultado não foi persistido.",
        )

    document_id = new_id()
    ocr_confidence = ocr.confidence
    with transaction() as db:
        db.execute(
            """INSERT INTO protected_documents
               (id, owner_id, document_type, masked_text, risk_score, ocr_confidence, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (document_id, user["id"], document_type, masked.text, risk.score, ocr.confidence, datetime.now(UTC).isoformat()),
        )
    # The original bytes and the OCR raw text remain local variables only and are never logged or stored.
    del raw_image, clean_image, ocr
    return IngestionResult(
        success=True,
        decision="approved",
        masked_text=masked.text,
        risk_score=risk.score,
        ocr_confidence=ocr_confidence,
        findings=list(masked.categories),
        persisted_id=document_id,
        message="Texto mascarado aprovado e armazenado sem a imagem original.",
    )


@router.get("/documents")
def list_protected_documents(user: Annotated[dict, Depends(require_role("patient"))]):
    with transaction() as db:
        rows = db.execute(
            """SELECT id, document_type, masked_text, risk_score, ocr_confidence, created_at
               FROM protected_documents WHERE owner_id = ? ORDER BY created_at DESC""",
            (user["id"],),
        ).fetchall()
    return {"success": True, "data": [dict(row) for row in rows]}
