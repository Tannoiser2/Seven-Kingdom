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
signal next_pressed
var game_done := false

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
			title = "%s — %s" % [engine.pname(who), SKData.CHAR_NAME.get(c, "mossa")]
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


func _refresh_left() -> void:
	var st: SKState = engine.st
	for c in left_box.get_children():
		c.queue_free()
	left_box.add_child(UI.title("I casati", 22))
	var order := []
	for k in st.n:
		order.append((st.first + k) % st.n)
	for p in order:
		var pc := PanelContainer.new()
		var border := UI.pcol(p).lightened(0.2) if p != engine.cur else UI.GOLD
		pc.add_theme_stylebox_override("panel", UI.flat(UI.pcol(p).darkened(0.62), border, 3 if p == engine.cur else 2, 8, 8))
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
		var sc := UI.label("%d PV" % st.score(p, false), 17, UI.GOLD, UI.font_bold)
		sc.tooltip_text = _score_tip(p)
		sc.mouse_filter = Control.MOUSE_FILTER_PASS
		info.add_child(sc)
		vb.add_child(info)
		var rs := HBoxContainer.new()
		rs.add_theme_constant_override("separation", 6)
		for t in SKData.RESOURCES:
			rs.add_child(UI.res_chip(t, st.res[p][t], 24))
		vb.add_child(rs)
		if _can_see_objective(p) and st.objectives[p] != "":
			var ob := UI.button("Obiettivo: " + SKData.obj_name(st.objectives[p]), 260, 32, 12)
			ob.clip_text = true
			ob.tooltip_text = SKData.obj_text(st.objectives[p]) + "\n(ora varrebbe %d PV)" % st.objective_points(p, st.objectives[p])
			var pp: int = p
			ob.pressed.connect(func(): _show_objective(pp))
			vb.add_child(ob)
		left_box.add_child(pc)
	var leg := UI.wrap("Punti stimati senza obiettivi segreti. Passa il mouse su un regno per i dettagli.", 15, UI.PARCH.darkened(0.25), 260, UI.font_italic)
	left_box.add_child(leg)


func _score_tip(p: int) -> String:
	var d: Dictionary = engine.st.score_detail(p, false)
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
		var b := PanelContainer.new()
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var bg_col := Color(0.1, 0.14, 0.24) if not used else Color(0.07, 0.07, 0.09)
		var lit: bool = my_turn and not used
		var border := UI.GOLD if chosen else (Color("#e9c766") if lit else Color(0.35, 0.33, 0.3))
		b.add_theme_stylebox_override("panel", UI.flat(bg_col, border, 3 if chosen else (2 if lit else 1), 8, 4))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hb)
		var art := TextureRect.new()
		art.texture = UI.tex("res://assets/chars/%s_art.webp" % c)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.custom_minimum_size = Vector2(78, 64)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if used:
			art.modulate = Color(0.4, 0.4, 0.4)
		hb.add_child(art)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(vb)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nm := UI.label(SKData.CHAR_SHORT[c], 16, UI.GOLD if not used else Color(0.55, 0.55, 0.55), UI.font_title)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(nm)
		var where := UI.label("  in " + SKData.TILES[st.regions[st.chars[c]]["tile"]]["short"], 14, UI.PARCH.darkened(0.2) if not used else Color(0.5, 0.5, 0.5), UI.font_italic)
		where.mouse_filter = Control.MOUSE_FILTER_IGNORE
		where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(where)
		if used:
			var who := UI.label("usato da " + engine.pname(st.used[c]), 14, UI.plight(st.used[c]), UI.font_bold)
			who.mouse_filter = Control.MOUSE_FILTER_IGNORE
			top.add_child(who)
			top.add_child(UI.icon("res://assets/tokens/azione_%s.webp" % UI.cid(st.used[c]), 20))
		vb.add_child(top)
		var ln := UI.wrap("Normale: " + SKData.CHAR_BRIEF[c][0], 13, UI.LIGHT if not used else Color(0.5, 0.5, 0.5), RW - 140)
		ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(ln)
		var pcol := UI.GOLD if (fav and not used) else Color(0.55, 0.53, 0.5)
		var lp := UI.wrap("Potenziata: " + SKData.CHAR_BRIEF[c][1] + ("" if fav or used else " (serve il Favore)"), 13, pcol, RW - 140, UI.font_italic)
		lp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(lp)
		b.tooltip_text = "%s\n\nNORMALE: %s\n\nPOTENZIATA (scarta il Favore Papale): %s\n\nPASSIVA: %s" % [SKData.CHAR_NAME[c],
			SKData.CHAR_TEXT[c]["normale"], SKData.CHAR_TEXT[c]["potenziata"], SKData.CHAR_TEXT[c]["passiva"]]
		var cc: String = c
		b.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				Audio.play("click", -6.0)
				_pick_char(cc))
		cards_box.add_child(b)


