extends CollisionShape3D

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.name == "Bus":
		body.can_move = false
		body.move_blocked = true
