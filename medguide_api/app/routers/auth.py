import sqlite3
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

from app.database import transaction
from app.schemas import DoctorRegister, LoginRequest, PatientRegister, ProfileUpdate
from app.security import create_access_token, current_user, hash_password, new_id, require_role, verify_password

router = APIRouter(tags=["Autenticação e perfis"])


def _public_user(row: sqlite3.Row) -> dict:
    return {
        key: row[key]
        for key in (
            "id", "name", "email", "role", "crm", "specialty", "phone",
            "address", "experience", "education", "bio",
        )
    }


def _register(payload: PatientRegister, role: str, crm: str | None = None, specialty: str | None = None):
    user_id = new_id()
    try:
        with transaction() as db:
            db.execute(
                "INSERT INTO users (id, name, email, password_hash, role, crm, specialty) VALUES (?, ?, ?, ?, ?, ?, ?)",
                (user_id, payload.name.strip(), payload.email.lower(), hash_password(payload.password), role, crm, specialty),
            )
            row = db.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    except sqlite3.IntegrityError:
        raise HTTPException(status.HTTP_409_CONFLICT, "E-mail ou CRM já cadastrado") from None
    return {"success": True, "data": {"user": _public_user(row)}}


@router.post("/api/pacient/register", status_code=status.HTTP_201_CREATED, deprecated=True, include_in_schema=False)
@router.post("/api/patients/register", status_code=status.HTTP_201_CREATED)
def register_patient(payload: PatientRegister):
    return _register(payload, "patient")


@router.post("/api/doctor/register", status_code=status.HTTP_201_CREATED, deprecated=True, include_in_schema=False)
@router.post("/api/doctors/register", status_code=status.HTTP_201_CREATED)
def register_doctor(payload: DoctorRegister):
    return _register(payload, "doctor", payload.crm.strip(), payload.specialty.strip())


def _login(payload: LoginRequest, role: str):
    with transaction() as db:
        row = db.execute(
            "SELECT * FROM users WHERE lower(email) = lower(?) AND role = ?",
            (payload.login.strip(), role),
        ).fetchone()
    if row is None or not verify_password(payload.password, row["password_hash"]):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Credenciais inválidas")
    return {
        "success": True,
        "data": {"token": create_access_token(row["id"], role), "user": _public_user(row)},
    }


@router.post("/api/pacient/login", deprecated=True, include_in_schema=False)
@router.post("/api/patients/login")
def login_patient(payload: LoginRequest):
    return _login(payload, "patient")


@router.post("/api/doctor/login", deprecated=True, include_in_schema=False)
@router.post("/api/doctors/login")
def login_doctor(payload: LoginRequest):
    return _login(payload, "doctor")


@router.get("/api/pacient/profile", deprecated=True, include_in_schema=False)
@router.get("/api/patients/me")
def patient_profile(user: Annotated[dict, Depends(require_role("patient"))]):
    return _profile(user["id"])


@router.put("/api/pacient/profile", deprecated=True, include_in_schema=False)
@router.put("/api/patients/me", deprecated=True, include_in_schema=False)
@router.patch("/api/patients/me")
def update_patient_profile(
    payload: ProfileUpdate,
    user: Annotated[dict, Depends(require_role("patient"))],
):
    return _update_profile(user["id"], payload, allowed={"name", "email", "phone", "address"})


@router.get("/api/doctor/profile", deprecated=True, include_in_schema=False)
@router.get("/api/doctors/me")
def doctor_profile(user: Annotated[dict, Depends(require_role("doctor"))]):
    return _profile(user["id"])


@router.put("/api/doctor/profile", deprecated=True, include_in_schema=False)
@router.put("/api/doctors/me", deprecated=True, include_in_schema=False)
@router.patch("/api/doctors/me")
def update_doctor_profile(
    payload: ProfileUpdate,
    user: Annotated[dict, Depends(require_role("doctor"))],
):
    return _update_profile(
        user["id"], payload,
        allowed={"name", "email", "phone", "address", "crm", "specialty", "experience", "education", "bio"},
    )


def _update_profile(user_id: str, payload: ProfileUpdate, allowed: set[str]):
    changes = payload.model_dump(exclude_unset=True)
    if not changes:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Informe ao menos um campo para atualizar")
    if not changes.keys() <= allowed:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Campo não permitido para este perfil")
    if "name" in changes and changes["name"] is not None:
        changes["name"] = changes["name"].strip()
    if "email" in changes and changes["email"] is not None:
        changes["email"] = str(changes["email"]).lower()
    for field in ("phone", "address", "crm", "specialty", "experience", "education", "bio"):
        if field in changes and isinstance(changes[field], str):
            changes[field] = changes[field].strip() or None
    assignments = ", ".join(f"{field} = ?" for field in changes)
    try:
        with transaction() as db:
            db.execute(f"UPDATE users SET {assignments} WHERE id = ?", (*changes.values(), user_id))
            row = db.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    except sqlite3.IntegrityError:
        raise HTTPException(status.HTTP_409_CONFLICT, "E-mail ou CRM já cadastrado") from None
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Perfil não encontrado")
    return {"success": True, "data": _public_user(row)}


def _profile(user_id: str):
    with transaction() as db:
        row = db.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Perfil não encontrado")
    return {"success": True, "data": _public_user(row)}


@router.get("/api/doctor/search", deprecated=True, include_in_schema=False)
@router.get("/api/doctors/search")
def search_doctors(
    user: Annotated[dict, Depends(current_user)],
    search: str = "",
    specialty: str = "",
):
    del user
    query = "SELECT id, name, role, crm, specialty, address FROM users WHERE role = 'doctor'"
    params: list[str] = []
    if search.strip():
        query += " AND name LIKE ?"
        params.append(f"%{search.strip()}%")
    if specialty.strip():
        query += " AND lower(specialty) = lower(?)"
        params.append(specialty.strip())
    with transaction() as db:
        rows = db.execute(query + " ORDER BY name", params).fetchall()
    return {"success": True, "data": [dict(row) for row in rows]}


@router.get("/api/doctor/specialties", deprecated=True, include_in_schema=False)
@router.get("/api/doctors/specialties")
def list_specialties(user: Annotated[dict, Depends(current_user)]):
    del user
    with transaction() as db:
        rows = db.execute(
            "SELECT DISTINCT specialty FROM users WHERE role = 'doctor' AND specialty IS NOT NULL ORDER BY specialty"
        ).fetchall()
    return {"success": True, "data": [row["specialty"] for row in rows]}
