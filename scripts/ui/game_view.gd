extends Control
## Vista della partita: il tavolo (Board3D) con la HUD. A sinistra i casati, a destra la plancia dei
## personaggi con le istruzioni della mossa e il registro; in alto turno, fase e comandi della vista.

var main
var config: Dictionary
var engine: SKEngine
var board: Board3D
var online = null
var humans: Array = []
var pending: Dictionary = {}
var last_human := -1

# costruzione della mossa del turno
var sel: Dictionary = {}
var step := ""

# HUD
var top_lbl: Label
var phase_lbl: Label
var online_lbl: Label
var left_box: VBoxContainer
var cards_box: VBoxContainer
var prompt_box: VBoxContainer
var log_box: RichTextLabel
var tip: PanelContainer
var tip_lbl: RichTextLabel
var modal: Control
var toast_box: VBoxContainer
var btn_map: Button
var btn_pcs: Button
var _refresh_queued := false
# barra di stato: cosa è appena successo, con «Avanti»
var status_pc: PanelContainer
var status_title: Label
var status_txt: RichTextLabel
var btn_next: Button
var btn_auto: Button
var auto_next := false
var pause_regs: Array = []
var house_boxes := {}
var res_nodes := {}
signal next_pressed
var game_done := false
var tutorial = null
# fase dei progetti (variante dell'Alchimista)
var psel: Dictionary = {}
var pstep := ""

const LW := 300.0
const RW := 480.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	online = config.get("online", null)
	UI.cmap = config.get("colors", [0, 1, 2, 3])
	engine = SKEngine.new()
	add_child(engine)
	engine.setup(config)
	engine.ai_delay = config.get("ai_delay", 0.7)
	if online != null:
		humans = [online.seat]
		online.view = self
		add_child(online)
		engine.online = online
		if online.role != "host":
			online.heartbeat_loop()
	else:
		for p in engine.players.size():
			if not engine.players[p]["ai"]:
				humans.append(p)
	board = Board3D.new()
	board.eng = engine
	board.map3d = config.get("map3d", true)
	board.pieces3d = config.get("pieces3d", true)
	add_child(board)
	board.region_clicked.connect(_on_region)
	board.site_clicked.connect(_on_site)
	board.hovered.connect(_on_hover)
	board.info_requested.connect(_on_info)
	_build_top()
	_build_left()
	_build_right()
	_build_cam()
	_build_status()
	engine.pause_cb = _on_pause
	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(LW + 30, 74)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_theme_constant_override("separation", 6)
	add_child(toast_box)
	tip = PanelContainer.new()
	tip.add_theme_stylebox_override("panel", UI.flat(Color(0.05, 0.08, 0.15, 0.95), UI.GOLD, 1, 6, 10))
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_lbl = UI.rich(17)
	tip_lbl.custom_minimum_size = Vector2(300, 0)
	tip_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.add_child(tip_lbl)
	tip.visible = false
	add_child(tip)
	modal = Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal)
	if config.get("tutorial", false):
		tutorial = preload("res://scripts/ui/tutorial.gd").new()
		tutorial.gv = self
		add_child(tutorial)
	engine.changed.connect(_queue_refresh)
	engine.log_added.connect(_on_log)
	engine.decision_requested.connect(_on_decision)
	engine.game_ended.connect(_on_game_end)
	engine.phase_changed.connect(_on_phase)
	get_viewport().size_changed.connect(_layout)
	_layout()
	refresh()
	_start.call_deferred()


func _start() -> void:
	if online != null and not online.backlog.is_empty():
		Audio.suspended = true
		online_status("Riprendo la partita…")
	if tutorial != null:
		auto_next = false
		_paint_auto()
		await tutorial.intro()
	await engine.run()


func _exit_tree() -> void:
	engine.abort = true
	Audio.suspended = false


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouse or ev is InputEventGesture:
		board.handle_input(ev)
	if ev is InputEventMouseMotion:
		if tip.visible:
			_place_tip()


func _layout() -> void:
	var vp := get_viewport_rect().size
	size = vp
	# il centro della mappa sta fra i due pannelli
	board.view_offset = Vector2((RW - LW) / 2.0 / 100.0, 0.0)
	board._update_cam()


# ------------------------------------------------------------------ costruzione HUD

func _panel(dark := true) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.night(0.9) if dark else UI.parchment(14))
	return pc


func _build_top() -> void:
	var bar := _panel()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 58
	bar.add_theme_stylebox_override("panel", UI.flat(Color(0.05, 0.08, 0.15, 0.92), UI.GOLD_DARK, 0, 0, 8))
	add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	bar.add_child(hb)
	var t := UI.label("Seven Kingdom", 30, UI.GOLD, UI.font_deco)
	hb.add_child(t)
	top_lbl = UI.label("", 20, UI.LIGHT, UI.font_title)
	hb.add_child(top_lbl)
	phase_lbl = UI.label("", 20, UI.GOLD, UI.font_italic)
	phase_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(phase_lbl)
	online_lbl = UI.label("", 17, UI.GOLD, UI.font_bold)
	online_lbl.visible = online != null
	hb.add_child(online_lbl)
	btn_map = UI.button("", 130, 40, 14)
	btn_map.pressed.connect(func():
		board.set_modes(not board.map3d, board.pieces3d)
		_paint_view_buttons())
	hb.add_child(btn_map)
	btn_pcs = UI.button("", 130, 40, 14)
	btn_pcs.pressed.connect(func():
		board.set_modes(board.map3d, not board.pieces3d)
		_paint_view_buttons())
	hb.add_child(btn_pcs)
	_paint_view_buttons()
	var rb := UI.button("Regole", 100, 40, 14)
	rb.pressed.connect(_show_rules_popup)
	hb.add_child(rb)
	hb.add_child(Audio.toggle_button("music", 100, 40))
	hb.add_child(Audio.toggle_button("sfx", 100, 40))
	var mb := UI.button("Menu", 90, 40, 14)
	mb.pressed.connect(_ask_quit)
	hb.add_child(mb)


func _paint_view_buttons() -> void:
	btn_map.text = "Mappa 3D" if board.map3d else "Mappa 2D"
	btn_pcs.text = "Pedine 3D" if board.pieces3d else "Pedine 2D"
	btn_map.tooltip_text = "Passa alla mappa " + ("piatta vista dall'alto" if board.map3d else "in rilievo, girevole")
	btn_pcs.tooltip_text = "Passa alle pedine " + ("disegnate" if board.pieces3d else "in miniatura 3D")


func _build_left() -> void:
	var pc := _panel()
	pc.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	pc.offset_top = 66
	pc.offset_right = LW
	pc.offset_bottom = -8
	pc.offset_left = 8
	add_child(pc)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(sc)
	left_box = VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 10)
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(left_box)


func _build_right() -> void:
	var pc := _panel()
	pc.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	pc.offset_top = 66
	pc.offset_left = -RW
	pc.offset_right = -8
	pc.offset_bottom = -8
	add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pc.add_child(vb)
	vb.add_child(UI.title("I personaggi", 22))
	cards_box = VBoxContainer.new()
	cards_box.add_theme_constant_override("separation", 4)
	vb.add_child(cards_box)
	var ps := ScrollContainer.new()
	ps.custom_minimum_size = Vector2(0, 160)
	ps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ps.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(ps)
	prompt_box = VBoxContainer.new()
	prompt_box.add_theme_constant_override("separation", 8)
	prompt_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ps.add_child(prompt_box)
	vb.add_child(UI.title("Cronaca", 16))
	var ls := ScrollContainer.new()
	ls.custom_minimum_size = Vector2(0, 120)
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(ls)
	log_box = UI.rich(16, Color("#e6dcc3"))
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ls.add_child(log_box)
	log_box.set_meta("scroll", ls)


const VIEW_CFG := "user://vista.cfg"


func _build_status() -> void:
	var c := ConfigFile.new()
	if c.load(VIEW_CFG) == OK:
		auto_next = bool(c.get_value("v", "auto", false))
	status_pc = PanelContainer.new()
	status_pc.add_theme_stylebox_override("panel", UI.flat(Color(0.05, 0.08, 0.15, 0.94), UI.GOLD, 2, 10, 12))
	status_pc.anchor_left = 0.0
	status_pc.anchor_right = 1.0
	status_pc.anchor_top = 1.0
	status_pc.anchor_bottom = 1.0
	status_pc.offset_left = LW + 20
	status_pc.offset_right = -RW - 20
	status_pc.offset_bottom = -64
	status_pc.offset_top = -64
	status_pc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	status_pc.visible = false
	add_child(status_pc)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	status_pc.add_child(hb)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	hb.add_child(vb)
	status_title = UI.label("", 20, UI.GOLD, UI.font_title)
	vb.add_child(status_title)
	status_txt = UI.rich(17, UI.LIGHT)
	status_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(status_txt)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	hb.add_child(bv)
	btn_next = UI.primary(UI.button("Avanti ›", 150, 46, 18))
	btn_next.tooltip_text = "Continua la partita (anche con Invio o Spazio)"
	btn_next.pressed.connect(func(): next_pressed.emit())
	bv.add_child(btn_next)
	btn_auto = UI.button("", 150, 34, 12)
	btn_auto.pressed.connect(func():
		auto_next = not auto_next
		var cf := ConfigFile.new()
		cf.set_value("v", "auto", auto_next)
		cf.save(VIEW_CFG)
		_paint_auto()
		if auto_next:
			next_pressed.emit())
	bv.add_child(btn_auto)
	_paint_auto()


func _paint_auto() -> void:
	btn_auto.text = "Automatico: sì" if auto_next else "Automatico: no"
	btn_auto.tooltip_text = "Sì: la partita va avanti da sola, senza fermarsi dopo ogni mossa degli avversari."


func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and (ev.keycode == KEY_ENTER or ev.keycode == KEY_SPACE or ev.keycode == KEY_KP_ENTER):
		if btn_next.visible and status_pc.visible:
			next_pressed.emit()


