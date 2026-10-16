extends Control
## Menu principale: i casati al tavolo (Umano / IA / Assente) con il livello dell'IA, la mappa
## (scenario), le opzioni, la vista 2D/3D, il gioco online, le regole e l'editor delle mappe.

const MODES := ["Umano", "IA", "Assente"]
const LEVELS := ["Facile", "Normale", "Difficile"]

var main
var seat_mode := [0, 1, 1, 1]
var levels := [1, 1, 1, 1]
var names := ["Casato Rosso", "Casato Blu", "Casato Verde", "Casato Giallo"]
var speed := 1
var scen_i := 0
var opts := {"objectives": true, "dice": false}
var map3d := true
var pieces3d := true
var msg: Label
var rows: VBoxContainer
var scen_box: VBoxContainer
var scens: Array = []

const OPT_LIST := [
	["objectives", "Carte obiettivo", "Ognuno pesca 3 carte obiettivo e ne tiene una in segreto: punti extra a fine partita (o la vittoria, per il Nemico e l'Usurpatore). Consigliate per le prime partite."],
	["dice", "Guerra con dado", "Regola opzionale: in battaglia si tira un dado e si vince superando il numero di invasori (+1 Favore Papale, +1 Fanteria, +1 Governatore)."],
]


func _ready() -> void:
	size = get_viewport_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if main.menu_state.has("seat_mode"):
		var ms: Dictionary = main.menu_state
		seat_mode = ms["seat_mode"].duplicate()
		levels = ms["levels"].duplicate()
		names = ms["names"].duplicate()
		speed = ms["speed"]
		scen_i = ms.get("scen_i", 0)
		opts = ms.get("opts", opts).duplicate()
		map3d = ms.get("map3d", true)
		pieces3d = ms.get("pieces3d", true)
	scens = main.all_scenarios()
	scen_i = clampi(scen_i, 0, scens.size() - 1)
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var vp := get_viewport_rect().size
	var bg := TextureRect.new()
	bg.texture = UI.tex("res://assets/ui/cover.webp")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.1, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var outer := MarginContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, 40 if side != "top" else 24)
	sc.add_child(outer)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	outer.add_child(col)
	var t := UI.label("Seven Kingdom", 84 if vp.x > 1200 else 54, UI.GOLD, UI.font_deco)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	t.add_theme_constant_override("shadow_offset_x", 4)
	t.add_theme_constant_override("shadow_offset_y", 4)
	t.add_theme_color_override("font_outline_color", Color("#2a1708"))
	t.add_theme_constant_override("outline_size", 8)
	col.add_child(t)
	var tag := UI.label("Sette regni, sei personaggi, una sola mossa per turno. Un gioco di Stefano & Simone Ancillai.", 24, UI.PARCH, UI.font_italic)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	tag.add_theme_constant_override("shadow_offset_x", 2)
	tag.add_theme_constant_override("shadow_offset_y", 2)
	col.add_child(tag)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 20)
	flow.add_theme_constant_override("v_separation", 20)
	col.add_child(flow)
	# casati al tavolo
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.parchment(24))
	box.custom_minimum_size = Vector2(minf(760, vp.x - 80), 0)
	flow.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	box.add_child(vb)
	vb.add_child(UI.title("I casati al tavolo", 30, UI.INK))
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	vb.add_child(rows)
	_refresh_rows()
	var sp := HBoxContainer.new()
	sp.add_theme_constant_override("separation", 8)
	sp.add_child(UI.label("Velocità dell'IA:", 20, UI.INK, UI.font_bold))
	for i in 4:
		var b := UI.button(["Calma", "Normale", "Rapida", "Lampo"][i], 110, 38, 14)
		if i == speed:
			UI.primary(b)
		var ii := i
		b.pressed.connect(func():
			speed = ii
			_store()
			_build())
		sp.add_child(b)
	vb.add_child(sp)
	for o in OPT_LIST:
		var cb := CheckBox.new()
		cb.text = o[1]
		cb.tooltip_text = o[2]
		cb.button_pressed = opts.get(o[0], false)
		var key: String = o[0]
		cb.toggled.connect(func(on): opts[key] = on)
		vb.add_child(cb)
	var vw := HBoxContainer.new()
	vw.add_theme_constant_override("separation", 8)
	vw.add_child(UI.label("Vista:", 20, UI.INK, UI.font_bold))
	var bm := UI.button("Mappa 3D" if map3d else "Mappa 2D", 150, 38, 14)
	bm.pressed.connect(func():
		map3d = not map3d
		_store()
		_build())
	vw.add_child(bm)
	var bp := UI.button("Pedine 3D" if pieces3d else "Pedine 2D", 150, 38, 14)
	bp.pressed.connect(func():
		pieces3d = not pieces3d
		_store()
		_build())
	vw.add_child(bp)
	vw.add_child(UI.label("(si cambiano anche in partita)", 17, UI.INK2, UI.font_italic))
	vb.add_child(vw)
	msg = UI.label("", 19, UI.RED, UI.font_bold)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(msg)
	# mappa
	var box2 := PanelContainer.new()
	box2.add_theme_stylebox_override("panel", UI.parchment(24))
	box2.custom_minimum_size = Vector2(minf(560, vp.x - 80), 0)
	flow.add_child(box2)
	scen_box = VBoxContainer.new()
	scen_box.add_theme_constant_override("separation", 10)
	box2.add_child(scen_box)
	_refresh_scen()
	# pulsanti
	var btns := HFlowContainer.new()
	btns.add_theme_constant_override("h_separation", 14)
	btns.add_theme_constant_override("v_separation", 12)
	col.add_child(btns)
	var play := UI.primary(UI.button("Gioca", 230, 62, 26))
	play.pressed.connect(_on_start)
	btns.add_child(play)
	var onl := UI.button("Gioca online", 270, 62, 24)
	onl.pressed.connect(_online_panel)
	btns.add_child(onl)
	var rul := UI.button("Regole", 190, 62, 24)
	rul.pressed.connect(func():
		_store()
		main.show_rules())
	btns.add_child(rul)
	var edi := UI.button("Editor delle mappe", 290, 62, 22)
	edi.pressed.connect(func():
		_store()
		main.show_editor())
	btns.add_child(edi)
	btns.add_child(Audio.toggle_button("music", 160, 62))
	btns.add_child(Audio.toggle_button("sfx", 160, 62))
	var ses: Dictionary = main.get_net().load_session()
	if str(ses.get("room", "")) != "":
		_online_panel()


