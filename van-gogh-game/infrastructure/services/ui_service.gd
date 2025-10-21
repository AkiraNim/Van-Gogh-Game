extends Node
class_name UIService

# --- UI Roots / Containers ---
@export var hud_root: Control
@export var stars_container: Container
@export var important_container: Container

@export var pause_menu_root: Control
@export var pause_label: Label
@export var pause_btn_resume: Button
@export var pause_btn_quit: Button
@export var quest_menu_root: Control
@export var active_quests_container: ItemList
@export var completed_quests_container: ItemList

# --- Data sources ---
@export var item_repository: ItemRepository
@export var player_inventory: PlayerInventory
@export var player_state: PlayerState
@export var quest_service: Node    # QuestManager/QuestService/Bridge/etc

# --- Input ---
@export var toggle_action: StringName = "toggle"
@export var pause_action: StringName = "pause"

# --- Visual ---
@export var icon_size: Vector2 = Vector2(32, 32)
@export var show_count_badge: bool = true
@export var interaction_prompt_scene: PackedScene
			  # 0 = ativas, 1 = concluídas
@onready var game_manager = get_node("/root/GameManager")


var _interaction_prompt_instance: Control
var _current_interactable: Node3D = null

func _ready() -> void:
	if interaction_prompt_scene:
		_interaction_prompt_instance = interaction_prompt_scene.instantiate()
		add_child(_interaction_prompt_instance)
		_interaction_prompt_instance.visible = false
	else:
		push_warning("A cena do aviso de interação não foi definida no UIService.")
		set_process(false)
		return

	# Conecta-se aos sinais de área
	EventBus.player_entered_interactable_area.connect(_on_player_entered_interactable_area)
	EventBus.player_exited_interactable_area.connect(_on_player_exited_interactable_area)
	
	# --- NOVO: Conecta-se aos sinais de estado da interação ---
	EventBus.interaction_started.connect(_on_interaction_started)
	EventBus.interaction_ended.connect(_on_interaction_ended)
	
	set_process(false)
	
	_rebind_services()
	_connect_signals()
	call_deferred("_rebind_services")
	if not get_tree().is_connected("node_added", Callable(self, "_on_node_added")):
		get_tree().connect("node_added", Callable(self, "_on_node_added"))
	_autowire_quest_menu()
	if quest_menu_root:
		quest_menu_root.visible = false

	_autowire_pause_menu()
	_hide_pause_menu()

func _process(_delta: float) -> void:
	if not is_instance_valid(_current_interactable):
		if is_instance_valid(_interaction_prompt_instance):
			_interaction_prompt_instance.visible = false
		set_process(false)
		return

	var camera = get_viewport().get_camera_3d()
	if not camera: return

	var world_position_3d = _current_interactable.global_position + Vector3.UP * 0.5
	var screen_position_2d = camera.unproject_position(world_position_3d)

	var prompt_size = _interaction_prompt_instance.size
	_interaction_prompt_instance.position = screen_position_2d - (prompt_size / 2)

func _on_interaction_started() -> void:
	# Esconde o letreiro e para de o atualizar
	if is_instance_valid(_interaction_prompt_instance):
		_interaction_prompt_instance.visible = false
	set_process(false)

func _on_interaction_ended() -> void:
	# Reavalia se o letreiro deve ser mostrado novamente.
	# Isto acontece se o jogador ainda estiver na área do objeto.
	if is_instance_valid(_current_interactable):
		if is_instance_valid(_interaction_prompt_instance):
			_interaction_prompt_instance.visible = true
		set_process(true)

func _on_player_entered_interactable_area(interactable_node: Node3D) -> void:
	_current_interactable = interactable_node
	if is_instance_valid(_interaction_prompt_instance):
		_interaction_prompt_instance.visible = true
		set_process(true)

func _on_player_exited_interactable_area(interactable_node: Node3D) -> void:
	if _current_interactable == interactable_node:
		_current_interactable = null
		if is_instance_valid(_interaction_prompt_instance):
			_interaction_prompt_instance.visible = false
		set_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_rebind_services()

