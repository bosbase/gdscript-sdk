extends "res://gdscript-sdk/src/services/base_service.gd"
class_name BatchService

const BosbaseUtils = preload("res://gdscript-sdk/src/utils.gd")

var _requests: Array = []
var _collections: Dictionary = {}

func collection(collection_id_or_name: String) -> Variant:
	if not _collections.has(collection_id_or_name):
		_collections[collection_id_or_name] = SubBatchService.new(self, collection_id_or_name)
	return _collections[collection_id_or_name]

func queue_request(method: String, url: String, headers: Dictionary = {}, body: Dictionary = {}, files: Array = []) -> void:
	_requests.append({
		"method": method,
		"url": url,
		"headers": headers.duplicate(),
		"body": BosbaseUtils.to_serializable(body) if body != null else {},
		"files": files.duplicate(),
	})

func send(body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var requests_payload: Array = []
	var attachments: Array = []

	for i in range(_requests.size()):
		var req = _requests[i]
		requests_payload.append({
			"method": req["method"],
			"url": req["url"],
			"headers": req["headers"],
			"body": req["body"],
		})
		for file_entry in req["files"]:
			attachments.append({
				"name": "requests.%s.%s" % [str(i), file_entry.get("name", "")],
				"filename": file_entry.get("filename", file_entry.get("name", "")),
				"content_type": file_entry.get("content_type", "application/octet-stream"),
				"data": file_entry.get("data", PackedByteArray()),
			})

	var payload := body.duplicate()
	payload["requests"] = requests_payload

	var response = await client.send("/api/batch", "POST", headers, query, payload, attachments.is_empty() ? null : attachments)
	_requests.clear()
	return response if response != null else []


class SubBatchService:
	extends RefCounted

	var _batch: BatchService
	var _collection: String

	func _init(batch: BatchService, collection_id_or_name: String) -> void:
		_batch = batch
		_collection = collection_id_or_name

	func _collection_url() -> String:
		var encoded := BosbaseUtils.encode_path_segment(_collection)
		return "/api/collections/%s/records" % encoded

	func create(body: Dictionary = {}, query: Dictionary = {}, files: Variant = null, headers: Dictionary = {}, expand: String = "", fields: String = "") -> void:
		var params := query.duplicate()
		if not expand.is_empty() and not params.has("expand"):
			params["expand"] = expand
		if not fields.is_empty() and not params.has("fields"):
			params["fields"] = fields
		_batch.queue_request("POST", BosbaseUtils.build_relative_url(_collection_url(), params), headers, body, _batch.client._normalize_files(files))

	func upsert(body: Dictionary = {}, query: Dictionary = {}, files: Variant = null, headers: Dictionary = {}, expand: String = "", fields: String = "") -> void:
		var params := query.duplicate()
		if not expand.is_empty() and not params.has("expand"):
			params["expand"] = expand
		if not fields.is_empty() and not params.has("fields"):
			params["fields"] = fields
		_batch.queue_request("PUT", BosbaseUtils.build_relative_url(_collection_url(), params), headers, body, _batch.client._normalize_files(files))

	func update(record_id: String, body: Dictionary = {}, query: Dictionary = {}, files: Variant = null, headers: Dictionary = {}, expand: String = "", fields: String = "") -> void:
		var params := query.duplicate()
		if not expand.is_empty() and not params.has("expand"):
			params["expand"] = expand
		if not fields.is_empty() and not params.has("fields"):
			params["fields"] = fields
		var encoded_id := BosbaseUtils.encode_path_segment(record_id)
		_batch.queue_request("PATCH", BosbaseUtils.build_relative_url("%s/%s" % [_collection_url(), encoded_id], params), headers, body, _batch.client._normalize_files(files))

	func delete(record_id: String, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> void:
		var encoded_id := BosbaseUtils.encode_path_segment(record_id)
		_batch.queue_request("DELETE", BosbaseUtils.build_relative_url("%s/%s" % [_collection_url(), encoded_id], query), headers, body)
