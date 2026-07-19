"""Mock GM: canned Caine-flavored replies, no LLM calls.

Exists so the whole pipeline (engine -> events -> sidecar -> narration -> screen)
can be built and tested before any real model is wired in (M0 exit criterion).
Replaced by the real Director at M2+; keep the same interface.
"""

from __future__ import annotations

from itertools import cycle
from typing import Iterator

from protocol import Event

_LINES: dict[str, list[str]] = {
    "session_started": [
        "А! Наконец-то. Я уж думал, вы никогда не запуститесь.",
    ],
    "player_moved": [
        "Шаг. Ещё шаг. Захватывающе.",
        "Вы ходите. Я наблюдаю. У всех свои роли.",
        "Топ-топ-топ. Обожаю этот звук.",
    ],
    "player_interacted": [
        "Ага! Вы решили ЭТО потрогать. Смело.",
        "Хм-м. Интересный выбор. Запишу.",
    ],
    "fell_into_pit": [
        "Ах да. Яма. Я всё ждал, когда вы её найдёте.",
    ],
    "picked_up": [
        "О, вы это подобрали. Пригодится. Наверное.",
    ],
    "unscrewed_table": [
        "Вы разобрали стол отвёрткой. Изящно. Путь открыт.",
    ],
    "player_died": [
        "И... вы умерли. Ну что ж. Бывает. С кем не бывает.",
    ],
    "level_complete": [
        "Вы добрались до выхода. Не скажу, что верил в вас. Но — браво.",
    ],
}

class MockGM:
    """Cycles through canned lines per event name; thin stand-in for the Director."""

    def __init__(self) -> None:
        self._iters: dict[str, Iterator[str]] = {}

    def react(self, event: Event) -> str | None:
        """Return a narration line for the event, or None to stay silent.

        The GM is silent by default (ADR-0011): it speaks ONLY on events it has
        explicit lines for. Events like bumped_wall / stun_tick / climbed_out_of_pit
        have no lines and produce no narration — no catch-all fallback, or the mock
        would comment on every twitch. player_moved is throttled to every 5th step.
        """
        lines = _LINES.get(event.name)
        if lines is None:
            return None
        if event.name == "player_moved" and event.turn % 5 != 0:
            return None
        if event.name not in self._iters:
            self._iters[event.name] = cycle(lines)
        return next(self._iters[event.name])