func _input(event: InputEvent) -> void:
	# Pause tem prioridade (se as ações estiverem na mesma tecla, só o pause roda)
	if event.is_action_pressed(pause_action):
		if _is_paused():
			_unpause_game()
		else:
			_pause_game()
		get_viewport().set_input_as_handled()
		return

	# Toggle do QuestMenu só funciona quando NÃO está pausado
	if event.is_action_pressed(toggle_action) and quest_menu_root and not _is_paused():
		quest_menu_root.visible = not quest_menu_root.visible
		if quest_menu_root.visible:
			_refresh_quest_menu()
		get_viewport().set_input_as_handled()

func _rebind_services() -> void:
	if item_repository == null:
		var n: Node = _find_first_of_type_name("ItemRepository")
		if n:
			item_repository = n as ItemRepository

	if player_inventory == null:
		var pc: Node = _find_first_in_group("player_controller")
		if pc and "inventory" in pc:
			player_inventory = pc.inventory

	if player_state == null:
		var pc2: Node = _find_first_in_group("player_controller")
		if pc2 and "state" in pc2 and (pc2.state is PlayerState):
			player_state = pc2.state
		else:
			var gm: Node = _find_first_named("GameManager")
			if gm and "state" in gm and (gm.state is PlayerState):
				player_state = gm.state

	if quest_service == null and Engine.has_singleton("QuestManager"):
		quest_service = Engine.get_singleton("QuestManager")
	if quest_service == null and Engine.has_singleton("QuestService"):
		quest_service = Engine.get_singleton("QuestService")
	if quest_service == null:
		var in_group: Array = get_tree().get_nodes_in_group("quest_service")
		if in_group.size() > 0:
			quest_service = in_group[0]
	if quest_service == null:
		quest_service = _find_quest_service_in_tree(get_tree().get_root())

	if quest_service != null:
		_connect_quest_signals()
		print("UIService: conectado a ", str(quest_service))

	_autowire_quest_menu()

func _connect_signals() -> void:
	if has_node("/root/EventBus"):
		var eb: Node = get_node("/root/EventBus")
		_safe_connect(eb, "star_count_changed", Callable(self, "_on_star_count_changed"))
		_safe_connect(eb, "inventory_item_added", Callable(self, "_on_inventory_changed"))
		_safe_connect(eb, "inventory_item_removed", Callable(self, "_on_inventory_changed"))
		_safe_connect(eb, "inventory_updated", Callable(self, "_on_inventory_changed"))
		_safe_connect(eb, "game_loaded", Callable(self, "_on_scene_or_save_changed"))
		_safe_connect(eb, "game_reset", Callable(self, "_on_scene_or_save_changed"))
		_safe_connect(eb, "scene_changed", Callable(self, "_on_scene_or_save_changed"))

func _safe_connect(target: Object, signal_name: StringName, callable: Callable) -> void:
	if target and target.has_signal(signal_name) and not target.is_connected(signal_name, callable):
		target.connect(signal_name, callable)

# -----------------------------------------------------------------
# Refresh
# -----------------------------------------------------------------
func _full_refresh() -> void:
	_refresh_hud()
	_refresh_quest_menu()

func _refresh_hud() -> void:
	_refresh_star_icons()
	_refresh_important_icons()

func _refresh_star_icons() -> void:
	if stars_container == null:
		return
	_clear_children(stars_container)
	var counts: Dictionary = _inventory_counts()
	for id in counts.keys():
		var rec: Dictionary = counts[id]
		var data: ItemData = rec.get("data", null)
		var qty: int = int(rec.get("qtd", 0))
		if data == null or qty <= 0:
			continue
		if data.tipo == "estrela" or data.grants_star:
			_add_icon(stars_container, data, qty)

func _refresh_important_icons() -> void:
	if important_container == null:
		return
	_clear_children(important_container)
	var counts: Dictionary = _inventory_counts()
	for id in counts.keys():
		var rec: Dictionary = counts[id]
		var data: ItemData = rec.get("data", null)
		var qty: int = int(rec.get("qtd", 0))
		if data == null or qty <= 0:
			continue
		if data.tipo == "importante":
			_add_icon(important_container, data, qty)