## Mostra cosa è appena successo e, se non è automatico, aspetta «Avanti».
func _on_pause(kind: String, who: int, lines: Array, regs: Array) -> void:
	if online != null and online.catchup:
		return
	if game_done:
		return
	var shown := []
	for l in lines:
		var t: String = l
		if t.begins_with("—") or t == "Azioni passive dei personaggi.":
			continue
		shown.append(t)
	if shown.is_empty():
		return
	var title := ""
	var mine := false
	match kind:
		"move":
			var c := ""
			for k in engine.st.used:
				if engine.st.used[k] == who:
					c = k
			title = "%s — %s" % [engine.pname(who), SKData.cn(c) if c != "" else "mossa"]
			mine = _is_local(who)
		"passive":
			title = "Azioni passive dei personaggi"
		"end":
			title = "Fine del turno %d" % engine.st.turn
		"setup":
			title = "Piazzamento iniziale completato"
	status_title.text = title
	status_title.add_theme_color_override("font_color", UI.plight(who) if kind == "move" else UI.GOLD)
	status_txt.text = ""
	for t in shown:
		var col := "#efe4c9"
		if t.contains("GUERRA") or t.contains("Invasione") or t.contains("invasore") or t.contains("Sconfitta"):
			col = "#ff9f8f"
		elif t.contains("VITTORIA") or t.contains("Favore") or t.contains("Corona"):
			col = "#ffe08a"
		status_txt.append_text("[color=%s]• %s[/color]\n" % [col, t])
	status_pc.visible = true
	pause_regs = regs
	_apply_highlight()
	if mine:
		btn_next.visible = false
		pause_regs = []
		return
	btn_next.visible = true
	if tutorial != null and await tutorial.on_pause(kind):
		btn_next.visible = false
		pause_regs = []
		_apply_highlight()
		return
	if auto_next:
		if engine.ai_delay > 0.01:
			await get_tree().create_timer(maxf(1.0, engine.ai_delay * 1.6)).timeout
	else:
		await next_pressed
	btn_next.visible = false
	pause_regs = []
	_apply_highlight()


func _build_cam() -> void:
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hb.position = Vector2(LW + 20, 0)
	hb.add_theme_constant_override("separation", 6)
	add_child(hb)
	hb.anchor_top = 1.0
	hb.anchor_bottom = 1.0
	hb.offset_top = -56
	hb.offset_bottom = -12
	hb.offset_left = LW + 20
	for b in [["‹", func(): board.rotate_view(-30)], ["›", func(): board.rotate_view(30)], ["+", func(): board.zoom(0.85)], ["−", func(): board.zoom(1.18)], ["Centra", func(): board.reset_view()]]:
		var bt := UI.button(b[0], 52 if b[0] != "Centra" else 96, 42, 22)
		bt.pressed.connect(b[1])
		bt.tooltip_text = {"‹": "Ruota a sinistra", "›": "Ruota a destra", "+": "Avvicina", "−": "Allontana", "Centra": "Torna alla vista iniziale"}[b[0]]
		hb.add_child(bt)


# ------------------------------------------------------------------ aggiornamento

func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_do_refresh.call_deferred()


func _do_refresh() -> void:
	_refresh_queued = false
	refresh()


func refresh() -> void:
	var st: SKState = engine.st
	_play_events()
	board.refresh(not (online != null and online.catchup))
	var ph: String = engine.phase
	top_lbl.text = "Turno %d" % (st.turn + 1) if ph != "preparazione" and ph != "obiettivi" else "Preparazione"
	var who := ""
	if engine.cur >= 0:
		who = " — tocca a %s" % engine.pname(engine.cur)
	phase_lbl.text = {"obiettivi": "Scelta degli obiettivi", "preparazione": "Piazzamento iniziale", "azioni": "Azioni dei giocatori", "passive": "Azioni passive dei personaggi", "fine turno": "Fine del turno", "fine": "Partita conclusa"}.get(ph, ph) + who + "   ·   Guerre %d/3 · Regni in pace %d/3" % [st.war_count(), st.peace_count()]
	_refresh_left()
	_refresh_cards()
	_apply_highlight()
	if tutorial != null and not pending.is_empty():
		tutorial.on_step(step)


func _refresh_left() -> void:
	var st: SKState = engine.st
	for c in left_box.get_children():
		c.queue_free()
	left_box.add_child(UI.title("I casati", 22))
	house_boxes = {}
	res_nodes = {}
	var picking_col: bool = step in ["king", "king_pw"]
	var picking_res: bool = step == "merch" or (step == "proj" and pstep == "res")
	var order := []
	for k in st.n:
		order.append((st.first + k) % st.n)
	for p in order:
		var pc := PanelContainer.new()
		var border := UI.pcol(p).lightened(0.2) if p != engine.cur else UI.GOLD
		var bw := 3 if p == engine.cur else 2
		if picking_col and int(sel.get("color", -1)) == p:
			border = Color("#fff3b0")
			bw = 5
		pc.add_theme_stylebox_override("panel", UI.flat(UI.pcol(p).darkened(0.62), border, bw, 8, 8))
		house_boxes[p] = pc
		var hp: int = p
		pc.gui_input.connect(func(ev):
			if _is_click(ev):
				_on_house(hp))
		if picking_col and st.reserve[p] > 0:
			pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			pc.tooltip_text = "Tocca per mettere villaggi di questo colore"
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 4)
		pc.add_child(vb)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		hb.add_child(UI.icon("res://assets/tokens/villaggio_%s.webp" % UI.cid(p), 38))
		var nm := UI.label(engine.pname(p), 19, UI.LIGHT, UI.font_title)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		hb.add_child(nm)
		if st.first == p:
			var cr := UI.icon("res://assets/tokens/corona.webp", 32)
			cr.tooltip_text = "Corona: Primo Giocatore (+2 PV a fine partita, +1 in battaglia)"
			hb.add_child(cr)
		if st.favor[p]:
			var fv := UI.icon("res://assets/tokens/favore.webp", 32)
			fv.tooltip_text = "Favore Papale: permette un'azione potenziata (+2 PV se lo tieni fino alla fine)"
			hb.add_child(fv)
		var sc := UI.label("%d PV" % st.score(p, false), 26, UI.GOLD, UI.font_title)
		sc.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		sc.add_theme_constant_override("outline_size", 4)
		sc.tooltip_text = _score_tip(p)
		sc.mouse_filter = Control.MOUSE_FILTER_PASS
		hb.add_child(sc)
		vb.add_child(hb)
		var info := HBoxContainer.new()
		info.add_theme_constant_override("separation", 10)
		var tag := "IA %s" % ["facile", "normale", "difficile"][engine.players[p].get("level", 1)] if engine.players[p]["ai"] else "umano"
		if online != null and p == online.seat:
			tag = "tu"
		info.add_child(UI.label(tag, 15, UI.PARCH.darkened(0.15), UI.font_italic))
		var vil := HBoxContainer.new()
		vil.add_theme_constant_override("separation", 2)
		vil.add_child(UI.icon("res://assets/tokens/villaggio_%s.webp" % UI.cid(p), 22))
		vil.add_child(UI.label(str(st.reserve[p]), 16, UI.LIGHT, UI.font_bold))
		vil.tooltip_text = "Villaggi ancora in riserva"
		vil.mouse_filter = Control.MOUSE_FILTER_PASS
		info.add_child(vil)
		var bis := HBoxContainer.new()
		bis.add_theme_constant_override("separation", 2)
		bis.add_child(UI.icon("res://assets/tokens/vescovo_%s.webp" % UI.cid(p), 22))
		bis.add_child(UI.label(str(st.bishops[p]), 16, UI.LIGHT, UI.font_bold))
		bis.tooltip_text = "Vescovi ancora da nominare"
		bis.mouse_filter = Control.MOUSE_FILTER_PASS
		info.add_child(bis)
		vb.add_child(info)
		# le risorse: una fila per tipo, tante icone quante ne ha, e il numero in fondo
		var rs := VBoxContainer.new()
		rs.add_theme_constant_override("separation", 0)
		res_nodes[p] = {}
		for t in SKData.RESOURCES:
			var n_have: int = st.res[p][t]
			var mine_pick := 0
			if picking_res and int(sel.get("from", -1)) == p:
				mine_pick = sel["res"].count(t)
			var shown := n_have - mine_pick
			var holder := PanelContainer.new()
			var can: bool = picking_res and p != _me() and shown > 0
			holder.add_theme_stylebox_override("panel", UI.flat(Color(1, 0.85, 0.3, 0.22) if can else Color(0, 0, 0, 0), Color("#ffd86a") if can else Color(0, 0, 0, 0), 2 if can else 0, 5, 1))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", -3)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(row)
			for k in maxi(1, shown):
				var ic := UI.icon("res://assets/res/%s.webp" % t, 21)
				ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
				if shown == 0:
					ic.modulate = Color(1, 1, 1, 0.22)
				row.add_child(ic)
			var gap := Control.new()
			gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(gap)
			var num := UI.label(str(shown), 17, UI.LIGHT if shown > 0 else UI.PARCH.darkened(0.4), UI.font_bold)
			num.custom_minimum_size = Vector2(22, 0)
			num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			num.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(num)
			holder.tooltip_text = SKData.RES_NAME[t] + (" — tocca per rubarne una" if can else "")
			if can:
				holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var tt: String = t
			holder.gui_input.connect(func(ev):
				if _is_click(ev):
					_on_house_res(hp, tt)
					holder.accept_event())
			res_nodes[p][t] = holder
			rs.add_child(holder)
		vb.add_child(rs)
		if st.alch() and int(st.jolly[p]) > 0:
			var jl := UI.label("Jolly: %d (vale come qualsiasi risorsa)" % int(st.jolly[p]), 14, UI.GOLD, UI.font_bold)
			vb.add_child(jl)
		if st.alch():
			vb.add_child(_house_projects(p))
		if picking_res and int(sel.get("from", -1)) == p and not sel["res"].is_empty():
			var tk := HBoxContainer.new()
			tk.add_child(UI.label("Rubate:", 14, UI.GOLD, UI.font_italic))
			for t2 in sel["res"]:
				tk.add_child(UI.res_chip(t2, 1, 20))
			vb.add_child(tk)
		if _can_see_objective(p) and st.objectives[p] != "":
			var ob := UI.button("Obiettivo: " + SKData.obj_name(st.objectives[p]), 260, 32, 12)
			ob.clip_text = true
			ob.tooltip_text = SKData.obj_text(st.objectives[p]) + "\n(ora varrebbe %d PV)" % st.objective_points(p, st.objectives[p])
			var pp: int = p
			ob.pressed.connect(func(): _show_objective(pp))
			vb.add_child(ob)
		left_box.add_child(pc)
	var leg := UI.wrap("Punti stimati senza obiettivi segreti. Tasto destro su un regno per i dettagli.", 15, UI.PARCH.darkened(0.25), 260, UI.font_italic)
	left_box.add_child(leg)


func _score_tip(p: int) -> String:
	var d: Dictionary = engine.st.score_detail(p, false)
	if engine.st.alch():
		return "Villaggi %d · Governatori %d · Vescovi %d · Progetti %d · Corona %d · Favore %d" % [d["villaggi"], d["gov"], d["vescovi"], d["progetti"], d["corona"], d["favore"]]
	return "Villaggi %d · Governatori %d · Vescovi %d · Risorse %d · Corona %d · Favore %d" % [d["villaggi"], d["gov"], d["vescovi"], d["risorse"], d["corona"], d["favore"]]


