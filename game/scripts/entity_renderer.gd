extends Node2D
## Draws World objects (enemies, items) as placeholder shapes — a view over the
## World registry (ADR-0013). Only entities on a currently-visible cell are shown
## (fog of war). The player and the pit are drawn by their own nodes. Placeholder
## visuals; the GM's SVG art arrives at M3.

const COLOR_ENEMY := Color(0.75, 0.2, 0.22)
const COLOR_ENEMY_EDGE := Color(0.35, 0.08, 0.1)
const COLOR_ITEM := Color(0.45, 0.75, 0.4)

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
		if "enemy" in tags:
			draw_circle(center, _grid.CELL * 0.34, COLOR_ENEMY)
			draw_circle(center, _grid.CELL * 0.34, COLOR_ENEMY_EDGE, false, 2.0)
		elif "item" in tags:
			var s: float = _grid.CELL * 0.2
			draw_rect(Rect2(center - Vector2(s, s), Vector2(s, s) * 2.0), COLOR_ITEM)
