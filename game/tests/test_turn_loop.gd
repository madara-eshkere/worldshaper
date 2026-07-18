extends Node
## Headless turn-loop test — verifies turn accounting and stun gating that the
## player cannot see in a playtest (no on-screen turn counter yet).
## Covers B-001 (wall bump), B-002 (stun press count), B-003 (stun blocks
## interaction), B-004 (interact consumes a turn).
## Runs as a scene so project autoloads (EventBus, TurnManager) are live:
##   godot --headless --path game res://tests/test_turn_loop.tscn

var _events: Array[String] = []
var _fails: Array[String] = []


func _ready() -> void:
	EventBus.game_event.connect(_on_event)
	var grid: Node2D = load("res://scripts/world_grid.gd").new()
	add_child(grid)
	var player: Node2D = load("res://scripts/player.gd").new()
	add_child(player)
	player.setup(grid)

	# T1 — wall bump must NOT consume a turn (B-001).
	player.cell = Vector2i(1, 2)  # x=0 is a wall
	TurnManager.turn = 0
	_events.clear()
	player._try_step(Vector2i.LEFT)
	_expect(TurnManager.turn == 0, "T1 wall bump consumed a turn (turn=%d)" % TurnManager.turn)
	_expect(player.cell == Vector2i(1, 2), "T1 wall bump moved the player")
	_expect(_last() == "bumped_wall", "T1 expected bumped_wall, got %s" % _last())

	# T2 — a normal move consumes exactly one turn.
	player.cell = Vector2i(2, 2)
	TurnManager.turn = 0
	_events.clear()
	player._try_step(Vector2i.RIGHT)
	_expect(TurnManager.turn == 1, "T2 move turn=%d (want 1)" % TurnManager.turn)
	_expect(player.cell == Vector2i(3, 2), "T2 player did not move")
	_expect(_last() == "player_moved", "T2 expected player_moved, got %s" % _last())

	# T3 — interact consumes a turn when not stunned (B-004: it DOES).
	TurnManager.turn = 0
	_events.clear()
	player._interact()
	_expect(TurnManager.turn == 1, "T3 interact turn=%d (want 1)" % TurnManager.turn)
	_expect(_last() == "player_interacted", "T3 expected player_interacted, got %s" % _last())

	# T4 — stepping onto the pit falls in, stuns for 2, and the step spends a turn.
	player.cell = Vector2i(grid.PIT_CELL.x - 1, grid.PIT_CELL.y)
	player.in_pit = false
	player.stunned_turns = 0
	TurnManager.turn = 0
	_events.clear()
	player._try_step(Vector2i.RIGHT)
	_expect(player.in_pit, "T4 not in pit after stepping onto it")
	_expect(player.stunned_turns == 2, "T4 stunned=%d (want 2)" % player.stunned_turns)
	_expect(TurnManager.turn == 1, "T4 step turn=%d (want 1)" % TurnManager.turn)
	_expect(_last() == "fell_into_pit", "T4 expected fell_into_pit, got %s" % _last())

	# T5 — interaction is blocked while stunned (B-003): it ticks the stun, no interact.
	_events.clear()
	var turn_before: int = TurnManager.turn
	player._interact()
	_expect(not _events.has("player_interacted"), "T5 interact worked during stun (B-003)")
	_expect(_last() == "stun_tick", "T5 blocked interact should tick stun, got %s" % _last())
	_expect(player.stunned_turns == 1, "T5 stun did not tick (%d)" % player.stunned_turns)
	_expect(TurnManager.turn == turn_before + 1, "T5 stun tick should consume a turn")

	# T6 — stun expiry auto-climbs (B-002: 2 presses recover a 2-turn stun, not 3).
	_events.clear()
	player._try_step(Vector2i.RIGHT)
	_expect(not player.in_pit, "T6 still in pit after stun expired")
	_expect(player.stunned_turns == 0, "T6 stunned=%d (want 0)" % player.stunned_turns)
	_expect(_last() == "climbed_out_of_pit", "T6 expected climbed_out_of_pit, got %s" % _last())

	# T7 — spacebar wait spends exactly one turn.
	player.in_pit = false
	player.stunned_turns = 0
	TurnManager.turn = 0
	_events.clear()
	player._wait()
	_expect(TurnManager.turn == 1, "T7 wait turn=%d (want 1)" % TurnManager.turn)
	_expect(_last() == "player_waited", "T7 expected player_waited, got %s" % _last())

	# T8 — auto-skip: _process ticks a pit stun to zero with no key presses.
	player.cell = Vector2i(grid.PIT_CELL.x - 1, grid.PIT_CELL.y)
	player.in_pit = false
	player.stunned_turns = 0
	player._try_step(Vector2i.RIGHT)  # fall in → stunned 2
	_expect(player.stunned_turns == 2, "T8 setup stunned=%d (want 2)" % player.stunned_turns)
	_events.clear()
	for _i in range(3):
		player._process(player.STUN_TICK_SEC)
	_expect(not player.in_pit, "T8 auto-skip did not climb out")
	_expect(player.stunned_turns == 0, "T8 auto-skip left stun=%d" % player.stunned_turns)
	_expect(_events.has("climbed_out_of_pit"), "T8 expected auto climb, events=%s" % str(_events))

	print("\n===== TURN-LOOP TEST =====")
	if _fails.is_empty():
		print("ALL PASS (T1-T8)")
	else:
		for f in _fails:
			print("FAIL  " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)


func _on_event(name: String, _data: Dictionary) -> void:
	_events.append(name)


func _last() -> String:
	return _events[-1] if not _events.is_empty() else "<none>"
