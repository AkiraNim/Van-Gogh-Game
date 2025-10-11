extends CharacterBody3D
class_name PlayerView

signal item_coletado(item_node)
signal contagem_estrelas_mudou(nova_contagem: int)

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
