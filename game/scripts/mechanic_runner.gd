extends RefCounted
## Trusted interpreter for Mechanics (ADR-0014). A Mechanic is DATA, never code:
##   { "id": String, "steps": [ {"prim": <name>, "args": [...]}, ... ] }
## Each step is a call to a vanilla Primitive. Args may reference the run context
## with "$name" tokens ("$actor", "$cell", "$target", "$data"). Only names in
## Primitives.PRIMITIVE_NAMES are callable — a Mechanic can never reach engine
## internals, only the vanilla alphabet.

var _prim


func _init(primitives) -> void:
	_prim = primitives


## Run every step in order. Returns false (and emits mechanic_error) on the first
## bad step, leaving earlier steps applied — Mechanics should be written so partial
## application is safe, same as the Primitives' own safe-failure contract.
func run(mechanic: Dictionary, ctx: Dictionary = {}) -> bool:
	for step in mechanic.get("steps", []):
		if not _run_step(step, ctx):
			return false
	return true


func _run_step(step: Dictionary, ctx: Dictionary) -> bool:
	var name: String = step.get("prim", "")
	if name not in _prim.PRIMITIVE_NAMES:
		_prim.emit("mechanic_error", {"reason": "unknown primitive '%s'" % name})
		return false
	_prim.callv(name, _resolve(step.get("args", []), ctx))
	return true


func _resolve(args: Array, ctx: Dictionary) -> Array:
	var out: Array = []
	for a in args:
		out.append(_resolve_one(a, ctx))
	return out


func _resolve_one(a: Variant, ctx: Dictionary) -> Variant:
	# "$name" pulls from ctx; a plain value passes through. Dictionaries are
	# resolved recursively so an emit's data payload can carry context too.
	if a is String and a.begins_with("$"):
		return ctx.get(a.substr(1), a)
	if a is Dictionary:
		var d := {}
		for k in a:
			d[k] = _resolve_one(a[k], ctx)
		return d
	return a
