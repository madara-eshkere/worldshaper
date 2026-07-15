# DnD Game — AI Game Master

**Repo:** https://github.com/madara-eshkere/worldshaper.git — "worldshaper" is a
prototype repo name only; the game's real title is undecided until M5. Don't build
naming on it.

Single-player DnD-style "quest room" game where an LLM is the game master: it
generates the scenario/map/NPCs, watches player actions as semantic events,
interprets intent on contextual interactions, and mutates the world at runtime
(spawns objects, draws SVG art, attaches runtime GDScript behaviors, narrates in
a Stanley Parable / TADC-Caine persona).

**The design doc is the source of truth: [docs/DESIGN.md](docs/DESIGN.md).**
Read it before making design-level decisions; update it when decisions change.

## Communication

- Always respond to the user in **Russian**. Code, comments, and commit messages in English.
- In-game GM narration and UI text: Russian.

## Stack (approved — do not change without asking)

- **Game:** Godot 4.4+ (stable), GDScript, 2D top-down. NOT YET INSTALLED (as of 2026-07-09).
- **AI sidecar:** Python 3.10 (`C:\WebDev\Soft\Python 310\python.exe`), Anthropic SDK.
  Godot ↔ sidecar over WebSocket: game sends semantic events, sidecar returns effect commands.
- **AI layers:** Observer (Haiku, filters event stream) → Director (GM persona, generates
  effects/SVG art/behaviors) → Validator (checks solvability & generated code before applying).
- **Art:** GM draws vector sketch-style assets as SVG, rendered at runtime via
  `Image.load_svg_from_string()`, cached to disk.
- Dynamic behaviors: runtime-compiled GDScript attached to entities, gated by the Validator.

## Layout (planned)

- `game/` — Godot project
- `sidecar/` — Python AI service (prompts, orchestration, WebSocket server)
- `docs/` — design docs

## Principles

- Latency is a feature: mask LLM thinking time as the narrator's dramatic pause.
- Never stream raw frames/coords to the LLM — only semantic events.
- The GM never edits the engine; it acts through the fixed effect API + sandboxed behaviors.
- Softlock is forbidden: the Validator must keep every level completable, no matter
  how "mischievous" the GM persona gets.
