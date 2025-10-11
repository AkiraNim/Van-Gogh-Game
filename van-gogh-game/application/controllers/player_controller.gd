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
var _current_seat: Seat = null
var _is_sitting: bool = false

const APPROACH_SPEED := 1.0

func _ready() -> void:
	_sync_dialogic_all_items()
	# Evita múltiplas instâncias do PlayerController
	if Engine.is_editor_hint():
		return

	if get_tree().get_nodes_in_group("player_controller").size() > 0:
		print("⚠️ PlayerController duplicado detectado — removendo instância:", name)
		queue_free()
		return

	add_to_group("player_controller")
	print("🎮 PlayerController inicializado como instância única.")
	
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
	var bridge = get_tree().get_first_node_in_group("dialog_bridge")
	if bridge:
		if not bridge.dialogic_lock_animation.is_connected(_on_dialogic_lock_animation):
			bridge.dialogic_lock_animation.connect(_on_dialogic_lock_animation)
		if not bridge.dialogic_unlock_animation.is_connected(_on_dialogic_unlock_animation):
			bridge.dialogic_unlock_animation.connect(_on_dialogic_unlock_animation)
	call_deferred("_bind_dialog_bridge")
	_resolve_player_view()
	_print_inventory_grouped("início do jogo")

# ===================== DIÁLOGO =====================
func _resolve_player_view() -> bool:
	if player_view and is_instance_valid(player_view):
		return true
	# pega exatamente a instância registrada no grupo 'player'
	var lst := get_tree().get_nodes_in_group("player")
	if lst.size() > 0 and lst[0] is PlayerView:
		player_view = lst[0]
		print("✅ PlayerView resolvido em _resolve_player_view():", player_view.name)
		# sanity: se houver duplicatas, elimina as extras
		for n in lst:
			if n != player_view:
				print("⚠️ PlayerView duplicado detectado (removendo):", n.name)
				n.queue_free()
		return true
	print("❌ _resolve_player_view() não encontrou PlayerView")
	return false

func _bind_dialog_bridge() -> void:
	var bridge := get_tree().get_first_node_in_group("dialog_bridge")
	if bridge:
		if not bridge.dialogic_lock_animation.is_connected(_on_dialogic_lock_animation):
			bridge.dialogic_lock_animation.connect(_on_dialogic_lock_animation)
		if not bridge.dialogic_unlock_animation.is_connected(_on_dialogic_unlock_animation):
			bridge.dialogic_unlock_animation.connect(_on_dialogic_unlock_animation)
		print("🔗 PlayerController conectado ao DialogicBridge")
	else:
		print("⏳ Bridge ainda não disponível; tentando novamente…")
		await get_tree().process_frame
		_bind_dialog_bridge()
	
func _on_dialogic_lock_animation(name: String, duration: float) -> void:
	print("🎛️ Controller recebeu lock -> name='", name, "' dur=", duration)
	if not _resolve_player_view():
		return

	# 1) congele a view para impedir qualquer lógica de mover/anim no frame
	_freeze_player_view()

	# 2) aplique o lock via método da view (se existir)
	if player_view.has_method("lock_animation"):
		player_view.lock_animation(name, duration)
	else:
		print("⚠️ PlayerView sem lock_animation(); aplicando failsafe")

		# FAILSAFE: seta variáveis e troca anima aqui também
		if "anim_lock_name" in player_view:
			player_view.anim_lock_name = name
		if "anim_lock_time" in player_view:
			player_view.anim_lock_time = duration

		if player_view.anim_sprite:
			var frames := player_view.anim_sprite.sprite_frames
			var final_name := name
			if frames and not frames.has_animation(final_name):
				if frames.has_animation("idle_down"):
					final_name = "idle_down"
				elif frames.has_animation("idle"):
					final_name = "idle"
				else:
					print("⚠️ Controller: animação não encontrada nem fallback (", name, ")")
					return
			var before := player_view.anim_sprite.animation
			player_view.anim_sprite.stop()
			player_view.anim_sprite.play(final_name)
			print("🎞️ Controller forçou anim →", final_name, "(antes era", before, ")")

	# 3) garanta que entradas não reativem nada durante o lock
	if "pode_mover" in player_view:
		player_view.pode_mover = false

