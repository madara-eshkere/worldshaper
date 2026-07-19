extends Node
## Headless test for combat + inventory (#7). Outcomes are made deterministic with
## extreme stats (str 30 vs def 1 = always hit; str 1 vs def 100 = always miss).
##   godot --headless --path game res://tests/test_combat.tscn

var _events: Array[String] = []
var _fails: Array[String] = []
var _prim
var _player: Node2D
var _grid: Node2D


func _ready() -> void:
	EventBus.game_event.connect(func(n: String, _d: Dictionary): _events.append(n))
	_grid = load("res://scripts/world_grid.gd").new()
	add_child(_grid)
	_prim = load("res://scripts/primitives.gd").new(_grid, 7)
	var enemies: Node = load("res://scripts/enemy_controller.gd").new()
	add_child(enemies)
	enemies.setup(_prim)
	_player = load("res://scripts/player.gd").new()
	add_child(_player)

	# 1 — bump-to-attack: a hit kills the goblin, and the player does not move.
	_setup_player(Vector2i(5, 5), {"str": 30, "atk": 5, "hp": 10, "def": 10})
	_prim.spawn("enemy", Vector2i(6, 5), {"hp": 5, "def": 1, "atk": 3, "str": 1}, ["enemy", "blocking"])
	_events.clear()
	_player._try_step(Vector2i.RIGHT)
	_expect(_player.cell == Vector2i(5, 5), "1 attacker should not move onto the enemy")
	_expect(_enemy_hp() <= 0, "1 enemy should be dead (hp=%d)" % _enemy_hp())
	_expect(_events.has("player_attacked"), "1 expected player_attacked")
	_expect(_events.has("died"), "1 expected died")

	# 2 — the enemy attacks on its turn: the player takes damage.
	_setup_player(Vector2i(5, 5), {"str": 1, "atk": 1, "hp": 10, "def": 1})
	_prim.spawn("enemy", Vector2i(6, 5), {"hp": 10, "str": 30, "atk": 3, "def": 20}, ["enemy", "blocking"])
	_events.clear()
	_player._wait()  # player turn ends -> adjacent enemy attacks
	_expect(int(_prim.get_prop("player", "hp")) == 7, "2 player hp should be 7 (10-3)")
	_expect(_events.has("attack"), "2 expected an attack event")

	# 3 — a distant enemy steps toward the player.
	_setup_player(Vector2i(5, 5), {"str": 1, "atk": 1, "hp": 10, "def": 1})
	var eid: String = _prim.spawn("enemy", Vector2i(10, 5), {"hp": 10, "str": 1, "atk": 1, "def": 1}, ["enemy", "blocking"])
	_player._wait()
	_expect(_prim.get_object(eid)["cell"] == Vector2i(9, 5), "3 enemy should step toward the player")

	# 4 — the player can die.
	_setup_player(Vector2i(5, 5), {"str": 1, "atk": 1, "hp": 3, "def": 1})
	_prim.spawn("enemy", Vector2i(6, 5), {"hp": 10, "str": 30, "atk": 5, "def": 20}, ["enemy", "blocking"])
	_events.clear()
	_player._wait()
	_expect(int(_prim.get_prop("player", "hp")) <= 0, "4 player should be dead")
	_expect(_events.has("player_died"), "4 expected player_died")

	# 5 — walking onto an item picks it up.
	_setup_player(Vector2i(5, 5), {"str": 5, "atk": 2, "hp": 10, "def": 10})
	var iid: String = _prim.spawn("item", Vector2i(6, 5), {"name": "зелье", "heal": 5}, ["item"])
	_events.clear()
	_player._try_step(Vector2i.RIGHT)
	_expect(_player.cell == Vector2i(6, 5), "5 player should move onto the item cell")
	_expect(not _prim.exists(iid), "5 item should be despawned after pickup")
	_expect((_prim.get_prop("player", "inventory", []) as Array).size() == 1, "5 inventory should hold 1 item")
	_expect(_events.has("picked_up"), "5 expected picked_up")

	# 6 — using a potion heals and consumes it.
	_setup_player(Vector2i(5, 5), {"str": 5, "atk": 2, "hp": 5, "hp_max": 10, "def": 10})
	_prim.set_prop("player", "inventory", [{"name": "зелье", "heal": 5}])
	_events.clear()
	_player._use_item()
	_expect(int(_prim.get_prop("player", "hp")) == 10, "6 potion should heal to 10")
	_expect((_prim.get_prop("player", "inventory", []) as Array).is_empty(), "6 potion should be consumed")
	_expect(_events.has("used_item"), "6 expected used_item")

	print("\n===== COMBAT TEST =====")
	if _fails.is_empty():
		print("ALL PASS")
	else:
		for f in _fails:
			print("FAIL  " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _setup_player(cell: Vector2i, props: Dictionary) -> void:
	World.clear()
	World.add_object("player", "player", cell, props, [])
	if not props.has("inventory"):
		_prim.set_prop("player", "inventory", [])
	_player.setup(_grid, _prim)


func _enemy_hp() -> int:
	var ids: Array = _prim.find_by_tag("enemy")
	return int(_prim.get_prop(ids[0], "hp", 0)) if not ids.is_empty() else -999


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
