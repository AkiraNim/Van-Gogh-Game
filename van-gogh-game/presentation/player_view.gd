extends CharacterBody3D
class_name PlayerView

signal item_coletado(item_node)
signal contagem_estrelas_mudou(nova_contagem: int)
signal quest_accepted(qid: String, title: String)
signal quest_progress(qid: String, have: Dictionary)
signal quest_completed(qid: String, title: String, motivo: String)


@export var speed: float = 2.0
@export var anim_sprite: AnimatedSprite3D
@export var ponto_item_acima: Marker3D
@export var nome_personagem: String = "Player"
@export var default_idle: StringName = "idle_down"   # 👈 idle padrão configurável

var anim_lock_name: StringName = ""
var anim_lock_time: float = 0.0
var _item_segurado: Node3D = null
var pode_mover: bool = true
var last_direction := Vector3.FORWARD   # será alinhado ao default_idle no _ready()
var velocity_vector := Vector3.ZERO
var is_sitting: bool = false
var quests_ativas := {}       
var quests_concluidas := {}   

func _enter_tree() -> void:
	# Se já existe outro player no grupo, remove a nova instância
	for node in get_tree().get_nodes_in_group("player"):
		if node != self:
			print("⚠️ Player duplicado detectado, removendo nova instância:", name)
			queue_free()
			return

func _ready():
	add_to_group("player")
	print("🎮 PlayerView registrado no grupo 'player':", name)

	# alinhar direção inicial ao idle padrão + tocar idle padrão no 1º frame
	last_direction = _dir_from_idle(String(default_idle))
	_play_safe(default_idle)

	# Conecta-se diretamente ao EventBus, garantindo bloqueio automático
	if not EventBus.dialog_started.is_connected(_on_dialogo_iniciou):
		EventBus.dialog_started.connect(_on_dialogo_iniciou)
	if not EventBus.dialog_ended.is_connected(_on_dialogo_terminou):
		EventBus.dialog_ended.connect(_on_dialogo_terminou)
	if has_node("/root/EventBus"):
		var eb := get_node("/root/EventBus")
		if not eb.item_collected.is_connected(_pv_on_item_collected):
			eb.item_collected.connect(_pv_on_item_collected)
		if not eb.npc_dialog_triggered.is_connected(_pv_on_npc_dialog_triggered):
			eb.npc_dialog_triggered.connect(_pv_on_npc_dialog_triggered)

# --------------------------- Itens ---------------------------
func set_held_item(n: Node3D) -> void:
	_item_segurado = n

func get_held_item_node() -> Node3D:
	return _item_segurado

func destruir_item_segurado() -> void:
	if is_instance_valid(_item_segurado):
		_item_segurado.queue_free()
	_item_segurado = null

