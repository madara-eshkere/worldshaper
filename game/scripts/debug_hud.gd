extends CanvasLayer
## Dev-only event log: a small scrolling window of recent semantic events + the turn
## number, so turn accounting and event flow are visible during playtests. The
## internal player_turn_ended signal is filtered out (redundant with the action
## event). Not shipping UI — remove/gate before release.

const MAX_LINES := 40
const SKIP := ["player_turn_ended"]

var _log: RichTextLabel
var _lines: Array[String] = []


func _ready() -> void:
	layer = 20
	var panel := PanelContainer.new()
	panel.position = Vector2(10, 8)
	add_child(panel)
	_log = RichTextLabel.new()
	_log.custom_minimum_size = Vector2(330, 150)
	_log.bbcode_enabled = false
	_log.scroll_active = true
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 12)
	_log.add_theme_color_override("default_color", Color(0.6, 1.0, 0.6))
	panel.add_child(_log)
	EventBus.game_event.connect(_on_event)
	_render()


func _on_event(name: String, _data: Dictionary) -> void:
	if name in SKIP:
		return
	_lines.append("t%d  %s" % [TurnManager.turn, name])
	if _lines.size() > MAX_LINES:
		_lines.pop_front()
	_render()


func _render() -> void:
	_log.text = "DEBUG · ход %d\n" % TurnManager.turn + "\n".join(_lines)
