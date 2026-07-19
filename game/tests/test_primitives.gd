extends Node
## Headless test for Primitives + World State (ADR-0013, spec: docs/specs/primitives.md).
## Runs as a scene so the World autoload is live.
##   godot --headless --path game res://tests/test_primitives.tscn

var _events: Array[String] = []
var _fails: Array[String] = []


func _ready() -> void:
	EventBus.game_event.connect(func(n: String, _d: Dictionary): _events.append(n))
	var grid: Node2D = load("res://scripts/world_grid.gd").new()
	add_child(grid)
	var Primitives := load("res://scripts/primitives.gd")
	var p = Primitives.new(grid, 12345)  # fixed seed → deterministic rolls

	World.clear()
	World.add_object("player", "player", Vector2i(2, 2), {"hp": 10, "str": 20}, [])

	# spawn returns an id, object is queryable
	var tid: String = p.spawn("prop", Vector2i(3, 3), {"hp": 4}, ["blocking", "flammable"])
	_expect(tid != "", "spawn returned empty id")
	_expect(p.exists(tid), "spawned object does not exist")
	var obj: Dictionary = p.get_object(tid)
	_expect(obj.get("type") == "prop", "spawn wrong type: %s" % obj.get("type"))
	_expect(obj.get("cell") == Vector2i(3, 3), "spawn wrong cell")

	# get_object returns a COPY (mutating it must not touch the registry)
	obj["props"]["hp"] = 999
	_expect(int(p.get_prop(tid, "hp")) == 4, "get_object leaked a live reference")

	# spawn onto a wall is rejected, no crash
	_events.clear()
	var bad: String = p.spawn("prop", Vector2i(0, 0), {}, [])
	_expect(bad == "", "spawn on wall should return empty id")
	_expect(_events.has("primitive_rejected"), "spawn-on-wall should emit primitive_rejected")

	# move_to validates walkability
	_expect(p.move_to(tid, Vector2i(4, 3)), "valid move rejected")
	_expect(p.get_object(tid)["cell"] == Vector2i(4, 3), "move did not update cell")
	_events.clear()
	_expect(not p.move_to(tid, Vector2i(0, 3)), "move onto wall should fail")
	_expect(p.get_object(tid)["cell"] == Vector2i(4, 3), "rejected move changed the cell")
	_expect(_events.has("primitive_rejected"), "rejected move should emit event")

	# set_prop / damage / heal
	_expect(p.set_prop(tid, "name", "стол"), "set_prop failed")
	_expect(p.get_prop(tid, "name") == "стол", "prop not stored")
	p.damage(tid, 10)  # hp 4 → clamps at 0
	_expect(int(p.get_prop(tid, "hp")) == 0, "damage did not clamp at 0")
	p.heal(tid, 3)
	_expect(int(p.get_prop(tid, "hp")) == 3, "heal wrong")

	# tags + find_by_tag + objects_at + distance
	_expect(p.find_by_tag("flammable") == [tid], "find_by_tag flammable")
	p.add_tag(tid, "wet")
	_expect(p.remove_tag(tid, "flammable"), "remove_tag failed")
	_expect(p.find_by_tag("flammable") == [], "flammable tag not removed")
	_expect(p.objects_at(Vector2i(4, 3)) == [tid], "objects_at wrong")
	_expect(p.distance(Vector2i(2, 2), Vector2i(4, 3)) == 3, "manhattan distance wrong")
	_expect(p.player_cell() == Vector2i(2, 2), "player_cell wrong")

	# roll_check: the ability modifier dominates at the extremes — str 20 (mod +5)
	# vs DC 1 always passes, vs DC 100 always fails.
	_expect(p.roll_check("player", "str", 1), "trivial check should pass")
	_expect(not p.roll_check("player", "str", 100), "impossible check should fail")

	# garbage args never crash, just fail safely
	_expect(p.get_prop("nope", "hp", -1) == -1, "get_prop on missing id should return default")
	_expect(not p.move_to("nope", Vector2i(3, 3)), "move on missing id should fail")
	_expect(not p.despawn("nope"), "despawn missing id should fail")

	# JSON round-trip preserves the registry
	var snapshot: String = World.to_json()
	World.clear()
	_expect(not p.exists(tid), "clear did not empty registry")
	_expect(World.from_json(snapshot), "from_json failed to parse")
	_expect(p.exists(tid), "round-trip lost the object")
	_expect(p.get_object(tid)["cell"] == Vector2i(4, 3), "round-trip lost the cell")

	print("\n===== PRIMITIVES TEST =====")
	if _fails.is_empty():
		print("ALL PASS")
	else:
		for f in _fails:
			print("FAIL  " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
