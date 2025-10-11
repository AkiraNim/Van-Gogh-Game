extends Node
class_name NpcController

@export var npc_entity_path: NodePath
var _npc_entity: NpcEntity

# debounce para evitar duplo start do Dialogic
var _last_start_time := 0.0
const START_COOLDOWN := 0.12 # seg

func _ready() -> void:
	_npc_entity = get_node_or_null(npc_entity_path)
	if not _npc_entity:
		push_warning("NpcController: entidade não encontrada.")
		return

	if has_node("/root/EventBus"):
		var eb := get_node("/root/EventBus")
		if not eb.npc_dialog_triggered.is_connected(_on_dialog_triggered):
			eb.npc_dialog_triggered.connect(_on_dialog_triggered)
	else:
		push_warning("NpcController: EventBus não encontrado.")

	print("🎭 NpcController pronto para NPC:", _npc_entity.name)

func _on_dialog_triggered(npc_name: String, timeline: String) -> void:
	if not _npc_entity or npc_name != _npc_entity.name:
		return

	var now := Time.get_ticks_msec() / 1000.0
	if (now - _last_start_time) < START_COOLDOWN:
		print("⏳ Ignorando start duplicado (cooldown).")
		return
	_last_start_time = now

	var D := _get_dialogic()
	if D == null:
		push_warning("NpcController: Dialogic autoload não encontrado.")
		return
	if not D.has_method("start_timeline"):
		push_warning("NpcController: Dialogic não expõe start_timeline().")
		return

	var styles_ok = (("has_subsystem" in D) and D.has_method("has_subsystem") and D.has_subsystem("Styles"))
	var has_layout := false
	var Styles = null

	if styles_ok:
		Styles = D.get_subsystem("Styles")
		if Styles and Styles.has_method("has_active_layout_node") and Styles.has_method("get_layout_node"):
			var ln = Styles.get_layout_node() if Styles.has_active_layout_node() else null
			has_layout = is_instance_valid(ln) and ln.is_inside_tree()

	print("🎬 Iniciando diálogo '%s' para NPC: %s" % [timeline, npc_name])

	if has_layout:
		# Já existe layout na árvore → iniciar timeline direto
		D.start_timeline(timeline)
		return

	# Sem layout: carregue manualmente e só então inicie a timeline.
	if styles_ok and Styles and Styles.has_method("load_style"):
		var layout: Node = Styles.load_style()
		if layout and not layout.is_node_ready():
			# CONECTA AO SEU PRÓPRIO MÉTODO (one-shot), não ao método do Dialogic:
			if not layout.is_connected("ready", Callable(self, "_start_timeline_after_layout_ready")):
				layout.ready.connect(Callable(self, "_start_timeline_after_layout_ready").bind(timeline), CONNECT_ONE_SHOT)
		else:
			D.start_timeline(timeline)
	else:
		# Fallback: sem Styles, ainda é seguro iniciar direto
		D.start_timeline(timeline)

# Chamado quando o layout acabou de dar ready.
func _start_timeline_after_layout_ready(timeline: String) -> void:
	var D := _get_dialogic()
	if D and D.has_method("start_timeline"):
		D.start_timeline(timeline)

func drop_item(item_id: String) -> void:
	if _npc_entity:
		_npc_entity.drop_item(item_id)

func give_item_to_player(item_id: String) -> void:
	if not _npc_entity:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and player is PlayerView:
		_npc_entity.give_item_to_player(item_id, player)

func _get_dialogic() -> Object:
	if Engine.has_singleton("Dialogic"):
		return Engine.get_singleton("Dialogic")
	if has_node("/root/Dialogic"):
		return get_node("/root/Dialogic")
	return null
