# res://application/controllers/player_controller.gd
extends Node
class_name PlayerController

@export var player_view: PlayerView
@export var light_service: PlayerLightService
@export var state: PlayerState

var _collecting := false

func _ready() -> void:
	# Coleta
	if not EventBus.item_collected.is_connected(_on_item_coletado):
		EventBus.item_collected.connect(_on_item_coletado)
	# Movimento bloqueado por diálogo
	if not EventBus.dialog_started.is_connected(_on_dialog_started):
		EventBus.dialog_started.connect(_on_dialog_started)
	if not EventBus.dialog_ended.is_connected(_on_dialog_ended):
		EventBus.dialog_ended.connect(_on_dialog_ended)

func _on_dialog_started() -> void:
	if player_view:
		player_view.pode_mover = false
		player_view.velocity = Vector3.ZERO

func _on_dialog_ended() -> void:
	if player_view:
		player_view.pode_mover = true

func _on_item_coletado(id_item: String, item_node: Node3D) -> void:
	if _collecting or not player_view or item_node == null:
		return
	_collecting = true

	# 1) Descobre o ItemData vindo do CollectableArea (propriedade) ou metadado (NPC give)
	var data: ItemData = _extract_item_data(item_node, id_item)

	# 2) Prende o item acima do player e liga a luz
	_attach_to_player(item_node)
	if light_service:
		light_service.ligar()

	# 3) Animação de coleta quando for estrela/“importante”
	var is_special := false
	if data:
		is_special = data.grants_star or data.tipo in ["estrela", "importante"]

	if is_special:
		await _play_collect_vfx()
	else:
		await get_tree().create_timer(0.20).timeout

	# 4) Desliga a luz, destrói o item preso e contabiliza estrela (se for o caso)
	if light_service:
		light_service.desligar()

	if player_view:
		player_view.destruir_item_segurado()

	if data and (data.grants_star or data.tipo == "estrela"):
		if state:
			state.adicionar_estrela()  # emite star_count_changed internamente
		# você pode também disparar um feedback/HUD aqui

	# 5) Sinaliza para quem estiver aguardando
	EventBus.emit_animation_collect_finished()
	_collecting = false

func _extract_item_data(node: Node, fallback_id: String) -> ItemData:
	var data: ItemData = null
	# Caso seja CollectableArea (tem export 'item_data')
	if node != null and "item_data" in node:
		data = node.item_data
	# Caso tenha vindo do NPC.give (usamos metadado)
	elif node != null and node.has_meta("item_data"):
		data = node.get_meta("item_data")
	return data

func _attach_to_player(node: Node3D) -> void:
	if not player_view or not node: return
	# reparenta o nó recebido para ficar acima do player (independe de ser Area3D ou Node3D)
	if node.get_parent():
		node.get_parent().remove_child(node)
	player_view.ponto_item_acima.add_child(node)
	node.position = Vector3.ZERO
	player_view.set_held_item(node)

func _play_collect_vfx() -> void:
	# Efeito visual simples: “pulse” no item preso
	var held := player_view.get_held_item_node() if player_view else null
	if not held:
		await get_tree().create_timer(0.2).timeout
		return
	var s0 := held.scale
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(held, "scale", s0 * 1.25, 0.15)
	tween.tween_property(held, "scale", s0, 0.15)
	await tween.finished
