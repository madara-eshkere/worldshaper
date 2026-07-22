extends Node2D
## Draws World objects (enemies, items) as placeholder shapes — a view over the
## World registry (ADR-0013). Only entities on a currently-visible cell are shown
## (fog of war). The player and the pit are drawn by their own nodes. Placeholder
## visuals; the GM's SVG art arrives at M3.

const COLOR_ENEMY := Color(0.75, 0.2, 0.22)
const COLOR_ITEM := Color(0.45, 0.75, 0.4)
const COLOR_TABLE := Color(0.5, 0.36, 0.22)
const COLOR_EXIT := Color(0.4, 0.7, 0.95)
const COLOR_PIT := Color(0.05, 0.05, 0.07)

var _grid: Node2D


func setup(grid: Node2D) -> void:
	_grid = grid
	# World mutations and turns both change what's on screen; redraw on either.
	EventBus.game_event.connect(func(_n: String, _d: Dictionary): queue_redraw())
	World.object_added.connect(func(_id: String): queue_redraw())
	World.object_removed.connect(func(_id: String): queue_redraw())
	World.object_moved.connect(func(_id: String): queue_redraw())


func _draw() -> void:
	if _grid == null:
		return
	for id in World.objects:
		if id == "player":
			continue
		var obj: Dictionary = World.objects[id]
		var cell: Vector2i = obj["cell"]
		if not _grid.is_cell_visible(cell):
			continue  # unseen or remembered-but-dark: don't reveal live entities
		var tags: Array = obj["tags"]
		var center: Vector2 = _grid.cell_to_px(cell)
		var half: float = _grid.CELL * 0.5
		if "corpse" in tags:
			# Same shape as the living creature, its own colour, darkened.
			_creature_shape(center, _grid.CELL * 0.28, _creature_color(obj).darkened(0.55),
					str(obj["props"].get("glyph", "circle")), false)
		elif "pit" in tags:
			# A hidden trap: drawn only once revealed (fallen into / spotted).
			if obj["props"].get("revealed", false):
				draw_circle(center, _grid.CELL * 0.38, COLOR_PIT)
		elif "enemy" in tags:
			_creature_shape(center, _grid.CELL * 0.34, _creature_color(obj),
					str(obj["props"].get("glyph", "circle")), true)
		elif "exit" in tags:
			draw_rect(Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), COLOR_EXIT, false, 3.0)
		elif "table" in tags:
			var t: float = _grid.CELL * 0.36
			draw_rect(Rect2(center - Vector2(t, t), Vector2(t, t) * 2.0), COLOR_TABLE)
		elif "item" in tags:
			var s: float = _grid.CELL * 0.2
			draw_rect(Rect2(center - Vector2(s, s), Vector2(s, s) * 2.0), COLOR_ITEM)


func _creature_shape(center: Vector2, r: float, col: Color, glyph: String, outline: bool) -> void:
	if glyph == "triangle":
		var pts := PackedVector2Array([
			center + Vector2(0, -r), center + Vector2(r, r * 0.8), center + Vector2(-r, r * 0.8)])
		draw_colored_polygon(pts, col)
		if outline:
			draw_polyline(pts + PackedVector2Array([pts[0]]), col.darkened(0.5), 2.0)
	else:
		draw_circle(center, r, col)
		if outline:
			draw_circle(center, r, col.darkened(0.5), false, 2.0)


func _creature_color(obj: Dictionary) -> Color:
	var c: Array = obj["props"].get("color", [])
	if c.size() >= 3:
		return Color(float(c[0]), float(c[1]), float(c[2]))
	return COLOR_ENEMY
