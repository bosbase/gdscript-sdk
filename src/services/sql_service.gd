extends "res://gdscript-sdk/src/services/base_service.gd"
class_name SQLService

const ClientResponseError = preload("res://gdscript-sdk/src/client_response_error.gd")

# Executes a raw SQL statement via the superuser-only /api/sql/execute endpoint.
func execute(
	query_text: String,
	body: Dictionary = {},
	query: Dictionary = {},
	headers: Dictionary = {}
) -> Variant:
	var trimmed := query_text.strip_edges()
	if trimmed.is_empty():
		return ClientResponseError.new("", 0, {"message": "query is required"})

	var payload := body.duplicate()
	if not payload.has("query"):
		payload["query"] = trimmed

	return await client.send("/api/sql/execute", "POST", headers, query, payload)
