extends Node
class_name PlayerController

@export var player_view: PlayerView
@export var light_service: PlayerLightService
@export var state: PlayerState
@export var inventory: PlayerInventory

# --- controle de item especial "segurado" ---
var _held_node: Node3D = null
var _awaiting_important_start: bool = false
var _important_active: bool = false

func _ready() -> void:
	# Sinais
	if not EventBus.item_collected.is_connected(_on_item_collected):
		EventBus.item_collected.connect(_on_item_collected)
	if not EventBus.dialog_started.is_connected(_on_dialog_started):
		EventBus.dialog_started.connect(_on_dialog_started)
	if not EventBus.dialog_ended.is_connected(_on_dialog_ended):
		EventBus.dialog_ended.connect(_on_dialog_ended)

	# Resolve PlayerView via grupo, se preciso
	if player_view == null:
		var lst: Array = get_tree().get_nodes_in_group("player")
		if lst.size() > 0 and lst[0] is PlayerView:
			player_view = lst[0]

	_print_inventory_grouped("início do jogo")

# ===================== DIÁLOGO =====================
func _on_dialog_started() -> void:
	if _awaiting_important_start:
		_important_active = true
		_awaiting_important_start = false

func _on_dialog_ended() -> void:
	# terminou o diálogo (inclusive o important_item) → destruir item visual
	if _held_node != null and is_instance_valid(_held_node):
		_held_node.call_deferred("queue_free")
	_held_node = null
	if light_service:
		light_service.desligar()

# ===================== COLETA ======================
func _on_item_collected(_id_item: String, item_node: Node3D) -> void:
	# validações básicas
	if player_view == null:
		var lst: Array = get_tree().get_nodes_in_group("player")
		if lst.size() > 0 and lst[0] is PlayerView:
			player_view = lst[0]
	if player_view == null:
		push_warning("PlayerController: player_view não definido; ignorando coleta.")
		return
	if item_node == null:
		return

	# Evita reentrada da Area3D durante o callback de física
	if item_node is Area3D:
		var a: Area3D = item_node
		a.call_deferred("set_process_input", false)
		a.set_deferred("monitoring", false)
		a.set_deferred("monitorable", false)

	# 1) Descobre os dados do item
	var data: ItemData = _extract_item_data(item_node)

	# 2) Atualiza inventário e imprime
	if data != null and inventory != null:
		inventory.add_item(data)
		_print_inventory_grouped("após coleta")

	# 3) Classifica se é especial (estrela/importante)
	var is_special: bool = false
	if data != null:
		is_special = (data.tipo == "importante") or (data.tipo == "estrela") or (("grants_star" in data) and data.grants_star)

	# 4) Fluxo visual e estado
	if is_special:
		# Anexa acima da cabeça e liga luz
		_attach_to_player_deferred(item_node)
		if light_service:
			light_service.ligar()
	else:
		# Itens comuns: não anexa ao player
		_held_node = null  # garantir que não será destruído pelo _destroy_held_item_deferred

	# mini‐delay (maior p/ especiais)
	await get_tree().create_timer(0.25 if is_special else 0.1).timeout

	# 5) Estado de estrela
	if data and (data.grants_star or data.tipo == "estrela"):
		if state:
			state.adicionar_estrela()

	# 6) Diálogo / destruição
	if is_special and data:
		# manter acima da cabeça até o fim do diálogo
		_awaiting_important_start = true
		EventBus.emit_important_item_collected(data.nome)
	else:
		# comum → destruir imediatamente
		if is_instance_valid(item_node):
			item_node.call_deferred("queue_free")
		if light_service:
			light_service.desligar()

# ===================== HELPERS =====================
func _attach_to_player_deferred(node: Node3D) -> void:
	# Seta como "held" e reparent seguro
	_held_node = node
	var parent: Node = node.get_parent()
	if parent != null:
		parent.call_deferred("remove_child", node)
	if player_view and player_view.ponto_item_acima:
		player_view.ponto_item_acima.call_deferred("add_child", node)
	else:
		push_warning("PlayerController: ponto_item_acima não configurado; anexando abortado.")
		return
	call_deferred("_after_attach_zero", node)

func _after_attach_zero(node: Node3D) -> void:
	if node != null:
		node.transform = Transform3D.IDENTITY
	if player_view != null:
		player_view.set_held_item(node)

func _extract_item_data(node: Node) -> ItemData:
	if node == null:
		return null
	if node is CollectableArea:
		var ca: CollectableArea = node
		if ca.item_data != null:
			return ca.item_data
	if node.has_meta("item_data"):
		var v: Variant = node.get_meta("item_data")
		if v is ItemData:
			return v
	for child in node.get_children():
		var sub: ItemData = _extract_item_data(child)
		if sub != null:
			return sub
	return null

func _print_inventory_grouped(label: String) -> void:
	if inventory == null:
		print("📦 Inventário do Player (", label, "): <resource não ligado>")
		return

	var counts := {}  # { id_item: { "data": ItemData, "qtd": int } }
	for it in inventory.itens:
		if it == null: continue
		var id := it.id_item
		if not counts.has(id):
			counts[id] = {"data": it, "qtd": 0}
		counts[id].qtd += 1

	print("📦 Inventário do Player (", label, "): ", counts.size(), " tipo(s)")
	for id in counts.keys():
		var rec = counts[id]
		var nome = (rec.data.nome if rec.data else id)
		print("- ", nome, " x", rec.qtd, " (", id, ")")