func _refresh_rows() -> void:
	for ch in rows.get_children():
		ch.queue_free()
	for i in 4:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		var dot := TextureRect.new()
		dot.texture = UI.tex("res://assets/tokens/villaggio_%s.webp" % SKData.COLORS[i]["id"])
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dot.custom_minimum_size = Vector2(44, 44)
		hb.add_child(dot)
		var le := LineEdit.new()
		le.text = names[i]
		le.max_length = 18
		le.custom_minimum_size = Vector2(200, 42)
		var ii := i
		le.text_changed.connect(func(t2): names[ii] = t2)
		le.editable = seat_mode[i] != 2
		hb.add_child(le)
		for m in 3:
			var b := UI.button(MODES[m], 96, 42, 14)
			if seat_mode[i] == m:
				UI.primary(b)
			var mm := m
			b.pressed.connect(func():
				seat_mode[ii] = mm
				_refresh_rows())
			hb.add_child(b)
		if seat_mode[i] == 1:
			var lv := UI.gold(UI.button(LEVELS[levels[i]], 116, 42, 14))
			lv.tooltip_text = "Livello dell'IA (clicca per cambiarlo)"
			lv.pressed.connect(func():
				levels[ii] = (levels[ii] + 1) % 3
				_refresh_rows())
			hb.add_child(lv)
		rows.add_child(hb)


