extends RefCounted
class_name BosBase

const AuthStore = preload("res://gdscript-sdk/src/auth_store.gd")
const ClientResponseError = preload("res://gdscript-sdk/src/client_response_error.gd")
const BosbaseUtils = preload("res://gdscript-sdk/src/utils.gd")

const USER_AGENT := "bosbase-gdscript-sdk/0.1.0"

var base_url: String
var lang: String = "en-US"
var timeout: float = 30.0
var auth_store: AuthStore

# Optional hooks matching the JS SDK shape.
# before_send(url: String, options: Dictionary) -> Dictionary?
var before_send: Callable
# after_send(response: Dictionary, data: Variant, options: Dictionary) -> Variant
var after_send: Callable

# Services (assigned during initialization).
var collections
var files
var logs
var realtime
var pubsub
var settings
var health
var backups
var crons
var vectors
var llm_documents
var langchaingo
var caches
var graphql

var _record_services: Dictionary = {}

func _init(
	base_url: String = "/",
	lang: String = "en-US",
	auth_store: AuthStore = null,
	timeout: float = 30.0
) -> void:
	var normalized_base := base_url
	if normalized_base.length() > 1 and normalized_base.ends_with("/"):
		normalized_base = normalized_base.substr(0, normalized_base.length() - 1)
	self.base_url = normalized_base
	self.lang = lang
	self.timeout = timeout
	self.auth_store = auth_store if auth_store != null else AuthStore.new()

	# Lazy imports to avoid circular dependency issues.
	var CollectionService = preload("res://gdscript-sdk/src/services/collection_service.gd")
	var FileService = preload("res://gdscript-sdk/src/services/file_service.gd")
	var LogService = preload("res://gdscript-sdk/src/services/log_service.gd")
	var RealtimeService = preload("res://gdscript-sdk/src/services/realtime_service.gd")
	var PubSubService = preload("res://gdscript-sdk/src/services/pubsub_service.gd")
	var SettingsService = preload("res://gdscript-sdk/src/services/settings_service.gd")
	var HealthService = preload("res://gdscript-sdk/src/services/health_service.gd")
	var BackupService = preload("res://gdscript-sdk/src/services/backup_service.gd")
	var CronService = preload("res://gdscript-sdk/src/services/cron_service.gd")
	var VectorService = preload("res://gdscript-sdk/src/services/vector_service.gd")
	var LLMDocumentService = preload("res://gdscript-sdk/src/services/llm_document_service.gd")
	var LangChaingoService = preload("res://gdscript-sdk/src/services/langchaingo_service.gd")
	var CacheService = preload("res://gdscript-sdk/src/services/cache_service.gd")
	var GraphQLService = preload("res://gdscript-sdk/src/services/graphql_service.gd")

	collections = CollectionService.new(self)
	files = FileService.new(self)
	logs = LogService.new(self)
	realtime = RealtimeService.new(self)
	pubsub = PubSubService.new(self)
	settings = SettingsService.new(self)
	health = HealthService.new(self)
	backups = BackupService.new(self)
	crons = CronService.new(self)
	vectors = VectorService.new(self)
	llm_documents = LLMDocumentService.new(self)
	langchaingo = LangChaingoService.new(self)
	caches = CacheService.new(self)
	graphql = GraphQLService.new(self)

func admins() -> Variant:
	return collection("_superusers")

func collection(collection_id_or_name: String) -> Variant:
	if not _record_services.has(collection_id_or_name):
		var RecordService = preload("res://gdscript-sdk/src/services/record_service.gd")
		_record_services[collection_id_or_name] = RecordService.new(self, collection_id_or_name)
	return _record_services[collection_id_or_name]

func create_batch() -> Variant:
	var BatchService = preload("res://gdscript-sdk/src/services/batch_service.gd")
	return BatchService.new(self)

