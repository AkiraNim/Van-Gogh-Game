extends Node

signal dialogic_lock_animation(name: String, duration: float)
signal dialogic_unlock_animation()
signal npc_lock_animation(key: String, name: String, duration: float)
signal npc_unlock_animation(key: String)

var _hooked := {}  # Set-like: { RID/instance_id: true }

func _ready() -> void:
	add_to_group("dialog_bridge")
	# 1) tenta conectar no autoload/nó principal do Dialogic
	_connect_dialogic_signals()
	# 2) passa a hookar dinamicamente qqr nó que entre e tenha os sinais
	get_tree().connect("node_added", Callable(self, "_on_node_added"))
	# 3) varre nós já existentes (cenas carregadas antes do bridge)
	for n in get_tree().get_nodes_in_group("root"): # group 'root' pode não existir; então varremos manualmente
		_try_hook_node(n)
	# fallback: varredura genérica
	for n in get_tree().get_nodes_in_group("**"): # não existe curinga, então ignore se seu Godot reclamar
		_try_hook_node(n)
	# varredura manual simples (é leve):
	for n in get_tree().get_nodes_in_group("dialogic"):
		_try_hook_node(n)
	for n in get_tree().get_nodes_in_group("Dialogic"):
		_try_hook_node(n)
	# e todos os nós existentes na raiz
	for n in get_tree().get_root().get_children():
		_try_hook_node(n)

func _get_dialogic() -> Object:
	if Engine.has_singleton("Dialogic"):
		return Engine.get_singleton("Dialogic")
	if has_node("/root/Dialogic"):
		return get_node("/root/Dialogic")
	return null

func _connect_dialogic_signals() -> void:
	var D := _get_dialogic()
	if D != null:
		_try_hook_node(D)
	else:
		push_warning("Dialogic não encontrado (autoload). Bridge continuará tentando via node_added.")

func _on_node_added(n: Node) -> void:
	_try_hook_node(n)
	# também tenta hookar filhos relevantes que forem criados prontos (ex.: DialogicGameHandler dentro de um CanvasLayer)
	for c in n.get_children():
		if c is Node:
			_try_hook_node(c)

func _try_hook_node(n: Node) -> void:
	if n == null: return
	# evita reconectar
	var key := n.get_instance_id()
	if _hooked.has(key):
		return

	# Heurísticas: qualquer nó que tenha 'signal' / 'signal_event' (DialogicGameHandler, DialogicNode, etc.)
	var hooked := false
	if n.has_signal("signal"):
		n.connect("signal", Callable(self, "_on_dialogic_signal_single"))
		hooked = true
	if n.has_signal("signal_event"):
		n.connect("signal_event", Callable(self, "_on_dialogic_signal_name_args"))
		hooked = true
	if n.has_signal("timeline_started"):
		n.connect("timeline_started", Callable(self, "_on_dialogic_timeline_started"))
	if n.has_signal("timeline_ended"):
		n.connect("timeline_ended", Callable(self, "_on_dialogic_timeline_ended"))

	if hooked:
		_hooked[key] = true
		print("🔌 DialogicBridge hooked em nó:", n.name, "classe:", n.get_class())

# ——— Handlers ———

func _on_dialogic_signal_single(arg: Variant) -> void:
	# ex.: [signal arg="lock_anim:walking_down:0.25"]
	_route_dialogic_signal(arg, null)

func _on_dialogic_signal_name_args(name: Variant, args: Variant = null) -> void:
	# ex.: name="lock_anim", args={"name":"walking_down","duration":0.25}
	_route_dialogic_signal(name, args)

func _receive_timeline_signal(signal_name: String, value: Variant = null) -> void:
	# Fallback para Call Node a partir da Timeline
	_route_dialogic_signal(signal_name, value)

