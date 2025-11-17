extends Node
class_name QuestService

signal quest_accepted(qid: String, title: String)
signal quest_progress(qid: String, have: Dictionary)
signal quest_completed(qid: String, title: String, description: String)

var active_quests := {}     
var finished_quests := {} 

func _ready() -> void:

	if has_node("/root/EventBus"):
		var eb := get_node("/root/EventBus")
		if not eb.item_collected.is_connected(_on_item_collected):
			eb.item_collected.connect(_on_item_collected)

func accept(qid: String, title: String, type: String, req_items := {}, req_talk_to := "", giver := "") -> void:
	if finished_quests.has(qid):
		_set_var("quest/%s/status" % qid, "completed")
		return
	if active_quests.has(qid) and String(active_quests[qid].get("status","")) == "accepted":
		return

	var q := {
		"title": title,
		"type": type,
		"status": "accepted",
		"giver": giver
	}

	if type == "collect":
		q.req_items = req_items.duplicate(true)
		q.have = {}
		for id in q.req_items.keys():
			q.have[id] = 0
	elif type == "talk":
		q.req_talk_to = req_talk_to

	active_quests[qid] = q
	emit_signal("quest_accepted", qid, title)
	_sync_vars(qid)

func set_req(qid: String, item_id: String, need: int) -> void:
	var q = active_quests.get(qid, null)
	if q == null:
		return
	if String(q.get("type","")) != "collect":
		return
	if not q.has("req_items"):
		q.req_items = {}
	if not q.has("have"):
		q.have = {}
	q.req_items[item_id] = need
	q.have[item_id] = q.have.get(item_id, 0)
	active_quests[qid] = q
	_sync_vars(qid)

func add_progress(qid: String, item_id: String, amount := 1) -> void:
	var q = active_quests.get(qid, null)
	if q == null or String(q.get("type","")) != "collect" or String(q.get("status","")) != "accepted":
		return
	if not q.req_items.has(item_id):
		return
	q.have[item_id] = int(q.have.get(item_id, 0)) + int(amount)
	active_quests[qid] = q
	emit_signal("quest_progress", qid, q.have)
	_sync_vars(qid)
	if _is_collect_done(q):
		complete(qid, "collect")

func set_talk_target(qid: String, npc_name: String) -> void:
	var q = active_quests.get(qid, null)
	if q == null:
		return
	q.type = "talk"
	q.req_talk_to = npc_name
	active_quests[qid] = q
	_sync_vars(qid)

func talk_hit(npc_name: String) -> void:
	for qid in active_quests.keys():
		var q = active_quests[qid]
		if String(q.get("type","")) != "talk":    continue
		if String(q.get("status","")) != "accepted": continue
		if String(q.get("req_talk_to","")) != npc_name: continue
		complete(qid, "talk")

func complete(qid: String, description := "") -> void:
	var q = active_quests.get(qid, null)
	if q == null:
		return
	if String(q.get("status","")) != "accepted":
		return
	q.status = "completed"
	active_quests.erase(qid)
	finished_quests[qid] = true
	var title := String(q.get("title", qid))

	emit_signal("quest_completed", qid, title, description)
	_set_var("quest/%s/status" % qid, "completed")
	_set_var("quest/%s/done" % qid, true)

func _on_item_collected(id_item: String, _node: Node3D) -> void:
	for qid in active_quests.keys():
		var q = active_quests[qid]
		if String(q.get("type","")) != "collect":   continue
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
	var q = active_quests.get(qid, null)
	if q == null:
		if finished_quests.has(qid):
			_set_var("quest/%s/status" % qid, "completed")
			_set_var("quest/%s/done" % qid, true)
		return

	_set_var("quest/%s/status" % qid, String(q.get("status","")))
	_set_var("quest/%s/title"  % qid, String(q.get("title", qid)))

	if String(q.get("type","")) == "collect":
		for id in q.req_items.keys():
			_set_var("quest/%s/need/%s" % [qid, id], int(q.req_items[id]))
			_set_var("quest/%s/have/%s" % [qid, id], int(q.have.get(id, 0)))
	elif String(q.get("type","")) == "talk":
		_set_var("quest/%s/req_talk_to" % qid, String(q.get("req_talk_to","")))

func _set_var(path: String, value: Variant) -> void:
	if Engine.has_singleton("Dialogic"):
		var D := Engine.get_singleton("Dialogic")
		if D and "Variables" in D:
			D.Variables.set_variable(path, value)
