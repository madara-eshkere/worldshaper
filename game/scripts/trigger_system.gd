extends Node
## Reflexes (ADR-0009/0011): Scripted Triggers + Escalations, all data-driven,
## zero LLM. A Trigger maps an event to a Mechanic that runs instantly in-engine.
## An Escalation is a deterministic counter that fires after a threshold — this is
## how "importance" is decided at runtime without an Observer model.
##
## Trigger:    { "on": <event>, "if": <condition?>, "mechanic": <Mechanic> }
## Escalation: { "id": String, "watch": <event>, "if": <condition?>,
##               "threshold": int, "mechanic": <Mechanic?>, "emit": <event?> }
## Condition (M1): { "cell_has_tag": <tag> } — evaluated against the event's cell.

const MAX_DEPTH := 8  # guard against a Mechanic emitting into its own trigger

var _prim
var _runner
var _triggers: Array[Dictionary] = []
var _escalations: Array[Dictionary] = []
var _counters: Dictionary = {}
var _depth := 0


func setup(primitives, runner) -> void:
	_prim = primitives
	_runner = runner
	EventBus.game_event.connect(_on_event)


func register_trigger(t: Dictionary) -> void:
	_triggers.append(t)


func register_escalation(e: Dictionary) -> void:
	_escalations.append(e)
	_counters[e.get("id", "")] = 0


func counter(id: String) -> int:
	return int(_counters.get(id, 0))


func _on_event(name: String, data: Dictionary) -> void:
	if _depth >= MAX_DEPTH:
		return
	_depth += 1
	# Iterate copies: a Mechanic may emit events that re-enter this handler.
	for t in _triggers.duplicate():
		if t.get("on") == name and _cond_ok(t.get("if"), data):
			_runner.run(t.get("mechanic", {}), _ctx(data))
	for e in _escalations.duplicate():
		if e.get("watch") == name and _cond_ok(e.get("if"), data):
			_tick_escalation(e, data)
	_depth -= 1


func _tick_escalation(e: Dictionary, data: Dictionary) -> void:
	var id: String = e.get("id", "")
	_counters[id] = int(_counters.get(id, 0)) + 1
	if _counters[id] >= int(e.get("threshold", 1)):
		_counters[id] = 0
		if e.has("mechanic"):
			_runner.run(e["mechanic"], _ctx(data))
		if e.has("emit"):
			_prim.emit(e["emit"], {"escalation": id})


func _ctx(data: Dictionary) -> Dictionary:
	var ctx := {"actor": "player", "data": data}
	if data.has("cell_x") and data.has("cell_y"):
		var cell := Vector2i(int(data["cell_x"]), int(data["cell_y"]))
		ctx["cell"] = cell
		# First non-player object on that cell — handy as "$target".
		for id in _prim.objects_at(cell):
			if id != "player":
				ctx["target"] = id
				break
	return ctx


func _cond_ok(cond: Variant, data: Dictionary) -> bool:
	if cond == null:
		return true
	if cond is Dictionary and cond.has("cell_has_tag"):
		var cell := Vector2i(int(data.get("cell_x", -9999)), int(data.get("cell_y", -9999)))
		for id in _prim.objects_at(cell):
			if cond["cell_has_tag"] in _prim.get_object(id).get("tags", []):
				return true
		return false
	return true
