# application/controllers/dialog_controller.gd
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
		if not EventBus.important_item_collected.is_connected(_on_important_item):
			EventBus.important_item_collected.connect(_on_important_item)

# -------------------------------------------------
# Início do diálogo — Passo 1
# -------------------------------------------------
func _on_dialogo_iniciado() -> void:
	modo_ativo = ModoAtivo.DIALOGO
	_precisa_abrir_camera = true
	EventBus.emit_dialog_started()

# -------------------------------------------------
# Fim do diálogo — Passo 3 (zoom out)
# -------------------------------------------------
func _on_dialogo_finalizado() -> void:
	if camera_service != null:
		camera_service.finalizar_dialogo()
	modo_ativo = ModoAtivo.NENHUM
	falante_atual = null
	_precisa_abrir_camera = false
	EventBus.emit_dialog_ended()

# -------------------------------------------------
# Evento do Dialogic — Passo 1/2 (foco) + Signal (drop/give)
# -------------------------------------------------
func _on_evento_dialogic(event_resource: Object) -> void:
	if event_resource == null:
		return

	# 2.1) Se for um "Signal" do Dialogic, tratamos aqui (npc_drop:nome / npc_give:nome)
	var event_name: String = ""
	if event_resource.has_method("get"):
		var ev: Variant = event_resource.get("event_name")
		if ev == null:
			ev = event_resource.get("event")
		event_name = str(ev)

	if event_name == "Signal":
		var arg_line: String = ""
		if event_resource.has_method("get"):
			var a: Variant = event_resource.get("argument")
			if a == null:
				a = event_resource.get("arg")
			arg_line = str(a)
		_handle_dialogic_signal(arg_line)
		return

	# 2.2) Pipeline de foco/zoom conforme o repo
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

	var scene: Node = get_tree().get_current_scene()
	if scene == null:
		return

	var node_found: Node = scene.get_node_or_null(actor_name)
	if node_found == null or not (node_found is Node3D):
		return
	var node3d := node_found as Node3D

	# Passo 1: primeiro evento após iniciar o diálogo → zoom e foco
	if _precisa_abrir_camera:
		if camera_service != null:
			camera_service.iniciar_dialogo(node3d)
		_precisa_abrir_camera = false
		falante_atual = node3d
		return

	# Passo 2: troca de foco se falante mudou
	if falante_atual != node3d:
		falante_atual = node3d
		if camera_service != null:
			camera_service.focar_personagem(node3d)

# -------------------------------------------------
# Trata linha "[signal arg=\"...:\"]" do Dialogic
# -------------------------------------------------
func _handle_dialogic_signal(line: String) -> void:
	if line == "":
		return
	var parts := line.split(":")
	if parts.size() < 2:
		return
	var cmd := parts[0]
	var payload := parts[1]

	var ent := _resolve_active_npc_entity()
	if ent == null:
		return

	match cmd:
		"npc_drop":
			ent.drop_item(payload)
		"npc_give":
			ent.give_item_to_player(payload, null)
		_:
			# sinais futuros
			pass

func _resolve_active_npc_entity() -> NpcEntity:
	# Convenção da cena: NpcEntity é filho do nó do falante (NPC_Teste/NpcEntity)
	if falante_atual:
		var ent: Node = falante_atual.get_node_or_null("NpcEntity")
		if ent and (ent is NpcEntity):
			return ent as NpcEntity
	return null

# -------------------------------------------------
# Abre a timeline "important_item" com o nome do item capturado
# -------------------------------------------------
func _on_important_item(item_name: String) -> void:
	var D = Dialogic
	if Engine.has_singleton("Dialogic"):
		var var_store: Variant = Dialogic.get("VAR")  # pega o storage de variáveis
		if var_store != null and var_store.has_method("set"):
			var_store.set("last_item_name", item_name)
		else:
			# fallback para versões antigas
			if Dialogic.has_method("set_variable"):
				Dialogic.set_variable("last_item_name", item_name)
		# Dialogic 2 – duas formas comuns:
		if D.has_method("set_variable"):
			D.set_variable("last_item_name", item_name)
		elif D.has_method("get_subsystem"):
			var vars_ss = D.get_subsystem("Variables")
			if vars_ss and vars_ss.has_method("set_variable"):
				vars_ss.set_variable("last_item_name", item_name)

	# Abrir a timeline 'important_item'
	# (pode ser via EventBus -> NpcController -> Dialogic, ou direto)
	Dialogic.VAR.set("last_item_name", item_name)
	if D.has_method("start"):
		
		D.start("important_item")
