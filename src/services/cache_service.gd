extends "res://gdscript-sdk/src/services/base_service.gd"
class_name CacheService

const BosbaseUtils = preload("res://gdscript-sdk/src/utils.gd")

func list(query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var data = await client.send("/api/cache", "GET", headers, query)
	if data is Dictionary and data.has("items"):
		return data["items"]
	if data == null:
		return []
	return data

func create(
	name: String,
	size_bytes: Variant = null,
	default_ttl_seconds: Variant = null,
	read_timeout_ms: Variant = null,
	body: Dictionary = {},
	query: Dictionary = {},
	headers: Dictionary = {}
) -> Variant:
	var payload := body.duplicate()
	payload["name"] = name
	if size_bytes != null:
		payload["sizeBytes"] = size_bytes
	if default_ttl_seconds != null:
		payload["defaultTTLSeconds"] = default_ttl_seconds
	if read_timeout_ms != null:
		payload["readTimeoutMs"] = read_timeout_ms
	return await client.send("/api/cache", "POST", headers, query, payload)

func update(name: String, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("/api/cache/%s" % BosbaseUtils.encode_path_segment(name), "PATCH", headers, query, body)

func delete(name: String, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("/api/cache/%s" % BosbaseUtils.encode_path_segment(name), "DELETE", headers, query)

func set_entry(
	cache: String,
	key: String,
	value: Variant,
	ttl_seconds: Variant = null,
	body: Dictionary = {},
	query: Dictionary = {},
	headers: Dictionary = {}
) -> Variant:
	var payload := body.duplicate()
	payload["value"] = value
	if ttl_seconds != null:
		payload["ttlSeconds"] = ttl_seconds
	return await client.send("/api/cache/%s/entries/%s" % [BosbaseUtils.encode_path_segment(cache), BosbaseUtils.encode_path_segment(key)], "PUT", headers, query, payload)

func get_entry(cache: String, key: String, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("/api/cache/%s/entries/%s" % [BosbaseUtils.encode_path_segment(cache), BosbaseUtils.encode_path_segment(key)], "GET", headers, query)

func renew_entry(
	cache: String,
	key: String,
	ttl_seconds: Variant = null,
	body: Dictionary = {},
	query: Dictionary = {},
	headers: Dictionary = {}
) -> Variant:
	var payload := body.duplicate()
	if ttl_seconds != null:
		payload["ttlSeconds"] = ttl_seconds
	return await client.send("/api/cache/%s/entries/%s" % [cache, key], "PATCH", headers, query, payload)

func delete_entry(cache: String, key: String, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("/api/cache/%s/entries/%s" % [BosbaseUtils.encode_path_segment(cache), BosbaseUtils.encode_path_segment(key)], "DELETE", headers, query)
