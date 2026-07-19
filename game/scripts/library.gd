extends RefCounted
## The Vanilla Library (ADR-0014): Mechanics shipped in the build as data — ordered
## compositions of vanilla Primitives, never code. M1 seeds it by hand; from M2 the
## player's library grows via the Assembler/Creator. Provides id lookup for triggers
## and interactions.

var _mechanics: Dictionary = {}  # id -> mechanic data


func add(mechanic: Dictionary) -> void:
	_mechanics[mechanic.get("id", "")] = mechanic


func get_mechanic(id: String) -> Dictionary:
	return _mechanics.get(id, {})


func has(id: String) -> bool:
	return _mechanics.has(id)


func count() -> int:
	return _mechanics.size()
