extends Node

# ==========================================================
# 🌐 EVENTBUS — Sistema Global de Eventos do Jogo
# ==========================================================
# Padrão: Desacopla comunicação entre controllers e views.
# Uso: EventBus.sinal.connect(funcao)
# ==========================================================

# --- DIALOGO ---
signal dialog_started                     # Disparado quando um diálogo começa
signal dialog_ended                       # Disparado quando um diálogo termina

# --- COLETA ---
signal item_collected(id_item: String, item_node: Node3D)   # Quando um item é coletado
signal animation_collect_finished                          # Quando a animação de coleta termina
signal star_count_changed(count: int)                      # Quando número de estrelas muda

# --- ZONA / AMBIENTE ---
signal player_entered_zone(zone_name: String)              # Quando o jogador entra em uma zona
signal zone_changed(zone_name: String)                     # Quando iluminação ou efeito muda

# --- PLAYER / MOVIMENTO ---
signal player_moved(direction: Vector3)                    # Para broadcast de movimento
signal player_stopped                                      # Para broadcast de parada

# --- NPC / INTERAÇÃO ---
signal npc_dropped_item(npc_name: String, id_item: String)
signal npc_dialog_triggered(npc_name: String, timeline: String)

# --- INVENTÁRIO / SISTEMA ---
signal inventory_item_added(item_id: String)
signal inventory_item_removed(item_id: String)
signal inventory_updated                                   # Dispara quando o inventário é atualizado

# --- SISTEMA / GAME MANAGEMENT ---
signal game_paused(is_paused: bool)                  # Disparado quando o jogo é pausado/despausado
signal game_saved                                   # Disparado quando o jogo é salvo com sucesso
signal game_loaded(scene_path: String)              # Disparado após carregar jogo
signal game_reset                                   # Disparado ao resetar o jogo
signal scene_changed(scene_path: String)            # Disparado quando uma nova cena é carregada
signal save_failed(error_msg: String)               # Caso o salvamento falhe

# --- EMISSÕES AUXILIARES ---
func emit_game_paused(is_paused: bool) -> void:
	game_paused.emit(is_paused)

func emit_game_saved() -> void:
	game_saved.emit()

func emit_save_failed(msg: String) -> void:
	save_failed.emit(msg)

func emit_game_loaded(scene_path: String) -> void:
	game_loaded.emit(scene_path)

func emit_scene_changed(scene_path: String) -> void:
	scene_changed.emit(scene_path)

func emit_game_reset() -> void:
	game_reset.emit()

func emit_dialog_started() -> void:
	dialog_started.emit()

func emit_dialog_ended() -> void:
	dialog_ended.emit()

func emit_item_collected(id_item: String, item_node: Node3D) -> void:
	item_collected.emit(id_item, item_node)

func emit_animation_collect_finished() -> void:
	animation_collect_finished.emit()

func emit_star_count_changed(count: int) -> void:
	star_count_changed.emit(count)

func emit_player_entered_zone(zone_name: String) -> void:
	player_entered_zone.emit(zone_name)

func emit_zone_changed(zone_name: String) -> void:
	zone_changed.emit(zone_name)

func emit_inventory_updated() -> void:
	inventory_updated.emit()
	
	