func _refresh_quest_menu() -> void:
	if quest_menu_root == null:
		print("UIService: quest_menu_root não setado — nada a exibir.")
		return

	_autowire_quest_menu()
	_ensure_menu_layout()

	# Agora são ItemList
	if active_quests_container and active_quests_container is ItemList:
		(active_quests_container as ItemList).clear()
	if completed_quests_container and completed_quests_container is ItemList:
		(completed_quests_container as ItemList).clear()

	var qdata: Dictionary = _collect_quests()
	var act: Dictionary = _as_dict(qdata.get("active", {}))
	var done: Dictionary = _as_dict(qdata.get("done", {}))

	for qid in act.keys():
		var q: Dictionary = _as_dict(act[qid])
		var fallback_title: String = String(q.get("title", qid))
		var title: String = _get_dialogic_title(String(qid), fallback_title)
		_add_quest_line(active_quests_container, title, false)

	for qid in done.keys():
		var title := _get_dialogic_title(String(qid), String(qid))
		_add_quest_line(completed_quests_container, title, true)

	# Seleciona o primeiro por padrão (opcional)
	if active_quests_container and active_quests_container is ItemList:
		var al := active_quests_container as ItemList
		if al.item_count > 0:
			al.select(0)
			al.grab_focus()

# -----------------------------------------------------------------
# Dialogic helpers (título)
# -----------------------------------------------------------------
func _get_dialogic_title(qid: String, fallback: String) -> String:
	var key := "quest/%s/title" % qid
	if Engine.has_singleton("Dialogic"):
		var D = Engine.get_singleton("Dialogic")
		if D and D.has_subsystem and D.has_subsystem("VAR"):
			var v = D.VAR.get_variable(key)
			if v != null and str(v) != "":
				return str(v)
		if "Variables" in Dialogic:
			var vv = Dialogic.Variables.get_variable(key)
			if vv != null and str(vv) != "":
				return str(vv)
	return fallback

# -----------------------------------------------------------------
# Builders
# -----------------------------------------------------------------
func _add_icon(parent: Node, data: ItemData, qty: int) -> void:
	if parent == null or data == null:
		return
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(box)

	var tex := TextureRect.new()
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.custom_minimum_size = icon_size
	tex.texture = data.icone
	tex.tooltip_text = data.nome if data.nome != "" else data.id_item
	box.add_child(tex)

	if data.icone == null:
		var ph := ColorRect.new()
		ph.color = Color(0.15, 0.15, 0.15)
		ph.custom_minimum_size = icon_size
		ph.tooltip_text = tex.tooltip_text
		box.add_child(ph)

	if show_count_badge and qty > 1:
		var badge := Label.new()
		badge.text = "x%d" % qty
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.custom_minimum_size = Vector2(0, icon_size.y)
		box.add_child(badge)
	
func _add_quest_line(parent: Node, title: String, is_done: bool) -> void:
	if parent == null or not (parent is ItemList):
		return
	var list := parent as ItemList
	var idx := list.add_item(title)
	# cor do "dot": usamos o ícone lateral do ItemList como cor (via Theme override simples)
	# Opcional: se quiser, configure ícones/cores no Theme do projeto.
	list.set_item_metadata(idx, {"title": title, "done": is_done})
	
# -----------------------------------------------------------------
# Data helpers
# -----------------------------------------------------------------
func _inventory_counts() -> Dictionary:
	var dict: Dictionary = {}
	var inv: PlayerInventory = _get_inventory()
	if inv == null:
		return dict
	if inv.has_method("get_counts"):
		return inv.get_counts()
	for it in inv.itens:
		if it == null:
			continue
		var id: String = String(it.id_item)
		if not dict.has(id):
			dict[id] = {"data": it, "qtd": 0}
		dict[id].qtd += 1
	return dict

