extends Node
class_name DialogController

enum ModoAtivo { NENHUM, DIALOGO }

@export var camera_service: DialogCameraService
@export var dialogic_service: DialogicService

var modo_ativo: int = ModoAtivo.NENHUM
var falante_atual: Node3D = null
var _precisa_abrir_camera: bool = false

func _ready() -> void:
	if dialogic_service != null:
		if not dialogic_service.dialogo_iniciou.is_connected(_on_dialogo_iniciado):
			dialogic_service.dialogo_iniciou.connect(_on_dialogo_iniciado)
		if not dialogic_service.dialogo_terminou.is_connected(_on_dialogo_finalizado):
			dialogic_service.dialogo_terminou.connect(_on_dialogo_finalizado)
		if not dialogic_service.evento_recebido.is_connected(_on_evento_dialogic):
			dialogic_service.evento_recebido.connect(_on_evento_dialogic)


# -------------------------------------------------
# Início do diálogo — arma o gatilho do Passo 1
# -------------------------------------------------
func _on_dialogo_iniciado() -> void:
	modo_ativo = ModoAtivo.DIALOGO
	_precisa_abrir_camera = true


# -------------------------------------------------
# Fim do diálogo — Passo 3 (zoom out)
# -------------------------------------------------
func _on_dialogo_finalizado() -> void:
	if camera_service != null:
		camera_service.finalizar_dialogo()
	modo_ativo = ModoAtivo.NENHUM
	falante_atual = null
	_precisa_abrir_camera = false


# -------------------------------------------------
# Evento do Dialogic — Passo 1 (primeiro falante) e Passo 2 (troca de falante)
# -------------------------------------------------
func _on_evento_dialogic(event_resource: Object) -> void:
	if event_resource == null:
		return

	# Tenta obter o "character" do recurso de evento de forma segura
	var char_res: Object = null
	if event_resource.has_method("get"):
		var tmp_char: Variant = event_resource.get("character")
		if tmp_char != null and tmp_char is Object:
			char_res = tmp_char

	var actor_name: String = ""
	if char_res != null and char_res.has_method("get"):
		var dn: Variant = char_res.get("display_name")
		if dn != null:
			actor_name = str(dn)

	if actor_name == "":
		return

	# Resolve o nó do ator na cena atual
	var scene: Node = get_tree().get_current_scene()
	if scene == null:
		return

	var node_found: Node = scene.get_node_or_null(actor_name)
	if node_found == null or not (node_found is Node3D):
		return
	var node3d: Node3D = node_found as Node3D

	# Passo 1: no primeiro evento válido após iniciar o diálogo, abrir com zoom e foco
	if _precisa_abrir_camera:
		if camera_service != null:
			camera_service.iniciar_dialogo(node3d)
		_precisa_abrir_camera = false
		falante_atual = node3d
		return

	# Passo 2: durante o diálogo, só refoca se o falante mudou
	if falante_atual != node3d:
		falante_atual = node3d
		if camera_service != null:
			camera_service.focar_personagem(node3d)
