extends Node3D
class_name NpcView

@export var anim_sprite: AnimatedSprite3D
@export var default_idle: StringName = "idle_down"  
@export var nome_npc: String = "NPC"
@export var auto_listen_dialogic: bool = true
@export var dialogic_key: String = ""              

var anim_lock_name: StringName = ""
var anim_lock_time: float = 0.0
var is_sitting: bool = false
var pode_mover: bool = true

var last_direction := Vector3.FORWARD   
var _prev_pos := Vector3.ZERO
var _vel_estimate := Vector3.ZERO
const _MOVE_EPS := 0.01

func _enter_tree() -> void:
	add_to_group("npc")

func _ready() -> void:
	_prev_pos = global_position
	last_direction = _dir_from_idle(String(default_idle))
	if auto_listen_dialogic:
		_connect_dialog_bridge()
	_play_safe(default_idle)

func _physics_process(delta: float) -> void:
	if is_sitting:
		return

	if anim_lock_name != "" or anim_lock_time > 0.0:
		if anim_lock_time > 0.0:
			anim_lock_time = max(0.0, anim_lock_time - delta)
			if anim_lock_time == 0.0:
				anim_lock_name = ""
				_play_safe(default_idle)
		return

	if not pode_mover:
		_update_animation(false)
		return

	var cur := global_position
	var disp := cur - _prev_pos
	_prev_pos = cur
	_vel_estimate = disp / max(delta, 0.000001)

	var is_moving := _vel_estimate.length() > _MOVE_EPS
	if is_moving:
		last_direction = _vel_estimate.normalized()

	_update_animation(is_moving)


func lock_animation(name: StringName, duration: float = -1.0) -> void:
	anim_lock_name = name
	anim_lock_time = duration
	_freeze()
	_play_safe(name)
	
func unlock_animation() -> void:
	anim_lock_name = ""
	anim_lock_time = 0.0
	_play_safe(default_idle)
	_unfreeze()

func set_default_idle(anim: StringName) -> void:
	default_idle = anim
	last_direction = _dir_from_idle(String(default_idle))
	if anim_lock_name == "" and pode_mover and not is_sitting:
		_play_safe(default_idle)

func freeze() -> void: _freeze()
func unfreeze() -> void:
	if anim_lock_name == "" and not is_sitting:
		_unfreeze()

func face_direction(dir: Vector3) -> void:
	if dir.length() > 0.01:
		last_direction = dir.normalized()
		_update_animation(false)

func _freeze() -> void:
	if has_method("set_physics_process"):
		set_physics_process(false)
	if has_method("set_process"):
		set_process(false)
	pode_mover = false

func _unfreeze() -> void:
	if has_method("set_physics_process"):
		set_physics_process(true)
	if has_method("set_process"):
		set_process(true)
	pode_mover = true
	_prev_pos = global_position

func _play_safe(name: StringName) -> void:
	if anim_sprite == null: return
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

func _update_animation(is_moving: bool) -> void:
	if anim_sprite == null: return
	if is_sitting or anim_lock_name != "": return

	var prefix := "walking" if is_moving else "idle"
	var dir := last_direction
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
	if anim_sprite.animation != anim:
		anim_sprite.play(anim)

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


func _connect_dialog_bridge() -> void:
	var bridge := get_tree().get_first_node_in_group("dialog_bridge")
	if bridge == null:
		await get_tree().process_frame
		_connect_dialog_bridge()
		return

	if bridge.has_signal("npc_lock_animation"):
		if not bridge.npc_lock_animation.is_connected(_on_dialogic_npc_lock):
			bridge.npc_lock_animation.connect(_on_dialogic_npc_lock)
	if bridge.has_signal("npc_unlock_animation"):
		if not bridge.npc_unlock_animation.is_connected(_on_dialogic_npc_unlock):
			bridge.npc_unlock_animation.connect(_on_dialogic_npc_unlock)

func _on_dialogic_npc_lock(key: String, name: String, duration: float) -> void:
	if dialogic_key != "" and key != dialogic_key: return
	lock_animation(name, duration)

func _on_dialogic_npc_unlock(key: String) -> void:
	if dialogic_key != "" and key != dialogic_key: return
	unlock_animation()
