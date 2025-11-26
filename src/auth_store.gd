class_name AuthStore
extends RefCounted

signal changed

var token: String = ""
var model: Dictionary = {}

# Path used for persistence. Set to empty string to disable disk persistence.
var storage_path: String
var persist: bool

func _init(storage_path: String = "user://bosbase_auth.json", persist: bool = true) -> void:
	self.storage_path = storage_path
	self.persist = persist

	if persist and storage_path:
		_load()

func is_valid() -> bool:
	return not token.is_empty()

func clear() -> void:
	token = ""
	model = {}
	if persist:
		_save()
	changed.emit()

func save(new_token: String, new_model: Dictionary = {}) -> void:
	token = new_token
	model = new_model
	if persist:
		_save()
	changed.emit()

func export_data() -> Dictionary:
	return {
		"token": token,
		"model": model,
	}

func import_data(data: Dictionary) -> void:
	token = data.get("token", "")
	model = data.get("model", {}) if data.has("model") else {}
	if persist:
		_save()
	changed.emit()

func _save() -> void:
	if storage_path.is_empty():
		return
	var payload := {"token": token, "model": model}
	var json_str := JSON.stringify(payload)
	var file := FileAccess.open(storage_path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()

func _load() -> void:
	if storage_path.is_empty() or not FileAccess.file_exists(storage_path):
		return
	var file := FileAccess.open(storage_path, FileAccess.READ)
	if not file:
		return
	var content := file.get_as_text()
	file.close()
	var parse := JSON.parse_string(content)
	if typeof(parse) == TYPE_DICTIONARY:
		token = parse.get("token", "")
		model = parse.get("model", {}) if parse.has("model") else {}
