extends Node
class_name QuestService

signal quest_accepted(qid: String, title: String)
signal quest_progress(qid: String, have: Dictionary)
signal quest_completed(qid: String, title: String, motivo: String)

var quests_ativas := {}    
var quests_concluidas := {}

func _ready() -> void:
	if has_node("/root/EventBus"):
		var eb := get_node("/root/EventBus")
		if not eb.item_collected.is_connected(_on_item_collected):
			eb.item_collected.connect(_on_item_collected)

func accept(qid: String, title: String, tipo: String, req_items := {}, req_talk_to := "", giver := "") -> void:
	if quests_concluidas.has(qid):
		_set_var("quest/%s/status" % qid, "completed")
		return
	if quests_ativas.has(qid) and String(quests_ativas[qid].get("status","")) == "accepted":
		return

	var q := {
		"title": title,
		"tipo": tipo,
		"status": "accepted",
		"giver": giver
	}

	if tipo == "collect":
		q.req_items = req_items.duplicate(true)
		q.have = {}
		for id in q.req_items.keys():
			q.have[id] = 0
	elif tipo == "talk":
		q.req_talk_to = req_talk_to

	quests_ativas[qid] = q
	emit_signal("quest_accepted", qid, title)
	_sync_vars(qid)

func set_req(qid: String, item_id: String, need: int) -> void:
	var q = quests_ativas.get(qid, null)
	if q == null:
		return
	if String(q.get("tipo","")) != "collect":
		return
	if not q.has("req_items"):
		q.req_items = {}
	if not q.has("have"):
		q.have = {}
	q.req_items[item_id] = need
	q.have[item_id] = q.have.get(item_id, 0)
	quests_ativas[qid] = q
	_sync_vars(qid)

func add_progress(qid: String, item_id: String, amount := 1) -> void:
	var q = quests_ativas.get(qid, null)
	if q == null or String(q.get("tipo","")) != "collect" or String(q.get("status","")) != "accepted":
		return
	if not q.req_items.has(item_id):
		return
	q.have[item_id] = int(q.have.get(item_id, 0)) + int(amount)
	quests_ativas[qid] = q
	emit_signal("quest_progress", qid, q.have)
	_sync_vars(qid)
	if _is_collect_done(q):
		complete(qid, "collect")

func set_talk_target(qid: String, npc_name: String) -> void:
	var q = quests_ativas.get(qid, null)
	if q == null:
		return
	q.tipo = "talk"
	q.req_talk_to = npc_name
	quests_ativas[qid] = q
	_sync_vars(qid)

func talk_hit(npc_name: String) -> void:
	for qid in quests_ativas.keys():
		var q = quests_ativas[qid]
		if String(q.get("tipo","")) != "talk":    continue
		if String(q.get("status","")) != "accepted": continue
		if String(q.get("req_talk_to","")) != npc_name: continue
		complete(qid, "talk")

func complete(qid: String, motivo := "") -> void:
	var q = quests_ativas.get(qid, null)
	if q == null:
		return
	if String(q.get("status","")) != "accepted":
		return
	q.status = "completed"
	quests_ativas.erase(qid)
	quests_concluidas[qid] = true
	var title := String(q.get("title", qid))
	emit_signal("quest_completed", qid, title, motivo)
	_set_var("quest/%s/status" % qid, "completed")
	_set_var("quest/%s/done" % qid, true)

func _on_item_collected(id_item: String, _node: Node3D) -> void:
	for qid in quests_ativas.keys():
		var q = quests_ativas[qid]
		if String(q.get("tipo","")) != "collect":   continue
		if String(q.get("status","")) != "accepted": continue
		if not q.req_items.has(id_item):            continue
		add_progress(qid, id_item, 1)

func _is_collect_done(q: Dictionary) -> bool:
	for id in q.req_items.keys():
		var need := int(q.req_items[id])
		var have := int(q.have.get(id, 0))
		if have < need:
			return false
	return true

func _sync_vars(qid: String) -> void:
	var q = quests_ativas.get(qid, null)
	if q == null:
		if quests_concluidas.has(qid):
			_set_var("quest/%s/status" % qid, "completed")
			_set_var("quest/%s/done" % qid, true)
		return

	_set_var("quest/%s/status" % qid, String(q.get("status","")))
	_set_var("quest/%s/title"  % qid, String(q.get("title", qid)))

	if String(q.get("tipo","")) == "collect":
		for id in q.req_items.keys():
			_set_var("quest/%s/need/%s" % [qid, id], int(q.req_items[id]))
			_set_var("quest/%s/have/%s" % [qid, id], int(q.have.get(id, 0)))
	elif String(q.get("tipo","")) == "talk":
		_set_var("quest/%s/req_talk_to" % qid, String(q.get("req_talk_to","")))

func _set_var(path: String, value: Variant) -> void:
	if Engine.has_singleton("Dialogic"):
		var D := Engine.get_singleton("Dialogic")
		if D and "Variables" in D:
			D.Variables.set_variable(path, value)
