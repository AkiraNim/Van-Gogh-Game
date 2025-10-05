extends Node3D

func _ready() -> void:
	await get_tree().process_frame

	%ZoneManager.player_entrou_na_zona.connect(_on_player_entrou_na_zona)
	%Player_3D.item_coletado.connect(_on_player_item_coletado)
	%DialogManager.animacao_coleta_terminou.connect(_on_animacao_coleta_terminou)
	print("Managers e Player conectados com sucesso via Nomes Únicos!")


func _on_player_entrou_na_zona(nome_da_zona: String):
	
	return


func _on_player_item_coletado(item_node):
	print("MainManager notificado que o jogador pegou: ", item_node.name)
	
	%Player_3D.segurar_item(item_node)
	%Player_3D.acender_spotlight()
	
	await %DialogManager.iniciar_animacao_de_coleta(%Player_3D, "Player_item")
	

func _on_animacao_coleta_terminou():
	%Player_3D.apagar_spotlight()
	%Player_3D.destruir_item_segurado()
	%Player_3D.adicionar_estrela()
