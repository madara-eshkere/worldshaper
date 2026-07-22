extends Node
## Headless test for the M1 level (#8): library seed, exit reachability, the table
## gate + screwdriver interaction, and the formal win condition. Proves the level is
## completable with zero LLM.
##   godot --headless --path game res://tests/test_level.tscn

const Level = preload("res://scripts/level.gd")
const WinCondition = preload("res://scripts/win_condition.gd")

var _events: Array[String] = []
var _fails: Array[String] = []
var _prim
var _player: Node2D
var _grid: Node2D


func _ready() -> void:
	EventBus.game_event.connect(func(n: String, _d: Dictionary): _events.append(n))
	_grid = load("res://scripts/world_grid.gd").new()
	add_child(_grid)
	World.clear()
	World.add_object("player", "player", Level.START, {"inventory": [], "str": 10}, [])

	_prim = load("res://scripts/primitives.gd").new(3)
	var runner = load("res://scripts/mechanic_runner.gd").new(_prim)
	var library = load("res://scripts/library.gd").new()
	var triggers: Node = load("res://scripts/trigger_system.gd").new()
	add_child(triggers)
	triggers.setup(_prim, runner)
	var interactions: Node = load("res://scripts/interaction_system.gd").new()
	add_child(interactions)
	interactions.setup(_prim, runner, library)
	var win: Node = load("res://scripts/win_condition.gd").new()
	add_child(win)
	win.setup(_prim)

	Level.build(_prim, triggers, library, interactions, win)

	_player = load("res://scripts/player.gd").new()
	add_child(_player)
	_player.setup(_grid, _prim)

	# library seeded, incl. the two Mechanics this level wires
	_expect(library.count() >= 10, "library should be seeded (count=%d)" % library.count())
	_expect(library.has("pit_fall"), "library missing pit_fall")
	_expect(library.has("unscrew_table"), "library missing unscrew_table")

	# geometry is solvable: the exit is reachable from the start (Validator check)
	_expect(WinCondition.reachable(World.is_walkable, Level.START, Level.EXIT, World.map_w, World.map_h),
			"exit should be reachable over walkable cells")

	# the table blocks the doorway: stepping into it is a no-op, not a move
	_place(Vector2i(7, 4))
	_events.clear()
	_player._try_step(Vector2i.RIGHT)  # into the table at (8,4)
	_expect(_player.cell == Vector2i(7, 4), "table should block movement")
	_expect(_events.has("bumped_object"), "expected bumped_object at the table")

	# without the screwdriver, interacting does nothing to the table
	_place(Vector2i(7, 4))
	_events.clear()
	EventBus.emit_game_event("player_interacted", {})
	_expect(not _events.has("unscrewed_table"), "table should not unscrew without the screwdriver")
	_expect(not _prim.find_by_tag("table").is_empty(), "table should still be there")

	# with the screwdriver, interacting unscrews the table and clears the doorway
	_prim.set_prop("player", "inventory", [{"name": "отвёртка", "item_key": "screwdriver"}])
	_events.clear()
	EventBus.emit_game_event("player_interacted", {})
	_expect(_events.has("unscrewed_table"), "expected unscrewed_table")
	_expect(_prim.find_by_tag("table").is_empty(), "table should be despawned after unscrewing")

	# now the doorway is passable
	_place(Vector2i(7, 4))
	_player._try_step(Vector2i.RIGHT)
	_expect(_player.cell == Vector2i(8, 4), "player should pass through the cleared doorway")

	# win: reaching the exit completes the level; not before
	_place(Vector2i(13, 4))
	_events.clear()
	EventBus.emit_game_event("player_moved", {"cell_x": 13, "cell_y": 4})
	_expect(not _events.has("level_complete"), "level should not complete before the exit")
	_place(Level.EXIT)
	EventBus.emit_game_event("player_moved", {"cell_x": Level.EXIT.x, "cell_y": Level.EXIT.y})
	_expect(_events.has("level_complete"), "reaching the exit should complete the level")

	print("\n===== LEVEL TEST =====")
	if _fails.is_empty():
		print("ALL PASS")
	else:
		for f in _fails:
			print("FAIL  " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _place(cell: Vector2i) -> void:
	World.set_cell("player", cell)
	_player.cell = cell


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
