"""Development-only Agent Studio API simulator for the G1 companion.

Run from the repository root:

    python -m venv .venv
    .venv/bin/pip install -r tool/requirements.txt
    AGENT_STUDIO_DEV_TOKEN=local-dev-token \
      .venv/bin/uvicorn tool.mock_agent_studio_server:app --host 0.0.0.0 --port 8765

On Windows PowerShell:

    py -m venv .venv
    .\.venv\Scripts\pip.exe install -r tool\requirements.txt
    $env:AGENT_STUDIO_DEV_TOKEN = "local-dev-token"
    .\.venv\Scripts\uvicorn.exe tool.mock_agent_studio_server:app --host 0.0.0.0 --port 8765

This server is not a production security boundary. It exists only to validate the
mobile request, response, idempotency, and event-replay contract.
"""

from __future__ import annotations

import asyncio
import os
import time
import uuid
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from dataclasses import dataclass, field
from typing import Any

from fastapi import BackgroundTasks, FastAPI, Header, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel, ConfigDict, Field

DEV_TOKEN = os.environ.get("AGENT_STUDIO_DEV_TOKEN", "local-dev-token")


class InputMessage(BaseModel):
    model_config = ConfigDict(extra="allow")

    type: str = "text"
    text: str = Field(min_length=1, max_length=20_000)


class RoutingRequest(BaseModel):
    model_config = ConfigDict(extra="allow")

    mode: str = "auto"
    allow_new_thread: bool = True
    project_id: str | None = None
    thread_id: str | None = None


class ClientDescriptor(BaseModel):
    model_config = ConfigDict(extra="allow")

    device_id: str
    device_type: str = "even_g1_companion"
    capabilities: list[str] = Field(default_factory=list)


class MessageRequest(BaseModel):
    model_config = ConfigDict(extra="allow")

    request_id: str
    source: str = "even_g1"
    input: InputMessage
    routing: RoutingRequest = Field(default_factory=RoutingRequest)
    client: ClientDescriptor
    response: dict[str, Any] = Field(default_factory=dict)


@dataclass(slots=True)
class EventStore:
    events: list[dict[str, Any]] = field(default_factory=list)
    sequence: int = 0
    condition: asyncio.Condition = field(default_factory=asyncio.Condition)

    async def append(
        self,
        event_type: str,
        *,
        payload: dict[str, Any],
        project_id: str | None = None,
        thread_id: str | None = None,
        task_id: str | None = None,
    ) -> dict[str, Any]:
        async with self.condition:
            self.sequence += 1
            event = {
                "event_id": str(uuid.uuid4()),
                "sequence": self.sequence,
                "type": event_type,
                "project_id": project_id,
                "thread_id": thread_id,
                "task_id": task_id,
                "created_at_unix": time.time(),
                "payload": payload,
            }
            self.events.append(event)
            self.events = self.events[-1_000:]
            self.condition.notify_all()
            return event

    async def stream_after(self, sequence: int) -> AsyncIterator[dict[str, Any]]:
        cursor = sequence
        while True:
            pending = [event for event in self.events if event["sequence"] > cursor]
            if pending:
                for event in pending:
                    cursor = event["sequence"]
                    yield event
                continue

            async with self.condition:
                await self.condition.wait()


EVENTS = EventStore()
IDEMPOTENT_RESPONSES: dict[str, dict[str, Any]] = {}


@asynccontextmanager
async def lifespan(_: FastAPI):
    yield


app = FastAPI(
    title="Agent Studio G1 Mock Gateway",
    version="0.1.0",
    lifespan=lifespan,
)


def require_bearer(authorization: str | None) -> None:
    if authorization != f"Bearer {DEV_TOKEN}":
        raise HTTPException(status_code=401, detail="Invalid paired-device token")


@app.get("/api/v1/health")
async def health() -> dict[str, str]:
    return {
        "status": "ok",
        "service": "agent-studio-g1-mock",
        "version": "0.1.0",
    }


@app.post("/api/v1/messages")
async def create_message(
    request: MessageRequest,
    background_tasks: BackgroundTasks,
    authorization: str | None = Header(default=None),
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
) -> dict[str, Any]:
    require_bearer(authorization)

    key = idempotency_key or request.request_id
    existing = IDEMPOTENT_RESPONSES.get(key)
    if existing is not None:
        return existing

    thread_id = request.routing.thread_id or f"thread-{uuid.uuid4()}"
    project_id = request.routing.project_id or "agent-studio-inbox"
    task_id = f"task-{uuid.uuid4()}"

    response = {
        "request_id": request.request_id,
        "thread_id": thread_id,
        "message_id": f"message-{uuid.uuid4()}",
        "reply": {
            "display_text": (
                "Agent Studio received your request. "
                "A background verification task is now running."
            ),
            "spoken_text": (
                "Agent Studio received your request and started a background "
                "verification task. I will report back when it finishes."
            ),
        },
        "task": {
            "id": task_id,
            "status": "queued",
            "summary": f"Mock task for: {request.input.text[:120]}",
        },
    }
    IDEMPOTENT_RESPONSES[key] = response

    await EVENTS.append(
        "task.queued",
        payload={"summary": response["task"]["summary"]},
        project_id=project_id,
        thread_id=thread_id,
        task_id=task_id,
    )
    background_tasks.add_task(
        complete_mock_task,
        project_id,
        thread_id,
        task_id,
        request.input.text,
    )
    return response


async def complete_mock_task(
    project_id: str,
    thread_id: str,
    task_id: str,
    prompt: str,
) -> None:
    await asyncio.sleep(3)
    await EVENTS.append(
        "task.completed",
        payload={
            "title": "Mock task completed",
            "summary": f"Verified the G1 event path for: {prompt[:180]}",
        },
        project_id=project_id,
        thread_id=thread_id,
        task_id=task_id,
    )


@app.websocket("/api/v1/events")
async def events(websocket: WebSocket) -> None:
    authorization = websocket.headers.get("authorization")
    if authorization != f"Bearer {DEV_TOKEN}":
        await websocket.close(code=4401, reason="Invalid paired-device token")
        return

    try:
        after = int(websocket.query_params.get("after", "0"))
    except ValueError:
        await websocket.close(code=4400, reason="Invalid event sequence")
        return

    await websocket.accept()
    try:
        async for event in EVENTS.stream_after(after):
            await websocket.send_json(event)
    except WebSocketDisconnect:
        return
