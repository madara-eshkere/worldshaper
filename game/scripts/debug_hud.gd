extends CanvasLayer
## Dev-only HUD: turn counter + last semantic event, so turn accounting is
## visible during playtests (the player asked for this — turns were invisible).
## Not shipping UI — remove/gate before release.

var _label: Label
var _last_event := "-"


func _ready() -> void:
	layer = 20
	_label = Label.new()
	_label.position = Vector2(12, 8)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	add_child(_label)
	EventBus.game_event.connect(_on_event)


func _process(_delta: float) -> void:
	_label.text = "DEBUG  turn: %d   last: %s" % [TurnManager.turn, _last_event]


func _on_event(event_name: String, _data: Dictionary) -> void:
	_last_event = event_name
