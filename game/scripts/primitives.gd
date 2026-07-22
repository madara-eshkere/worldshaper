extends RefCounted
## Primitives — the fixed alphabet through which anything mutates the world
## (spec: docs/specs/primitives.md, ADR-0013). This object is what the sandbox
## whitelist exposes; sandboxed Mechanics may call ONLY these methods.
##
## Every method validates its arguments and returns a safe failure on garbage
## (false / "" / default) plus a `primitive_rejected` event — it must NEVER crash,
## because a guest can call it with anything.

const D20 = preload("res://scripts/d20.gd")

## The callable vanilla alphabet — the ONLY method names a Mechanic (data) may
## invoke through the interpreter (ADR-0014). Keep in sync with the funcs below.
const PRIMITIVE_NAMES := [
	"exists", "get_object", "get_prop", "objects_at", "find_by_tag", "is_walkable",
	"player_cell", "distance", "spawn", "despawn", "move_to", "set_prop", "add_tag",
	"remove_tag", "damage", "heal", "roll_check", "emit",
]

var _rng := RandomNumberGenerator.new()
var _next_id := 1


func _init(rng_seed: int = 0) -> void:
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()


# --- Query (read-only) ---

func exists(id: String) -> bool:
	return World.has(id)


func get_object(id: String) -> Dictionary:
	return World.get_copy(id)


func get_prop(id: String, key: String, default: Variant = null) -> Variant:
	if not World.has(id):
		return default
	return World.raw(id)["props"].get(key, default)


func objects_at(cell: Vector2i) -> Array:
	var out: Array = []
	for id in World.objects:
		if World.objects[id]["cell"] == cell:
			out.append(id)
	return out


func find_by_tag(tag: String) -> Array:
	var out: Array = []
	for id in World.objects:
		if tag in World.objects[id]["tags"]:
			out.append(id)
	return out


func is_walkable(cell: Vector2i) -> bool:
	return World.is_walkable(cell)


func player_cell() -> Vector2i:
	return World.raw("player").get("cell", Vector2i.ZERO)


func distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


# --- Spawn / remove ---

func spawn(type: String, cell: Vector2i, props: Dictionary = {}, tags: Array = []) -> String:
	if not World.is_walkable(cell):
		_reject("spawn on non-walkable cell %s" % cell)
		return ""
	var id := "%s_%d" % [type, _next_id]
	_next_id += 1
	World.add_object(id, type, cell, props, tags)
	return id


func despawn(id: String) -> bool:
	if not World.has(id):
		_reject("despawn missing id %s" % id)
		return false
	World.remove_object(id)
	return true


# --- Move ---

func move_to(id: String, cell: Vector2i) -> bool:
	if not World.has(id):
		_reject("move missing id %s" % id)
		return false
	if not World.is_walkable(cell):
		_reject("move %s onto non-walkable %s" % [id, cell])
		return false
	World.set_cell(id, cell)
	return true


# --- Modify ---

func set_prop(id: String, key: String, value: Variant) -> bool:
	if not World.has(id):
		_reject("set_prop missing id %s" % id)
		return false
	World.set_prop(id, key, value)
	return true


func add_tag(id: String, tag: String) -> bool:
	if not World.has(id):
		_reject("add_tag missing id %s" % id)
		return false
	var tags: Array = World.raw(id)["tags"]
	if tag not in tags:
		tags.append(tag)
		World.object_changed.emit(id)
	return true


func remove_tag(id: String, tag: String) -> bool:
	if not World.has(id):
		_reject("remove_tag missing id %s" % id)
		return false
	World.raw(id)["tags"].erase(tag)
	World.object_changed.emit(id)
	return true


func damage(id: String, amount: int) -> bool:
	if not World.has(id) or amount < 0:
		_reject("damage bad args %s %d" % [id, amount])
		return false
	var hp := int(get_prop(id, "hp", 0))
	World.set_prop(id, "hp", maxi(0, hp - amount))
	return true


func heal(id: String, amount: int) -> bool:
	if not World.has(id) or amount < 0:
		_reject("heal bad args %s %d" % [id, amount])
		return false
	var hp := int(get_prop(id, "hp", 0)) + amount
	var hp_max: Variant = get_prop(id, "hp_max", null)  # cap at hp_max if the object has one
	if hp_max != null:
		hp = mini(int(hp_max), hp)
	World.set_prop(id, "hp", hp)
	return true


# --- Rules / events ---

func roll_check(actor_id: String, ability: String, dc: int) -> bool:
	# Invisible dice (ADR-0008): d20 + ability modifier vs DC. The player sees
	# only the narrative outcome, never the roll. `ability` names a d20 stat
	# (str/dex/con/int/wis/cha); a missing actor defaults to a neutral score 10.
	var score := int(get_prop(actor_id, ability, 10))
	var roll := _rng.randi_range(1, 20)
	return roll + D20.ability_mod(score) >= dc


func emit(name: String, data: Dictionary = {}) -> void:
	EventBus.emit_game_event(name, data)


# --- internals ---

func _reject(reason: String) -> void:
	EventBus.emit_game_event("primitive_rejected", {"reason": reason})
