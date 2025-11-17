extends Node

signal dialogic_lock_animation(name: String, duration: float)
signal dialogic_unlock_animation()
signal npc_lock_animation(key: String, name: String, duration: float)
signal npc_unlock_animation(key: String)

var _hooked := {}  # { instance_id: true }
var _starting := false
var _active := false
var _last_start_time := 0.0
const START_COOLDOWN := 0.15

var _q_actives := {}
var _q_finished := {}  # { qid: true }

func _ensure_q(qid: String) -> Dictionary:
	if not _q_actives.has(qid) and not _q_finished.has(qid):
		_q_actives[qid] = {
			"status": "none",
			"type": "",
			"title": qid,
			"giver": "",
			"reqs": {},
			"progress": {},
			"talk_target": ""
		}
	return _q_actives.get(qid, {})

func _set_var(name: String, value: Variant) -> void:
	var D := _get_dialogic()
	if D and D.has_subsystem("VAR"):
		D.VAR.set_variable(name, value)
	elif "Variables" in Dialogic:
		Dialogic.Variables.set_variable(name, value)

func _sync_status_vars(qid: String) -> void:
	if _q_finished.has(qid):
		_set_var("q_%s_status" % qid, "completed")
	elif _q_actives.has(qid):
		var q = _q_actives[qid]
		_set_var("q_%s_status" % qid, str(q.get("status", "none")))
	else:
		_set_var("q_%s_status" % qid, "none")

func _sync_req_vars(qid: String) -> void:
	if not _q_actives.has(qid):
		return
	var q = _q_actives[qid]
	var reqs = q.get("reqs", {})
	var prog = q.get("progress", {})
	for id in reqs.keys():
		_set_var("q_%s_need_%s" % [qid, id], int(reqs[id]))
	for id in prog.keys():
		_set_var("q_%s_progress_%s" % [qid, id], int(prog[id]))

func _quest_try_autocomplete(qid: String) -> void:
	if not _q_actives.has(qid):
		return
	var q = _q_actives[qid]
	if str(q.get("status", "")) != "accepted":
		return
	if str(q.get("type", "")) == "talk":
		# talk completa apenas via quest_talk_hit
		return
	var reqs = q.get("reqs", {})
	var prog = q.get("progress", {})
	for id in reqs.keys():
		var need := int(reqs[id])
		var cur := int(prog.get(id, 0))
		if cur < need:
			return
	_quest_complete_local(qid, "auto")

func _quest_complete_local(qid: String, source: String) -> void:
	if _q_finished.has(qid):
		return
	var title := qid
	if _q_actives.has(qid):
		var q = _q_actives[qid]
		title = str(q.get("title", qid))
	_q_finished[qid] = true
	_q_actives.erase(qid)
	_set_var("q_%s_status" % qid, "completed")
	if has_node("/root/EventBus"):
		var eb := get_node("/root/EventBus")
		if "quest_done" in eb:
			eb.quest_done.emit("", qid)

func _quest_dump() -> void:
	for qid in _q_actives.keys():
		var q = _q_actives[qid]
		#print("- ", qid, " (", str(q.get("title", qid)), ")",
			  #" | status=", str(q.get("status", "")),
			  #" type=", str(q.get("type", "")),
			  #" talk_target=", str(q.get("talk_target", "")))
		var reqs = q.get("reqs", {})
		var prog = q.get("progress", {})
		if reqs.size() > 0:
			for id in reqs.keys():
				#print("  • req ", id, ": ", int(prog.get(id, 0)), "/", int(reqs.get(id, 0)))
				return
	for qid in _q_finished.keys():
		#print("- ", qid)
		return