# --------------------------- Movimento ---------------------------
func _physics_process(_delta: float) -> void:
	# sentado: não move nem troca anim aqui
	if is_sitting:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# lock ativo: mantém animação travada
	if anim_lock_name != "" or anim_lock_time > 0.0:
		if anim_lock_time > 0.0:
			anim_lock_time = max(0.0, anim_lock_time - _delta)
			if anim_lock_time == 0.0:
				anim_lock_name = ""
				# ao expirar lock por tempo, volta pro idle padrão
				_play_safe(default_idle)
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# bloqueio global (diálogo, etc.)
	if not pode_mover:
		velocity = Vector3.ZERO
		move_and_slide()
		_update_animation()
		return

	var dir := Vector3(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		0.0,
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	if dir.length() > 0.01:
		dir = dir.normalized()
		velocity = dir * speed
		last_direction = dir
	else:
		velocity = Vector3.ZERO

	move_and_slide()
	_update_animation()

# --------------------------- Dialogo ---------------------------
func _on_dialogo_iniciou() -> void:
	pode_mover = false
	velocity = Vector3.ZERO
	print("🚫 PlayerView bloqueado via EventBus")

func _on_dialogo_terminou() -> void:
	pode_mover = not is_sitting
	print("🏃 PlayerView liberado via EventBus")

# --------------------------- Animações ---------------------------
func _update_animation() -> void:
	if not anim_sprite:
		return
	# não mexe na animação se estiver sentado ou com lock ativo
	if is_sitting or anim_lock_name != "":
		return
	
	var moving := velocity.length() > 0.01
	var prefix := "walking" if moving else "idle"
	var dir := velocity.normalized() if moving else last_direction
	var suffix := ""
	if dir.z < -0.5 and dir.x > 0.5: suffix = "_up_right"
	elif dir.z < -0.5 and dir.x < -0.5: suffix = "_up_left"
	elif dir.z > 0.5 and dir.x > 0.5: suffix = "_down_right"
	elif dir.z > 0.5 and dir.x < -0.5: suffix = "_down_left"
	elif dir.x > 0.5: suffix = "_right"
	elif dir.x < -0.5: suffix = "_left"
	elif dir.z < -0.5: suffix = "_up"
	elif dir.z > 0.5: suffix = "_down"
	var anim := prefix + suffix
	if anim_sprite and anim_sprite.animation != anim:
		anim_sprite.play(anim)

func lock_animation(name: StringName, duration: float = -1.0) -> void:
	anim_lock_name = name
	anim_lock_time = duration
	if anim_sprite:
		var frames := anim_sprite.sprite_frames
		var final_name := String(name)
		if frames and not frames.has_animation(final_name):
			# fallback: se não existir, tenta uma idle padrão/idle_down
			if frames.has_animation(default_idle):
				final_name = default_idle
			elif frames.has_animation("idle_down"):
				final_name = "idle_down"
			elif frames.has_animation("idle"):
				final_name = "idle"
			else:
				print("⚠️ lock_animation: animação não encontrada:", name)
				print("🔒 lock_animation (sem troca visível) por", duration, "s")
				return
		anim_sprite.stop()
		anim_sprite.play(final_name)
		print("🎞️ PlayerView.anim =", anim_sprite.animation, "(lock por", duration, "s)")
	else:
		print("⚠️ lock_animation: anim_sprite está null")
	print("🔒 lock_animation requisitado =", name, "por", duration, "s")

func unlock_animation() -> void:
	anim_lock_name = ""
	anim_lock_time = 0.0
	# ao desbloquear, retorna ao idle padrão
	_play_safe(default_idle)
	print("🔓 unlock_animation →", default_idle)

# --------------------------- Helpers ---------------------------
func set_default_idle(anim: StringName) -> void:
	default_idle = anim
	# alinhar direção ao novo idle
	last_direction = _dir_from_idle(String(default_idle))
	# se estiver livre (sem lock/sitting) já aplica
	if anim_lock_name == "" and not is_sitting:
		_play_safe(default_idle)

func face_direction(dir: Vector3) -> void:
	if dir.length() > 0.01:
		last_direction = dir.normalized()
		_update_animation()

func _play_safe(name: StringName) -> void:
	if not anim_sprite:
		return
	var frames := anim_sprite.sprite_frames
	var final_name := String(name)
	if frames and not frames.has_animation(final_name):
		if frames.has_animation(default_idle):
			final_name = default_idle
		elif frames.has_animation("idle_down"):
			final_name = "idle_down"
		elif frames.has_animation("idle"):
			final_name = "idle"
		else:
			print("⚠️ _play_safe: animação não encontrada:", name)
			return
	anim_sprite.stop()
	anim_sprite.play(final_name)

# Mapeia idle_* para direção coerente (garante idle correto no 1º frame)
func _dir_from_idle(idle: String) -> Vector3:
	match idle:
		"idle_down":       return Vector3.BACK      # (0,0, 1)
		"idle_up":         return Vector3.FORWARD   # (0,0,-1)
		"idle_left":       return Vector3.LEFT      # (-1,0,0)
		"idle_right":      return Vector3.RIGHT     # ( 1,0,0)
		"idle_up_left":    return (Vector3.FORWARD + Vector3.LEFT).normalized()
		"idle_up_right":   return (Vector3.FORWARD + Vector3.RIGHT).normalized()
		"idle_down_left":  return (Vector3.BACK + Vector3.LEFT).normalized()
		"idle_down_right": return (Vector3.BACK + Vector3.RIGHT).normalized()
		_:                 return Vector3.BACK      # fallback: down

# =========================
#        QUESTS
# =========================

func accept_quest(qid: String, cfg: Dictionary) -> void:
	# Evita aceitar novamente ou aceitar algo já concluído
	if quests_concluidas.has(qid):
		print("ℹ️ Quest já concluída:", qid)
		return
	if quests_ativas.has(qid) and String(quests_ativas[qid].get("status","")) == "accepted":
		print("ℹ️ Quest já aceita:", qid)
		return

	var q := cfg.duplicate(true)
	q.status = "accepted"

	# Normaliza estrutura para 'collect'
	if String(q.get("tipo","")) == "collect":
		if not q.has("req_items"):
			q.req_items = {}  # {"item_id": qtd}
		if not q.has("have"):
			q.have = {}
		for id in q.req_items.keys():
			q.have[id] = int(q.have.get(id, 0))

	quests_ativas[qid] = q

	var title := String(q.get("title", qid))
	print("✅ Quest aceita:", title, " (", qid, ")")
	emit_signal("quest_accepted", qid, title)

	# (Opcional) sincronia com Dialogic
	if Engine.has_singleton("Dialogic"):
		var D := Engine.get_singleton("Dialogic")
		if D and "Variables" in D:
			D.Variables.set_variable("quest/%s/status" % qid, "accepted")
			D.Variables.set_variable("quest/%s/title" % qid, title)

func complete_quest(qid: String, motivo: String="") -> void:
	if not quests_ativas.has(qid):
		print("❌ Tentativa de completar quest inexistente/nao aceita:", qid)
		return
	var q = quests_ativas[qid]
	if String(q.get("status","")) != "accepted":
		print("⛔ Quest não está aceita:", qid)
		return

	q.status = "completed"
	quests_ativas.erase(qid)
	quests_concluidas[qid] = true

	var title := String(q.get("title", qid))
	print("🏆 Missão concluída:", title, "(id:", qid, ", motivo:", motivo, ")")
	emit_signal("quest_completed", qid, title, motivo)

	# (Opcional) dialogic vars
	if Engine.has_singleton("Dialogic"):
		var D := Engine.get_singleton("Dialogic")
		if D and "Variables" in D:
			D.Variables.set_variable("quest/%s/status" % qid, "completed")
			D.Variables.set_variable("quest/%s/done" % qid, true)

func get_active_quests() -> Dictionary:
	return quests_ativas

func get_completed_quests() -> Dictionary:
	return quests_concluidas

# ---- Progresso por itens coletados ----
func _pv_on_item_collected(id_item: String, _item_node: Node3D) -> void:
	# Atualiza todas as quests de coleta aceitas que dependam desse item
	for qid in quests_ativas.keys():
		var q = quests_ativas[qid]
		if String(q.get("tipo","")) != "collect": 
			continue
		if String(q.get("status","")) != "accepted":
			continue
		if not q.req_items.has(id_item):
			continue

		# incrementa 'have'
		var have := int(q.have.get(id_item, 0)) + 1
		q.have[id_item] = have
		quests_ativas[qid] = q

		emit_signal("quest_progress", qid, q.have)
		print("🧭 Quest", qid, "progresso:", q.have, "/", q.req_items)

		# se cumpriu tudo, completa
		if _pv_is_collect_done(q):
			complete_quest(qid, "collect")

func _pv_is_collect_done(q: Dictionary) -> bool:
	for id in q.req_items.keys():
		var need := int(q.req_items[id])
		var have := int(q.have.get(id, 0))
		if have < need:
			return false
	return true

# ---- Completa 'talk' quando conversa com o NPC alvo ----
func _pv_on_npc_dialog_triggered(npc_name: String, _timeline: String) -> void:
	for qid in quests_ativas.keys():
		var q = quests_ativas[qid]
		if String(q.get("tipo","")) != "talk":
			continue
		if String(q.get("status","")) != "accepted":
			continue
		if String(q.get("req_talk_to","")) != npc_name:
			continue

		complete_quest(qid, "talk")
