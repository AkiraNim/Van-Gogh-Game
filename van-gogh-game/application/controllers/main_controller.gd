extends Node
class_name MainController

@export var dialog_service: DialogController
@export var player: PlayerView
@export var zone_controller: ZoneController

var dialogo_ativo: bool = false

func _ready() -> void:
	print("✅ MainController inicializado e ouvindo eventos globais.")

	# Encontra o player ativo na árvore em tempo de execução
	if not player:
		for node in get_tree().get_nodes_in_group("player"):
			if node is PlayerView:
				player = node
				break
	if not player:
		player = get_tree().get_current_scene().get_node_or_null("Player_3D")

	if player:
		print("🎯 PlayerView encontrado com sucesso:", player.name, "Path:", player.get_path())
	else:
		push_error("❌ PlayerView não encontrado na cena.")

	if not EventBus.dialog_started.is_connected(_on_dialogo_iniciou):
		EventBus.dialog_started.connect(_on_dialogo_iniciou)
	if not EventBus.dialog_ended.is_connected(_on_dialogo_terminou):
		EventBus.dialog_ended.connect(_on_dialogo_terminou)

	EventBus.player_entered_zone.connect(_on_player_entrou_na_zona)
	EventBus.item_collected.connect(_on_item_coletado)
	EventBus.star_count_changed.connect(_on_star_count_changed)
	EventBus.animation_collect_finished.connect(_on_animacao_coleta_finalizada)


# ======================================================
# 🎭 DIÁLOGO
# ======================================================
func _on_dialogo_iniciou() -> void:
	dialogo_ativo = true
	print("🛑 Evento de diálogo recebido no MainController")
	if player:
		player.pode_mover = false
		player.velocity = Vector3.ZERO
		print("🚫 Movimento do Player bloqueado")
	else:
		push_warning("⚠️ MainController: Player não definido para bloquear movimento")

func _on_dialogo_terminou() -> void:
	dialogo_ativo = false
	print("✅ Evento de diálogo finalizado no MainController")
	if player:
		player.pode_mover = true
		print("🏃 Player liberado para mover")
	else:
		push_warning("⚠️ MainController: Player não definido para liberar movimento")
	EventBus.interaction_ended.emit()


# ======================================================
# 🌍 ZONA
# ======================================================
func _on_player_entrou_na_zona(nome_zona: String) -> void:
	print("🏞️ Jogador entrou na zona:", nome_zona)

# ======================================================
# 🌟 ITENS / COLETA
# ======================================================
func _on_item_coletado(id_item: String, item_node: Node3D) -> void:
	if dialogo_ativo:
		if is_instance_valid(item_node):
			print("⚠️ Ignorando coleta: diálogo ativo")
		return
	if not player or not dialog_service:
		return
	player.segurar_item(item_node)
	player.acender_spotlight()
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
