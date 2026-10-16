class_name Board3D
extends Node3D
## Il tavolo di gioco: il tabellone del mare, le sette tessere dei regni con ponti e porti, i pezzi.
## Mappa 3D: tessere in rilievo (le altezze ricavate dai dipinti), mare animato, telecamera libera.
## Mappa 2D: tessere piatte viste dall'alto. Pedine 3D (miniature Meshy e modelli) o 2D (segnalini dipinti).

signal region_clicked(r: int)
signal site_clicked(r: int, i: int)
signal hovered(r: int, i: int)

const TILE_SCALE := 0.955
const TILE_D := 1.7466        # profondità della tessera (2 × 1172/1342)
const BASE_3D := 0.09
const BASE_2D := 0.012
const BOARD_W := 7.71
const BOARD_H := 7.99
const BOARD_Z := -0.244

var eng
var map3d := true
var pieces3d := true
var cam: Camera3D
var light: DirectionalLight3D
var env: WorldEnvironment
var root_tiles: Node3D
var root_pieces: Node3D
var root_hl: Node3D
var board_mat: ShaderMaterial
var tile_mats := {}
var tile_nodes := {}
var region_center := {}       # r -> Vector3 (al livello della tessera)
var char_spots := {}          # r -> [Vector3 locali]
var token_spots := {}         # r -> {war, peace}
var nodes := {}               # chiave -> Node3D
var vals := {}                # chiave -> valore attuale
var hl_regions: Array = []
var hl_sites: Array = []      # [[r, i]]
var hl_nodes: Array = []
var hover_r := -1
var hover_i := -1
var models := {}
var tint_shader: Shader
var _t := 0.0
# telecamera
var yaw := 0.0
var pitch := 60.0
var dist := 9.6
var target := Vector3(0.4, 0, 0.35)
var ortho_size := 8.3
var _drag := false
var _rdrag := false
var _moved := 0.0
var view_offset := Vector2.ZERO   # spostamento del centro di vista (per i pannelli laterali)


func _ready() -> void:
	tint_shader = Shader.new()
	tint_shader.code = TINT_SHADER
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#0b1220")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#c9d2e6")
	e.ambient_light_energy = 0.42
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)
	light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, -38, 0)
	light.light_energy = 0.62
	light.light_color = Color("#fff1d6")
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 30.0
	add_child(light)
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.current = true
	_build_table()
	root_tiles = Node3D.new()
	add_child(root_tiles)
	root_hl = Node3D.new()
	add_child(root_hl)
	root_pieces = Node3D.new()
	add_child(root_pieces)
	build_map()
	_update_cam()


func set_modes(p_map3d: bool, p_pieces3d: bool) -> void:
	var changed_map := p_map3d != map3d
	map3d = p_map3d
	pieces3d = p_pieces3d
	if changed_map:
		build_map()
	for k in nodes.keys():
		nodes[k].queue_free()
	nodes.clear()
	vals.clear()
	refresh(false)
	_update_cam()


func base_y() -> float:
	return BASE_3D if map3d else BASE_2D


# ------------------------------------------------------------------ tavolo e tessere

func _build_table() -> void:
	var table := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	table.mesh = pm
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color("#2a1c12")
	tm.roughness = 0.9
	table.material_override = tm
	table.position.y = -0.03
	add_child(table)
	var board := MeshInstance3D.new()
	var bm := PlaneMesh.new()
	bm.size = Vector2(BOARD_W, BOARD_H)
	bm.subdivide_width = 1
	bm.subdivide_depth = 1
	board.mesh = bm
	board_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SEA_SHADER
	board_mat.shader = sh
	board_mat.set_shader_parameter("tex", UI.tex("res://assets/board/mare.webp"))
	board.material_override = board_mat
	board.position = Vector3(0, 0, BOARD_Z)
	add_child(board)