func _get_inventory() -> PlayerInventory:
	if player_inventory:
		return player_inventory
	var pc: Node = _find_first_in_group("player_controller")
	if pc and "inventory" in pc:
		player_inventory = pc.inventory
	return player_inventory

# -----------------------------------------------------------------
# Event handlers
# -----------------------------------------------------------------
func _on_star_count_changed(_count: int) -> void:
	_refresh_star_icons()

func _on_inventory_changed(_id := "", _v = null) -> void:
	_refresh_hud()

func _on_scene_or_save_changed(_x = null) -> void:
	_rebind_services()
	_full_refresh()

func _on_quest_changed(_a = null, _b = null, _c = null) -> void:
	if quest_menu_root and quest_menu_root.visible:
		_refresh_quest_menu()

# -----------------------------------------------------------------
# Utils
# -----------------------------------------------------------------
func _clear_children(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		c.queue_free()

func _find_first_in_group(group: String) -> Node:
	var arr: Array = get_tree().get_nodes_in_group(group)
	return arr[0] if arr.size() > 0 else null

func _find_first_named(name_str: String) -> Node:
	var root: Node = get_tree().get_root()
	if root:
		return root.find_child(name_str, true, false)
	return null

func _find_first_of_type_name(class_names: String) -> Node:
	var root: Node = get_tree().get_root()
	if root == null:
		return null
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		var is_match: bool = (n.get_class() == class_names)
		if not is_match and n.get_script():
			var scr: Script = n.get_script()
			if scr and scr.has_method("get_global_name"):
				var g = scr.get_global_name()
				is_match = (String(g) == class_names)
		if is_match:
			return n
		for c in n.get_children():
			if c is Node:
				stack.append(c)
	return null

func _autowire_quest_menu() -> void:
	if quest_menu_root == null:
		quest_menu_root = _find_control_by_names(["QuestMenu","questmenu"])

	if quest_menu_root:
		# Scrolls tipados
		var sc_act: ScrollContainer = quest_menu_root.find_child("ScrollContainer", true, false) as ScrollContainer
		var sc_done: ScrollContainer = quest_menu_root.find_child("ScrollContainer2", true, false) as ScrollContainer

		# Nós internos tipados como Node
		var act: Node = null
		if sc_act:
			act = sc_act.find_child("ActiveQuestContainer", true, false)

		var done: Node = null
		if sc_done:
			done = sc_done.find_child("CompletedQuestContainer", true, false)

		# ATIVAS -> sempre passe pelo _ensure_list_container (retorna ItemList)
		if act:
			active_quests_container = _ensure_list_container(act)
		elif sc_act:
			active_quests_container = _ensure_list_container(sc_act)

		# CONCLUÍDAS
		if done:
			completed_quests_container = _ensure_list_container(done)
		elif sc_done:
			completed_quests_container = _ensure_list_container(sc_done)

	_ensure_menu_layout()


func _find_control_by_names(candidates: Array[String]) -> Control:
	var root: Node = get_tree().get_root()
	if root == null:
		return null
	for name_str in candidates:
		var n: Node = root.find_child(name_str, true, false)
		if n and n is Control:
			return n as Control
	return null

func _find_child_by_names(parent: Node, candidates: Array[String]) -> Node:
	if parent == null:
		return null
	for name_str in candidates:
		var n: Node = parent.find_child(name_str, true, false)
		if n:
			return n
	return null

func _on_node_added(n: Node) -> void:
	if quest_service == null:
		var qs: Node = null
		if (n.has_method("get_active_quests") or n.has_signal("quest_accepted")):
			qs = n
		elif n.is_in_group("quest_service"):
			qs = n
		if qs != null:
			quest_service = qs
			_connect_quest_signals()
			if quest_menu_root and quest_menu_root.visible:
				_refresh_quest_menu()

func _find_quest_service_in_tree(node: Node) -> Node:
	if node == null:
		return null
	if node.has_method("get_active_quests") or node.has_signal("quest_accepted"):
		return node
	for c in node.get_children():
		var found: Node = _find_quest_service_in_tree(c)
		if found != null:
			return found
	return null

func _connect_quest_signals() -> void:
	if quest_service == null:
		return
	if quest_service.has_signal("quest_accepted") and not quest_service.is_connected("quest_accepted", Callable(self, "_on_quest_changed")):
		quest_service.connect("quest_accepted", Callable(self, "_on_quest_changed"))
	if quest_service.has_signal("quest_progress") and not quest_service.is_connected("quest_progress", Callable(self, "_on_quest_changed")):
		quest_service.connect("quest_progress", Callable(self, "_on_quest_changed"))
	if quest_service.has_signal("quest_completed") and not quest_service.is_connected("quest_completed", Callable(self, "_on_quest_changed")):
		quest_service.connect("quest_completed", Callable(self, "_on_quest_changed"))

# -----------------------------------------------------------------
# Quest collection + normalização
# -----------------------------------------------------------------
func _collect_quests() -> Dictionary:
	var out: Dictionary = {"active": {}, "done": {}, "source": ""}

	if quest_service and quest_service.has_method("get_active_quests") and quest_service.has_method("get_completed_quests"):
		var a = quest_service.call("get_active_quests")
		var d = quest_service.call("get_completed_quests")
		out["active"] = _normalize_variant_to_dict(a)
		out["done"]   = _normalize_variant_to_dict(d)
		out["source"] = "quest_service.api"
		if (out["active"] as Dictionary).size() > 0 or (out["done"] as Dictionary).size() > 0:
			return out

	var candidates: Array = [
		["quests_ativas", "quests_concluidas"],
		["_q_ativas", "_q_concluidas"],
		["active_quests", "completed_quests"],
		["active", "completed"]
	]
	for pair in candidates:
		var a_name: String = String(pair[0])
		var d_name: String = String(pair[1])
		if quest_service:
			var a_val = quest_service.get(a_name)
			var d_val = quest_service.get(d_name)
			var a_norm: Dictionary = _normalize_variant_to_dict(a_val)
			var d_norm: Dictionary = _normalize_variant_to_dict(d_val)
			if a_norm.size() > 0 or d_norm.size() > 0:
				out["active"] = a_norm
				out["done"] = d_norm
				out["source"] = "quest_service.props:" + a_name + "," + d_name
				return out

	var bridge: Node = _find_first_in_group("dialog_bridge")
	if bridge:
		var ba = bridge.get("_q_ativas")
		var bd = bridge.get("_q_concluidas")
		var ba_norm: Dictionary = _normalize_variant_to_dict(ba)
		var bd_norm: Dictionary = _normalize_variant_to_dict(bd)
		if ba_norm.size() > 0 or bd_norm.size() > 0:
			out["active"] = ba_norm
			out["done"] = bd_norm
			out["source"] = "dialogic_bridge._q_*"
			return out

	if Engine.has_singleton("Dialogic"):
		var D = Engine.get_singleton("Dialogic")
		if D and "Variables" in D and D.Variables:
			var names: Array = []
			if D.Variables.has_method("get_variable_names"):
				names = D.Variables.get_variable_names()
			elif D.Variables.has_method("get_all"):
				var all_vars = D.Variables.get_all()
				if typeof(all_vars) == TYPE_DICTIONARY:
					names = (all_vars as Dictionary).keys()
			elif D.Variables.has_method("save"):
				var saved = D.Variables.save()
				if typeof(saved) == TYPE_DICTIONARY:
					names = (saved as Dictionary).keys()

			var found_ids: Dictionary = {}
			for n in names:
				if typeof(n) == TYPE_STRING and (n as String).begins_with("quest/") and (n as String).ends_with("/status"):
					var qid_from_var: String = (n as String).substr(6, (n as String).length() - 6 - 7)
					found_ids[qid_from_var] = true

			var active: Dictionary = {}
			var done: Dictionary = {}
			for qid in found_ids.keys():
				var qid_s: String = String(qid)
				var status: String = str(D.Variables.get_variable("quest/%s/status" % qid_s))
				var tval = D.Variables.get_variable("quest/%s/title" % qid_s)
				var title_str: String = str(tval) if (tval != null and str(tval) != "") else qid_s
				var rec: Dictionary = {"title": title_str, "status": status}
				if status == "completed":
					done[qid_s] = rec
				elif status == "accepted" or status == "active" or status == "progress":
					active[qid_s] = rec

			if active.size() > 0 or done.size() > 0:
				out["active"] = active
				out["done"] = done
				out["source"] = "dialogic.variables"
				return out

	out["source"] = "none"
	return out

func _normalize_variant_to_dict(v) -> Dictionary:
	var result: Dictionary = {}
	var t := typeof(v)
	match t:
		TYPE_NIL:
			pass
		TYPE_DICTIONARY:
			result = (v as Dictionary)
		TYPE_ARRAY:
			result = _dict_from_array(v as Array)
		_:
			pass
	return result

func _as_dict(v) -> Dictionary:
	return _normalize_variant_to_dict(v)

func _dict_from_array(arr: Array) -> Dictionary:
	var d: Dictionary = {}
	for e in arr:
		if typeof(e) == TYPE_DICTIONARY:
			var ed: Dictionary = e as Dictionary
			var id: String = str(ed.get("id", ed.get("qid", "")))
			if id != "":
				d[id] = ed
	return d

func _find_child_by_names_ci(parent: Node, candidates: Array[String]) -> Node:
	if parent == null:
		return null
	var lower_map: Dictionary = {}
	for c in candidates:
		lower_map[c.to_lower()] = true
	var stack: Array = [parent]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n and lower_map.has(n.name.to_lower()):
			return n
		for ch in n.get_children():
			if ch is Node:
				stack.append(ch)
	return null

# Garante que vamos adicionar em um ItemList válido dentro do ScrollContainer.
func _ensure_list_container(node: Node) -> ItemList:
	if node == null:
		return null

	# Se já for ItemList, só ajusta flags
	if node is ItemList:
		var il := node as ItemList
		il.select_mode = ItemList.SELECT_SINGLE
		il.allow_reselect = true
		il.focus_mode = Control.FOCUS_ALL
		il.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		il.size_flags_vertical = Control.SIZE_EXPAND_FILL
		return il

	# Se for ScrollContainer: procura/instala um ItemList
	if node is ScrollContainer:
		var sc := node as ScrollContainer
		for ch in sc.get_children():
			if ch is ItemList:
				return _ensure_list_container(ch)
		var il2 := ItemList.new()
		il2.name = "List"
		il2.select_mode = ItemList.SELECT_SINGLE
		il2.allow_reselect = true
		il2.focus_mode = Control.FOCUS_ALL
		il2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		il2.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.add_child(il2)
		return il2

	# Qualquer Control -> cria um ItemList dentro
	if node is Control:
		var host := node as Control
		for ch in host.get_children():
			if ch is ItemList:
				return _ensure_list_container(ch)
		var il3 := ItemList.new()
		il3.name = "List"
		il3.select_mode = ItemList.SELECT_SINGLE
		il3.allow_reselect = true
		il3.focus_mode = Control.FOCUS_ALL
		il3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		il3.size_flags_vertical = Control.SIZE_EXPAND_FILL
		host.add_child(il3)
		return il3

	return null

func _ensure_menu_layout() -> void:
	# raiz do menu
	if quest_menu_root and quest_menu_root is Control:
		var c := quest_menu_root as Control
		c.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if c.custom_minimum_size == Vector2.ZERO:
			c.custom_minimum_size = Vector2(480, 320)

	# Centraliza e ROTACIONA 90° o TextureRect do QuestMenu
	var tex_node: Node = quest_menu_root.find_child("TextureRect", true, false)
	if tex_node and tex_node is Control:
		var t := tex_node as Control
		# ancora no centro da tela
		t.anchor_left = 0.5
		t.anchor_right = 0.5
		t.anchor_top = 0.5
		t.anchor_bottom = 0.5

		# tamanho de referência
		var sz := t.size
		if sz == Vector2.ZERO:
			sz = t.custom_minimum_size
		if sz == Vector2.ZERO:
			# se for TextureRect e tiver textura, tenta usar o tamanho da textura
			if tex_node is TextureRect and (tex_node as TextureRect).texture:
				sz = (tex_node as TextureRect).texture.get_size()
			if sz == Vector2.ZERO:
				sz = Vector2(880, 520) # fallback

		# centraliza por offsets simétricos
		t.offset_left = -sz.x * 0.5
		t.offset_right =  sz.x * 0.5
		t.offset_top =   -sz.y * 0.5
		t.offset_bottom = sz.y * 0.5

		# gira 90° com pivô exatamente no centro do retângulo
		t.pivot_offset = sz * 0.5
		t.rotation_degrees = 90.0

	# scrolls
	var sc_act := quest_menu_root.find_child("ScrollContainer", true, false)
	var sc_done := quest_menu_root.find_child("ScrollContainer2", true, false)
	for sc in [sc_act, sc_done]:
		if sc and sc is Control:
			var scc := sc as Control
			scc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scc.size_flags_vertical = Control.SIZE_EXPAND_FILL
			if scc.custom_minimum_size == Vector2.ZERO:
				scc.custom_minimum_size = Vector2(440, 120)

	# Containers internos (as listas), com separação entre as linhas
	active_quests_container = _ensure_list_container(active_quests_container)
	completed_quests_container = _ensure_list_container(completed_quests_container)

	for cont in [active_quests_container, completed_quests_container]:
		if cont and cont is Control:
			var cc := cont as Control
			cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
			if cc.custom_minimum_size == Vector2.ZERO:
				cc.custom_minimum_size = Vector2(0, 4)
		if cont and cont.has_method("add_theme_constant_override"):
			(cont as Node).call("add_theme_constant_override", "separation", 6)

func _on_list_item_activated(index: int, list: ItemList) -> void:
	var meta = list.get_item_metadata(index)
	var title: String = str(meta.get("title", list.get_item_text(index)))
	var done: bool = bool(meta.get("done", false))
	# Aqui você faz o que significa "entrar na missão/seleção":
	# - abrir detalhes
	# - iniciar rastreamento
	# - emitir sinal/evento global, etc.
	print("Quest ativada → ", title, " | concluída?: ", done)


func _focus_other_list(current: ItemList, to_right: bool) -> void:
	var a_ok := active_quests_container and active_quests_container is ItemList
	var c_ok := completed_quests_container and completed_quests_container is ItemList
	if not a_ok or not c_ok:
		return

	var a := active_quests_container as ItemList
	var c := completed_quests_container as ItemList

	var target := c if (current == a and to_right) else a if (current == c and not to_right) else null
	if target:
		target.grab_focus()
		# Se nada estiver selecionado ali, seleciona o primeiro
		if target.get_selected_items().size() == 0 and target.item_count > 0:
			target.select(0)

func _autowire_pause_menu() -> void:
	if pause_menu_root == null:
		# Tenta achar por nome na árvore
		pause_menu_root = _find_control_by_names(["PauseMenu","pausemenu"])
	if pause_menu_root == null:
		# Cria dinamicamente um menu simples
		var root := Control.new()
		root.name = "PauseMenu"
		root.process_mode = Node.PROCESS_MODE_WHEN_PAUSED  # NOVO
		root.visible = false
		root.mouse_filter = Control.MOUSE_FILTER_STOP
		root.set_anchors_preset(Control.PRESET_FULL_RECT, true)

		var dim := ColorRect.new()
		dim.color = Color(0,0,0,0.5)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		root.add_child(dim)

		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		root.add_child(center)

		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 12)
		center.add_child(v)

		var lbl := Label.new()
		lbl.text = "PAUSADO"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(1,1,1,1))
		lbl.add_theme_font_size_override("font_size", 28)
		v.add_child(lbl)

		var btn_resume := Button.new()
		btn_resume.text = "Continuar"
		btn_resume.focus_mode = Control.FOCUS_ALL
		v.add_child(btn_resume)

		var btn_quit := Button.new()
		btn_quit.text = "Sair"
		btn_quit.focus_mode = Control.FOCUS_ALL
		v.add_child(btn_quit)

		get_tree().get_root().add_child(root)

		pause_menu_root = root
		pause_label = lbl
		pause_btn_resume = btn_resume
		pause_btn_quit = btn_quit

	# Se veio do editor, tenta localizar subnós
	if pause_label == null:
		pause_label = pause_menu_root.find_child("Label", true, false)
	if pause_btn_resume == null:
		pause_btn_resume = pause_menu_root.find_child("Continuar", true, false) as Button
		if pause_btn_resume == null:
			pause_btn_resume = pause_menu_root.find_child("Resume", true, false) as Button
	if pause_btn_quit == null:
		pause_btn_quit = pause_menu_root.find_child("Sair", true, false) as Button
		if pause_btn_quit == null:
			pause_btn_quit = pause_menu_root.find_child("Quit", true, false) as Button

	_wire_pause_signals()
	_ensure_pause_layout()

