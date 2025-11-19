extends Control
class_name QuestMenuController

@export var active_list: VBoxContainer
@export var completed_list: VBoxContainer
@export var toggle_action: StringName = "toggle"

@export var row_font: Font

func _ready() -> void:
	visible = false
	var QS := _get_quest_service()
	if QS:
		if not QS.quest_accepted.is_connected(_on_q_accepted):
			QS.quest_accepted.connect(_on_q_accepted)
		if not QS.quest_progress.is_connected(_on_q_progress):
			QS.quest_progress.connect(_on_q_progress)
		if not QS.quest_completed.is_connected(_on_q_completed):
			QS.quest_completed.connect(_on_q_completed)

	_refresh_lists()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		visible = not visible
		if visible:
			_refresh_lists()

func _on_q_accepted(qid: String, title: String) -> void:
	_print_title("ACCEPTED", title)
	_refresh_lists()

func _on_q_progress(qid: String, have: Dictionary) -> void:
	# tenta obter título no serviço para imprimir igual você queria
	var title := _get_title_for(qid)
	_print_title("PROGRESS", title)
	_refresh_lists()

func _on_q_completed(qid: String, title: String, motivo: String) -> void:
	_print_title("COMPLETED", title)
	_refresh_lists()

func _refresh_lists() -> void:
	_clear_container(active_list)
	_clear_container(completed_list)

	var QS := _get_quest_service()
	if not QS:
		return

	# ativa
	var act = QS.get_active_quests()
	for qid in act.keys():
		var q = act[qid]
		var title := String(q.get("title", qid))
		_add_row(active_list, title)

	# concluída
	var done = QS.get_completed_quests()
	for qid in done.keys():
		var title := _get_title_for(qid)
		_add_row(completed_list, title)

func _add_row(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	if row_font:
		var theme = Theme.new()
		theme.set_font("font", "Label", row_font)
		lbl.theme = theme
	parent.add_child(lbl)

func _clear_container(node: Node) -> void:
	if not node: return
	for c in node.get_children():
		c.queue_free()

func _get_quest_service() -> QuestService:
	if Engine.has_singleton("QuestService"):
		return Engine.get_singleton("QuestService")
	var ns := get_tree().get_nodes_in_group("QuestService")
	return ns[0] if ns.size() > 0 else null

func _get_title_for(qid: String) -> String:
	var QS := _get_quest_service()
	if QS == null:
		return qid
	var act = QS.get_active_quests()
	if act.has(qid):
		return String(act[qid].get("title", qid))
	var done = QS.get_completed_quests()
	if done.has(qid):
		if Engine.has_singleton("Dialogic"):
			var D := Engine.get_singleton("Dialogic")
			if D and D.has_subsystem("VAR"):
				var t = D.VAR.get_variable("quest/%s/title" % qid)
				if t != null and String(t) != "":
					return String(t)
		return qid
	return qid

func _print_title(kind: String, title: String) -> void:
	if title == "" or title == null:
		title = "<untitled quest>"
