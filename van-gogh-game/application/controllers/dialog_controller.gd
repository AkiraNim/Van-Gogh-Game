# res://application/controllers/dialog_controller.gd
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

# --- início do diálogo
func _on_dialogo_iniciado() -> void:
	modo_ativo = ModoAtivo.DIALOGO
	_precisa_abrir_camera = true
	print("🎬 Diálogo iniciado - emitindo EventBus")
	EventBus.emit_dialog_started()

# --- final do diálogo
func _on_dialogo_finalizado() -> void:
	if camera_service != null:
		camera_service.finalizar_dialogo()
	modo_ativo = ModoAtivo.NENHUM
	falante_atual = null
	_precisa_abrir_camera = false
	print("🏁 Diálogo finalizado - emitindo EventBus")
	EventBus.emit_dialog_ended()

# --- eventos por passo do Dialogic (troca de foco + sinais custom)
func _on_evento_dialogic(event_resource: Object) -> void:
	if event_resource == null:
		return

	# 1) Foco de câmera baseado no "character" do evento
	var actor_name := ""
	if event_resource.has_method("get"):
		var char_res: Object = event_resource.get("character")
		if char_res != null and char_res.has_method("get"):
			var dn = char_res.get("display_name")
			if dn != null:
				actor_name = str(dn)

	if actor_name != "":
		var scene := get_tree().get_current_scene()
		var node_found := scene.get_node_or_null(actor_name)
		if node_found and (node_found is Node3D):
			var node3d := node_found as Node3D
			if _precisa_abrir_camera:
				if camera_service != null:
					camera_service.iniciar_dialogo(node3d)
				_precisa_abrir_camera = false
				falante_atual = node3d
			elif falante_atual != node3d:
				falante_atual = node3d
				if camera_service != null:
					camera_service.focar_personagem(node3d)

	# 2) Tenta processar "EventSignal" do Dialogic (npc_drop / npc_give)
	#    Para garantir robustez, lemos campos por 'get' com fallback.
	var ev_kind := ""
	var sig_name := ""
	var sig_arg0 := ""

	if event_resource.has_method("get"):
		ev_kind = str(event_resource.get("event_name") if event_resource.get("event_name") != null else "")
		# Em algumas versões de Dialogic, os campos variam:
		sig_name = str(event_resource.get("signal") if event_resource.get("signal") != null else event_resource.get("name") if event_resource.get("name") != null else "")
		var arg0 = event_resource.get("argument0")
		if arg0 == null: arg0 = event_resource.get("argument_string")
		if arg0 == null and event_resource.get("arguments"):  # array
			var arr = event_resource.get("arguments")
			if arr.size() > 0:
				arg0 = arr[0]
		if arg0 != null:
			sig_arg0 = str(arg0)

	# Só reage se for um "signal event"
	if ev_kind.to_lower() == "signal" and sig_name != "":
		match sig_name:
			"npc_drop":
				# se falante atual é o NPC, pedimos para ele dropar
				var npc := (falante_atual as Node3D)
				if npc:
					var ent: NpcEntity = npc.get_node_or_null("NpcEntity")
					if ent:
						ent.drop_item(sig_arg0)
			"npc_give":
				var npc2 := (falante_atual as Node3D)
				if npc2:
					var ent2: NpcEntity = npc2.get_node_or_null("NpcEntity")
					if ent2:
						# tenta entregar ao último player detectado
						ent2.give_item_to_player(sig_arg0, null)
			_:
				pass
