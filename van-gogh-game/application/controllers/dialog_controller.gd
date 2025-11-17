# application/controllers/dialog_controller.gd
extends Node
class_name DialogController

enum ActiveMode { NONE, DIALOG }

@export var camera_service: DialogCameraService
@export var dialogic_service: DialogicService

var active_mode: int = ActiveMode.NONE
var actual_speaker: Node3D = null
var _need_open_camera: bool = false

func _ready() -> void:
	add_to_group("dialog_controller")
	if get_tree().get_nodes_in_group("dialog_controller").size() > 1:
		queue_free()
		return

	if dialogic_service != null:
		if not dialogic_service.dialog_started.is_connected(_on_dialog_started):
			dialogic_service.dialog_started.connect(_on_dialog_started)
		if not dialogic_service.dialog_ended.is_connected(_on_dialog_ended):
			dialogic_service.dialog_ended.connect(_on_dialog_ended)
		if not dialogic_service.event_received.is_connected(_on_event_dialogic):
			dialogic_service.event_received.connect(_on_event_dialogic)
		if not EventBus.important_item_collected.is_connected(_on_important_item):
			EventBus.important_item_collected.connect(_on_important_item)

func _on_dialog_started() -> void:
	active_mode = ActiveMode.DIALOG
	_need_open_camera = true

func _on_dialog_ended() -> void:
	if camera_service != null:
		camera_service.finish_dialog()
	active_mode = ActiveMode.NONE
	actual_speaker = null
	_need_open_camera = false


func _on_event_dialogic(event_resource: Object) -> void:
	if event_resource == null:
		return

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

	if _need_open_camera:
		if camera_service != null:
			camera_service.start_dialog(node3d)
		_need_open_camera = false
		actual_speaker = node3d
		return

	if actual_speaker != node3d:
		actual_speaker = node3d
		if camera_service != null:
			camera_service.focar_personagem(node3d)

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
			pass

func _resolve_active_npc_entity() -> NpcEntity:
	if actual_speaker:
		var ent: Node = actual_speaker.get_node_or_null("NpcEntity")
		if ent and (ent is NpcEntity):
			return ent as NpcEntity
	return null


func _on_important_item(item_name: String) -> void:
	var D = Dialogic
	if Engine.has_singleton("Dialogic"):
		var var_store: Variant = Dialogic.get("VAR")
		if var_store != null and var_store.has_method("set"):
			var_store.set("last_item_name", item_name)
		else:
			if Dialogic.has_method("set_variable"):
				Dialogic.set_variable("last_item_name", item_name)
		if D.has_method("set_variable"):
			D.set_variable("last_item_name", item_name)
		elif D.has_method("get_subsystem"):
			var vars_ss = D.get_subsystem("Variables")
			if vars_ss and vars_ss.has_method("set_variable"):
				vars_ss.set_variable("last_item_name", item_name)
	
	Dialogic.VAR.set("last_item_name", item_name)
	if D.has_method("start"):
		D.start("important_item")
