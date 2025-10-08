extends Node
class_name PlayerController

@export var player_view: PlayerView
@export var light_service: PlayerLightService
@export var state: PlayerState

func _ready() -> void:
	EventBus.dialog_started.connect(_on_dialogo_comecou)
	EventBus.dialog_ended.connect(_on_dialogo_terminou)
	EventBus.item_collected.connect(_on_item_coletado)

func _on_dialogo_comecou() -> void:
	player_view.pode_mover = false
	player_view.velocity = Vector3.ZERO

func _on_dialogo_terminou() -> void:
	player_view.pode_mover = true

func _on_item_coletado(id_item: String, area_node: Node3D) -> void:
	if not player_view.ponto_item_acima:
		return
	player_view.segurar_item(area_node)
	light_service.ligar()
	await EventBus.animation_collect_finished
	light_service.desligar()
	area_node.queue_free()
	state.adicionar_estrela()

# Método utilitário
func segurar_item(node: Node3D) -> void:
	if not player_view or not player_view.ponto_item_acima:
		return
	node.get_parent().remove_child(node)
	player_view.ponto_item_acima.add_child(node)
	node.position = Vector3.ZERO
