extends Node
## Headless turn-loop test — now an integration test of the turn loop together with
## the pit Scripted Trigger + World-backed stun (ADR-0013/0014). Covers B-001 (wall
## bump), B-002 (stun press count), B-003 (stun blocks interaction), B-004 (interact
## consumes a turn), plus the pit fall firing through the trigger, not hardcode.
##   godot --headless --path game res://tests/test_turn_loop.tscn

const PIT_FALL := {"id": "pit_fall", "steps": [
	{"prim": "set_prop", "args": ["$actor", "stunned_turns", 2]},
	{"prim": "set_prop", "args": ["$actor", "in_pit", true]},
	{"prim": "emit", "args": ["fell_into_pit", {"stun_turns": 2}]},
]}

var _events: Array[String] = []
var _fails: Array[String] = []
var _prim
var _player: Node2D
var _grid: Node2D


func _ready() -> void:
	EventBus.game_event.connect(func(n: String, _d: Dictionary): _events.append(n))
	_grid = load("res://scripts/world_grid.gd").new()
	add_child(_grid)
	World.clear()
	World.add_object("player", "player", Vector2i(2, 2), {}, [])

	_prim = load("res://scripts/primitives.gd").new(_grid, 42)
	var runner = load("res://scripts/mechanic_runner.gd").new(_prim)
	var triggers: Node = load("res://scripts/trigger_system.gd").new()
	add_child(triggers)
	triggers.setup(_prim, runner)
	_prim.spawn("pit", _grid.PIT_CELL, {}, ["pit"])
	triggers.register_trigger({"on": "player_moved", "if": {"cell_has_tag": "pit"}, "mechanic": PIT_FALL})

	_player = load("res://scripts/player.gd").new()
	add_child(_player)
	_player.setup(_grid, _prim)

	# T1 — wall bump must NOT consume a turn (B-001).
	_reset(Vector2i(1, 2))
	_player._try_step(Vector2i.LEFT)  # target (0,2) is a wall
	_expect(TurnManager.turn == 0, "T1 wall bump consumed a turn (turn=%d)" % TurnManager.turn)
	_expect(_player.cell == Vector2i(1, 2), "T1 wall bump moved the player")
	_expect(_last() == "bumped_wall", "T1 expected bumped_wall, got %s" % _last())

	# T2 — a normal move consumes exactly one turn.
	_reset(Vector2i(2, 2))
	_player._try_step(Vector2i.RIGHT)
	_expect(TurnManager.turn == 1, "T2 move turn=%d (want 1)" % TurnManager.turn)
	_expect(_player.cell == Vector2i(3, 2), "T2 player did not move")
	_expect(_events.has("player_moved"), "T2 expected player_moved, got %s" % str(_events))

	# T3 — interact consumes a turn when not stunned (B-004: it DOES).
	_reset(Vector2i(3, 2))
	_player._interact()
	_expect(TurnManager.turn == 1, "T3 interact turn=%d (want 1)" % TurnManager.turn)
	_expect(_events.has("player_interacted"), "T3 expected player_interacted, got %s" % str(_events))

	# T4 — stepping onto the pit fires the trigger: fall, stun 2, step spends a turn.
	_reset(Vector2i(_grid.PIT_CELL.x - 1, _grid.PIT_CELL.y))
	_player._try_step(Vector2i.RIGHT)
	_expect(_in_pit(), "T4 not in pit after stepping onto it")
	_expect(_stun() == 2, "T4 stunned=%d (want 2)" % _stun())
	_expect(TurnManager.turn == 1, "T4 step turn=%d (want 1)" % TurnManager.turn)
	_expect(_events.has("fell_into_pit"), "T4 expected fell_into_pit, got %s" % str(_events))

	# T5 — interaction is blocked while stunned (B-003): it ticks the stun, no interact.
	_events.clear()
	var turn_before: int = TurnManager.turn
	_player._interact()
	_expect(not _events.has("player_interacted"), "T5 interact worked during stun (B-003)")
	_expect(_events.has("stun_tick"), "T5 blocked interact should tick stun, got %s" % str(_events))
	_expect(_stun() == 1, "T5 stun did not tick (%d)" % _stun())
	_expect(TurnManager.turn == turn_before + 1, "T5 stun tick should consume a turn")

	# T6 — stun expiry auto-climbs (B-002: 2 presses recover a 2-turn stun, not 3).
	_events.clear()
	_player._try_step(Vector2i.RIGHT)
	_expect(not _in_pit(), "T6 still in pit after stun expired")
	_expect(_stun() == 0, "T6 stunned=%d (want 0)" % _stun())
	_expect(_events.has("climbed_out_of_pit"), "T6 expected climbed_out_of_pit, got %s" % str(_events))

	# T7 — spacebar wait spends exactly one turn.
	_reset(Vector2i(2, 2))
	_player._wait()
	_expect(TurnManager.turn == 1, "T7 wait turn=%d (want 1)" % TurnManager.turn)
	_expect(_events.has("player_waited"), "T7 expected player_waited, got %s" % str(_events))

	# T8 — auto-skip: _process ticks a pit stun to zero with no key presses.
	_reset(Vector2i(_grid.PIT_CELL.x - 1, _grid.PIT_CELL.y))
	_player._try_step(Vector2i.RIGHT)  # fall in → stunned 2
	_expect(_stun() == 2, "T8 setup stunned=%d (want 2)" % _stun())
	_events.clear()
	for _i in range(3):
		_player._process(_player.STUN_TICK_SEC)
	_expect(not _in_pit(), "T8 auto-skip did not climb out")
	_expect(_stun() == 0, "T8 auto-skip left stun=%d" % _stun())
	_expect(_events.has("climbed_out_of_pit"), "T8 expected auto climb, events=%s" % str(_events))

	print("\n===== TURN-LOOP TEST =====")
	if _fails.is_empty():
		print("ALL PASS (T1-T8)")
	else:
		for f in _fails:
			print("FAIL  " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _reset(at: Vector2i) -> void:
	_prim.set_prop("player", "stunned_turns", 0)
	_prim.set_prop("player", "in_pit", false)
	World.set_cell("player", at)
	_player.cell = at
	TurnManager.turn = 0
	_events.clear()


func _stun() -> int:
	return int(_prim.get_prop("player", "stunned_turns", 0))


func _in_pit() -> bool:
	return bool(_prim.get_prop("player", "in_pit", false))


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)


func _last() -> String:
	return _events[-1] if not _events.is_empty() else "<none>"
