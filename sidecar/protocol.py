"""Wire protocol between the game (Godot) and the AI sidecar.

Transport: JSON messages over a localhost WebSocket, one JSON object per message.

Game -> sidecar:
    {"type": "hello", "game_version": str, "protocol_version": int}
    {"type": "event", "name": str, "turn": int, "data": dict}

Sidecar -> game:
    {"type": "ready", "sidecar_version": str, "protocol_version": int}
    {"type": "narration", "text": str, "ref_turn": int | None}

Design notes:
- Narration is a garnish and never blocks the turn loop (DESIGN.md 4.4);
  the game renders it whenever it arrives.
- Intents/effects will be added at M2+; keep this file the single source of
  truth for message shapes on the Python side.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

PROTOCOL_VERSION = 0
SIDECAR_VERSION = "0.1.0"


@dataclass
class Event:
    """Semantic event observed by the engine (CONTEXT.md: Семантическое событие)."""

    name: str
    turn: int
    data: dict[str, Any]

    @staticmethod
    def from_message(msg: dict[str, Any]) -> "Event":
        return Event(
            name=str(msg.get("name", "")),
            turn=int(msg.get("turn", -1)),
            data=dict(msg.get("data", {})),
        )


def parse_message(raw: str | bytes) -> dict[str, Any]:
    msg = json.loads(raw)
    if not isinstance(msg, dict) or "type" not in msg:
        raise ValueError(f"malformed message: {raw!r}")
    return msg


def ready_message() -> str:
    return json.dumps(
        {
            "type": "ready",
            "sidecar_version": SIDECAR_VERSION,
            "protocol_version": PROTOCOL_VERSION,
        }
    )


def narration_message(text: str, ref_turn: int | None = None) -> str:
    return json.dumps(
        {"type": "narration", "text": text, "ref_turn": ref_turn},
        ensure_ascii=False,
    )
