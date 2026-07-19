extends Node2D
## M1 scene bootstrap: hardcoded room + vanilla runtime (Primitives + Mechanic
## interpreter + Reflexes) + player view + UI. Wires the pit as a Scripted Trigger
## instead of hardcoding it in the player (ADR-0014). Zero LLM.

const WorldGridScript := preload("res://scripts/world_grid.gd")
const PlayerScript := preload("res://scripts/player.gd")
const NarratorUIScript := preload("res://scripts/narrator_ui.gd")
const DebugHudScript := preload("res://scripts/debug_hud.gd")
const CharacterSheet := preload("res://scripts/character_sheet.gd")
const CharacterSheetUIScript := preload("res://scripts/character_sheet_ui.gd")
const PrimitivesScript := preload("res://scripts/primitives.gd")
const MechanicRunnerScript := preload("res://scripts/mechanic_runner.gd")
const TriggerSystemScript := preload("res://scripts/trigger_system.gd")

const START_CELL := Vector2i(2, 2)

var _prim  # kept alive for the session; player/runner/triggers all share this one


func _ready() -> void:
	# Cap FPS: a turn-based 2D game has no business burning the GPU, and it
	# keeps headless test runs on real wall-clock time.
	Engine.max_fps = 60

	var grid: Node2D = WorldGridScript.new()
	grid.name = "WorldGrid"
	add_child(grid)

	# World State first: the player data object (stats + position live here).
	World.clear()
	CharacterSheet.create_default(START_CELL)

	# Vanilla runtime: Primitives (the alphabet) + the trusted Mechanic interpreter
	# + Reflexes (Scripted Triggers / Escalations). All data-driven, no LLM.
	_prim = PrimitivesScript.new(grid)
	var runner = MechanicRunnerScript.new(_prim)
	var triggers: Node = TriggerSystemScript.new()
	triggers.name = "TriggerSystem"
	add_child(triggers)
	triggers.setup(_prim, runner)
	_install_pit(triggers, grid.PIT_CELL)

	# Player view node (reads its data from the World "player" object).
	var player: Node2D = PlayerScript.new()
	player.name = "Player"
	grid.add_child(player)
	player.setup(grid, _prim)

	var ui: CanvasLayer = NarratorUIScript.new()
	ui.name = "NarratorUI"
	add_child(ui)

	var hud: CanvasLayer = DebugHudScript.new()
	hud.name = "DebugHud"
	add_child(hud)

	var sheet_ui: CanvasLayer = CharacterSheetUIScript.new()
	sheet_ui.name = "CharacterSheetUI"
	add_child(sheet_ui)

	# Center the playfield in the window.
	var playfield: Vector2 = Vector2(grid.GRID_W, grid.GRID_H) * grid.CELL
	var viewport_size := Vector2(get_viewport_rect().size)
	grid.position = (viewport_size - playfield) * 0.5


## The pit as data (M1 hardcoded; M2 has the Director generate such triggers).
func _install_pit(triggers: Node, pit_cell: Vector2i) -> void:
	_prim.spawn("pit", pit_cell, {}, ["pit"])
	var pit_fall := {"id": "pit_fall", "steps": [
		{"prim": "set_prop", "args": ["$actor", "stunned_turns", 2]},
		{"prim": "set_prop", "args": ["$actor", "in_pit", true]},
		{"prim": "emit", "args": ["fell_into_pit", {"stun_turns": 2}]},
	]}
	triggers.register_trigger({
		"on": "player_moved",
		"if": {"cell_has_tag": "pit"},
		"mechanic": pit_fall,
	})
	# Escalation stub: falling into pits repeatedly would wake the GM at M4.
	triggers.register_escalation({
		"id": "pit_frustration", "watch": "fell_into_pit", "threshold": 3,
		"emit": "pit_escalation",
	})
