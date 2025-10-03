extends Node3D

# --- REFERÊNCIAS GERAIS ---
@export_group("Referências Gerais")
@export var world_environment: WorldEnvironment
@export var directional_light: DirectionalLight3D

# --- CORES DAS ZONAS ---
@export_group("Cores das Zonas")
@export var cor_zona_vermelha: Color = Color("ff4d4d")
@export var cor_zona_azul: Color = Color("4d89ff")
@export var cor_zona_verde: Color = Color("4dff5b")
@export var cor_zona_amarela: Color = Color("fff64d")
@export var cor_neutra: Color = Color.WHITE
@export var cor_padrao: Color = Color.WHITE

# --- ROTAÇÕES DA LUZ (EM GRAUS) ---
@export_group("Rotações da DirectionalLight (em Graus)")
@export var rotacao_zona_vermelha: Vector3 = Vector3(-90, 0, 0)
@export var rotacao_zona_azul: Vector3 = Vector3(-45, 45, 0)
@export var rotacao_zona_verde: Vector3 = Vector3(-45, -45, 0)
@export var rotacao_zona_amarela: Vector3 = Vector3(-90, 90, 0)
@export var rotacao_neutra: Vector3 = Vector3(-60, 0, 0)
@export var rotacao_padrao: Vector3 = Vector3(-60, 0, 0)

# --- ZONAS (Area3D) ---
@export_group("Zonas (Area3D)")
@export var zona_vermelha: Area3D
@export var zona_azul: Area3D
@export var zona_verde: Area3D
@export var zona_amarela: Area3D
@export var zona_neutra: Area3D

# --- DIÁLOGO E CÂMERA ---
@export_group("Diálogo e Câmera")
@export var camera_principal: Camera3D
@export var camera_dialogo: Camera3D
@export var offset_camera: Vector3 = Vector3(0, 1.6, -2.5)
@export var offset_mira: Vector3 = Vector3(0, 1.6, 0)
@export var velocidade_camera: float = 0.7

# Variáveis internas
var zonas_atuais: Array[Area3D] = []
var cor_tween: Tween
var rotacao_tween: Tween
var personagens: Dictionary = {}


func _ready():
	var todas_as_zonas = [zona_vermelha, zona_azul, zona_verde, zona_amarela, zona_neutra]
	for zona in todas_as_zonas:
		if zona:
			zona.body_entered.connect(_on_body_entered.bind(zona))
			zona.body_exited.connect(_on_body_exited.bind(zona))
	
	if camera_dialogo:
		camera_dialogo.current = false
	
	for child in get_children():
		if child is CharacterBody3D or child.name.begins_with("NPC"):
			personagens[child.name] = child

	Dialogic.timeline_started.connect(_on_dialogo_iniciado)
	Dialogic.timeline_ended.connect(_on_dialogo_finalizado)
	Dialogic.event_handled.connect(_on_dialogic_event_handled)
	
	# Espera um frame para garantir que a cena esteja 100% pronta
	await get_tree().process_frame
	Dialogic.start("Timeline_teste")

# --- Funções de Controle das Zonas ---
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

func _iniciar_transicao(cor_alvo: Color, rotacao_alvo_graus: Vector3):
	_transicionar_cor(cor_alvo)
	_transicionar_rotacao(rotacao_alvo_graus)

func _transicionar_cor(cor_alvo: Color):
	if cor_tween and cor_tween.is_running(): cor_tween.kill()
	cor_tween = create_tween()
	cor_tween.tween_property(world_environment.environment, "ambient_light_color", cor_alvo, 1.5).set_trans(Tween.TRANS_SINE)

func _transicionar_rotacao(rotacao_alvo_graus: Vector3):
	if not directional_light: return
	if rotacao_tween and rotacao_tween.is_running(): rotacao_tween.kill()
	rotacao_tween = create_tween()
	rotacao_tween.tween_property(directional_light, "rotation_degrees", rotacao_alvo_graus, 1.5).set_trans(Tween.TRANS_SINE)


# --- Funções de Controle de Diálogo ---
func _on_dialogo_iniciado() -> void:
	if camera_principal: camera_principal.current = false
	if camera_dialogo: camera_dialogo.current = true

func _on_dialogo_finalizado() -> void:
	if camera_dialogo: camera_dialogo.current = false
	if camera_principal: camera_principal.current = true

func _on_dialogic_event_handled(event_resource) -> void:
	if "character" in event_resource and event_resource.character != null:
		var character_name: String = event_resource.character.name
		
		if character_name == "":
			return
			
		if personagens.has(character_name):
			var alvo: Node3D = personagens[character_name]
			var pos_final_camera = alvo.global_transform.origin - alvo.global_transform.basis * offset_camera
			
			var tween = create_tween().set_trans(Tween.TRANS_SINE)
			
			tween.tween_method(
				_atualizar_posicao_camera.bind(alvo),
				camera_dialogo.global_transform,
				pos_final_camera,
				velocidade_camera
			).as_relative()

func _atualizar_posicao_camera(nova_posicao: Vector3, alvo: Node3D) -> void:
	camera_dialogo.global_position = nova_posicao
	camera_dialogo.look_at(alvo.global_position + offset_mira)
