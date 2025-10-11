extends Node3D
class_name Seat

@export var marker3D: Marker3D
@onready var area: Area3D = $Area3D
var occupied_by: Node3D = null
var player_in_range: Node3D = null

func _ready() -> void:
	add_to_group("seats")
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	print("🪑 Seat registrado:", name)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = body
		print("🧍 Player entrou na área de", name)

func _on_body_exited(body: Node3D) -> void:
	if body == player_in_range:
		player_in_range = null
		print("🚶 Player saiu da área de", name)

func get_sit_transform() -> Transform3D:
	return marker3D.global_transform if marker3D else global_transform

func can_sit() -> bool:
	return player_in_range != null and occupied_by == null

func try_reserve(by: Node3D) -> bool:
	if occupied_by:
		return false
	occupied_by = by
	return true

func release(by: Node3D) -> void:
	if occupied_by == by:
		occupied_by = null