func build_map() -> void:
	if eng == null:
		return
	for c in root_tiles.get_children():
		c.queue_free()
	tile_nodes.clear()
	var st: SKState = eng.st
	board_mat.set_shader_parameter("waves", 1.0 if map3d else 0.0)
	light.shadow_enabled = map3d
	for r in st.regions.size():
		var rg: Dictionary = st.regions[r]
		var c2: Vector2 = SKData.pos_center(rg["pos"])
		var center := Vector3(c2.x, base_y(), c2.y)
		region_center[r] = center
		var tile := Node3D.new()
		tile.position = Vector3(c2.x, 0, c2.y)
		root_tiles.add_child(tile)
		tile_nodes[r] = tile
		var top := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(2.0 * TILE_SCALE, TILE_D * TILE_SCALE)
		if map3d:
			pm.subdivide_width = 110
			pm.subdivide_depth = 96
		top.mesh = pm
		var mat := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = TILE_SHADER
		mat.shader = sh
		var t: String = rg["tile"]
		mat.set_shader_parameter("tex", UI.tex(SKData.TILES[t]["img"]))
		mat.set_shader_parameter("hmap", UI.tex("res://assets/tiles/%s_h.png" % t))
		mat.set_shader_parameter("relief", 0.16 * float(SKData.TILES[t]["relief"]) + 0.06 if map3d else 0.0)
		top.material_override = mat
		top.position.y = base_y()
		top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if map3d else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tile.add_child(top)
		tile_mats[r] = mat
		if map3d:
			tile.add_child(_skirt(BASE_3D))
		_find_spots(r)
	# ponti
	for b in st.scen["bridges"]:
		var pa := int(b[0])
		var pb := int(b[1])
		var ca: Vector2 = SKData.pos_center(pa)
		var cb: Vector2 = SKData.pos_center(pb)
		var mid := (ca + cb) / 2.0
		var dir := (cb - ca).normalized()
		root_tiles.add_child(_bridge(Vector3(mid.x, base_y(), mid.y), dir))
	# porti e rotte
	var port_pos := {}
	for pt in st.scen["ports"]:
		var p := int(pt["pos"])
		var c := SKData.pos_center(p)
		var em := SKData.edge_mid(int(pt["edge"]))
		var at := c + em * TILE_SCALE * 1.02
		var outward := em.normalized()
		port_pos[pt["id"]] = [at, outward]
		root_tiles.add_child(_port(pt["id"], Vector3(at.x, base_y(), at.y), outward))
	for pr in [["alba", "vespro"], ["rupe", "bruma"]]:
		if port_pos.has(pr[0]) and port_pos.has(pr[1]):
			_route(port_pos[pr[0]], port_pos[pr[1]], Color("#f3d58c") if pr[0] == "alba" else Color("#d6b8f0"))


func _skirt(h: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for k in 6:
		var a := deg_to_rad(60.0 * k)
		pts.append(Vector2(cos(a), sin(a)) * TILE_SCALE)
	for k in 6:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[(k + 1) % 6]
		var n := Vector3((a + b).x, 0, (a + b).y).normalized()
		st.set_normal(n)
		st.add_vertex(Vector3(a.x, 0, a.y))
		st.add_vertex(Vector3(b.x, 0, b.y))
		st.add_vertex(Vector3(b.x, h, b.y))
		st.add_vertex(Vector3(a.x, 0, a.y))
		st.add_vertex(Vector3(b.x, h, b.y))
		st.add_vertex(Vector3(a.x, h, a.y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#3a6f7d")
	m.roughness = 0.85
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi


func _bridge(at: Vector3, dir: Vector2) -> Node3D:
	var n := Node3D.new()
	n.position = at + Vector3(0, 0.004, 0)
	n.rotation.y = -atan2(dir.y, dir.x) + PI / 2.0
	var q := MeshInstance3D.new()
	if map3d:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.15, 0.03, 0.30)
		q.mesh = bm
		q.position.y = 0.0
	else:
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.15, 0.30)
		q.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = UI.tex("res://assets/tokens/ponte.webp")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.uv1_scale = Vector3(3, 2, 1) if map3d else Vector3(1, 1, 1)
	if map3d:
		m.uv1_scale = Vector3(1, 1, 1)
		m.uv1_triplanar = false
	q.material_override = m
	n.add_child(q)
	return n


func _port(id: String, at: Vector3, outward: Vector2) -> Node3D:
	var n := Node3D.new()
	n.position = at + Vector3(outward.x, 0, outward.y) * 0.16 + Vector3(0, 0.02, 0)
	var q := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.30, 0.30)
	q.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = UI.tex("res://assets/tokens/porto_%s.webp" % SKData.PORT_NAMES[id]["pair"])
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	q.material_override = m
	n.add_child(q)
	var lb := Label3D.new()
	lb.text = SKData.PORT_NAMES[id]["n"]
	lb.font = UI.font_title
	lb.font_size = 44
	lb.pixel_size = 0.0022
	lb.outline_size = 10
	lb.modulate = Color("#fff0c8")
	lb.outline_modulate = Color(0, 0, 0, 0.8)
	lb.rotation_degrees.x = -90
	lb.position = Vector3(0, 0.01, 0.22)
	n.add_child(lb)
	return n


