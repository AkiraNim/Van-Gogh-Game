extends Node
class_name UIService

# --- UI Roots / Containers ---
@export var hud_root: Control
@export var stars_container: Container
@export var important_container: Container

@export var quest_menu_root: Control
@export var active_quests_container: Container
@export var completed_quests_container: Container

# --- Data sources ---
@export var item_repository: ItemRepository
@export var player_inventory: PlayerInventory
@export var player_state: PlayerState
@export var quest_service: Node    # QuestManager/QuestService/Bridge/etc

# --- Input ---
@export var toggle_action: StringName = "toggle"

# --- Visual ---
@export var icon_size: Vector2 = Vector2(32, 32)
@export var show_count_badge: bool = true

func _ready() -> void:
	_rebind_services()
	_connect_signals()
	call_deferred("_rebind_services")
	if not get_tree().is_connected("node_added", Callable(self, "_on_node_added")):
		get_tree().connect("node_added", Callable(self, "_on_node_added"))
	_autowire_quest_menu()
	if quest_menu_root:
		quest_menu_root.visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_rebind_services()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action) and quest_menu_root:
		quest_menu_root.visible = not quest_menu_root.visible
		if quest_menu_root.visible:
			_refresh_quest_menu()

# -----------------------------------------------------------------
# Bind / Resolve
# -----------------------------------------------------------------
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

	_clear_children(active_quests_container)
	_clear_children(completed_quests_container)

	var qdata: Dictionary = _collect_quests()
	var act: Dictionary = _as_dict(qdata.get("active", {}))
	var done: Dictionary = _as_dict(qdata.get("done", {}))

	for qid in act.keys():
		var q: Dictionary = _as_dict(act[qid])
		var fallback_title: String = String(q.get("title", qid))
		var title: String = _get_dialogic_title(String(qid), fallback_title)
		_add_quest_line(active_quests_container, title, false) # ativo => vermelho
		print("UIService: +ativa → ", qid, " | ", title)

	for qid in done.keys():
		var title := _get_dialogic_title(String(qid), String(qid))
		_add_quest_line(completed_quests_container, title, true) # concluída => verde
		print("UIService: +concluída → ", String(qid), " | ", title)

	var act_cc := (active_quests_container as Node).get_child_count() if active_quests_container else -1
	var done_cc := (completed_quests_container as Node).get_child_count() if completed_quests_container else -1
	print("UIService: list paths → act:", active_quests_container.get_path(), " (", act_cc, " filhos)",
		" | done:", completed_quests_container.get_path(), " (", done_cc, " filhos)")
	print("UIService: quests → ativas:", act.size(), " | concluídas:", done.size())

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

# is_done = false (ativa/vermelho) | true (concluída/verde)
func _add_quest_line(parent: Node, title: String, is_done: bool) -> void:
	if parent == null:
		return
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 28)
	parent.add_child(panel)

	var h := HBoxContainer.new()
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_theme_constant_override("separation", 6)
	panel.add_child(h)

	var dot := ColorRect.new()
	dot.color = Color(0.20, 0.80, 0.30) if is_done else Color(0.90, 0.20, 0.20) # verde / vermelho
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)

	var lbl := Label.new()
	lbl.text = title
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.add_theme_color_override("font_color", Color(1,1,1,1))
	h.add_child(lbl)

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
		var sc_act := quest_menu_root.find_child("ScrollContainer", true, false)
		var act = (sc_act and sc_act.find_child("ActiveQuestContainer", true, false)) if sc_act else null
		var sc_done := quest_menu_root.find_child("ScrollContainer2", true, false)
		var done = (sc_done and sc_done.find_child("CompletedQuestContainer", true, false)) if sc_done else null

		if act:
			if act is Container:
				active_quests_container = act
			elif act is Control:
				active_quests_container = _ensure_list_container(act)
		elif sc_act and sc_act is ScrollContainer:
			active_quests_container = _ensure_list_container(sc_act)

		if done:
			if done is Container:
				completed_quests_container = done
			elif done is Control:
				completed_quests_container = _ensure_list_container(done)
		elif sc_done and sc_done is ScrollContainer:
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

# Garante que vamos adicionar em um Container válido dentro do ScrollContainer.
func _ensure_list_container(node: Node) -> Container:
	if node == null:
		return null
	if node is Container:
		var c := node as Container
		if c is Control:
			var cc := c as Control
			cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		return c

	if node is ScrollContainer:
		var sc := node as ScrollContainer
		for ch in sc.get_children():
			if ch is Container:
				var cont := ch as Container
				if cont is Control:
					var cc := cont as Control
					cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
				return cont
		var vb := VBoxContainer.new()
		vb.name = "ListContainer"
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.add_child(vb)
		return vb

	if node is Control:
		var host := node as Control
		var vb2 := VBoxContainer.new()
		vb2.name = "ListContainer"
		vb2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb2.size_flags_vertical = Control.SIZE_EXPAND_FILL
		host.add_child(vb2)
		return vb2

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
