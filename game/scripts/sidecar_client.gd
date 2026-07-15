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
const CONNECT_TIMEOUT_SEC := 4.0

var _ws := WebSocketPeer.new()
var _hello_sent := false
var _was_open := false
var _reconnect_timer := 0.0
var _connecting := false
var _connecting_time := 0.0
var _spawned_pid := -1


func _ready() -> void:
	EventBus.game_event.connect(_on_game_event)
	# The game owns the sidecar (ADR-0002): launch it proactively at boot.
	# If one is already running (dev mode), the duplicate dies on port bind.
	_spawn_sidecar()
	_try_connect()


func _exit_tree() -> void:
	if _spawned_pid > 0 and OS.is_process_running(_spawned_pid):
		OS.kill(_spawned_pid)


## In dev mode this finds ../sidecar next to the project; in release
## builds it will find the packaged exe next to the game binary (M5).
func _spawn_sidecar() -> void:
	var candidates: Array[PackedStringArray] = []
	var dev_root := ProjectSettings.globalize_path("res://").path_join("..")
	var dev_python := dev_root.path_join("sidecar/.venv/Scripts/python.exe")
	var dev_main := dev_root.path_join("sidecar/main.py")
	if FileAccess.file_exists(dev_python) and FileAccess.file_exists(dev_main):
		candidates.append(PackedStringArray([dev_python, dev_main]))
	var packaged := OS.get_executable_path().get_base_dir().path_join("sidecar.exe")
	if FileAccess.file_exists(packaged):
		candidates.append(PackedStringArray([packaged]))
	if candidates.is_empty():
		print("[sidecar] no sidecar found to launch — running in offline mode")
		return
	var cmd := candidates[0]
	var args := cmd.slice(1)
	_spawned_pid = OS.create_process(cmd[0], args)
	if _spawned_pid > 0:
		print("[sidecar] launched (pid %d)" % _spawned_pid)
	else:
		print("[sidecar] failed to launch — running in offline mode")


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
				_connecting_time = 0.0
				_send({"type": "hello", "game_version": GAME_VERSION,
						"protocol_version": PROTOCOL_VERSION})
			while _ws.get_available_packet_count() > 0:
				_handle_packet(_ws.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CONNECTING:
			# Windows quirk: a refused localhost port can hang in CONNECTING
			# forever — enforce our own handshake deadline.
			_connecting_time += delta
			if _connecting_time > CONNECT_TIMEOUT_SEC:
				_drop_connection()
		WebSocketPeer.STATE_CLOSED:
			if _was_open:
				print("[sidecar] connection lost, retrying in %ss" % RECONNECT_DELAY_SEC)
			_drop_connection()


func _drop_connection() -> void:
	_connecting = false
	_connecting_time = 0.0
	_hello_sent = false
	_was_open = false
	_reconnect_timer = RECONNECT_DELAY_SEC


func _try_connect() -> void:
	_ws = WebSocketPeer.new()
	_connecting_time = 0.0
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
