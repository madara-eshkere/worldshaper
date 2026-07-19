extends Node
## Enemy turns (ADR-0007: everything is turn-based; combat is the player and
## enemies alternating, no separate real-time mode). After each player turn, every
## living enemy either attacks the player (if adjacent) or steps toward them.
## Deterministic AI, zero LLM. M1 hardcoded; M2 lets the Director script smarter
## enemy Mechanics.

const Combat = preload("res://scripts/combat.gd")

var _prim


func setup(prim) -> void:
	_prim = prim
	EventBus.game_event.connect(_on_event)


func _on_event(name: String, _data: Dictionary) -> void:
	if name == "player_turn_ended":
		_take_turns()


func _take_turns() -> void:
	var player_cell: Vector2i = _prim.player_cell()
	for id in _prim.find_by_tag("enemy"):
		if int(_prim.get_prop(id, "hp", 0)) <= 0:
			continue
		var cell: Vector2i = _prim.get_object(id)["cell"]
		if Combat.adjacent(cell, player_cell):
			Combat.attack(_prim, id, "player")
			if int(_prim.get_prop("player", "hp", 1)) <= 0:
				_prim.emit("player_died", {})
				return
		else:
			_step_toward(id, cell, player_cell)


func _step_toward(id: String, from: Vector2i, target: Vector2i) -> void:
	var dir := Vector2i(signi(target.x - from.x), signi(target.y - from.y))
	# Try the diagonal step first, then straighten out if it's blocked.
	for cand in [from + dir, from + Vector2i(dir.x, 0), from + Vector2i(0, dir.y)]:
		if cand != from and _prim.is_walkable(cand) and _prim.objects_at(cand).is_empty():
			_prim.move_to(id, cand)
			return