func _refresh_scen() -> void:
	for c in scen_box.get_children():
		c.queue_free()
	scen_box.add_child(UI.title("La mappa", 30, UI.INK))
	var s: Dictionary = scens[scen_i]
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var prev := UI.button("‹", 50, 42, 26)
	prev.pressed.connect(func():
		scen_i = (scen_i + scens.size() - 1) % scens.size()
		_refresh_scen())
	hb.add_child(prev)
	var nm := UI.label(s.get("n", "Mappa"), 25, UI.INK, UI.font_title)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb.add_child(nm)
	var nxt := UI.button("›", 50, 42, 26)
	nxt.pressed.connect(func():
		scen_i = (scen_i + 1) % scens.size()
		_refresh_scen())
	hb.add_child(nxt)
	scen_box.add_child(hb)
	var mini := MapPreview.new()
	mini.scen = s
	mini.custom_minimum_size = Vector2(500, 300)
	scen_box.add_child(mini)
	scen_box.add_child(UI.wrap(s.get("desc", ""), 19, UI.INK2, 500))
	var errs := SKData.validate_scenario(s)
	if not errs.is_empty():
		scen_box.add_child(UI.wrap("Questa mappa ha dei problemi: " + " ".join(errs), 17, UI.RED, 500))
	if s.get("custom", false):
		var hb2 := HBoxContainer.new()
		hb2.add_theme_constant_override("separation", 8)
		var ed := UI.button("Modifica", 150, 38, 14)
		ed.pressed.connect(func():
			_store()
			main.show_editor(s))
		hb2.add_child(ed)
		var dl := UI.button("Elimina", 150, 38, 14)
		dl.pressed.connect(func():
			main.delete_custom(s["id"])
			scens = main.all_scenarios()
			scen_i = 0
			_refresh_scen())
		hb2.add_child(dl)
		scen_box.add_child(hb2)


func _store() -> void:
	main.menu_state = {"seat_mode": seat_mode.duplicate(), "levels": levels.duplicate(), "names": names.duplicate(),
		"speed": speed, "scen_i": scen_i, "opts": opts.duplicate(), "map3d": map3d, "pieces3d": pieces3d}


## Configurazione scelta nel menu (anche quella che, online, viaggia agli altri).
func _config() -> Dictionary:
	var players := []
	var colors := []
	for i in 4:
		var m: int = seat_mode[i]
		if m == 2:
			continue
		var nm: String = names[i].strip_edges()
		if nm == "":
			nm = "Casato " + SKData.COLORS[i]["n"]
		players.append({"name": nm, "ai": m == 1, "level": levels[i]})
		colors.append(i)
	var speeds := [1.2, 0.7, 0.25, 0.0]
	var o := {}
	for k in opts:
		if opts[k]:
			o[k] = true
	return {"players": players, "colors": colors, "ai_delay": speeds[speed], "opts": o, "scenario": scens[scen_i],
		"map3d": map3d, "pieces3d": pieces3d, "seed": 1 + randi() % 2000000000}


func _on_start() -> void:
	var cfg := _config()
	if cfg["players"].size() < 2:
		msg.text = "Seven Kingdom si gioca da 2 a 4: metti al tavolo almeno 2 casati."
		return
	var errs := SKData.validate_scenario(cfg["scenario"])
	if not errs.is_empty():
		msg.text = "La mappa scelta non è valida: " + errs[0]
		return
	_store()
	main.start_game(cfg)


# =================================================================== online

var on_panel: Control
var on_name: LineEdit
var on_code: LineEdit
var on_lbl: Label
var on_start: Button


