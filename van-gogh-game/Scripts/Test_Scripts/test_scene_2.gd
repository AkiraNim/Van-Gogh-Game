# Main.gd (Versão final e limpa)
extends Node3D

@export var zone_manager: Node3D
@export var dialog_manager: Node3D

# A função _ready agora é 'assíncrona' para podermos usar 'await'
func _ready() -> void:
	# Pausa a execução por um frame para garantir que tudo na cena esteja pronto
	await get_tree().process_frame

	# Verificação de segurança
	if not zone_manager or not dialog_manager:
		print("ERRO CRÍTICO no Main.gd: Nós ZoneManager ou DialogManager não foram conectados no inspetor.")
		return

	# Conecta os sinais
	
	zone_manager.player_entrou_na_zona.connect(_on_player_entrou_na_zona)
	print("Managers conectados com sucesso!")


func _on_player_entrou_na_zona(nome_da_zona: String):
	print("Player entrou na zona: ", nome_da_zona)
	
	match nome_da_zona:
		"neutra":
			dialog_manager.iniciar_dialogo("Timeline_teste")
