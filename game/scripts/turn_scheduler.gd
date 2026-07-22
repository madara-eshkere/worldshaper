extends Node
## Time-based turn scheduler (roguelike energy model). Every actor — the player and
## each living enemy — is INDEPENDENT: it acts when its accumulated time comes up,
## and a faster actor (higher speed) comes up more often. This replaces the old
## player-centric loop (player acts, then all mobs once), which is why a fleeing
## player kept a constant gap from a faster mob. Now a speed-8 bat genuinely acts
## about twice as often as a speed-4 player and closes in.
##
## The player is input-driven: the scheduler runs mob turns until it is the player's
## turn, then waits. The player calls player_acted() after each of its actions.

const Combat = preload("res://scripts/combat.gd")

var _prim
var _next: Dictionary = {}  # id -> next action time (float; lower = acts sooner)
var _waiting_for_player := false


func setup(prim) -> void:
	_prim = prim


func start() -> void:
	_next.clear()
	for id in _actors():
		_next[id] = 0.0
	_advance()


func is_player_turn() -> bool:
	return _waiting_for_player


func player_acted() -> void:
	_next["player"] = _time_of("player") + 1.0 / _speed("player")
	_waiting_for_player = false
	_advance()


## Run mob turns until it is the player's turn (or nobody is left).
func _advance() -> void:
	var guard := 0
	while guard < 10000:
		guard += 1
		var actors := _actors()
		if actors.is_empty():
			return
		var front := _min_time(actors)
		for id in actors:
			if not _next.has(id):
				_next[id] = front  # a fresh actor joins at the current front
		for id in _next.keys():
			if id not in actors:
				_next.erase(id)  # dead/removed actors drop out
		_rebase(front)
		var cur := _pick(actors)
		if cur == "player":
			_waiting_for_player = true
			return
		_next[cur] = _time_of(cur) + 1.0 / _speed(cur)
		_mob_turn(cur)
		if int(_prim.get_prop("player", "hp", 1)) <= 0:
			_prim.emit("player_died", {})
			return


func _pick(actors: Array) -> String:
	# Smallest next time; ties break player-first, then faster actor.
	var best := ""
	for id in actors:
		if best == "":
			best = id
			continue
		var t := _time_of(id)
		var bt := _time_of(best)
		if t < bt - 0.0001:
			best = id
		elif absf(t - bt) <= 0.0001:
			if id == "player":
				best = id
			elif best != "player" and _speed(id) > _speed(best):
				best = id
	return best


# --- mob AI (one action: attack if adjacent, else step one cell toward player) ---

func _mob_turn(id: String) -> void:
	var stun := int(_prim.get_prop(id, "stunned_turns", 0))
	if stun > 0:
		_prim.set_prop(id, "stunned_turns", stun - 1)  # e.g. fell in a pit — waste the turn
		return
	var cell: Vector2i = _prim.get_object(id)["cell"]
	var player_cell: Vector2i = _prim.player_cell()
	if Combat.adjacent(cell, player_cell):
		Combat.attack(_prim, id, "player")
	else:
		_step_toward(id, cell, player_cell)


func _step_toward(id: String, from: Vector2i, target: Vector2i) -> void:
	var dir := Vector2i(signi(target.x - from.x), signi(target.y - from.y))
	for cand in [from + dir, from + Vector2i(dir.x, 0), from + Vector2i(0, dir.y)]:
		if cand != from and _can_enter(cand):
			_prim.move_to(id, cand)
			_check_hazards(id, cand)
			return


func _can_enter(cell: Vector2i) -> bool:
	if not _prim.is_walkable(cell):
		return false
	for oid in _prim.objects_at(cell):
		if oid == "player":
			return false  # never share the player's cell (attack from adjacent instead)
		if "blocking" in _prim.get_object(oid).get("tags", []):
			return false  # walls/tables/other living enemies; a corpse/pit is passable
	return true


func _check_hazards(id: String, cell: Vector2i) -> void:
	for oid in _prim.objects_at(cell):
		if "pit" in _prim.get_object(oid).get("tags", []):
			if bool(_prim.get_prop(id, "flying", false)):
				return  # flyers glide over pits
			_prim.set_prop(id, "stunned_turns", 2)
			_prim.set_prop(oid, "revealed", true)
			_prim.emit("enemy_fell_into_pit", {"who": id})
			return


func _actors() -> Array:
	var out: Array = []
	if _prim.exists("player") and int(_prim.get_prop("player", "hp", 1)) > 0:
		out.append("player")
	for id in _prim.find_by_tag("enemy"):
		if int(_prim.get_prop(id, "hp", 0)) > 0:
			out.append(id)
	return out


func _speed(id: String) -> int:
	return maxi(1, int(_prim.get_prop(id, "speed", 1)))


func _time_of(id: String) -> float:
	return float(_next.get(id, 0.0))


func _min_time(actors: Array) -> float:
	var m := INF
	for id in actors:
		m = minf(m, _time_of(id))
	return m if m != INF else 0.0


func _rebase(front: float) -> void:
	if front > 1000.0:
		for id in _next:
			_next[id] -= front
