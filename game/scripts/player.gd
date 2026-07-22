extends Node2D
## Grid-locked player (ADR-0007). Data (cell, stun, speed) lives in the World
## "player" object (ADR-0013); this node is a view + input driver. Turn timing is
## owned by the TurnScheduler — the player just performs ONE action when it's its
## turn and reports it. Input is responsive: a press acts at once (a one-frame
## coalesce catches a diagonal), holding repeats on a short cadence.

const Combat = preload("res://scripts/combat.gd")

const MOVE_TWEEN_SEC := 0.11
const STUN_TICK_SEC := 0.30
const MOVE_REPEAT_SEC := 0.12  # cadence while a movement key is held
const DIM := Color(0.55, 0.55, 0.62)

var grid: Node2D
var cell := Vector2i(2, 2)

var _prim
var _scheduler
var _tween: Tween
var _stun_accum := 0.0
var _pending_move := false
var _repeat := 0.0


func setup(world_grid: Node2D, primitives, scheduler = null) -> void:
	grid = world_grid
	_prim = primitives
	_scheduler = scheduler
	if World.has("player"):
		cell = World.raw("player")["cell"]
	position = grid.cell_to_px(cell)
	EventBus.game_event.connect(_on_game_event)


func _on_game_event(name: String, _data: Dictionary) -> void:
	if name == "player_died" or name == "level_complete":
		if _tween and _tween.is_valid():
			_tween.kill()
		position = grid.cell_to_px(cell)  # snap to the real cell before the pause


func _stun() -> int:
	return int(_prim.get_prop("player", "stunned_turns", 0)) if _prim else 0


func _in_pit() -> bool:
	return bool(_prim.get_prop("player", "in_pit", false)) if _prim else false


func _my_turn() -> bool:
	return _scheduler == null or _scheduler.is_player_turn()


func _held_dir() -> Vector2i:
	return Vector2i(
		int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left")),
		int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up")))


func _process(delta: float) -> void:
	if _prim == null:
		return
	modulate = DIM if _in_pit() else Color.WHITE
	if _stun() > 0:
		_stun_accum += delta
		if _stun_accum >= STUN_TICK_SEC:
			_stun_accum = 0.0
			_tick_stun()
		return
	if _tween and _tween.is_running():
		return
	var dir := _held_dir()
	if _pending_move:
		_pending_move = false
		if dir != Vector2i.ZERO:
			_step_now(dir)
		return
	if dir != Vector2i.ZERO:
		_repeat -= delta
		if _repeat <= 0.0:
			_step_now(dir)
	else:
		_repeat = 0.0  # idle: the next press acts immediately


func _unhandled_input(event: InputEvent) -> void:
	if _prim == null or not event.is_pressed() or event.is_echo():
		return
	if _stun() > 0 or not _my_turn():
		return
	if event.is_action("move_up") or event.is_action("move_down") \
			or event.is_action("move_left") or event.is_action("move_right"):
		_pending_move = true  # commit next frame so a near-simultaneous 2nd key = diagonal
		return
	if _tween and _tween.is_running():
		return
	if event.is_action("interact"):
		_interact()
	elif event.is_action("wait"):
		_wait()
	elif event.is_action("use"):
		_use_item()


func _step_now(dir: Vector2i) -> void:
	if not _my_turn():
		return
	_repeat = MOVE_REPEAT_SEC
	_try_step(dir)


func _try_step(step: Vector2i) -> void:
	if _stun() > 0:
		_tick_stun()
		return
	var target := cell + step
	for oid in _prim.objects_at(target):
		var tags: Array = _prim.get_object(oid).get("tags", [])
		if "enemy" in tags:
			Combat.attack(_prim, "player", oid)  # emits player_hit_enemy / enemy_slain
			_spend_turn()
			return
		if "blocking" in tags:
			EventBus.emit_game_event("bumped_object", {"target": oid})
			return  # blocked — no turn
	if not _prim.is_walkable(target):
		EventBus.emit_game_event("bumped_wall", {"cell_x": target.x, "cell_y": target.y})
		return  # wall — no turn
	cell = target
	_prim.move_to("player", cell)
	_glide_to(grid.cell_to_px(cell))
	_pickup(cell)
	EventBus.emit_game_event("player_moved", {"cell_x": cell.x, "cell_y": cell.y})
	_spend_turn()


func _interact() -> void:
	if _stun() > 0:
		_tick_stun()
		return
	EventBus.emit_game_event("player_interacted", {"cell_x": cell.x, "cell_y": cell.y})
	_spend_turn()


func _wait() -> void:
	if _stun() > 0:
		_tick_stun()
		return
	EventBus.emit_game_event("player_waited", {"cell_x": cell.x, "cell_y": cell.y})
	_spend_turn()


func _use_item() -> void:
	if _stun() > 0:
		_tick_stun()
		return
	var inv: Array = _prim.get_prop("player", "inventory", [])
	for i in inv.size():
		var item: Dictionary = inv[i]
		if item.has("heal"):
			_prim.heal("player", int(item["heal"]))
			var rest := inv.duplicate()
			rest.remove_at(i)
			_prim.set_prop("player", "inventory", rest)
			EventBus.emit_game_event("used_item", {"item": item.get("name", "зелье")})
			_spend_turn()
			return
	_prim.emit("nothing_to_use", {})  # nothing usable — not a turn


func _pickup(at: Vector2i) -> void:
	for oid in _prim.objects_at(at):
		var obj: Dictionary = _prim.get_object(oid)
		if "item" in obj.get("tags", []):
			var inv: Array = _prim.get_prop("player", "inventory", []).duplicate()
			inv.append(obj.get("props", {}))
			_prim.set_prop("player", "inventory", inv)
			_prim.despawn(oid)
			_prim.emit("picked_up", {"item": obj.get("props", {}).get("name", "предмет")})


func _tick_stun() -> void:
	# Helpless: the player spends the turn ticking down the stun (climbs out of a pit
	# automatically when it expires — a 2-turn stun costs 2 skips, not 3, B-002).
	var s := _stun() - 1
	_prim.set_prop("player", "stunned_turns", s)
	if s <= 0 and _in_pit():
		_prim.set_prop("player", "in_pit", false)
		EventBus.emit_game_event("climbed_out_of_pit", {})
	else:
		EventBus.emit_game_event("stun_tick", {"remaining": s})
	_spend_turn()


func _spend_turn() -> void:
	TurnManager.advance()
	if _scheduler != null:
		_scheduler.player_acted()  # hands control to the scheduler (mobs act)


func _glide_to(target_px: Vector2) -> void:
	_tween = create_tween()
	_tween.tween_property(self, "position", target_px, MOVE_TWEEN_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 16.0, Color(0.85, 0.78, 0.55))
	draw_circle(Vector2.ZERO, 16.0, Color(0.4, 0.35, 0.2), false, 2.0)