func _ready() -> void:
	# 1. Guarda Singleton: Garante que o Bridge seja uma instância única.
	add_to_group("dialog_bridge")
	if get_tree().get_nodes_in_group("dialog_bridge").size() > 1:
		queue_free()
		return

	var D := _get_dialogic()
	if D != null:
		if not D.is_connected("signal_event", Callable(self, "_on_dialogic_signal_name_args")):
			D.connect("signal_event", Callable(self, "_on_dialogic_signal_name_args"))
		if not D.is_connected("timeline_started", Callable(self, "_on_dialogic_timeline_started")):
			D.connect("timeline_started", Callable(self, "_on_dialogic_timeline_started"))
		if not D.is_connected("timeline_ended", Callable(self, "_on_dialogic_timeline_ended")):
			D.connect("timeline_ended", Callable(self, "_on_dialogic_timeline_ended"))

	if has_node("/root/EventBus"):
		var eb := get_node("/root/EventBus")
		if not eb.npc_dialog_triggered.is_connected(_on_npc_dialog_triggered):
			eb.npc_dialog_triggered.connect(_on_npc_dialog_triggered)
			
	
func _on_npc_dialog_triggered(_npc_name: String, timeline: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if (now - _last_start_time) < START_COOLDOWN or _active or _starting:
		return
	_last_start_time = now

	var D := _get_dialogic()
	if D and D.has_method("start"):
		_starting = true
		D.call_deferred("start", timeline)
	elif D and D.has_method("start_timeline"):
		_starting = true
		D.call_deferred("start_timeline", timeline)

func _get_dialogic() -> Object:
	if Engine.has_singleton("Dialogic"):
		return Engine.get_singleton("Dialogic")
	if has_node("/root/Dialogic"):
		return get_node("/root/Dialogic")
	return null

func _connect_dialogic_signals() -> void:
	var D := _get_dialogic()
	if D != null:
		_try_hook_node(D)

func _on_node_added(n: Node) -> void:
	_try_hook_node(n)
	for c in n.get_children():
		if c is Node:
			_try_hook_node(c)

func _try_hook_node(n: Node) -> void:
	if n == null:
		return
	var key := n.get_instance_id()
	if _hooked.has(key):
		return
	var hooked := false
	if n.has_signal("signal") and not n.is_connected("signal", Callable(self, "_on_dialogic_signal_single")):
		n.connect("signal", Callable(self, "_on_dialogic_signal_single")); hooked = true
	if n.has_signal("signal_event") and not n.is_connected("signal_event", Callable(self, "_on_dialogic_signal_name_args")):
		n.connect("signal_event", Callable(self, "_on_dialogic_signal_name_args")); hooked = true
	if n.has_signal("timeline_started") and not n.is_connected("timeline_started", Callable(self, "_on_dialogic_timeline_started")):
		n.connect("timeline_started", Callable(self, "_on_dialogic_timeline_started"))
	if n.has_signal("timeline_ended") and not n.is_connected("timeline_ended", Callable(self, "_on_dialogic_timeline_ended")):
		n.connect("timeline_ended", Callable(self, "_on_dialogic_timeline_ended"))
	if hooked:
		_hooked[key] = true

func _on_dialogic_timeline_started() -> void:
	if _active:
		return

	_starting = false
	_active = true
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").dialog_started.emit()

func _on_dialogic_timeline_ended() -> void:
	_active = false
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").dialog_ended.emit()

func _on_dialogic_signal_single(arg: Variant) -> void:
	_route_dialogic_signal(arg, null)

func _on_dialogic_signal_name_args(name: Variant, args: Variant = null) -> void:
	_route_dialogic_signal(name, args)

func _receive_timeline_signal(signal_name: String, value: Variant = null) -> void:
	_route_dialogic_signal(signal_name, value)

func _route_dialogic_signal(name_v: Variant, payload: Variant) -> void:
	var sig := ""
	if typeof(name_v) == TYPE_STRING:
		sig = String(name_v).strip_edges()
	elif typeof(name_v) == TYPE_DICTIONARY and name_v.has("arg"):
		sig = String(name_v["arg"]).strip_edges()
	elif typeof(payload) == TYPE_DICTIONARY and payload.has("arg"):
		sig = String(payload["arg"]).strip_edges()
	if sig == "":
		return

	sig = _expand_vars(sig)

	if typeof(payload) == TYPE_DICTIONARY:
		for k in payload.keys():
			if typeof(payload[k]) == TYPE_STRING:
				payload[k] = _expand_vars(str(payload[k]))

	if sig == "quest_dump":
		_quest_dump()
		return

	if sig == "inv_sync":
		var pc := _player_controller()
		if not pc or not ("inventory" in pc) or pc.inventory == null:
			return

		var inv: PlayerInventory = pc.inventory
		
		var counts: Dictionary = inv.get_counts() 

		for id in counts.keys():
			var rec: Dictionary = counts[id]
			var qtd: int = rec.qtd
			
			_set_var("has_%s" % id, qtd > 0)
			_set_var("count_%s" % id, qtd)
		return
	
	if sig.begins_with("remove_item"):
		var parts := sig.split(":")
		if parts.size() < 2:
			return

		var item_id := parts[1].strip_edges()
		var amount_to_remove := 1
		if parts.size() >= 3:
			amount_to_remove = int(parts[2])

		if item_id == "":
			return

		var pc := _player_controller()
		if not pc or not ("inventory" in pc) or pc.inventory == null:
			return
			
		var inv: PlayerInventory = pc.inventory
		
		var removed_count := 0
		for i in range(amount_to_remove):
			var removed_data: ItemData = inv.remove_item_by_id(item_id)
			if removed_data != null:
				removed_count += 1
			else:
				break 
		
		var counts := inv.get_counts()
		var current_qty := 0
		if counts.has(item_id):
			current_qty = counts[item_id].qtd

		_set_var("has_%s" % item_id, current_qty > 0)
		_set_var("count_%s" % item_id, current_qty)
		
		if removed_count > 0:
			return
		else:
			return
		
		return
	if sig.begins_with("quest_accept"):
		var parts := sig.split(":")
		if parts.size() >= 3:
			var qid := parts[1].strip_edges()
			var type := parts[2].strip_edges()

			if Engine.has_singleton("QuestService"):
				var QS := Engine.get_singleton("QuestService")
				if QS.has_method("is_completed") and QS.is_completed(qid):
					return
				if QS.has_method("is_active") and QS.is_active(qid):
					return
			else:
				if _q_finished.has(qid):
					return
				if _q_actives.has(qid):
					return

			var title := qid
			var giver := ""
			var req_talk_to := ""
			if typeof(payload) == TYPE_DICTIONARY:
				if payload.has("title"):       title = str(payload["title"])
				if payload.has("giver"):       giver = str(payload["giver"])
				if payload.has("req_talk_to"): req_talk_to = str(payload["req_talk_to"])

			if Engine.has_singleton("QuestService"):
				Engine.get_singleton("QuestService").accept(qid, title, type, {}, req_talk_to, giver)
			else:
				var q := _ensure_q(qid)
				q["status"]      = "accepted"
				q["type"]        = type
				q["title"]       = title
				q["giver"]       = giver
				q["talk_target"] = req_talk_to
				_q_actives[qid]   = q
				_sync_status_vars(qid)
		return

	if sig.begins_with("quest_set_req"):
		var parts := sig.split(":")
		if parts.size() >= 4:
			var qid := parts[1].strip_edges()
			var item_id := parts[2].strip_edges()
			var need := int(parts[3])
			if Engine.has_singleton("QuestService"):
				var QS := Engine.get_singleton("QuestService")
				if QS.has_method("is_completed") and QS.is_completed(qid):
					return
			else:
				if _q_finished.has(qid):
					return

			if Engine.has_singleton("QuestService"):
				Engine.get_singleton("QuestService").set_req(qid, item_id, need)
			else:
				var q := _ensure_q(qid)
				var reqs = q.get("reqs", {})
				reqs[item_id] = need
				q["reqs"] = reqs
				_q_actives[qid] = q
				_set_var("q_%s_need_%s" % [qid, item_id], need)
				_quest_try_autocomplete(qid)
		return

	if sig.begins_with("quest_add"):
		var parts := sig.split(":")
		if parts.size() >= 3:
			var qid := parts[1].strip_edges()
			var item_id := parts[2].strip_edges()
			var amount := 1
			if parts.size() >= 4:
				amount = int(parts[3])
			if Engine.has_singleton("QuestService"):
				var QS := Engine.get_singleton("QuestService")
				if QS.has_method("is_completed") and QS.is_completed(qid):
					return
				if QS.has_method("is_active") and not QS.is_active(qid):
					return
				Engine.get_singleton("QuestService").add_progress(qid, item_id, amount)
			else:
				if _q_finished.has(qid):
					return
				if not _q_actives.has(qid) or str(_q_actives[qid].get("status","")) != "accepted":
					return
				var q := _ensure_q(qid)
				var prog = q.get("progress", {})
				prog[item_id] = int(prog.get(item_id, 0)) + amount
				q["progress"] = prog
				_q_actives[qid] = q
				_set_var("q_%s_progress_%s" % [qid, item_id], int(prog[item_id]))
				print("➕ Progresso:", qid, "→", item_id, "=", int(prog[item_id]), "/", int(q.get("reqs", {}).get(item_id, 0)))
				_quest_try_autocomplete(qid)
		return

	if sig.begins_with("quest_talk_target"):
		var parts := sig.split(":")
		if parts.size() >= 3:
			var qid := parts[1].strip_edges()
			var who := parts[2].strip_edges()
			if Engine.has_singleton("QuestService"):
				Engine.get_singleton("QuestService").set_talk_target(qid, who)
			else:
				var q := _ensure_q(qid)
				q["talk_target"] = who
				_q_actives[qid] = q
				print("🗣️ Target set:", qid, "→", who)
		return

	if sig.begins_with("quest_talk_hit"):
		var parts := sig.split(":")
		if parts.size() >= 2:
			var who := parts[1].strip_edges()
			if Engine.has_singleton("QuestService"):
				Engine.get_singleton("QuestService").talk_hit(who)
			else:
				for qid in _q_actives.keys():
					var q = _q_actives[qid]
					if str(q.get("type","")) == "talk" and str(q.get("status","")) == "accepted" and str(q.get("talk_target","")) == who:
						_quest_complete_local(qid, "talk_hit")
		return

	if sig.begins_with("quest_complete"):
		var parts := sig.split(":")
		if parts.size() >= 2:
			var qid := parts[1].strip_edges()
			if Engine.has_singleton("QuestService"):
				Engine.get_singleton("QuestService").complete(qid, "dialogic")
			else:
				_quest_complete_local(qid, "manual")
		return

	if sig.begins_with("lock_anim"):
		var anim_name := "idle_down"
		var duration := 0.25
		var parts := sig.split(":")
		if parts.size() >= 2:
			anim_name = parts[1].strip_edges()
		if parts.size() >= 3:
			var dur_txt := parts[2].strip_edges().replace(",", ".")
			var dur_try := dur_txt.to_float()
			if dur_try > 0.0:
				duration = dur_try
		if parts.size() == 2:
			var dur_idx := anim_name.find("dur=")
			if dur_idx >= 0:
				var base := anim_name.substr(0, dur_idx).strip_edges()
				var dtxt := anim_name.substr(dur_idx + 4).strip_edges().replace(",", ".")
				var dval := dtxt.to_float()
				if base != "":
					anim_name = base
				if dval > 0.0:
					duration = dval
			else:
				var rx := RegEx.new()
				rx.compile("^(.*?)([0-9]+(?:\\.[0-9]+)?)$")
				var m := rx.search(anim_name)
				if m:
					var base2 := m.get_string(1).strip_edges()
					var dtxt2 := m.get_string(2).strip_edges().replace(",", ".")
					var dval2 := dtxt2.to_float()
					if base2 != "":
						anim_name = base2
					if dval2 > 0.0:
						duration = dval2
		if typeof(payload) == TYPE_DICTIONARY and payload.has("duration"):
			var d := str(payload["duration"]).replace(",", ".").to_float()
			if d > 0.0:
				duration = d
		emit_signal("dialogic_lock_animation", anim_name, duration)
		return

	if sig == "unlock_anim":
		emit_signal("dialogic_unlock_animation")
		return

	if sig.begins_with("npc_lock"):
		var npc_key := ""
		var anim_name := "idle_down"
		var duration := 0.25
		var parts := sig.split(":")
		if parts.size() >= 2:
			npc_key = parts[1].strip_edges()
		if parts.size() >= 3:
			anim_name = parts[2].strip_edges()
		if parts.size() >= 4:
			var dt := parts[3].strip_edges().replace(",", ".")
			if dt.begins_with("dur="):
				dt = dt.substr(4)
			var dv := dt.to_float()
			if dv > 0.0:
				duration = dv
		emit_signal("npc_lock_animation", npc_key, anim_name, duration)
		return

	if sig.begins_with("npc_unlock"):
		var parts := sig.split(":")
		var npc_key := parts[1].strip_edges() if parts.size() >= 2 else ""
		emit_signal("npc_unlock_animation", npc_key)
		return

	if sig.begins_with("npc_next"):
		var parts := sig.split(":")
		if parts.size() >= 2:
			var npc_key := parts[1].strip_edges()
			var npc := _find_npc_by_name(npc_key)
			if npc and npc.has_method("avancar_timeline"):
				npc.avancar_timeline()
			else:
				return
		return

	if sig.begins_with("npc_timeline_index"):
		var parts := sig.split(":")
		if parts.size() >= 3:
			var npc_key := parts[1].strip_edges()
			var idx := int(parts[2])
			var npc := _find_npc_by_name(npc_key)
			if npc and ("_current_timeline_index" in npc) and ("timelines" in npc):
				npc._current_timeline_index = clamp(idx, 0, npc.timelines.size()-1)
			else:
				return
		return

func _find_npc_by_name(npc_name: String) -> Node:
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.name == npc_name:
			return n
		if "npc_name" in n and String(n.npc_name) == npc_name:
			return n
	var root := get_tree().get_current_scene()
	if root:
		var found := root.get_node_or_null("//" + npc_name)
		if found:
			return found
	var possiveis := []
	for n in get_tree().get_nodes_in_group("npcs"):
		var tag := n.name
		if "npc_name" in n:
			tag += " (npc_name=" + String(n.npc_name) + ")"
		possiveis.append(tag)
	return null

func _player_controller() -> Node:
	var nodes := get_tree().get_nodes_in_group("player_controller")
	return nodes[0] if nodes.size() > 0 else null

func _get_var(key: String) -> Variant:
	var D := _get_dialogic()
	if D and D.has_subsystem("VAR"):
		return D.VAR.get_variable(key)
	if "Variables" in Dialogic:
		return Dialogic.Variables.get_variable(key)
	return null

func _expand_vars(s: String) -> String:
	if s == "" or s.find("{") == -1:
		return s
	var out := s
	var rx := RegEx.new()
	rx.compile("\\{([^}]+)\\}")
	var matches := rx.search_all(out)
	if matches:
		for i in range(matches.size()-1, -1, -1):
			var m := matches[i]
			var key := m.get_string(1) # ex: "count_estrela_vermelha"
			var val = _get_var(key)
			out = out.substr(0, m.get_start()) + str(val) + out.substr(m.get_end())
	return out
