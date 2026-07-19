extends Node2D
## Hardcoded M1 room: tile grid with walls, one hidden pit, and fog of war.
## A view over engine state: reveals the pit on the pit Mechanic (ADR-0013) and
## recomputes sight from the player's cell each move. Placeholder flat visuals;
## the GM's SVG art pipeline arrives at M3.

const FogOfWar = preload("res://scripts/fog_of_war.gd")

const CELL := 48
const GRID_W := 16
const GRID_H := 10
const PIT_CELL := Vector2i(11, 4)

const COLOR_FLOOR_A := Color(0.16, 0.15, 0.19)
const COLOR_FLOOR_B := Color(0.18, 0.17, 0.21)
const COLOR_WALL := Color(0.32, 0.28, 0.38)
const COLOR_PIT := Color(0.05, 0.05, 0.07)
const COLOR_UNSEEN := Color(0.02, 0.02, 0.03)
const SEEN_DARKEN := 0.45

var pit_revealed := false
var _fog: FogOfWar


func _ready() -> void:
	_fog = FogOfWar.new(GRID_W, GRID_H, is_wall)
	EventBus.game_event.connect(_on_event)


func _on_event(name: String, data: Dictionary) -> void:
	match name:
		"player_moved":
			reveal_from(Vector2i(int(data.get("cell_x", 0)), int(data.get("cell_y", 0))))
		"fell_into_pit":
			reveal_pit()


## Recompute the fog from a cell and redraw. Called on move and at level start.
func reveal_from(cell: Vector2i) -> void:
	if _fog:
		_fog.recompute(cell)
		queue_redraw()


func fog_state_at(cell: Vector2i) -> int:
	return _fog.state_at(cell) if _fog else FogOfWar.VISIBLE


func is_cell_visible(cell: Vector2i) -> bool:
	return fog_state_at(cell) == FogOfWar.VISIBLE


const DIVIDER_X := 8
const DOORWAY_Y := 4


func is_wall(cell: Vector2i) -> bool:
	if cell.x <= 0 or cell.y <= 0 or cell.x >= GRID_W - 1 or cell.y >= GRID_H - 1:
		return true
	# Interior divider wall splitting the room, with one doorway (blocked by a table).
	if cell.x == DIVIDER_X and cell.y != DOORWAY_Y:
		return true
	return false


func is_walkable(cell: Vector2i) -> bool:
	return not is_wall(cell)


func cell_to_px(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL + Vector2(CELL, CELL) * 0.5


func reveal_pit() -> void:
	pit_revealed = true
	queue_redraw()


func _draw() -> void:
	for y in GRID_H:
		for x in GRID_W:
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL))
			var st := _fog.state_at(cell) if _fog else FogOfWar.VISIBLE
			if st == FogOfWar.HIDDEN:
				draw_rect(rect, COLOR_UNSEEN)  # unexplored — keep secrets secret
				continue
			var base: Color
			if is_wall(cell):
				base = COLOR_WALL
			else:
				base = COLOR_FLOOR_A if (x + y) % 2 == 0 else COLOR_FLOOR_B
			if st == FogOfWar.SEEN:
				base = base.darkened(SEEN_DARKEN)  # remembered but out of sight
			draw_rect(rect, base)
	# The pit is a hidden trap: shown only once triggered AND on explored ground.
	if pit_revealed and _fog and _fog.state_at(PIT_CELL) != FogOfWar.HIDDEN:
		draw_circle(cell_to_px(PIT_CELL), CELL * 0.38, COLOR_PIT)
