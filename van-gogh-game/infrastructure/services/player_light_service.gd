extends Node
class_name PlayerLightService

@export var spotlight: SpotLight3D

func ligar():
	if spotlight: spotlight.visible = true

func desligar():
	if spotlight: spotlight.visible = false
