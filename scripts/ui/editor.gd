extends Control
## Editor delle mappe: si dispongono le 7 tessere sulle 10 posizioni del mare, si mettono gli 11 ponti
## (clic su un lato fra due regni) e i 4 porti (clic su un lato verso il mare), si sceglie dove partono
## i personaggi. Le mappe si salvano sul dispositivo e si condividono con un codice.

var main
var scen: Dictionary = {}
var preview: MapPreview
var tool := "tile"          # tile | bridge | port
var tile_sel := "capitale"
var port_sel := "alba"
var info: Label
var errs_lbl: Label
var side: VBoxContainer
var name_edit: LineEdit
var code_edit: LineEdit


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	if scen.is_empty():
		scen = SKData.scenario("base")
		scen["id"] = "mia_%d" % (Time.get_unix_time_from_system() as int)
		scen["n"] = "La mia mappa"
		scen["desc"] = "Mappa fatta con l'editor."
	else:
		scen = scen.duplicate(true)
	scen["custom"] = true
	if SKData.SCENARIOS.any(func(s): return s["id"] == scen.get("id", "")):
		scen["id"] = "mia_%d" % (Time.get_unix_time_from_system() as int)
	var bg := ColorRect.new()
	bg.color = Color("#0b1220")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 20
	hb.offset_top = 20
	hb.offset_right = -20
	hb.offset_bottom = -20
	hb.add_theme_constant_override("separation", 20)
	add_child(hb)
	preview = MapPreview.new()
	preview.show_empty = true
	preview.scen = scen
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.pos_clicked.connect(_on_pos)
	preview.edge_clicked.connect(_on_edge)
	hb.add_child(preview)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.parchment(18))
	pc.custom_minimum_size = Vector2(520, 0)
	hb.add_child(pc)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(sc)
	side = VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(side)
	_build_side()


func _build_side() -> void:
	for c in side.get_children():
		c.queue_free()
	side.add_child(UI.label("Editor delle mappe", 34, UI.INK, UI.font_deco))
	name_edit = LineEdit.new()
	name_edit.text = scen.get("n", "")
	name_edit.placeholder_text = "Nome della mappa"
	name_edit.max_length = 40
	name_edit.text_changed.connect(func(t): scen["n"] = t)
	side.add_child(name_edit)
	var de := LineEdit.new()
	de.text = scen.get("desc", "")
	de.placeholder_text = "Descrizione"
	de.max_length = 200
	de.text_changed.connect(func(t): scen["desc"] = t)
	side.add_child(de)
	var tb := HBoxContainer.new()
	tb.add_theme_constant_override("separation", 6)
	for t in [["tile", "Tessere"], ["bridge", "Ponti"], ["port", "Porti"]]:
		var b := UI.button(t[1], 150, 42, 15)
		if tool == t[0]:
			UI.primary(b)
		var tt: String = t[0]
		b.pressed.connect(func():
			tool = tt
			_build_side())
		tb.add_child(b)
	side.add_child(tb)
	match tool:
		"tile":
			side.add_child(UI.wrap("Scegli una tessera e tocca una posizione del mare per metterla (o toglierla, se c'è già). Ogni regno compare una volta sola.", 17, UI.INK2, 470))
			var fl := HFlowContainer.new()
			fl.add_theme_constant_override("h_separation", 6)
			fl.add_theme_constant_override("v_separation", 6)
			for t in SKData.TILE_ORDER:
				var b := UI.button(SKData.TILES[t]["short"], 150, 38, 14)
				if tile_sel == t:
					UI.gold(b)
				var placed := _tiles().values().has(t)
				b.text += " •" if placed else ""
				var tt2: String = t
				b.pressed.connect(func():
					tile_sel = tt2
					_build_side())
				fl.add_child(b)
			side.add_child(fl)
		"bridge":
			side.add_child(UI.wrap("Tocca il lato fra due regni vicini per mettere o togliere un ponte. Servono %d ponti (ora %d)." % [SKData.bridges_needed(scen), scen["bridges"].size()], 17, UI.INK2, 470))
		"port":
			side.add_child(UI.wrap("Scegli un porto e tocca un lato di un regno rivolto verso il mare aperto. Le coppie I (Alba–Vespro) e II (Rupe–Bruma) sono collegate via mare.", 17, UI.INK2, 470))
			var fl2 := HFlowContainer.new()
			fl2.add_theme_constant_override("h_separation", 6)
			for id in SKData.PORT_NAMES:
				var b := UI.button(SKData.PORT_NAMES[id]["n"], 220, 38, 13)
				if port_sel == id:
					UI.gold(b)
				var ii: String = id
				b.pressed.connect(func():
					port_sel = ii
					_build_side())
				fl2.add_child(b)
			side.add_child(fl2)
	side.add_child(UI.title("Partenza dei personaggi", 22, UI.INK))
	var placed_tiles := _tiles().values()
	for c in SKData.CHARS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var lb := UI.label(SKData.CHAR_SHORT[c], 17, UI.INK, UI.font_bold)
		lb.custom_minimum_size = Vector2(110, 0)
		row.add_child(lb)
		var ob := OptionButton.new()
		ob.custom_minimum_size = Vector2(240, 34)
		var k := 0
		for t in SKData.TILE_ORDER:
			if placed_tiles.has(t):
				ob.add_item(SKData.TILES[t]["n"])
				ob.set_item_metadata(k, t)
				if scen["start"].get(c, "") == t:
					ob.select(k)
				k += 1
		var cc: String = c
		ob.item_selected.connect(func(i):
			scen["start"][cc] = ob.get_item_metadata(i)
			_refresh())
		row.add_child(ob)
		side.add_child(row)
	errs_lbl = UI.wrap("", 16, UI.RED, 470)
	side.add_child(errs_lbl)
	var row2 := HFlowContainer.new()
	row2.add_theme_constant_override("h_separation", 8)
	row2.add_theme_constant_override("v_separation", 8)
	var sv := UI.primary(UI.button("Salva", 140, 46, 17))
	sv.pressed.connect(_save)
	row2.add_child(sv)
	var cp := UI.button("Copia codice", 190, 46, 15)
	cp.pressed.connect(func():
		DisplayServer.clipboard_set(main.scen_code(_clean()))
		info.text = "Codice copiato: incollalo a un amico, lo carica con «Carica codice».")
	row2.add_child(cp)
	var back := UI.button("Torna al menu", 190, 46, 15)
	back.pressed.connect(func(): main.show_menu())
	row2.add_child(back)
	side.add_child(row2)
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 6)
	code_edit = LineEdit.new()
	code_edit.placeholder_text = "Incolla qui un codice SK1:…"
	code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(code_edit)
	var ld := UI.button("Carica codice", 170, 42, 14)
	ld.pressed.connect(func():
		var s: Dictionary = main.scen_from_code(code_edit.text)
		if s.is_empty():
			info.text = "Codice non valido."
			return
		s["id"] = "mia_%d" % (Time.get_unix_time_from_system() as int)
		s["custom"] = true
		scen = s
		preview.scen = scen
		_build_side()
		info.text = "Mappa caricata dal codice: ricordati di salvarla.")
	row3.add_child(ld)
	side.add_child(row3)
	info = UI.wrap("", 17, UI.INK, 470, UI.font_italic)
	side.add_child(info)
	_refresh()


