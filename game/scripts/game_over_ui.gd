extends CanvasLayer
## Game over via Godot's built-in tree pause — no per-entity freezing. On death or
## victory it pauses the whole SceneTree (every node stops processing at once) and
## shows an overlay; this node runs with PROCESS_MODE_ALWAYS so it still reacts to
## the restart key, which unpauses and reloads the scene.

var _shown := false
var _dim: ColorRect
var _label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)

	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 40)
	_label.visible = false
	add_child(_label)

	EventBus.game_event.connect(_on_event)


func _on_event(name: String, _data: Dictionary) -> void:
	if _shown:
		return
	if name == "player_died":
		_show("ВЫ ПОГИБЛИ", Color(0.9, 0.4, 0.4))
	elif name == "level_complete":
		_show("УРОВЕНЬ ПРОЙДЕН", Color(0.5, 0.85, 1.0))


func _show(title: String, color: Color) -> void:
	_shown = true
	_label.text = "%s\n\nR — начать заново" % title
	_label.add_theme_color_override("font_color", color)
	_dim.visible = true
	_label.visible = true
	get_tree().paused = true  # stops every node at once (ADR-0007 turn loop halts)


func _unhandled_input(event: InputEvent) -> void:
	if _shown and event.is_action_pressed("restart"):
		get_tree().paused = false
		get_tree().reload_current_scene()
