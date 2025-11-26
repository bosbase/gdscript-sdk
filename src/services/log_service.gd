extends "res://gdscript-sdk/src/services/base_service.gd"
class_name LogService

const ClientResponseError = preload("res://gdscript-sdk/src/client_response_error.gd")

func get_list(
	page: int = 1,
	per_page: int = 30,
	filter: String = "",
	sort: String = "",
	query: Dictionary = {},
	headers: Dictionary = {}
) -> Variant:
	var params := query.duplicate()
	if not params.has("page"):
		params["page"] = page
	if not params.has("perPage"):
		params["perPage"] = per_page
	if not filter.is_empty() and not params.has("filter"):
		params["filter"] = filter
	if not sort.is_empty() and not params.has("sort"):
		params["sort"] = sort
	return await client.send("/api/logs", "GET", headers, params)

func get_one(log_id: String, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	if log_id.is_empty():
		return ClientResponseError.new(
			client.build_url("/api/logs/"),
			404,
			{
				"code": 404,
				"message": "Missing required log id.",
				"data": {},
			}
		)
	return await client.send("/api/logs/%s" % log_id, "GET", headers, query)

func get_stats(query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var data = await client.send("/api/logs/stats", "GET", headers, query)
	if data is Array:
		return data
	if data == null:
		return []
	return data
