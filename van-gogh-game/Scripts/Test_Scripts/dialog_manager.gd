# DialogManager.gd
extends Node3D

signal dialogo_iniciou
signal dialogo_terminou

# --- CONFIGURAÇÕES DO DIALOGIC ---
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

func _ready():
	# Conecta aos sinais internos do Dialogic
	if not Dialogic.timeline_started.is_connected(_on_dialogo_iniciado):
		Dialogic.timeline_started.connect(_on_dialogo_iniciado)
	if not Dialogic.timeline_ended.is_connected(_on_dialogo_finalizado):
		Dialogic.timeline_ended.connect(_on_dialogo_finalizado)
	if not Dialogic.event_handled.is_connected(_on_evento_dialogic):
		Dialogic.event_handled.connect(_on_evento_dialogic)

	# Prepara as câmeras
	if camera_principal and camera_dialogo:
		camera_principal.current = true
		camera_dialogo.current = false
		camera_dialogo.size = zoom_inicial


# --- FUNÇÕES PÚBLICAS ---
func iniciar_dialogo(nome_timeline: String):
	Dialogic.start(nome_timeline)


# --- CONTROLES DO DIALOGIC ---
func _on_dialogo_iniciado():
	if not camera_dialogo or not camera_principal:
		return
	camera_principal.current = false
	camera_dialogo.current = true
	call_deferred("_iniciar_zoom_ortografico")
	print("Diálogo iniciado.")
	dialogo_iniciou.emit()


func _on_dialogo_finalizado():
	if not camera_dialogo or not camera_principal:
		return
	camera_dialogo.current = false
	camera_principal.current = true
	camera_dialogo.size = zoom_inicial
	print("Diálogo finalizado.")
	dialogo_terminou.emit()


func _on_evento_dialogic(event_resource):
	if "character" in event_resource:
		var character_resource = event_resource.character
		if character_resource:
			var char_name_string = character_resource.display_name
			if char_name_string != "":
				_focar_personagem(char_name_string)


# --- FUNÇÕES DE CÂMERA ---
func _iniciar_zoom_ortografico():
	if not camera_dialogo:
		return
	if zoom_tween and zoom_tween.is_running():
		zoom_tween.kill()
	zoom_tween = create_tween()
	zoom_tween.tween_property(camera_dialogo, "size", zoom_final, zoom_duracao).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _focar_personagem(nome: String):
	if not camera_dialogo: return
	var char_node = get_tree().get_current_scene().get_node_or_null(nome)
	if not (char_node and char_node is Node3D): return

	var pos_alvo = char_node.global_transform.origin + char_node.global_transform.basis * offset_camera
	if foco_tween and foco_tween.is_running():
		foco_tween.kill()
	foco_tween = create_tween()
	foco_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	foco_tween.tween_property(camera_dialogo, "global_position", pos_alvo, velocidade_foco)
	foco_tween.tween_callback(camera_dialogo.look_at.bind(char_node.global_position))
