extends Node
## World State registry (ADR-0013): the single source of truth about the world —
## objects AND the tile map — serialized straight to JSON. Godot nodes are views
## synced from the signals below. Only Primitives should mutate this. The map lives
## here (not in the grid view) so the Director can generate it as data (M2).
##
## Object shape: { "type": String, "cell": Vector2i, "props": Dictionary,
##                 "tags": Array[String] }
## Tiles: 0 = floor, 1 = wall (indexed y*map_w + x).

signal object_added(id: String)
signal object_moved(id: String)
signal object_removed(id: String)
signal object_changed(id: String)
signal map_changed()

var objects: Dictionary = {}
var map_w := 0
var map_h := 0
var _tiles := PackedByteArray()


func clear() -> void:
	objects.clear()
	map_w = 0
	map_h = 0
	_tiles = PackedByteArray()


# --- Tile map (terrain data) ---

func set_map(w: int, h: int, tiles: PackedByteArray) -> void:
	map_w = w
	map_h = h
	_tiles = tiles
	map_changed.emit()


func map_size() -> Vector2i:
	return Vector2i(map_w, map_h)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < map_w and cell.y < map_h


func is_wall(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return true
	return _tiles[cell.y * map_w + cell.x] != 0


func is_walkable(cell: Vector2i) -> bool:
	return in_bounds(cell) and _tiles[cell.y * map_w + cell.x] == 0


# --- Objects ---

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


# --- Serialization (map + objects) ---

func to_json() -> String:
	var objs := {}
	for id in objects:
		var o: Dictionary = objects[id]
		objs[id] = {
			"type": o["type"],
			"cell": [o["cell"].x, o["cell"].y],
			"props": o["props"],
			"tags": o["tags"],
		}
	return JSON.stringify({
		"map": {"w": map_w, "h": map_h, "tiles": Array(_tiles)},
		"objects": objs,
	})


func from_json(text: String) -> bool:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("objects"):
		return false
	clear()
	var m: Dictionary = parsed.get("map", {})
	var tiles := PackedByteArray()
	for t in m.get("tiles", []):
		tiles.append(int(t))
	set_map(int(m.get("w", 0)), int(m.get("h", 0)), tiles)
	for id in parsed["objects"]:
		var o: Dictionary = parsed["objects"][id]
		var c: Array = o.get("cell", [0, 0])
		add_object(id, o.get("type", ""), Vector2i(int(c[0]), int(c[1])),
				o.get("props", {}), o.get("tags", []))
	return true
