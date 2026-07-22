extends Node2D
## M1 scene bootstrap: builds the vanilla runtime (Primitives + Mechanic interpreter
## + Reflexes + interactions + win condition), the player view, and the UI, then
## hands level content to Level.build. Zero LLM.

const WorldGridScript := preload("res://scripts/world_grid.gd")
const PlayerScript := preload("res://scripts/player.gd")
const NarratorUIScript := preload("res://scripts/narrator_ui.gd")
const DebugHudScript := preload("res://scripts/debug_hud.gd")
const CharacterSheet := preload("res://scripts/character_sheet.gd")
const CharacterSheetUIScript := preload("res://scripts/character_sheet_ui.gd")
const PrimitivesScript := preload("res://scripts/primitives.gd")
const MechanicRunnerScript := preload("res://scripts/mechanic_runner.gd")
const TriggerSystemScript := preload("res://scripts/trigger_system.gd")
const TurnSchedulerScript := preload("res://scripts/turn_scheduler.gd")
const EntityRendererScript := preload("res://scripts/entity_renderer.gd")
const LibraryScript := preload("res://scripts/library.gd")
const InteractionSystemScript := preload("res://scripts/interaction_system.gd")
const WinConditionScript := preload("res://scripts/win_condition.gd")
const StatusHudScript := preload("res://scripts/status_hud.gd")
const GameOverUIScript := preload("res://scripts/game_over_ui.gd")
const Level := preload("res://scripts/level.gd")

var _prim  # kept alive for the session; player/runner/triggers all share this one


func _ready() -> void:
	Engine.max_fps = 60

	var grid: Node2D = WorldGridScript.new()
	grid.name = "WorldGrid"
	add_child(grid)

	# World State first: the player data object (stats + position live here).
	World.clear()
	CharacterSheet.create_default(Level.START)

	# Vanilla runtime: Primitives + interpreter + Reflexes + interactions + win.
	_prim = PrimitivesScript.new()
	var runner = MechanicRunnerScript.new(_prim)
	var library = LibraryScript.new()

	var triggers: Node = TriggerSystemScript.new()
	triggers.name = "TriggerSystem"
	add_child(triggers)
	triggers.setup(_prim, runner)

	var interactions: Node = InteractionSystemScript.new()
	interactions.name = "InteractionSystem"
	add_child(interactions)
	interactions.setup(_prim, runner, library)

	var win: Node = WinConditionScript.new()
	win.name = "WinCondition"
	add_child(win)
	win.setup(_prim)

	Level.build(_prim, triggers, library, interactions, win)

	# Time-based turn scheduler: every actor is independent; faster ones act more
	# often (ADR-0007). Started after the level is built.
	var scheduler: Node = TurnSchedulerScript.new()
	scheduler.name = "TurnScheduler"
	add_child(scheduler)
	scheduler.setup(_prim)

	# Entity view (enemies/items), under the player so the player draws on top.
	var entities: Node2D = EntityRendererScript.new()
	entities.name = "Entities"
	grid.add_child(entities)
	entities.setup(grid)

	# Player view node (reads its data from the World "player" object).
	var player: Node2D = PlayerScript.new()
	player.name = "Player"
	grid.add_child(player)
	player.setup(grid, _prim, scheduler)

	# Camera bound to the player: the map scrolls under a centered player (works at
	# any map size — bigger maps just scroll further).
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	player.add_child(cam)

	grid.reveal_from(Level.START)
	entities.queue_redraw()
	scheduler.start()

	var ui: CanvasLayer = NarratorUIScript.new()
	ui.name = "NarratorUI"
	add_child(ui)

	var hud: CanvasLayer = DebugHudScript.new()
	hud.name = "DebugHud"
	add_child(hud)

	var sheet_ui: CanvasLayer = CharacterSheetUIScript.new()
	sheet_ui.name = "CharacterSheetUI"
	add_child(sheet_ui)

	var status: CanvasLayer = StatusHudScript.new()
	status.name = "StatusHud"
	add_child(status)

	var game_over: CanvasLayer = GameOverUIScript.new()
	game_over.name = "GameOverUI"
	add_child(game_over)
