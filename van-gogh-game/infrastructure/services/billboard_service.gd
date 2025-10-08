extends Node
class_name BillboardService

func face_camera(node: Node3D) -> void:
	if not node:
		return
	var cam := node.get_viewport().get_camera_3d()
	if not cam:
		return
	var look := cam.global_position
	look.y = node.global_position.y
	node.look_at(look, Vector3.UP)