func _online_panel() -> void:
	if is_instance_valid(on_panel):
		on_panel.queue_free()
	on_panel = Control.new()
	on_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	on_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(on_panel)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.1, 0.8)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	on_panel.add_child(shade)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	on_panel.add_child(cc)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.parchment(30))
	box.custom_minimum_size = Vector2(minf(780, get_viewport_rect().size.x - 40), 0)
	cc.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	box.add_child(vb)
	vb.add_child(UI.title("Gioca online", 40, UI.INK))
	vb.add_child(UI.wrap("Chi crea la stanza sceglie prima nel menu i casati, la mappa, le opzioni e il livello dell'IA: i casati su Umano diventano i posti per gli amici (il primo è il suo). Gli amici entrano con il codice. I posti rimasti liberi li gioca l'IA.", 20, UI.INK2, 700))
	var ses: Dictionary = main.get_net().load_session()
	on_name = _line("Il tuo nome", 20)
	on_name.text = str(ses.get("name", ""))
	vb.add_child(on_name)
	var b_create := UI.primary(UI.button("Crea una stanza", 300, 58, 22))
	b_create.pressed.connect(_online_create)
	vb.add_child(b_create)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	on_code = _line("Codice", 4)
	on_code.custom_minimum_size.x = 220
	on_code.text_changed.connect(func(t):
		on_code.text = t.to_upper()
		on_code.caret_column = t.length())
	row.add_child(on_code)
	var b_join := UI.primary(UI.button("Entra", 200, 58, 22))
	b_join.pressed.connect(_online_join)
	row.add_child(b_join)
	vb.add_child(row)
	on_lbl = UI.wrap("", 20, UI.INK, 700)
	on_lbl.custom_minimum_size.y = 110
	vb.add_child(on_lbl)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	on_start = UI.primary(UI.button("Si comincia!", 320, 58, 22))
	on_start.pressed.connect(_online_start)
	on_start.visible = main.lobby.get("role", "") == "host"
	row2.add_child(on_start)
	var b_close := UI.button("Indietro", 220, 58, 22)
	b_close.pressed.connect(func():
		on_panel.queue_free())
	row2.add_child(b_close)
	vb.add_child(row2)
	if not main.lobby.is_empty():
		on_code.text = main.lobby["code"]
		on_lbl.text = "Stanza %s…" % main.lobby["code"]
	elif str(ses.get("room", "")) != "":
		on_code.text = str(ses["room"])
		on_lbl.text = "Eri nella stanza %s: premi Entra per rientrare." % ses["room"]


func _line(ph: String, maxlen: int) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = ph
	le.max_length = maxlen
	le.custom_minimum_size = Vector2(0, 56)
	le.add_theme_font_size_override("font_size", 22)
	return le


func _say(t: String) -> void:
	if is_instance_valid(on_lbl):
		on_lbl.text = t


func _seats_text(room: Dictionary) -> String:
	var seats := Net._as_dict(room.get("seats", {}))
	var list: Array = _config()["players"]
	var parts := []
	for idx in room.get("open", []):
		var k := str(int(idx))
		var who := str(seats[k].get("name", "?")) if seats.has(k) and seats[k] is Dictionary else "libero"
		var cname: String = list[int(idx)]["name"] if int(idx) < list.size() else "posto %d" % (int(idx) + 1)
		parts.append("%s: %s" % [cname, who])
	return ", ".join(parts)


func _online_create() -> void:
	var nm := on_name.text.strip_edges()
	if nm == "":
		_say("Scrivi il tuo nome.")
		return
	var seats := []
	var list: Array = _config()["players"]
	for i in list.size():
		if not list[i]["ai"]:
			seats.append(i)
	if list.size() < 2 or seats.size() < 2:
		_say("Servono almeno 2 casati su Umano: il primo è il tuo, gli altri sono i posti per gli amici.")
		return
	_store()
	_say("Creo la stanza…")
	var net: Net = main.get_net()
	var code := await net.create_room(nm, seats)
	if code == "":
		_say("Non riesco a creare la stanza.\n%s" % net.last_error)
		return
	main.lobby = {"role": "host", "code": code, "seat": seats[0]}
	net.remember_room(code, seats[0])
	net._save({"name": nm})
	if is_instance_valid(on_code):
		on_code.text = code
	if is_instance_valid(on_start):
		on_start.visible = true
	_lobby_poll(code)


