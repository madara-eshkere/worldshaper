extends Node2D
## Grid-locked player with smooth-turn movement (ADR-0007):
## logic snaps cell-to-cell (one step = one turn), visuals glide between cells.

const MOVE_TWEEN_SEC := 0.11
const STUN_TURNS_IN_PIT := 2

var grid: Node2D
var cell := Vector2i(2, 2)
var stunned_turns := 0
var in_pit := false

var _tween: Tween


func setup(world_grid: Node2D) -> void:
	grid = world_grid
	position = grid.cell_to_px(cell)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	# Ignore input mid-glide so a held key can't queue phantom turns.
	if _tween and _tween.is_running():
		return
	if event.is_action("interact"):
		_interact()
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
	if stunned_turns > 0:
		_tick_stun()
		return
	# B-001: bumping a wall is a no-op — it must NOT consume a turn. Check
	# walkability BEFORE advancing the turn counter.
	var target := cell + step
	if not grid.is_walkable(target):
		EventBus.emit_game_event("bumped_wall", {"cell_x": target.x, "cell_y": target.y})
		return
	TurnManager.advance()
	cell = target
	_glide_to(grid.cell_to_px(cell))
	if cell == grid.PIT_CELL:
		_fall_into_pit()
	else:
		EventBus.emit_game_event("player_moved", {"cell_x": cell.x, "cell_y": cell.y})


func _interact() -> void:
	# B-003: interaction is an action too — blocked while stunned.
	if stunned_turns > 0:
		_tick_stun()
		return
	TurnManager.advance()
	EventBus.emit_game_event("player_interacted", {"cell_x": cell.x, "cell_y": cell.y})


func _tick_stun() -> void:
	# Each key press while stunned burns one turn doing nothing. When the stun
	# runs out in the pit, the player climbs out automatically — so a 2-turn stun
	# costs 2 presses, not 3 (B-002). M1 replaces this placeholder with a proper
	# check-based "climb out" Declared action (dex/con roll).
	TurnManager.advance()
	stunned_turns -= 1
	if stunned_turns <= 0 and in_pit:
		in_pit = false
		modulate = Color.WHITE
		EventBus.emit_game_event("climbed_out_of_pit", {})
	else:
		EventBus.emit_game_event("stun_tick", {"remaining": stunned_turns})


func _fall_into_pit() -> void:
	in_pit = true
	stunned_turns = STUN_TURNS_IN_PIT
	grid.reveal_pit()
	modulate = Color(0.55, 0.55, 0.62)  # dimmed: player is down in the dark
	EventBus.emit_game_event("fell_into_pit", {"stun_turns": STUN_TURNS_IN_PIT})


func _glide_to(target_px: Vector2) -> void:
	_tween = create_tween()
	_tween.tween_property(self, "position", target_px, MOVE_TWEEN_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 16.0, Color(0.85, 0.78, 0.55))
	draw_circle(Vector2.ZERO, 16.0, Color(0.4, 0.35, 0.2), false, 2.0)
