extends CharacterBody3D

@export var speed: float = 2.0

@export var anim_sprite: AnimatedSprite3D

# Variável para guardar a última direção de movimento.
# O valor inicial define a animação idle_down como padrão ao iniciar o jogo.
var last_direction = Vector3(0, 0, 1)

func _physics_process(delta):
	var input_dir = Vector3.ZERO

	if Input.is_action_pressed("move_up"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_down"):
		input_dir.z += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
		velocity = input_dir * speed
		# A mágica acontece aqui: guardamos a direção (inclusive diagonais)
		last_direction = input_dir
	else:
		velocity = Vector3.ZERO

	move_and_slide()
	_update_animation()

func _update_animation() -> void:
	var anim_prefix: String
	var direction_vector: Vector3

	# 1. Decide se o estado é "walking" ou "idle"
	if velocity.length() > 0:
		anim_prefix = "walking"
		direction_vector = velocity.normalized() # Usa a direção atual do movimento
	else:
		anim_prefix = "idle"
		direction_vector = last_direction # Usa a ÚLTIMA direção guardada

	var anim_suffix = ""

	# 2. O MESMO bloco de código decide o sufixo para AMBOS os estados
	# Se direction_vector veio de last_direction (parado na diagonal), ele vai
	# entrar em uma das condições de diagonal abaixo.
	
	# Checa Diagonais PRIMEIRO
	if direction_vector.z < -0.5 and direction_vector.x > 0.5:
		anim_suffix = "_up_right"
	elif direction_vector.z < -0.5 and direction_vector.x < -0.5:
		anim_suffix = "_up_left"
	elif direction_vector.z > 0.5 and direction_vector.x > 0.5:
		anim_suffix = "_down_right"
	elif direction_vector.z > 0.5 and direction_vector.x < -0.5:
		anim_suffix = "_down_left"
	# Checa Retas (Horizontais / Verticais)
	elif direction_vector.x > 0.5:
		anim_suffix = "_right"
	elif direction_vector.x < -0.5:
		anim_suffix = "_left"
	elif direction_vector.z < -0.5:
		anim_suffix = "_up"
	elif direction_vector.z > 0.5:
		anim_suffix = "_down"
		
	# 3. Monta o nome final e toca a animação
	var final_anim = anim_prefix + anim_suffix
	
	if anim_sprite.animation != final_anim:
		anim_sprite.play(final_anim)
