extends RefCounted
## Deterministic grid fog of war + line of sight (DESIGN 4.6: geometry is engine
## math, never LLM). Three states per cell:
##   HIDDEN  — never seen (drawn black; secrets stay secret)
##   SEEN    — explored but out of current sight (drawn dim; terrain remembered)
##   VISIBLE — in the current line of sight (drawn full)
## `is_wall` is injected so this is testable headless without the grid node.

enum { HIDDEN, SEEN, VISIBLE }

const RADIUS := 6.5  # sight radius in cells (euclidean)

var _w: int
var _h: int
var _is_wall: Callable
var _state: PackedByteArray


func _init(w: int, h: int, is_wall: Callable) -> void:
	_w = w
	_h = h
	_is_wall = is_wall
	_state.resize(w * h)  # zero-filled == HIDDEN


func state_at(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= _w or cell.y >= _h:
		return HIDDEN
	return _state[cell.y * _w + cell.x]


## Recompute sight from `origin`: demote last frame's VISIBLE to SEEN, then light
## every in-radius cell that has a clear line to the origin.
func recompute(origin: Vector2i) -> void:
	for i in _state.size():
		if _state[i] == VISIBLE:
			_state[i] = SEEN
	var r := int(ceil(RADIUS))
	for y in range(maxi(0, origin.y - r), mini(_h, origin.y + r + 1)):
		for x in range(maxi(0, origin.x - r), mini(_w, origin.x + r + 1)):
			var c := Vector2i(x, y)
			if Vector2(c - origin).length() <= RADIUS and _los_clear(origin, c):
				_state[y * _w + x] = VISIBLE


## Clear if no wall sits strictly between a and b (endpoints don't block).
func _los_clear(a: Vector2i, b: Vector2i) -> bool:
	for cell in _line(a, b):
		if cell != a and cell != b and _is_wall.call(cell):
			return false
	return true


## Bresenham line between two cells (inclusive).
func _line(a: Vector2i, b: Vector2i) -> Array:
	var pts: Array = []
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var x := a.x
	var y := a.y
	while true:
		pts.append(Vector2i(x, y))
		if x == b.x and y == b.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return pts