## Rotta tratteggiata fra due porti collegati.
func _route(a: Array, b: Array, col: Color) -> void:
	var pa: Vector2 = a[0] + a[1] * 0.16
	var pb: Vector2 = b[0] + b[1] * 0.16
	var ctrl = (pa + pb) / 2.0 + (a[1] + b[1]).normalized() * maxf(1.2, pa.distance_to(pb) * 0.35)
	if (a[1] + b[1]).length() < 0.2:
		ctrl = (pa + pb) / 2.0 + a[1] * 1.4
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col * 0.6
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var steps := 34
	for k in steps:
		if k % 2 == 1:
			continue
		var t0 := float(k) / steps
		var t1 := float(k + 1) / steps
		var p0 := _bez(pa, ctrl, pb, t0)
		var p1 := _bez(pa, ctrl, pb, t1)
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.035, 0.004, p0.distance_to(p1))
		seg.mesh = bm
		seg.material_override = m
		var mid := (p0 + p1) / 2.0
		seg.position = Vector3(mid.x, 0.006, mid.y)
		var d := p1 - p0
		seg.rotation.y = -atan2(d.y, d.x) + PI / 2.0
		root_tiles.add_child(seg)


func _bez(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(c, t).lerp(c.lerp(b, t), t)


## Posizione nel mondo di un punto dell'immagine della tessera.
func tile_point(r: int, px: float, py: float, lift := 0.0) -> Vector3:
	var c: Vector3 = region_center[r]
	var u := (px / SKData.TILE_W - 0.5) * 2.0 * TILE_SCALE
	var v := (py / SKData.TILE_H - 0.5) * TILE_D * TILE_SCALE
	return Vector3(c.x + u, base_y() + lift, c.z + v)


func site_pos(r: int, i: int) -> Vector3:
	var s: Array = SKData.TILES[eng.st.regions[r]["tile"]]["sites"][i]
	return tile_point(r, s[0], s[1])


func wealth_pos(r: int, slot: int) -> Vector3:
	return tile_point(r, SKData.WEALTH_X[slot - 1], SKData.WEALTH_Y)


func bishop_pos(r: int) -> Vector3:
	var b: Array = SKData.TILES[eng.st.regions[r]["tile"]]["bishop"]
	return tile_point(r, b[0], b[1])


## Cerca sulla tessera i punti liberi per i personaggi e i segnalini (lontano da siti e tracce).
func _find_spots(r: int) -> void:
	var t: String = eng.st.regions[r]["tile"]
	var info: Dictionary = SKData.TILES[t]
	var busy := []
	for s in info["sites"]:
		busy.append(Vector2(s[0], s[1]))
	busy.append(Vector2(info["bishop"][0], info["bishop"][1]))
	var cand := []
	for gy in range(260, 1010, 34):
		for gx in range(160, 1190, 34):
			var p := Vector2(gx, gy)
			# dentro l'esagono, con margine
			var q := Vector2((gx / SKData.TILE_W - 0.5) * 2.0, (gy / SKData.TILE_H - 0.5) * 2.0 * 0.866)
			if absf(q.y) > 0.70 or absf(q.x) * 0.866 + absf(q.y) * 0.5 > 0.70:
				continue
			var dmin := 99999.0
			for b in busy:
				dmin = minf(dmin, maxf(absf(p.x - b.x), absf(p.y - b.y)))
			if dmin < 105:
				continue
			# fuori dalla traccia Ricchezza e dal cartiglio
			if gy < 300 and gx > 380 and gx < 960:
				continue
			if gy > 990 and gx > 420 and gx < 920:
				continue
			cand.append([p, dmin])
	cand.sort_custom(func(a, b): return a[1] > b[1])
	var chosen := []
	for c in cand:
		var ok := true
		for o in chosen:
			if (c[0] as Vector2).distance_to(o) < 125:
				ok = false
				break
		if ok:
			chosen.append(c[0])
		if chosen.size() >= 8:
			break
	# ordina da sinistra a destra per una disposizione leggibile
	chosen.sort_custom(func(a, b): return a.x + a.y * 0.2 < b.x + b.y * 0.2)
	char_spots[r] = chosen.slice(0, 6)
	var rest: Array = chosen.slice(6)
	while rest.size() < 2:
		rest.append(Vector2(260 + rest.size() * 820, 300))
	token_spots[r] = rest


# ------------------------------------------------------------------ pezzi

func _model(name: String) -> Node3D:
	if not models.has(name):
		models[name] = load("res://assets/models/%s.glb" % name)
	var scn: PackedScene = models[name]
	return scn.instantiate()


## Normalizza un modello: base a y=0, centrato, alto h.
func _fit(n: Node3D, h: float) -> Node3D:
	var aabb := AABB()
	var first := true
	for mi in _meshes(n):
		var a: AABB = mi.get_aabb()
		a = mi.transform * a
		if first:
			aabb = a
			first = false
		else:
			aabb = aabb.merge(a)
	var holder := Node3D.new()
	holder.add_child(n)
	var s := h / maxf(0.001, aabb.size.y)
	n.scale = Vector3.ONE * s
	n.position = -Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z) * s
	return holder


