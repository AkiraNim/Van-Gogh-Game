extends Node
class_name PlayerController

@export var player_view: PlayerView
@export var light_service: PlayerLightService
@export var state: PlayerState

# --- controle de retenção do item especial ---
var _held_node: Node3D = null                       # item atualmente preso acima do player
var _awaiting_important_start: bool = false         # aguardando iniciar o 'important_item'
var _important_active: bool = false                 # 'important_item' está rodando

func _ready() -> void:
	# Sinais necessários
	if not EventBus.item_collected.is_connected(_on_item_collected):
		EventBus.item_collected.connect(_on_item_collected)
	if not EventBus.dialog_started.is_connected(_on_dialog_started):
		EventBus.dialog_started.connect(_on_dialog_started)
	if not EventBus.dialog_ended.is_connected(_on_dialog_ended):
		EventBus.dialog_ended.connect(_on_dialog_ended)

	# Fallback para encontrar o PlayerView pelo grupo
	if player_view == null:
		var lst: Array = get_tree().get_nodes_in_group("player")
		if lst.size() > 0 and lst[0] is PlayerView:
			player_view = lst[0]

# ======================================================
# DIÁLOGO (apenas para saber quando destruir o item especial)
# ======================================================
func _on_dialog_started() -> void:
	# Se estávamos esperando abrir o 'important_item', este 'started' é dele
	if _awaiting_important_start:
		_important_active = true
		_awaiting_important_start = false

func _on_dialog_ended() -> void:
	# aqui você sabe que o important_item terminou
	if _held_node != null and is_instance_valid(_held_node):
		_held_node.call_deferred("queue_free")
		_held_node = null

	# se quiser apagar o spotlight só no fim do diálogo, pode ficar aqui:
	if light_service:
		light_service.desligar()

# ======================================================
# COLETA (mantém sua lógica, mas com reparent seguro e retenção em diálogos)
# ======================================================
func _on_item_collected(_id_item: String, item_node: Node3D) -> void:
	# resolve player_view se não estiver setado
	if player_view == null:
		var lst: Array = get_tree().get_nodes_in_group("player")
		if lst.size() > 0 and lst[0] is PlayerView:
			player_view = lst[0]
	if player_view == null:
		push_warning("PlayerController: player_view não definido; ignorando coleta.")
		return
	if player_view.ponto_item_acima == null:
		push_warning("PlayerController: ponto_item_acima não configurado no PlayerView.")
		return
	if item_node == null:
		return

	# Desabilita a Area3D para não recom disparar (anti reentrada)
	if item_node is Area3D:
		var a: Area3D = item_node
		a.call_deferred("set_process_input", false)
		a.set_deferred("monitoring", false)
		a.set_deferred("monitorable", false)

	# visual: item "na cabeça" (reparent SEGURO, fora do callback de física)
	_attach_to_player_deferred(item_node)

	# spotlight rápido
	if light_service:
		light_service.ligar()

	# dados do item
	var data: ItemData = _extract_item_data(item_node)
	var is_special: bool = false
	if data != null:
		is_special = data.tipo == "estrela" or data.tipo == "importante" or (("grants_star" in data) and data.grants_star)

	# pequena pausa/anim
	await get_tree().create_timer(0.25 if is_special else 0.1).timeout

	# luz off
	

	# estado (estrela)
	if data and (data.grants_star or data.tipo == "importante" or data.tipo == "estrela"):
		if state:
			state.adicionar_estrela()

	# item especial → mantém acima da cabeça e inicia diálogo de recebido
	if is_special and data:
		# marcar que esperamos o 'dialog_started' do important_item
		_awaiting_important_start = true
		# dispara o diálogo; DialogController deve setar a var e iniciar 'important_item'
		EventBus.emit_important_item_collected(data.nome)
	else:
		# item comum → pode destruir já
		_destroy_held_item_deferred()

# ======================================================
# HELPERS
# ======================================================
func _attach_to_player_deferred(node: Node3D) -> void:
	_held_node = node
	var parent: Node = node.get_parent()
	if parent != null:
		parent.call_deferred("remove_child", node)
	player_view.ponto_item_acima.call_deferred("add_child", node)
	call_deferred("_after_attach_zero", node)

func _after_attach_zero(node: Node3D) -> void:
	if node != null:
		node.transform = Transform3D.IDENTITY
	if player_view != null:
		player_view.set_held_item(node)

func _destroy_held_item_deferred() -> void:
	if _held_node != null and is_instance_valid(_held_node):
		_held_node.call_deferred("queue_free")
	_held_node = null

func _extract_item_data(node: Node) -> ItemData:
	if node == null:
		return null
	# 1) Se for CollectableArea com export 'item_data'
	if node is CollectableArea:
		var ca: CollectableArea = node
		if ca.item_data != null:
			return ca.item_data
	# 2) Via metadado
	if node.has_meta("item_data"):
		var v: Variant = node.get_meta("item_data")
		if v is ItemData:
			return v
	# 3) Busca recursiva
	var children: Array = node.get_children()
	for child in children:
		var sub: ItemData = _extract_item_data(child)
		if sub != null:
			return sub
	return null
