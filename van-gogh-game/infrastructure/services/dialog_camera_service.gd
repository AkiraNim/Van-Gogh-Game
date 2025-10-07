extends Node3D
class_name DialogCameraService

signal zoom_iniciado
signal zoom_finalizado

@export var camera_principal: Camera3D
@export var camera_dialogo: Camera3D
@export var zoom_inicial: float = 10.0
@export var zoom_final: float = 5.0
@export var zoom_duracao: float = 1.2
@export var offset_camera: Vector3 = Vector3(0, 1.6, 2.8)
@export var velocidade_foco: float = 0.6

var zoom_tween: Tween
var foco_tween: Tween

func _ready() -> void:
	if camera_principal and camera_dialogo:
		camera_principal.current = true
		camera_dialogo.current = false
		camera_dialogo.size = zoom_inicial

func ativar_camera_dialogo() -> void:
	camera_principal.current = false
	camera_dialogo.current = true

func restaurar_camera_principal() -> void:
	camera_dialogo.current = false
	camera_principal.current = true

func iniciar_zoom_in() -> void:
	if zoom_tween and zoom_tween.is_running(): zoom_tween.kill()
	zoom_tween = create_tween()
	zoom_tween.tween_property(camera_dialogo, "size", zoom_final, zoom_duracao)
	zoom_iniciado.emit()

func iniciar_zoom_out() -> void:
	if zoom_tween and zoom_tween.is_running(): zoom_tween.kill()
	zoom_tween = create_tween()
	zoom_tween.tween_property(camera_dialogo, "size", zoom_inicial, zoom_duracao)
	zoom_finalizado.emit()

func focar_personagem(char_node: Node3D) -> void:
	if not (camera_dialogo and char_node): return
	var pos_alvo = char_node.global_transform.origin + char_node.global_transform.basis * offset_camera
	if foco_tween and foco_tween.is_running(): foco_tween.kill()
	foco_tween = create_tween()
	foco_tween.tween_property(camera_dialogo, "global_position", pos_alvo, velocidade_foco)
	foco_tween.tween_callback(camera_dialogo.look_at.bind(char_node.global_position))