func _on_dialogic_unlock_animation() -> void:
	print("🎛️ Controller recebeu unlock")
	if not _resolve_player_view():
		return

	# solta o lock na view (se existir o método)
	if player_view.has_method("unlock_animation"):
		player_view.unlock_animation()

	# reabilita física/processo e input somente se não estiver sentado
	if not _is_sitting:
		await get_tree().process_frame  # dá 1 frame para a idle/estado colar
		_unfreeze_player_view()
		if "pode_mover" in player_view:
			player_view.pode_mover = true

		
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
		
	if Engine.has_singleton("Dialogic"):
		var D := Engine.get_singleton("Dialogic")
		var c := _inventory_count("estrela_vermelha")  # helper abaixo
		if D and D.has_subsystem("VAR"):
			D.VAR.set_variable("count_estrela_vermelha", c)
		elif "Variables" in Dialogic:
			Dialogic.Variables.set_variable("count_estrela_vermelha", c)
		print("🧮 Dialogic VAR sync → count_estrela_vermelha =", c)
	if data != null:
		_set_dialogic_item_vars(data.id_item, inventory.count_id(data.id_item) if inventory.has_method("count_id") else _count_in_inventory(data.id_item))
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

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _is_sitting:
			print("⬆️ Player levantando...")
			_stand_up()
			return

		var seat := _find_nearby_seat()
		print("🔍 Seat encontrado:", seat)
		if seat:
			print("🪑 Player vai sentar em:", seat.name)
			await _sit_on(seat)

