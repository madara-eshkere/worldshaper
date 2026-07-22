extends Node2D
## Renderer/view for the tile map + fog of war. Reads terrain from World State
## (ADR-0013) — it holds NO level data of its own; the map is authored by the level
## (M2: the Director). Placeholder flat visuals; the GM's SVG art arrives at M3.

const FogOfWar = preload("res://scripts/fog_of_war.gd")

const CELL := 48
const COLOR_FLOOR_A := Color(0.16, 0.15, 0.19)
const COLOR_FLOOR_B := Color(0.18, 0.17, 0.21)
const COLOR_WALL := Color(0.32, 0.28, 0.38)
const COLOR_UNSEEN := Color(0.02, 0.02, 0.03)
const SEEN_DARKEN := 0.45

var _fog: FogOfWar


func _ready() -> void:
	_rebuild_fog()
	EventBus.game_event.connect(_on_event)
	World.map_changed.connect(_rebuild_fog)


func _rebuild_fog() -> void:
	_fog = FogOfWar.new(World.map_w, World.map_h, World.is_wall)
	queue_redraw()


func _on_event(name: String, data: Dictionary) -> void:
	if name == "player_moved":
		reveal_from(Vector2i(int(data.get("cell_x", 0)), int(data.get("cell_y", 0))))


## Recompute the fog from a cell and redraw. Called on move and at level start.
func reveal_from(cell: Vector2i) -> void:
	if _fog:
		_fog.recompute(cell)
		queue_redraw()


func fog_state_at(cell: Vector2i) -> int:
	return _fog.state_at(cell) if _fog else FogOfWar.VISIBLE


func is_cell_visible(cell: Vector2i) -> bool:
	return fog_state_at(cell) == FogOfWar.VISIBLE


func cell_to_px(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL + Vector2(CELL, CELL) * 0.5


func _draw() -> void:
	for y in World.map_h:
		for x in World.map_w:
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL))
			var st := _fog.state_at(cell) if _fog else FogOfWar.VISIBLE
			if st == FogOfWar.HIDDEN:
				draw_rect(rect, COLOR_UNSEEN)  # unexplored — keep secrets secret
				continue
			var base: Color
			if World.is_wall(cell):
				base = COLOR_WALL
			else:
				base = COLOR_FLOOR_A if (x + y) % 2 == 0 else COLOR_FLOOR_B
			if st == FogOfWar.SEEN:
				base = base.darkened(SEEN_DARKEN)  # remembered but out of sight
			draw_rect(rect, base)
