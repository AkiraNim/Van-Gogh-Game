extends Node3D
class_name Seat

@export var marker3D: Marker3D
@export var dialogCameraService: DialogCameraService
@export var dialogService: DialogicService
@export var npc_entity_path: NpcEntity
@export var player: PlayerView
@export var bus: CharacterBody3D
@export var fazendeiro: Node3D
@export var vanGogh: Node3D
@export var florista: Node3D
@export var bordeaux: Node3D

@onready var area: Area3D = $Area3D
var occupied_by: Node3D = null
var player_in_range: Node3D = null


func _ready() -> void:
	add_to_group("seats")
	add_to_group("interactables")
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if str(Dialogic.VAR.get_variable("bus_passed")).strip_edges() == "can_go" and !bus.move_blocked:
		bus.can_move = true
	
	if str(Dialogic.VAR.get_variable("bus_passed")).strip_edges() == "await"  and bus.move_blocked:
		bus.move_blocked = false
	
	if Dialogic.VAR.get_variable("bus_visible"):
		bus.show()
	
	if !Dialogic.VAR.get_variable("bus_visible"):
		bus.hide()
	
	if Dialogic.VAR.get_variable("final_dialog"):
		await get_tree().create_timer(0.10).timeout
		$"../EnviromentNode/LightingService/Sky".hide()
		$"../Camera3D_Final".current = true
		$"../Camera3D_Final".rotacionar()
		
	if Dialogic.VAR.get_variable("move_characters") and !bus.can_move:
			Dialogic.VAR.set_variable("move_characters", false)
			await get_tree().create_timer(0.10).timeout
			$"../EnviromentNode/LightingService/Sky".hide()
			player.hide()
			vanGogh.global_position = Vector3(-0.997, 0.341, 0.885)
			fazendeiro.global_position = Vector3(-0.03, 0.341, 0.42)
			bordeaux.global_position = Vector3(0.635, 0.341, 0.74)
			florista.global_position = Vector3(-0.674, 0.341, 0.54)
			await get_tree().create_timer(0.8).timeout
			$"../EnviromentNode/LightingService/Sky".show()
			return
			
	if str(Dialogic.VAR.get_variable("bus_status")).strip_edges() == "can_pass":
		npc_entity_path.trigger_dialog()
		bus.show()
		
	if occupied_by != null and Dialogic.VAR.get_variable("final_status"):
		player.collision_layer = 2
		npc_entity_path.trigger_dialog()
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