func _online_join() -> void:
	var code := on_code.text.strip_edges().to_upper()
	var nm := on_name.text.strip_edges()
	if nm == "" or code.length() != 4:
		_say("Scrivi il tuo nome e il codice di 4 lettere.")
		return
	_say("Entro nella stanza %s…" % code)
	var net: Net = main.get_net()
	var seat := await net.join_room(code, nm)
	if seat == -2:
		_say("Stanza %s non trovata, oppure la partita è già iniziata.%s" % [code, ("\n" + net.last_error) if net.last_error != "" else ""])
		return
	if seat == -1:
		_say("Nella stanza %s non ci sono posti liberi." % code)
		return
	var room: Dictionary = net.last_room
	main.lobby = {"role": "host" if room.get("host", "") == net.uid else "guest", "code": code, "seat": seat}
	net.remember_room(code, seat)
	net._save({"name": nm})
	if room.get("status", "") in ["playing", "over"] and room.has("game"):
		_say("Rientro nella partita della stanza %s…" % code)
		_begin(room["game"], true)
		return
	if is_instance_valid(on_start):
		on_start.visible = main.lobby["role"] == "host"
	_lobby_poll(code)


func _lobby_poll(code: String) -> void:
	var net: Net = main.get_net()
	while is_inside_tree() and main.lobby.get("code", "") == code:
		var room := await net.room(code)
		if not is_inside_tree() or main.lobby.get("code", "") != code:
			return
		if room.is_empty():
			_say("La stanza %s non esiste più." % code)
			main.lobby = {}
			return
		if main.lobby["role"] == "host":
			_say("Stanza [ %s ]: dai il codice ai tuoi amici.\nPosti: %s.\nQuando ci siete tutti premi Si comincia!: i posti liberi li gioca l'IA." % [code, _seats_text(room)])
		else:
			if room.get("status", "") == "playing" and room.has("game"):
				_begin(room["game"], false)
				return
			_say("Sei nella stanza [ %s ] (posto %d).\nPosti: %s.\nAspetta che chi l'ha creata avvii la partita." % [code, int(main.lobby["seat"]) + 1, _seats_text(room)])
		await get_tree().create_timer(2.0).timeout


## Chi ha creato la stanza avvia: casati, mappa, opzioni e seme valgono per tutti.
func _online_start() -> void:
	var code: String = main.lobby["code"]
	var net: Net = main.get_net()
	var room := await net.room(code)
	if room.is_empty():
		_say("La stanza %s non esiste più." % code)
		main.lobby = {}
		return
	var seats_db := Net._as_dict(room.get("seats", {}))
	var cfg := _config()
	var my_seat := int(main.lobby["seat"])
	if my_seat >= cfg["players"].size() or not seats_db.has(str(my_seat)) or cfg["players"][my_seat]["ai"]:
		_say("Hai cambiato i casati dopo aver creato la stanza: creane una nuova.")
		return
	for i in cfg["players"].size():
		var k := str(i)
		if seats_db.has(k) and seats_db[k] is Dictionary and not cfg["players"][i]["ai"]:
			cfg["players"][i]["name"] = str(seats_db[k].get("name", cfg["players"][i]["name"]))
		else:
			cfg["players"][i]["ai"] = true
	cfg.erase("map3d")
	cfg.erase("pieces3d")
	var g := {"cfg": var_to_str(cfg)}
	if not await net.start_room(code, g):
		_say("Non riesco ad avviare la partita (%s)." % net.last_error)
		return
	_begin(g, false)


## Avvio (o rientro) della partita online.
func _begin(g: Dictionary, rejoin: bool) -> void:
	var net: Net = main.get_net()
	var lob: Dictionary = main.lobby
	var backlog: Array = []
	if rejoin:
		backlog = await net.get_acts(lob["code"])
		net.set_away(lob["code"], int(lob["seat"]), false)
	var cfg = str_to_var(str(g.get("cfg", "")))
	if not (cfg is Dictionary):
		_say("Configurazione della partita non valida.")
		return
	var ses := OnlineSession.new()
	ses.setup(net, lob["code"], int(lob["seat"]), lob["role"], backlog)
	cfg["online"] = ses
	cfg["map3d"] = map3d
	cfg["pieces3d"] = pieces3d
	main.lobby = {}
	main.start_game(cfg)
