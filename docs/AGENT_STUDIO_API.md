# Agent Studio G1 API Contract

This document defines the minimum backend contract expected by the Even G1 companion application.

## Authentication

Every request uses a device-scoped bearer token:

```http
Authorization: Bearer <paired-device-token>
X-Agent-Studio-Device: <device-uuid>
```

The token should be limited to the following capabilities:

- Submit a user message.
- Read events authorized for the paired user and device.
- Read basic health status.
- Read concise task and approval summaries.

The G1 client should not receive shell, credential-export, administrative, billing, or unrestricted approval authority.

## Health

### `GET /api/v1/health`

Successful response:

```json
{
  "status": "ok",
  "service": "agent-studio",
  "version": "0.1.0"
}
```

Any 2xx response is treated as healthy by the current client.

## Submit a message

### `POST /api/v1/messages`

Headers:

```http
Content-Type: application/json
Idempotency-Key: <request-uuid>
```

Request:

```json
{
  "request_id": "a5a8148f-c3c2-4c47-a6f7-e1f37fc7e747",
  "source": "even_g1",
  "input": {
    "type": "text",
    "text": "Check the game loop and tell me whether it is on schedule."
  },
  "routing": {
    "mode": "auto",
    "allow_new_thread": true,
    "project_id": "optional-default-project",
    "thread_id": "optional-explicit-thread"
  },
  "client": {
    "device_id": "paired-device-uuid",
    "device_type": "even_g1_companion",
    "capabilities": [
      "g1.microphone",
      "g1.display.text",
      "g1.touchbar"
    ]
  },
  "response": {
    "mode": "concise",
    "max_display_characters": 900
  }
}
```

Recommended response:

```json
{
  "request_id": "a5a8148f-c3c2-4c47-a6f7-e1f37fc7e747",
  "thread_id": "thread-01",
  "message_id": "message-01",
  "reply": {
    "display_text": "The game loop is active. I started a schedule audit in the background.",
    "spoken_text": "The game loop is active. I started a more detailed schedule audit in the background and will report back when it finishes."
  },
  "task": {
    "id": "task-01",
    "status": "queued",
    "summary": "Audit game loop schedule and artifacts"
  }
}
```

The parser also accepts a top-level `display_text`, `text`, or `content` value for compatibility.

## Event stream

### `GET /api/v1/events`

Upgrade this endpoint to a WebSocket connection.

Query parameters:

- `device_id`: Paired device UUID.
- `after`: Optional last processed event sequence for replay after reconnect.

Event envelope:

```json
{
  "event_id": "event-01",
  "sequence": 42,
  "type": "task.completed",
  "project_id": "project-01",
  "thread_id": "thread-01",
  "task_id": "task-01",
  "payload": {
    "title": "Game loop audit complete",
    "summary": "The loop is healthy and the latest artifact passed review."
  }
}
```

The client automatically reconnects with exponential backoff and includes its last processed sequence in `after`.

## Events displayed on the glasses

The current client treats these as glanceable:

- `approval.requested`
- `task.blocked`
- `task.completed`
- `task.failed`
- `run.failed`
- `agent.alert`
- `agent.message`

Preferred payload text fields, in order:

1. `display_text`
2. `summary`
3. `message`
4. `reason`
5. `error`

The client rate-limits G1 display updates and does not interrupt an active voice interaction.

## Idempotency

The backend must store or otherwise recognize the `Idempotency-Key`. Repeating the same request ID must not create a duplicate task or duplicate external action.

## Error behavior

Recommended HTTP codes:

- `400`: Invalid request.
- `401`: Invalid or expired device token.
- `403`: Device lacks the required scope.
- `404`: Endpoint or referenced resource does not exist.
- `409`: Idempotency or state conflict.
- `429`: Rate or budget limit.
- `500` or `503`: Temporary server failure.

Return machine-readable errors:

```json
{
  "error": {
    "code": "device_token_expired",
    "message": "Pair this device again."
  }
}
```

## Approval policy

The G1 receives informational approval events only. High-risk approval decisions should be completed on the authenticated phone or desktop interface with the exact proposed action, target, parameters, expiration, and one-time approval nonce visible to the user.
