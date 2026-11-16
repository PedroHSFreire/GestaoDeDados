import os
import tempfile
from pathlib import Path
from uuid import uuid4

_test_data = tempfile.TemporaryDirectory(prefix="medguide-api-test-")
os.environ["APP_ENV"] = "test"
os.environ["JWT_SECRET"] = "test-only-secret-not-for-real-deployments-32chars"
os.environ["DATABASE_PATH"] = str(Path(_test_data.name) / "test.sqlite3")

from fastapi.testclient import TestClient

from app.main import app
from app.privacy import pipeline
from app.routers import privacy as privacy_router


def _patient_token(client: TestClient) -> str:
    email = f"patient-{uuid4().hex}@example.org"
    registered = client.post("/api/pacient/register", json={
        "name": "Paciente Fictício", "email": email, "password": "SenhaSegura123"
    })
    assert registered.status_code == 201
    login = client.post("/api/pacient/login", json={"login": email, "password": "SenhaSegura123"})
    return login.json()["data"]["token"]


def test_masks_direct_identifiers_and_keeps_clinical_content():
    result = pipeline.mask_text(
        "Paciente: Ana Exemplo, CPF: 529.982.247-25, CRM 123456. "
        "Usar Dipirona 500 mg, 1 comprimido a cada 8 horas."
    )
    assert "529.982.247-25" not in result.text
    assert "123456" not in result.text
    assert "Dipirona 500 mg" in result.text
    assert "1 comprimido a cada 8 horas" in result.text
    assert "[CPF]" in result.text
    assert pipeline.assess_residual_risk(result.text).score <= 0.2


def test_gatekeeper_flags_residual_direct_identifier():
    assessment = pipeline.assess_residual_risk("Texto: CPF 529.982.247-25; usar medicamento X")
    assert assessment.score > 0.2
    assert "CPF" in assessment.findings


def test_ingestion_persists_only_approved_masked_text(monkeypatch):
    monkeypatch.setattr(privacy_router.shutil, "which", lambda command: "mocked-tesseract")
    monkeypatch.setattr(privacy_router, "find_spec", lambda name: object())
    monkeypatch.setattr(privacy_router, "sanitize_image_bytes", lambda raw: b"sanitized")
    monkeypatch.setattr(privacy_router, "extract_text", lambda clean: pipeline.OCRResult(
        "Paciente: Ana Exemplo, CPF 529.982.247-25. Usar Dipirona 500 mg a cada 8 horas.", 0.98
    ))
    monkeypatch.setattr(privacy_router, "mask_text", lambda text: pipeline.MaskResult(
        "Paciente [NOME], CPF [CPF]. Usar Dipirona 500 mg a cada 8 horas.", ("CPF", "NOME")
    ))
    monkeypatch.setattr(privacy_router, "assess_residual_risk", lambda text: pipeline.RiskResult(0.0, ()))

    with TestClient(app) as client:
        token = _patient_token(client)
        headers = {
            "Authorization": f"Bearer {token}",
            "X-Privacy-Consent": "true",
            "Content-Type": "image/png",
        }
        response = client.post("/api/privacy/ingest?document_type=receita", content=b"fake image", headers=headers)
        assert response.status_code == 200, response.text
        assert response.json()["decision"] == "approved"
        assert "529.982.247-25" not in response.json()["masked_text"]
        stored = client.get("/api/privacy/documents", headers={"Authorization": f"Bearer {token}"})
        assert stored.status_code == 200
        assert len(stored.json()["data"]) == 1
        assert "529.982.247-25" not in stored.json()["data"][0]["masked_text"]


def test_ingestion_rejects_without_consent():
    with TestClient(app) as client:
        token = _patient_token(client)
        response = client.post(
            "/api/privacy/ingest?document_type=receita",
            content=b"image",
            headers={"Authorization": f"Bearer {token}", "Content-Type": "image/png"},
        )
        assert response.status_code == 400


def test_gatekeeper_blocks_and_does_not_persist_residual_risk(monkeypatch):
    monkeypatch.setattr(privacy_router.shutil, "which", lambda command: "mocked-tesseract")
    monkeypatch.setattr(privacy_router, "find_spec", lambda name: object())
    monkeypatch.setattr(privacy_router, "sanitize_image_bytes", lambda raw: b"sanitized")
    monkeypatch.setattr(privacy_router, "extract_text", lambda clean: pipeline.OCRResult("texto fictício", 0.99))
    monkeypatch.setattr(privacy_router, "mask_text", lambda text: pipeline.MaskResult("CPF residual 000.000.000-00", ("CPF",)))
    monkeypatch.setattr(privacy_router, "assess_residual_risk", lambda text: pipeline.RiskResult(0.7, ("CPF",)))

    with TestClient(app) as client:
        token = _patient_token(client)
        headers = {
            "Authorization": f"Bearer {token}",
            "X-Privacy-Consent": "true",
            "Content-Type": "image/png",
        }
        response = client.post("/api/privacy/ingest?document_type=exame", content=b"fake image", headers=headers)
        assert response.status_code == 200
        assert response.json()["decision"] == "blocked"
        stored = client.get("/api/privacy/documents", headers={"Authorization": f"Bearer {token}"})
        assert stored.status_code == 200
        assert stored.json()["data"] == []
