"""AI sidecar entry point: localhost WebSocket server the game talks to.

Run: python main.py [--port 8974]
The game launches this process itself and shuts it down on exit (M0 task 5).
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import sys

import websockets
from websockets.asyncio.server import ServerConnection, serve

from mock_gm import MockGM
from protocol import Event, narration_message, parse_message, ready_message

DEFAULT_PORT = 8974
log = logging.getLogger("sidecar")


async def handle_connection(ws: ServerConnection) -> None:
    gm = MockGM()
    log.info("game connected")
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
                line = gm.react(event)
                if line is not None:
                    await ws.send(narration_message(line, ref_turn=event.turn))
            case other:
                log.warning("unknown message type: %s", other)
    log.info("game disconnected")


async def run(port: int) -> None:
    async with serve(handle_connection, "127.0.0.1", port):
        log.info("sidecar listening on ws://127.0.0.1:%d", port)
        await asyncio.get_running_loop().create_future()  # run forever


def main() -> int:
    parser = argparse.ArgumentParser(description="AI GM sidecar")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    args = parser.parse_args()
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s"
    )
    log.info("websockets %s, python %s", websockets.__version__, sys.version.split()[0])
    try:
        asyncio.run(run(args.port))
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
