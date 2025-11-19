extends Node
class_name PlayerController

@export var player_view: PlayerView
@export var light_service: PlayerLightService
@export var state: PlayerState
@export var inventory: PlayerInventory

var _held_node: Node3D = null
var _awaiting_important_start: bool = false
var _important_active: bool = false
var _current_seat: Seat = null
var _is_sitting: bool = false
var _is_initiating_sit: bool = false

const APPROACH_SPEED := 1.0

func _ready() -> void:
	add_to_group("player_controller")
	if get_tree().get_nodes_in_group("player_controller").size() > 1:
		queue_free()
		return

	if not EventBus.item_collected.is_connected(_on_item_collected):
		EventBus.item_collected.connect(_on_item_collected)
	if not EventBus.dialog_started.is_connected(_on_dialog_started):
		EventBus.dialog_started.connect(_on_dialog_started)
	if not EventBus.dialog_ended.is_connected(_on_dialog_ended):
		EventBus.dialog_ended.connect(_on_dialog_ended)

	call_deferred("_bind_dialog_bridge")
	call_deferred("_initial_setup")

func _initial_setup() -> void:
	_sync_dialogic_all_items()
	#_print_inventory_grouped("início do jogo")

func _resolve_player_view() -> bool:
	if is_instance_valid(player_view):
		return true
	player_view = PlayerRegistry.player
	if is_instance_valid(player_view):
		return true
	return false
	
func _bind_dialog_bridge() -> void:
	var bridge := get_tree().get_first_node_in_group("dialog_bridge")
	if bridge:
		if not bridge.dialogic_lock_animation.is_connected(_on_dialogic_lock_animation):
			bridge.dialogic_lock_animation.connect(_on_dialogic_lock_animation)
		if not bridge.dialogic_unlock_animation.is_connected(_on_dialogic_unlock_animation):
			bridge.dialogic_unlock_animation.connect(_on_dialogic_unlock_animation)
	else:
		await get_tree().process_frame
		_bind_dialog_bridge()
	
func _on_dialogic_lock_animation(name: String, duration: float) -> void:
	if not _resolve_player_view():
		return
	_freeze_player_view()
	if player_view.has_method("lock_animation"):
		player_view.lock_animation(name, duration)
	else:
		if "anim_lock_name" in player_view:
			player_view.anim_lock_name = name
		if "anim_lock_time" in player_view:
			player_view.anim_lock_time = duration
		if player_view.anim_sprite:
			var frames := player_view.anim_sprite.sprite_frames
			var final_name := name
			if frames and not frames.has_animation(final_name):
				if frames.has_animation("idle_down"):
					final_name = "idle_down"
				elif frames.has_animation("idle"):
					final_name = "idle"
				else:
					return
			var before := player_view.anim_sprite.animation
			player_view.anim_sprite.stop()
			player_view.anim_sprite.play(final_name)
	if "pode_mover" in player_view:
		player_view.pode_mover = false

func _on_dialogic_unlock_animation() -> void:
	if not _resolve_player_view():
		return
	if player_view.has_method("unlock_animation"):
		player_view.unlock_animation()
	if not _is_sitting:
		await get_tree().process_frame
		_unfreeze_player_view()
		if "pode_mover" in player_view:
			player_view.pode_mover = true

func _on_dialog_started() -> void:
	if _awaiting_important_start:
		_important_active = true
		_awaiting_important_start = false

func _on_dialog_ended() -> void:
	if _held_node != null and is_instance_valid(_held_node):
		_held_node.call_deferred("queue_free")
	_held_node = null
	if light_service:
		light_service.desligar()

func _on_item_collected(_id_item: String, item_node: Node3D) -> void:
	if not _resolve_player_view():
		return

	if item_node == null:
		return

	if item_node is Area3D:
		var a: Area3D = item_node
		a.call_deferred("set_process_input", false)
		a.set_deferred("monitoring", false)
		a.set_deferred("monitorable", false)
	
	var data: ItemData = _extract_item_data(item_node)
	if data != null and inventory != null:
		inventory.add_item(data)
		#_print_inventory_grouped("após coleta")

	if Engine.has_singleton("Dialogic"):
		_sync_dialogic_all_items()

	var is_special: bool = data and (data.tipo == "importante" or data.tipo == "estrela" or data.grants_star)

	if is_special:
		_attach_to_player_deferred(item_node)
		if light_service:
			light_service.ligar()
	else:
		_held_node = null

	await get_tree().create_timer(0.25 if is_special else 0.1).timeout

	if data and (data.grants_star or data.tipo == "estrela"):
		if state:
			state.adicionar_estrela()
		_check_and_trigger_zone_conquest(data)

	if is_special and data:
		_awaiting_important_start = true
		EventBus.emit_important_item_collected(data.nome)
	else:
		if is_instance_valid(item_node):
			item_node.call_deferred("queue_free")
		if light_service:
			light_service.desligar()
			

func _check_and_trigger_zone_conquest(item_data: ItemData) -> void:
	if item_data == null or item_data.tipo != "estrela":
		return

	var star_to_zone_map := {
		"estrela_vermelha": "ZonaVermelha",
		"estrela_azul": "ZonaAzul",
		"estrela_verde": "ZonaVerde",
		"estrela_amarela": "ZonaAmarela"
	}

	if star_to_zone_map.has(item_data.id_item):
		var zone_name_to_conquer = star_to_zone_map[item_data.id_item]
		EventBus.emit_zone_conquered(zone_name_to_conquer)

func _attach_to_player_deferred(node: Node3D) -> void:
	if not _resolve_player_view(): return
	_held_node = node
	var parent: Node = node.get_parent()
	if parent != null:
		parent.call_deferred("remove_child", node)
	if player_view.ponto_item_acima:
		player_view.ponto_item_acima.call_deferred("add_child", node)
	else:
		return
	call_deferred("_after_attach_zero", node)

