extends "res://gdscript-sdk/src/services/base_crud_service.gd"
class_name RecordService

const ClientResponseError = preload("res://gdscript-sdk/src/client_response_error.gd")
const BosbaseUtils = preload("res://gdscript-sdk/src/utils.gd")

var collection_id_or_name: String

func _init(client, collection_id_or_name: String) -> void:
	super._init(client)
	self.collection_id_or_name = collection_id_or_name

func base_collection_path() -> String:
	return "/api/collections/%s" % BosbaseUtils.encode_path_segment(collection_id_or_name)

func base_crud_path() -> String:
	return "%s/records" % base_collection_path()

func subscribe(topic: String, callback: Callable, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	if topic.is_empty():
		return ClientResponseError.new("", 0, {"message": "topic must be set"})
	var full_topic := "%s/%s" % [collection_id_or_name, topic]
	return await client.realtime.subscribe(full_topic, callback, {"query": query, "headers": headers})

func unsubscribe(topic: String = "") -> Variant:
	if topic.is_empty():
		return await client.realtime.unsubscribe_by_prefix(collection_id_or_name)
	return await client.realtime.unsubscribe("%s/%s" % [collection_id_or_name, topic])

func update(record_id: String, body: Dictionary = {}, query: Dictionary = {}, files: Variant = null, headers: Dictionary = {}, expand: String = "", fields: String = "") -> Variant:
	var item = await super.update(record_id, body, query, files, headers, expand, fields)
	if item is ClientResponseError:
		return item
	_maybe_update_auth_record(item)
	return item

func delete(record_id: String, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var res = await super.delete(record_id, body, query, headers)
	if res is ClientResponseError:
		return res
	if _is_auth_record(record_id):
		client.auth_store.clear()
	return res

func get_count(filter: String = "", expand: String = "", fields: String = "", query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var params := query.duplicate()
	if not filter.is_empty() and not params.has("filter"):
		params["filter"] = filter
	if not expand.is_empty() and not params.has("expand"):
		params["expand"] = expand
	if not fields.is_empty() and not params.has("fields"):
		params["fields"] = fields
	var data = await client.send("%s/count" % base_crud_path(), "GET", headers, params)
	if data is ClientResponseError:
		return data
	return int(data.get("count", 0))

func list_auth_methods(fields: String = "", query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var params := query.duplicate()
	if not params.has("fields"):
		params["fields"] = fields if not fields.is_empty() else "mfa,otp,password,oauth2"
	return await client.send("%s/auth-methods" % base_collection_path(), "GET", headers, params)

func auth_with_password(identity: String, password: String, expand: String = "", fields: String = "", body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var payload := body.duplicate()
	payload["identity"] = identity
	payload["password"] = password

	var params := query.duplicate()
	if not expand.is_empty() and not params.has("expand"):
		params["expand"] = expand
	if not fields.is_empty() and not params.has("fields"):
		params["fields"] = fields

	var data = await client.send("%s/auth-with-password" % base_collection_path(), "POST", headers, params, payload)
	return _auth_response(data)

func auth_with_oauth2_code(provider: String, code: String, code_verifier: String, redirect_url: String, create_data: Dictionary = {}, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}, expand: String = "", fields: String = "") -> Variant:
	var payload := body.duplicate()
	if not payload.has("provider"):
		payload["provider"] = provider
	if not payload.has("code"):
		payload["code"] = code
	if not payload.has("codeVerifier"):
		payload["codeVerifier"] = code_verifier
	if not payload.has("redirectURL"):
		payload["redirectURL"] = redirect_url
	if not payload.has("createData"):
		payload["createData"] = create_data

	var params := query.duplicate()
	if not expand.is_empty() and not params.has("expand"):
		params["expand"] = expand
	if not fields.is_empty() and not params.has("fields"):
		params["fields"] = fields

	var data = await client.send("%s/auth-with-oauth2" % base_collection_path(), "POST", headers, params, payload)
	return _auth_response(data)

func auth_with_oauth2(provider_name: String, url_callback: Callable, scopes: Array = [], create_data: Dictionary = {}, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}, expand: String = "", fields: String = "", timeout: float = 180.0) -> Variant:
	var auth_methods = await list_auth_methods()
	if auth_methods is ClientResponseError:
		return auth_methods
	var providers: Array = auth_methods.get("oauth2", {}).get("providers", []) if auth_methods is Dictionary else []
	var provider := null
	for p in providers:
		if p is Dictionary and p.get("name", "") == provider_name:
			provider = p
			break
	if provider == null:
		return ClientResponseError.new("", 0, {"message": "missing provider %s" % provider_name})

	var redirect_url := client.build_url("/api/oauth2-redirect")
	var ensure = await client.realtime.ensure_connected(10.0)
	if ensure is ClientResponseError:
		return ensure
	var state := client.realtime.client_id

	var auth_url := str(provider.get("authURL", "")) + redirect_url
	var parsed_query: Dictionary = {}
	parsed_query["state"] = state
	if not scopes.is_empty():
		parsed_query["scope"] = Array(scopes).join(" ")
	var separator := auth_url.find("?") == -1 ? "?" : "&"
	auth_url += separator
	var parts: Array[String] = []
	for k in parsed_query.keys():
		parts.append("%s=%s" % [str(k).uri_encode(), str(parsed_query[k]).uri_encode()])
	auth_url += parts.join("&")

	if url_callback and url_callback.is_valid():
		url_callback.call(auth_url)

	var event_data: Variant = null
	var error_data: Variant = null
	var unsubscribe = await client.realtime.subscribe("@oauth2", func(payload):
		var code := str(payload.get("code", ""))
		var state_payload := str(payload.get("state", ""))
		var err := str(payload.get("error", ""))
		if state_payload != state:
			return
		if not err.is_empty() or code.is_empty():
			error_data = ClientResponseError.new("", 0, {"message": err if not err.is_empty() else "OAuth2 redirect missing code"})
		else:
			event_data = code
	)

	var tree = Engine.get_main_loop() as SceneTree
	var timer = tree.create_timer(timeout)
	var timed_out := false
	timer.timeout.connect(func(): timed_out = true)
	while event_data == null and error_data == null and not timed_out:
		await tree.process_frame

	if unsubscribe is Callable:
		unsubscribe.call()

	if timed_out:
		return ClientResponseError.new("", 0, {"message": "OAuth2 flow timed out"})
	if error_data:
		return error_data
	return await auth_with_oauth2_code(
		provider_name,
		event_data,
		str(provider.get("codeVerifier", "")),
		redirect_url,
		create_data,
		body,
		query,
		headers,
		expand,
		fields
	)

func auth_refresh(expand: String = "", fields: String = "", body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var params := query.duplicate()
	if not expand.is_empty() and not params.has("expand"):
		params["expand"] = expand
	if not fields.is_empty() and not params.has("fields"):
		params["fields"] = fields
	var data = await client.send("%s/auth-refresh" % base_collection_path(), "POST", headers, params, body)
	return _auth_response(data)

func request_password_reset(email: String, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var payload := body.duplicate()
	payload["email"] = email
	return await client.send("%s/request-password-reset" % base_collection_path(), "POST", headers, query, payload)

func confirm_password_reset(token: String, password: String, password_confirm: String, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var payload := body.duplicate()
	payload["token"] = token
	payload["password"] = password
	payload["passwordConfirm"] = password_confirm
	return await client.send("%s/confirm-password-reset" % base_collection_path(), "POST", headers, query, payload)

func request_verification(email: String, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var payload := body.duplicate()
	payload["email"] = email
	return await client.send("%s/request-verification" % base_collection_path(), "POST", headers, query, payload)

func confirm_verification(token: String, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var payload := body.duplicate()
	payload["token"] = token
	var res = await client.send("%s/confirm-verification" % base_collection_path(), "POST", headers, query, payload)
	_mark_verified(token)
	return res

func request_email_change(new_email: String, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var payload := body.duplicate()
	payload["newEmail"] = new_email
	return await client.send("%s/request-email-change" % base_collection_path(), "POST", headers, query, payload)

func confirm_email_change(token: String, password: String, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var payload := body.duplicate()
	payload["token"] = token
	payload["password"] = password
	var res = await client.send("%s/confirm-email-change" % base_collection_path(), "POST", headers, query, payload)
	_clear_if_same_token(token)
	return res

func request_otp(email: String, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var payload := body.duplicate()
	if not payload.has("email"):
		payload["email"] = email
	return await client.send("%s/request-otp" % base_collection_path(), "POST", headers, query, payload)

func auth_with_otp(otp_id: String, password: String, expand: String = "", fields: String = "", body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var payload := body.duplicate()
	if not payload.has("otpId"):
		payload["otpId"] = otp_id
	if not payload.has("password"):
		payload["password"] = password

	var params := query.duplicate()
	if not expand.is_empty() and not params.has("expand"):
		params["expand"] = expand
	if not fields.is_empty() and not params.has("fields"):
		params["fields"] = fields

	var data = await client.send("%s/auth-with-otp" % base_collection_path(), "POST", headers, params, payload)
	return _auth_response(data)

func impersonate(record_id: String, duration: int, expand: String = "", fields: String = "", body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var payload := body.duplicate()
	if not payload.has("duration"):
		payload["duration"] = duration

	var params := query.duplicate()
	if not expand.is_empty() and not params.has("expand"):
		params["expand"] = expand
	if not fields.is_empty() and not params.has("fields"):
		params["fields"] = fields

	var enriched_headers := headers.duplicate()
	if not enriched_headers.has("Authorization") and client.auth_store.is_valid():
		enriched_headers["Authorization"] = client.auth_store.token

	var BosBase = preload("res://gdscript-sdk/src/bosbase.gd")
	var new_client = BosBase.new(client.base_url, client.lang)
	var data = await new_client.send("%s/impersonate/%s" % [base_collection_path(), BosbaseUtils.encode_path_segment(record_id)], "POST", enriched_headers, params, payload)
	if data is ClientResponseError:
		return data
	new_client.auth_store.save(data.get("token", ""), data.get("record", {}))
	return new_client

func _auth_response(data: Variant) -> Variant:
	if data is ClientResponseError:
		return data
	if data is Dictionary:
		var token := data.get("token", "")
		var record := data.get("record")
		if token != "" and record != null:
			client.auth_store.save(token, record)
	return data

func _maybe_update_auth_record(item: Dictionary) -> void:
	var current = client.auth_store.model
	if current.is_empty():
		return
	if current.get("id", "") != item.get("id", ""):
		return
	var col_id = current.get("collectionId", current.get("collectionName", ""))
	if col_id != collection_id_or_name and current.get("collectionName", "") != collection_id_or_name:
		return
	var merged := current.duplicate()
	for k in item.keys():
		merged[k] = item[k]
	if current.has("expand") and item.has("expand"):
		var expand_current: Dictionary = current["expand"]
		var expand_new: Dictionary = item["expand"]
		for ek in expand_new.keys():
			expand_current[ek] = expand_new[ek]
		merged["expand"] = expand_current
	client.auth_store.save(client.auth_store.token, merged)

func _is_auth_record(record_id: String) -> bool:
	var current = client.auth_store.model
	if current.is_empty():
		return false
	var col_id = current.get("collectionId", current.get("collectionName", ""))
	return current.get("id", "") == record_id and (col_id == collection_id_or_name or current.get("collectionName", "") == collection_id_or_name)

func _mark_verified(token: String) -> void:
	var current = client.auth_store.model
	if current.is_empty():
		return
	var payload = _decode_token_payload(token)
	if payload and current.get("id", "") == payload.get("id", "") and current.get("collectionId", "") == payload.get("collectionId", "") and not current.get("verified", false):
		current["verified"] = true
		client.auth_store.save(client.auth_store.token, current)

func _clear_if_same_token(token: String) -> void:
	var current = client.auth_store.model
	if current.is_empty():
		return
	var payload = _decode_token_payload(token)
	if payload and current.get("id", "") == payload.get("id", "") and current.get("collectionId", "") == payload.get("collectionId", ""):
		client.auth_store.clear()

func _decode_token_payload(token: String) -> Dictionary:
	var parts = token.split(".")
	if parts.size() != 3:
		return {}
	var payload_part: String = parts[1]
	while payload_part.length() % 4 != 0:
		payload_part += "="
	var decoded = Marshalls.base64_to_raw(payload_part)
	var json_str = decoded.get_string_from_utf8()
	var parsed = JSON.parse_string(json_str)
	return parsed if parsed is Dictionary else {}
