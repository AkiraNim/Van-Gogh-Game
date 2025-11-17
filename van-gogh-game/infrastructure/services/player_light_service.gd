extends Node
class_name PlayerLightService

@export var spotlight: SpotLight3D

func light_on():
	if spotlight: spotlight.visible = true

func light_off():
	if spotlight: spotlight.visible = false
