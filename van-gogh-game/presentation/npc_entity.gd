# res://presentation/npc_entity.gd
extends Node3D
class_name NpcEntity

@export var inventory: NpcInventory
@export var drop_point: Marker3D
@export var nome_npc: String = "NPC_Teste"
@export var timelines: Array[String] = []  # nomes das timelines Dialogic

var _current_timeline_index: int = 0
var _player_inside := false
var _last_player: PlayerView = null

# Serviço de NPC (conforme cena do PR: MainScene/Npc/NpcService)
@onready var _npc_service: NpcService = (
	get_tree().current_scene.get_node_or_null("Npc/NpcService") as NpcService
)

func _ready() -> void:
	var area := $"../Interacao"
	if area and not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)
	if area and not area.body_exited.is_connected(_on_body_exited):
		area.body_exited.connect(_on_body_exited)

func _input(event: InputEvent) -> void:
	if not _player_inside: return
	if event.is_action_pressed("interact"):  # InputMap: "interact"
		trigger_dialog()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_last_player = body as PlayerView
		print("👋 Player entrou na área de interação de", name)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_last_player = null

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

# =============================
#  🔽 DROP / 🎁 GIVE (API)
# =============================
func drop_item(id_item: String) -> void:
	if not inventory:
		push_warning("%s sem inventário." % name)
		return
	var data := inventory.remove_item(id_item)
	if data == null:
		push_warning("%s tentou dropar '%s' mas não possui." % [name, id_item])
		return

	if _npc_service:
		_npc_service.dropar_item(nome_npc, data, drop_point)
	else:
		# Fallback: instancia direto sem serviço
		var inst := data.instantiate_node()
		if inst:
			get_tree().current_scene.add_child(inst)
			inst.global_position = drop_point.global_position
			EventBus.npc_dropped_item.emit(nome_npc, data.id_item)  # mantém contrato do EventBus

	# Atualiza inventário globalmente
	EventBus.inventory_item_removed.emit(id_item)
	EventBus.emit_inventory_updated()

func give_item_to_player(id_item: String, player: PlayerView) -> void:
	if player == null:
		player = _last_player  # último player que entrou
	if not player or not inventory:
		push_warning("%s não conseguiu entregar: player/inventário ausente." % name)
		return

	var data := inventory.remove_item(id_item)
	if data == null:
		push_warning("%s tentou entregar '%s' mas não possui." % [name, id_item])
		return

	# Cria um nó visual do item e marca metadado com ItemData, para pipeline de coleta.
	var node := data.instantiate_node()
	if node:
		node.set_meta("item_data", data)  # para o PlayerController reconhecer tipo/estrela
		# Reutilizamos o MESMO pipeline de coleta do player:
		EventBus.emit_item_collected(data.id_item, node)
		EventBus.inventory_item_removed.emit(id_item)
		EventBus.emit_inventory_updated()
	else:
		push_warning("%s não conseguiu instanciar cena do item '%s'." % [name, id_item])
