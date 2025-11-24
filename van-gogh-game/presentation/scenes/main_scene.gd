extends Node3D
class_name MainScene

@export var main_controller: MainController
@export var player_controller: PlayerController
@export var dialog_controller: DialogController
@export var zone_controller: ZoneController
@export var lighting_service: LightingService
@export var player_light_service: PlayerLightService
@export var player_view: PlayerView
@export var npc_entity_path: NpcEntity
var played_start: bool = false

func _ready():
	main_controller.player = player_view
	main_controller.zone_controller = zone_controller
	main_controller.dialog_service = dialog_controller
	if !played_start:
		npc_entity_path.trigger_dialog()
		played_start = true
