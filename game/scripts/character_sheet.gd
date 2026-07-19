extends RefCounted
## Character Sheet — deterministic player stats (race, class, level, XP, HP, six
## d20 abilities). VISIBLE to the player (ADR-0008 amended: only the dice are
## hidden, not the sheet). Stored in the World "player" object's props, the single
## source of truth (ADR-0013). Static helpers; preload, not an autoload.

const D20 = preload("res://scripts/d20.gd")

# Simplified d20 abilities (user 2026-07-18): WIS folded into INT (it would only
# have driven a manapool), PER added because this is a top-down trap-heavy game.
const ABILITIES := ["str", "dex", "con", "int", "cha", "per"]
const CLASS_BASE_HP := {"adventurer": 10, "warrior": 12, "rogue": 8, "mage": 6}
const XP_PER_LEVEL := 100


## M1 hardcoded hero. M2 replaces this with the creation form (race/class + free
## points) and generated lore/traits.
static func create_default(cell: Vector2i = Vector2i(2, 2)) -> void:
	var abilities := {"str": 13, "dex": 12, "con": 14, "int": 11, "cha": 10, "per": 12}
	create("player", "human", "adventurer", abilities, 1, cell)


static func create(id: String, race: String, cls: String, abilities: Dictionary,
		level: int, cell: Vector2i) -> void:
	var props := {"race": race, "class": cls, "level": level, "xp": 0}
	for a in ABILITIES:
		props[a] = int(abilities.get(a, 10))
	var hp := hp_for(cls, int(props["con"]), level)
	props["hp_max"] = hp
	props["hp"] = hp
	# Derived combat stats + empty inventory (used by combat.gd / pickups, #7).
	props["atk"] = 2 + D20.ability_mod(int(props["str"]))
	props["def"] = 10 + D20.ability_mod(int(props["dex"]))
	props["inventory"] = []
	if World.has(id):
		for k in props:
			World.set_prop(id, k, props[k])
	else:
		World.add_object(id, "player", cell, props, [])


static func hp_for(cls: String, con_score: int, level: int) -> int:
	var base := int(CLASS_BASE_HP.get(cls, 10))
	return maxi(1, base + D20.ability_mod(con_score) * level)


static func modifier(id: String, ability: String) -> int:
	if not World.has(id):
		return 0
	return D20.ability_mod(int(World.raw(id)["props"].get(ability, 10)))


static func grant_xp(id: String, amount: int) -> void:
	if not World.has(id) or amount <= 0:
		return
	var props: Dictionary = World.raw(id)["props"]
	var xp := int(props.get("xp", 0)) + amount
	World.set_prop(id, "xp", xp)
	var new_level := 1 + int(xp / float(XP_PER_LEVEL))
	if new_level > int(props.get("level", 1)):
		_level_up(id, new_level)


static func _level_up(id: String, new_level: int) -> void:
	var props: Dictionary = World.raw(id)["props"]
	World.set_prop(id, "level", new_level)
	var hp := hp_for(str(props.get("class", "adventurer")), int(props.get("con", 10)), new_level)
	World.set_prop(id, "hp_max", hp)
	World.set_prop(id, "hp", hp)  # M1: full heal on level up
	EventBus.emit_game_event("level_up", {"level": new_level})
