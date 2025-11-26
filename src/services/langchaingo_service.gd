extends "res://gdscript-sdk/src/services/base_service.gd"
class_name LangChaingoService

var base_path := "/api/langchaingo"

func completions(payload: Dictionary, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("%s/completions" % base_path, "POST", headers, query, payload)

func rag(payload: Dictionary, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("%s/rag" % base_path, "POST", headers, query, payload)

func query_documents(payload: Dictionary, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("%s/documents/query" % base_path, "POST", headers, query, payload)

func sql(payload: Dictionary, query: Dictionary = {}, headers: Dictionary = {}) -> Variant:
	return await client.send("%s/sql" % base_path, "POST", headers, query, payload)