# --- N-LAYER SIT FUNCTION ---
func _sit_on(seat: Seat) -> void:
	# resolve player_view se necessário
	if player_view == null:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_view = players[0]
			print("✅ PlayerView resolvido dinamicamente em _sit_on():", player_view.name)
		else:
			push_error("❌ Nenhum PlayerView encontrado no grupo 'player'!")
			return

	if not seat.try_reserve(player_view):
		return

	_freeze_player_view()
	await get_tree().process_frame # garante que o movimento parou

	var xf := seat.get_sit_transform()
	var target := xf.origin
	var start  := player_view.global_position
	var dist   := start.distance_to(target)

	# --- CÁLCULO DO TEMPO DE VIAGEM ---
	var travel_time = max(0.1, dist / APPROACH_SPEED)

	# --- AJUSTE DA VELOCIDADE DA ANIMAÇÃO PARA CASAR COM O TEMPO DE VIAGEM ---
	var anim_name := "sitting_down"
	if player_view.anim_sprite and player_view.anim_sprite.sprite_frames.has_animation(anim_name):
		var frames := player_view.anim_sprite.sprite_frames.get_frame_count(anim_name)
		var base_fps := player_view.anim_sprite.sprite_frames.get_animation_speed(anim_name)
		if base_fps <= 0.0:
			base_fps = 10.0
		var base_duration := float(frames) / base_fps
		# speed_scale = (duração_base / tempo_desejado)
		var scale = base_duration / travel_time
		player_view.anim_sprite.speed_scale = scale
		player_view.anim_sprite.play(anim_name)
		print("🎬 'sitting_down' tocando durante a aproximação (scale=", scale, ", t=", travel_time, "s)")
	else:
		print("⚠️ AnimatedSprite3D não tem 'sitting_down'; movendo sem anim.")

	# --- ORIENTAÇÃO PARA A FRENTE DO ASSENTO (opcional) ---
	if "look_at" in player_view:
		player_view.look_at(xf.origin + xf.basis.z)

	# --- MOVIMENTO ATÉ O MARKER ENQUANTO A ANIMAÇÃO RODA ---
	var tween := get_tree().create_tween()
	tween.tween_property(player_view, "global_position", target, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished

	# Garante posição final (caso qualquer coisa tente empurrar 1px)
	player_view.global_position = target

	_is_sitting = true
	_current_seat = seat
	# mantenha congelado até levantar; assim a pose final da animação fica

func _stand_up() -> void:
	if _current_seat:
		_current_seat.release(player_view)
		_current_seat = null

	# zera movimento para não puxar walk
	if "velocity" in player_view:
		player_view.velocity = Vector3.ZERO

	# garante que o idle padrão seja down
	if player_view.has_method("set_default_idle"):
		player_view.set_default_idle("idle_down")
	else:
		# fallback se ainda não atualizou o PlayerView
		if player_view.anim_sprite:
			player_view.anim_sprite.stop()
			player_view.anim_sprite.play("idle_down")

	# alinha a direção para 'down' (coerente com idle_down)
	if "last_direction" in player_view:
		player_view.last_direction = Vector3.BACK  # (0,0,1) = down no teu mapeamento

	# trava a animação por um instante pra “colar” a pose
	if player_view.has_method("lock_animation"):
		player_view.lock_animation("idle_down", 0.25)
	else:
		if player_view.anim_sprite:
			player_view.anim_sprite.play("idle_down")

	# normaliza a velocidade da animação
	if player_view.anim_sprite:
		player_view.anim_sprite.speed_scale = 1.0

	# dá 1 frame e descongela; com lock, o _update_animation não sobrescreve
	await get_tree().process_frame
	_unfreeze_player_view()
	_is_sitting = false


func _find_nearby_seat() -> Seat:
	for seat in get_tree().get_nodes_in_group("seats"):
		if seat.can_sit():
			return seat
	return null
	
func _freeze_player_view() -> void:
	if player_view == null: return
	# Para qualquer física e lógica de movimento
	if player_view.has_method("set_physics_process"):
		player_view.set_physics_process(false)
	if player_view.has_method("set_process"):
		player_view.set_process(false)
	# Zera velocidade caso use CharacterBody3D
	if "velocity" in player_view:
		player_view.velocity = Vector3.ZERO
	# Bloqueia controles/estado do seu lado
	if "pode_mover" in player_view:
		player_view.pode_mover = false

func _unfreeze_player_view() -> void:
	if player_view == null: return
	if player_view.has_method("set_physics_process"):
		player_view.set_physics_process(true)
	if player_view.has_method("set_process"):
		player_view.set_process(true)
	# Reabilita controles
	if "pode_mover" in player_view:
		player_view.pode_mover = true

func _sync_dialogic_all_items() -> void:
	if inventory == null: return
	var counts := {}
	for it in inventory.itens:
		if it == null: continue
		var id := it.id_item
		counts[id] = (counts.get(id, 0) as int) + 1

	# Zera/atualiza tudo que importa pra você
	for id in counts.keys():
		_set_dialogic_item_vars(id, counts[id])

	# Se quiser garantir que itens não presentes fiquem como false/0,
	# liste-os aqui manualmente:
	# _set_dialogic_item_vars("estrela_vermelha", counts.get("estrela_vermelha", 0))

func _set_dialogic_item_vars(id_item: String, qtd: int) -> void:
	# Cria duas variáveis por item:
	# has_<id> (bool) e count_<id> (int)
	if Engine.has_singleton("Dialogic"):
		var D := Engine.get_singleton("Dialogic")
		if D and "Variables" in D:
			D.Variables.set_variable("has_%s" % id_item, qtd > 0)
			D.Variables.set_variable("count_%s" % id_item, qtd)
			# debug opcional:
			print("🔗 Dialogic vars → has_%s=%s | count_%s=%d" % [id_item, str(qtd > 0), id_item, qtd])

func _count_in_inventory(id_item: String) -> int:
	if inventory == null: return 0
	var n := 0
	for it in inventory.itens:
		if it and it.id_item == id_item:
			n += 1
	return n
	
func _inventory_count(id_item: String) -> int:
	var n := 0
	if inventory:
		for it in inventory.itens:
			if it and String(it.id_item) == id_item:
				n += 1
	return n
