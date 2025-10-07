extends Node3D
class_name MainScene

@export var main_controller: MainController
@export var dialog_controller: DialogController
@export var zone_controller: ZoneController
@export var player: PlayerView

func _ready() -> void:
	main_controller.dialog_service = dialog_controller
	main_controller.player = player
	main_controller.zone_controller = zone_controller
