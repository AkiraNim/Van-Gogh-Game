extends Node
class_name DialogCameraService

signal zoom_out_finished

@export var camera_principal: Camera3D
@export var camera_dialogo: Camera3D
@export var zoom_inicial: float = 10.0
@export var zoom_final: float = 5.0
@export var zoom_duracao: float = 1.2
@export var offset_camera: Vector3 = Vector3(0, 1.6, 2.8)
@export var velocidade_foco: float = 0.6

var zoom_tween: Tween
var foco_tween: Tween


# -------------------------------------------------
# Inicialização
# -------------------------------------------------
func _ready() -> void:
	if camera_principal:
		camera_principal.current = true
	if camera_dialogo:
		camera_dialogo.current = false
		camera_dialogo.size = zoom_inicial
	print("🎥 Serviço de câmera iniciado:", camera_principal.name, camera_dialogo.name)


# -------------------------------------------------
# Ativa a câmera de diálogo
# -------------------------------------------------
func ativar_camera_dialogo() -> void:
	if not (camera_principal and camera_dialogo):
		return

	# Desativa a principal e ativa a de diálogo
	camera_principal.current = false
	camera_dialogo.current = true
	camera_dialogo.size = zoom_inicial

	print("🎬 Solicitando ativação da câmera de diálogo...")

	# Aguarda o frame atual e o próximo frame de física
	await get_tree().process_frame
	await get_tree().physics_frame

	# Força a câmera de diálogo como current
	if not camera_dialogo.is_current():
		camera_dialogo.make_current()

	await get_tree().process_frame

	# Fallback: se ainda não assumiu, força diretamente no viewport
	var vp := camera_dialogo.get_viewport()
	if vp and vp.get_camera_3d() != camera_dialogo:
		vp.set_camera_3d(camera_dialogo)
		print("⚙️ Câmera de diálogo forçada no viewport.")

	var ativa := (camera_dialogo.get_viewport() and camera_dialogo.get_viewport().get_camera_3d())
	


# -------------------------------------------------
# Desativa a de diálogo e restaura a principal
# -------------------------------------------------
func desativar_camera_dialogo() -> void:
	if not (camera_principal and camera_dialogo):
		return

	camera_dialogo.current = false
	camera_principal.current = true

	await get_tree().process_frame
	await get_tree().physics_frame

	if not camera_principal.is_current():
		camera_principal.make_current()

	await get_tree().process_frame

	var vp := camera_principal.get_viewport()
	if vp and vp.get_camera_3d() != camera_principal:
		vp.set_camera_3d(camera_principal)
		print("⚙️ Câmera principal forçada no viewport.")

	var ativa := (camera_principal.get_viewport() and camera_principal.get_viewport().get_camera_3d())
	


# -------------------------------------------------
# Zoom In / Out
# -------------------------------------------------
func iniciar_zoom_in() -> void:
	if not camera_dialogo:
		return
	if zoom_tween and zoom_tween.is_running():
		zoom_tween.kill()
	zoom_tween = create_tween()
	zoom_tween.tween_property(camera_dialogo, "size", zoom_final, zoom_duracao)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	print("🔍 Zoom in iniciado")

func iniciar_zoom_out() -> void:
	if not camera_dialogo:
		return
	if zoom_tween and zoom_tween.is_running():
		zoom_tween.kill()
	zoom_tween = create_tween()
	zoom_tween.tween_property(camera_dialogo, "size", zoom_inicial, zoom_duracao)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	zoom_tween.finished.connect(func():
		zoom_out_finished.emit()
		desativar_camera_dialogo()
	)
	print("🔎 Zoom out iniciado")


# -------------------------------------------------
# Foco no personagem falante
# -------------------------------------------------
func focar_personagem(alvo: Node3D) -> void:
	if not (camera_dialogo and alvo):
		return

	var pos_alvo: Vector3 = alvo.global_transform.origin + alvo.global_transform.basis * offset_camera

	if foco_tween and foco_tween.is_running():
		foco_tween.kill()

	foco_tween = create_tween()
	foco_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	foco_tween.tween_property(camera_dialogo, "global_position", pos_alvo, velocidade_foco)
	foco_tween.tween_callback(camera_dialogo.look_at.bind(alvo.global_position))

	print("🎯 Focando câmera em:", alvo.name)
