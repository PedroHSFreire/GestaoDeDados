"""Manual HTTP smoke test for the live FastAPI routes using a disposable SQLite DB.

Run from medguide_api with the project's virtual environment activated:
    python tests/smoke_http_workflow.py
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import tempfile
import time
from uuid import uuid4

import httpx


API_ROOT = Path(__file__).resolve().parents[1]


def _free_port() -> int:
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def _expect(response: httpx.Response, expected: int, operation: str) -> dict:
    if response.status_code != expected:
        raise RuntimeError(
            f"{operation}: esperado HTTP {expected}, recebido HTTP {response.status_code}: "
            f"{response.text[:1000]}"
        )
    return response.json()


def _token(client: httpx.Client, route: str, email: str, password: str) -> str:
    body = _expect(
        client.post(route, json={"login": email, "password": password}),
        200,
        "login de teste",
    )
    return body["data"]["token"]


def run() -> None:
    port = _free_port()
    password = "SmokeTest-Pass-2026"
    patient_email = f"patient-{uuid4().hex}@example.com"
    doctor_email = f"doctor-{uuid4().hex}@example.com"
    doctor_crm = f"CRM-{uuid4().hex[:12]}"

    with tempfile.TemporaryDirectory(prefix="medguide-http-smoke-") as temporary:
        environment = os.environ.copy()
        environment.update({
            "APP_ENV": "test",
            "JWT_SECRET": secrets.token_urlsafe(48),
            "DATABASE_PATH": str(Path(temporary) / "smoke.sqlite3"),
        })
        server = subprocess.Popen(
            [sys.executable, "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", str(port), "--log-level", "error"],
            cwd=API_ROOT,
            env=environment,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        base_url = f"http://127.0.0.1:{port}"
        try:
            with httpx.Client(base_url=base_url, timeout=10) as client:
                for _ in range(100):
                    if server.poll() is not None:
                        raise RuntimeError("O servidor de teste encerrou antes de iniciar")
                    try:
                        health = client.get("/api/health")
                        if health.status_code == 200:
                            break
                    except httpx.ConnectError:
                        pass
                    time.sleep(0.1)
                else:
                    raise RuntimeError("Tempo esgotado aguardando o servidor de teste")
                health_data = health.json()["data"]
                print("PASS health endpoint HTTP")

                patient = _expect(client.post("/api/patients/register", json={
                    "name": "Paciente Smoke",
                    "email": patient_email,
                    "password": password,
                }), 201, "cadastro paciente")
                patient_id = patient["data"]["user"]["id"]
                doctor = _expect(client.post("/api/doctors/register", json={
                    "name": "Profissional Smoke",
                    "email": doctor_email,
                    "password": password,
                    "crm": doctor_crm,
                    "specialty": "Clínica médica",
                }), 201, "cadastro profissional")
                doctor_id = doctor["data"]["user"]["id"]
                patient_token = _token(client, "/api/patients/login", patient_email, password)
                doctor_token = _token(client, "/api/doctors/login", doctor_email, password)
                patient_headers = {"Authorization": f"Bearer {patient_token}"}
                doctor_headers = {"Authorization": f"Bearer {doctor_token}"}
                print("PASS cadastro e autenticacao HTTP para paciente e profissional")

                appointment = _expect(client.post("/api/appointments", headers=patient_headers, json={
                    "doctor_id": doctor_id,
                    "date_time": (datetime.now(UTC) + timedelta(days=7)).isoformat(),
                    "type": "online",
                    "symptoms": "Cenário fictício de smoke test",
                }), 201, "criação de consulta")
                appointment_id = appointment["data"]["id"]
                _expect(client.patch(f"/api/appointments/{appointment_id}", headers=doctor_headers, json={
                    "status": "confirmada",
                }), 200, "confirmação da consulta")
                _expect(client.patch(f"/api/appointments/{appointment_id}", headers=doctor_headers, json={
                    "diagnosis": "Registro sintético de teste",
                    "prescription": "",
                    "medication_name": "Medicamento Smoke",
                    "medication_dosage": "10 mg",
                    "medication_frequency": "1 vez ao dia",
                    "medication_duration": "7 dias",
                    "medication_notes": "Após refeição",
                    "doctor_notes": "Conteúdo fictício de validação",
                }), 200, "salvamento do prontuário e prescrição")
                history = _expect(client.get("/api/appointments/me", headers=patient_headers), 200, "histórico do paciente")["data"]
                patient_prescriptions = _expect(client.get("/api/medications/prescribed", headers=patient_headers), 200, "prescrições do paciente")["data"]
                assert any(row["id"] == appointment_id and row["medication_name"] == "Medicamento Smoke" for row in history)
                assert any(row["id"] == appointment_id and row["medication_frequency"] == "1 vez ao dia" for row in patient_prescriptions)
                print("PASS consulta, gravacao do prontuario e leitura da prescricao pelo paciente")

                optional_appointment = _expect(client.post("/api/appointments", headers=patient_headers, json={
                    "doctor_id": doctor_id,
                    "date_time": (datetime.now(UTC) + timedelta(days=8)).isoformat(),
                    "type": "online",
                    "symptoms": "Cenário sintético sem prescrição",
                }), 201, "criação de consulta sem prescrição")
                optional_id = optional_appointment["data"]["id"]
                _expect(client.patch(f"/api/appointments/{optional_id}", headers=doctor_headers, json={
                    "diagnosis": "Orientação sem medicamento",
                }), 200, "salvamento de prontuário sem prescrição")
                invalid_prescription = client.patch(f"/api/appointments/{optional_id}", headers=doctor_headers, json={
                    "medication_dosage": "10 mg",
                })
                assert invalid_prescription.status_code == 422
                assert invalid_prescription.json()["error"]["code"] == "VALIDATION_INVALID_FIELD"
                print("PASS prontuario sem prescricao; detalhes sem nome retornam validacao 422 padronizada")

                _expect(client.post("/api/exams", headers=doctor_headers, json={
                    "patient_id": patient_id,
                    "exam_type": "Exame Smoke",
                    "description": "Solicitação fictícia",
                }), 201, "criação de solicitação de exame")
                exams = _expect(client.get("/api/exams/me", headers=patient_headers), 200, "lista de exames do paciente")["data"]
                assert any(row["exam_type"] == "Exame Smoke" for row in exams)
                print("PASS solicitacao de exame visivel na area do paciente")

                if not health_data.get("ocr_binary_available") or not health_data.get("portuguese_ner_model_available"):
                    ocr = client.post(
                        "/api/privacy/ingest?document_type=receita",
                        headers={**patient_headers, "X-Privacy-Consent": "true", "Content-Type": "image/png"},
                        content=b"arquivo-ficticio-smoke",
                    )
                    ocr_error = ocr.json().get("error", {})
                    assert ocr.status_code == 503
                    assert ocr_error.get("code") == "SERVICE_UNAVAILABLE"
                    print("LIMIT OCR real nao executado: dependencia Tesseract/NER indisponivel; API respondeu 503 padronizado")
                else:
                    print("INFO dependências de OCR/NER disponíveis; este smoke test não envia imagem para evitar falso atestado de OCR")

        finally:
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait(timeout=5)


if __name__ == "__main__":
    run()
