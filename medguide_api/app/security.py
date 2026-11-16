from datetime import UTC, datetime, timedelta
from typing import Annotated
from uuid import uuid4

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pwdlib import PasswordHash

from app.config import get_settings

password_hash = PasswordHash.recommended()
bearer = HTTPBearer(auto_error=False)


def hash_password(password: str) -> str:
    return password_hash.hash(password)


def verify_password(password: str, hashed: str) -> bool:
    return password_hash.verify(password, hashed)


def create_access_token(user_id: str, role: str) -> str:
    now = datetime.now(UTC)
    payload = {"sub": user_id, "role": role, "iat": now, "exp": now + timedelta(hours=12)}
    return jwt.encode(payload, get_settings().jwt_secret, algorithm="HS256")


def new_id() -> str:
    return str(uuid4())


def current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> dict[str, str]:
    if credentials is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Autenticação necessária")
    try:
        payload = jwt.decode(credentials.credentials, get_settings().jwt_secret, algorithms=["HS256"])
        user_id, role = payload.get("sub"), payload.get("role")
        if not user_id or role not in {"patient", "doctor"}:
            raise ValueError("token claims invalid")
        return {"id": user_id, "role": role}
    except (jwt.InvalidTokenError, ValueError):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token inválido ou expirado") from None


def require_role(role: str):
    def dependency(user: Annotated[dict[str, str], Depends(current_user)]) -> dict[str, str]:
        if user["role"] != role:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Perfil sem permissão para esta operação")
        return user

    return dependency
