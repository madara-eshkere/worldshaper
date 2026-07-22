extends Node
## Headless test for the Character Sheet + d20 helpers + the roll_check Primitive.
## Runs as a scene so the World autoload is live.
##   godot --headless --path game res://tests/test_character_sheet.tscn

const D20 = preload("res://scripts/d20.gd")
const CharacterSheet = preload("res://scripts/character_sheet.gd")

var _events: Array[String] = []
var _fails: Array[String] = []


func _ready() -> void:
	EventBus.game_event.connect(func(n: String, _d: Dictionary): _events.append(n))
	var p = load("res://scripts/primitives.gd").new(999)

	# d20 modifier formula
	_expect(D20.ability_mod(10) == 0, "mod(10) should be 0")
	_expect(D20.ability_mod(14) == 2, "mod(14) should be +2")
	_expect(D20.ability_mod(8) == -1, "mod(8) should be -1")
	_expect(D20.ability_mod(20) == 5, "mod(20) should be +5")
	_expect(D20.ability_mod(1) == -5, "mod(1) should be -5")

	# create_default builds a full sheet in the World "player" object
	World.clear()
	CharacterSheet.create_default(Vector2i(2, 2))
	_expect(World.has("player"), "create_default did not make a player")
	var props: Dictionary = World.raw("player")["props"]
	_expect(props.get("race") == "human", "wrong race")
	_expect(props.get("class") == "adventurer", "wrong class")
	_expect(int(props.get("level")) == 1, "wrong level")
	for a in CharacterSheet.ABILITIES:
		_expect(props.has(a), "missing ability %s" % a)

	# HP derives from class base + CON modifier * level (adventurer 10, con 14 → 12)
	_expect(CharacterSheet.hp_for("adventurer", 14, 1) == 12, "hp_for adventurer/con14/l1")
	_expect(int(props.get("hp_max")) == 12, "player hp_max should be 12")
	_expect(int(props.get("hp")) == 12, "player hp should start full")
	_expect(CharacterSheet.modifier("player", "con") == 2, "con modifier should be +2")

	# roll_check uses the ability modifier: con +2 vs DC 1 always passes, vs 100 fails
	_expect(p.roll_check("player", "con", 1), "trivial con check should pass")
	_expect(not p.roll_check("player", "con", 100), "impossible con check should fail")

	# grant_xp levels up: 100 XP → level 2, HP recomputed, level_up event fires
	_events.clear()
	CharacterSheet.grant_xp("player", 100)
	props = World.raw("player")["props"]
	_expect(int(props.get("level")) == 2, "should be level 2 after 100 XP")
	_expect(int(props.get("hp_max")) == 14, "hp_max should be 14 at level 2 (10 + 2*2)")
	_expect(_events.has("level_up"), "level_up event should fire")

	print("\n===== CHARACTER SHEET TEST =====")
	if _fails.is_empty():
		print("ALL PASS")
	else:
		for f in _fails:
			print("FAIL  " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
