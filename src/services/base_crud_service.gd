extends "res://gdscript-sdk/src/services/base_service.gd"
class_name BaseCrudService

const ClientResponseError = preload("res://gdscript-sdk/src/client_response_error.gd")
const BosbaseUtils = preload("res://gdscript-sdk/src/utils.gd")

func base_crud_path() -> String:
	return "" # override in subclasses

func get_full_list(
	batch: int = 500,
	expand: String = "",
	filter: String = "",
	sort: String = "",
	fields: String = "",
	query: Dictionary = {},
	headers: Dictionary = {}
) -> Variant:
	if batch <= 0:
		return ClientResponseError.new("", 0, {"message": "batch must be > 0"}, false, null)

	var result: Array = []
	var page := 1
	while true:
		var data = await get_list(
			page,
			batch,
			true,
			expand,
			filter,
			sort,
			fields,
			query,
			headers
		)
		if data is ClientResponseError:
			return data
		var items: Array = data.get("items", [])
		result.append_array(items)
		var per_page := int(data.get("perPage", batch))
		if items.size() < per_page:
			break
		page += 1
	return result

func get_list(
	page: int = 1,
	per_page: int = 30,
	skip_total: bool = false,
	expand: String = "",
	filter: String = "",
	sort: String = "",
	fields: String = "",
	query: Dictionary = {},
	headers: Dictionary = {}
) -> Variant:
	var params := query.duplicate()
	if not params.has("page"):
		params["page"] = page
	if not params.has("perPage"):
		params["perPage"] = per_page
	if not params.has("skipTotal"):
		params["skipTotal"] = skip_total
	if not filter.is_empty():
		if not params.has("filter"):
			params["filter"] = filter
	if not sort.is_empty():
		if not params.has("sort"):
			params["sort"] = sort
	if not expand.is_empty():
		if not params.has("expand"):
			params["expand"] = expand
	if not fields.is_empty():
		if not params.has("fields"):
			params["fields"] = fields

	return await client.send(base_crud_path(), "GET", headers, params)

func get_one(
	record_id: String,
	expand: String = "",
	fields: String = "",
	query: Dictionary = {},
	headers: Dictionary = {}
) -> Variant:
	if record_id.is_empty():
		return ClientResponseError.new(
			client.build_url("%s/" % base_crud_path()),
			404,
			{
				"code": 404,
				"message": "Missing required record id.",
				"data": {},
			}
		)

	var params := query.duplicate()
	if not expand.is_empty():
		if not params.has("expand"):
			params["expand"] = expand
	if not fields.is_empty():
		if not params.has("fields"):
			params["fields"] = fields

	return await client.send("%s/%s" % [base_crud_path(), BosbaseUtils.encode_path_segment(record_id)], "GET", headers, params)

func get_first_list_item(
	filter: String,
	expand: String = "",
	fields: String = "",
	query: Dictionary = {},
	headers: Dictionary = {}
) -> Variant:
	var data = await get_list(1, 1, true, expand, filter, "", fields, query, headers)
	if data is ClientResponseError:
		return data
	var items: Array = data.get("items", [])
	if items.is_empty():
		return ClientResponseError.new(
			"",
			404,
			{
				"code": 404,
				"message": "The requested resource wasn't found.",
				"data": {},
			}
		)
	return items[0]

func create(
	body: Dictionary = {},
	query: Dictionary = {},
	files: Variant = null,
	headers: Dictionary = {},
	expand: String = "",
	fields: String = ""
) -> Variant:
	var params := query.duplicate()
	if not expand.is_empty():
		if not params.has("expand"):
			params["expand"] = expand
	if not fields.is_empty():
		if not params.has("fields"):
			params["fields"] = fields

	return await client.send(base_crud_path(), "POST", headers, params, body, files)

func update(
	record_id: String,
	body: Dictionary = {},
	query: Dictionary = {},
	files: Variant = null,
	headers: Dictionary = {},
	expand: String = "",
	fields: String = ""
) -> Variant:
	var params := query.duplicate()
	if not expand.is_empty():
		if not params.has("expand"):
			params["expand"] = expand
	if not fields.is_empty():
		if not params.has("fields"):
			params["fields"] = fields

	var encoded_id := BosbaseUtils.encode_path_segment(record_id)
	return await client.send("%s/%s" % [base_crud_path(), encoded_id], "PATCH", headers, params, body, files)

func delete(
	record_id: String,
	body: Dictionary = {},
	query: Dictionary = {},
	headers: Dictionary = {}
) -> Variant:
	var encoded_id := BosbaseUtils.encode_path_segment(record_id)
	return await client.send("%s/%s" % [base_crud_path(), encoded_id], "DELETE", headers, query, body)
