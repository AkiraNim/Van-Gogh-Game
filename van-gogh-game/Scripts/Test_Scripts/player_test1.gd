extends CharacterBody2D

@export var speed: float = 200.0
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO

	# Leitura dos inputs (seus nomes específicos)
	if Input.is_action_pressed("move_right"):
		dir.x += 1
	if Input.is_action_pressed("move_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_down"):
		dir.y += 1
	if Input.is_action_pressed("move_up"):
		dir.y -= 1

	dir = dir.normalized()
	velocity = dir * speed
	move_and_slide()

	# Animações de acordo com a direção
	if dir == Vector2.ZERO:
		anim.stop() # fica no último frame
	else:
		if dir.x > 0 and dir.y == 0:
			anim.play("walking_right")
		elif dir.x < 0 and dir.y == 0:
			anim.play("walking_left")
		elif dir.y > 0 and dir.x == 0:
			anim.play("walking_down")
		elif dir.y < 0 and dir.x == 0:
			anim.play("walking_up")
		elif dir.x > 0 and dir.y > 0:
			anim.play("walking_down_right")
		elif dir.x < 0 and dir.y > 0:
			anim.play("walking_down_left")
		elif dir.x > 0 and dir.y < 0:
			anim.play("walking_up_right")
		elif dir.x < 0 and dir.y < 0:
			anim.play("walking_up_left")