func _after_attach_zero(node: Node3D) -> void:
	if node != null:
		node.transform = Transform3D.IDENTITY
	if player_view != null:
		player_view.set_held_item(node)

func _extract_item_data(node: Node) -> ItemData:
	if node == null:
		return null
	if node is CollectableArea:
		var ca: CollectableArea = node
		if ca.item_data != null:
			return ca.item_data
	if node.has_meta("item_data"):
		var v: Variant = node.get_meta("item_data")
		if v is ItemData:
			return v
	for child in node.get_children():
		var sub: ItemData = _extract_item_data(child)
		if sub != null:
			return sub
	return null

func _print_inventory_grouped(label: String) -> void:
	if inventory == null:
		return
	var counts := {}
	for it in inventory.itens:
		if it == null: continue
		var id := it.id_item
		if not counts.has(id):
			counts[id] = {"data": it, "qtd": 0}
		counts[id].qtd += 1
	for id in counts.keys():
		var rec = counts[id]
		var nome = (rec.data.nome if rec.data else id)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _is_sitting or _is_initiating_sit:
			if _is_sitting: # Permite levantar se já estiver sentado
				_stand_up()
			return
		var seat := _find_nearby_seat()
		if seat:
			EventBus.interaction_started.emit()
			_is_initiating_sit = true 
			await _sit_on(seat)

func _sit_on(seat: Seat) -> void:
	if not _resolve_player_view():
		_is_initiating_sit = false
		return
	if not seat.try_reserve(player_view):
		_is_initiating_sit = false
		return
	_freeze_player_view()
	await get_tree().process_frame
	var xf := seat.get_sit_transform()
	var target := xf.origin
	var start := player_view.global_position
	var dist := start.distance_to(target)
	var travel_time = max(0.1, dist / APPROACH_SPEED)
	var anim_name := "sitting_down"

	if player_view.anim_sprite and player_view.anim_sprite.sprite_frames.has_animation(anim_name):
		var frames := player_view.anim_sprite.sprite_frames.get_frame_count(anim_name)
		var base_fps := player_view.anim_sprite.sprite_frames.get_animation_speed(anim_name)
		if base_fps <= 0.0:
			base_fps = 10.0
		var base_duration := float(frames) / base_fps
		var scale = base_duration / travel_time
		player_view.anim_sprite.speed_scale = scale
		player_view.anim_sprite.play(anim_name)

	if "look_at" in player_view:
		player_view.look_at(xf.origin + xf.basis.z)

	var tween := get_tree().create_tween()
	tween.tween_property(player_view, "global_position", target, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	player_view.global_position = target

	_is_sitting = true
	_current_seat = seat
	_is_initiating_sit = false

func _stand_up() -> void:
	_is_initiating_sit = true
	if _current_seat:
		_current_seat.release(player_view)
		_current_seat = null
	
	
	if "velocity" in player_view:
		player_view.velocity = Vector3.ZERO
	if player_view.has_method("set_default_idle"):
		player_view.set_default_idle("idle_down")
	else:
		if player_view.anim_sprite:
			player_view.anim_sprite.stop()
			player_view.anim_sprite.play("idle_down")
	if "last_direction" in player_view:
		player_view.last_direction = Vector3.BACK
	if player_view.has_method("lock_animation"):
		player_view.lock_animation("idle_down", 0.25)
	else:
		if player_view.anim_sprite:
			player_view.anim_sprite.play("idle_down")
	if player_view.anim_sprite:
		player_view.anim_sprite.speed_scale = 1.0
	await get_tree().process_frame
	_unfreeze_player_view()
	_is_sitting = false
	_unfreeze_player_view()
	_is_initiating_sit = false
	EventBus.interaction_ended.emit()

func _find_nearby_seat() -> Seat:
	for seat in get_tree().get_nodes_in_group("seats"):
		if seat.can_sit():
			return seat
	return null
	
func _freeze_player_view() -> void:
	if player_view == null: return
	if player_view.has_method("set_physics_process"):
		player_view.set_physics_process(false)
	if player_view.has_method("set_process"):
		player_view.set_process(false)
	if "velocity" in player_view:
		player_view.velocity = Vector3.ZERO
	if "pode_mover" in player_view:
		player_view.pode_mover = false

func _unfreeze_player_view() -> void:
	if player_view == null: return
	if player_view.has_method("set_physics_process"):
		player_view.set_physics_process(true)
	if player_view.has_method("set_process"):
		player_view.set_process(true)
	if "pode_mover" in player_view:
		player_view.pode_mover = true

func _sync_dialogic_all_items() -> void:
	if inventory == null: return
	var counts := {}
	for it in inventory.itens:
		if it == null: continue
		var id := it.id_item
		counts[id] = (counts.get(id, 0) as int) + 1
	for id in counts.keys():
		_set_dialogic_item_vars(id, counts[id])

func _set_dialogic_item_vars(id_item: String, qtd: int) -> void:
	if Engine.has_singleton("Dialogic"):
		var D := Engine.get_singleton("Dialogic")
		if D and "Variables" in D:
			D.Variables.set_variable("has_%s" % id_item, qtd > 0)
			D.Variables.set_variable("count_%s" % id_item, qtd)

func _count_in_inventory(id_item: String) -> int:
	if inventory == null: return 0
	var n := 0
	for it in inventory.itens:
		if it and it.id_item == id_item:
			n += 1
	return n
	
func _inventory_count(id_item: String) -> int:
	var n := 0
	if inventory:
		for it in inventory.itens:
			if it and String(it.id_item) == id_item:
				n += 1
	return n
