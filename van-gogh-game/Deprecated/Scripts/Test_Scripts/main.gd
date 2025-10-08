extends Node3D

var dialogo_esta_ativo: bool = false

func _ready() -> void:
	await get_tree().process_frame

	# Conectamos todos os sinais necessários
	%ZoneManager.player_entrou_na_zona.connect(_on_player_entrou_na_zona)
	%Player_3D.item_coletado.connect(_on_player_item_coletado)
	%DialogManager.animacao_coleta_terminou.connect(_on_animacao_coleta_terminou)
	
	# --- CONEXÕES DE CONTROLE DE ESTADO ---
	# Conecta o Main aos sinais que o DialogManager emite
	%DialogManager.dialogo_iniciou.connect(_on_qualquer_dialogo_comecou)
	%DialogManager.dialogo_terminou.connect(_on_qualquer_dialogo_terminou)
	
	%DialogManager.iniciar_dialogo("Player_NPC_item")


# --- FUNÇÕES QUE ATUALIZAM NOSSO ESTADO ---
func _on_qualquer_dialogo_comecou():
	dialogo_esta_ativo = true

func _on_qualquer_dialogo_terminou():
	dialogo_esta_ativo = false
	%NPCTesteNode.dropar_item("estrela")


# --- FUNÇÕES DE LÓGICA DO JOGO ---
func _on_player_entrou_na_zona(nome_da_zona: String):
	
	return


func _on_player_item_coletado(item_node):
	# Também podemos usar a variável aqui para evitar coletar itens durante um diálogo
	if dialogo_esta_ativo:
		# Opcional: devolve o item ao estado "não coletado" para ser pego depois
		if is_instance_valid(item_node):
			item_node.coletado = false
		return

	
	%Player_3D.segurar_item(item_node)
	%Player_3D.acender_spotlight()
	await %DialogManager.iniciar_animacao_de_coleta(%Player_3D, "Player_item")
	
func _on_animacao_coleta_terminou():
	%Player_3D.apagar_spotlight()
	%Player_3D.destruir_item_segurado()
	%Player_3D.adicionar_estrela()