func _route_dialogic_signal(name_v: Variant, payload: Variant) -> void:
	var sig := ""
	if typeof(name_v) == TYPE_STRING:
		sig = String(name_v).strip_edges()
	elif typeof(name_v) == TYPE_DICTIONARY and name_v.has("arg"):
		sig = String(name_v["arg"]).strip_edges()
	elif typeof(payload) == TYPE_DICTIONARY and payload.has("arg"):
		sig = String(payload["arg"]).strip_edges()

	if sig == "":
		return

	# -------------------------
	# lock_anim: parser robusto
	# -------------------------
	if sig.begins_with("lock_anim"):
		var anim_name := "idle_down"
		var duration := 0.25

		# 1) formato comum: "lock_anim:NAME:DUR"
		var parts := sig.split(":")
		if parts.size() >= 2:
			anim_name = parts[1].strip_edges()
		if parts.size() >= 3:
			var dur_txt := parts[2].strip_edges().replace(",", ".")
			var dur_try := dur_txt.to_float()
			if dur_try > 0.0:
				duration = dur_try

		# 2) CASOS COLADOS dentro do "anim_name"
		#    cobre "walking_down0.25" e "idle_downdur=1.0"
		if parts.size() == 2:
			# primeiro tenta "dur=" explícito
			var dur_idx := anim_name.find("dur=")
			if dur_idx >= 0:
				var base := anim_name.substr(0, dur_idx).strip_edges()
				var dtxt := anim_name.substr(dur_idx + 4).strip_edges().replace(",", ".")
				var dval := dtxt.to_float()
				if base != "":
					anim_name = base
				if dval > 0.0:
					duration = dval
			else:
				# tenta pegar qualquer número decimal colado ao final
				var rx := RegEx.new()
				rx.compile("^(.*?)([0-9]+(?:\\.[0-9]+)?)$")
				var m := rx.search(anim_name)
				if m:
					var base2 := m.get_string(1).strip_edges()
					var dtxt2 := m.get_string(2).strip_edges().replace(",", ".")
					var dval2 := dtxt2.to_float()
					if base2 != "":
						anim_name = base2
					if dval2 > 0.0:
						duration = dval2

		# 3) payload opcional (dicionário)
		if typeof(payload) == TYPE_DICTIONARY:
			if payload.has("name"):
				anim_name = String(payload["name"]).strip_edges()
			if payload.has("duration"):
				var d := String(payload["duration"]).replace(",", ".").to_float()
				if d > 0.0:
					duration = d

		print("🔔 DialogicBridge → lock (parsed):", anim_name, "dur=", duration)
		emit_signal("dialogic_lock_animation", anim_name, duration)
		return

	# -------------------------
	# unlock_anim
	# -------------------------
	if sig == "unlock_anim":
		print("🔔 DialogicBridge → unlock")
		emit_signal("dialogic_unlock_animation")
		return
# 3) npc_lock:<key>:<anim>:<dur>  (aceita variações com vírgula e dur=)
	if sig.begins_with("npc_lock"):
		var npc_key := ""
		var anim_name := "idle_down"
		var duration := 0.25
		var parts := sig.split(":")
		if parts.size() >= 2: npc_key = parts[1].strip_edges()
		if parts.size() >= 3: anim_name = parts[2].strip_edges()
		if parts.size() >= 4:
			var dt := parts[3].strip_edges().replace(",", ".")
			if dt.begins_with("dur="): dt = dt.substr(4)
			var dv := dt.to_float()
			if dv > 0.0: duration = dv
		print("🔔 DialogicBridge → npc_lock key=", npc_key, " anim=", anim_name, " dur=", duration)
		emit_signal("npc_lock_animation", npc_key, anim_name, duration)
		return

	# 4) npc_unlock:<key>
	if sig.begins_with("npc_unlock"):
		var npc_key := ""
		var parts := sig.split(":")
		if parts.size() >= 2: npc_key = parts[1].strip_edges()
		print("🔔 DialogicBridge → npc_unlock key=", npc_key)
		emit_signal("npc_unlock_animation", npc_key)
		return
