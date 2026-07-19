extends Node
## Contextual interaction (the game's signature loop): pressing interact (E) near an
## object looks up an applicable vanilla Mechanic in the Library given what the
## player is holding, and runs it through the trusted interpreter. M1 uses hardcoded
## rules; M2+ the Assembler picks the Mechanic. Zero LLM here.
##
## Rule: { "needs_tag": <target tag>, "needs_item": <item_key?>, "mechanic": <id> }

var _prim
var _runner
var _library
var _rules: Array[Dictionary] = []


func setup(prim, runner, library) -> void:
	_prim = prim
	_runner = runner
	_library = library
	EventBus.game_event.connect(_on_event)


func register(rule: Dictionary) -> void:
	_rules.append(rule)


func _on_event(name: String, _data: Dictionary) -> void:
	if name == "player_interacted":
		_try_interact()


func _try_interact() -> void:
	var here: Vector2i = _prim.player_cell()
	var held := _held_keys()
	for c in [here, here + Vector2i.UP, here + Vector2i.DOWN, here + Vector2i.LEFT, here + Vector2i.RIGHT]:
		for oid in _prim.objects_at(c):
			var tags: Array = _prim.get_object(oid).get("tags", [])
			for r in _rules:
				var need_item: String = r.get("needs_item", "")
				if r.get("needs_tag", "") in tags and (need_item == "" or need_item in held):
					_runner.run(_library.get_mechanic(r.get("mechanic", "")),
							{"actor": "player", "target": oid, "cell": c})
					return


func _held_keys() -> Array:
	var keys: Array = []
	for item in _prim.get_prop("player", "inventory", []):
		if item is Dictionary and item.has("item_key"):
			keys.append(item["item_key"])
	return keys
