extends RefCounted
## The M1 hardcoded level (M2 has the Director generate this as scenario DATA —
## ADR-0015). A left room and a right room split by a wall with one doorway blocked
## by a table: unscrew it with the screwdriver, cross, deal with the goblin, reach
## the exit. Seeds the Vanilla Library and wires the pit trigger, the interaction,
## and the win predicate. Zero LLM.

const Bestiary = preload("res://scripts/bestiary.gd")

const W := 16
const H := 10
const DIVIDER_X := 8
const DOORWAY_Y := 4

const START := Vector2i(2, 2)
const EXIT := Vector2i(14, 4)
const TABLE_CELL := Vector2i(8, 4)   # the doorway in the divider wall
const PIT_CELL := Vector2i(5, 6)


static func build(prim, triggers, library, interactions, win) -> void:
	_build_map()
	_seed_library(library)

	prim.spawn("item", Vector2i(4, 3), {"name": "отвёртка", "item_key": "screwdriver"}, ["item"])
	prim.spawn("pit", PIT_CELL, {}, ["pit"])
	prim.spawn("table", TABLE_CELL, {"name": "стол"}, ["table", "interactable", "blocking"])
	# Creatures from the bestiary (data-driven). Goblin: slower than the player.
	# Bat: fast flyer (speed 8) — acts more often and glides over pits.
	Bestiary.spawn(prim, "goblin", Vector2i(11, 5))
	Bestiary.spawn(prim, "bat", Vector2i(12, 7))
	prim.spawn("item", Vector2i(11, 2), {"name": "зелье лечения", "heal": 5}, ["item"])
	prim.spawn("exit", EXIT, {"name": "выход"}, ["exit"])

	triggers.register_trigger({
		"on": "player_moved", "if": {"cell_has_tag": "pit"},
		"mechanic": library.get_mechanic("pit_fall"),
	})
	triggers.register_escalation({
		"id": "pit_frustration", "watch": "fell_into_pit", "threshold": 3, "emit": "pit_escalation",
	})

	interactions.register({"needs_tag": "table", "needs_item": "screwdriver", "mechanic": "unscrew_table"})

	win.set_predicate({"player_at": EXIT})


## Author the tile map as DATA in World State (M2: the Director generates this).
## Border walls + an interior divider with one doorway (which the table blocks).
static func _build_map() -> void:
	var tiles := PackedByteArray()
	tiles.resize(W * H)
	for y in H:
		for x in W:
			var wall := (x == 0 or y == 0 or x == W - 1 or y == H - 1) \
					or (x == DIVIDER_X and y != DOORWAY_Y)
			tiles[y * W + x] = 1 if wall else 0
	World.set_map(W, H, tiles)


## Seed the Vanilla Library. Two Mechanics are wired to this level (pit_fall,
## unscrew_table); the rest are base interaction recipes available to future
## levels — the library is meant to grow (ADR-0014).
static func _seed_library(library) -> void:
	library.add({"id": "pit_fall", "steps": [
		{"prim": "set_prop", "args": ["$actor", "stunned_turns", 2]},
		{"prim": "set_prop", "args": ["$actor", "in_pit", true]},
		{"prim": "set_prop", "args": ["$target", "revealed", true]},
		{"prim": "emit", "args": ["fell_into_pit", {"stun_turns": 2}]},
	]})
	library.add({"id": "unscrew_table", "steps": [
		{"prim": "despawn", "args": ["$target"]},
		{"prim": "emit", "args": ["unscrewed_table", {}]},
	]})
	# Base interaction recipes (data, not code) for future levels.
	library.add({"id": "open_container", "steps": [
		{"prim": "add_tag", "args": ["$target", "open"]},
		{"prim": "emit", "args": ["opened", {"what": "$target"}]}]})
	library.add({"id": "break_object", "steps": [
		{"prim": "add_tag", "args": ["$target", "broken"]},
		{"prim": "remove_tag", "args": ["$target", "blocking"]},
		{"prim": "emit", "args": ["broke", {"what": "$target"}]}]})
	library.add({"id": "light_flammable", "steps": [
		{"prim": "add_tag", "args": ["$target", "burning"]},
		{"prim": "emit", "args": ["ignited", {"what": "$target"}]}]})
	library.add({"id": "douse_fire", "steps": [
		{"prim": "remove_tag", "args": ["$target", "burning"]},
		{"prim": "emit", "args": ["doused", {"what": "$target"}]}]})
	library.add({"id": "push_object", "steps": [
		{"prim": "emit", "args": ["pushed", {"what": "$target"}]}]})
	library.add({"id": "cut_rope", "steps": [
		{"prim": "despawn", "args": ["$target"]},
		{"prim": "emit", "args": ["cut", {}]}]})
	library.add({"id": "pour_liquid", "steps": [
		{"prim": "add_tag", "args": ["$target", "wet"]},
		{"prim": "remove_tag", "args": ["$target", "burning"]},
		{"prim": "emit", "args": ["poured", {"what": "$target"}]}]})
	library.add({"id": "pry_open", "steps": [
		{"prim": "remove_tag", "args": ["$target", "blocking"]},
		{"prim": "add_tag", "args": ["$target", "open"]},
		{"prim": "emit", "args": ["pried", {"what": "$target"}]}]})
	library.add({"id": "heal_self", "steps": [
		{"prim": "heal", "args": ["$actor", 3]},
		{"prim": "emit", "args": ["healed", {}]}]})
