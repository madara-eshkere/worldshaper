extends Node
## Headless test for FogOfWar: line of sight, radius, memory (seen), bounds.
##   godot --headless --path game res://tests/test_fog.tscn

const FogOfWar = preload("res://scripts/fog_of_war.gd")

var _fails: Array[String] = []


func _ready() -> void:
	# 20x20 grid with a single blocking wall cell at (7,5).
	var is_wall := func(c: Vector2i) -> bool: return c == Vector2i(7, 5)
	var fog = FogOfWar.new(20, 20, is_wall)

	# fresh: everything hidden
	_expect(fog.state_at(Vector2i(5, 5)) == FogOfWar.HIDDEN, "fresh fog should be HIDDEN")

	fog.recompute(Vector2i(5, 5))
	_expect(fog.state_at(Vector2i(5, 5)) == FogOfWar.VISIBLE, "origin should be VISIBLE")
	_expect(fog.state_at(Vector2i(6, 5)) == FogOfWar.VISIBLE, "adjacent clear cell should be VISIBLE")
	_expect(fog.state_at(Vector2i(7, 5)) == FogOfWar.VISIBLE, "the wall face itself is VISIBLE")
	_expect(fog.state_at(Vector2i(8, 5)) == FogOfWar.HIDDEN, "cell behind the wall should stay HIDDEN")
	_expect(fog.state_at(Vector2i(9, 5)) == FogOfWar.HIDDEN, "further behind the wall should stay HIDDEN")
	_expect(fog.state_at(Vector2i(15, 5)) == FogOfWar.HIDDEN, "beyond sight radius should be HIDDEN")
	_expect(fog.state_at(Vector2i(-1, -1)) == FogOfWar.HIDDEN, "out of bounds should be HIDDEN")
	_expect(fog.state_at(Vector2i(5, 2)) == FogOfWar.VISIBLE, "clear cell up-column should be VISIBLE")

	# memory: move far away — a previously visible cell becomes SEEN, not HIDDEN
	fog.recompute(Vector2i(5, 17))
	_expect(fog.state_at(Vector2i(6, 5)) == FogOfWar.SEEN, "explored cell out of sight should be SEEN")
	_expect(fog.state_at(Vector2i(5, 17)) == FogOfWar.VISIBLE, "new origin should be VISIBLE")

	print("\n===== FOG TEST =====")
	if _fails.is_empty():
		print("ALL PASS")
	else:
		for f in _fails:
			print("FAIL  " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
