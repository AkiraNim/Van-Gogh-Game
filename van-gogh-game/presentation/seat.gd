extends Node3D
class_name Seat

@export var marker3D: Marker3D
@export var dialogCameraService: DialogCameraService
@export var dialogService: DialogicService
@export var npc_entity_path: NpcEntity
@export var player: PlayerView
@export var bus: CharacterBody3D

@onready var area: Area3D = $Area3D
var occupied_by: Node3D = null
var player_in_range: Node3D = null

func _ready() -> void:
	add_to_group("seats")
	add_to_group("interactables")
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	#if str(Dialogic.VAR.get_variable("bus_status")).strip_edges() == "passed" and bus.can_move == false:
		#bus.can_move = true
		#await get_tree().create_timer(2.0).timeout
		#bus.hide()
	if str(Dialogic.VAR.get_variable("bus_status")).strip_edges() == "can_pass":
		npc_entity_path.trigger_dialog()
		bus.show()
		bus.can_move = true
		await get_tree().create_timer(0.2).timeout
		$"../EnviromentNode/LightingService/Sky".hide()
		#await get_tree().create_timer(0.2).timeout
		#$"../EnviromentNode/LightingService/Sky".show()
		return
		
	if occupied_by != null and str(Dialogic.VAR.get_variable("final_status")).strip_edges() != "completed":
		npc_entity_path.trigger_dialog()
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
