extends Node2D
## M0 skeleton scene: hardcoded room + player + narrator bar.
## Builds children in code to keep the .tscn trivial.

const WorldGridScript := preload("res://scripts/world_grid.gd")
const PlayerScript := preload("res://scripts/player.gd")
const NarratorUIScript := preload("res://scripts/narrator_ui.gd")


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

	var ui: CanvasLayer = NarratorUIScript.new()
	ui.name = "NarratorUI"
	add_child(ui)

	# Center the playfield in the window.
	var playfield: Vector2 = Vector2(grid.GRID_W, grid.GRID_H) * grid.CELL
	var viewport_size := Vector2(get_viewport_rect().size)
	grid.position = (viewport_size - playfield) * 0.5
