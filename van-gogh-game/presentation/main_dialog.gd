extends Node3D
@export var bus: CharacterBody3D
@export var fazendeiro: Node3D
@export var vanGogh: Node3D
@export var florista: Node3D
@export var bordeaux: Node3D
@export var player: PlayerView
@export var npc_entity_path: NpcEntity

func _process(delta: float) -> void:
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
