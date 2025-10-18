extends Node
class_name NpcController

@export var npc_entity_path: NodePath
var _npc_entity: NpcEntity

func _ready() -> void:
	# A guarda singleton permanece para garantir a robustez
	var group_name = "npc_controller_" + get_parent().name
	add_to_group(group_name)
	if get_tree().get_nodes_in_group(group_name).size() > 1:
		print("⚠️ NpcController duplicado detectado para '", get_parent().name, "'. Removendo instância:", name)
		queue_free()
		return
	
	print("✅ NpcController pronto para NPC:", get_parent().name)
	
	_npc_entity = get_node_or_null(npc_entity_path)
	if not _npc_entity:
		push_warning("NpcController: entidade não encontrada para ", get_parent().name)
		return
	# A conexão com o EventBus e toda a lógica de iniciar diálogo foi REMOVIDA.

# As funções _on_dialog_triggered, _start_timeline_after_layout_ready e _get_dialogic
# foram removidas por não serem mais necessárias neste script.

func drop_item(item_id: String) -> void:
	if _npc_entity:
		_npc_entity.drop_item(item_id)

func give_item_to_player(item_id: String) -> void:
	if not _npc_entity:
		return
	# Usamos o PlayerRegistry para obter o player de forma segura
	var player = PlayerRegistry.player
	if player and player is PlayerView:
		_npc_entity.give_item_to_player(item_id, player)
