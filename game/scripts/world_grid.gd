extends Node2D
## Hardcoded M0 room: tile grid with walls and one hidden pit.
## Placeholder visuals (flat colors); the GM's SVG art pipeline arrives at M3.

const CELL := 48
const GRID_W := 16
const GRID_H := 10
const PIT_CELL := Vector2i(11, 4)

const COLOR_FLOOR_A := Color(0.16, 0.15, 0.19)
const COLOR_FLOOR_B := Color(0.18, 0.17, 0.21)
const COLOR_WALL := Color(0.32, 0.28, 0.38)
const COLOR_PIT := Color(0.05, 0.05, 0.07)

var pit_revealed := false


func is_wall(cell: Vector2i) -> bool:
	return cell.x <= 0 or cell.y <= 0 or cell.x >= GRID_W - 1 or cell.y >= GRID_H - 1


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
			if is_wall(cell):
				draw_rect(rect, COLOR_WALL)
			else:
				draw_rect(rect, COLOR_FLOOR_A if (x + y) % 2 == 0 else COLOR_FLOOR_B)
	# The pit is invisible until stepped into: it is a *hidden* trap.
	if pit_revealed:
		draw_circle(cell_to_px(PIT_CELL), CELL * 0.38, COLOR_PIT)
