extends Node
class_name MainController

@export var dialog_service: DialogController
@export var player: PlayerView
@export var zone_controller: ZoneController



var _fade_tween: Tween

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
	EventBus.star_count_changed.connect(_on_star_count_changed)


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
	if nome_zona == "ZonaAzul":
		# retoma TUDO no Control antes de aparecer
		resume_control_tree(%SnowView2D)
		_fade(%SnowView2D, true, 0.4)
	else:
		# faz fade out e, ao terminar, pausa
		_fade(%SnowView2D, false, 0.4)
		# conecta um callback só para esta execução do tween:
		_fade_tween.finished.connect(func ():
			if is_instance_valid(%SnowView2D) and %SnowView2D.modulate.a <= 0.001:
				pause_control_tree(%SnowView2D)
		, CONNECT_ONE_SHOT)

	print("🏞️ Jogador entrou na zona:", nome_zona)


func _fade(node: CanvasItem, to_visible: bool, duration: float = 0.4) -> void:
	# Cancela tween anterior (se houver)
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()

	# Se vamos aparecer, garante que esteja visível antes de animar
	if to_visible:
		node.visible = true

	var target_a := 1.0 if to_visible else 0.0

	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_property(node, "modulate:a", target_a, duration)

	# Quando for fade-out, desliga a visibilidade ao terminar
	if not to_visible:
		_fade_tween.finished.connect(func():
			# Só esconde se realmente chegou em 0 (evita piscar no meio de outro fade)
			if is_instance_valid(node) and node.modulate.a <= 0.001:
				node.visible = false
		)

func _set_paused_recursive(n: Node, paused: bool) -> void:
	# Em Godot 4, isso desliga TODOS os callbacks (_process, _physics, inputs…) do nó
	n.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT

	# (Opcional) bloquear/reativar input visual de Controls
	if n is Control:
		var c := n as Control
		if paused:
			if not c.has_meta("_prev_mouse_filter"):
				c.set_meta("_prev_mouse_filter", c.mouse_filter)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			if c.has_meta("_prev_mouse_filter"):
				c.mouse_filter = int(c.get_meta("_prev_mouse_filter"))
				c.remove_meta("_prev_mouse_filter")

	# (Opcional) pausar efeitos comuns
	if n is AnimationPlayer:
		var ap := n as AnimationPlayer
		ap.speed_scale = 0.0 if paused else 1.0

	if n is Timer:
		var t := n as Timer
		if paused: t.stop()  # (retomar depois cabe ao seu fluxo)

	if n is GPUParticles2D or n is CPUParticles2D:
		n.emitting = not paused

	for child in n.get_children():
		_set_paused_recursive(child, paused)

func pause_control_tree(root: Control) -> void:
	_set_paused_recursive(root, true)

func resume_control_tree(root: Control) -> void:
	_set_paused_recursive(root, false)

# ======================================================
# ⭐ CONTAGEM DE ESTRELAS
# ======================================================
func _on_star_count_changed(nova_contagem: int) -> void:
	print("⭐ Estrelas coletadas:", nova_contagem)
