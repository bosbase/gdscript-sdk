extends "res://gdscript-sdk/src/services/base_service.gd"
class_name HealthService

func check(query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("/api/health", "GET", headers, query)
