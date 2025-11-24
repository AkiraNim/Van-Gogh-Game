extends Node3D
class_name NpcEntity

@export var inventory: NpcInventory
@export var drop_point: Marker3D
@export var nome_npc: String


@export var timelines: Array[String] = []
var _current_timeline_index: int = 0

var _player_na_area := false

func _ready() -> void:
	add_to_group("npcs")
	var area := $"../Interacao"
	if area and not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)
	if area and not area.body_exited.is_connected(_on_body_exited):
		area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_na_area = true
		EventBus.player_entered_interactable_area.emit(self)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_na_area = false
		EventBus.player_exited_interactable_area.emit(self)

func _unhandled_input(e: InputEvent) -> void:
	if _player_na_area and e.is_action_pressed("interact"):
		trigger_dialog()

func trigger_dialog() -> void:
	if timelines.is_empty():
		return
	var timeline_to_play := timelines[_current_timeline_index]
	EventBus.interaction_started.emit()
	EventBus.npc_dialog_triggered.emit(name, timeline_to_play)

func avancar_timeline() -> void:
	if _current_timeline_index < timelines.size() - 1:
		_current_timeline_index += 1
	else:
		return
func drop_item(id_item: String) -> void:
	if inventory == null:
		return
	var data := inventory.remove_item(id_item)
	if data == null:
		return

	var node := data.instantiate_node()
	if node == null:
		return

	_config_as_collectable(node, data)
	_colocar_no_cenario(node)
	if "npc_dropped_item" in EventBus:
		EventBus.npc_dropped_item.emit(nome_npc, id_item)

func give_item_to_player(id_item: String, _player: PlayerView) -> void:
	if inventory == null:
		return
	var data := inventory.remove_item(id_item)
	if data == null:
		return
	var node := data.instantiate_node()
	if node == null:
		return

	_config_as_collectable(node, data)
	EventBus.emit_item_collected(data.id_item, node)

func _config_as_collectable(node: Node3D, data: ItemData) -> void:
	var area: Area3D = null
	if node is Area3D:
		area = node
	else:
		for c in node.get_children():
			if c is Area3D:
				area = c
				break
	if area:
		if "item_data" in area:
			area.item_data = data
		else:
			area.set_meta("item_data", data)
		area.monitoring = true
		area.monitorable = true
		if not area.is_in_group("collectable"):
			area.add_to_group("collectable")
	else:
		node.set_meta("item_data", data)

func _colocar_no_cenario(node: Node3D) -> void:
	var root := get_tree().get_current_scene()
	if root:
		root.add_child(node)
	else:
		add_child(node)
	if drop_point:
		node.global_transform = drop_point.global_transform
	else:
		node.global_transform = global_transform

func _instance_item_node(data: ItemData) -> Node3D:
	if data.cena_do_item:
		var n := data.cena_do_item.instantiate()
		return n as Node3D
	return null
