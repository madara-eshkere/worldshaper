extends CanvasLayer
## Always-on status readout: HP, level, XP, the six abilities, and the inventory as
## a column. Drawn from the World "player" object. Fixed-width panel pinned to the
## top-right (fully on screen), text wraps, and the box has a capped height that
## scrolls when the inventory grows. Stats are public (ADR-0008: only dice hidden).

const ABILITIES := ["str", "dex", "con", "int", "cha", "per"]
const WIDTH := 288.0
const MAX_HEIGHT := 420.0

var _label: RichTextLabel


func _ready() -> void:
	layer = 16
	var panel := Panel.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -(WIDTH + 12.0)
	panel.offset_right = -12.0
	panel.offset_top = 12.0
	panel.offset_bottom = 12.0 + MAX_HEIGHT
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = false
	_label.fit_content = true
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(WIDTH - 16.0, 0)
	_label.add_theme_font_size_override("normal_font_size", 15)
	scroll.add_child(_label)

	EventBus.game_event.connect(func(_n: String, _d: Dictionary): _refresh())
	World.object_changed.connect(func(_id: String): _refresh())
	_refresh()


func _refresh() -> void:
	if _label == null or not World.has("player"):
		return
	var p: Dictionary = World.raw("player")["props"]
	var lines: Array[String] = []
	lines.append("HP %d / %d" % [int(p.get("hp", 0)), int(p.get("hp_max", 0))])
	lines.append("Уровень %d   Скор. %d   XP %d" % [
		int(p.get("level", 1)), int(p.get("speed", 1)), int(p.get("xp", 0))])
	var abils := ""
	for a in ABILITIES:
		abils += "%s %d   " % [a.to_upper(), int(p.get(a, 10))]
	lines.append(abils.strip_edges())
	lines.append("")
	lines.append("Инвентарь:")
	var items: Array = p.get("inventory", [])
	if items.is_empty():
		lines.append("  (пусто)")
	else:
		for it in items:
			if it is Dictionary:
				lines.append("  • " + str(it.get("name", "?")))
	_label.text = "\n".join(lines)
