class_name BosbaseUtils
extends RefCounted

static func to_serializable(value: Variant) -> Variant:
	if value == null:
		return null

	if value is Dictionary:
		var result: Dictionary = {}
		for k in value.keys():
			var v = value[k]
			if v == null:
				continue
			result[k] = to_serializable(v)
		return result

	if value is Array:
		var result: Array = []
		for v in value:
			result.append(to_serializable(v))
		return result

	# Godot objects with `to_dict` or `to_json` helpers.
	if value is Object:
		if value.has_method("to_dict"):
			return value.call("to_dict")
		if value.has_method("to_json"):
			var json_val = value.call("to_json")
			if json_val is String:
				var parsed = JSON.parse_string(json_val)
				return parsed if parsed != null else json_val
			return json_val

	return value

static func normalize_query_params(params: Dictionary) -> Dictionary:
	if params.is_empty():
		return {}

	var normalized: Dictionary = {}
	for key in params.keys():
		var value = params[key]
		if value == null:
			continue

		var values: Array
		if value is Array:
			values = value
		else:
			values = [value]

		var bucket: Array = []
		for item in values:
			if item == null:
				continue
			bucket.append(str(item))

		if not bucket.is_empty():
			normalized[str(key)] = bucket

	return normalized

static func encode_path_segment(value: Variant) -> String:
	return str(value).uri_encode()

static func build_relative_url(path: String, query: Dictionary = {}) -> String:
	var rel = "/" + path.lstrip("/")
	if query.is_empty():
		return rel
	var normalized = normalize_query_params(query)
	if normalized.is_empty():
		return rel

	var parts: Array[String] = []
	for key in normalized.keys():
		var values: Array = normalized[key]
		for item in values:
			parts.append("%s=%s" % [key.uri_encode(), str(item).uri_encode()])
	return rel + "?" + "&".join(parts)