func _meshes(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


## Ricolora le parti rosse di un modello nel colore del giocatore.
func _tint(n: Node, p: int) -> void:
	p = UI.cidx(p)
	if p == 0:
		return
	var hue = [0.0, 0.615, 0.33, 0.12][p]
	var sat = [1.0, 1.0, 0.9, 0.95][p]
	var val = [1.0, 0.95, 0.85, 1.35][p]
	for mi in _meshes(n):
		var m: MeshInstance3D = mi
		for s in m.mesh.get_surface_count():
			var src = m.get_active_material(s)
			if src is BaseMaterial3D:
				var sm := ShaderMaterial.new()
				sm.shader = tint_shader
				sm.set_shader_parameter("tex", src.albedo_texture)
				sm.set_shader_parameter("hsv", Vector3(hue, sat, val))
				m.set_surface_override_material(s, sm)


func _sprite(path: String, h: float, standing: bool) -> Node3D:
	var holder := Node3D.new()
	var sp := Sprite3D.new()
	sp.texture = UI.tex(path)
	if sp.texture == null:
		return holder
	var th := float(sp.texture.get_height())
	sp.pixel_size = h / th
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sp.shaded = false
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if standing:
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.position.y = h / 2.0
		sp.shaded = false
	else:
		sp.rotation_degrees.x = -90
		sp.position.y = 0.004
	holder.add_child(sp)
	return holder


func _disc(path: String, d: float, thick: float, side: Color) -> Node3D:
	var holder := Node3D.new()
	if thick > 0.0:
		var cy := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = d / 2.0
		cm.bottom_radius = d / 2.0
		cm.height = thick
		cm.radial_segments = 24
		cy.mesh = cm
		var m := StandardMaterial3D.new()
		m.albedo_color = side
		m.roughness = 0.6
		cy.material_override = m
		cy.position.y = thick / 2.0
		holder.add_child(cy)
	var q := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(d, d)
	q.mesh = pm
	var qm := StandardMaterial3D.new()
	qm.albedo_texture = UI.tex(path)
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	qm.roughness = 0.5
	q.material_override = qm
	q.position.y = thick + 0.002
	holder.add_child(q)
	return holder


func _mat(c: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


## Accampamento degli invasori: palizzata scura con stendardo nero.
func _camp3d() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(Color("#2a2420"), 0.9)
	var k := 11
	for i in k:
		var a := TAU * i / k
		var stake := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.008
		cm.height = 0.075
		cm.radial_segments = 5
		stake.mesh = cm
		stake.material_override = wood
		stake.position = Vector3(cos(a) * 0.042, 0.037 + 0.006 * sin(i * 2.3), sin(a) * 0.042)
		n.add_child(stake)
	var tent := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.0
	tm.bottom_radius = 0.03
	tm.height = 0.05
	tm.radial_segments = 6
	tent.mesh = tm
	tent.material_override = _mat(Color("#3b3532"))
	tent.position.y = 0.025
	n.add_child(tent)
	var pole := MeshInstance3D.new()
	var pmm := CylinderMesh.new()
	pmm.top_radius = 0.002
	pmm.bottom_radius = 0.002
	pmm.height = 0.11
	pole.mesh = pmm
	pole.material_override = wood
	pole.position = Vector3(0, 0.055, 0)
	n.add_child(pole)
	var flag := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.045, 0.026, 0.002)
	flag.mesh = bm
	flag.material_override = _mat(Color("#111111"))
	flag.position = Vector3(0.023, 0.095, 0)
	n.add_child(flag)
	return n


## Risorse in 3D (modelli semplici): legna, pietra, grano, ferro, oro.
func _res3d(t: String) -> Node3D:
	var n := Node3D.new()
	match t:
		"legno":
			var m := _mat(Color("#7a4a24"), 0.95)
			for i in 3:
				var lg := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.012
				cm.bottom_radius = 0.012
				cm.height = 0.06
				cm.radial_segments = 10
				lg.mesh = cm
				lg.material_override = m
				lg.rotation_degrees.z = 90
				lg.position = Vector3(0, 0.012 + (0.02 if i == 2 else 0.0), -0.013 + 0.026 * (i % 2) + (0.013 if i == 2 else 0.0))
				n.add_child(lg)
		"pietra":
			var m := _mat(Color("#9b9a95"), 0.95)
			for i in 3:
				var b := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.028, 0.022, 0.022)
				b.mesh = bm
				b.material_override = m
				b.position = [Vector3(-0.015, 0.011, 0), Vector3(0.015, 0.011, 0.004), Vector3(0, 0.033, 0.002)][i]
				b.rotation_degrees.y = [8, -12, 20][i]
				n.add_child(b)
		"grano":
			var m := _mat(Color("#d8ae4a"), 0.8)
			var sh := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.02
			cm.bottom_radius = 0.012
			cm.height = 0.06
			sh.mesh = cm
			sh.material_override = m
			sh.position.y = 0.03
			n.add_child(sh)
			var band := MeshInstance3D.new()
			var bc := CylinderMesh.new()
			bc.top_radius = 0.0145
			bc.bottom_radius = 0.0145
			bc.height = 0.008
			band.mesh = bc
			band.material_override = _mat(Color("#8a5a28"))
			band.position.y = 0.032
			n.add_child(band)
			var sack := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.016
			sm.height = 0.03
			sack.mesh = sm
			sack.material_override = _mat(Color("#b38b5a"), 0.95)
			sack.position = Vector3(0.026, 0.015, 0.008)
			n.add_child(sack)
		"ferro":
			var m := _mat(Color("#55595f"), 0.45, 0.8)
			for i in 3:
				var b := MeshInstance3D.new()
				var pm := PrismMesh.new()
				pm.size = Vector3(0.05, 0.016, 0.022)
				b.mesh = pm
				b.material_override = m
				b.position = [Vector3(0, 0.008, -0.012), Vector3(0, 0.008, 0.012), Vector3(0, 0.024, 0)][i]
				n.add_child(b)
		"oro":
			var m := _mat(Color("#e3b232"), 0.3, 1.0)
			var bar := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.05, 0.018, 0.024)
			bar.mesh = pm
			bar.material_override = m
			bar.position = Vector3(-0.008, 0.009, -0.01)
			n.add_child(bar)
			for i in 4:
				var c := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.011
				cm.bottom_radius = 0.011
				cm.height = 0.004
				c.mesh = cm
				c.material_override = m
				c.position = Vector3(0.018, 0.002 + 0.0045 * i, 0.014)
				n.add_child(c)
	return n


