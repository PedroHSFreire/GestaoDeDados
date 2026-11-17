from datetime import UTC
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

from app.database import transaction
from app.schemas import AppointmentCreate, AppointmentUpdate
from app.security import current_user, new_id

router = APIRouter(prefix="/api/appointments", tags=["Consultas"])


def _rows(query: str, values: tuple):
    with transaction() as db:
        return [dict(row) for row in db.execute(query, values).fetchall()]


@router.get("/mine", deprecated=True, include_in_schema=False)
@router.get("/me")
def list_my_appointments(user: Annotated[dict, Depends(current_user)]):
    if user["role"] == "patient":
        query = """SELECT a.*, d.name AS doctor_name, d.specialty FROM appointments a
                   JOIN users d ON d.id = a.doctor_id WHERE a.patient_id = ? ORDER BY a.date_time"""
    else:
        query = """SELECT a.*, p.name AS patient_name FROM appointments a
                   JOIN users p ON p.id = a.patient_id WHERE a.doctor_id = ? ORDER BY a.date_time"""
    return {"success": True, "data": _rows(query, (user["id"],))}


@router.post("", status_code=status.HTTP_201_CREATED)
def create_appointment(payload: AppointmentCreate, user: Annotated[dict, Depends(current_user)]):
    if user["role"] != "patient":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Somente paciente pode solicitar consulta")
    with transaction() as db:
        doctor = db.execute("SELECT id, specialty FROM users WHERE id = ? AND role = 'doctor'", (payload.doctor_id,)).fetchone()
        if doctor is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Profissional não encontrado")
        appointment_id = new_id()
        db.execute(
            """INSERT INTO appointments (id, patient_id, doctor_id, date_time, appointment_type, symptoms, notes)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (
                appointment_id, user["id"], doctor["id"],
                payload.date_time.astimezone(UTC).isoformat(), payload.type,
                payload.symptoms.strip(), payload.notes.strip() if payload.notes else None,
            ),
        )
        row = db.execute("SELECT * FROM appointments WHERE id = ?", (appointment_id,)).fetchone()
    return {"success": True, "data": dict(row)}


@router.get("/{appointment_id}")
def get_appointment(appointment_id: str, user: Annotated[dict, Depends(current_user)]):
    with transaction() as db:
        row = db.execute("SELECT * FROM appointments WHERE id = ?", (appointment_id,)).fetchone()
    if row is None or user["id"] not in {row["patient_id"], row["doctor_id"]}:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Consulta não encontrada")
    return {"success": True, "data": dict(row)}


@router.put("/{appointment_id}", deprecated=True, include_in_schema=False)
@router.patch("/{appointment_id}")
def update_appointment(appointment_id: str, payload: AppointmentUpdate, user: Annotated[dict, Depends(current_user)]):
    changes = payload.model_dump(exclude_unset=True, exclude_none=True)
    with transaction() as db:
        row = db.execute("SELECT * FROM appointments WHERE id = ?", (appointment_id,)).fetchone()
        if row is None or user["id"] not in {row["patient_id"], row["doctor_id"]}:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Consulta não encontrada")
        if user["role"] == "patient":
            if changes != {"status": "cancelada"}:
                raise HTTPException(status.HTTP_403_FORBIDDEN, "Paciente só pode cancelar a própria consulta")
        else:
            if row["doctor_id"] != user["id"]:
                raise HTTPException(status.HTTP_403_FORBIDDEN, "Ação não permitida")
            if not changes:
                raise HTTPException(status.HTTP_400_BAD_REQUEST, "Nenhuma alteração informada")
        allowed = {
            "status", "diagnosis", "prescription", "doctor_notes",
            "medication_name", "medication_dosage", "medication_frequency",
            "medication_duration", "medication_notes",
        }
        if not changes.keys() <= allowed:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Campos de atualização inválidos")
        assignments = ", ".join(f"{key} = ?" for key in changes)
        db.execute(f"UPDATE appointments SET {assignments} WHERE id = ?", (*changes.values(), appointment_id))
        updated = db.execute("SELECT * FROM appointments WHERE id = ?", (appointment_id,)).fetchone()
    return {"success": True, "data": dict(updated)}
