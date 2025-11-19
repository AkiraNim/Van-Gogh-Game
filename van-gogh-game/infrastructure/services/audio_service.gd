extends Node

@export var fade_duration: float = 2.0

var player_a: AudioStreamPlayer
var player_b: AudioStreamPlayer

var _player_ativo: AudioStreamPlayer
var _musica_atual: AudioStream

func _ready() -> void:
	add_child(AudioStreamPlayer.new())
	add_child(AudioStreamPlayer.new())
	
	player_a = get_child(0); player_a.name = "PlayerA"
	player_b = get_child(1); player_b.name = "PlayerB"
	
	_player_ativo = player_b


func play_music(nova_musica: AudioStream):
	if nova_musica == _musica_atual:
		return
	
	_musica_atual = nova_musica
	
	var player_fade_in = player_a if _player_ativo == player_b else player_b
	var player_fade_out = _player_ativo
	
	_player_ativo = player_fade_in
	
	_fade_out(player_fade_out)
	_fade_in(player_fade_in, nova_musica)


func _fade_in(player: AudioStreamPlayer, musica: AudioStream):
	if not is_instance_valid(player): return
	
	if musica == null:
		_fade_out(player)
		return

	player.stream = musica
	player.volume_db = -80.0
	player.play()
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(player, "volume_db", 0, fade_duration).from(-80.0)

func _fade_out(player: AudioStreamPlayer):
	if not is_instance_valid(player) or not player.playing:
		return

	var tween = create_tween()
	tween.tween_property(player, "volume_db", -80.0, fade_duration)
	
	await tween.finished
	if is_instance_valid(player):
		player.stop()
