extends Node
class_name DialogicService

signal dialog_started
signal dialog_ended
signal event_received(event_resource)

func _ready():
	if not Dialogic.timeline_started.is_connected(_on_timeline_started):
		Dialogic.timeline_started.connect(_on_timeline_started)
	if not Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.connect(_on_timeline_ended)
	if not Dialogic.event_handled.is_connected(_on_event_handled):
		Dialogic.event_handled.connect(_on_event_handled)

func iniciar_dialogo(nome_timeline: String) -> void:
	Dialogic.start(nome_timeline)

func _on_timeline_started():
	dialog_started.emit()

func _on_timeline_ended():
	dialog_ended.emit()

func _on_event_handled(event_resource):
	event_received.emit(event_resource)
