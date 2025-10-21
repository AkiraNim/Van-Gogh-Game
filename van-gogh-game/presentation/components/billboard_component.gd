@tool
extends Node3D
class_name BillboardComponent

@export var active: bool = true
@export var update_in_editor: bool = true
@export var service: BillboardService

func _process(_delta: float) -> void:
	if not active:
		return
	if Engine.is_editor_hint() and not update_in_editor:
		return
	if service:
		service.face_camera(self)
	else:
		_default_face_camera()

func _default_face_camera():
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
	var look := cam.global_position
	look.y = global_position.y
	look_at(look, Vector3.UP)
