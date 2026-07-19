extends Node2D
## M0 skeleton scene: hardcoded room + player + narrator bar.
## Builds children in code to keep the .tscn trivial.

const WorldGridScript := preload("res://scripts/world_grid.gd")
const PlayerScript := preload("res://scripts/player.gd")
const NarratorUIScript := preload("res://scripts/narrator_ui.gd")
const DebugHudScript := preload("res://scripts/debug_hud.gd")
const CharacterSheet := preload("res://scripts/character_sheet.gd")
const CharacterSheetUIScript := preload("res://scripts/character_sheet_ui.gd")


func _ready() -> void:
	# Cap FPS: a turn-based 2D game has no business burning the GPU, and it
	# keeps headless test runs on real wall-clock time.
	Engine.max_fps = 60

	var grid: Node2D = WorldGridScript.new()
	grid.name = "WorldGrid"
	add_child(grid)

	# Player lives inside the grid so every position is grid-local.
	var player: Node2D = PlayerScript.new()
	player.name = "Player"
	grid.add_child(player)
	player.setup(grid)

	# Create the World "player" data object (stats live here — ADR-0013). The
	# movement node above stays a separate view for now; #5 unifies them.
	World.clear()
	CharacterSheet.create_default(player.cell)

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