var _ev_seen := 0

func _play_events() -> void:
	var st: SKState = engine.st
	if st.events.size() < _ev_seen:
		_ev_seen = 0
	if st.events.size() == _ev_seen:
		return
	var sounds := {}
	for e in st.events.slice(_ev_seen):
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

func _on_hover(r: int, i: int) -> void:
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
		t += "\nPersonaggi: " + ", ".join(ch.map(func(c): return SKData.CHAR_SHORT[c]))
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
			_choice_modal("Battaglia in %s" % engine.st.rname(req["r"]), "Vuoi spendere il tuo Favore Papale per avere +1 in battaglia?", ["Sì, spendo il Favore", "No, lo tengo"], func(i): _provide(i == 0))
		"battle_gov":
			_choice_modal("Battaglia in %s" % engine.st.rname(req["r"]), "%s dà battaglia agli invasori. Come Governatore puoi aggiungere +1 al suo attacco. Se vince, diventerà lui il Governatore." % engine.pname(req["p"]),
				["Sì, lo aiuto", "No"], func(i): _provide(i == 0))
	refresh()
	_build_prompt()


func _provide(v) -> void:
	pending = {}
	sel = {}
	step = ""
	for c in modal.get_children():
		c.queue_free()
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.set_highlight([], [])
	_build_prompt()
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


func _choice_modal(title: String, text: String, options: Array, cb: Callable) -> void:
	var vb := _modal_box(title)
	vb.add_child(UI.wrap(text, 20, UI.INK, 540))
	for i in options.size():
		var b := UI.button(options[i], 540, 50, 18)
		if i == 0:
			UI.primary(b)
		var ii = i
		b.pressed.connect(func(): cb.call(ii))
		vb.add_child(b)


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
		col.add_child(UI.wrap(SKData.obj_text(id), 17, UI.INK2, 300))
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

func _me() -> int:
	return int(pending.get("seat", -1))


func _pick_char(c: String) -> void:
	if pending.get("type", "") != "turn":
		_show_card(c)
		return
	var st: SKState = engine.st
	if st.used.has(c):
		_show_card(c)
		return
	var pw: bool = sel.get("pw", false) and st.favor[_me()]
	sel = {"c": c, "pw": pw}
	step = "dest"
	refresh()
	_build_prompt()


func _show_card(c: String) -> void:
	var vb := _modal_box(SKData.CHAR_NAME[c], 520)
	var tr := UI.icon(SKData.CHAR_CARD[c], 420)
	tr.custom_minimum_size = Vector2(420, 630)
	vb.add_child(tr)
	vb.add_child(UI.wrap("Azione passiva: " + SKData.CHAR_TEXT[c]["passiva"], 18, UI.INK, 460))
	var b := UI.button("Chiudi", 200, 46, 18)
	b.pressed.connect(func():
		_close_modal())
	vb.add_child(b)


func _dests() -> Array:
	var out := []
	for path in engine.st.move_paths(sel["c"]):
		var d: int = path[path.size() - 1]
		if not out.has(d):
			out.append(d)
	return out


func _path_to(d: int) -> Array:
	var best := []
	for path in engine.st.move_paths(sel["c"]):
		if path[path.size() - 1] == d and (best.is_empty() or path.size() < best.size()):
			best = path
	return best


func _on_region(r: int) -> void:
	var st: SKState = engine.st
	if pending.is_empty():
		return
	match step:
		"setup":
			if st.setup_regions().has(r):
				_provide(r)
		"dest":
			if _dests().has(r):
				sel["path"] = _path_to(r)
				_after_dest()
		"king_adj":
			var sl := st.king_normal_slots(_dest())
			if sl["adj"].has(r):
				sel["adj"] = r
				_king_default()
		"king_pw":
			if _king_pw_cand().has(r) and sel["pl"].size() < 2:
				sel["pl"].append([r, _me()])
				if sel["pl"].size() >= 2:
					step = "confirm"
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
	refresh()
	_build_prompt()


