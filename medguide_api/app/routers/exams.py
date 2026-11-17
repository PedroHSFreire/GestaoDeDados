import sqlite3
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

from app.database import transaction
from app.schemas import ExamRequestCreate, ExamRequestUpdate
from app.security import current_user, new_id

router = APIRouter(prefix="/api/exams", tags=["Solicitações de exames"])


@router.get("/mine", deprecated=True, include_in_schema=False)
@router.get("/me")
def list_my_exam_requests(user: Annotated[dict, Depends(current_user)]):
    if user["role"] == "patient":
        query = """SELECT e.*, d.name AS doctor_name FROM exam_requests e
                   JOIN users d ON d.id = e.doctor_id WHERE e.patient_id = ?
                   ORDER BY e.request_date DESC"""
    else:
        query = """SELECT e.*, p.name AS patient_name FROM exam_requests e
                   JOIN users p ON p.id = e.patient_id WHERE e.doctor_id = ?
                   ORDER BY e.request_date DESC"""
    with transaction() as db:
        rows = db.execute(query, (user["id"],)).fetchall()
    return {"success": True, "data": [dict(row) for row in rows]}


@router.post("", status_code=status.HTTP_201_CREATED)
def create_exam_request(payload: ExamRequestCreate, user: Annotated[dict, Depends(current_user)]):
    if user["role"] != "doctor":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Somente profissionais podem solicitar exames")
    with transaction() as db:
        relation = db.execute(
            """SELECT 1 FROM appointments
               WHERE doctor_id = ? AND patient_id = ? AND status IN ('confirmada', 'realizada')
               LIMIT 1""",
            (user["id"], payload.patient_id),
        ).fetchone()
        if relation is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Paciente sem consulta vinculada a este profissional")
        request_id = new_id()
        now = datetime.now(UTC).isoformat()
        db.execute(
            """INSERT INTO exam_requests (id, patient_id, doctor_id, exam_type, description, request_date, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (request_id, payload.patient_id, user["id"], payload.exam_type.strip(), payload.description.strip(), now, now),
        )
        row = db.execute("SELECT * FROM exam_requests WHERE id = ?", (request_id,)).fetchone()
    return {"success": True, "data": dict(row)}


@router.put("/{request_id}", deprecated=True, include_in_schema=False)
@router.patch("/{request_id}")
def update_exam_request(
    request_id: str,
    payload: ExamRequestUpdate,
    user: Annotated[dict, Depends(current_user)],
):
    with transaction() as db:
        row = db.execute("SELECT * FROM exam_requests WHERE id = ?", (request_id,)).fetchone()
        if row is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Solicitação não encontrada")
        if row["status"] != "pendente":
            raise HTTPException(status.HTTP_409_CONFLICT, "Solicitação já encerrada")
        if user["role"] == "patient":
            if row["patient_id"] != user["id"] or row["status"] != "pendente" or payload.status != "cancelado":
                raise HTTPException(status.HTTP_403_FORBIDDEN, "Ação não permitida para esta solicitação")
        elif row["doctor_id"] != user["id"] or payload.status not in {"concluido", "cancelado"}:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Ação não permitida para esta solicitação")
        db.execute(
            "UPDATE exam_requests SET status = ?, updated_at = ? WHERE id = ?",
            (payload.status, datetime.now(UTC).isoformat(), request_id),
        )
        updated = db.execute("SELECT * FROM exam_requests WHERE id = ?", (request_id,)).fetchone()
    return {"success": True, "data": dict(updated)}
