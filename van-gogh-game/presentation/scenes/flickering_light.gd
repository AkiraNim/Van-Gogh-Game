extends SpotLight3D

@export var animation_player: AnimationPlayer

@onready var timer = %Timer

func _ready():
	timer.timeout.connect(_on_timer_timeout)
	
	_play_flicker_animation()

func _play_flicker_animation():

	animation_player.play("flashing_light")
	
	await animation_player.animation_finished
	
	_start_random_wait_timer()

func _start_random_wait_timer():
	var wait_time = randf_range(15.0, 20.0)
	
	timer.wait_time = wait_time
	timer.start()

func _on_timer_timeout():
	_play_flicker_animation()