func _tiles() -> Dictionary:
	var t := {}
	for k in scen["tiles"]:
		t[int(k)] = scen["tiles"][k]
	return t


func _refresh() -> void:
	preview.scen = scen
	preview.queue_redraw()
	var errs := SKData.validate_scenario(scen)
	if is_instance_valid(errs_lbl):
		errs_lbl.text = "Mappa pronta per giocare." if errs.is_empty() else "Da sistemare: " + " ".join(errs)
		errs_lbl.add_theme_color_override("font_color", UI.GREEN if errs.is_empty() else UI.RED)


func _on_pos(p: int) -> void:
	if tool != "tile":
		return
	var t := _tiles()
	if t.get(p, "") == tile_sel:
		t.erase(p)
	else:
		for k in t.keys():
			if t[k] == tile_sel:
				t.erase(k)
		t[p] = tile_sel
	scen["tiles"] = t
	# ponti e porti che non hanno più senso spariscono
	scen["bridges"] = scen["bridges"].filter(func(b): return t.has(int(b[0])) and t.has(int(b[1])))
	scen["ports"] = scen["ports"].filter(func(pt): return t.has(int(pt["pos"])) and not t.has(SKData.neighbor(int(pt["pos"]), int(pt["edge"]))))
	for c in SKData.CHARS:
		if not t.values().has(scen["start"].get(c, "")):
			scen["start"][c] = "capitale" if t.values().has("capitale") else (t.values()[0] if not t.is_empty() else "")
	_build_side()


func _on_edge(p: int, e: int) -> void:
	var t := _tiles()
	if not t.has(p):
		return
	var q := SKData.neighbor(p, e)
	if tool == "bridge" or (tool == "tile" and t.has(q)):
		if not t.has(q):
			info.text = "Lì non c'è un regno vicino: i ponti uniscono due tessere."
			return
		var found := -1
		for i in scen["bridges"].size():
			var b: Array = scen["bridges"][i]
			if (int(b[0]) == p and int(b[1]) == q) or (int(b[0]) == q and int(b[1]) == p):
				found = i
		if found >= 0:
			scen["bridges"].remove_at(found)
		else:
			scen["bridges"].append([p, q])
		tool = "bridge"
		_build_side()
	elif tool == "port":
		if t.has(q):
			info.text = "I porti vanno sui lati rivolti verso il mare aperto."
			return
		scen["ports"] = scen["ports"].filter(func(pt): return pt["id"] != port_sel and not (int(pt["pos"]) == p and int(pt["edge"]) == e))
		scen["ports"].append({"id": port_sel, "pos": p, "edge": e})
		# passa al porto successivo ancora da mettere
		var ids := SKData.PORT_NAMES.keys()
		for id in ids:
			if not scen["ports"].any(func(pt): return pt["id"] == id):
				port_sel = id
				break
		_build_side()


func _clean() -> Dictionary:
	var s := scen.duplicate(true)
	var t := {}
	for k in s["tiles"]:
		t[str(k)] = s["tiles"][k]
	s["tiles"] = t
	return s


func _save() -> void:
	var errs := SKData.validate_scenario(scen)
	if not errs.is_empty():
		info.text = "Prima sistema la mappa: " + errs[0]
		return
	if str(scen.get("n", "")).strip_edges() == "":
		scen["n"] = "La mia mappa"
	main.save_custom(_clean())
	info.text = "Mappa salvata: la trovi nel menu fra le mappe."
