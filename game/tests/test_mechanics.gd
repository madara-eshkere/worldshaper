extends Node
## Headless test for the Mechanic interpreter + Trigger/Escalation system (ADR-0014).
##   godot --headless --path game res://tests/test_mechanics.tscn

var _events: Array[String] = []
var _fails: Array[String] = []


func _ready() -> void:
	EventBus.game_event.connect(func(n: String, _d: Dictionary): _events.append(n))
	var prim = load("res://scripts/primitives.gd").new(42)
	var runner = load("res://scripts/mechanic_runner.gd").new(prim)
	var triggers: Node = load("res://scripts/trigger_system.gd").new()
	add_child(triggers)
	triggers.setup(prim, runner)

	World.clear()
	World.set_map(16, 10, load("res://tests/test_helpers.gd").bordered_map())
	World.add_object("player", "player", Vector2i(2, 2), {"hp": 10}, [])

	# --- interpreter: steps run as Primitive calls, $vars resolve from ctx ---
	var mech := {"id": "hurt_actor", "steps": [
		{"prim": "damage", "args": ["$actor", 3]},
		{"prim": "set_prop", "args": ["$actor", "marked", true]},
		{"prim": "emit", "args": ["mech_done", {"who": "$actor"}]},
	]}
	_events.clear()
	var ok: bool = runner.run(mech, {"actor": "player"})
	_expect(ok, "runner.run returned false")
	_expect(int(prim.get_prop("player", "hp")) == 7, "damage step: hp should be 7")
	_expect(prim.get_prop("player", "marked") == true, "set_prop step did not apply")
	_expect(_events.has("mech_done"), "emit step did not fire")

	# --- interpreter: unknown primitive is refused, not executed ---
	_events.clear()
	var bad: bool = runner.run({"steps": [{"prim": "delete_everything", "args": []}]}, {})
	_expect(not bad, "unknown primitive should make run() fail")
	_expect(_events.has("mechanic_error"), "unknown primitive should emit mechanic_error")

	# --- trigger: fires its Mechanic only when the condition matches ---
	prim.spawn("pit", Vector2i(5, 5), {}, ["pit"])  # a pit tile at (5,5)
	triggers.register_trigger({
		"on": "player_moved",
		"if": {"cell_has_tag": "pit"},
		"mechanic": {"steps": [{"prim": "set_prop", "args": ["$actor", "fell", true]}]},
	})
	# stepping onto a non-pit cell: trigger must NOT fire
	EventBus.emit_game_event("player_moved", {"cell_x": 6, "cell_y": 6})
	_expect(prim.get_prop("player", "fell", false) == false, "trigger fired on a non-pit cell")
	# stepping onto the pit cell: trigger fires, mechanic runs
	EventBus.emit_game_event("player_moved", {"cell_x": 5, "cell_y": 5})
	_expect(prim.get_prop("player", "fell", false) == true, "trigger did not fire on the pit cell")

	# --- escalation: counter fires after the threshold, then resets ---
	triggers.register_escalation({"id": "boom3", "watch": "boom", "threshold": 3, "emit": "escalated"})
	_events.clear()
	EventBus.emit_game_event("boom", {})
	EventBus.emit_game_event("boom", {})
	_expect(not _events.has("escalated"), "escalation fired before threshold")
	_expect(triggers.counter("boom3") == 2, "escalation counter should be 2")
	EventBus.emit_game_event("boom", {})
	_expect(_events.has("escalated"), "escalation did not fire at threshold")
	_expect(triggers.counter("boom3") == 0, "escalation counter should reset to 0")

	print("\n===== MECHANICS TEST =====")
	if _fails.is_empty():
		print("ALL PASS")
	else:
		for f in _fails:
			print("FAIL  " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
