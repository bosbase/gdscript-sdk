extends "res://gdscript-sdk/src/services/base_service.gd"
class_name RealtimeService

const ClientResponseError = preload("res://gdscript-sdk/src/client_response_error.gd")

var client_id: String = ""
var on_disconnect: Callable

var _subscriptions: Dictionary = {}
var _current_event: Dictionary = {"event": "message", "data": "", "id": ""}
var _buffer := ""
var _running := false
var _stop_requested := false
var _listen_state: GDScriptFunctionState

func get_is_connected() -> bool:
	return _running and not client_id.is_empty()

func subscribe(topic: String, callback: Callable, options: Dictionary = {}) -> Variant:
	if topic.is_empty():
		return ClientResponseError.new("", 0, {"message": "topic must be set"})

	var key := _build_subscription_key(topic, options.get("query", {}), options.get("headers", {}))
	var listeners: Array = _subscriptions.get(key, [])
	listeners.append(callback)
	_subscriptions[key] = listeners

	_ensure_loop()
	if get_is_connected():
		await _submit_subscriptions()

	return func() -> Variant:
		return unsubscribe_by_topic_and_listener(topic, callback)

func unsubscribe(topic: String = "") -> Variant:
	var need_submit := false
	if topic.is_empty():
		_subscriptions.clear()
	else:
		var keys = _keys_for_topic(topic)
		for key in keys:
			if _subscriptions.has(key):
				_subscriptions.erase(key)
				need_submit = true

	if _subscriptions.is_empty():
		disconnect()
	elif need_submit:
		await _submit_subscriptions()

func unsubscribe_by_prefix(prefix: String) -> Variant:
	var keys_to_remove: Array = []
	for key in _subscriptions.keys():
		if (key + "?").begins_with(prefix):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_subscriptions.erase(key)

	if _subscriptions.is_empty():
		disconnect()
	else:
		await _submit_subscriptions()

func unsubscribe_by_topic_and_listener(topic: String, listener: Callable) -> Variant:
	var keys = _keys_for_topic(topic)
	for key in keys:
		var listeners: Array = _subscriptions.get(key, [])
		if listener in listeners:
			listeners.erase(listener)
			if listeners.is_empty():
				_subscriptions.erase(key)
			else:
				_subscriptions[key] = listeners

	if _subscriptions.is_empty():
		disconnect()
	else:
		await _submit_subscriptions()

func disconnect() -> void:
	_stop_requested = true
	client_id = ""
	_running = false

func ensure_connected(timeout: float = 10.0) -> Variant:
	var elapsed := 0.0
	var step := 0.05
	_ensure_loop()
	while elapsed < timeout:
		if get_is_connected():
			return true
		await _sleep(step)
		elapsed += step
	return ClientResponseError.new("", 0, {"message": "Realtime connection not established"})

func get_active_subscriptions() -> Array:
	return _subscriptions.keys()

# Internal
func _ensure_loop() -> void:
	if _running:
		return
	_stop_requested = false
	_listen_state = _run_loop()

func _run_loop() -> GDScriptFunctionState:
	return _run_loop_async()

async func _run_loop_async() -> void:
	_running = true
	var backoff: Array = [0.2, 0.3, 0.5, 1.0, 1.2, 1.5, 2.0]
	var attempt := 0
	while not _stop_requested and not _subscriptions.is_empty():
		var ok = await _connect_and_listen()
		if _stop_requested or _subscriptions.is_empty():
			break
		var delay := backoff[min(attempt, backoff.size() - 1)]
		attempt += 1
		await _sleep(delay)
	_stop_requested = false
	_running = false
	client_id = ""
	if on_disconnect and on_disconnect.is_valid():
		on_disconnect.call(_subscriptions.keys())

async func _connect_and_listen() -> bool:
	var url := client.build_url("/api/realtime")
	var http := HTTPClient.new()
	var err = http.connect_to_url(url)
	if err != OK:
		return false

	while http.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		http.poll()
		await _next_frame()

	var headers: Array[String] = [
		"Accept: text/event-stream",
		"Cache-Control: no-store",
		"Accept-Language: %s" % client.lang,
	]
	if client.auth_store.is_valid():
		headers.append("Authorization: %s" % client.auth_store.token)

	err = http.request(HTTPClient.METHOD_GET, url, headers)
	if err != OK:
		return false

	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		await _next_frame()

	if http.get_status() != HTTPClient.STATUS_BODY:
		return false

	_current_event = {"event": "message", "data": "", "id": ""}
	_buffer = ""
	client_id = ""

	while not _stop_requested and http.get_status() == HTTPClient.STATUS_BODY and not _subscriptions.is_empty():
		http.poll()
		var chunk := http.read_response_body_chunk()
		if chunk.size() > 0:
		await _handle_sse_chunk(chunk)
		await _next_frame()

	http.close()
	return get_is_connected()

async func _handle_sse_chunk(chunk: PackedByteArray) -> void:
	_buffer += chunk.get_string_from_utf8()
	var lines := _buffer.split("\n")
	if not _buffer.ends_with("\n"):
		_buffer = lines.pop_back()
	else:
		_buffer = ""

	for line_untrimmed in lines:
		var line: String = str(line_untrimmed).rstrip("\r")
		if line.is_empty():
			await _dispatch_event(_current_event)
			_current_event = {"event": "message", "data": "", "id": ""}
			continue
		if line.begins_with(":"):
			continue
		var parts = line.split(":", false, 1)
		var field := parts[0]
		var value := ""
		if parts.size() > 1:
			value = str(parts[1]).lstrip(" ")
		match field:
			"event":
				_current_event["event"] = value if value != "" else "message"
			"data":
				_current_event["data"] = str(_current_event.get("data", "")) + value + "\n"
			"id":
				_current_event["id"] = value

async func _dispatch_event(event: Dictionary) -> void:
	var name := str(event.get("event", "message"))
	var data_str := str(event.get("data", "")).rstrip("\n")
	var payload: Variant = {}
	if not data_str.is_empty():
		var parsed = JSON.parse_string(data_str)
		payload = parsed if parsed != null else {"raw": data_str}

	if name == "PB_CONNECT":
		client_id = payload.get("clientId", event.get("id", ""))
		await _submit_subscriptions()
		return

	var listeners: Array = _subscriptions.get(name, [])
	for listener in listeners:
		if listener is Callable and listener.is_valid():
			listener.call(payload)

func _build_subscription_key(topic: String, query: Dictionary, headers: Dictionary) -> String:
	var key := topic
	var options: Dictionary = {}
	if not query.is_empty():
		options["query"] = query
	if not headers.is_empty():
		options["headers"] = headers
	if not options.is_empty():
		var serialized := JSON.stringify(options)
		var suffix := "options=" + serialized.uri_encode()
		key += (key.find("?") != -1 ? "&" : "?") + suffix
	return key

func _keys_for_topic(topic: String) -> Array:
	var result: Array = []
	var prefix := "%s?" % topic
	for key in _subscriptions.keys():
		if key == topic or key.begins_with(prefix):
			result.append(key)
	return result

func _has_subscriptions() -> bool:
	return not _subscriptions.is_empty()

func _submit_subscriptions() -> Variant:
	if client_id.is_empty() or not _has_subscriptions():
		return null
	var payload := {
		"clientId": client_id,
		"subscriptions": get_active_subscriptions(),
	}
	return await client.send("/api/realtime", "POST", {}, {}, payload)

func _next_frame() -> Variant:
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		return await (loop as SceneTree).process_frame
	return null

func _sleep(seconds: float) -> Variant:
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		return await (loop as SceneTree).create_timer(seconds).timeout
	return null
