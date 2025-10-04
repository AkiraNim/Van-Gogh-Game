extends Node

@export var camera_principal: Camera3D
@export var camera_dialogo: Camera3D
@export var zoom_inicial: float = 70.0   # FOV inicial
@export var zoom_final: float = 40.0     # FOV quando em zoom máximo
@export var zoom_duracao: float = 1.2    # duração da animação de zoom

# Armazena o Tween atual
var zoom_tween: Tween

func _ready():
# Conectar aos sinais globais do Dialogic
	Dialogic.timeline_started.connect(_on_dialogo_iniciado)
	Dialogic.timeline_ended.connect(_on_dialogo_finalizado)
	Dialogic.signal_event.connect(_on_evento_dialogic) 
# "signal_event" é chamado em cada step da timeline

# Garantir estado inicial
	camera_principal.current = true
	camera_dialogo.current = false
	camera_dialogo.fov = zoom_inicial


func _on_dialogo_iniciado(dialog_node):
# Alterna para a câmera de diálogo
	camera_principal.current = false
	camera_dialogo.current = true

# Faz o zoom-in
	if zoom_tween and zoom_tween.is_running():
		zoom_tween.kill()

	zoom_tween = create_tween()
	zoom_tween.tween_property(
	camera_dialogo, "fov", zoom_final, zoom_duracao
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_dialogo_finalizado(dialog_node):
# Volta para a câmera principal
	camera_dialogo.current = false
	camera_principal.current = true
	camera_dialogo.fov = zoom_inicial


func _on_evento_dialogic(event: Dictionary):
# O evento "text" contém os dados da fala
	if event.has("type") and event.type == "text":
		var char_name = event.get("character", "")
		if char_name != "":
			_focar_personagem(char_name)


func _focar_personagem(nome: String):
# Busca na cena o personagem com esse nome
	var char_node = get_tree().get_current_scene().get_node_or_null(nome)
	if char_node and char_node is Node3D:
# Faz a câmera de diálogo olhar para o personagem
		camera_dialogo.look_at(char_node.global_transform.origin, Vector3.UP)
