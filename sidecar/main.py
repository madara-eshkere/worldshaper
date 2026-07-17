"""AI sidecar entry point: localhost WebSocket server the game talks to.

Run: python main.py [--port 8974]
The game launches this process itself and shuts it down on exit (M0 task 5).
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import os
import sys
from pathlib import Path

import websockets
from websockets.asyncio.server import ServerConnection, serve

from mock_gm import MockGM
from protocol import Event, narration_message, parse_message, ready_message

DEFAULT_PORT = 8974
log = logging.getLogger("sidecar")

# Set when the game disconnects, so the sidecar exits instead of lingering.
# The game owns exactly one sidecar and spawns it at boot; a closed connection
# means the game is gone (normal exit or crash), so there is nothing left to
# serve. This prevents orphaned sidecar processes after a game crash.
_game_gone = asyncio.Event()


def _log_dir() -> Path:
    """Where to write the sidecar log. Next to the executable when frozen
    (PyInstaller), otherwise next to this source file."""
    if getattr(sys, "frozen", False):
        return Path(sys.executable).parent
    return Path(__file__).parent


async def handle_connection(ws: ServerConnection) -> None:
    gm = MockGM()
    log.info("game connected")
    try:
        await _serve_events(ws, gm)
    except websockets.exceptions.ConnectionClosed:
        # Normal when the game exits — not an error worth a traceback.
        pass
    log.info("game disconnected")
    _game_gone.set()


async def _serve_events(ws: ServerConnection, gm: MockGM) -> None:
    async for raw in ws:
        try:
            msg = parse_message(raw)
        except ValueError as exc:
            log.warning("dropping malformed message: %s", exc)
            continue
        match msg["type"]:
            case "hello":
                log.info("hello from game v%s", msg.get("game_version"))
                await ws.send(ready_message())
            case "event":
                event = Event.from_message(msg)
                log.info("event: %s (turn %d)", event.name, event.turn)
                line = gm.react(event)
                if line is not None:
                    await ws.send(narration_message(line, ref_turn=event.turn))
                    log.info("narration sent for '%s'", event.name)
            case other:
                log.warning("unknown message type: %s", other)


async def run(port: int) -> None:
    async with serve(handle_connection, "127.0.0.1", port):
        log.info("sidecar listening on ws://127.0.0.1:%d", port)
        await _game_gone.wait()  # exit once the game disconnects
    log.info("sidecar shutting down")


def main() -> int:
    parser = argparse.ArgumentParser(description="AI GM sidecar")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    args = parser.parse_args()
    handlers: list[logging.Handler] = [logging.StreamHandler()]
    try:
        handlers.append(logging.FileHandler(_log_dir() / "sidecar.log", mode="w", encoding="utf-8"))
    except OSError:
        pass  # read-only install dir: stdout logging still works
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
        handlers=handlers,
    )
    log.info("websockets %s, python %s", websockets.__version__, sys.version.split()[0])
    try:
        asyncio.run(run(args.port))
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
