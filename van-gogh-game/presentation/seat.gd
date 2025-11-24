extends Node3D
class_name Seat

@export var marker3D: Marker3D
@export var dialogCameraService: DialogCameraService
@export var dialogService: DialogicService
@export var player: PlayerView
@export var mainDialog: Node3D

@onready var area: Area3D = $Area3D

var occupied_by: Node3D = null
var player_in_range: Node3D = null

func _ready() -> void:
	add_to_group("seats")
	add_to_group("interactables")
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if occupied_by != null and Dialogic.VAR.get_variable("final_status"):
		player.collision_layer = 2
		mainDialog.npc_entity_path.trigger_dialog()
		occupied_by = null
	return
	
func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = body
		EventBus.player_entered_interactable_area.emit(self)

func _on_body_exited(body: Node3D) -> void:
	if body == player_in_range:
		player_in_range = null
		EventBus.player_exited_interactable_area.emit(self)

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
