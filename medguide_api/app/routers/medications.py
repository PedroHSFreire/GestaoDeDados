import json
import sqlite3
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

from app.database import transaction
from app.schemas import MedicationCreate, MedicationUpdate
from app.security import new_id, require_role

router = APIRouter(prefix="/api/medications", tags=["Medicamentos"])


def _public(row: sqlite3.Row) -> dict:
    return {
        "id": row["id"],
        "name": row["name"],
        "dosage": row["dosage"],
        "times": json.loads(row["times_json"]),
        "active": bool(row["active"]),
        "timezone": row["timezone"],
        "createdAt": row["created_at"],
        "updatedAt": row["updated_at"],
    }


@router.get("")
def list_medications(user: Annotated[dict, Depends(require_role("patient"))]):
    with transaction() as db:
        rows = db.execute(
            "SELECT * FROM medications WHERE owner_id = ? ORDER BY created_at DESC",
            (user["id"],),
        ).fetchall()
    return {"success": True, "data": [_public(row) for row in rows]}


@router.post("", status_code=status.HTTP_201_CREATED)
def create_medication(
    payload: MedicationCreate,
    user: Annotated[dict, Depends(require_role("patient"))],
):
    medication_id = new_id()
    now = datetime.now(UTC).isoformat()
    with transaction() as db:
        db.execute(
            """INSERT INTO medications
               (id, owner_id, name, dosage, times_json, active, timezone, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                medication_id, user["id"], payload.name.strip(), payload.dosage,
                json.dumps(payload.times), int(payload.active), payload.timezone, now, now,
            ),
        )
        row = db.execute("SELECT * FROM medications WHERE id = ?", (medication_id,)).fetchone()
    return {"success": True, "data": _public(row)}


@router.put("/{medication_id}")
def update_medication(
    medication_id: str,
    payload: MedicationUpdate,
    user: Annotated[dict, Depends(require_role("patient"))],
):
    changes = payload.model_dump(exclude_unset=True)
    if not changes:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Nenhuma alteração informada")
    with transaction() as db:
        row = db.execute(
            "SELECT * FROM medications WHERE id = ? AND owner_id = ?",
            (medication_id, user["id"]),
        ).fetchone()
        if row is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Medicamento não encontrado")
        values: dict[str, object] = {}
        for key, value in changes.items():
            if key == "times":
                values["times_json"] = json.dumps(value)
            elif key == "active":
                values[key] = int(value)
            elif isinstance(value, str):
                values[key] = value.strip() or None
            else:
                values[key] = value
        values["updated_at"] = datetime.now(UTC).isoformat()
        assignments = ", ".join(f"{key} = ?" for key in values)
        db.execute(
            f"UPDATE medications SET {assignments} WHERE id = ? AND owner_id = ?",
            (*values.values(), medication_id, user["id"]),
        )
        updated = db.execute("SELECT * FROM medications WHERE id = ?", (medication_id,)).fetchone()
    return {"success": True, "data": _public(updated)}


@router.delete("/{medication_id}")
def delete_medication(
    medication_id: str,
    user: Annotated[dict, Depends(require_role("patient"))],
):
    with transaction() as db:
        result = db.execute(
            "DELETE FROM medications WHERE id = ? AND owner_id = ?",
            (medication_id, user["id"]),
        )
        if result.rowcount == 0:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Medicamento não encontrado")
    return {"success": True, "message": "Medicamento removido"}
