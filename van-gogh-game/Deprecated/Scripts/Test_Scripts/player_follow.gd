# Nome do arquivo: patrulheiro.gd
extends Node3D

# --- Variáveis Configuráveis ---
@export var velocidade: float = 2.0
@export var duracao_patrulha: float = 10.0
const DURACAO_PAUSA: float = 4.0

@export var camera: Camera3D

# --- Referências aos Nós ---
@onready var path_follow: PathFollow3D = $PathFollow3D
@onready var timer_patrulha: Timer = $TimerPatrulha
@onready var timer_pausa: Timer = $TimerPausa
@onready var sprite: AnimatedSprite3D =$PathFollow3D/CharacterBody3D/AnimatedSprite3D

# --- Controle de Estados ---
enum Estado { MOVENDO, PAUSADO }
var estado_atual = Estado.PAUSADO

# --- Variáveis para Direção ---
# VAI OBSERVAR A POSIÇÃO DO NÓ QUE REALMENTE SE MOVE
var pos_anterior: Vector3 = Vector3.ZERO
var animacao_atual: String = ""


func _ready() -> void:
	if not camera:
		push_error("A câmera não foi definida no Inspetor do Patrulheiro!")
		get_tree().quit()

	timer_patrulha.wait_time = duracao_patrulha
	timer_pausa.wait_time = DURACAO_PAUSA
	
	# **CORREÇÃO AQUI**
	# Inicializa a posição anterior usando a posição do PathFollow3D
	pos_anterior = path_follow.global_position
	
	iniciar_patrulha()

func _process(delta: float) -> void:
	if estado_atual == Estado.MOVENDO:
		path_follow.progress += velocidade * delta
		atualizar_animacao_direcional()
	
	# **CORREÇÃO AQUI**
	# Atualiza a posição anterior usando a posição do PathFollow3D
	pos_anterior = path_follow.global_position


func iniciar_patrulha() -> void:
	print("Iniciando patrulha...")
	estado_atual = Estado.MOVENDO
	timer_patrulha.start()

func iniciar_pausa() -> void:
	print("Pausando por 4 segundos...")
	estado_atual = Estado.PAUSADO
	tocar_animacao("walking_down") # Animação de parado
	timer_pausa.start()


func atualizar_animacao_direcional():
	# **CORREÇÃO AQUI**
	# Calcula a direção usando a posição do PathFollow3D
	var direcao = (path_follow.global_position - pos_anterior).normalized()
	
	# Se não houve movimento significativo, não faz nada.
	if (path_follow.global_position - pos_anterior).length() < 0.001:
		return

	var cam_frente = -camera.global_transform.basis.z
	cam_frente.y = 0
	cam_frente = cam_frente.normalized()
	
	var cam_direita = camera.global_transform.basis.x
	cam_direita.y = 0
	cam_direita = cam_direita.normalized()

	var para_frente = direcao.dot(cam_frente)
	var para_direita = direcao.dot(cam_direita)

	var nova_animacao = ""
	var limiar = 0.4

	if para_frente > limiar:
		if para_direita > limiar: nova_animacao = "walking_up_right"
		elif para_direita < -limiar: nova_animacao = "walking_up_left"
		else: nova_animacao = "walking_up"
	elif para_frente < -limiar:
		if para_direita > limiar: nova_animacao = "walking_down_right"
		elif para_direita < -limiar: nova_animacao = "walking_down_left"
		else: nova_animacao = "walking_down"
	else:
		if para_direita > limiar: nova_animacao = "walking_right"
		elif para_direita < -limiar: nova_animacao = "walking_left"

	tocar_animacao(nova_animacao)

func tocar_animacao(nome: String):
	if nome != "" and nome != animacao_atual:
		animacao_atual = nome
		sprite.play(animacao_atual)

# --- Conexões dos Sinais (Signals) ---
func _on_timer_patrulha_timeout() -> void:
	iniciar_pausa()

func _on_timer_pausa_timeout() -> void:
	iniciar_patrulha()
