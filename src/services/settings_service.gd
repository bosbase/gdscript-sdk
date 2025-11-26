extends "res://gdscript-sdk/src/services/base_service.gd"
class_name SettingsService

const ClientResponseError = preload("res://gdscript-sdk/src/client_response_error.gd")

func get_all(query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("/api/settings", "GET", headers, query)

func update(body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("/api/settings", "PATCH", headers, query, body)

func test_s3(filesystem: String = "storage", body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var payload := body.duplicate()
	if not payload.has("filesystem"):
		payload["filesystem"] = filesystem
	return await client.send("/api/settings/test/s3", "POST", headers, query, payload)

func test_email(
	to_email: String,
	template: String,
	collection: String = "",
	body: Dictionary = {},
	query: Dictionary = {},
	headers: Dictionary = {}
) -> Variant:
	var payload := body.duplicate()
	if not payload.has("email"):
		payload["email"] = to_email
	if not payload.has("template"):
		payload["template"] = template
	if collection != "" and not payload.has("collection"):
		payload["collection"] = collection
	return await client.send("/api/settings/test/email", "POST", headers, query, payload)

func generate_apple_client_secret(
	client_id: String,
	team_id: String,
	key_id: String,
	private_key: String,
	duration: int,
	body: Dictionary = {},
	query: Dictionary = {},
	headers: Dictionary = {}
) -> Variant:
	var payload := body.duplicate()
	if not payload.has("clientId"):
		payload["clientId"] = client_id
	if not payload.has("teamId"):
		payload["teamId"] = team_id
	if not payload.has("keyId"):
		payload["keyId"] = key_id
	if not payload.has("privateKey"):
		payload["privateKey"] = private_key
	if not payload.has("duration"):
		payload["duration"] = duration
	return await client.send("/api/settings/apple/generate-client-secret", "POST", headers, query, payload)

func get_category(category: String, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var settings = await get_all(query, headers)
	if settings is Dictionary:
		return settings.get(category)
	return null

func update_meta(
	app_name: String = "",
	app_url: String = "",
	sender_name: String = "",
	sender_address: String = "",
	hide_controls: Variant = null,
	query: Dictionary = {},
	headers: Dictionary = {}
) -> Variant:
	var meta: Dictionary = {}
	if app_name != "":
		meta["appName"] = app_name
	if app_url != "":
		meta["appURL"] = app_url
	if sender_name != "":
		meta["senderName"] = sender_name
	if sender_address != "":
		meta["senderAddress"] = sender_address
	if hide_controls != null:
		meta["hideControls"] = hide_controls
	return await update({"meta": meta}, query, headers)

func get_application_settings(query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var settings = await get_all(query, headers)
	if settings is ClientResponseError:
		return settings
	return {
		"meta": settings.get("meta"),
		"trustedProxy": settings.get("trustedProxy"),
		"rateLimits": settings.get("rateLimits"),
		"batch": settings.get("batch"),
	}

func update_application_settings(
	meta: Dictionary = {},
	trusted_proxy: Dictionary = {},
	rate_limits: Dictionary = {},
	batch: Dictionary = {},
	query: Dictionary = {},
	headers: Dictionary = {}
) -> Variant:
	var payload: Dictionary = {}
	if not meta.is_empty():
		payload["meta"] = meta
	if not trusted_proxy.is_empty():
		payload["trustedProxy"] = trusted_proxy
	if not rate_limits.is_empty():
		payload["rateLimits"] = rate_limits
	if not batch.is_empty():
		payload["batch"] = batch
	return await update(payload, query, headers)
