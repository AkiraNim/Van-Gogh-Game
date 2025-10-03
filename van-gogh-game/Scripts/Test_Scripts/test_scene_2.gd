extends Node3D

# Arraste o nó WorldEnvironment aqui pelo inspetor
@export var world_environment: WorldEnvironment
# Arraste o nó DirectionalLight3D aqui pelo inspetor
@export var directional_light: DirectionalLight3D

# --- CORES ---
@export_group("Cores das Zonas")
@export var cor_zona_vermelha: Color = Color("3a0a0a")
@export var cor_zona_azul: Color = Color("10244b")
@export var cor_zona_verde: Color = Color("0d4211")
@export var cor_zona_amarela: Color = Color("504d12")
@export var cor_neutra: Color = Color("010201")
@export var cor_padrao: Color = Color("010201")

# --- ROTAÇÕES DA LUZ (EM GRAUS) ---
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

# Variáveis internas
var zonas_atuais: Array[Area3D] = []
var cor_tween: Tween
var rotacao_tween: Tween


func _ready():
	var todas_as_zonas = [zona_vermelha, zona_azul, zona_verde, zona_amarela, zona_neutra]
	for zona in todas_as_zonas:
		if zona:
			zona.body_entered.connect(_on_body_entered.bind(zona))
			zona.body_exited.connect(_on_body_exited.bind(zona))
	Dialogic.start("Timeline_teste")


func _on_body_entered(body, zona: Area3D):
	if body.is_in_group("player"):
		if not zonas_atuais.has(zona):
			zonas_atuais.push_back(zona)
		_atualizar_estado_ambiente()


func _on_body_exited(body, zona: Area3D):
	if body.is_in_group("player"):
		if zonas_atuais.has(zona):
			zonas_atuais.erase(zona)
		_atualizar_estado_ambiente()


# A função principal foi renomeada para refletir que ela faz mais do que só mudar a cor
func _atualizar_estado_ambiente():
	if zonas_atuais.has(zona_neutra):
		_iniciar_transicao(cor_neutra, rotacao_neutra)
	elif zonas_atuais.has(zona_vermelha):
		_iniciar_transicao(cor_zona_vermelha, rotacao_zona_vermelha)
	elif zonas_atuais.has(zona_azul):
		_iniciar_transicao(cor_zona_azul, rotacao_zona_azul)
	elif zonas_atuais.has(zona_verde):
		_iniciar_transicao(cor_zona_verde, rotacao_zona_verde)
	elif zonas_atuais.has(zona_amarela):
		_iniciar_transicao(cor_zona_amarela, rotacao_zona_amarela)
	else:
		_iniciar_transicao(cor_padrao, rotacao_padrao)


# Esta nova função central inicia AMBAS as transições
func _iniciar_transicao(cor_alvo: Color, rotacao_alvo_graus: Vector3):
	_transicionar_cor(cor_alvo)
	_transicionar_rotacao(rotacao_alvo_graus)


func _transicionar_cor(cor_alvo: Color):
	if cor_tween and cor_tween.is_running():
		cor_tween.kill()
	
	cor_tween = create_tween()
	cor_tween.tween_property(
		world_environment.environment, 
		"ambient_light_color", 
		cor_alvo, 
		1.5 # Duração da transição
	).set_trans(Tween.TRANS_SINE)


# Nova função específica para animar a rotação da DirectionalLight3D
func _transicionar_rotacao(rotacao_alvo_graus: Vector3):
	if not directional_light: return # Não faz nada se a luz não for definida

	if rotacao_tween and rotacao_tween.is_running():
		rotacao_tween.kill()
	
	rotacao_tween = create_tween()
	# Usamos "rotation_degrees" para poder usar ângulos em graus, que são mais fáceis
	rotacao_tween.tween_property(
		directional_light, 
		"rotation_degrees", 
		rotacao_alvo_graus, 
		1.5 # Duração da transição
	).set_trans(Tween.TRANS_SINE)