func _can_see_objective(p: int) -> bool:
	if engine.st.game_over:
		return true
	if online != null:
		return p == online.seat
	if humans.size() == 1:
		return p == humans[0]
	return p == engine.cur and humans.has(p)


func _viewer() -> int:
	if pending.get("type", "") == "turn":
		return _me()
	if online != null:
		return online.seat
	return humans[0] if not humans.is_empty() else -1


func _refresh_cards() -> void:
	var st: SKState = engine.st
	for c in cards_box.get_children():
		c.queue_free()
	var my_turn: bool = pending.get("type", "") == "turn"
	var me := _viewer()
	var fav: bool = me >= 0 and st.favor[me]
	for c in SKData.CHARS:
		var used: bool = st.used.has(c)
		var chosen: bool = sel.get("c", "") == c
		var lit: bool = my_turn and not used
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		# ritratto con nome e regno
		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(92, 84)
		pc.add_theme_stylebox_override("panel", UI.flat(Color(0.08, 0.1, 0.16), UI.GOLD if chosen else (Color("#e9c766") if lit else Color(0.3, 0.3, 0.3)), 3 if chosen else (2 if lit else 1), 6, 2))
		pc.mouse_filter = Control.MOUSE_FILTER_STOP
		pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var art := TextureRect.new()
		art.texture = UI.tex(SKData.cart(c))
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if used:
			art.modulate = Color(0.35, 0.35, 0.35)
		pc.add_child(art)
		var cap := VBoxContainer.new()
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.alignment = BoxContainer.ALIGNMENT_END
		pc.add_child(cap)
		var nm := UI.label(SKData.cshort(c), 14, UI.GOLD if not used else Color(0.6, 0.6, 0.6), UI.font_title)
		nm.add_theme_color_override("font_outline_color", Color.BLACK)
		nm.add_theme_constant_override("outline_size", 5)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.add_child(nm)
		var wh := UI.label(SKData.TILES[st.regions[st.chars[c]]["tile"]]["short"], 12, UI.LIGHT, UI.font_italic)
		wh.add_theme_color_override("font_outline_color", Color.BLACK)
		wh.add_theme_constant_override("outline_size", 4)
		wh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.add_child(wh)
		if used:
			var mk := UI.icon("res://assets/tokens/azione_%s.webp" % UI.cid(st.used[c]), 40)
			mk.set_anchors_preset(Control.PRESET_CENTER)
			pc.add_child(mk)
		var cc: String = c
		pc.gui_input.connect(func(ev): if _is_click(ev): _pick_char(cc, false))
		row.add_child(pc)
		# i tre riquadri delle azioni
		var pw_ok: bool = fav and not used
		var boxes := [["Normale", SKData.cbrief(c)[0], lit, false],
			["Potenziata", SKData.cbrief(c)[1], lit and pw_ok, true],
			["Passiva", SKData.cpassive(c), false, false]]
		for bx in boxes:
			var on: bool = bx[2]
			var is_sel: bool = chosen and bx[0] != "Passiva" and sel.get("pw", false) == bx[3]
			var bp := PanelContainer.new()
			bp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bp.custom_minimum_size = Vector2(0, 84)
			var bgc := Color(0.12, 0.17, 0.29) if on else Color(0.08, 0.09, 0.12)
			if bx[0] == "Passiva":
				bgc = Color(0.1, 0.12, 0.16)
			if bx[3] and pw_ok:
				bgc = Color(0.25, 0.19, 0.08) if on else Color(0.14, 0.11, 0.06)
			var brd := UI.GOLD if is_sel else (Color("#e9c766") if on else Color(0.28, 0.28, 0.3))
			bp.add_theme_stylebox_override("panel", UI.flat(bgc, brd, 3 if is_sel else 1, 6, 5))
			var vb := VBoxContainer.new()
			vb.add_theme_constant_override("separation", 1)
			vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bp.add_child(vb)
			var tcol := UI.GOLD if bx[0] != "Passiva" else Color("#a9c4ff")
			if used or (bx[3] and not pw_ok):
				tcol = Color(0.5, 0.5, 0.5)
			var tl := UI.label(bx[0] + (" ✦" if bx[3] else ""), 12, tcol, UI.font_title)
			tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(tl)
			var tx := UI.wrap(bx[1], 12, UI.LIGHT if not (used or (bx[3] and not pw_ok)) else Color(0.5, 0.5, 0.5), 108)
			tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(tx)
			if bx[0] != "Passiva":
				bp.mouse_filter = Control.MOUSE_FILTER_STOP
				if on:
					bp.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				var pwv: bool = bx[3]
				bp.gui_input.connect(func(ev): if _is_click(ev): _pick_char(cc, pwv))
			row.add_child(bp)
		cards_box.add_child(row)


func _is_click(ev: InputEvent) -> bool:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		Audio.play("click", -6.0)
		return true
	return false


var _ev_seen := 0

func _play_events() -> void:
	var st: SKState = engine.st
	if st.events.size() < _ev_seen:
		_ev_seen = 0
	if st.events.size() == _ev_seen:
		return
	var sounds := {}
	var flights := []
	if tutorial != null:
		tutorial.on_events(st.events.slice(_ev_seen))
	var anim: bool = not (online != null and online.catchup) and _ev_seen > 0
	for e in st.events.slice(_ev_seen):
		if anim and e["k"] == "res":
			flights.append({"t": e["t"], "from_site": [int(e["r"]), int(e["i"])], "to": int(e["p"])})
		elif anim and e["k"] == "steal":
			var k := 0
			for t in e["res"]:
				flights.append({"t": t, "from_house": [int(e["from"]), t], "to": int(e["to"]), "delay": 0.15 * k})
				k += 1
		match e["k"]:
			"place", "inv": sounds["pawn"] = true
			"res": sounds["coin"] = true
			"war": sounds["cannon"] = true
			"battle":
				sounds["dice"] = true
				if e.get("win", false):
					sounds["win"] = true
			"crown", "favor": sounds["bell"] = true
			"move": sounds["voyage"] = true
			"steal": sounds["market"] = true
	_ev_seen = st.events.size()
	for s in sounds:
		Audio.play(s, -4.0)
	if not flights.is_empty():
		_fly_resources(flights)


## Le risorse «saltano» dal sito della mappa (o dal riquadro del derubato) al riquadro del casato.
func _fly_resources(flights: Array) -> void:
	# le posizioni dei riquadri si conoscono solo dopo che la colonna di sinistra è stata ridisegnata
	var src := {}
	for fi in flights.size():
		var f: Dictionary = flights[fi]
		if f.has("from_house"):
			var hp: int = f["from_house"][0]
			if res_nodes.has(hp) and is_instance_valid(res_nodes[hp].get(f["t"])):
				var n: Control = res_nodes[hp][f["t"]]
				src[fi] = n.get_global_rect().get_center()
	await get_tree().process_frame
	await get_tree().process_frame
	var k := 0
	for fi in flights.size():
		var f: Dictionary = flights[fi]
		var a := Vector2.ZERO
		if f.has("from_site"):
			var wp: Vector3 = board.site_pos(f["from_site"][0], f["from_site"][1])
			if board.cam.is_position_behind(wp):
				continue
			a = board.cam.unproject_position(wp)
		elif src.has(fi):
			a = src[fi]
		else:
			continue
		var to: int = f["to"]
		var b := Vector2.ZERO
		if res_nodes.has(to) and is_instance_valid(res_nodes[to].get(f["t"])):
			b = (res_nodes[to][f["t"]] as Control).get_global_rect().get_center()
		elif house_boxes.has(to) and is_instance_valid(house_boxes[to]):
			b = (house_boxes[to] as Control).get_global_rect().get_center()
		else:
			continue
		var ic := TextureRect.new()
		ic.texture = UI.tex("res://assets/res/%s.webp" % f["t"])
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size = Vector2(40, 40)
		ic.pivot_offset = Vector2(20, 20)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.position = a - ic.size / 2.0
		ic.modulate.a = 0.0
		add_child(ic)
		var delay: float = float(f.get("delay", 0.0)) + 0.06 * k
		k += 1
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(ic, "modulate:a", 1.0, 0.1)
		var mid := (a + b) / 2.0 + Vector2(0, -minf(160.0, a.distance_to(b) * 0.35))
		var aa := a
		var bb := b
		tw.tween_method(func(t: float):
			var q := aa.lerp(mid, t).lerp(mid.lerp(bb, t), t)
			ic.position = q - ic.size / 2.0
			ic.scale = Vector2.ONE * (1.0 + 0.5 * sin(t * PI)), 0.0, 1.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(ic, "scale", Vector2(1.4, 1.4), 0.08)
		tw.tween_property(ic, "modulate:a", 0.0, 0.18)
		tw.tween_callback(ic.queue_free)
		if house_boxes.has(to) and is_instance_valid(house_boxes[to]):
			var hb: Control = house_boxes[to]
			hb.pivot_offset = hb.size / 2.0
			var tw2 := hb.create_tween()
			tw2.tween_interval(delay + 0.85)
			tw2.tween_property(hb, "scale", Vector2(1.04, 1.04), 0.08)
			tw2.tween_property(hb, "scale", Vector2.ONE, 0.15)


func _on_log(t: String) -> void:
	var col := "#e6dcc3"
	if t.begins_with("—"):
		col = "#f0c868"
		t = "[b]" + t + "[/b]"
	elif t.contains("GUERRA") or t.contains("Invasione") or t.contains("invasore"):
		col = "#f08a7a"
	elif t.contains("VITTORIA") or t.contains("Favore") or t.contains("Corona"):
		col = "#ffe08a"
	log_box.append_text("[color=%s]%s[/color]\n" % [col, t])
	var sc: ScrollContainer = log_box.get_meta("scroll")
	await get_tree().process_frame
	if is_instance_valid(sc):
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)


func _on_phase(ph: String) -> void:
	if online != null and online.catchup:
		return
	match ph:
		"passive":
			toast("Azioni passive dei personaggi")
		"azioni":
			toast("Turno %d" % (engine.st.turn + 1))


func toast(t: String, secs := 2.2) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.flat(Color(0.06, 0.09, 0.17, 0.92), UI.GOLD, 2, 8, 10))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(UI.label(t, 22, UI.GOLD, UI.font_title))
	toast_box.add_child(pc)
	var tw := pc.create_tween()
	tw.tween_interval(secs)
	tw.tween_property(pc, "modulate:a", 0.0, 0.5)
	tw.tween_callback(pc.queue_free)


# ------------------------------------------------------------------ informazioni sui regni

func _on_hover(_r: int, _i: int) -> void:
	tip.visible = false


