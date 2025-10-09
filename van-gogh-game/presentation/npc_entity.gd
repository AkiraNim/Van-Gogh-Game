extends Node3D
class_name NpcEntity

@export var inventory: NpcInventory
@export var drop_point: Marker3D
@export var nome_npc: String = "NPC_Teste"

@export var timelines: Array[String] = []  # nomes das timelines Dialogic
var _current_timeline_index: int = 0

func _ready() -> void:
	var area := $"../Interacao"
	if area and not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		print("👋 Player entrou na área de interação de", name)
		trigger_dialog()

func trigger_dialog() -> void:
	if timelines.is_empty():
		push_warning("%s não possui timelines configuradas." % name)
		return

	var timeline_to_play := timelines[_current_timeline_index]
	print("🎭 Iniciando timeline:", timeline_to_play)
	EventBus.npc_dialog_triggered.emit(name, timeline_to_play)

func avancar_timeline() -> void:
	if _current_timeline_index < timelines.size() - 1:
		_current_timeline_index += 1
	else:
		print("💬 %s já concluiu todas as timelines." % name)
