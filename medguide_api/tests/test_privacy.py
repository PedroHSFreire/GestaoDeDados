import os
import tempfile
from pathlib import Path
from uuid import uuid4
from uuid import UUID

_test_data = tempfile.TemporaryDirectory(prefix="medguide-api-test-")
os.environ["APP_ENV"] = "test"
os.environ["JWT_SECRET"] = "test-only-secret-not-for-real-deployments-32chars"
os.environ["DATABASE_PATH"] = str(Path(_test_data.name) / "test.sqlite3")

from fastapi.testclient import TestClient

from app.main import app
from app.privacy import pipeline
from app.routers import privacy as privacy_router
from app.schemas import AppointmentUpdate
from app.security import new_id
from pydantic import ValidationError


def _patient_token(client: TestClient) -> str:
    email = f"patient-{uuid4().hex}@example.org"
    registered = client.post("/api/patients/register", json={
        "name": "Paciente Fictício", "email": email, "password": "SenhaSegura123"
    })
    assert registered.status_code == 201
    login = client.post("/api/patients/login", json={"login": email, "password": "SenhaSegura123"})
    return login.json()["data"]["token"]


def _doctor_token(client: TestClient) -> tuple[str, str]:
    email = f"doctor-{uuid4().hex}@example.org"
    registered = client.post("/api/doctors/register", json={
        "name": "Doutora Fictícia", "email": email, "password": "SenhaSegura123",
        "crm": f"CRM-{uuid4().hex[:12]}", "specialty": "Clínica médica",
    })
    assert registered.status_code == 201
    login = client.post("/api/doctors/login", json={"login": email, "password": "SenhaSegura123"})
    return login.json()["data"]["token"], registered.json()["data"]["user"]["id"]


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


def test_consultation_can_be_saved_without_medication():
    record = AppointmentUpdate(diagnosis="Acompanhamento clínico")
    assert record.diagnosis == "Acompanhamento clínico"
    assert record.medication_name is None


def test_prescription_details_require_medication_name():
    try:
        AppointmentUpdate(medication_dosage="500 mg", medication_frequency="8/8 horas")
    except ValidationError as error:
        assert "Informe o nome do medicamento" in str(error)
    else:
        raise AssertionError("Detalhes de prescrição sem nome deveriam ser rejeitados")

    record = AppointmentUpdate(medication_name="Dipirona", medication_dosage="500 mg")
    assert record.medication_name == "Dipirona"
    empty_record = AppointmentUpdate(medication_name="   ")
    assert empty_record.medication_name == ""


def test_api_validation_error_is_readable_and_does_not_echo_input():
    with TestClient(app) as client:
        response = client.post("/api/patients/register", json={
            "name": "A",
            "email": "valor-sensivel-invalido",
            "password": "x",
        })

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "VALIDATION_INVALID_FIELD"
    assert "e-mail" in response.json()["error"]["message"]
    assert "senha" in response.json()["error"]["message"]
    assert response.json()["error"]["request_id"]
    assert "valor-sensivel-invalido" not in response.text


def test_doctor_exam_request_appears_in_patient_exam_list():
    with TestClient(app) as client:
        patient_token = _patient_token(client)
        patient_profile = client.get(
            "/api/patients/me", headers={"Authorization": f"Bearer {patient_token}"}
        ).json()["data"]
        doctor_token, doctor_id = _doctor_token(client)
        appointment = client.post(
            "/api/appointments",
            headers={"Authorization": f"Bearer {patient_token}"},
            json={
                "doctor_id": doctor_id,
                "date_time": "2027-01-10T10:00:00Z",
                "type": "online",
                "symptoms": "Consulta de acompanhamento",
            },
        )
        appointment_id = appointment.json()["data"]["id"]
        confirmed = client.put(
            f"/api/appointments/{appointment_id}",
            headers={"Authorization": f"Bearer {doctor_token}"},
            json={"status": "confirmada"},
        )
        assert confirmed.status_code == 200

        created = client.post(
            "/api/exams",
            headers={"Authorization": f"Bearer {doctor_token}"},
            json={
                "patient_id": patient_profile["id"],
                "exam_type": "Hemograma",
                "description": "Coleta em jejum",
            },
        )
        assert created.status_code == 201

        patient_exams = client.get(
            "/api/exams/me", headers={"Authorization": f"Bearer {patient_token}"}
        )
        assert patient_exams.status_code == 200
        assert len(patient_exams.json()["data"]) == 1
        assert patient_exams.json()["data"][0]["exam_type"] == "Hemograma"
        assert patient_exams.json()["data"][0]["doctor_name"] == "Doutora Fictícia"


def test_doctor_can_update_clinical_record_and_patient_sees_medication():
    with TestClient(app) as client:
        patient_token = _patient_token(client)
        patient_profile = client.get(
            "/api/patients/me", headers={"Authorization": f"Bearer {patient_token}"}
        ).json()["data"]
        doctor_token, doctor_id = _doctor_token(client)
        appointment = client.post(
            "/api/appointments",
            headers={"Authorization": f"Bearer {patient_token}"},
            json={
                "doctor_id": doctor_id,
                "date_time": "2027-01-10T10:00:00Z",
                "type": "online",
                "symptoms": "Consulta de acompanhamento",
            },
        ).json()["data"]
        client.put(
            f"/api/appointments/{appointment['id']}",
            headers={"Authorization": f"Bearer {doctor_token}"},
            json={"status": "confirmada"},
        )

        saved = client.patch(
            f"/api/appointments/{appointment['id']}",
            headers={"Authorization": f"Bearer {doctor_token}"},
            json={
                "diagnosis": "Acompanhamento",
                "prescription": "",
                "medication_name": "Medicamento fictício",
                "medication_dosage": "10 mg",
                "medication_frequency": "1 vez ao dia",
                "medication_duration": "7 dias",
                "medication_notes": "Após a refeição",
                "doctor_notes": "Retorno em 30 dias",
            },
        )
        assert saved.status_code == 200, saved.text
        assert saved.json()["data"]["medication_name"] == "Medicamento fictício"

        patient_history = client.get(
            "/api/appointments/me", headers={"Authorization": f"Bearer {patient_token}"}
        ).json()["data"]
        updated_appointment = next(item for item in patient_history if item["id"] == appointment["id"])
        assert updated_appointment["medication_frequency"] == "1 vez ao dia"
        assert updated_appointment["prescription"] == ""

        prescribed = client.get(
            "/api/medications/prescribed", headers={"Authorization": f"Bearer {patient_token}"}
        )
        assert prescribed.status_code == 200
        assert len(prescribed.json()["data"]) == 1
        assert prescribed.json()["data"][0]["medication_name"] == "Medicamento fictício"
        assert prescribed.json()["data"][0]["doctor_name"] == "Doutora Fictícia"


def test_all_generated_resource_ids_are_random_uuid4():
    identifier = UUID(new_id())
    assert identifier.version == 4


def test_legacy_patient_auth_route_remains_available():
    with TestClient(app) as client:
        response = client.post("/api/pacient/register", json={
            "name": "Paciente Compatível", "email": f"legacy-{uuid4().hex}@example.org",
            "password": "SenhaSegura123",
        })
    assert response.status_code == 201


def test_not_found_uses_standard_error_envelope():
    with TestClient(app) as client:
        response = client.get("/api/resource-that-does-not-exist")

    assert response.status_code == 404
    assert response.json()["success"] is False
    assert response.json()["error"]["code"] == "RESOURCE_NOT_FOUND"
    assert response.json()["error"]["message"] == "O item solicitado não foi encontrado."
    assert response.headers["x-request-id"] == response.json()["error"]["request_id"]