func _make(kind: String, v) -> Node3D:
	match kind:
		"vil":
			var p: int = v
			if p == SKState.INV:
				if pieces3d:
					var cp := _camp3d()
					cp.scale = Vector3.ONE * 1.35
					return cp
				return _sprite("res://assets/tokens/invasore.webp", 0.12, map3d)
			if pieces3d:
				var m := _fit(_model("villaggio"), 0.135)
				_tint(m, p)
				return m
			return _sprite("res://assets/tokens/villaggio_%s.webp" % UI.cid(p), 0.12, false if not map3d else false)
		"res":
			if pieces3d:
				var hold := Node3D.new()
				var base := _disc("res://assets/res/%s.webp" % v, 0.075, 0.008, SKData.RES_COLOR[v].darkened(0.3))
				base.position = Vector3(0.0, 0, 0.0)
				hold.add_child(base)
				var rs := _res3d(v)
				rs.scale = Vector3.ONE * 1.7
				rs.position = Vector3(0, 0.009, 0)
				hold.add_child(rs)
				return hold
			return _sprite("res://assets/res/%s.webp" % v, 0.075, false)
		"econ":
			return _disc("res://assets/tokens/ricchezza.webp", 0.085, 0.012 if pieces3d else 0.0, Color("#b8892e"))
		"infl":
			return _disc("res://assets/tokens/influenza.webp", 0.085, 0.012 if pieces3d else 0.0, Color("#e9e2cf"))
		"bishop":
			var p2: int = v
			if pieces3d:
				var mb := _fit(_model("vescovo"), 0.19)
				_tint(mb, p2)
				return mb
			return _sprite("res://assets/tokens/vescovo_%s.webp" % UI.cid(p2), 0.12, map3d)
		"war":
			return _disc("res://assets/tokens/guerra.webp", 0.2, 0.016 if pieces3d else 0.0, Color("#7a1a1a"))
		"peace":
			return _disc("res://assets/tokens/pace.webp", 0.2, 0.016 if pieces3d else 0.0, Color("#e8e2d0"))
		"char":
			var c: String = v
			if pieces3d:
				return _fit(_model(c), 0.42 if c != "cavalleria" else 0.44)
			return _sprite(SKData.CHAR_PORTRAIT[c], 0.40, map3d)
	return Node3D.new()


