extends "res://gdscript-sdk/src/services/base_service.gd"
class_name CronService

const BosbaseUtils = preload("res://gdscript-sdk/src/utils.gd")

func get_full_list(query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	var data = await client.send("/api/crons", "GET", headers, query)
	if data == null:
		return []
	return data

func run(job_id: String, body: Dictionary = {}, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("/api/crons/%s" % BosbaseUtils.encode_path_segment(job_id), "POST", headers, query, body)
