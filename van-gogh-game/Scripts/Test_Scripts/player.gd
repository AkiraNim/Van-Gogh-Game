extends CharacterBody3D

signal contagem_estrelas_mudou(nova_contagem: int)
signal item_coletado(item_node)

@export var speed: float = 2.0
@export var anim_sprite: AnimatedSprite3D
@export var ponto_item_acima: Marker3D
@export var spotlight_item: SpotLight3D

var last_direction = Vector3(0, 0, 1)
var estrelas_coletadas: int = 0
var item_segurado_atualmente = null
var pode_mover: bool = true

func _ready():
	if spotlight_item:
		spotlight_item.visible = false
	
	$AreaColeta.area_entered.connect(_on_area_de_coleta_area_entered)
	
	%DialogManager.dialogo_iniciou.connect(_on_dialogo_comecou)
	%DialogManager.dialogo_terminou.connect(_on_dialogo_terminou)

func _on_dialogo_comecou():
	pode_mover = false
	velocity = Vector3.ZERO

func _on_dialogo_terminou():
	pode_mover = true

func _on_area_de_coleta_area_entered(area_do_item):
	if area_do_item.is_in_group("coletaveis") and not area_do_item.coletado:
		area_do_item.coletado = true
		item_coletado.emit(area_do_item)

func segurar_item(item_node):
	if not ponto_item_acima:
		print("ERRO no PlayerScript: Nó 'PontoItemAcima' não definido.")
		item_node.queue_free()
		return
	
	item_node.get_parent().remove_child(item_node)
	ponto_item_acima.add_child(item_node)
	item_node.position = Vector3.ZERO
	item_segurado_atualmente = item_node

func destruir_item_segurado():
	if is_instance_valid(item_segurado_atualmente):
		item_segurado_atualmente.queue_free()
		item_segurado_atualmente = null

func adicionar_estrela():
	estrelas_coletadas += 1
	print("Player agora tem ", estrelas_coletadas, " estrela(s).")
	contagem_estrelas_mudou.emit(estrelas_coletadas)

func acender_spotlight():
	if spotlight_item:
		spotlight_item.visible = true

func apagar_spotlight():
	if spotlight_item:
		spotlight_item.visible = false

func _physics_process(delta):
	if not pode_mover:
		velocity = Vector3.ZERO
		move_and_slide()
		_update_animation()
		return
		
	var input_dir = Vector3.ZERO
	if Input.is_action_pressed("move_up"): input_dir.z -= 1
	if Input.is_action_pressed("move_down"): input_dir.z += 1
	if Input.is_action_pressed("move_left"): input_dir.x -= 1
	if Input.is_action_pressed("move_right"): input_dir.x += 1

	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
		velocity = input_dir * speed
		last_direction = input_dir
	else:
		velocity = Vector3.ZERO
	move_and_slide()
	_update_animation()

func _update_animation() -> void:
	var anim_prefix: String
	var direction_vector: Vector3
	if velocity.length() > 0:
		anim_prefix = "walking"
		direction_vector = velocity.normalized()
	else:
		anim_prefix = "idle"
		direction_vector = last_direction
	var anim_suffix = ""
	if direction_vector.z < -0.5 and direction_vector.x > 0.5: anim_suffix = "_up_right"
	elif direction_vector.z < -0.5 and direction_vector.x < -0.5: anim_suffix = "_up_left"
	elif direction_vector.z > 0.5 and direction_vector.x > 0.5: anim_suffix = "_down_right"
	elif direction_vector.z > 0.5 and direction_vector.x < -0.5: anim_suffix = "_down_left"
	elif direction_vector.x > 0.5: anim_suffix = "_right"
	elif direction_vector.x < -0.5: anim_suffix = "_left"
	elif direction_vector.z < -0.5: anim_suffix = "_up"
	elif direction_vector.z > 0.5: anim_suffix = "_down"
	var final_anim = anim_prefix + anim_suffix
	if anim_sprite.animation != final_anim: anim_sprite.play(final_anim)
