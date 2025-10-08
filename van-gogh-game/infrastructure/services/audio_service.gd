extends Node
class_name AudioService

@export var bgm_player: AudioStreamPlayer
@export var sfx_player: AudioStreamPlayer

func play_bgm(stream: AudioStream) -> void:
	if not bgm_player:
		return
	bgm_player.stream = stream
	bgm_player.play()

func play_sfx(stream: AudioStream) -> void:
	if not sfx_player:
		return
	sfx_player.stream = stream
	sfx_player.play()

func set_volume_db(volume_db: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), volume_db)
