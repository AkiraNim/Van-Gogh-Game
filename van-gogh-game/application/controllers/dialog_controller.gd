extends Node
class_name DialogController

enum ModoAtivo { NENHUM, DIALOGO, COLETA }

@export var camera_service: DialogCameraService
@export var dialogic_service: DialogicService

var modo_ativo := ModoAtivo.NENHUM
var falante_atual: Node3D = null

func _ready() -> void:
	dialogic_service.dialogo_iniciou.connect(_on_dialogo_iniciado)
	dialogic_service.dialogo_terminou.connect(_on_dialogo_finalizado)
	dialogic_service.evento_recebido.connect(_on_evento_dialogic)

func iniciar_dialogo(timeline: String) -> void:
	modo_ativo = ModoAtivo.DIALOGO
	dialogic_service.iniciar_dialogo(timeline)

func iniciar_animacao_coleta(alvo: Node3D, timeline: String) -> void:
	modo_ativo = ModoAtivo.COLETA
	camera_service.ativar_camera_dialogo()
	await get_tree().process_frame
	camera_service.focar_personagem(alvo)
	camera_service.iniciar_zoom_in()
	dialogic_service.iniciar_dialogo(timeline)

func _on_dialogo_iniciado() -> void:
	if modo_ativo == ModoAtivo.DIALOGO:
		camera_service.ativar_camera_dialogo()
		camera_service.iniciar_zoom_in()

func _on_dialogo_finalizado() -> void:
	match modo_ativo:
		ModoAtivo.DIALOGO:
			camera_service.iniciar_zoom_out()
		ModoAtivo.COLETA:
			camera_service.iniciar_zoom_out()
	modo_ativo = ModoAtivo.NENHUM

func _on_evento_dialogic(event_resource) -> void:
	if "character" in event_resource:
		var character_resource = event_resource.character
		if character_resource and character_resource.display_name != "":
			var nome = character_resource.display_name
			var char_node = get_tree().get_current_scene().get_node_or_null(nome)
			if char_node:
				camera_service.focar_personagem(char_node)
				falante_atual = char_node

	if "event_name" in event_resource and event_resource.event_name == "signal":
		var valor = event_resource.get("value", "")
		var partes = valor.split(":")
		if partes.size() == 2 and partes[0] == "dropar_item":
			if is_instance_valid(falante_atual) and falante_atual.has_method("dropar_item"):
				falante_atual.dropar_item(partes[1])
