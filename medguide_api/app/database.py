import sqlite3
from contextlib import contextmanager
from typing import Iterator

from app.config import get_settings


SCHEMA = """
PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE COLLATE NOCASE,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('patient', 'doctor')),
    crm TEXT UNIQUE,
    specialty TEXT,
    phone TEXT,
    address TEXT,
    experience TEXT,
    education TEXT,
    bio TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS appointments (
    id TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL REFERENCES users(id),
    doctor_id TEXT NOT NULL REFERENCES users(id),
    date_time TEXT NOT NULL,
    appointment_type TEXT NOT NULL,
    symptoms TEXT NOT NULL,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'agendada',
    diagnosis TEXT,
    prescription TEXT,
    doctor_notes TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS medications (
    id TEXT PRIMARY KEY,
    owner_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    dosage TEXT,
    times_json TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1,
    timezone TEXT NOT NULL DEFAULT 'America/Sao_Paulo',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS exam_requests (
    id TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    doctor_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exam_type TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'pendente',
    request_date TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS protected_documents (
    id TEXT PRIMARY KEY,
    owner_id TEXT NOT NULL REFERENCES users(id),
    document_type TEXT NOT NULL,
    masked_text TEXT NOT NULL,
    risk_score REAL NOT NULL,
    ocr_confidence REAL NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
"""


def connect() -> sqlite3.Connection:
    settings = get_settings()
    settings.database_file.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(settings.database_file, timeout=10)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    return connection


@contextmanager
def transaction() -> Iterator[sqlite3.Connection]:
    connection = connect()
    try:
        yield connection
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


def initialize_database() -> None:
    with transaction() as connection:
        connection.executescript(SCHEMA)
        # Additive migration keeps user accounts created by earlier prototype versions.
        existing = {row["name"] for row in connection.execute("PRAGMA table_info(users)")}
        for column, sql_type in {
            "phone": "TEXT",
            "address": "TEXT",
            "experience": "TEXT",
            "education": "TEXT",
            "bio": "TEXT",
        }.items():
            if column not in existing:
                connection.execute(f"ALTER TABLE users ADD COLUMN {column} {sql_type}")
        appointment_columns = {row["name"] for row in connection.execute("PRAGMA table_info(appointments)")}
        if "notes" not in appointment_columns:
            connection.execute("ALTER TABLE appointments ADD COLUMN notes TEXT")