func filter(expr: String, params: Dictionary = {}) -> String:
	if params.is_empty():
		return expr
	for key in params.keys():
		var placeholder := "{:%s}" % key
		var value = params[key]
		match typeof(value):
			TYPE_BOOL:
				expr = expr.replace(placeholder, value ? "true" : "false")
			TYPE_INT, TYPE_FLOAT:
				expr = expr.replace(placeholder, str(value))
			TYPE_STRING:
				var escaped = (value as String).replace("'", "\\'")
				expr = expr.replace(placeholder, "'%s'" % escaped)
			_:
				if value == null:
					expr = expr.replace(placeholder, "null")
				elif value is Dictionary or value is Array:
					var serialized = JSON.stringify(value)
					serialized = serialized.replace("'", "\\'")
					expr = expr.replace(placeholder, "'%s'" % serialized)
				elif value is Object and value.has_method("to_iso8601"):
					var dt = value.call("to_iso8601")
					expr = expr.replace(placeholder, "'%s'" % dt.replace("T", " "))
				else:
					var serialized_any = JSON.stringify(value)
					expr = expr.replace(placeholder, "'%s'" % serialized_any.replace("'", "\\'"))
	return expr

func build_url(path: String, query: Dictionary = {}) -> String:
	var base := base_url
	if not base.ends_with("/"):
		base += "/"
	var relative := path.strip_edges()
	if relative.begins_with("/"):
		relative = relative.substr(1, relative.length() - 1)
	var full := base + relative

	if query.is_empty():
		return full

	var normalized := BosbaseUtils.normalize_query_params(query)
	if normalized.is_empty():
		return full

	var parts: Array[String] = []
	for key in normalized.keys():
		var values: Array = normalized[key]
		for v in values:
			parts.append("%s=%s" % [key.uri_encode(), str(v).uri_encode()])

	var separator := "?" if full.find("?") == -1 else "&"
	return full + separator + "&".join(parts)

func get_file_url(
	record: Dictionary,
	filename: String,
	thumb: String = "",
	token: String = "",
	download: bool = false,
	query: Dictionary = {}
) -> String:
	return files.get_url(record, filename, thumb: thumb, token: token, download: download, query: query)

func send(
	path: String,
	method: String = "GET",
	headers: Dictionary = {},
	query: Dictionary = {},
	body: Variant = null,
	files: Variant = null,
	timeout_sec: float = -1.0
) -> Variant:
	var current_query := query.duplicate(true)
	var url := build_url(path, current_query)

	var req_headers: Dictionary = {
		"Accept-Language": lang,
		"User-Agent": USER_AGENT,
	}
	for key in headers.keys():
		req_headers[key] = headers[key]

	if not req_headers.has("Authorization") and auth_store.is_valid():
		req_headers["Authorization"] = auth_store.token

	var options := {
		"method": method,
		"headers": req_headers.duplicate(),
		"body": body,
		"query": current_query.duplicate(),
		"files": files,
	}

	if before_send and before_send.is_valid():
		var override = before_send.call(url, options)
		if override is Dictionary and override.has("url") or override.has("options"):
			url = override.get("url", url)
			options = override.get("options", options)
		elif override is Dictionary and not override.is_empty():
			options = override
		method = str(options.get("method", method))
		req_headers = options.get("headers", req_headers)
		body = options.get("body", body)
		current_query = options.get("query", current_query)
		files = options.get("files", files)
		url = build_url(path, current_query)

	method = method.to_upper()

	if files == null and body != null:
		body = BosbaseUtils.to_serializable(body)

	var payload: Variant = ""
	var content_type := ""

	var normalized_files := _normalize_files(files)
	if not normalized_files.is_empty():
		var mp = _build_multipart(body if body != null else {}, normalized_files)
		payload = mp.body
		content_type = mp.content_type
	else:
		if body != null:
			payload = JSON.stringify(body)
			content_type = "application/json"

	if content_type != "" and not _has_header(req_headers, "Content-Type"):
		req_headers["Content-Type"] = content_type

	url = build_url(path, current_query)

	var response := await _do_http_request(
		url,
		method,
		req_headers,
		payload,
		timeout_sec > 0.0 ? timeout_sec : timeout
	)

	if response is ClientResponseError:
		return response

	var response_code: int = response.get("code", 0)
	var response_headers: Dictionary = response.get("headers", {})
	var raw_body: PackedByteArray = response.get("body", PackedByteArray())

	var data: Variant = null
	if raw_body.size() > 0:
		var text := raw_body.get_string_from_utf8()
		var parsed = JSON.parse_string(text)
		data = parsed if parsed != null else text

	if after_send and after_send.is_valid():
		data = after_send.call(response, data, options)

	if response_code >= 400:
		return ClientResponseError.new(url, response_code, data if data is Dictionary else {}, false, null)

	return data

