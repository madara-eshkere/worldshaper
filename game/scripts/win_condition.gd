extends Node
## Formal, checkable win condition (DESIGN 4.5 / ADR-0009): the goal is a predicate
## over World State, not free text, so completability is machine-verifiable and
## softlock is impossible. Emits level_complete once satisfied. Also exposes a
## static grid-reachability check (the Validator's geometry sanity check).

var _prim
var _predicate: Dictionary = {}
var _done := false


func setup(prim) -> void:
	_prim = prim
	EventBus.game_event.connect(_on_event)


func set_predicate(pred: Dictionary) -> void:
	_predicate = pred


func _on_event(name: String, _data: Dictionary) -> void:
	if _done:
		return
	if name in ["player_moved", "player_turn_ended", "died", "player_interacted", "used_item"]:
		if _satisfied():
			_done = true
			_prim.emit("level_complete", {})


func _satisfied() -> bool:
	if _predicate.has("player_at"):
		return _prim.player_cell() == _predicate["player_at"]
	if _predicate.has("dead"):
		return int(_prim.get_prop(_predicate["dead"], "hp", 1)) <= 0
	return false


## BFS over walkable cells — is `to` reachable from `from`? The Validator runs this
## at generation time so no level ships with a walled-off goal (softlock).
static func reachable(is_walkable: Callable, from: Vector2i, to: Vector2i, w: int, h: int) -> bool:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == to:
			return true
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and not seen.has(n) and is_walkable.call(n):
				seen[n] = true
				queue.append(n)
	return false
