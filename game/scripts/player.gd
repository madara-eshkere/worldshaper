extends Node2D
## Grid-locked player with smooth-turn movement (ADR-0007). The player's data
## (cell, stun, in_pit) lives in the World "player" object — this node is a view
## over it (ADR-0013). Falling into a pit is no longer hardcoded here: it is a
## Scripted Trigger (registered in main.gd) that fires on player_moved and runs
## the pit Mechanic, which sets the stun on the World object (ADR-0014).

const Combat = preload("res://scripts/combat.gd")

const MOVE_TWEEN_SEC := 0.11
const STUN_TICK_SEC := 0.35  # real time between auto-skipped stun turns
const DIM := Color(0.55, 0.55, 0.62)  # player is down in the dark

var grid: Node2D
var cell := Vector2i(2, 2)

var _prim
var _tween: Tween
var _stun_accum := 0.0


func setup(world_grid: Node2D, primitives) -> void:
	grid = world_grid
	_prim = primitives
	if World.has("player"):
		cell = World.raw("player")["cell"]
	position = grid.cell_to_px(cell)


func _stun() -> int:
	return int(_prim.get_prop("player", "stunned_turns", 0)) if _prim else 0


func _in_pit() -> bool:
	return bool(_prim.get_prop("player", "in_pit", false)) if _prim else false


func _process(delta: float) -> void:
	if _prim == null:
		return
	modulate = DIM if _in_pit() else Color.WHITE
	# Auto-skip: a stunned player's turns tick by themselves; no key-mashing.
	if _stun() > 0:
		_stun_accum += delta
		if _stun_accum >= STUN_TICK_SEC:
			_stun_accum = 0.0
			_tick_stun()


func _unhandled_input(event: InputEvent) -> void:
	if _prim == null or not event.is_pressed() or event.is_echo():
		return
	# Ignore input mid-glide so a held key can't queue phantom turns.
	if _tween and _tween.is_running():
		return
	# Stunned: the player can't act; _process auto-skips the turns. Swallow input.
	if _stun() > 0:
		return
	if event.is_action("interact"):
		_interact()
		return
	if event.is_action("wait"):
		_wait()
		return
	if event.is_action("use"):
		_use_item()
		return
	var step := Vector2i.ZERO
	if event.is_action("move_up"):
		step = Vector2i.UP
	elif event.is_action("move_down"):
		step = Vector2i.DOWN
	elif event.is_action("move_left"):
		step = Vector2i.LEFT
	elif event.is_action("move_right"):
		step = Vector2i.RIGHT
	if step != Vector2i.ZERO:
		_try_step(step)


func _try_step(step: Vector2i) -> void:
	# B-003: stun gates EVERY action — a stunned player can only wait it out.
	if _stun() > 0:
		_tick_stun()
		return
	var target := cell + step
	# Bump-to-attack: stepping into an enemy attacks it instead of moving.
	for oid in _prim.objects_at(target):
		if "enemy" in _prim.get_object(oid).get("tags", []):
			Combat.attack(_prim, "player", oid)
			_end_turn("player_attacked", {"target": oid})
			return
	# B-001: bumping a wall is a no-op — it must NOT consume a turn.
	if not grid.is_walkable(target):
		EventBus.emit_game_event("bumped_wall", {"cell_x": target.x, "cell_y": target.y})
		return
	cell = target
	_prim.move_to("player", cell)  # position lives in the World object
	_glide_to(grid.cell_to_px(cell))
	_pickup(cell)
	# A pit Scripted Trigger listens on player_moved and reacts if this cell is one.
	_end_turn("player_moved", {"cell_x": cell.x, "cell_y": cell.y})


func _interact() -> void:
	if _stun() > 0:
		_tick_stun()
		return
	_end_turn("player_interacted", {"cell_x": cell.x, "cell_y": cell.y})


func _wait() -> void:
	# Spend a turn doing nothing (spacebar).
	if _stun() > 0:
		_tick_stun()
		return
	_end_turn("player_waited", {"cell_x": cell.x, "cell_y": cell.y})


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
			_end_turn("used_item", {"item": item.get("name", "зелье")})
			return
	_prim.emit("nothing_to_use", {})  # no usable item — not a turn


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
	# Burn one turn doing nothing. When the stun runs out in the pit, the player
	# climbs out automatically — so a 2-turn stun costs 2 skips, not 3 (B-002).
	# M1 placeholder; M4 replaces climbing with a check-based Declared action.
	TurnManager.advance()
	var s := _stun() - 1
	_prim.set_prop("player", "stunned_turns", s)
	if s <= 0 and _in_pit():
		_prim.set_prop("player", "in_pit", false)
		EventBus.emit_game_event("climbed_out_of_pit", {})
	else:
		EventBus.emit_game_event("stun_tick", {"remaining": s})
	EventBus.emit_game_event("player_turn_ended", {})  # enemies act while you're stunned


func _end_turn(event_name: String, data: Dictionary) -> void:
	# One player action = one turn. Emit the action event, then signal end-of-turn
	# so the enemy controller can act (ADR-0007).
	TurnManager.advance()
	EventBus.emit_game_event(event_name, data)
	EventBus.emit_game_event("player_turn_ended", {})


func _glide_to(target_px: Vector2) -> void:
	_tween = create_tween()
	_tween.tween_property(self, "position", target_px, MOVE_TWEEN_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 16.0, Color(0.85, 0.78, 0.55))
	draw_circle(Vector2.ZERO, 16.0, Color(0.4, 0.35, 0.2), false, 2.0)
