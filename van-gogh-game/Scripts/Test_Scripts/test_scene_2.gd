extends Node3D

# --- NÓS EXTERNOS ---
@export var world_environment: WorldEnvironment
@export var directional_light: DirectionalLight3D

# --- CORES ---
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

# --- DIALOGIC ---
@export_group("Dialogic")
@export var camera_principal: Camera3D
@export var camera_dialogo: Camera3D
@export var zoom_inicial: float = 10.0
@export var zoom_final: float = 5.0
@export var zoom_duracao: float = 1.2
@export var offset_camera: Vector3 = Vector3(0, 1.6, 2.8)
@export var velocidade_foco: float = 0.6

# --- VARIÁVEIS INTERNAS ---
var zoom_tween: Tween
var foco_tween: Tween
var cor_tween: Tween
var rotacao_tween: Tween
var zonas_atuais: Array[Area3D] = []

# --- INICIALIZAÇÃO ---
func _ready():
	var todas_as_zonas = [zona_vermelha, zona_azul, zona_verde, zona_amarela, zona_neutra]
	for zona in todas_as_zonas:
		if zona:
			zona.body_entered.connect(_on_body_entered.bind(zona))
			zona.body_exited.connect(_on_body_exited.bind(zona))

	if not Dialogic.timeline_started.is_connected(_on_dialogo_iniciado):
		Dialogic.timeline_started.connect(_on_dialogo_iniciado)
	if not Dialogic.timeline_ended.is_connected(_on_dialogo_finalizado):
		Dialogic.timeline_ended.connect(_on_dialogo_finalizado)
	if not Dialogic.event_handled.is_connected(_on_evento_dialogic):
		Dialogic.event_handled.connect(_on_evento_dialogic)

	call_deferred("_inicializar_cameras")


func _inicializar_cameras():
	if camera_principal and camera_dialogo:
		camera_principal.current = true
		camera_dialogo.current = false
		camera_dialogo.size = zoom_inicial
		Dialogic.start("Timeline_teste")


# --- CONTROLES DO DIALOGIC ---
func _on_dialogo_iniciado():
	if not camera_dialogo or not camera_principal:
		return
	camera_principal.current = false
	camera_dialogo.current = true
	call_deferred("_iniciar_zoom_ortografico")
	print("Diálogo iniciado.")


func _on_dialogo_finalizado():
	if not camera_dialogo or not camera_principal:
		return
	camera_dialogo.current = false
	camera_principal.current = true
	camera_dialogo.size = zoom_inicial
	print("Diálogo finalizado.")


func _on_evento_dialogic(event_resource):
	if "character" in event_resource:
		var character_resource = event_resource.character
		
		if character_resource:
			var char_name_string = character_resource.display_name
			
			if char_name_string != "":
				print("Personagem falando: '", char_name_string, "'. Focando a câmera.")
				_focar_personagem(char_name_string)


# --- FUNÇÕES DE CÂMERA ---
func _iniciar_zoom_ortografico():
	if not camera_dialogo:
		return
	if zoom_tween and zoom_tween.is_running():
		zoom_tween.kill()

	zoom_tween = create_tween()
	zoom_tween.tween_property(
		camera_dialogo,
		"size",
		zoom_final,
		zoom_duracao
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _focar_personagem(nome: String):
	# PROTEÇÃO ADICIONADA: Se a câmera de diálogo não foi definida, a função para aqui.
	if not camera_dialogo:
		print("ERRO: A variável 'camera_dialogo' não foi definida no inspetor.")
		return

	var char_node = get_tree().get_current_scene().get_node_or_null(nome)
	
	if not (char_node and char_node is Node3D):
		print("AVISO: Personagem '", nome, "' não encontrado na cena.")
		return

	var pos_alvo = char_node.global_transform.origin + char_node.global_transform.basis * offset_camera

	if foco_tween and foco_tween.is_running():
		foco_tween.kill()

	foco_tween = create_tween()
	foco_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	foco_tween.tween_property(camera_dialogo, "global_position", pos_alvo, velocidade_foco)
	foco_tween.tween_callback(camera_dialogo.look_at.bind(char_node.global_position))


# --- CONTROLES DAS ZONAS DE AMBIENTE (Sem alterações) ---
# (O resto do código permanece o mesmo)
func _on_body_entered(body, zona: Area3D):
	if body.is_in_group("player") and not zonas_atuais.has(zona):
		zonas_atuais.push_back(zona)
		_atualizar_estado_ambiente()
		Dialogic.start("Timeline_teste")


func _on_body_exited(body, zona: Area3D):
	if body.is_in_group("player") and zonas_atuais.has(zona):
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
	if cor_tween and cor_tween.is_running():
		cor_tween.kill()
	cor_tween = create_tween()
	cor_tween.tween_property(
		world_environment.environment,
		"ambient_light_color",
		cor_alvo,
		1.5
	).set_trans(Tween.TRANS_SINE)


func _transicionar_rotacao(rotacao_alvo_graus: Vector3):
	if not directional_light:
		return
	if rotacao_tween and rotacao_tween.is_running():
		rotacao_tween.kill()
	rotacao_tween = create_tween()
	rotacao_tween.tween_property(
		directional_light,
		"rotation_degrees",
		rotacao_alvo_graus,
		1.5
	).set_trans(Tween.TRANS_SINE)
