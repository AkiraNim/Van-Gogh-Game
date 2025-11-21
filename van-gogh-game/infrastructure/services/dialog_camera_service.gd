extends Node
class_name DialogCameraService

signal dialogo_finalizado

@export var camera: Camera3D

@export var gameplay_target: Node3D
@export var gameplay_follow_speed: float = 5.0

@export var zoom_padrao: float = 5.0
@export var zoom_inicial: float = 3.0
@export var zoom_final: float = 2.5

@export var duracao_zoom_in: float = 0.8
@export var duracao_zoom_out: float = 0.5
@export var velocidade_foco: float = 0.5
@export var offset_camera: Vector3 = Vector3(0, 4, 6)

var camera_tween: Tween
var is_in_dialogue: bool = false


func _ready() -> void:
	if camera:
		camera.size = zoom_padrao
	else:
		set_physics_process(false)

func _physics_process(delta: float) -> void:
	if is_in_dialogue or not is_instance_valid(gameplay_target):
		return

	var pos_alvo = calcular_posicao_foco(gameplay_target)
	camera.global_position = camera.global_position.lerp(pos_alvo, delta * gameplay_follow_speed)

func iniciar_dialogo(personagem_alvo: Node3D) -> void:
	if not camera: return
	
	is_in_dialogue = true
	
	_iniciar_tween_foco_e_zoom(personagem_alvo, zoom_inicial, duracao_zoom_in)

func focar_personagem(novo_alvo: Node3D) -> void:
	if not camera or not novo_alvo: return
	
	_iniciar_tween_foco_e_zoom(novo_alvo, camera.size, velocidade_foco)


func finalizar_dialogo() -> void:
	if not camera: return
	
	if camera_tween and camera_tween.is_running():
		camera_tween.kill()
		
	camera_tween = create_tween()
	camera_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	camera_tween.tween_property(camera, "size", zoom_padrao, duracao_zoom_out)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	camera_tween.finished.connect(func():
		dialogo_finalizado.emit()
		## NOVO: Avisa que o diálogo acabou, devolvendo o controle da câmera para o gameplay.
		is_in_dialogue = false)

func _iniciar_tween_foco_e_zoom(alvo: Node3D, novo_zoom: float, duracao: float) -> void:
	if camera_tween and camera_tween.is_running():
		camera_tween.kill()

	var pos_alvo := calcular_posicao_foco(alvo)
	camera_tween = create_tween()
	camera_tween.set_parallel()
	camera_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	camera_tween.tween_property(camera, "global_position", pos_alvo, velocidade_foco)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	camera_tween.tween_property(camera, "size", novo_zoom, duracao)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func calcular_posicao_foco(alvo: Node3D) -> Vector3:
	var pos_alvo := alvo.global_position + offset_camera
	return pos_alvo
