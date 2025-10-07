extends Node
class_name DialogicService

signal dialogo_iniciou
signal dialogo_terminou
signal evento_recebido(event_resource)

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
	dialogo_iniciou.emit()

func _on_timeline_ended():
	dialogo_terminou.emit()

func _on_event_handled(event_resource):
	evento_recebido.emit(event_resource)