func _has_header(headers: Dictionary, name: String) -> bool:
	var lowered := name.to_lower()
	for k in headers.keys():
		if str(k).to_lower() == lowered:
			return true
	return false

func _normalize_files(files: Variant) -> Array:
	if files == null:
		return []
	var normalized: Array = []
	if files is Dictionary:
		for key in files.keys():
			var file_val = files[key]
			normalized.append(_normalize_single_file(str(key), file_val))
	elif files is Array:
		for entry in files:
			if entry is Dictionary and entry.has("name"):
				normalized.append(entry)
			elif entry is Array and entry.size() >= 2:
				normalized.append(_normalize_single_file(str(entry[0]), entry[1]))
	return normalized

func _normalize_single_file(field: String, value: Variant) -> Dictionary:
	if value is Dictionary:
		return {
			"name": field,
			"filename": value.get("filename", field),
			"content_type": value.get("content_type", "application/octet-stream"),
			"data": value.get("data", PackedByteArray()),
		}

	var data: PackedByteArray = PackedByteArray()
	if value is PackedByteArray:
		data = value
	elif value is String and FileAccess.file_exists(value):
		var f := FileAccess.open(value, FileAccess.READ)
		if f:
			data = f.get_buffer(f.get_length())
			f.close()

	return {
		"name": field,
		"filename": field,
		"content_type": "application/octet-stream",
		"data": data,
	}

func _build_multipart(body: Dictionary, files: Array) -> Dictionary:
	var boundary := "----bosbase-%s" % str(Time.get_ticks_msec())
	var bytes := PackedByteArray()

	func append_line(line: String) -> void:
		bytes.append_array((line + "\r\n").to_utf8_buffer())

	var payload := body if body != null else {}
	append_line("--%s" % boundary)
	append_line('Content-Disposition: form-data; name="@jsonPayload"')
	append_line("Content-Type: application/json")
	append_line("")
	append_line(JSON.stringify(payload))

	for file_dict in files:
		append_line("--%s" % boundary)
		var disposition := 'Content-Disposition: form-data; name="%s"; filename="%s"' % [
			file_dict.get("name", "").replace('"', ""),
			file_dict.get("filename", "").replace('"', ""),
		]
		append_line(disposition)
		var ctype := file_dict.get("content_type", "application/octet-stream")
		append_line("Content-Type: %s" % ctype)
		append_line("")
		var data: PackedByteArray = file_dict.get("data", PackedByteArray())
		bytes.append_array(data)
		append_line("")

	append_line("--%s--" % boundary)

	return {
		"body": bytes,
		"content_type": "multipart/form-data; boundary=%s" % boundary,
	}

func _do_http_request(
	url: String,
	method: String,
	headers: Dictionary,
	body: Variant,
	timeout_sec: float
) -> Variant:
	var http := HTTPRequest.new()
	http.timeout = timeout_sec

	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		(main_loop as SceneTree).get_root().add_child(http)

	var header_list: Array = []
	for key in headers.keys():
		header_list.append("%s: %s" % [str(key), str(headers[key])])

	var http_method := HTTPClient.METHOD_GET
	match method:
		"POST":
			http_method = HTTPClient.METHOD_POST
		"PUT":
			http_method = HTTPClient.METHOD_PUT
		"PATCH":
			http_method = HTTPClient.METHOD_PATCH
		"DELETE":
			http_method = HTTPClient.METHOD_DELETE
		_:
			http_method = HTTPClient.METHOD_GET

	var req_body := body if body != null else ""
	var err := http.request(url, header_list, http_method, req_body)
	if err != OK:
		if http.get_parent():
			http.queue_free()
		return ClientResponseError.new(url, 0, {}, err == ERR_BUSY, "HTTP request error %s" % err)

	var result = await http.request_completed

	if http.get_parent():
		http.queue_free()

	var status_code: int = result[1]
	var response_headers: Dictionary = {}
	for h in result[2]:
		if h is String and ":" in h:
			var split := h.split(":", false, 1)
			if split.size() == 2:
				response_headers[split[0].strip_edges()] = split[1].strip_edges()

	return {
		"code": status_code,
		"headers": response_headers,
		"body": result[3],
		"url": url,
	}
