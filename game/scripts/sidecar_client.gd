extends Node
## WebSocket client to the AI sidecar (ADR-0002).
## Static-core discipline (ADR-0009): if the sidecar is unreachable, the game
## keeps running silently — narration is a garnish, never a dependency.

signal narration_received(text: String, ref_turn: int)
signal sidecar_ready()

const URL := "ws://127.0.0.1:8974"
const GAME_VERSION := "0.0.1"
const PROTOCOL_VERSION := 0
const RECONNECT_DELAY_SEC := 3.0

var _ws := WebSocketPeer.new()
var _hello_sent := false
var _was_open := false
var _reconnect_timer := 0.0
var _connecting := false


func _ready() -> void:
	EventBus.game_event.connect(_on_game_event)
	_try_connect()


func _process(delta: float) -> void:
	if not _connecting:
		_reconnect_timer -= delta
		if _reconnect_timer <= 0.0:
			_try_connect()
		return

	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _hello_sent:
				_hello_sent = true
				_was_open = true
				_send({"type": "hello", "game_version": GAME_VERSION,
						"protocol_version": PROTOCOL_VERSION})
			while _ws.get_available_packet_count() > 0:
				_handle_packet(_ws.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			if _was_open:
				print("[sidecar] connection lost, retrying in %ss" % RECONNECT_DELAY_SEC)
			_connecting = false
			_hello_sent = false
			_was_open = false
			_reconnect_timer = RECONNECT_DELAY_SEC


func _try_connect() -> void:
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(URL)
	if err == OK:
		_connecting = true
	else:
		_reconnect_timer = RECONNECT_DELAY_SEC


func _handle_packet(raw: String) -> void:
	var msg: Variant = JSON.parse_string(raw)
	if typeof(msg) != TYPE_DICTIONARY or not msg.has("type"):
		push_warning("sidecar sent malformed message: %s" % raw)
		return
	match msg["type"]:
		"ready":
			print("[sidecar] ready, protocol v%s" % str(msg.get("protocol_version")))
			sidecar_ready.emit()
			EventBus.emit_game_event("session_started")
		"narration":
			var ref_turn := int(msg.get("ref_turn", -1) if msg.get("ref_turn") != null else -1)
			print("[narration] %s" % msg["text"])
			narration_received.emit(str(msg["text"]), ref_turn)
		var other:
			push_warning("unknown sidecar message type: %s" % str(other))


func _on_game_event(event_name: String, data: Dictionary) -> void:
	if _connecting and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send({"type": "event", "name": event_name, "turn": TurnManager.turn, "data": data})


func _send(msg: Dictionary) -> void:
	_ws.send_text(JSON.stringify(msg))
