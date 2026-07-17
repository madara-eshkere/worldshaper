extends SceneTree
## GO/NO-GO crux (ADR-0006): with a Sandbox NODE we own, can we bound execution
## so a guest cannot hang the engine? Load the shipped compiler ELF, set a low
## instruction budget, confirm the node accepts config and reports its limits.
## Hard OS timeout wraps this externally, so even a hang is a bounded outcome.
## Findings: docs/spikes/0001-godot-sandbox.md. Verdict: conditional GO.
## Run: godot --headless --path game --script res://tests/probe_sandbox_node.gd

func _init() -> void:
	var sb: Object = ClassDB.instantiate("Sandbox")
	print("PN created: %s" % (sb != null))

	# 1) limits + restrictions are settable BEFORE loading any program
	sb.call("set_instructions_max", 1)        # 1 = 1 million-insn budget unit
	sb.set("execution_timeout", 2)            # seconds, hard wall
	sb.set("restrictions", true)              # deny-all until whitelisted
	print("PN instructions_max=%s timeout=%s restrictions=%s" % [
		str(sb.call("get_instructions_max")),
		str(sb.get("execution_timeout")),
		str(sb.get("restrictions"))])

	# 2) load a real ELF program (the shipped compiler) to prove load path works
	var bytes := FileAccess.get_file_as_bytes("res://addons/godot_sandbox/gdscript.elf")
	print("PN elf bytes: %s" % bytes.size())
	sb.call("load_buffer", bytes)
	print("PN has_program_loaded: %s" % str(sb.call("has_program_loaded")))

	# 3) monitors are readable (this is how we detect a cut loop at runtime)
	print("PN monitor_calls_made=%s exceptions=%s timeouts=%s" % [
		str(sb.get("monitor_calls_made")),
		str(sb.get("monitor_exceptions")),
		str(sb.get("monitor_execution_timeouts"))])
	print("PN done")
	quit(0)
