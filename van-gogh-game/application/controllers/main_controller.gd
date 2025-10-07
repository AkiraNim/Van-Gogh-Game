extends Node
class_name MainController

@export var dialog_service: DialogController
@export var player: PlayerView
@export var zone_controller: ZoneController

var dialogo_ativo: bool = false

func _ready() -> void:
	# Conexões de eventos globais
	EventBus.player_entered_zone.connect(_on_player_entrou_na_zona)
	EventBus.item_collected.connect(_on_item_coletado)
	EventBus.star_count_changed.connect(_on_star_count_changed)

	# Sinais de serviços
	dialog_service.dialogic_service.dialogo_iniciou.connect(_on_dialogo_iniciou)
	dialog_service.dialogic_service.dialogo_terminou.connect(_on_dialogo_terminou)

func _on_dialogo_iniciou() -> void:
	dialogo_ativo = true
	if player:
		player.pode_mover = false

func _on_dialogo_terminou() -> void:
	dialogo_ativo = false
	if player:
		player.pode_mover = true
	# Exemplo: NPC solta item quando diálogo termina
	var npc := get_tree().get_current_scene().get_node_or_null("NPCTesteNode")
	if npc and npc.has_method("dropar_item"):
		npc.dropar_item("estrela")

func _on_player_entrou_na_zona(nome_zona: String) -> void:
	if zone_controller:
		zone_controller._on_player_entered_zone(nome_zona)

func _on_item_coletado(id_item: String, item_node: Node3D) -> void:
	if dialogo_ativo:
		if is_instance_valid(item_node):
			item_node.coletado = false
		return

	# Fase de coleta visual e lógica
	player.segurar_item(item_node)
	player.acender_spotlight()
	await dialog_service.iniciar_animacao_coleta(player, "Player_item")

func _on_star_count_changed(nova_contagem: int) -> void:
	# Aqui poderia atualizar UI ou salvar progresso
	print("Estrelas coletadas: ", nova_contagem)

func _on_animacao_coleta_finalizada() -> void:
	player.apagar_spotlight()
	player.destruir_item_segurado()
	player.adicionar_estrela()