## Clic destro su un regno: la sua scheda (resta finché si muove il mouse fuori).
func _on_info(r: int, i: int) -> void:
	if r < 0:
		tip.visible = false
		return
	var st: SKState = engine.st
	var rg: Dictionary = st.regions[r]
	var t := "[b][color=#f0c868]%s[/color][/b]" % st.rname(r)
	var stato := []
	if rg["war"]:
		stato.append("[color=#ff8a7a]in GUERRA[/color]")
	if rg["peace"]:
		stato.append("[color=#bfe8b0]pacificato[/color]")
	if not stato.is_empty():
		t += " — " + ", ".join(stato)
	t += "\nRicchezza [b]%d[/b] · Governatore vale [b]%d[/b] · influenze %d/5" % [st.econ(r), st.gov_value(r), rg["infl"]]
	var g := st.governor(r)
	t += "\nGovernatore: " + ("[color=#%s]%s[/color]" % [UI.plight(g).to_html(false), st.pname(g)] if g >= 0 else "nessuno")
	var mi := st.majority_info(r)
	if mi["w"] >= 0:
		t += "\nMaggioranza: [color=#%s]%s[/color]" % [UI.plight(mi["w"]).to_html(false), st.pname(mi["w"])]
	elif not mi["tied"].is_empty():
		t += "\nParità fra " + ", ".join(mi["tied"].map(func(q): return st.pname(q))) + " (decide il Governatore)"
	var cnt := []
	for p in st.n:
		var k := st.count(r, p)
		if k > 0:
			cnt.append("[color=#%s]%s %d[/color]" % [UI.plight(p).to_html(false), st.pname(p), k])
	var inv := st.count(r, SKState.INV)
	if inv > 0:
		cnt.append("invasori %d" % inv)
	t += "\nVillaggi: " + (", ".join(cnt) if not cnt.is_empty() else "nessuno") + " · liberi %d/%d" % [st.free_count(r), rg["sites"].size()]
	if rg["bishop"] >= 0:
		t += "\nVescovo di %s (vale %d)" % [st.pname(rg["bishop"]), 2 + 2 * int(rg["infl"])]
	var ch := st.chars_in(r)
	if not ch.is_empty():
		t += "\nPersonaggi: " + ", ".join(ch.map(func(c): return SKData.cshort(c)))
	elif not rg["peace"] and not rg["war"]:
		t += "\n[color=#ffb070]Senza personaggi: a fine turno arriveranno gli invasori![/color]"
	var nb := []
	for a in st.land[r]:
		nb.append(SKData.TILES[st.regions[a]["tile"]]["short"])
	t += "\nPonti verso: " + ", ".join(nb)
	if st.sea[r] >= 0:
		t += "\nPorto verso: " + st.rname(st.sea[r])
	if i >= 0:
		var p2: int = rg["sites"][i]
		var what := "libero"
		if p2 == SKState.INV:
			what = "invasori"
		elif p2 >= 0:
			what = "villaggio di " + st.pname(p2)
		elif rg["res"][i] != "":
			what = "libero, con 1 " + SKData.RES_NAME[rg["res"][i]]
		t += "\n[i]Sito %d%s: %s[/i]" % [i + 1, " (Governatore)" if i == 0 else "", what]
	tip_lbl.text = ""
	tip_lbl.append_text(t)
	tip.visible = true
	tip.reset_size()
	_place_tip()


func _place_tip() -> void:
	var m := get_viewport().get_mouse_position()
	var vp := get_viewport_rect().size
	var p := m + Vector2(22, 18)
	if p.x + tip.size.x > vp.x - RW:
		p.x = m.x - tip.size.x - 22
	if p.y + tip.size.y > vp.y - 10:
		p.y = vp.y - tip.size.y - 10
	tip.position = p


# ------------------------------------------------------------------ decisioni

func _is_local(p: int) -> bool:
	if online != null:
		return p == online.seat
	return not engine.players[p]["ai"]


func _on_decision(req: Dictionary) -> void:
	pending = req
	var p: int = req["seat"]
	# più persone allo stesso dispositivo: si passa il dispositivo (per gli obiettivi segreti)
	if online == null and humans.size() > 1 and p != last_human and engine.st.opts.get("objectives", false):
		last_human = p
		await _handoff(p)
		if pending != req:
			return
	last_human = p
	sel = {}
	step = ""
	if is_instance_valid(status_pc) and not btn_next.visible:
		status_pc.visible = req["type"] in ["tie", "crown", "battle_favor", "battle_gov"] and status_pc.visible
	match req["type"]:
		"turn":
			step = "char"
			Audio.play("turn", -6.0)
		"setup":
			step = "setup"
		"athanor":
			_athanor_modal(req)
		"projects":
			step = "proj"
			psel = {"t": [], "b": "", "uid": "", "u": {}}
			pstep = ""
		"objective":
			_objective_modal(req)
		"tie":
			_choice_modal("Parità in %s" % engine.st.rname(req["r"]),
				"Sei il Governatore e decidi chi ha la maggioranza (%s)." % ("per la Corona del Re" if req.get("why", "") == "corona" else "per il Favore del Papa"),
				req["tied"].map(func(q): return engine.pname(q)), func(i): _provide(req["tied"][i]))
		"crown":
			var opts := []
			for q in engine.st.n:
				opts.append(engine.pname(q) + (" (tu)" if q == p else ""))
			_choice_modal("La Corona", "Hai la maggioranza nel regno del Re: a chi dai la Corona? Chi la riceve diventa Primo Giocatore.", opts, func(i): _provide(i))
		"battle_favor":
			_choice_modal("Battaglia in %s" % engine.st.rname(req["r"]), "Vuoi spendere il tuo Favore Papale per avere +1 in battaglia?", ["Sì, spendo il Favore", "No, lo tengo"], func(i): _provide(i == 0),
				_battle_panel(engine.st, p, int(req["r"]), "favor"))
		"battle_gov":
			_choice_modal("Battaglia in %s" % engine.st.rname(req["r"]), "%s dà battaglia agli invasori. Come Governatore puoi aggiungere +1 al suo attacco. Se vince, diventerà lui il Governatore." % engine.pname(req["p"]),
				["Sì, lo aiuto", "No"], func(i): _provide(i == 0), _battle_panel(engine.st, int(req["p"]), int(req["r"]), "gov"))
	refresh()
	_build_prompt()
	if tutorial != null:
		tutorial.on_decision(req)


func _provide(v) -> void:
	pending = {}
	sel = {}
	step = ""
	board.preview = null
	for c in modal.get_children():
		c.queue_free()
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.set_highlight([], [])
	_build_prompt()
	if tutorial != null:
		tutorial.after_provide()
	engine.provide_decision(v)


func _handoff(p: int) -> void:
	var box := _modal_box("Tocca a %s" % engine.pname(p))
	box.add_child(UI.wrap("Passa il dispositivo a %s: le carte obiettivo sono segrete." % engine.pname(p), 21, UI.INK, 520))
	var b := UI.primary(UI.button("Sono %s, si gioca" % engine.pname(p), 380, 56, 20))
	box.add_child(b)
	await b.pressed
	_close_modal()


func _modal_box(title: String, w := 600.0) -> VBoxContainer:
	for c in modal.get_children():
		c.queue_free()
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.08, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(cc)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.parchment(26))
	pc.custom_minimum_size = Vector2(w, 0)
	cc.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	pc.add_child(vb)
	vb.add_child(UI.title(title, 30, UI.INK))
	return vb


func _close_modal() -> void:
	for c in modal.get_children():
		c.queue_free()
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _choice_modal(title: String, text: String, options: Array, cb: Callable, extra: Control = null) -> void:
	var vb := _modal_box(title)
	vb.add_child(UI.wrap(text, 20, UI.INK, 540))
	if extra != null:
		vb.add_child(extra)
	for i in options.size():
		var b := UI.button(options[i], 540, 50, 18)
		if i == 0:
			UI.primary(b)
		var ii = i
		b.pressed.connect(func(): cb.call(ii))
		vb.add_child(b)


## I rapporti di forza di una battaglia: l'attacco voce per voce contro gli invasori e l'esito
## per ogni scelta ancora aperta (Favore Papale, aiuto del Governatore).
## stage: "declare" (prima della battaglia), "favor" (si chiede il Favore), "gov" (si chiede al Governatore).
func _battle_panel(st: SKState, p: int, r: int, stage: String, opaque := false) -> Control:
	var dice: bool = st.opts.get("dice", false)
	var inv := st.count(r, SKState.INV)
	var rows := []
	var atk := 0
	if stage == "gov":
		atk = st.battle_atk
		rows.append(["Attacco di %s finora" % st.pname(p), atk])
	else:
		if not dice:
			var v := st.count(r, p)
			atk += v
			rows.append(["Villaggi di %s nel regno" % st.pname(p), v])
			if st.first == p:
				atk += 1
				rows.append(["Corona", 1])
		if st.chars["fanteria"] == r:
			atk += 1
			rows.append(["Fanteria nel regno", 1])
		if st.has_art(p, "A03"):
			atk += 1
			rows.append(["Stendardo animato", 1])
		for army in st.battle_bonus:
			if int(st.battles.get(army, -1)) == p and st.chars[army] == r:
				atk += int(st.battle_bonus[army])
				rows.append(["Polvere del tuono", int(st.battle_bonus[army])])
	var g := st.governor(r)
	var fav_open: bool = stage != "gov" and st.favor[p]
	var gov_open: bool = g >= 0 and g != p
	if g >= 0 and g == p and stage != "gov":
		atk += 1
		rows.append(["Governatore (è suo)", 1])
	var t := "[b]Forze in campo[/b]\n"
	for x in rows:
		t += "• %s: [b]+%d[/b]\n" % [x[0], x[1]]
	if dice:
		t += "• Dado: [b]1–6[/b] (vince se dado + bonus supera gli invasori)\n"
	if fav_open:
		t += "• Favore Papale: [b]+1[/b] se lo spende\n"
	if gov_open:
		t += "• Governatore (%s): [b]+1[/b] se aiuta\n" % st.pname(g)
	t += "[b]Invasori: %d[/b]\n\n[b]Esito[/b]\n" % inv
	var combos := []
	for f in ([true, false] if fav_open else [false]):
		for h in ([true, false] if gov_open else [false]):
			combos.append([f, h])
	for cmb in combos:
		var a: int = atk + (1 if cmb[0] else 0) + (1 if cmb[1] else 0)
		var label := []
		if fav_open:
			label.append("con Favore" if cmb[0] else "senza Favore")
		if gov_open:
			label.append("Governatore aiuta" if cmb[1] else "Governatore no")
		var head := (", ".join(label) + ": ") if not label.is_empty() else ""
		if dice:
			var wins := 0
			for roll in range(1, 7):
				if roll + a > inv:
					wins += 1
			var col := "#2e6b2e" if wins >= 4 else ("#8a5a00" if wins >= 2 else "#8b1a1a")
			t += "• %s+%d → [color=%s][b]vittoria %d su 6[/b][/color] (%d%%)\n" % [head, a, col, wins, roundi(wins * 100.0 / 6.0)]
		else:
			var win := a >= inv
			t += "• %s%d contro %d → [color=%s][b]%s[/b][/color]\n" % [head, a, inv, "#2e6b2e" if win else "#8b1a1a", "VITTORIA" if win else "sconfitta"]
	if not dice:
		t += "[i]Senza dado si vince se l'attacco è almeno pari agli invasori.[/i]"
	var rt := UI.rich(17, UI.INK)
	rt.custom_minimum_size = Vector2(540, 0)
	rt.append_text(t)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.parchment(12) if opaque else UI.flat(Color(1, 1, 1, 0.35), Color("#8a6a3a"), 1, 8, 12))
	if opaque:
		rt.custom_minimum_size = Vector2(RW - 70, 0)
	pc.add_child(rt)
	return pc


