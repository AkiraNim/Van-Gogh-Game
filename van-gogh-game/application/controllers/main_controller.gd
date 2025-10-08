extends Node
class_name MainController

@export var dialog_service: DialogController
@export var player: PlayerView
@export var zone_controller: ZoneController

var dialogo_ativo: bool = false

func _ready() -> void:
	# --- Conexões de eventos globais via EventBus ---
	EventBus.player_entered_zone.connect(_on_player_entrou_na_zona)
	EventBus.item_collected.connect(_on_item_coletado)
	EventBus.star_count_changed.connect(_on_star_count_changed)
	EventBus.animation_collect_finished.connect(_on_animacao_coleta_finalizada)
	EventBus.dialog_started.connect(_on_dialogo_iniciou)
	EventBus.dialog_ended.connect(_on_dialogo_terminou)

	print("✅ MainController inicializado e ouvindo eventos globais.")

# ======================================================
# 🎭 DIÁLOGO
# ======================================================

func _on_dialogo_iniciou() -> void:
	dialogo_ativo = true
	if player:
		player.pode_mover = false

func _on_dialogo_terminou() -> void:
	dialogo_ativo = false
	if player:
		player.pode_mover = true

	# Exemplo: NPC solta item ao final do diálogo
	var npc := get_tree().get_current_scene().get_node_or_null("NPCTesteNode")
	if npc and npc.has_method("dropar_item"):
		npc.dropar_item("estrela")

# ======================================================
# 🗺️ ZONA / AMBIENTE
# ======================================================

func _on_player_entrou_na_zona(nome_zona: String) -> void:
	print("🏞️ Jogador entrou na zona:", nome_zona)
	# O ZoneController já emite EventBus.player_entered_zone,
	# então não é necessário chamar método interno aqui.

# ======================================================
# 🌟 ITENS / COLETA
# ======================================================

func _on_item_coletado(id_item: String, item_node: Node3D) -> void:
	# Se estiver em diálogo, não coleta ainda
	if dialogo_ativo:
		if is_instance_valid(item_node):
			item_node.coletado = false
		return

	if not player or not dialog_service:
		return

	# Fase visual e lógica de coleta
	player.segurar_item(item_node)
	player.acender_spotlight()

	# Inicia animação de coleta + diálogo visual
	await dialog_service.iniciar_animacao_de_coleta(player, "Player_item")

func _on_animacao_coleta_finalizada() -> void:
	if not player:
		return
	player.apagar_spotlight()
	player.destruir_item_segurado()
	player.adicionar_estrela()

# ======================================================
# ⭐ CONTAGEM DE ESTRELAS
# ======================================================

func _on_star_count_changed(nova_contagem: int) -> void:
	print("⭐ Estrelas coletadas:", nova_contagem)
