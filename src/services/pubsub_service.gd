extends "res://gdscript-sdk/src/services/base_service.gd"
class_name PubSubService

const ClientResponseError = preload("res://gdscript-sdk/src/client_response_error.gd")

var _socket: WebSocketPeer
var _subscriptions: Dictionary = {}
var _pending_acks: Dictionary = {}
var _loop_state: GDScriptFunctionState
var _manual_close := false
var _ack_timeout_sec := 10.0

func get_is_connected() -> bool:
	return _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN

func publish(topic: String, data: Variant) -> Variant:
	if topic.is_empty():
		return ClientResponseError.new("", 0, {"message": "topic must be set."})

	var ok = await _ensure_socket()
	if ok is ClientResponseError:
		return ok

	var request_id := _next_request_id()
	var ack_waiter = _wait_for_ack(request_id)

	var envelope := {
		"type": "publish",
		"topic": topic,
		"data": data,
		"requestId": request_id,
	}
	_send_envelope(envelope)

	return await ack_waiter

func subscribe(topic: String, callback: Callable) -> Variant:
	if topic.is_empty():
		return ClientResponseError.new("", 0, {"message": "topic must be set."})

	var listeners: Array = _subscriptions.get(topic, [])
	var is_first := listeners.is_empty()
	listeners.append(callback)
	_subscriptions[topic] = listeners

	var ok = await _ensure_socket()
	if ok is ClientResponseError:
		return ok

	if is_first:
		var request_id := _next_request_id()
		var ack_waiter = _wait_for_ack(request_id)
		_send_envelope({"type": "subscribe", "topic": topic, "requestId": request_id})
		await ack_waiter
	return func() -> Variant:
		return unsubscribe(topic, callback)

func unsubscribe(topic: String = "", callback: Callable = Callable()) -> Variant:
	if topic.is_empty():
		_subscriptions.clear()
		if get_is_connected():
			_send_envelope({"type": "unsubscribe"})
		disconnect()
		return null

	var listeners: Array = _subscriptions.get(topic, [])
	if callback.is_valid() and callback in listeners:
		listeners.erase(callback)
	if listeners.is_empty():
		_subscriptions.erase(topic)
		if get_is_connected():
			var request_id := _next_request_id()
			var ack_waiter = _wait_for_ack(request_id)
			_send_envelope({"type": "unsubscribe", "topic": topic, "requestId": request_id})
			await ack_waiter
	if _subscriptions.is_empty():
		disconnect()
	return null

func disconnect() -> void:
	_manual_close = true
	_reject_all_pending(ClientResponseError.new("", 0, {"message": "pubsub connection closed"}))
	if _socket:
		_socket.close()
	_socket = null

func _build_ws_url() -> String:
	var params: Dictionary = {}
	if client.auth_store.is_valid():
		params["token"] = client.auth_store.token
	var raw := client.build_url("/api/pubsub", params)
	if raw.begins_with("https"):
		return raw.replace("https", "wss", false)
	if raw.begins_with("http"):
		return raw.replace("http", "ws", false)
	return "ws://" + raw.lstrip("/")

func _next_request_id() -> String:
	return String.num_uint64(Time.get_ticks_msec(), 16) + str(randi() % 100000)

func _ensure_socket() -> Variant:
	if get_is_connected():
		return true
	_manual_close = false
	_socket = WebSocketPeer.new()
	var url := _build_ws_url()
	var err = _socket.connect_to_url(url)
	if err != OK:
		return ClientResponseError.new(url, 0, {"message": "failed to connect websocket", "error": err})

	while _socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		_socket.poll()
		await _next_frame()

	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ClientResponseError.new(url, 0, {"message": "unable to open websocket"})

	_loop_state = _socket_loop()

	for topic in _subscriptions.keys():
		var request_id := _next_request_id()
		_send_envelope({"type": "subscribe", "topic": topic, "requestId": request_id})
	return true

func _send_envelope(data: Dictionary) -> void:
	if not get_is_connected():
		return
	_socket.send_text(JSON.stringify(data))

func _socket_loop() -> GDScriptFunctionState:
	return _socket_loop_async()

async func _socket_loop_async() -> void:
	while _socket and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.poll()
		while _socket.get_available_packet_count() > 0:
			var pkt: PackedByteArray = _socket.get_packet()
			var text := pkt.get_string_from_utf8()
			_handle_message(text)
		await _next_frame()

	if not _manual_close and not _subscriptions.is_empty():
		# attempt a quick reconnect
		_socket = null
		await _ensure_socket()

func _handle_message(raw: String) -> void:
	var parsed = JSON.parse_string(raw)
	if parsed == null:
		return
	if parsed is Dictionary:
		var typ := str(parsed.get("type", "message"))
		if typ == "ack":
			var request_id := str(parsed.get("requestId", ""))
			_resolve_ack(request_id, parsed)
			return
		if typ == "error":
			var request_id_err := str(parsed.get("requestId", ""))
			if request_id_err != "":
				_reject_ack(request_id_err, ClientResponseError.new("", 0, parsed))
			return
		# message delivery
		var topic := parsed.get("topic", "")
		var listeners: Array = _subscriptions.get(topic, [])
		for listener in listeners:
			if listener is Callable and listener.is_valid():
				listener.call({
					"id": parsed.get("id", ""),
					"topic": topic,
					"created": parsed.get("created", ""),
					"data": parsed.get("data"),
				})

func _wait_for_ack(request_id: String) -> GDScriptFunctionState:
	return _wait_for_ack_async(request_id)

async func _wait_for_ack_async(request_id: String) -> Variant:
	var tree = Engine.get_main_loop() as SceneTree
	var timer = tree.create_timer(_ack_timeout_sec)
	var timed_out := false
	timer.timeout.connect(func(): timed_out = true)
	var result: Variant = null
	_pending_acks[request_id] = {"done": false, "value": null}
	while true:
		if _pending_acks.has(request_id) and _pending_acks[request_id]["done"]:
			result = _pending_acks[request_id]["value"]
			_pending_acks.erase(request_id)
			return result
		if timed_out:
			break
		await tree.process_frame
	_pending_acks.erase(request_id)
	return ClientResponseError.new("", 0, {"message": "Timed out waiting for pubsub response."})

func _resolve_ack(request_id: String, payload: Variant) -> void:
	if not _pending_acks.has(request_id):
		return
	_pending_acks[request_id] = {"done": true, "value": payload}

func _reject_ack(request_id: String, err: Variant) -> void:
	if not _pending_acks.has(request_id):
		return
	_pending_acks[request_id] = {"done": true, "value": err}

func _reject_all_pending(err: Variant) -> void:
	var keys := _pending_acks.keys()
	for key in keys:
		_pending_acks[key] = {"done": true, "value": err}
	_pending_acks.clear()

func _next_frame() -> Variant:
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		return await (loop as SceneTree).process_frame
	return null