func _wire_pause_signals() -> void:
	if pause_btn_resume and not pause_btn_resume.is_connected("pressed", Callable(self, "_on_pause_resume_pressed")):
		pause_btn_resume.connect("pressed", Callable(self, "_on_pause_resume_pressed"))

	if pause_btn_quit and not pause_btn_quit.is_connected("pressed", Callable(self, "_on_pause_quit_pressed")):
		pause_btn_quit.connect("pressed", Callable(self, "_on_pause_quit_pressed"))

	if pause_menu_root and not pause_menu_root.is_connected("gui_input", Callable(self, "_on_pause_gui_input")):
		pause_menu_root.connect("gui_input", Callable(self, "_on_pause_gui_input"))

func _on_pause_resume_pressed() -> void:
	_unpause_game()

# Substitua a função existente em UIService.gd por esta

func _on_pause_quit_pressed() -> void:
	# 1. Fornece feedback visual e previne cliques duplos.
	if pause_btn_quit:
		pause_btn_quit.disabled = true
		pause_btn_quit.text = "Salvando..."
	
	# 2. Conecta ao sinal 'game_saved' UMA ÚNICA VEZ. 
	#    Quando o sinal for emitido, a função get_tree().quit será chamada.
	#    CONNECT_ONE_SHOT é crucial para que isso não aconteça em todo save futuro.
	EventBus.game_saved.connect(get_tree().quit, CONNECT_ONE_SHOT)
	
	# 3. Dispara o processo de salvamento através do GameManager.
	#    O GameManager fará o save e, no final, emitirá o sinal 'game_saved'
	#    através do EventBus, o que ativará a conexão que fizemos acima.
	game_manager.save_game()

	# NOTA: Não chamamos get_tree().quit() diretamente aqui.
	# A execução do jogo só terminará quando o salvamento for confirmado.

# permite Esc para sair do pause também
func _on_pause_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.is_action_pressed(pause_action):
			_unpause_game()
			get_viewport().set_input_as_handled()

func _is_paused() -> bool:
	return get_tree().paused

func _pause_game() -> void:
	# Esconde o QuestMenu quando pausar (não reabre ao despausar)
	if quest_menu_root:
		quest_menu_root.visible = false

	get_tree().paused = true
	_show_pause_menu()

func _unpause_game() -> void:
	_hide_pause_menu()
	get_tree().paused = false

func _show_pause_menu() -> void:
	if not pause_menu_root:
		_autowire_pause_menu()
	if pause_menu_root:
		pause_menu_root.visible = true
		# foca o primeiro botão pra teclado funcionar na hora
		if pause_btn_resume:
			pause_btn_resume.grab_focus()

func _hide_pause_menu() -> void:
	if pause_menu_root:
		pause_menu_root.visible = false

func _ensure_pause_layout() -> void:
	if not pause_menu_root: return
	var c := pause_menu_root
	if c is Control:
		(c as Control).set_anchors_preset(Control.PRESET_FULL_RECT, true)
	pause_menu_root.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
