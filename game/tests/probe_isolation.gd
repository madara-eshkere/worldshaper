extends SceneTree
## Minimal isolation probe (ADR-0006). Question: does a SafeGDScript guest,
## with NO configuration, reach host engine globals OS / FileAccess?
## Required outcome for GO: both "blocked" (guest cannot touch host system).
## Kept tiny and side-effect-free so a hard OS timeout can bound it.

func _init() -> void:
	var src := "extends Node\n"
	src += "func reach_os():\n"
	src += "\tif OS == null:\n\t\treturn \"blocked\"\n\treturn \"reachable:\" + str(OS.get_name())\n"
	src += "func reach_file():\n"
	src += "\tif FileAccess == null:\n\t\treturn \"blocked\"\n\treturn \"reachable\"\n"

	var s: Script = ClassDB.instantiate("SafeGDScript")
	s.source_code = src
	var err := s.reload()
	print("PROBE compile err: %s" % error_string(err))

	var n := Node.new()
	n.set_script(s)
	get_root().add_child(n)

	print("PROBE os: %s" % str(n.call("reach_os")))
	print("PROBE file: %s" % str(n.call("reach_file")))
	print("PROBE done")
	quit(0)
