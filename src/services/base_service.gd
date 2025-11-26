extends RefCounted
class_name BaseService

const BosBase = preload("res://gdscript-sdk/src/bosbase.gd")

var client: BosBase

func _init(client: BosBase) -> void:
	self.client = client
