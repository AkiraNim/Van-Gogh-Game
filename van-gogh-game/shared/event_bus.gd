extends Node

signal dialog_started                
signal dialog_ended                   

signal item_collected(id_item: String, item_node: Node3D)  
signal animation_collect_finished                          
signal star_count_changed(count: int)                     
signal important_item_collected(item_name: String)

signal player_entered_zone(zone_name: String)
signal player_exited_zone(zone_name: String)  
signal zone_changed(zone_name: String)
signal zone_conquered(zone_name: String)


signal player_moved(direction: Vector3)                    # Para broadcast de movimento
signal player_stopped                                      # Para broadcast de parada
signal player_entered_interactable_area(interactable_node: Node3D)
signal player_exited_interactable_area(interactable_node: Node3D)
signal interaction_started
signal interaction_ended

signal npc_dropped_item(npc_name: String, id_item: String)
signal npc_dialog_triggered(npc_name: String, timeline: String)
signal npc_item_dropped(npc_name: String, item_id: String, item_node) # Node3D
signal npc_item_given(npc_name: String, item_id: String, player)      # PlayerView

signal inventory_item_added(item_id: String)
signal inventory_item_removed(item_id: String)
signal inventory_updated

signal game_paused(is_paused: bool)                  
signal game_saved                                  
signal game_loaded(scene_path: String)              
signal game_reset                                  
signal scene_changed(scene_path: String)            
signal save_failed(error_msg: String)              

func emit_important_item_collected(item_name: String) -> void:
	important_item_collected.emit(item_name)

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

func emit_zone_conquered(zone_name: String) -> void:
	zone_conquered.emit(zone_name)	

func emit_player_exited_zone(zone_name: String) -> void:
	player_exited_zone.emit(zone_name)

func emit_inventory_updated() -> void:
	inventory_updated.emit()

func emit_npc_item_dropped(npc_name: String, item_id: String, item_node: Node) -> void:
	npc_item_dropped.emit(npc_name, item_id, item_node)

func emit_npc_item_given(npc_name: String, item_id: String, player) -> void:
	npc_item_given.emit(npc_name, item_id, player)
