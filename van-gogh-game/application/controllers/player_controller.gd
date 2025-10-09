extends Node
class_name PlayerController

@export var player_view: PlayerView
@export var light_service: PlayerLightService
@export var state: PlayerState

func _ready() -> void:
	EventBus.item_collected.connect(_on_item_coletado)

func _on_item_coletado(id_item: String, area_node: Node3D) -> void:
	if not player_view:
		player_view = get_node_or_null(^"../../Player_3D")
		if not player_view:
			push_warning("⚠️ PlayerController: player_view ausente.")
			return

	if not player_view.ponto_item_acima:
		push_warning("⚠️ PlayerController: ponto_item_acima não configurado.")
		return

	player_view.segurar_item(area_node)
	light_service.ligar()
	await EventBus.animation_collect_finished
	light_service.desligar()
	area_node.queue_free()
	state.adicionar_estrela()
