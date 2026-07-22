extends CanvasLayer
## Visible character sheet panel (ADR-0008 amended: stats are shown to the player;
## only the dice stay hidden). Toggle with C. Reads the World "player" object.

const D20 = preload("res://scripts/d20.gd")
const ABILITIES := ["str", "dex", "con", "int", "cha", "per"]

var _panel: PanelContainer
var _label: RichTextLabel


func _ready() -> void:
	layer = 15
	_panel = PanelContainer.new()
	_panel.position = Vector2(20, 60)
	_panel.visible = false
	add_child(_panel)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = false
	_label.fit_content = true
	_label.custom_minimum_size = Vector2(240, 0)
	_label.add_theme_font_size_override("normal_font_size", 16)
	_panel.add_child(_label)
	EventBus.game_event.connect(_on_event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("sheet"):
		_panel.visible = not _panel.visible
		if _panel.visible:
			_refresh()


func _on_event(event_name: String, _data: Dictionary) -> void:
	# Keep the panel live if it's open (hp/level can change under it).
	if _panel.visible:
		_refresh()


func _refresh() -> void:
	if not World.has("player"):
		_label.text = "(нет персонажа)"
		return
	var p: Dictionary = World.raw("player")["props"]
	var lines: Array[String] = []
	lines.append("%s %s, ур. %d" % [p.get("race", "?"), p.get("class", "?"), int(p.get("level", 1))])
	lines.append("HP: %d/%d    XP: %d" % [int(p.get("hp", 0)), int(p.get("hp_max", 0)), int(p.get("xp", 0))])
	lines.append("Скорость: %d  (ходит чаще при большей)" % int(p.get("speed", 1)))
	lines.append("")
	for a in ABILITIES:
		var score := int(p.get(a, 10))
		lines.append("%s  %2d  (%+d)" % [a.to_upper(), score, D20.ability_mod(score)])
	_label.text = "\n".join(lines)
