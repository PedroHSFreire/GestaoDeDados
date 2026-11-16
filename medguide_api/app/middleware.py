from starlette.types import ASGIApp, Message, Receive, Scope, Send


class InMemoryUploadLimitMiddleware:
    """Bound and buffer document request bodies in RAM before FastAPI parses them."""

    def __init__(self, app: ASGIApp, max_bytes: int) -> None:
        self.app = app
        self.max_bytes = max_bytes

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http" or scope.get("path") != "/api/privacy/ingest":
            await self.app(scope, receive, send)
            return
        headers = {key.lower(): value for key, value in scope.get("headers", [])}
        content_length = headers.get(b"content-length")
        if content_length:
            try:
                if int(content_length) > self.max_bytes:
                    await self._too_large(send)
                    return
            except ValueError:
                await self._too_large(send)
                return

        buffered = bytearray()
        more = True
        while more:
            message = await receive()
            buffered.extend(message.get("body", b""))
            if len(buffered) > self.max_bytes:
                await self._too_large(send)
                return
            more = message.get("more_body", False)

        body = bytes(buffered)
        delivered = False

        async def replay() -> Message:
            nonlocal delivered
            if delivered:
                return {"type": "http.request", "body": b"", "more_body": False}
            delivered = True
            return {"type": "http.request", "body": body, "more_body": False}

        await self.app(scope, replay, send)

    async def _too_large(self, send: Send) -> None:
        body = b'{"detail":"Arquivo excede o limite de tamanho configurado"}'
        await send({"type": "http.response.start", "status": 413, "headers": [(b"content-type", b"application/json")]})
        await send({"type": "http.response.body", "body": body})
