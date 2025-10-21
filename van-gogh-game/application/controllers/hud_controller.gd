extends Control
class_name HUDController

@export var stars_box: HBoxContainer
@export var important_items_box: HBoxContainer
@export var star_icon: Texture2D
@export var inventory: PlayerInventory
@export var item_repository: ItemRepository
@export var max_star_icons: int = 20

# opcional: filtrar quais itens contam como "importantes" (além de tipo == "importante")
var _extra_important_ids := {
	"chave_boss": true,
}

func _ready() -> void:
	if not stars_box or not important_items_box:
		push_warning("HUDController: arraste StarsBox e ImportantItemsBox no Inspector.")
		return

	# sinais que você já tem no EventBus
	if not EventBus.star_count_changed.is_connected(_on_star_count_changed):
		EventBus.star_count_changed.connect(_on_star_count_changed)
	if not EventBus.inventory_item_added.is_connected(_on_inventory_change):
		EventBus.inventory_item_added.connect(_on_inventory_change)
	if not EventBus.inventory_item_removed.is_connected(_on_inventory_change):
		EventBus.inventory_item_removed.connect(_on_inventory_change)
	if not EventBus.inventory_updated.is_connected(_on_inventory_change):
		EventBus.inventory_updated.connect(_on_inventory_change)

	# primeiro desenho
	_redraw_stars(_get_star_count_from_inventory_or_var())
	_redraw_important_items()

func _on_star_count_changed(count: int) -> void:
	_redraw_stars(count)

func _on_inventory_change(_id := "", _opt = null) -> void:
	# atualiza ambos; barato o suficiente p/ HUD
	_redraw_stars(_get_star_count_from_inventory_or_var())
	_redraw_important_items()

func _get_star_count_from_inventory_or_var() -> int:
	# preferir PlayerInventory, caindo pra Dialogic VAR se quiser
	if inventory:
		var n := 0
		for it in inventory.itens:
			if it and (it.tipo == "estrela" or it.grants_star):
				n += 1
		return n
	# fallback: se você mantiver VAR no Dialogic
	if Engine.has_singleton("Dialogic"):
		var D := Engine.get_singleton("Dialogic")
		if D and D.has_subsystem("VAR"):
			var v = D.VAR.get_variable("count_estrela_vermelha")
			return int(v) if v != null else 0
	return 0

func _redraw_stars(count: int) -> void:
	if not stars_box:
		return
	for c in stars_box.get_children():
		c.queue_free()

	count = clamp(count, 0, max_star_icons)
	for i in count:
		var t := TextureRect.new()
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_min_size = Vector2(24, 24)
		t.texture = star_icon
		stars_box.add_child(t)

func _redraw_important_items() -> void:
	if not important_items_box:
		return
	for c in important_items_box.get_children():
		c.queue_free()

	if not inventory:
		return

	# cria um set por id para não repetir ícone do mesmo item importante
	var printed := {}
	for it in inventory.itens:
		if it == null:
			continue
		if _is_important_item(it):
			if printed.has(it.id_item):
				continue
			printed[it.id_item] = true
			var icon := _resolve_icon(it)
			if icon:
				var tr := TextureRect.new()
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.custom_min_size = Vector2(24, 24)
				tr.texture = icon
				important_items_box.add_child(tr)

func _is_important_item(it: ItemData) -> bool:
	if it.tipo == "importante":
		return true
	# se quiser tratar estrelas especiais como importantes, mantenha:
	# if it.tipo == "estrela": return true
	# ids extras marcados manualmente:
	if _extra_important_ids.has(it.id_item):
		return true
	return false

func _resolve_icon(it: ItemData) -> Texture2D:
	if it.icone:
		return it.icone
	if item_repository:
		var data := item_repository.get_item_data(it.id_item)
		if data and data.icone:
			return data.icone
	return null