func _on_site(r: int, i: int) -> void:
	var st: SKState = engine.st
	if step == "spy_a":
		if r == _dest() and st.spy_sites(r, sel["pw"]).has(i):
			sel["a"] = [r, i]
			step = "spy_b"
			refresh()
			_build_prompt()
	elif step == "spy_b":
		if st.land[_dest()].has(r) and st.spy_sites(r, sel["pw"]).has(i):
			sel["b"] = [r, i]
			step = "confirm"
			refresh()
			_build_prompt()


func _dest() -> int:
	var p: Array = sel.get("path", [])
	return p[p.size() - 1] if not p.is_empty() else -1


func _after_dest() -> void:
	var st: SKState = engine.st
	var d := _dest()
	match sel["c"]:
		"re":
			if sel["pw"]:
				sel["pl"] = []
				step = "king_pw" if not _king_pw_cand().is_empty() else "confirm"
			else:
				var sl := st.king_normal_slots(d)
				sel.erase("adj")
				if sl["adj"].size() == 1:
					sel["adj"] = sl["adj"][0]
				if sl["adj"].size() > 1:
					step = "king_adj"
					sel["pl"] = []
				else:
					_king_default()
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


func _king_pw_cand() -> Array:
	var out := []
	var d := _dest()
	var adj_used := -1
	for x in sel.get("pl", []):
		if int(x[0]) != d:
			adj_used = int(x[0])
	for r in [d] + engine.st.land[d]:
		if engine.st._king_region_ok(r, true) and (adj_used == -1 or r == d or r == adj_used):
			out.append(r)
	return out


## Il Re (azione normale): i villaggi vanno nel suo regno e in quello adiacente scelto; di base i
## tuoi, con uno dell'avversario che segue nell'ordine (lo si può cambiare).
func _king_default() -> void:
	var st: SKState = engine.st
	var me := _me()
	var sl := st.king_normal_slots(_dest())
	var pl := []
	for i in sl["main"]:
		pl.append([_dest(), me])
	if sel.has("adj"):
		pl.append([int(sel["adj"]), me])
	if pl.size() >= 2:
		var other := (me + 1) % st.n
		for k in st.n:
			var q := (me + 1 + k) % st.n
			if q != me and st.reserve[q] > 0:
				other = q
				break
		pl[pl.size() - 1][1] = other
	sel["pl"] = pl
	step = "confirm"


func _apply_highlight() -> void:
	var st: SKState = engine.st
	var regs := []
	var sts := []
	match step:
		"setup":
			regs = st.setup_regions()
		"dest":
			regs = _dests()
		"king_adj":
			regs = st.king_normal_slots(_dest())["adj"]
		"king_pw":
			regs = _king_pw_cand()
		"pope_t":
			regs = st.pope_targets(_dest(), sel.get("pw", false))
		"pope_b":
			regs = st.free_cathedrals()
		"spy_a":
			for i in st.spy_sites(_dest(), sel["pw"]):
				sts.append([_dest(), i])
		"spy_b":
			for r in st.land[_dest()]:
				for i in st.spy_sites(r, sel["pw"]):
					sts.append([r, i])
	if pending.is_empty():
		regs = pause_regs.duplicate()
		sts = []
	board.set_highlight(regs, sts)


