extends Node
## Headless test for combat + the turn scheduler (mob AI). Player attacks are driven
## through Combat directly; mob turns through the scheduler. Deterministic via
## extreme stats (str 30 vs def 1 always hits). New unambiguous events:
## player_hit_enemy / enemy_hit_player / enemy_slain / player_died.
##   godot --headless --path game res://tests/test_combat.tscn

const Combat = preload("res://scripts/combat.gd")

var _events: Array[String] = []
var _fails: Array[String] = []
var _prim
var _sched: Node


func _ready() -> void:
	EventBus.game_event.connect(func(n: String, _d: Dictionary): _events.append(n))
	_prim = load("res://scripts/primitives.gd").new(7)
	_sched = load("res://scripts/turn_scheduler.gd").new()
	add_child(_sched)
	_sched.setup(_prim)

	# 1 — a player hit kills the goblin -> it becomes a corpse; clear events fire.
	_reset()
	World.add_object("player", "player", Vector2i(5, 5), {"str": 30, "atk": 5, "speed": 4}, [])
	var goblin: String = _prim.spawn("goblin", Vector2i(6, 5), {"hp": 5, "def": 1, "name": "гоблин"}, ["enemy", "blocking"])
	_events.clear()
	Combat.attack(_prim, "player", goblin)
	_expect(int(_prim.get_prop(goblin, "hp", 1)) <= 0, "1 goblin should be dead")
	var gt: Array = _prim.get_object(goblin).get("tags", [])
	_expect("corpse" in gt and not ("enemy" in gt) and not ("blocking" in gt), "1 slain enemy -> passable corpse")
	_expect(_events.has("player_hit_enemy"), "1 expected player_hit_enemy")
	_expect(_events.has("enemy_slain"), "1 expected enemy_slain")

	# 2 — an adjacent enemy attacks the player on its scheduled turn.
	_reset()
	World.add_object("player", "player", Vector2i(5, 5), {"def": 1, "hp": 20, "speed": 4}, [])
	_prim.spawn("goblin", Vector2i(6, 5), {"hp": 10, "atk": 3, "str": 30, "def": 20, "speed": 4}, ["enemy", "blocking"])
	_sched.start()
	_events.clear()
	_sched.player_acted()  # player spends a turn -> scheduler runs the enemy
	_expect(int(_prim.get_prop("player", "hp")) == 17, "2 enemy should hit for 3 (20->17)")
	_expect(_events.has("enemy_hit_player"), "2 expected enemy_hit_player")

	# 3 — a distant enemy steps one cell toward the player.
	_reset()
	World.add_object("player", "player", Vector2i(5, 5), {"def": 30, "hp": 20, "speed": 4}, [])
	var g3: String = _prim.spawn("goblin", Vector2i(10, 5), {"hp": 10, "def": 30, "speed": 4}, ["enemy", "blocking"])
	_sched.start()
	_sched.player_acted()
	_expect(_prim.get_object(g3)["cell"].x < 10, "3 enemy should step toward the player")

	# 4 — the player can die.
	_reset()
	World.add_object("player", "player", Vector2i(5, 5), {"def": 1, "hp": 3, "speed": 4}, [])
	_prim.spawn("goblin", Vector2i(6, 5), {"hp": 10, "atk": 5, "str": 30, "def": 20, "speed": 4}, ["enemy", "blocking"])
	_sched.start()
	_events.clear()
	_sched.player_acted()
	_expect(int(_prim.get_prop("player", "hp")) <= 0, "4 player should be dead")
	_expect(_events.has("player_died"), "4 expected player_died")

	# 5 — occupancy: an adjacent enemy attacks in place, never stacks on the player.
	_reset()
	World.add_object("player", "player", Vector2i(5, 5), {"def": 30, "hp": 20, "speed": 4}, [])
	var g5: String = _prim.spawn("goblin", Vector2i(6, 5), {"hp": 10, "str": 1, "atk": 1, "def": 30, "speed": 4}, ["enemy", "blocking"])
	_sched.start()
	_sched.player_acted()
	_expect(_prim.get_object(g5)["cell"] == Vector2i(6, 5), "5 adjacent enemy must not move onto the player")

	# 6 — flying: a bat glides over a pit; a goblin falls in and is stunned.
	_reset()
	World.add_object("player", "player", Vector2i(2, 2), {"def": 30, "hp": 20, "speed": 1}, [])
	_prim.spawn("pit", Vector2i(3, 2), {}, ["pit"])
	var bat: String = _prim.spawn("bat", Vector2i(4, 2), {"hp": 3, "def": 30, "str": 1, "speed": 1, "flying": true}, ["enemy", "blocking"])
	_sched.start()
	_sched.player_acted()  # bat steps (4,2)->(3,2 pit); flying -> no stun
	_expect(_prim.get_object(bat)["cell"] == Vector2i(3, 2), "6 bat should step onto the pit cell")
	_expect(int(_prim.get_prop(bat, "stunned_turns", 0)) == 0, "6 flyer should NOT be stunned by a pit")

	_reset()
	World.add_object("player", "player", Vector2i(2, 2), {"def": 30, "hp": 20, "speed": 1}, [])
	_prim.spawn("pit", Vector2i(3, 2), {}, ["pit"])
	var gob: String = _prim.spawn("goblin", Vector2i(4, 2), {"hp": 6, "def": 30, "str": 1, "speed": 1}, ["enemy", "blocking"])
	_sched.start()
	_sched.player_acted()
	_expect(int(_prim.get_prop(gob, "stunned_turns", 0)) == 2, "6 non-flyer should be stunned by the pit")

	print("\n===== COMBAT TEST =====")
	if _fails.is_empty():
		print("ALL PASS")
	else:
		for f in _fails:
			print("FAIL  " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _reset() -> void:
	World.clear()
	World.set_map(16, 10, load("res://tests/test_helpers.gd").bordered_map())


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