func _objective_modal(req: Dictionary) -> void:
	var vb := _modal_box("Scegli la tua carta obiettivo — %s" % engine.pname(req["seat"]), 1000)
	vb.add_child(UI.wrap("Tienine una, segreta: ti darà punti a fine partita. Le altre due vengono scartate.", 20, UI.INK, 940))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	vb.add_child(hb)
	for i in req["options"].size():
		var id: String = req["options"][i]
		var col := VBoxContainer.new()
		var b := TextureButton.new()
		b.texture_normal = UI.tex(SKData.obj_image(id))
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(300, 428)
		b.tooltip_text = SKData.obj_text(id)
		var ii = i
		b.pressed.connect(func(): _provide(ii))
		col.add_child(b)
		hb.add_child(col)


func _show_objective(p: int) -> void:
	var id: String = engine.st.objectives[p]
	var vb := _modal_box("Il tuo obiettivo segreto", 520)
	var tr := UI.icon(SKData.obj_image(id), 420)
	tr.custom_minimum_size = Vector2(420, 600)
	vb.add_child(tr)
	vb.add_child(UI.wrap(SKData.obj_text(id) + "\nOra varrebbe %d PV." % engine.st.objective_points(p, id), 19, UI.INK, 460))
	var b := UI.button("Chiudi", 200, 46, 18)
	b.pressed.connect(func():
		_close_modal()
		if not pending.is_empty() and pending["type"] in ["tie", "crown", "battle_favor", "battle_gov", "objective"]:
			_on_decision(pending))
	vb.add_child(b)


# ------------------------------------------------------------------ costruzione della mossa
## La mossa si costruisce direttamente sulla mappa: si sceglie il personaggio (normale o potenziata),
## lo si porta in un regno seguendo le frecce (si muove subito), poi si toccano i siti illuminati.
## Il colore dei villaggi del Re si cambia toccando il riquadro del casato a sinistra; le risorse da
## rubare col Mercante si toccano nel riquadro dell'avversario.

func _me() -> int:
	return int(pending.get("seat", -1))


func _pick_char(c: String, pw := false) -> void:
	if step == "proj" and pstep == "char":
		psel["uc"] = c
		pstep = "dest"
		refresh()
		_build_prompt()
		return
	if pending.get("type", "") != "turn":
		_show_card(c)
		return
	var st: SKState = engine.st
	if st.used.has(c):
		_show_card(c)
		return
	if pw and not st.favor[_me()]:
		return
	if tutorial != null and not tutorial.allowed(c):
		toast("Per ora scegli %s: lo dice la pergamena del tutorial." % SKData.cn(tutorial.lock_char))
		return
	sel = {"c": c, "pw": pw}
	step = "dest"
	_update_preview()
	refresh()
	_build_prompt()


func _show_card(c: String) -> void:
	var vb := _modal_box(SKData.cn(c), 520)
	var tr := UI.icon(SKData.ccard(c), 420)
	tr.custom_minimum_size = Vector2(420, 630)
	vb.add_child(tr)
	vb.add_child(UI.wrap("Azione passiva: " + SKData.ctext(c)["passiva"], 18, UI.INK, 460))
	var b := UI.button("Chiudi", 200, 46, 18)
	b.pressed.connect(func():
		_close_modal())
	vb.add_child(b)


func _dests() -> Array:
	var out := []
	for path in engine.st.move_paths(sel["c"], _me()):
		var d: int = path[path.size() - 1]
		if not out.has(d):
			out.append(d)
	return out


func _path_to(d: int) -> Array:
	var best := []
	for path in engine.st.move_paths(sel["c"], _me()):
		if path[path.size() - 1] == d and (best.is_empty() or path.size() < best.size()):
			best = path
	return best


func _dest() -> int:
	var p: Array = sel.get("path", [])
	return p[p.size() - 1] if not p.is_empty() else -1


## Anteprima: lo stato con la mossa fin qui applicata (il personaggio già spostato, i villaggi già messi).
func _preview_state() -> SKState:
	var st: SKState = engine.st
	if not sel.has("path"):
		return null
	var ps := st.clone()
	var m := _move()
	if m["c"] == "spia" and not m.has("a"):
		ps.chars["spia"] = _dest()
		return ps
	if m["c"] == "mercante":
		m["from"] = -1
		m["res"] = []
	if m["c"] in ["fanteria", "cavalleria"]:
		ps.chars[m["c"]] = _dest()
		return ps
	var pw: bool = m["pw"]
	if pw and not ps.favor[_me()]:
		m["pw"] = false
	ps.apply_move(_me(), m)
	ps.used.erase(m["c"])
	if pw:
		ps.favor[_me()] = true
	return ps


func _update_preview() -> void:
	board.preview = _preview_state() if not pending.is_empty() else null


func _on_region(r: int) -> void:
	var st: SKState = engine.st
	if pending.is_empty():
		return
	if step == "proj":
		_proj_region(r)
		return
	match step:
		"setup":
			if st.setup_regions().has(r):
				_provide(r)
				return
		"dest":
			if _dests().has(r):
				sel["path"] = _path_to(r)
				_after_dest()
		"king", "king_pw":
			# toccare il regno equivale a toccare il suo sito illuminato
			for x in _king_targets():
				if int(x[0]) == r:
					_on_site(r, int(x[1]))
					return
			return
		"pope_t":
			if st.pope_targets(_dest(), sel["pw"]).has(r):
				sel["r"] = r
				step = "pope_b" if sel["pw"] and st.bishops[_me()] > 0 and not st.free_cathedrals().is_empty() else "confirm"
		"pope_b":
			if st.free_cathedrals().has(r):
				sel["b"] = r
				step = "confirm"
		_:
			return
	_update_preview()
	refresh()
	_build_prompt()


func _on_site(r: int, i: int) -> void:
	var st: SKState = engine.st
	if step == "proj":
		if pstep == "site_a" or pstep == "site_b":
			_proj_site(r, i)
		else:
			_proj_region(r)
		return
	match step:
		"king", "king_pw":
			var col: int = sel.get("color", _me())
			# toccare un villaggio appena messo lo toglie
			var pl: Array = sel.get("pl", [])
			var ghost := _ghost_index(r, i)
			if ghost >= 0:
				pl.remove_at(ghost)
				sel["pl"] = pl
			else:
				var ok := false
				for x in _king_targets():
					if int(x[0]) == r and int(x[1]) == i:
						ok = true
				if not ok:
					return
				if step == "king":
					# regole del Re normale: uno solo → tuo; due o più → almeno uno di un altro casato
					var want := _king_want()
					var other := pl.any(func(y): return int(y[1]) != _me())
					if want == 1:
						col = _me()
					elif pl.size() == want - 1 and not other and col == _me():
						_king_auto_color()
						col = sel.get("color", col)
				if st.reserve[col] - pl.filter(func(y): return int(y[1]) == col).size() <= 0:
					return
				pl.append([r, col])
				sel["pl"] = pl
			_king_auto_color()
		"spy_a":
			if r == _dest() and st.spy_sites(r, sel["pw"]).has(i):
				sel["a"] = [r, i]
				step = "spy_b"
			else:
				return
		"spy_b":
			if r == _dest() and st.spy_sites(r, sel["pw"]).has(i):
				sel["a"] = [r, i]
			elif st.land[_dest()].has(r) and st.spy_sites(r, sel["pw"]).has(i):
				sel["b"] = [r, i]
				step = "confirm"
			else:
				return
		_:
			_on_region(r)
			return
	_update_preview()
	refresh()
	_build_prompt()


## Il villaggio del Re già messo (anteprima) che si trova sul sito (r, i), oppure -1.
func _ghost_index(r: int, i: int) -> int:
	var st: SKState = engine.st
	var pl: Array = sel.get("pl", [])
	if sel.get("pw", false):
		var done := {}
		for k in pl.size():
			var rr := int(pl[k][0])
			var at := mini(1 + int(done.get(rr, 0)), st.regions[rr]["sites"].size() - 1)
			done[rr] = int(done.get(rr, 0)) + 1
			if rr == r and at == i:
				return k
		return -1
	var used := {}
	for k in pl.size():
		var rr := int(pl[k][0])
		var free_sites := []
		for j in st.regions[rr]["sites"].size():
			if st.regions[rr]["sites"][j] == -1:
				free_sites.append(j)
		var n := int(used.get(rr, 0))
		used[rr] = n + 1
		if rr == r and n < free_sites.size() and free_sites[n] == i:
			return k
	return -1


## Siti dove il Re può mettere il prossimo villaggio: [[regno, sito]].
func _king_targets() -> Array:
	var st: SKState = engine.st
	var d := _dest()
	var pl: Array = sel.get("pl", [])
	var out := []
	if sel.get("pw", false):
		if pl.size() >= 2:
			return []
		var done := {}
		var adj_used := -1
		for x in pl:
			done[int(x[0])] = int(done.get(int(x[0]), 0)) + 1
			if int(x[0]) != d:
				adj_used = int(x[0])
		for r in [d] + st.land[d]:
			if not st._king_region_ok(r, true):
				continue
			if r != d and adj_used != -1 and r != adj_used:
				continue
			out.append([r, mini(1 + int(done.get(r, 0)), st.regions[r]["sites"].size() - 1)])
		return out
	var sl := st.king_normal_slots(d)
	var in_main := 0
	var adj_r := -1
	for x in pl:
		if int(x[0]) == d:
			in_main += 1
		else:
			adj_r = int(x[0])
	var ps := board.preview if board.preview != null else st
	if in_main < sl["main"]:
		var lf := ps.lowest_free(d)
		if lf >= 0:
			out.append([d, lf])
	if adj_r == -1:
		for a in sl["adj"]:
			var lf2 := ps.lowest_free(a)
			if lf2 >= 0:
				out.append([a, lf2])
	return out


