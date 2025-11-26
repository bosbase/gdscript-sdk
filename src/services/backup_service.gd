extends "res://gdscript-sdk/src/services/base_service.gd"
class_name BackupService

const BosbaseUtils = preload("res://gdscript-sdk/src/utils.gd")

func get_full_list(query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var data = await client.send("/api/backups", "GET", headers, query)
	if data == null:
		return []
	return data

func create(name: String, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var payload := body.duplicate()
	if not payload.has("name"):
		payload["name"] = name
	return await client.send("/api/backups", "POST", headers, query, payload)

func upload(files: Variant, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("/api/backups/upload", "POST", headers, query, body, files)

func delete(key: String, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("/api/backups/%s" % BosbaseUtils.encode_path_segment(key), "DELETE", headers, query, body)

func restore(key: String, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("/api/backups/%s/restore" % BosbaseUtils.encode_path_segment(key), "POST", headers, query, body)

func get_download_url(token: String, key: String, query: Dictionary = {}) -> String:
	var params := query.duplicate()
	if not params.has("token"):
		params["token"] = token
	return client.build_url("/api/backups/%s" % BosbaseUtils.encode_path_segment(key), params)
