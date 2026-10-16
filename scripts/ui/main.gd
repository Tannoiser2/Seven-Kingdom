extends Control
## Radice dell'applicazione: alterna menu, partita, regole ed editor delle mappe.

var current: Control
## Collegamento a Firebase per il gioco online (resta vivo fra menu e partita).
var net: Net
## Stanza online in preparazione: {role, code, seat}. Vuota se non si è in una stanza.
var lobby := {}
## Ultime scelte del menu (si ritrovano tornando al menu).
var menu_state := {}
var bg: ColorRect


func get_net() -> Net:
	if net == null:
		net = Net.new()
		add_child(net)
	return net


func _ready() -> void:
	theme = UI.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg = ColorRect.new()
	bg.color = Color("#0b1220")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var au := Audio.new()
	add_child(au)
	get_tree().node_added.connect(func(n):
		if n is BaseButton:
			(n as BaseButton).pressed.connect(func(): Audio.play("click", -6.0)))
	add_child(bg)
	show_menu()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_F11:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _clear() -> void:
	if current != null:
		current.queue_free()
		current = null


func show_menu() -> void:
	_clear()
	bg.visible = true
	var m := preload("res://scripts/ui/menu.gd").new()
	m.main = self
	add_child(m)
	current = m


func start_game(config: Dictionary) -> void:
	_clear()
	bg.visible = false
	var g := preload("res://scripts/ui/game_view.gd").new()
	g.main = self
	g.config = config
	add_child(g)
	current = g


func show_rules() -> void:
	_clear()
	bg.visible = true
	var t := preload("res://scripts/ui/rules_view.gd").new()
	t.main = self
	add_child(t)
	current = t


func show_editor(scen = null) -> void:
	_clear()
	bg.visible = true
	var e := preload("res://scripts/ui/editor.gd").new()
	e.main = self
	if scen != null:
		e.scen = scen
	add_child(e)
	current = e


# ------------------------------------------------------------------ scenari salvati

const SCEN_FILE := "user://scenari.json"


func custom_scenarios() -> Array:
	if not FileAccess.file_exists(SCEN_FILE):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(SCEN_FILE))
	return d if d is Array else []


func save_custom(scen: Dictionary) -> void:
	var list := custom_scenarios()
	var found := false
	for i in list.size():
		if list[i].get("id", "") == scen["id"]:
			list[i] = scen
			found = true
	if not found:
		list.append(scen)
	var f := FileAccess.open(SCEN_FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify(list))
	f.close()


func delete_custom(id: String) -> void:
	var list := custom_scenarios().filter(func(s): return s.get("id", "") != id)
	var f := FileAccess.open(SCEN_FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify(list))
	f.close()


## Tutti gli scenari: quelli del gioco e quelli fatti con l'editor.
func all_scenarios() -> Array:
	var out := []
	for s in SKData.SCENARIOS:
		out.append(s)
	for s in custom_scenarios():
		out.append(normalize(s))
	return out


## Le chiavi delle tessere da JSON arrivano come testo: le riporta a numeri.
static func normalize(s: Dictionary) -> Dictionary:
	var o := s.duplicate(true)
	var t := {}
	for k in o.get("tiles", {}):
		t[int(k)] = o["tiles"][k]
	o["tiles"] = t
	var br := []
	for b in o.get("bridges", []):
		br.append([int(b[0]), int(b[1])])
	o["bridges"] = br
	var ps := []
	for p in o.get("ports", []):
		ps.append({"id": str(p["id"]), "pos": int(p["pos"]), "edge": int(p["edge"])})
	o["ports"] = ps
	return o


## Codice di condivisione di uno scenario (testo da copiare e incollare).
static func scen_code(s: Dictionary) -> String:
	return "SK1:" + Marshalls.utf8_to_base64(JSON.stringify(s))


static func scen_from_code(code: String) -> Dictionary:
	code = code.strip_edges()
	if not code.begins_with("SK1:"):
		return {}
	var txt := Marshalls.base64_to_utf8(code.substr(4))
	var d = JSON.parse_string(txt)
	return normalize(d) if d is Dictionary else {}
