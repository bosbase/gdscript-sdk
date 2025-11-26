extends "res://gdscript-sdk/src/services/base_service.gd"
class_name FileService

const BosbaseUtils = preload("res://gdscript-sdk/src/utils.gd")

func get_url(
	record: Dictionary,
	filename: String,
	thumb: String = "",
	token: String = "",
	download: bool = false,
	query: Dictionary = {}
) -> String:
	var record_id := str(record.get("id", ""))
	if record_id.is_empty() or filename.is_empty():
		return ""
	var collection := str(record.get("collectionId", record.get("collectionName", "")))

	var params := query.duplicate()
	if not thumb.is_empty() and not params.has("thumb"):
		params["thumb"] = thumb
	if not token.is_empty() and not params.has("token"):
		params["token"] = token
	if download:
		params["download"] = ""

	return client.build_url(
		"/api/files/%s/%s/%s" % [
			BosbaseUtils.encode_path_segment(collection),
			BosbaseUtils.encode_path_segment(record_id),
			BosbaseUtils.encode_path_segment(filename),
		],
		params
	)

func get_token(body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var data = await client.send("/api/files/token", "POST", headers, query, body)
	if data is Dictionary:
		return data.get("token", "")
	return data
