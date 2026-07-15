extends CanvasLayer
## Narrator subtitle bar: shows GM lines with a typewriter effect.
## Narration may arrive late relative to the turn it refers to — that is fine
## by design (DESIGN.md 4.4): it garnishes, it never gates.

const TYPE_SPEED_CHARS_PER_SEC := 40.0
const HOLD_SEC := 3.5

var _label: RichTextLabel
var _panel: PanelContainer
var _queue: Array[String] = []
var _busy := false


func _ready() -> void:
	layer = 10
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -84.0
	_panel.offset_left = 24.0
	_panel.offset_right = -24.0
	_panel.offset_bottom = -16.0
	_panel.modulate.a = 0.0
	add_child(_panel)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = false
	_label.fit_content = true
	_label.add_theme_font_size_override("normal_font_size", 20)
	_panel.add_child(_label)

	SidecarClient.narration_received.connect(_on_narration)


func _on_narration(text: String, _ref_turn: int) -> void:
	_queue.append(text)
	if not _busy:
		_play_next()


func _play_next() -> void:
	if _queue.is_empty():
		_busy = false
		var fade := create_tween()
		fade.tween_property(_panel, "modulate:a", 0.0, 0.6)
		return
	_busy = true
	var text: String = _queue.pop_front()
	_label.text = text
	_label.visible_characters = 0
	_panel.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(_label, "visible_characters", text.length(),
			text.length() / TYPE_SPEED_CHARS_PER_SEC)
	t.tween_interval(HOLD_SEC)
	t.tween_callback(_play_next)
