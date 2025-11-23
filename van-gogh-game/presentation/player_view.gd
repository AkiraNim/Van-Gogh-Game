extends CharacterBody3D
class_name PlayerView

signal item_coletado(item_node)
signal contagem_estrelas_mudou(nova_contagem: int)
signal quest_accepted(qid: String, title: String)
signal quest_progress(qid: String, have: Dictionary)
signal quest_completed(qid: String, title: String, motivo: String)

@export var speed: float = 3.0
@export var anim_sprite: AnimatedSprite3D
@export var ponto_item_acima: Marker3D
@export var nome_personagem: String = "Player"
@export var default_idle: StringName = "idle_down"

var anim_lock_name: StringName = ""
var anim_lock_time: float = 0.0
var _item_segurado: Node3D = null
var pode_mover: bool = true
var last_direction := Vector3.FORWARD
var velocity_vector := Vector3.ZERO
var is_sitting: bool = false
var quests_ativas := {}
var quests_concluidas := {}

func _enter_tree() -> void:
	if PlayerRegistry.player == null:
		PlayerRegistry.player = self
		add_to_group("player")
	else:
		queue_free()
		return

func _exit_tree() -> void:
	if PlayerRegistry.player == self:
		PlayerRegistry.player = null

func _ready():
	last_direction = _dir_from_idle(String(default_idle))
	_play_safe(default_idle)

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
	if is_sitting:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if anim_lock_name != "" or anim_lock_time > 0.0:
		if anim_lock_time > 0.0:
			anim_lock_time = max(0.0, anim_lock_time - _delta)
			if anim_lock_time == 0.0:
				anim_lock_name = ""
				_play_safe(default_idle)
		velocity = Vector3.ZERO
		move_and_slide()
		return

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

func _on_dialogo_iniciou() -> void:
	pode_mover = false
	velocity = Vector3.ZERO

func _on_dialogo_terminou() -> void:
	pode_mover = not is_sitting

func _update_animation() -> void:
	if not anim_sprite:
		return
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
			if frames.has_animation(default_idle):
				final_name = default_idle
			elif frames.has_animation("idle_down"):
				final_name = "idle_down"
			elif frames.has_animation("idle"):
				final_name = "idle"
			else:
				return
		anim_sprite.stop()
		anim_sprite.play(final_name)
	else:
		return

func unlock_animation() -> void:
	anim_lock_name = ""
	anim_lock_time = 0.0
	_play_safe(default_idle)

func set_default_idle(anim: StringName) -> void:
	default_idle = anim
	last_direction = _dir_from_idle(String(default_idle))
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
			return
	anim_sprite.stop()
	anim_sprite.play(final_name)

func _dir_from_idle(idle: String) -> Vector3:
	match idle:
		"idle_down": return Vector3.BACK
		"idle_up": return Vector3.FORWARD
		"idle_left": return Vector3.LEFT
		"idle_right": return Vector3.RIGHT
		"idle_up_left": return (Vector3.FORWARD + Vector3.LEFT).normalized()
		"idle_up_right": return (Vector3.FORWARD + Vector3.RIGHT).normalized()
		"idle_down_left": return (Vector3.BACK + Vector3.LEFT).normalized()
		"idle_down_right": return (Vector3.BACK + Vector3.RIGHT).normalized()
		_: return Vector3.BACK

func accept_quest(qid: String, cfg: Dictionary) -> void:
	if quests_concluidas.has(qid):
		return
	if quests_ativas.has(qid) and String(quests_ativas[qid].get("status","")) == "accepted":
		return

	var q := cfg.duplicate(true)
	q.status = "accepted"

	if String(q.get("tipo","")) == "collect":
		if not q.has("req_items"):
			q.req_items = {}
		if not q.has("have"):
			q.have = {}
		for id in q.req_items.keys():
			q.have[id] = int(q.have.get(id, 0))

	quests_ativas[qid] = q
	var title := String(q.get("title", qid))
	emit_signal("quest_accepted", qid, title)

	if Engine.has_singleton("Dialogic"):
		var D := Engine.get_singleton("Dialogic")
		if D and "Variables" in D:
			D.Variables.set_variable("quest/%s/status" % qid, "accepted")
			D.Variables.set_variable("quest/%s/title" % qid, title)

func complete_quest(qid: String, motivo: String="") -> void:
	if not quests_ativas.has(qid):
		return
	var q = quests_ativas[qid]
	if String(q.get("status","")) != "accepted":
		return

	q.status = "completed"
	quests_ativas.erase(qid)
	quests_concluidas[qid] = true
	var title := String(q.get("title", qid))
	emit_signal("quest_completed", qid, title, motivo)

	if Engine.has_singleton("Dialogic"):
		var D := Engine.get_singleton("Dialogic")
		if D and "Variables" in D:
			D.Variables.set_variable("quest/%s/status" % qid, "completed")
			D.Variables.set_variable("quest/%s/done" % qid, true)

func get_active_quests() -> Dictionary:
	return quests_ativas

func get_completed_quests() -> Dictionary:
	return quests_concluidas

func _pv_on_item_collected(id_item: String, _item_node: Node3D) -> void:
	for qid in quests_ativas.keys():
		var q = quests_ativas[qid]
		if String(q.get("tipo","")) != "collect" or String(q.get("status","")) != "accepted" or not q.req_items.has(id_item):
			continue
		
		var have := int(q.have.get(id_item, 0)) + 1
		q.have[id_item] = have
		quests_ativas[qid] = q

		emit_signal("quest_progress", qid, q.have)
		
		if _pv_is_collect_done(q):
			complete_quest(qid, "collect")

func _pv_is_collect_done(q: Dictionary) -> bool:
	for id in q.req_items.keys():
		var need := int(q.req_items[id])
		var have := int(q.have.get(id, 0))
		if have < need:
			return false
	return true

func _pv_on_npc_dialog_triggered(npc_name: String, _timeline: String) -> void:
	for qid in quests_ativas.keys():
		var q = quests_ativas[qid]
		if String(q.get("tipo","")) != "talk" or String(q.get("status","")) != "accepted" or String(q.get("req_talk_to","")) != npc_name:
			continue
		complete_quest(qid, "talk")
