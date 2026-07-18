"""Smoke test: pretend to be the game, check the mock GM pipeline end-to-end.

Run: python test_smoke.py  (expects main.py already listening on the port)
Exit code 0 = pipeline works: hello->ready, events->narrations.
"""

from __future__ import annotations

import json
import sys

from websockets.sync.client import connect

PORT = 8974


def main() -> int:
    with connect(f"ws://127.0.0.1:{PORT}", open_timeout=5) as ws:
        ws.send(json.dumps({"type": "hello", "game_version": "0.0.1", "protocol_version": 0}))
        ready = json.loads(ws.recv(timeout=5))
        assert ready["type"] == "ready", f"expected ready, got {ready}"

        ws.send(json.dumps({"type": "event", "name": "session_started", "turn": 0, "data": {}}))
        greeting = json.loads(ws.recv(timeout=5))
        assert greeting["type"] == "narration" and greeting["text"], greeting

        # Moves are throttled to every 5th turn: turn 3 must be silent, turn 5 must speak.
        ws.send(json.dumps({"type": "event", "name": "player_moved", "turn": 3, "data": {}}))
        ws.send(json.dumps({"type": "event", "name": "player_moved", "turn": 5, "data": {}}))
        move_line = json.loads(ws.recv(timeout=5))
        assert move_line["type"] == "narration" and move_line["ref_turn"] == 5, move_line

        ws.send(json.dumps({"type": "event", "name": "fell_into_pit", "turn": 7, "data": {}}))
        pit = json.loads(ws.recv(timeout=5))
        assert "Яма" in pit["text"] or "яму" in pit["text"], pit

        # Regression: the GM is silent on events it has no line for (ADR-0011).
        # bumped_wall / stun_tick must produce NO narration — the old catch-all
        # fallback spammed a reply on every wall bump and every stun tick.
        ws.send(json.dumps({"type": "event", "name": "bumped_wall", "turn": 8, "data": {}}))
        ws.send(json.dumps({"type": "event", "name": "stun_tick", "turn": 9, "data": {}}))
        ws.send(json.dumps({"type": "event", "name": "player_interacted", "turn": 10, "data": {}}))
        # The only reply should be for player_interacted — proving the two before it
        # were silent (otherwise this recv would return a wall/stun fallback line).
        after_silence = json.loads(ws.recv(timeout=5))
        assert after_silence["type"] == "narration" and after_silence["ref_turn"] == 10, (
            f"expected only player_interacted to speak; got {after_silence}"
        )

        print("SMOKE OK")
        print("  greeting :", greeting["text"])
        print("  move@5   :", move_line["text"])
        print("  pit      :", pit["text"])
        print("  wall/stun: (silent, as expected)")
        print("  interact :", after_silence["text"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
