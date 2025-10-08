extends Node
class_name NpcController

@export var npc_entity: NodePath
@export var npc_service: NpcService

var _npc: NpcEntity

func _ready():
	_npc = get_node_or_null(npc_entity)
	EventBus.npc_dialog_triggered.connect(_on_dialog_triggered)

func _on_dialog_triggered(npc_name: String) -> void:
	if not _npc or npc_name != _npc.name:
		return
	# pode iniciar fala, acionar animação, etc.
	pass

func dropar_item(id_item: String) -> void:
	if not _npc or not npc_service:
		return
	var item_data := _npc.inventory.remove_item(id_item)
	if not item_data:
		push_warning("NpcController: NPC '%s' não possui item '%s'." % [_npc.name, id_item])
		return
	npc_service.dropar_item(item_data, _npc.drop_point)
