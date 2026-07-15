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
	var step := Vector2i.ZERO
	if event.is_action("move_up"):
		step = Vector2i.UP
	elif event.is_action("move_down"):
		step = Vector2i.DOWN
	elif event.is_action("move_left"):
		step = Vector2i.LEFT
	elif event.is_action("move_right"):
		step = Vector2i.RIGHT
	elif event.is_action("interact"):
		_interact()
		return
	if step != Vector2i.ZERO:
		_try_step(step)


func _try_step(step: Vector2i) -> void:
	if _tween and _tween.is_running():
		return
	var turn := TurnManager.advance()
	if stunned_turns > 0:
		stunned_turns -= 1
		EventBus.emit_game_event("stun_tick", {"remaining": stunned_turns})
		return
	if in_pit:
		# M0 placeholder: climbing out is a free action; the real check-based
		# scripted trigger (dex/con roll) is M1 work.
		in_pit = false
		EventBus.emit_game_event("climbed_out_of_pit", {})
		modulate = Color.WHITE
		return
	var target := cell + step
	if not grid.is_walkable(target):
		EventBus.emit_game_event("bumped_wall", {"cell_x": target.x, "cell_y": target.y})
		return
	cell = target
	_glide_to(grid.cell_to_px(cell))
	if cell == grid.PIT_CELL and not in_pit:
		_fall_into_pit()
	else:
		EventBus.emit_game_event("player_moved", {"cell_x": cell.x, "cell_y": cell.y})


func _fall_into_pit() -> void:
	in_pit = true
	stunned_turns = STUN_TURNS_IN_PIT
	grid.reveal_pit()
	modulate = Color(0.55, 0.55, 0.62)  # dimmed: player is down in the dark
	EventBus.emit_game_event("fell_into_pit", {"stun_turns": STUN_TURNS_IN_PIT})


func _interact() -> void:
	TurnManager.advance()
	EventBus.emit_game_event("player_interacted", {"cell_x": cell.x, "cell_y": cell.y})


func _glide_to(target_px: Vector2) -> void:
	_tween = create_tween()
	_tween.tween_property(self, "position", target_px, MOVE_TWEEN_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 16.0, Color(0.85, 0.78, 0.55))
	draw_circle(Vector2.ZERO, 16.0, Color(0.4, 0.35, 0.2), false, 2.0)