func _place(key: String, kind: String, v, pos: Vector3, animate: bool, rot := 0.0) -> void:
	if vals.has(key) and vals[key] == v and nodes.has(key):
		var n0: Node3D = nodes[key]
		if n0.position.distance_to(pos) > 0.001:
			if animate:
				var tw := n0.create_tween()
				tw.tween_property(n0, "position", pos, 0.35).set_trans(Tween.TRANS_SINE)
			else:
				n0.position = pos
		return
	if nodes.has(key):
		_remove(key, animate)
	var n := _make(kind, v)
	n.position = pos
	n.rotation.y = rot
	root_pieces.add_child(n)
	nodes[key] = n
	vals[key] = v
	if animate:
		n.scale = Vector3.ONE * 0.01
		n.position = pos + Vector3(0, 0.35, 0)
		var tw := n.create_tween().set_parallel(true)
		tw.tween_property(n, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "position", pos, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _remove(key: String, animate: bool) -> void:
	var n: Node3D = nodes[key]
	nodes.erase(key)
	vals.erase(key)
	if animate and is_instance_valid(n):
		var tw := n.create_tween()
		tw.tween_property(n, "scale", Vector3.ONE * 0.01, 0.25)
		tw.tween_callback(n.queue_free)
	else:
		n.queue_free()


func refresh(animate := true) -> void:
	if eng == null:
		return
	var st: SKState = eng.st
	var want := {}
	for r in st.regions.size():
		var rg: Dictionary = st.regions[r]
		for i in rg["sites"].size():
			var p: int = rg["sites"][i]
			if p != -1:
				var k := "v%d_%d" % [r, i]
				want[k] = true
				_place(k, "vil", p, site_pos(r, i), animate, deg_to_rad(float((r * 7 + i * 13) % 5) * 8.0 - 16.0))
			elif rg["res"][i] != "":
				var k2 := "r%d_%d" % [r, i]
				want[k2] = true
				_place(k2, "res", rg["res"][i], site_pos(r, i), animate, deg_to_rad(float((r + i * 3) % 7) * 12.0))
		var e: int = rg["econ"]
		if e >= 1:
			want["e%d" % r] = true
			_place("e%d" % r, "econ", 1, wealth_pos(r, e), animate)
		for k3 in int(rg["infl"]):
			var key = "i%d_%d" % [r, k3]
			want[key] = true
			_place(key, "infl", 1, wealth_pos(r, 5 - k3), animate)
		if rg["bishop"] >= 0:
			want["b%d" % r] = true
			_place("b%d" % r, "bishop", int(rg["bishop"]), bishop_pos(r), animate)
		var ts: Array = token_spots[r]
		if rg["war"]:
			want["w%d" % r] = true
			_place("w%d" % r, "war", 1, tile_point(r, ts[0].x, ts[0].y), animate)
		if rg["peace"]:
			want["p%d" % r] = true
			_place("p%d" % r, "peace", 1, tile_point(r, ts[1].x, ts[1].y), animate)
	# personaggi: ognuno al suo posto nel regno
	var per_region := {}
	for c in SKData.CHARS:
		var r: int = st.chars[c]
		var k := int(per_region.get(r, 0))
		per_region[r] = k + 1
		var spots: Array = char_spots[r]
		var sp: Vector2 = spots[(SKData.CHARS.find(c)) % maxi(1, spots.size())] if spots.size() >= 6 else (spots[k % maxi(1, spots.size())] if not spots.is_empty() else Vector2(671, 586))
		var key = "c_" + c
		want[key] = true
		var pos := tile_point(r, sp.x, sp.y)
		if nodes.has(key) and vals.get(key, "") == c and animate and nodes[key].position.distance_to(pos) > 0.01:
			var n: Node3D = nodes[key]
			var tw := n.create_tween()
			var mid := (n.position + pos) / 2.0 + Vector3(0, 0.6, 0)
			tw.tween_property(n, "position", mid, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(n, "position", pos, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		else:
			_place(key, "char", c, pos, animate)
	for k in nodes.keys():
		if not want.has(k):
			_remove(k, animate)
	_rebuild_hl()


# ------------------------------------------------------------------ evidenziazioni

func set_highlight(regions: Array, sites_list: Array) -> void:
	hl_regions = regions.duplicate()
	hl_sites = sites_list.duplicate()
	_rebuild_hl()


func _rebuild_hl() -> void:
	for n in hl_nodes:
		if is_instance_valid(n):
			n.queue_free()
	hl_nodes.clear()
	if eng == null:
		return
	for r in hl_regions:
		hl_nodes.append(_hex_ring(r, Color("#ffd86a"), 0.06))
	if hover_r >= 0 and not hl_regions.has(hover_r):
		hl_nodes.append(_hex_ring(hover_r, Color(1, 1, 1, 0.5), 0.018))
	for s in hl_sites:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.062
		tm.outer_radius = 0.078
		tm.rings = 24
		ring.mesh = tm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#ffe27a")
		m.emission_enabled = true
		m.emission = Color("#ffcf40")
		m.emission_energy_multiplier = 1.6
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = m
		ring.position = site_pos(int(s[0]), int(s[1])) + Vector3(0, 0.02, 0)
		root_hl.add_child(ring)
		hl_nodes.append(ring)


func _hex_ring(r: int, col: Color, w: float) -> Node3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c: Vector3 = region_center[r]
	var outer := TILE_SCALE * 1.0
	var inner := outer - w * 2.0
	for k in 6:
		var a0 := deg_to_rad(60.0 * k)
		var a1 := deg_to_rad(60.0 * (k + 1))
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		st.add_vertex(o0 * outer)
		st.add_vertex(o1 * outer)
		st.add_vertex(o1 * inner)
		st.add_vertex(o0 * outer)
		st.add_vertex(o1 * inner)
		st.add_vertex(o0 * inner)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = col
	mi.material_override = m
	mi.position = Vector3(c.x, base_y() + (0.03 if map3d else 0.004), c.z)
	root_hl.add_child(mi)
	return mi


# ------------------------------------------------------------------ telecamera e input

func _process(delta: float) -> void:
	_t += delta
	var pulse := 0.65 + 0.35 * sin(_t * 5.0)
	for n in hl_nodes:
		if is_instance_valid(n) and n is MeshInstance3D and n.material_override is StandardMaterial3D:
			(n.material_override as StandardMaterial3D).emission_energy_multiplier = 0.6 + 1.6 * pulse
	if map3d:
		board_mat.set_shader_parameter("t", _t)


func _update_cam() -> void:
	if cam == null:
		return
	if map3d:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		var p := deg_to_rad(pitch)
		var y := deg_to_rad(yaw)
		var off := Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)) * dist
		cam.position = target + off
		cam.look_at(target, Vector3.UP)
		cam.h_offset = view_offset.x * dist * 0.045
		cam.v_offset = view_offset.y * dist * 0.045
	else:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = ortho_size
		cam.position = Vector3(target.x, 20, target.z - 0.35)
		cam.rotation_degrees = Vector3(-90, 0, 0)
		cam.h_offset = view_offset.x * ortho_size * 0.05
		cam.v_offset = view_offset.y * ortho_size * 0.05


func reset_view() -> void:
	yaw = 0.0
	pitch = 60.0
	dist = 9.6
	ortho_size = 8.3
	target = Vector3(0.4, 0, 0.35)
	_update_cam()


func zoom(f: float) -> void:
	if map3d:
		dist = clampf(dist * f, 2.2, 16.0)
	else:
		ortho_size = clampf(ortho_size * f, 2.0, 12.0)
	_update_cam()


func rotate_view(deg: float) -> void:
	yaw += deg
	_update_cam()


## Da chiamare con gli eventi del mouse che la HUD non ha usato.
func handle_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom(0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom(1.1)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag = true
				_moved = 0.0
			else:
				if _drag and _moved < 8.0:
					_click(mb.position)
				_drag = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_rdrag = mb.pressed
	elif ev is InputEventMouseMotion:
		var mm: InputEventMouseMotion = ev
		if _drag:
			_moved += mm.relative.length()
			if _moved >= 8.0:
				if map3d:
					yaw -= mm.relative.x * 0.3
					pitch = clampf(pitch + mm.relative.y * 0.25, 18.0, 89.0)
				else:
					_pan(mm.relative)
				_update_cam()
		elif _rdrag:
			_pan(mm.relative)
			_update_cam()
		else:
			_hover(mm.position)
	elif ev is InputEventMagnifyGesture:
		zoom(1.0 / (ev as InputEventMagnifyGesture).factor)
	elif ev is InputEventPanGesture:
		_pan(-(ev as InputEventPanGesture).delta * 8.0)
		_update_cam()


func _pan(rel: Vector2) -> void:
	var k := (dist if map3d else ortho_size) * 0.0016
	var y := deg_to_rad(yaw) if map3d else 0.0
	var right := Vector3(cos(y), 0, -sin(y))
	var fwd := Vector3(sin(y), 0, cos(y))
	target -= right * rel.x * k + fwd * rel.y * k
	target.x = clampf(target.x, -4.0, 4.0)
	target.z = clampf(target.z, -4.0, 4.0)


## Punto del tavolo sotto il mouse (sul piano delle tessere).
func _ground(screen: Vector2) -> Variant:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return null
	var t := (base_y() - o.y) / d.y
	if t < 0:
		return null
	return o + d * t


func pick(screen: Vector2) -> Array:
	var g = _ground(screen)
	if g == null or eng == null:
		return [-1, -1]
	var p: Vector3 = g
	var st: SKState = eng.st
	for r in st.regions.size():
		var c: Vector3 = region_center[r]
		var q := Vector2(p.x - c.x, p.z - c.z) / TILE_SCALE
		var k := 0.866
		if absf(q.y) <= k and absf(q.x) * k + absf(q.y) * 0.5 <= k:
			var best := -1
			var bd := 0.085
			for i in st.regions[r]["sites"].size():
				var sp := site_pos(r, i)
				var d := Vector2(sp.x - p.x, sp.z - p.z).length()
				if d < bd:
					bd = d
					best = i
			return [r, best]
	return [-1, -1]


func _click(pos: Vector2) -> void:
	var pk := pick(pos)
	if pk[0] < 0:
		return
	if pk[1] >= 0:
		site_clicked.emit(pk[0], pk[1])
	region_clicked.emit(pk[0])


func _hover(pos: Vector2) -> void:
	var pk := pick(pos)
	if pk[0] != hover_r or pk[1] != hover_i:
		hover_r = pk[0]
		hover_i = pk[1]
		hovered.emit(hover_r, hover_i)
		_rebuild_hl()


## Posizione sullo schermo di un regno (per le etichette della HUD).
func screen_of(r: int) -> Vector2:
	return cam.unproject_position(region_center[r])


# ------------------------------------------------------------------ shader

const TILE_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform sampler2D hmap : filter_linear;
uniform float relief = 0.0;
varying float h;
void vertex() {
	h = (texture(hmap, UV).r * 1.7 - 0.5);
	VERTEX.y += h * relief;
	if (relief > 0.0) {
		float e = 1.0 / 128.0;
		float hx = (texture(hmap, UV + vec2(e, 0)).r - texture(hmap, UV - vec2(e, 0)).r) * 1.7;
		float hz = (texture(hmap, UV + vec2(0, e)).r - texture(hmap, UV - vec2(0, e)).r) * 1.7;
		NORMAL = normalize(vec3(-hx * relief * 30.0, 1.0, -hz * relief * 34.0));
	}
}
void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) discard;
	ALBEDO = c.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
"""

const SEA_SHADER := """
shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float t = 0.0;
uniform float waves = 1.0;
void fragment() {
	vec2 uv = UV;
	// il mare si muove appena, la cornice resta ferma
	float inner = step(0.03, uv.x) * step(uv.x, 0.97) * step(0.08, uv.y) * step(uv.y, 0.97);
	uv += waves * inner * vec2(sin(uv.y * 40.0 + t * 0.9), cos(uv.x * 36.0 + t * 0.7)) * 0.0018;
	vec3 c = texture(tex, uv).rgb;
	float glint = waves * inner * pow(max(0.0, sin(uv.x * 90.0 + t * 1.3) * sin(uv.y * 70.0 - t * 1.1)), 12.0) * 0.18;
	ALBEDO = c + vec3(glint);
	ROUGHNESS = mix(0.9, 0.35, inner * waves);
	SPECULAR = 0.4 * inner * waves;
}
"""

const TINT_SHADER := """
shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 hsv = vec3(0.0, 1.0, 1.0);
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
void fragment() {
	vec3 c = texture(tex, UV).rgb;
	vec3 h = rgb2hsv(c);
	float hd = min(h.x, 1.0 - h.x);
	float red = smoothstep(0.075, 0.035, hd) * smoothstep(0.28, 0.48, h.y);
	vec3 nc = hsv2rgb(vec3(hsv.x, clamp(h.y * hsv.y, 0.0, 1.0), clamp(h.z * hsv.z, 0.0, 1.0)));
	ALBEDO = mix(c, nc, red);
	ROUGHNESS = 0.75;
}
"""
