extends "res://gdscript-sdk/src/services/base_service.gd"
class_name VectorService

const BosbaseUtils = preload("res://gdscript-sdk/src/utils.gd")

var base_path := "/api/vectors"

func _collection_path(collection: String) -> String:
	if not collection.is_empty():
		return "%s/%s" % [base_path, BosbaseUtils.encode_path_segment(collection)]
	return base_path

func insert(document: Dictionary, collection: String = "", query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send(_collection_path(collection), "POST", headers, query, document)

func batch_insert(options: Dictionary, collection: String = "", query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("%s/documents/batch" % _collection_path(collection), "POST", headers, query, options)

func update(document_id: String, document: Dictionary, collection: String = "", query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("%s/%s" % [_collection_path(collection), BosbaseUtils.encode_path_segment(document_id)], "PATCH", headers, query, document)

func delete(document_id: String, collection: String = "", body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("%s/%s" % [_collection_path(collection), BosbaseUtils.encode_path_segment(document_id)], "DELETE", headers, query, body)

func search(options: Dictionary, collection: String = "", query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("%s/documents/search" % _collection_path(collection), "POST", headers, query, options)

func get(document_id: String, collection: String = "", query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("%s/%s" % [_collection_path(collection), BosbaseUtils.encode_path_segment(document_id)], "GET", headers, query)

func list(collection: String = "", page: int = 0, per_page: int = 0, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var params := query.duplicate()
	if page > 0:
		params["page"] = page
	if per_page > 0:
		params["perPage"] = per_page
	return await client.send(_collection_path(collection), "GET", headers, params)

func create_collection(name: String, config: Dictionary, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("%s/collections/%s" % [base_path, BosbaseUtils.encode_path_segment(name)], "POST", headers, query, config)

func update_collection(name: String, config: Dictionary, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("%s/collections/%s" % [base_path, BosbaseUtils.encode_path_segment(name)], "PATCH", headers, query, config)

func delete_collection(name: String, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("%s/collections/%s" % [base_path, BosbaseUtils.encode_path_segment(name)], "DELETE", headers, query, body)

func list_collections(query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var data = await client.send("%s/collections" % base_path, "GET", headers, query)
	if data == null:
		return []
	return data
