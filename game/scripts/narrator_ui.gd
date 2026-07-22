extends CanvasLayer
## Narrator subtitle bar. Latest line wins: a new line immediately replaces whatever
## is on screen (no long queue), so spamming interactions shows the newest reply at
## once (UX-2). One tween per line — a new line kills the old one, which fixes the
## "starts then instantly fades" timing bug (B-005).

const TYPE_CPS := 55.0   # typewriter chars per second
const HOLD_SEC := 3.0
const FADE_SEC := 0.5

var _panel: PanelContainer
var _label: RichTextLabel
var _tween: Tween


func _ready() -> void:
	# Keep animating during the game-over pause so the death/victory line shows.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -96.0
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
	# Kill any in-progress line and show the new one immediately.
	if _tween and _tween.is_valid():
		_tween.kill()
	_label.text = text
	_label.visible_characters = 0
	_panel.modulate.a = 1.0
	var reveal := maxf(0.05, text.length() / TYPE_CPS)
	_tween = create_tween()
	_tween.tween_property(_label, "visible_characters", text.length(), reveal)
	_tween.tween_interval(HOLD_SEC)
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE_SEC)
