extends "res://gdscript-sdk/src/services/base_crud_service.gd"
class_name CollectionService

const BosbaseUtils = preload("res://gdscript-sdk/src/utils.gd")
const ClientResponseError = preload("res://gdscript-sdk/src/client_response_error.gd")

func base_crud_path() -> String:
	return "/api/collections"

func delete_collection(collection_id_or_name: String, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await delete(collection_id_or_name, body, query, headers)

func truncate(collection_id_or_name: String, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var encoded := BosbaseUtils.encode_path_segment(collection_id_or_name)
	return await client.send("%s/%s/truncate" % [base_crud_path(), encoded], "DELETE", headers, query, body)

func import_collections(collections: Variant, delete_missing: bool = false, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var payload := body.duplicate()
	payload["collections"] = collections
	payload["deleteMissing"] = delete_missing
	return await client.send("%s/import" % base_crud_path(), "PUT", headers, query, payload)

func get_scaffolds(body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var payload := body.duplicate()
	return await client.send("%s/meta/scaffolds" % base_crud_path(), "GET", headers, query, payload)

func create_from_scaffold(scaffold_type: String, name: String, overrides: Dictionary = {}, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var scaffolds = await get_scaffolds({}, query, headers)
	if scaffolds is ClientResponseError:
		return scaffolds
	var scaffold = scaffolds.get(scaffold_type) if scaffolds is Dictionary else null
	if scaffold == null:
		return ClientResponseError.new("", 0, {"message": "Scaffold for type '%s' not found." % scaffold_type})

	var data: Dictionary = scaffold
	data["name"] = name
	for k in overrides.keys():
		data[k] = overrides[k]
	for k in body.keys():
		data[k] = body[k]
	return await create(data, query, null, headers)

func create_base(name: String, overrides: Dictionary = {}, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await create_from_scaffold("base", name, overrides, body, query, headers)

func create_auth(name: String, overrides: Dictionary = {}, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await create_from_scaffold("auth", name, overrides, body, query, headers)

func create_view(name: String, view_query: String = "", overrides: Dictionary = {}, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var scaffold_overrides := overrides.duplicate()
	if not view_query.is_empty():
		scaffold_overrides["viewQuery"] = view_query
	return await create_from_scaffold("view", name, scaffold_overrides, body, query, headers)

func add_index(collection_id_or_name: String, columns: Array, unique: bool = false, index_name: String = "", query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	if columns.is_empty():
		return ClientResponseError.new("", 0, {"message": "At least one column must be specified."})

	var collection = await get_one(collection_id_or_name, "", "", query, headers)
	if collection is ClientResponseError:
		return collection
	var fields: Array = collection.get("fields", [])
	var field_names: Array = []
	for field in fields:
		if field is Dictionary and field.has("name"):
			field_names.append(field["name"])

	for column in columns:
		if column != "id" and not field_names.has(column):
			return ClientResponseError.new("", 0, {"message": 'Field "%s" does not exist in the collection.' % column})

	var collection_name := collection.get("name", collection_id_or_name)
	var idx_name := index_name if not index_name.is_empty() else "idx_%s_%s" % [collection_name, Array(columns).join("_")]
	var columns_str_parts: Array[String] = []
	for column in columns:
		columns_str_parts.append("`%s`" % column)
	var columns_str := ", ".join(columns_str_parts)
	var index_sql := ""
	if unique:
		index_sql = "CREATE UNIQUE INDEX `%s` ON `%s` (%s)" % [idx_name, collection_name, columns_str]
	else:
		index_sql = "CREATE INDEX `%s` ON `%s` (%s)" % [idx_name, collection_name, columns_str]

	var indexes: Array = collection.get("indexes", [])
	if indexes.has(index_sql):
		return ClientResponseError.new("", 0, {"message": "Index already exists."})

	indexes.append(index_sql)
	collection["indexes"] = indexes
	return await update(collection_id_or_name, collection, query, null, headers)

func remove_index(collection_id_or_name: String, columns: Array, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	if columns.is_empty():
		return ClientResponseError.new("", 0, {"message": "At least one column must be specified."})

	var collection = await get_one(collection_id_or_name, "", "", query, headers)
	if collection is ClientResponseError:
		return collection

	var indexes: Array = collection.get("indexes", [])
	var filtered: Array = []
	for idx in indexes:
		if typeof(idx) != TYPE_STRING:
			continue
		var match := true
		for column in columns:
			var backticked := "`%s`" % column
			if idx.find(backticked) == -1 and idx.find("(%s)" % column) == -1 and idx.find("(%s," % column) == -1 and idx.find(", %s)" % column) == -1:
				match = false
				break
		if not match:
			filtered.append(idx)
	if filtered.size() == indexes.size():
		return ClientResponseError.new("", 0, {"message": "Index not found."})

	collection["indexes"] = filtered
	return await update(collection_id_or_name, collection, query, null, headers)

func get_indexes(collection_id_or_name: String, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var collection = await get_one(collection_id_or_name, "", "", query, headers)
	if collection is ClientResponseError:
		return collection
	var existing: Array = collection.get("indexes", [])
	var result: Array = []
	for idx in existing:
		if idx is String:
			result.append(idx)
	return result

func get_schema(collection_id_or_name: String, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var encoded := BosbaseUtils.encode_path_segment(collection_id_or_name)
	return await client.send("%s/%s/schema" % [base_crud_path(), encoded], "GET", headers, query)

func get_all_schemas(query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("%s/schemas" % base_crud_path(), "GET", headers, query)
