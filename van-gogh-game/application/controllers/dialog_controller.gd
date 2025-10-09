extends Node
class_name DialogController

enum ModoAtivo { NENHUM, DIALOGO, COLETA }

@export var dialogic_service: DialogicService
@export var camera_service: DialogCameraService

var modo_ativo: int = ModoAtivo.NENHUM
var falante_atual: Node3D = null

func _ready() -> void:
	dialogic_service.dialogo_iniciou.connect(_on_dialogo_iniciado)
	dialogic_service.dialogo_terminou.connect(_on_dialogo_finalizado)
	dialogic_service.evento_recebido.connect(_on_evento_dialogic)

func iniciar_dialogo(timeline: String) -> void:
	modo_ativo = ModoAtivo.DIALOGO
	if camera_service:
		camera_service.ativar_camera_dialogo()
		camera_service.iniciar_zoom_in()
	await get_tree().process_frame
	dialogic_service.iniciar_dialogo(timeline)

func _on_dialogo_iniciado() -> void:
	modo_ativo = ModoAtivo.DIALOGO

func _on_dialogo_finalizado() -> void:
	if camera_service:
		camera_service.iniciar_zoom_out()
		await camera_service.zoom_out_finished
		camera_service.desativar_camera_dialogo()
	modo_ativo = ModoAtivo.NENHUM

func _on_evento_dialogic(event_resource) -> void:
	if event_resource == null:
		return

	# Foco no personagem que fala (via display_name do Dialogic)
	if "character" in event_resource:
		var char_res = event_resource.character
		if char_res and char_res.display_name != "":
			var nome: String = char_res.display_name
			var alvo: Node3D = get_tree().get_current_scene().get_node_or_null(nome)

			# Se não existir nó com esse nome, procura por export "nome_npc" em nós da cena
			if alvo == null:
				var root := get_tree().get_current_scene()
				for child in root.get_children():
					if child is Node:
						var props = child.get_property_list()
						for p in props:
							if p.name == "nome_npc" and child.get(p.name) == nome:
								if child is Node3D:
									alvo = child
								break
					if alvo:
						break

			if alvo and camera_service:
				camera_service.focar_personagem(alvo)
				falante_atual = alvo

	# Eventos do tipo "signal"
	if "event_name" in event_resource and event_resource.event_name == "signal":
		var valor: String = event_resource.get("value", "")
		var partes := valor.split(":")
		if partes.size() == 2 and partes[0] == "dropar_item":
			if is_instance_valid(falante_atual) and falante_atual.has_method("dropar_item"):
				falante_atual.dropar_item(partes[1])
