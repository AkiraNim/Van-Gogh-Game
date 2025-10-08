extends Node3D

signal dialogo_iniciou
signal dialogo_terminou
signal animacao_coleta_terminou

enum ModoAtivo { NENHUM, DIALOGO, COLETA }
var modo_ativo = ModoAtivo.NENHUM

@export_group("Dialogic")
@export var camera_principal: Camera3D
@export var camera_dialogo: Camera3D
@export var zoom_inicial: float = 10.0
@export var zoom_final: float = 5.0
@export var zoom_duracao: float = 1.2
@export var offset_camera: Vector3 = Vector3(0, 1.6, 2.8)
@export var velocidade_foco: float = 0.6

var zoom_tween: Tween
var foco_tween: Tween
var falante_atual: Node3D = null

func _ready():
	if not Dialogic.timeline_started.is_connected(_on_dialogo_iniciado):
		Dialogic.timeline_started.connect(_on_dialogo_iniciado)
	if not Dialogic.timeline_ended.is_connected(_on_dialogo_finalizado):
		Dialogic.timeline_ended.connect(_on_dialogo_finalizado)
	if not Dialogic.event_handled.is_connected(_on_evento_dialogic):
		Dialogic.event_handled.connect(_on_evento_dialogic)

	if camera_principal and camera_dialogo:
		camera_principal.current = true
		camera_dialogo.current = false
		camera_dialogo.size = zoom_inicial

func iniciar_dialogo(nome_timeline: String):
	modo_ativo = ModoAtivo.DIALOGO
	Dialogic.start(nome_timeline)

func iniciar_animacao_de_coleta(node_alvo, nome_timeline: String):
	if not camera_dialogo or not camera_principal: return
	modo_ativo = ModoAtivo.COLETA
	dialogo_iniciou.emit()
	camera_principal.current = false
	camera_dialogo.current = true
	await get_tree().process_frame
	_focar_personagem(node_alvo.name)
	call_deferred("_iniciar_zoom_ortografico")
	Dialogic.start(nome_timeline)

func _on_dialogo_iniciado():
	if modo_ativo == ModoAtivo.DIALOGO:
		if not camera_dialogo or not camera_principal: return
		camera_principal.current = false
		camera_dialogo.current = true
		call_deferred("_iniciar_zoom_ortografico")
		dialogo_iniciou.emit()

func _on_dialogo_finalizado():
	match modo_ativo:
		ModoAtivo.DIALOGO:
			var tween = create_tween()
			tween.tween_property(camera_dialogo, "size", zoom_inicial, zoom_duracao)
			tween.finished.connect(func():
				if camera_dialogo: camera_dialogo.current = false
				if camera_principal: camera_principal.current = true
				dialogo_terminou.emit()
			)
		ModoAtivo.COLETA:
			animacao_coleta_terminou.emit()
			var tween = create_tween()
			tween.tween_property(camera_dialogo, "size", zoom_inicial, zoom_duracao)
			tween.finished.connect(func():
				if camera_dialogo: camera_dialogo.current = false
				if camera_principal: camera_principal.current = true
				dialogo_terminou.emit()
			)
	modo_ativo = ModoAtivo.NENHUM

func _on_evento_dialogic(event_resource):
	if "character" in event_resource:
		var character_resource = event_resource.character
		if character_resource:
			var char_name_string = character_resource.display_name
			if char_name_string != "":
				_focar_personagem(char_name_string)
				falante_atual = get_tree().get_current_scene().get_node_or_null(char_name_string)
	
	# CORREÇÃO: Trocado 'event_resource.has("event_name")' por '"event_name" in event_resource'
	if "event_name" in event_resource and event_resource.event_name == "signal":
		var valor_sinal = event_resource.get("value", "")
		var partes = valor_sinal.split(":")
		if partes.size() == 2 and partes[0] == "dropar_item":
			var id_do_item = partes[1]
			if is_instance_valid(falante_atual) and falante_atual.has_method("dropar_item"):
				falante_atual.dropar_item(id_do_item)

func _iniciar_zoom_ortografico():
	if not camera_dialogo: return
	if zoom_tween and zoom_tween.is_running(): zoom_tween.kill()
	zoom_tween = create_tween()
	zoom_tween.tween_property(camera_dialogo, "size", zoom_final, zoom_duracao).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _focar_personagem(nome: String):
	if not camera_dialogo: return
	var char_node = get_tree().get_current_scene().get_node_or_null(nome)
	if not (char_node and char_node is Node3D): return
	var pos_alvo = char_node.global_transform.origin + char_node.global_transform.basis * offset_camera
	if foco_tween and foco_tween.is_running(): foco_tween.kill()
	foco_tween = create_tween()
	foco_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	foco_tween.tween_property(camera_dialogo, "global_position", pos_alvo, velocidade_foco)
	foco_tween.tween_callback(camera_dialogo.look_at.bind(char_node.global_position))