func _build_prompt() -> void:
	for c in prompt_box.get_children():
		c.queue_free()
	var st: SKState = engine.st
	if pending.is_empty():
		if engine.cur >= 0 and not game_done:
			prompt_box.add_child(UI.wrap("Tocca a %s…" % engine.pname(engine.cur), 19, UI.PARCH, RW - 40, UI.font_italic))
		return
	var me := _me()
	var t: String = pending["type"]
	if t == "setup":
		prompt_box.add_child(UI.title("Piazzamento iniziale", 20))
		prompt_box.add_child(UI.wrap("%s, scegli un regno per un tuo villaggio (giro %d di 3): va sul sito libero più basso, partendo dal Governatore, e prendi la risorsa che c'era." % [engine.pname(me), int(pending.get("round", 0)) + 1], 18, UI.LIGHT, RW - 40))
		_region_buttons(st.setup_regions(), func(r): _provide(r))
		return
	if t != "turn":
		return
	prompt_box.add_child(UI.title("La tua mossa, %s" % engine.pname(me), 20))
	if st.favor[me]:
		var pwb := UI.button("Azione potenziata: " + ("SÌ" if sel.get("pw", false) else "no"), 300, 40, 14)
		if sel.get("pw", false):
			UI.gold(pwb)
		pwb.tooltip_text = "Scarta il Favore Papale per fare l'azione potenziata del personaggio."
		pwb.pressed.connect(func():
			var c0: String = sel.get("c", "")
			sel = {"pw": not sel.get("pw", false)}
			if c0 != "":
				sel["c"] = c0
				step = "dest"
			else:
				step = "char"
			refresh()
			_build_prompt())
		prompt_box.add_child(pwb)
	if step == "char" or not sel.has("c"):
		prompt_box.add_child(UI.wrap("Scegli un personaggio libero sulla plancia qui sopra (o tocca la sua carta per leggerne le azioni). Poi lo sposti e fai la sua azione.", 18, UI.LIGHT, RW - 40))
		return
	var c: String = sel["c"]
	var mode := " (potenziata)" if sel.get("pw", false) else ""
	prompt_box.add_child(UI.label(SKData.CHAR_NAME[c] + mode, 19, UI.GOLD, UI.font_title))
	match step:
		"dest":
			prompt_box.add_child(UI.wrap("Dove lo sposti? (Il movimento è obbligatorio; i regni illuminati sono raggiungibili%s.)" % ("" if c == "cavalleria" else ", anche via porto"), 18, UI.LIGHT, RW - 40))
			_region_buttons(_dests(), func(r): _on_region(r))
		"king_adj":
			prompt_box.add_child(UI.wrap("In quale regno adiacente metti il terzo villaggio?", 18, UI.LIGHT, RW - 40))
			_region_buttons(st.king_normal_slots(_dest())["adj"], func(r): _on_region(r))
		"king_pw":
			prompt_box.add_child(UI.wrap("Scegli i regni dei due villaggi (%d/2): il regno del Re o uno adiacente, anche lo stesso due volte." % sel["pl"].size(), 18, UI.LIGHT, RW - 40))
			_region_buttons(_king_pw_cand(), func(r): _on_region(r))
		"pope_t":
			prompt_box.add_child(UI.wrap("Dove metti l'influenza religiosa?", 18, UI.LIGHT, RW - 40))
			_region_buttons(st.pope_targets(_dest(), sel["pw"]), func(r): _on_region(r))
		"pope_b":
			prompt_box.add_child(UI.wrap("In quale Cattedrale nomini il tuo Vescovo?", 18, UI.LIGHT, RW - 40))
			_region_buttons(st.free_cathedrals(), func(r): _on_region(r))
		"merch":
			_merchant_panel()
		"spy_a":
			prompt_box.add_child(UI.wrap("Tocca un villaggio nel regno della Spia (%s)%s." % [st.rname(_dest()), "" if sel["pw"] else ", non il Governatore"], 18, UI.LIGHT, RW - 40))
			var nb := UI.button("Nessuno scambio", 220, 38, 14)
			nb.pressed.connect(func():
				step = "confirm"
				_build_prompt())
			prompt_box.add_child(nb)
		"spy_b":
			prompt_box.add_child(UI.wrap("Ora tocca il villaggio con cui scambiarlo, in un regno adiacente (collegato da un ponte).", 18, UI.LIGHT, RW - 40))
	if step == "confirm" or step == "king_pw" or step == "merch":
		_placement_editor()
		var err := st.check_move(me, _move())
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var ok := UI.primary(UI.button("Conferma", 180, 48, 18))
		ok.disabled = err != ""
		ok.pressed.connect(func(): _provide(_move()))
		row.add_child(ok)
		if c in ["fanteria", "cavalleria"] and st.regions[_dest()]["war"]:
			prompt_box.add_child(UI.wrap("Il regno è in guerra: dichiari battaglia (si combatte nelle azioni passive).", 17, UI.GOLD, RW - 40))
		if err != "" and step == "confirm":
			prompt_box.add_child(UI.wrap("Non ancora: " + err + ".", 16, Color("#ff9a8a"), RW - 40))
		prompt_box.add_child(row)
		prompt_box.add_child(UI.wrap(_summary(), 16, UI.PARCH, RW - 40, UI.font_italic))
	var back := UI.button("Annulla", 140, 38, 14)
	back.pressed.connect(func():
		sel = {"pw": sel.get("pw", false)}
		step = "char"
		refresh()
		_build_prompt())
	prompt_box.add_child(back)


func _region_buttons(list: Array, cb: Callable) -> void:
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	for r in list:
		var b := UI.button(SKData.TILES[engine.st.regions[r]["tile"]]["short"], 126, 36, 13)
		var rr: int = r
		b.pressed.connect(func(): cb.call(rr))
		b.mouse_entered.connect(func(): board.set_highlight([rr], []))
		b.mouse_exited.connect(_apply_highlight)
		fl.add_child(b)
	prompt_box.add_child(fl)


