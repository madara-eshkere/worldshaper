extends Node
## World State registry (ADR-0013): the single source of truth about the world —
## a plain id->object dictionary that serializes straight to JSON. Godot nodes are
## views synced from the signals below. Only Primitives should mutate this.
##
## Object shape: { "type": String, "cell": Vector2i, "props": Dictionary,
##                 "tags": Array[String] }

signal object_added(id: String)
signal object_moved(id: String)
signal object_removed(id: String)
signal object_changed(id: String)

var objects: Dictionary = {}


func clear() -> void:
	objects.clear()


func has(id: String) -> bool:
	return objects.has(id)


func add_object(id: String, type: String, cell: Vector2i,
		props: Dictionary = {}, tags: Array = []) -> void:
	objects[id] = {
		"type": type,
		"cell": cell,
		"props": props.duplicate(true),
		"tags": tags.duplicate(),
	}
	object_added.emit(id)


func remove_object(id: String) -> void:
	if objects.erase(id):
		object_removed.emit(id)


func get_copy(id: String) -> Dictionary:
	return objects[id].duplicate(true) if objects.has(id) else {}


## Internal ref for Primitives — external code must go through Primitives, not this.
func raw(id: String) -> Dictionary:
	return objects.get(id, {})


func set_cell(id: String, cell: Vector2i) -> void:
	if objects.has(id):
		objects[id]["cell"] = cell
		object_moved.emit(id)


func set_prop(id: String, key: String, value: Variant) -> void:
	if objects.has(id):
		objects[id]["props"][key] = value
		object_changed.emit(id)


func to_json() -> String:
	var out := {}
	for id in objects:
		var o: Dictionary = objects[id]
		out[id] = {
			"type": o["type"],
			"cell": [o["cell"].x, o["cell"].y],
			"props": o["props"],
			"tags": o["tags"],
		}
	return JSON.stringify(out)


func from_json(text: String) -> bool:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	clear()
	for id in parsed:
		var o: Dictionary = parsed[id]
		var c: Array = o.get("cell", [0, 0])
		add_object(id, o.get("type", ""), Vector2i(int(c[0]), int(c[1])),
				o.get("props", {}), o.get("tags", []))
	return true