## Prima si mettono i propri villaggi, poi (se serve) quello di un altro casato: il colore passa da
## solo al primo avversario quando resta l'ultimo villaggio e non ce n'è ancora uno avversario.
func _king_auto_color() -> void:
	var st: SKState = engine.st
	var me := _me()
	var pl: Array = sel.get("pl", [])
	if sel.get("pw", false):
		if not sel.has("color"):
			sel["color"] = me
		return
	var want := _king_want()
	var other := pl.any(func(x): return int(x[1]) != me)
	if want >= 2 and not other and pl.size() == want - 1:
		for k in st.n:
			var q := (me + 1 + k) % st.n
			if q != me and st.reserve[q] > 0:
				sel["color"] = q
				return
	elif other and int(sel.get("color", me)) != me:
		# il villaggio dell'altro casato c'è già: si torna al proprio colore
		sel["color"] = me


func _king_want() -> int:
	var st: SKState = engine.st
	var sl := st.king_normal_slots(_dest())
	var tot := 0
	for o in st.n:
		tot += st.reserve[o]
	return mini(sl["main"] + (1 if not sl["adj"].is_empty() else 0), tot)


## Tocco sul riquadro di un casato (a sinistra): sceglie il colore dei villaggi del Re.
func _on_house(p: int) -> void:
	if pending.get("type", "") != "turn":
		return
	if step in ["king", "king_pw"]:
		sel["color"] = p
		refresh()
		_build_prompt()


## Tocco su una risorsa nel riquadro di un casato: il Mercante la ruba.
func _on_house_res(p: int, t: String) -> void:
	if step == "proj" and pstep == "res":
		if p != _me():
			for u in _proj_uses("I07"):
				if int(u["q"]) == p and u["t"] == t:
					psel["u"] = u
					pstep = ""
		refresh()
		_build_prompt()
		return
	if step != "merch" or p == _me():
		_on_house(p)
		return
	var st: SKState = engine.st
	var need := mini(2 if sel["pw"] else 1, st.total_res(p))
	if sel["from"] != p:
		sel["from"] = p
		sel["res"] = []
	var taken: int = sel["res"].count(t)
	if st.res[p][t] - taken <= 0:
		return
	if sel["res"].size() >= need:
		sel["res"] = []
	sel["res"].append(t)
	if sel["res"].size() >= need:
		step = "confirm"
	refresh()
	_build_prompt()


func _after_dest() -> void:
	var st: SKState = engine.st
	var d := _dest()
	match sel["c"]:
		"re":
			sel["pl"] = []
			sel["color"] = _me()
			step = "king_pw" if sel["pw"] else "king"
			_update_preview()
			if _king_targets().is_empty():
				step = "confirm"
		"papa":
			var t := st.pope_targets(d, sel["pw"])
			sel["r"] = -1
			sel["b"] = -1
			if t.is_empty():
				step = "pope_b" if sel["pw"] and st.bishops[_me()] > 0 and not st.free_cathedrals().is_empty() else "confirm"
			else:
				step = "pope_t"
		"mercante":
			sel["from"] = -1
			sel["res"] = []
			if st.alch():
				step = "confirm"
				return
			step = "merch"
			var any := false
			for q in st.n:
				if q != _me() and st.total_res(q) > 0:
					any = true
			if not any:
				step = "confirm"
		"spia":
			step = "spy_a"
		"fanteria", "cavalleria":
			sel["battle"] = st.regions[d]["war"]
			step = "confirm"


func _apply_highlight() -> void:
	var st: SKState = engine.st
	var regs := []
	var sts := []
	var pts := []
	var arr := []
	match step:
		"setup":
			for r in st.setup_regions():
				sts.append([r, st.lowest_free(r)])
		"dest":
			var from: int = st.chars[sel["c"]]
			for d in _dests():
				arr.append([from, d])
		"king", "king_pw":
			sts = _king_targets()
		"pope_t":
			for r in st.pope_targets(_dest(), sel.get("pw", false)):
				pts.append(board.wealth_pos(r, 5 - int(st.regions[r]["infl"])))
		"pope_b":
			for r in st.free_cathedrals():
				pts.append(board.bishop_pos(r))
		"proj":
			var hl := _proj_highlight()
			regs = hl[0]
			sts = hl[1]
			arr = hl[2]
		"spy_a":
			for i in st.spy_sites(_dest(), sel["pw"]):
				sts.append([_dest(), i])
		"spy_b":
			for r in st.land[_dest()]:
				for i in st.spy_sites(r, sel["pw"]):
					sts.append([r, i])
	# i regni con caselle illuminate hanno anche il bordo dorato, per trovarle a colpo d'occhio
	for x in sts:
		if step != "setup" and not regs.has(int(x[0])):
			regs.append(int(x[0]))
	if pending.is_empty():
		regs = pause_regs.duplicate()
		sts = []
		pts = []
		arr = []
	board.set_highlight(regs, sts, pts, arr)


var proj_pc: PanelContainer = null


