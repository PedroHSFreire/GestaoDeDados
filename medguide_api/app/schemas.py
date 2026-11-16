from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class PatientRegister(BaseModel):
    name: str = Field(min_length=3, max_length=120)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class DoctorRegister(PatientRegister):
    crm: str = Field(min_length=3, max_length=30)
    specialty: str = Field(min_length=2, max_length=100)


class ProfileUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=3, max_length=120)
    email: EmailStr | None = None
    phone: str | None = Field(default=None, max_length=40)
    address: str | None = Field(default=None, max_length=250)
    crm: str | None = Field(default=None, min_length=3, max_length=30)
    specialty: str | None = Field(default=None, min_length=2, max_length=100)
    experience: str | None = Field(default=None, max_length=100)
    education: str | None = Field(default=None, max_length=250)
    bio: str | None = Field(default=None, max_length=1000)


class LoginRequest(BaseModel):
    login: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=1, max_length=128)


class UserPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    name: str
    email: str
    role: Literal["patient", "doctor"]
    crm: str | None = None
    specialty: str | None = None


class AuthResponse(BaseModel):
    success: bool = True
    data: dict


class AppointmentCreate(BaseModel):
    doctor_id: str
    date_time: datetime
    type: Literal["presencial", "online", "domiciliar", "urgente"] = "online"
    symptoms: str = Field(min_length=1, max_length=3000)
    notes: str | None = Field(default=None, max_length=3000)


class AppointmentUpdate(BaseModel):
    status: Literal["agendada", "confirmada", "cancelada", "realizada", "remarcada"] | None = None
    diagnosis: str | None = Field(default=None, max_length=3000)
    prescription: str | None = Field(default=None, max_length=3000)
    doctor_notes: str | None = Field(default=None, max_length=3000)


class MedicationCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    dosage: str | None = Field(default=None, max_length=120)
    times: list[str] = Field(min_length=1, max_length=12)
    active: bool = True
    timezone: str = Field(default="America/Sao_Paulo", max_length=80)

    @field_validator("times")
    @classmethod
    def validate_times(cls, values: list[str]) -> list[str]:
        import re

        if any(not re.fullmatch(r"(?:[01]\d|2[0-3]):[0-5]\d", value) for value in values):
            raise ValueError("Horários devem usar o formato HH:mm")
        return sorted(set(values))


class MedicationUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    dosage: str | None = Field(default=None, max_length=120)
    times: list[str] | None = Field(default=None, min_length=1, max_length=12)
    active: bool | None = None
    timezone: str | None = Field(default=None, max_length=80)

    @field_validator("times")
    @classmethod
    def validate_times(cls, values: list[str] | None) -> list[str] | None:
        import re

        if values is not None and any(not re.fullmatch(r"(?:[01]\d|2[0-3]):[0-5]\d", value) for value in values):
            raise ValueError("Horários devem usar o formato HH:mm")
        return sorted(set(values)) if values is not None else None


class ExamRequestCreate(BaseModel):
    patient_id: str
    exam_type: str = Field(min_length=2, max_length=120)
    description: str = Field(default="", max_length=1000)


class ExamRequestUpdate(BaseModel):
    status: Literal["concluido", "cancelado"]


class IngestionResult(BaseModel):
    success: bool
    decision: Literal["approved", "blocked", "review"]
    masked_text: str | None = None
    risk_score: float
    ocr_confidence: float
    findings: list[str]
    persisted_id: str | None = None
    message: str
