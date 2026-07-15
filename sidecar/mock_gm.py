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
}

_FALLBACK = [
    "Занятно. Продолжайте.",
    "Я это видел. Я всё вижу.",
]


class MockGM:
    """Cycles through canned lines per event name; thin stand-in for the Director."""

    def __init__(self) -> None:
        self._iters: dict[str, Iterator[str]] = {}

    def react(self, event: Event) -> str | None:
        """Return a narration line for the event, or None to stay silent.

        Mimics the trigger discipline: the mock only 'speaks' on events it has
        lines for; player_moved replies are throttled to every 5th step so the
        pipeline demo doesn't spam.
        """
        if event.name == "player_moved" and event.turn % 5 != 0:
            return None
        lines = _LINES.get(event.name)
        key = event.name if lines else "__fallback__"
        if key not in self._iters:
            self._iters[key] = cycle(lines if lines else _FALLBACK)
        return next(self._iters[key])
