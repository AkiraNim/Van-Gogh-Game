# ZoneManager.gd
extends Node3D

# Sinal para avisar qual zona foi ativada
signal player_entrou_na_zona(nome_da_zona: String)

# --- NÓS DO AMBIENTE ---
@export var world_environment: WorldEnvironment
@export var directional_light: DirectionalLight3D

# --- CONFIGURAÇÕES DAS ZONAS ---
@export_group("Cores das Zonas")
@export var cor_zona_vermelha: Color = Color("3a0a0a")
@export var cor_zona_azul: Color = Color("10244b")
@export var cor_zona_verde: Color = Color("0d4211")
@export var cor_zona_amarela: Color = Color("504d12")
@export var cor_neutra: Color = Color("010201")
@export var cor_padrao: Color = Color("010201")

# --- ROTAÇÕES DA LUZ ---
@export_group("Rotações da DirectionalLight (em Graus)")
@export var rotacao_zona_vermelha: Vector3 = Vector3(-29.3, 45.7, 0)
@export var rotacao_zona_azul: Vector3 = Vector3(-29.3, 45.7, 0)
@export var rotacao_zona_verde: Vector3 = Vector3(-29.3, 45.7, 0)
@export var rotacao_zona_amarela: Vector3 = Vector3(-29.3, 45.7, 0)
@export var rotacao_neutra: Vector3 = Vector3(-29.3, 45.7, 0)
@export var rotacao_padrao: Vector3 = Vector3(-29.3, 45.7, 0)

# --- ZONAS ---
@export_group("Zonas (Area3D)")
@export var zona_vermelha: Area3D
@export var zona_azul: Area3D
@export var zona_verde: Area3D
@export var zona_amarela: Area3D
@export var zona_neutra: Area3D

# --- VARIÁVEIS INTERNAS ---
var cor_tween: Tween
var rotacao_tween: Tween
var zonas_atuais: Array[Area3D] = []


func _ready():
	var todas_as_zonas = [zona_vermelha, zona_azul, zona_verde, zona_amarela, zona_neutra]
	for zona in todas_as_zonas:
		if zona:
			zona.body_entered.connect(_on_body_entered.bind(zona))
			zona.body_exited.connect(_on_body_exited.bind(zona))


func _on_body_entered(body, zona: Area3D):
	if body.is_in_group("player") and not zonas_atuais.has(zona):
		zonas_atuais.push_back(zona)
		_atualizar_estado_ambiente()


func _on_body_exited(body, zona: Area3D):
	if body.is_in_group("player") and zonas_atuais.has(zona):
		zonas_atuais.erase(zona)
		_atualizar_estado_ambiente()


func _atualizar_estado_ambiente():
	if zonas_atuais.has(zona_neutra):
		_iniciar_transicao(cor_neutra, rotacao_neutra)
		player_entrou_na_zona.emit("neutra") # Avisa que entrou na zona neutra
	elif zonas_atuais.has(zona_vermelha):
		_iniciar_transicao(cor_zona_vermelha, rotacao_zona_vermelha)
		player_entrou_na_zona.emit("vermelha")
	elif zonas_atuais.has(zona_azul):
		_iniciar_transicao(cor_zona_azul, rotacao_zona_azul)
		player_entrou_na_zona.emit("azul")
	elif zonas_atuais.has(zona_verde):
		_iniciar_transicao(cor_zona_verde, rotacao_zona_verde)
		player_entrou_na_zona.emit("verde")
	elif zonas_atuais.has(zona_amarela):
		_iniciar_transicao(cor_zona_amarela, rotacao_zona_amarela)
		player_entrou_na_zona.emit("amarela")
	else:
		_iniciar_transicao(cor_padrao, rotacao_padrao)
		player_entrou_na_zona.emit("nenhuma")


func _iniciar_transicao(cor_alvo: Color, rotacao_alvo_graus: Vector3):
	_transicionar_cor(cor_alvo)
	_transicionar_rotacao(rotacao_alvo_graus)


func _transicionar_cor(cor_alvo: Color):
	if cor_tween and cor_tween.is_running():
		cor_tween.kill()
	cor_tween = create_tween()
	cor_tween.tween_property(world_environment.environment, "ambient_light_color", cor_alvo, 1.5).set_trans(Tween.TRANS_SINE)


func _transicionar_rotacao(rotacao_alvo_graus: Vector3):
	if not directional_light:
		return
	if rotacao_tween and rotacao_tween.is_running():
		rotacao_tween.kill()
	rotacao_tween = create_tween()
	rotacao_tween.tween_property(directional_light, "rotation_degrees", rotacao_alvo_graus, 1.5).set_trans(Tween.TRANS_SINE)
