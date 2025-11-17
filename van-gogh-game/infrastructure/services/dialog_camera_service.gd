extends Node
class_name DialogCameraService

signal dialog_finished

@export var camera: Camera3D

@export var gameplay_target: Node3D
@export var gameplay_follow_speed: float = 5.0

# Níveis de zoom
@export var default_zoom: float = 5.0
@export var initial_zoom: float = 3.0
@export var final_zoom: float = 2.5

# Configurações de Animação
@export var zoom_in_tempo: float = 0.8
@export var zoom_out_tempo: float = 0.5
@export var focus_velocity: float = 0.5

@export var offset_camera: Vector3 = Vector3(0, 4, 6)

var camera_tween: Tween
var is_in_dialogue: bool = false


func _ready() -> void:
	if camera:
		camera.size = default_zoom
	else:
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if is_in_dialogue or not is_instance_valid(gameplay_target):
		return
	
	var pos_alvo = calc_focus_position(gameplay_target)
	camera.global_position = camera.global_position.lerp(pos_alvo, delta * gameplay_follow_speed)

func start_dialog(personagem_alvo: Node3D) -> void:
	if not camera: return
	
	is_in_dialogue = true
	_start_tween_focus_zoom(personagem_alvo, initial_zoom, zoom_in_tempo)

func focus_character(novo_alvo: Node3D) -> void:
	if not camera or not novo_alvo: return
	
	_start_tween_focus_zoom(novo_alvo, camera.size, focus_velocity)

func finish_dialog() -> void:
	if not camera: return
	
	
	if camera_tween and camera_tween.is_running():
		camera_tween.kill()
		
	camera_tween = create_tween()
	camera_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	camera_tween.tween_property(camera, "size", default_zoom, zoom_out_tempo)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	camera_tween.finished.connect(func():
		dialog_finished.emit()
		is_in_dialogue = false
	)

func _start_tween_focus_zoom(target: Node3D, new_zoom: float, duration: float) -> void:
	if camera_tween and camera_tween.is_running():
		camera_tween.kill()

	var pos_alvo := calc_focus_position(target)
	camera_tween = create_tween()
	camera_tween.set_parallel()
	camera_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	camera_tween.tween_property(camera, "global_position", pos_alvo, focus_velocity)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	camera_tween.tween_property(camera, "size", new_zoom, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func calc_focus_position(target: Node3D) -> Vector3:
	var pos_alvo := target.global_position + offset_camera
	return pos_alvo
