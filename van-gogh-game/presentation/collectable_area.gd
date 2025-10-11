extends Area3D
class_name CollectableArea

@export var id_item: String = ""
@export var item_data: ItemData
@export var auto_collect: bool = true

var _coletado: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _coletado or not auto_collect:
		return
	if body.is_in_group("player") or body is PlayerView:
		_coletado = true
		var final_id: String = id_item
		if final_id == "" and item_data:
			final_id = item_data.id_item
		if final_id == "":
			final_id = "item"
		EventBus.emit_item_collected(final_id, self)
