extends Node
## Headless test for the speed system: DEX->speed thresholds, and — the real point —
## that a faster actor genuinely takes MORE turns in the scheduler (closing distance
## on a fleeing/standing player), not just "acts before/after" like the old loop.
##   godot --headless --path game res://tests/test_speed.tscn

const Speed = preload("res://scripts/speed.gd")

var _fails: Array[String] = []
var _prim
var _sched: Node


func _ready() -> void:
	_prim = load("res://scripts/primitives.gd").new(9)
	_sched = load("res://scripts/turn_scheduler.gd").new()
	add_child(_sched)
	_sched.setup(_prim)

	# thresholds
	_expect(Speed.for_dex(30) == 9, "dex30 -> speed 9")
	_expect(Speed.for_dex(20) == 6, "dex20 -> speed 6")
	_expect(Speed.for_dex(10) == 3, "dex10 -> speed 3")
	_expect(Speed.for_dex(1) == 1, "dex1 -> speed 1 (min)")

	# frequency: over the same number of player turns, a speed-8 mob covers more
	# ground toward the player than a speed-2 mob (both start equidistant).
	World.clear()
	World.set_map(16, 10, load("res://tests/test_helpers.gd").bordered_map())
	var player_cell := Vector2i(2, 2)
	World.add_object("player", "player", player_cell, {"speed": 4, "def": 30, "hp": 200}, [])
	var fast: String = _prim.spawn("bat", Vector2i(14, 8), {"speed": 8, "def": 30, "str": 1, "atk": 1, "hp": 50}, ["enemy", "blocking"])
	var slow: String = _prim.spawn("goblin", Vector2i(14, 2), {"speed": 2, "def": 30, "str": 1, "atk": 1, "hp": 50}, ["enemy", "blocking"])
	_sched.start()
	for _i in range(4):
		_sched.player_acted()
	var fast_d := _cheby(_prim.get_object(fast)["cell"], player_cell)
	var slow_d := _cheby(_prim.get_object(slow)["cell"], player_cell)
	_expect(fast_d < slow_d, "faster mob should close more (fast_dist=%d, slow_dist=%d)" % [fast_d, slow_d])

	print("\n===== SPEED TEST =====")
	if _fails.is_empty():
		print("ALL PASS")
	else:
		for f in _fails:
			print("FAIL  " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _cheby(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
