extends "res://gdscript-sdk/src/services/base_service.gd"
class_name GraphQLService

func query(
	query_text: String,
	variables: Dictionary = {},
	operation_name: String = "",
	query_params: Dictionary = {},
	headers: Dictionary = {},
	timeout: float = -1.0
) -> Variant:
	var payload: Dictionary = {
		"query": query_text,
		"variables": variables.duplicate(),
	}
	if not operation_name.is_empty():
		payload["operationName"] = operation_name
	return await client.send("/api/graphql", "POST", headers, query_params, payload, null, timeout)
