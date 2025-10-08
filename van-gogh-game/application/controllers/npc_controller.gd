extends Node
class_name NpcController

@export var npc_entity_path: NodePath

var _npc_entity: NpcEntity

func _ready() -> void:
	_npc_entity = get_node_or_null(npc_entity_path)
	if not _npc_entity:
		push_warning("NpcController: entidade não encontrada.")
		return

	if not EventBus.npc_dialog_triggered.is_connected(_on_dialog_triggered):
		EventBus.npc_dialog_triggered.connect(_on_dialog_triggered)

	print("🎭 NpcController pronto para NPC:", _npc_entity.name)

func _on_dialog_triggered(npc_name: String, timeline: String) -> void:
	if not _npc_entity or npc_name != _npc_entity.name:
		return

	print("🎬 Iniciando diálogo '%s' para NPC: %s" % [timeline, npc_name])

	var timeline_exists := false
	if "timeline_exists" in Dialogic:
		timeline_exists = Dialogic.timeline_exists(timeline)
	else:
		timeline_exists = true  # fallback para versões antigas

	if timeline_exists:
		Dialogic.start(timeline)
	else:
		push_warning("Timeline '%s' não encontrada para %s" % [timeline, npc_name])
