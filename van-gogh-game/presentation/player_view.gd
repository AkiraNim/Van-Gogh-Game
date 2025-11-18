extends CharacterBody3D
class_name PlayerView

signal item_collected(item_node)
signal stars_count_changed(nova_contagem: int)
signal quest_accepted(qid: String, title: String)
signal quest_progress(qid: String, have: Dictionary)
signal quest_completed(qid: String, title: String, motivo: String)


@export var speed: float = 2.0
@export var anim_sprite: AnimatedSprite3D
@export var ponto_item_acima: Marker3D
@export var nome_personagem: String = "Player"
@export var default_idle: StringName = "idle_down"

var anim_lock_name: StringName = ""
var anim_lock_time: float = 0.0
var _held_item: Node3D = null
var can_move: bool = true
var last_direction := Vector3.FORWARD
var velocity_vector := Vector3.ZERO
var is_sitting: bool = false
var finished_quests := {}
var active_quests := {}

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

	if not EventBus.dialog_started.is_connected(_on_dialog_started):
		EventBus.dialog_started.connect(_on_dialog_started)
	if not EventBus.dialog_ended.is_connected(_on_dialog_ended):
		EventBus.dialog_ended.connect(_on_dialog_ended)
	if has_node("/root/EventBus"):
		var eb := get_node("/root/EventBus")
		if not eb.item_collected.is_connected(_pv_on_item_collected):
			eb.item_collected.connect(_pv_on_item_collected)
		if not eb.npc_dialog_triggered.is_connected(_pv_on_npc_dialog_triggered):
			eb.npc_dialog_triggered.connect(_pv_on_npc_dialog_triggered)

func set_held_item(n: Node3D) -> void:
	_held_item = n

func get_held_item_node() -> Node3D:
	return _held_item

func destroy_held_item() -> void:
	if is_instance_valid(_held_item):
		_held_item.queue_free()
	_held_item = null

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

	if not can_move:
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

func _on_dialog_started() -> void:
	can_move = false
	velocity = Vector3.ZERO

func _on_dialog_ended() -> void:
	can_move = not is_sitting

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

# ========================= QUESTS =========================
func accept_quest(qid: String, cfg: Dictionary) -> void:
	if active_quests.has(qid):
		return
	if finished_quests.has(qid) and String(finished_quests[qid].get("status","")) == "accepted":
		return

	var q := cfg.duplicate(true)
	q.status = "accepted"

	if String(q.get("type","")) == "collect":
		if not q.has("req_items"):
			q.req_items = {}
		if not q.has("have"):
			q.have = {}
		for id in q.req_items.keys():
			q.have[id] = int(q.have.get(id, 0))

	finished_quests[qid] = q
	var title := String(q.get("title", qid))
	emit_signal("quest_accepted", qid, title)

	if Engine.has_singleton("Dialogic"):
		var D := Engine.get_singleton("Dialogic")
		if D and "Variables" in D:
			D.Variables.set_variable("quest/%s/status" % qid, "accepted")
			D.Variables.set_variable("quest/%s/title" % qid, title)

func complete_quest(qid: String, motivo: String="") -> void:
	if not finished_quests.has(qid):
		return
	var q = finished_quests[qid]
	if String(q.get("status","")) != "accepted":
		return

	q.status = "completed"
	finished_quests.erase(qid)
	active_quests[qid] = true
	var title := String(q.get("title", qid))
	emit_signal("quest_completed", qid, title, motivo)

	if Engine.has_singleton("Dialogic"):
		var D := Engine.get_singleton("Dialogic")
		if D and "Variables" in D:
			D.Variables.set_variable("quest/%s/status" % qid, "completed")
			D.Variables.set_variable("quest/%s/done" % qid, true)

func get_active_quests() -> Dictionary:
	return finished_quests

func get_completed_quests() -> Dictionary:
	return active_quests

func _pv_on_item_collected(id_item: String, _item_node: Node3D) -> void:
	for qid in finished_quests.keys():
		var q = finished_quests[qid]
		if String(q.get("type","")) != "collect" or String(q.get("status","")) != "accepted" or not q.req_items.has(id_item):
			continue
		
		var have := int(q.have.get(id_item, 0)) + 1
		q.have[id_item] = have
		finished_quests[qid] = q

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
	for qid in finished_quests.keys():
		var q = finished_quests[qid]
		if String(q.get("type","")) != "talk" or String(q.get("status","")) != "accepted" or String(q.get("req_talk_to","")) != npc_name:
			continue
		complete_quest(qid, "talk")
