extends "res://gdscript-sdk/src/services/base_service.gd"
class_name LLMDocumentService

const BosbaseUtils = preload("res://gdscript-sdk/src/utils.gd")

var base_path := "/api/llm-documents"

func _collection_path(collection: String) -> String:
	return "%s/%s" % [base_path, BosbaseUtils.encode_path_segment(collection)]

func list_collections(query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var data = await client.send("%s/collections" % base_path, "GET", headers, query)
	if data == null:
		return []
	return data

func create_collection(name: String, metadata: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("%s/collections/%s" % [base_path, BosbaseUtils.encode_path_segment(name)], "POST", headers, query, {"metadata": metadata})

func delete_collection(name: String, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("%s/collections/%s" % [base_path, BosbaseUtils.encode_path_segment(name)], "DELETE", headers, query)

func insert(collection: String, document: Dictionary, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send(_collection_path(collection), "POST", headers, query, document)

func get(collection: String, document_id: String, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("%s/%s" % [_collection_path(collection), BosbaseUtils.encode_path_segment(document_id)], "GET", headers, query)

func update(collection: String, document_id: String, document: Dictionary, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("%s/%s" % [_collection_path(collection), BosbaseUtils.encode_path_segment(document_id)], "PATCH", headers, query, document)

func delete(collection: String, document_id: String, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("%s/%s" % [_collection_path(collection), BosbaseUtils.encode_path_segment(document_id)], "DELETE", headers, query)

func list(collection: String, page: int = 0, per_page: int = 0, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var params := query.duplicate()
	if page > 0:
		params["page"] = page
	if per_page > 0:
		params["perPage"] = per_page
	return await client.send(_collection_path(collection), "GET", headers, params)

func query(collection: String, options: Dictionary, query_params: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("%s/documents/query" % _collection_path(collection), "POST", headers, query_params, options)
