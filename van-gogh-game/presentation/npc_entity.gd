extends Node3D
class_name NpcEntity

@export var inventory: NpcInventory
@export var drop_point: Marker3D

func _ready():
	# Exemplo: emitir evento quando o jogador se aproxima para interagir
	# (Opcional)
	pass

func trigger_dialog():
	EventBus.npc_dialog_triggered.emit(name)