func _build_prompt() -> void:
	for c in prompt_box.get_children():
		c.queue_free()
	if proj_pc != null and is_instance_valid(proj_pc):
		proj_pc.queue_free()
		proj_pc = null
	var st: SKState = engine.st
	var W := RW - 40
	if pending.is_empty():
		if engine.cur >= 0 and not game_done:
			prompt_box.add_child(UI.wrap("Tocca a %s…" % engine.pname(engine.cur), 19, UI.PARCH, W, UI.font_italic))
		return
	var me := _me()
	var t: String = pending["type"]
	if t == "projects":
		_build_projects_prompt(W)
		return
	if t == "setup":
		prompt_box.add_child(UI.title("Piazzamento iniziale", 20))
		prompt_box.add_child(UI.wrap("%s, tocca uno dei siti illuminati (giro %d di 3): ci metti un tuo villaggio e prendi la risorsa che c'era." % [engine.pname(me), int(pending.get("round", 0)) + 1], 18, UI.LIGHT, W))
		return
	if t != "turn":
		return
	prompt_box.add_child(UI.title("La tua mossa, %s" % engine.pname(me), 20))
	if step == "char" or not sel.has("c"):
		prompt_box.add_child(UI.wrap("Scegli un personaggio libero: tocca il riquadro «Normale» o, se hai il Favore Papale, «Potenziata».", 18, UI.LIGHT, W))
		return
	var c: String = sel["c"]
	prompt_box.add_child(UI.label(SKData.cn(c) + (" — potenziata" if sel.get("pw", false) else ""), 19, UI.GOLD, UI.font_title))
	var hint := ""
	match step:
		"dest":
			hint = "Seguendo una freccia, tocca il regno dove lo porti."
		"king":
			var col: int = sel.get("color", me)
			hint = "Tocca i siti illuminati per mettere i villaggi. Ora metti un villaggio di [b][color=#%s]%s[/color][/b]: per cambiare casato tocca il suo riquadro a sinistra. Tocca un villaggio appena messo per toglierlo." % [UI.plight(col).to_html(false), engine.pname(col)]
		"king_pw":
			var col2: int = sel.get("color", me)
			hint = "Tocca i siti illuminati (2° posto, gli altri villaggi scalano). Colore: [b][color=#%s]%s[/color][/b] (tocca un riquadro a sinistra per cambiarlo)." % [UI.plight(col2).to_html(false), engine.pname(col2)]
		"pope_t":
			hint = "Tocca la casella illuminata della Ricchezza dove metti l'influenza religiosa."
		"pope_b":
			hint = "Tocca il Luogo Sacro dove nomini il tuo Vescovo."
		"merch":
			var need := 2 if sel["pw"] else 1
			hint = "Tocca %s nel riquadro di un avversario, a sinistra." % ("una sua risorsa" if need == 1 else "due sue risorse")
		"spy_a":
			hint = "Tocca un villaggio nel regno della Spia%s." % ("" if sel["pw"] else " (non il Governatore)")
		"spy_b":
			hint = "Ora tocca il villaggio con cui scambiarlo, in un regno collegato da un ponte."
		"confirm":
			if c in ["fanteria", "cavalleria"] and st.regions[_dest()]["war"]:
				hint = "Il regno è in guerra: dichiari battaglia (si combatte nelle azioni passive)."
	if hint != "":
		var hl := UI.rich(17, UI.LIGHT)
		hl.custom_minimum_size = Vector2(W, 0)
		hl.append_text(hint)
		prompt_box.add_child(hl)
	if step == "confirm" and c in ["fanteria", "cavalleria"] and st.regions[_dest()]["war"]:
		var bs: SKState = board.preview if board.preview != null else st
		prompt_box.add_child(_battle_panel(bs, me, _dest(), "declare", true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if sel.has("path"):
		var err := st.check_move(me, _move())
		var ok := UI.primary(UI.button("Conferma", 170, 46, 18))
		ok.disabled = err != ""
		ok.pressed.connect(func(): _provide(_move()))
		row.add_child(ok)
		if step == "spy_a" or step == "spy_b":
			var nb := UI.button("Nessuno scambio", 190, 46, 14)
			nb.pressed.connect(func():
				sel.erase("a")
				sel.erase("b")
				_provide(_move()))
			row.add_child(nb)
	var back := UI.button("Annulla", 120, 46, 14)
	back.pressed.connect(func():
		sel = {}
		step = "char"
		_update_preview()
		refresh()
		_build_prompt())
	row.add_child(back)
	prompt_box.add_child(row)
	if sel.has("path"):
		prompt_box.add_child(UI.wrap(_summary(), 15, UI.PARCH, W, UI.font_italic))


func _move() -> Dictionary:
	var m := {"c": sel.get("c", ""), "pw": sel.get("pw", false), "path": sel.get("path", [])}
	match m["c"]:
		"re":
			m["pl"] = sel.get("pl", [])
		"papa":
			m["r"] = sel.get("r", -1)
			if m["pw"]:
				m["b"] = sel.get("b", -1)
		"mercante":
			m["from"] = sel.get("from", -1)
			m["res"] = sel.get("res", [])
		"spia":
			if sel.has("a") and sel.has("b"):
				m["a"] = sel["a"]
				m["b"] = sel["b"]
		"fanteria", "cavalleria":
			m["battle"] = sel.get("battle", false)
	return m


# ------------------------------------------------------------------ variante dell'Alchimista

## Stato dopo Trasmutatore e realizzazione scelti (per sapere cosa si potrà usare e su quali bersagli).
func _proj_state() -> SKState:
	# lo stato dopo aver pagato la carta scelta (senza ancora l'effetto): servono i bersagli possibili
	var c: SKState = engine.st.clone()
	var id: String = psel.get("b", "")
	if id != "":
		var keep := c.free_next.duplicate()
		c._do_projects(_me(), {"b": id})
		c.free_next = keep
	return c


func _proj_uses(id: String) -> Array:
	var st: SKState = engine.st
	return st.invention_uses(_me(), id)


func _proj_value() -> Dictionary:
	var v := {}
	if psel.get("b", "") != "":
		v["b"] = psel["b"]
	var u: Dictionary = psel.get("u", {}).duplicate()
	u.erase("id")
	u.erase("x")
	if not u.is_empty():
		v["u"] = u
	return v


## Sceglie la carta da attivare e il primo passo della scelta del bersaglio del suo effetto.
func _proj_pick_use(id: String) -> void:
	psel["b"] = id
	psel["uid"] = id
	psel["u"] = {}
	psel.erase("uc")
	psel.erase("ua")
	psel.erase("ur")
	pstep = ""
	var uses := _proj_uses(id)
	if uses.is_empty():
		return
	match id:
		"I01", "I02", "I03", "I05":
			pstep = "region"
		"I04", "A02":
			pstep = "char"
		"I07":
			pstep = "res"
		"I08":
			pstep = "site_a"
		"A04":
			pstep = "variant"


func _proj_region(r: int) -> void:
	var id: String = psel.get("uid", "")
	if id == "":
		return
	var uses := _proj_uses(id)
	match pstep:
		"region":
			var opts := uses.filter(func(u): return int(u["r"]) == r)
			if opts.is_empty():
				return
			psel["ur"] = r
			if opts.size() == 1:
				psel["u"] = opts[0]
				pstep = ""
			else:
				pstep = "variant"
		"dest":
			for u in uses:
				if u["c"] == psel.get("uc", "") and int(u["to"]) == r:
					psel["u"] = u
					pstep = ""
		_:
			return
	refresh()
	_build_prompt()


func _proj_site(r: int, i: int) -> void:
	var uses := _proj_uses("I08")
	if pstep == "site_a":
		for u in uses:
			if int(u["a"][0]) == r and int(u["a"][1]) == i:
				psel["ua"] = [r, i]
				pstep = "site_b"
				break
	elif pstep == "site_b":
		var a: Array = psel.get("ua", [])
		var found := false
		for u in uses:
			if int(u["a"][0]) == int(a[0]) and int(u["a"][1]) == int(a[1]) and int(u["b"][0]) == r and int(u["b"][1]) == i:
				psel["u"] = u
				pstep = ""
				found = true
		if not found:
			# si ricomincia dal proprio villaggio
			pstep = "site_a"
			_proj_site(r, i)
			return
	refresh()
	_build_prompt()


func _proj_highlight() -> Array:
	var regs := []
	var sts := []
	var arr := []
	var id: String = psel.get("uid", "")
	if id == "":
		return [regs, sts, arr]
	var uses := _proj_uses(id)
	var st: SKState = engine.st
	match pstep:
		"region":
			for u in uses:
				if not regs.has(int(u["r"])):
					regs.append(int(u["r"]))
		"dest":
			var c: String = psel.get("uc", "")
			for u in uses:
				if u["c"] == c:
					arr.append([st.chars[c], int(u["to"])])
		"site_a":
			for u in uses:
				var a := [int(u["a"][0]), int(u["a"][1])]
				if not sts.has(a):
					sts.append(a)
		"site_b":
			var aa: Array = psel.get("ua", [])
			for u in uses:
				if int(u["a"][0]) == int(aa[0]) and int(u["a"][1]) == int(aa[1]):
					sts.append([int(u["b"][0]), int(u["b"][1])])
	if not psel.get("u", {}).is_empty():
		var u2: Dictionary = psel["u"]
		if u2.has("r"):
			regs = [int(u2["r"])]
	return [regs, sts, arr]


func _proj_thumb(id: String, w: float, state: int, cb: Callable) -> Control:
	# state: 0 normale, 1 disponibile, 2 scelto, 3 non disponibile
	var pc := PanelContainer.new()
	var col: Color = [Color(0, 0, 0, 0), Color("#ffd86a"), Color("#ff6a4a"), Color(0, 0, 0, 0)][state]
	pc.add_theme_stylebox_override("panel", UI.flat(Color(0, 0, 0, 0), col, 3 if state in [1, 2] else 0, 6, 2))
	var tr := UI.icon(SKData.proj_img(id), w)
	tr.custom_minimum_size = Vector2(w, w * 502.0 / 360.0)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if state == 3:
		tr.modulate = Color(0.55, 0.55, 0.55)
	var d: Dictionary = SKData.PROJECTS[id]
	# costo e PV aggiornati della variante (le tessere stampate riportano ancora quelli del prototipo 0.2)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tr)
	if w >= 60:
		var strip := HBoxContainer.new()
		strip.add_theme_constant_override("separation", 1)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for t in d["cost"]:
			for k in int(d["cost"][t]):
				var ic := UI.icon("res://assets/res/%s.webp" % t, 18)
				ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
				strip.add_child(ic)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(gap)
		var pvl := UI.label("%d PV" % int(d["pv"]), 13, UI.GOLD, UI.font_bold)
		pvl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(pvl)
		vb.add_child(strip)
	pc.add_child(vb)
	var cost := []
	for t in d["cost"]:
		cost.append("%d %s" % [int(d["cost"][t]), SKData.RES_NAME[t]])
	pc.tooltip_text = "%s (%s, %d PV)\nCosto: %s\n%s" % [d["n"], "Invenzione, effetto una volta" if d["kind"] == "inv" else "Artefatto, effetto permanente", int(d["pv"]), ", ".join(cost), d["t"]]
	pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pc.gui_input.connect(func(ev):
		if _is_click(ev):
			cb.call())
	return pc


func _build_projects_prompt(_w: float) -> void:
	var st: SKState = engine.st
	var me := _me()
	prompt_box.add_child(UI.title("Le carte dell'Alchimista, %s" % engine.pname(me), 20))
	prompt_box.add_child(UI.wrap("Scegli la carta da attivare nel riquadro in basso sulla mappa, poi «Attiva» (o «Non attivare»).", 17, UI.LIGHT, RW - 40))
	# il pannello dei progetti sta sopra la mappa, in basso: c'è più spazio per le tessere
	proj_pc = PanelContainer.new()
	proj_pc.add_theme_stylebox_override("panel", UI.night(0.94))
	add_child(proj_pc)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	proj_pc.add_child(outer)
	var W := 980.0
	var real_box := prompt_box
	prompt_box = outer
	_proj_contents(st, me, W)
	prompt_box = real_box
	proj_pc.reset_size()
	var vp := get_viewport_rect().size
	await get_tree().process_frame
	if is_instance_valid(proj_pc):
		proj_pc.reset_size()
		proj_pc.position = Vector2(LW + ((vp.x - LW - RW) - proj_pc.size.x) / 2.0, vp.y - proj_pc.size.y - 70.0)


func _proj_contents(st: SKState, me: int, W: float) -> void:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	prompt_box.add_child(cols)
	var c_cards := VBoxContainer.new()
	var c_side := VBoxContainer.new()
	c_side.custom_minimum_size = Vector2(340, 0)
	for cc in [c_cards, c_side]:
		cc.add_theme_constant_override("separation", 4)
		cols.add_child(cc)
	var passive: bool = pending.get("passive", false)
	var left := int(pending.get("left", 1))
	var head := "Hai la maggioranza nel regno dell'Alchimista: puoi attivare 1 carta." if passive else ("Attiva una carta" + (" (ne puoi attivare ancora %d)" % left if left > 1 else "") + ":")
	if st.free_next[me]:
		head += " Athanor: questa non costa risorse."
	c_cards.add_child(UI.label(head, 15, UI.GOLD, UI.font_italic))
	var hf := HFlowContainer.new()
	hf.custom_minimum_size = Vector2(600, 0)
	hf.add_theme_constant_override("h_separation", 6)
	hf.add_theme_constant_override("v_separation", 6)
	var seen := {}
	for id in st.hand[me]:
		if seen.has(id):
			continue
		seen[id] = true
		var ok: bool = st.can_afford(me, id)
		var stt := 2 if psel.get("b", "") == id else (1 if ok else 3)
		var idd: String = id
		var cnt: int = st.hand[me].count(id)
		var th := _proj_thumb(id, 74, stt, func():
			if not ok:
				_show_proj(idd)
				return
			_proj_pick_use(idd)
			_build_prompt()
			refresh())
		if cnt > 1:
			th.tooltip_text += "\n(ne hai %d)" % cnt
		hf.add_child(th)
	c_cards.add_child(hf)
	prompt_box = c_side
	var hint := ""
	var uid: String = psel.get("uid", "")
	if uid == "":
		hint = "Tocca una carta illuminata: la paghi, ne risolvi l'effetto e la giri (a fine partita vale i PV stampati). Le carte scure non le puoi ancora pagare."
	else:
		var d: Dictionary = SKData.PROJECTS[uid]
		prompt_box.add_child(UI.label(d["n"], 17, UI.GOLD, UI.font_title))
		prompt_box.add_child(UI.wrap(d["t"], 14, UI.PARCH, 330))
		match pstep:
			"region": hint = "Tocca un regno illuminato."
			"char": hint = "Tocca il ritratto del personaggio da spostare, a destra."
			"dest": hint = "Tocca il regno dove lo porti (frecce)."
			"res": hint = "Tocca la risorsa nel riquadro di un avversario, a sinistra."
			"site_a": hint = "Tocca un tuo villaggio illuminato (non il sito 1)."
			"site_b": hint = "Tocca il villaggio avversario con cui scambiarlo."
			"variant":
				var fl := HFlowContainer.new()
				fl.custom_minimum_size = Vector2(330, 0)
				fl.add_theme_constant_override("h_separation", 6)
				fl.add_theme_constant_override("v_separation", 6)
				for u in _proj_uses(uid):
					if u.has("r") and int(u["r"]) != int(psel.get("ur", -1)):
						continue
					var lab := ""
					if uid == "A04":
						lab = " + ".join(u["t"].map(func(t): return SKData.RES_NAME[t]))
					elif uid == "I03":
						lab = "Ricchezza +1" if int(u["d"]) == 1 else "Ricchezza -1"
					else:
						lab = "Aggiungi influenza" if u["add"] else "Togli influenza"
					var bb := UI.button(lab, 160, 36, 13)
					var uu: Dictionary = u
					bb.pressed.connect(func():
						psel["u"] = uu
						pstep = ""
						_build_prompt()
						refresh())
					fl.add_child(bb)
				prompt_box.add_child(fl)
			"":
				if not psel.get("u", {}).is_empty():
					hint = "Effetto: " + _use_text(psel["u"])
				elif SKData.PROJECTS[uid].get("auto", false):
					hint = "Effetto: " + _use_text({"id": uid})
				else:
					hint = "Nessun bersaglio possibile ora: la carta si attiva solo per i PV."
	if hint != "":
		prompt_box.add_child(UI.wrap(hint, 15, UI.LIGHT, 330))
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 8)
	var v := _proj_value()
	var err := st.check_projects(me, v) if not v.is_empty() else "scegli una carta"
	if uid != "" and pstep != "":
		err = "scegli il bersaglio dell'effetto"
	var ok2 := UI.primary(UI.button("Attiva", 150, 46, 18))
	ok2.disabled = err != ""
	ok2.pressed.connect(func(): _provide(_proj_value()))
	row3.add_child(ok2)
	var skip := UI.button("Non attivare", 170, 46, 14)
	skip.pressed.connect(func(): _provide({}))
	row3.add_child(skip)
	prompt_box.add_child(row3)
	if err != "" and uid != "":
		prompt_box.add_child(UI.wrap(err, 14, Color("#ffb0a0"), 330, UI.font_italic))
	prompt_box = c_side.get_parent().get_parent()


func _use_text(u: Dictionary) -> String:
	var st: SKState = engine.st
	match str(u["id"]):
		"I01": return "un villaggio in %s" % st.rname(int(u["r"]))
		"I02": return "via un invasore da %s" % st.rname(int(u["r"]))
		"I03": return "Ricchezza %s in %s" % ["+1" if int(u["d"]) == 1 else "-1", st.rname(int(u["r"]))]
		"I04": return "%s in %s" % [SKData.cn(u["c"]), st.rname(int(u["to"]))]
		"I05": return "%s influenza in %s" % ["aggiungi" if u["add"] else "togli", st.rname(int(u["r"]))]
		"I06": return "+2 alle tue battaglie di questo turno"
		"A01": return "la prossima carta è gratis"
		"A02": return "%s in %s" % [SKData.cn(u["c"]), st.rname(int(u["to"]))]
		"A03": return "+1 alle tue battaglie di questo turno"
		"A04": return "prendi " + " e ".join(u["t"].map(func(t): return SKData.RES_NAME[t]))
		"I07": return "1 %s da %s" % [SKData.RES_NAME[u["t"]], st.pname(int(u["q"]))]
		"I08": return "scambio fra %s e %s" % [st.rname(int(u["a"][0])), st.rname(int(u["b"][0]))]
	return ""


func _show_proj(id: String) -> void:
	var d: Dictionary = SKData.PROJECTS[id]
	var vb := _modal_box(d["n"], 460)
	var tr := UI.icon(SKData.proj_img(id), 360)
	tr.custom_minimum_size = Vector2(360, 502)
	vb.add_child(tr)
	var b := UI.button("Chiudi", 200, 46, 18)
	b.pressed.connect(func():
		_close_modal())
	vb.add_child(b)


func _athanor_modal(req: Dictionary) -> void:
	var vb := _modal_box("Athanor", 820)
	vb.add_child(UI.wrap("Hai visto questi progetti: tocca quello da SCARTARE, gli altri vanno nella tua mano.", 20, UI.INK, 760))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	var cards: Array = req["cards"]
	for i in cards.size():
		var ii := i
		hb.add_child(_proj_thumb(cards[i], 220, 1, func(): _provide(ii)))
	vb.add_child(hb)


## Progetti di un casato nel suo riquadro: realizzati (pubblici) e in mano (solo i propri).
func _house_projects(p: int) -> Control:
	var st: SKState = engine.st
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	var hb := HFlowContainer.new()
	hb.add_theme_constant_override("h_separation", 3)
	hb.add_child(UI.label("Carte girate %d PV" % st.proj_points(p), 14, UI.GOLD, UI.font_bold))
	for b in st.built[p]:
		var id: String = b["id"]
		var t := _proj_thumb(id, 30, 0, func(): _show_proj(id))
		if b["used"]:
			t.modulate = Color(0.5, 0.5, 0.5)
			t.tooltip_text += "\n(girata: vale i PV a fine partita)"
		hb.add_child(t)
	vb.add_child(hb)
	if _can_see_objective(p):
		var hh := HFlowContainer.new()
		hh.add_theme_constant_override("h_separation", 3)
		hh.add_child(UI.label("Da attivare:", 13, UI.PARCH, UI.font_italic))
		for id in st.hand[p]:
			var idd: String = id
			hh.add_child(_proj_thumb(id, 30, 0, func(): _show_proj(idd)))
		vb.add_child(hh)
	else:
		vb.add_child(UI.label("Da attivare: %d carte" % st.hand[p].size(), 13, UI.PARCH, UI.font_italic))
	return vb


func _summary() -> String:
	var st: SKState = engine.st
	var m := _move()
	var d := _dest()
	if d < 0:
		return ""
	var s := "%s va in %s. " % [SKData.cshort(m["c"]), st.rname(d)]
	match m["c"]:
		"re":
			for x in m["pl"]:
				s += "Villaggio di %s in %s. " % [st.pname(int(x[1])), SKData.TILES[st.regions[int(x[0])]["tile"]]["short"]]
		"papa":
			if m["r"] >= 0:
				s += "Influenza in %s. " % st.rname(m["r"])
			if m.get("b", -1) >= 0:
				s += "Vescovo in %s. " % st.rname(m["b"])
		"mercante":
			if st.alch():
				s += "Pesca %d progett%s. " % [2 if m["pw"] else 1, "i" if m["pw"] else "o"]
			elif m["from"] >= 0 and not m["res"].is_empty():
				s += "Prendi %s a %s. " % [", ".join(m["res"].map(func(t): return SKData.RES_NAME[t])), st.pname(m["from"])]
		"spia":
			if m.has("a"):
				s += "Scambio fra %s e %s. " % [st.rname(m["a"][0]), st.rname(m["b"][0])]
		"fanteria", "cavalleria":
			if m["battle"]:
				s += "Battaglia contro %d invasori. " % st.count(d, SKState.INV)
			else:
				s += "Invasori presenti: %d. " % st.count(d, SKState.INV)
	return s


# ------------------------------------------------------------------ fine partita, regole, uscita

func _on_game_end(results: Array) -> void:
	game_done = true
	pending = {}
	_build_prompt()
	if online != null:
		online.finish()
	Audio.play("win")
	await get_tree().create_timer(1.0).timeout
	if tutorial != null:
		await tutorial.on_end()
	var st: SKState = engine.st
	var vb := _modal_box("Fine della partita", 900)
	vb.add_child(UI.wrap(SKState.END_TEXT.get(st.end_reason, ""), 20, UI.INK2, 840, UI.font_italic))
	var w: Dictionary = results[0]
	vb.add_child(UI.title("Vince %s!" % engine.pname(w["p"]) + (" (obiettivo segreto)" if w["instant"] else ""), 32, UI.pcol(w["p"]).darkened(0.2)))
	var gr := GridContainer.new()
	gr.columns = 10
	gr.add_theme_constant_override("h_separation", 14)
	var rk_res := "progetti" if st.alch() else "risorse"
	for h in ["", "Casato", "Villaggi", "Gov.", "Vescovi", "Progetti" if st.alch() else "Risorse", "Corona", "Favore", "Obiettivo", "Totale"]:
		gr.add_child(UI.label(h, 16, UI.INK2, UI.font_bold))
	var pos := 1
	for d in results:
		gr.add_child(UI.label("%d°" % pos, 18, UI.INK, UI.font_title))
		gr.add_child(UI.label(engine.pname(d["p"]), 18, UI.pcol(d["p"]).darkened(0.3), UI.font_bold))
		for k in ["villaggi", "gov", "vescovi", rk_res, "corona", "favore", "obiettivo", "tot"]:
			gr.add_child(UI.label(str(d[k]), 18 if k != "tot" else 21, UI.INK, UI.font_bold if k == "tot" else UI.font_body))
		pos += 1
	vb.add_child(gr)
	if st.opts.get("objectives", false):
		var ol := []
		for p in st.n:
			ol.append("%s: %s" % [engine.pname(p), SKData.obj_name(st.objectives[p])])
		vb.add_child(UI.wrap("Obiettivi: " + " · ".join(ol), 16, UI.INK2, 840))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var b1 := UI.primary(UI.button("Torna al menu", 260, 52, 20))
	b1.pressed.connect(func(): main.show_menu())
	row.add_child(b1)
	var b2 := UI.button("Guarda la mappa", 260, 52, 20)
	b2.pressed.connect(_close_modal)
	row.add_child(b2)
	vb.add_child(row)
	refresh()


func _ask_quit() -> void:
	var vb := _modal_box("Tornare al menu?", 520)
	vb.add_child(UI.wrap("La partita in corso andrà persa%s." % (" (online potrai rientrare con il codice)" if online != null else ""), 19, UI.INK, 460))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var y := UI.primary(UI.button("Sì, esci", 200, 50, 18))
	y.pressed.connect(func():
		if online != null:
			online.alive = false
		main.show_menu())
	row.add_child(y)
	var n := UI.button("Continua", 200, 50, 18)
	n.pressed.connect(func():
		_close_modal()
		if not pending.is_empty() and pending["type"] in ["tie", "crown", "battle_favor", "battle_gov", "objective"]:
			_on_decision(pending))
	row.add_child(n)
	vb.add_child(row)


func _show_rules_popup() -> void:
	var vb := _modal_box("Regole in breve", 900)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(860, 620)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var r := UI.rich(18, UI.INK)
	r.custom_minimum_size = Vector2(830, 0)
	r.append_text(RulesText.TEXT)
	sc.add_child(r)
	var b := UI.button("Chiudi", 200, 46, 18)
	b.pressed.connect(func():
		_close_modal()
		if not pending.is_empty() and pending["type"] in ["tie", "crown", "battle_favor", "battle_gov", "objective"]:
			_on_decision(pending))
	vb.add_child(b)


# ------------------------------------------------------------------ online

func online_status(t: String) -> void:
	online_lbl.text = t


func online_waiting(seat: int, is_slow: bool) -> void:
	if seat < 0:
		online_lbl.text = ""
	else:
		online_lbl.text = "In attesa di %s…%s" % [engine.pname(seat), " (sembra lento: se non torna entro un minuto gioca l'IA)" if is_slow else ""]


func online_caught_up() -> void:
	Audio.suspended = false
	online_lbl.text = "Partita ripresa."
	refresh()


func online_cancel_decision(t: String) -> void:
	pending = {}
	sel = {}
	step = ""
	_close_modal()
	_build_prompt()
	online_lbl.text = t
