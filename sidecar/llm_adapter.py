"""LLM Adapter: the only door to any model (CONTEXT.md: Адаптер LLM, ADR-0003).

OpenAI-compatible chat-completions shape so any backend fits: OpenRouter,
Anthropic (via compat endpoint), local Ollama/LM Studio. The concrete model and
base URL are configuration, never architecture.

M0: interface + config only, no real calls (mock GM does not need them).
First real implementation lands at M2 (generation).
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Protocol


@dataclass
class LLMConfig:
    base_url: str = os.environ.get("WS_LLM_BASE_URL", "https://openrouter.ai/api/v1")
    api_key: str = os.environ.get("WS_LLM_API_KEY", "")
    model: str = os.environ.get("WS_LLM_MODEL", "")
    max_tokens: int = 1024
    temperature: float = 0.8
    extra_headers: dict[str, str] = field(default_factory=dict)


class ChatBackend(Protocol):
    """Minimal surface every backend must offer. Roles build on this only."""

    def complete(self, system: str, messages: list[dict[str, str]], config: LLMConfig) -> str:
        """Return assistant text for the given system prompt + chat messages."""
        ...


class NotConfiguredBackend:
    """Placeholder backend: raises loudly instead of silently failing."""

    def complete(self, system: str, messages: list[dict[str, str]], config: LLMConfig) -> str:
        raise RuntimeError(
            "LLM backend is not configured. Set WS_LLM_BASE_URL / WS_LLM_API_KEY / "
            "WS_LLM_MODEL or keep using the mock GM (M0/M1 do not need a model)."
        )
