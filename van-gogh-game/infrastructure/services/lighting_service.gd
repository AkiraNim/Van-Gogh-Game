extends Node
class_name LightingService

@export var world_environment: WorldEnvironment
@export var directional_light: DirectionalLight3D

var _cor_tween: Tween
var _rot_tween: Tween

func transicionar(cor_alvo: Color, rotacao_alvo: Vector3, duracao: float = 1.5):
	_transicionar_cor(cor_alvo, duracao)
	_transicionar_rotacao(rotacao_alvo, duracao)

func _transicionar_cor(cor_alvo: Color, duracao: float):
	if _cor_tween and _cor_tween.is_running():
		_cor_tween.kill()
	_cor_tween = create_tween()
	if world_environment:
		_cor_tween.tween_property(
			world_environment.environment, 
			"ambient_light_color", 
			cor_alvo, duracao
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _transicionar_rotacao(rotacao_alvo: Vector3, duracao: float):
	if not directional_light:
		return
	if _rot_tween and _rot_tween.is_running():
		_rot_tween.kill()
	_rot_tween = create_tween()
	_rot_tween.tween_property(
		directional_light, 
		"rotation_degrees", 
		rotacao_alvo, duracao
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
