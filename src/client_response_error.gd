class_name ClientResponseError
extends RefCounted

var url: String
var status: int
var response: Dictionary
var is_abort: bool
var original_error: Variant

func _init(
	url: String = "",
	status: int = 0,
	response: Dictionary = {},
	is_abort: bool = false,
	original_error: Variant = null
) -> void:
	self.url = url
	self.status = status
	self.response = response
	self.is_abort = is_abort
	self.original_error = original_error

func to_string() -> String:
	var parts: Array[String] = []
	if url:
		parts.append("url=%s" % url)
	if status != 0:
		parts.append("status=%s" % status)
	if response:
		parts.append("response=%s" % JSON.stringify(response))
	if is_abort:
		parts.append("is_abort=true")
	if original_error != null:
		parts.append("original_error=%s" % str(original_error))
	return "ClientResponseError(%s)" % ", ".join(parts)
