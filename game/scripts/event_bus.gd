extends Node
## Central pub/sub for semantic events (CONTEXT.md: Семантическое событие).
## The engine emits facts about the world here; SidecarClient forwards them.
## Never push raw frames/coords through this — only meaningful facts.

signal game_event(name: String, data: Dictionary)


func emit_game_event(event_name: String, data: Dictionary = {}) -> void:
	game_event.emit(event_name, data)