## Colori dei villaggi del Re (si possono cambiare).
func _placement_editor() -> void:
	if sel.get("c", "") != "re" or not sel.has("pl"):
		return
	var st: SKState = engine.st
	for k in sel["pl"].size():
		var x: Array = sel["pl"][k]
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 4)
		var lb := UI.label("%s:" % SKData.TILES[st.regions[int(x[0])]["tile"]]["short"], 16, UI.LIGHT, UI.font_bold)
		lb.custom_minimum_size = Vector2(100, 0)
		hb.add_child(lb)
		for q in st.n:
			var b := UI.button("", 52, 34, 12)
			UI.colored(b, UI.pcol(q))
			if int(x[1]) == q:
				b.add_theme_stylebox_override("normal", UI.flat(UI.pcol(q).lightened(0.15), Color.WHITE, 4, 6, 6))
				b.text = "•"
			b.tooltip_text = engine.pname(q) + " (riserva %d)" % st.reserve[q]
			var kk = k
			var qq: int = q
			b.pressed.connect(func():
				sel["pl"][kk][1] = qq
				_build_prompt())
			hb.add_child(b)
		prompt_box.add_child(hb)


func _merchant_panel() -> void:
	var st: SKState = engine.st
	var me := _me()
	var need := 2 if sel["pw"] else 1
	prompt_box.add_child(UI.wrap("Prendi %d risors%s dalla riserva di un avversario." % [need, "e" if need > 1 else "a"], 18, UI.LIGHT, RW - 40))
	for q in st.n:
		if q == me or st.total_res(q) <= 0:
			continue
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 4)
		var lb := UI.label(engine.pname(q), 16, UI.plight(q), UI.font_bold)
		lb.custom_minimum_size = Vector2(110, 0)
		lb.clip_text = true
		hb.add_child(lb)
		for t in SKData.RESOURCES:
			var have: int = st.res[q][t]
			var taken: int = sel["res"].count(t) if sel["from"] == q else 0
			var b := Button.new()
			b.custom_minimum_size = Vector2(52, 40)
			b.icon = UI.tex("res://assets/res/%s.webp" % t)
			b.expand_icon = true
			b.text = "%d" % (have - taken)
			b.disabled = have - taken <= 0
			b.tooltip_text = "%s di %s" % [SKData.RES_NAME[t], engine.pname(q)]
			if taken > 0:
				UI.gold(b)
			var qq: int = q
			var tt: String = t
			b.pressed.connect(func():
				if sel["from"] != qq:
					sel["from"] = qq
					sel["res"] = []
				if sel["res"].size() >= need:
					sel["res"] = []
				sel["res"].append(tt)
				_build_prompt())
			hb.add_child(b)
		prompt_box.add_child(hb)


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


func _summary() -> String:
	var st: SKState = engine.st
	var m := _move()
	var d := _dest()
	if d < 0:
		return ""
	var s := "%s va in %s. " % [SKData.CHAR_SHORT[m["c"]], st.rname(d)]
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
			if m["from"] >= 0 and not m["res"].is_empty():
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
	var st: SKState = engine.st
	var vb := _modal_box("Fine della partita", 900)
	vb.add_child(UI.wrap(SKState.END_TEXT.get(st.end_reason, ""), 20, UI.INK2, 840, UI.font_italic))
	var w: Dictionary = results[0]
	vb.add_child(UI.title("Vince %s!" % engine.pname(w["p"]) + (" (obiettivo segreto)" if w["instant"] else ""), 32, UI.pcol(w["p"]).darkened(0.2)))
	var gr := GridContainer.new()
	gr.columns = 10
	gr.add_theme_constant_override("h_separation", 14)
	for h in ["", "Casato", "Villaggi", "Gov.", "Vescovi", "Risorse", "Corona", "Favore", "Obiettivo", "Totale"]:
		gr.add_child(UI.label(h, 16, UI.INK2, UI.font_bold))
	var pos := 1
	for d in results:
		gr.add_child(UI.label("%d°" % pos, 18, UI.INK, UI.font_title))
		gr.add_child(UI.label(engine.pname(d["p"]), 18, UI.pcol(d["p"]).darkened(0.3), UI.font_bold))
		for k in ["villaggi", "gov", "vescovi", "risorse", "corona", "favore", "obiettivo", "tot"]:
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
