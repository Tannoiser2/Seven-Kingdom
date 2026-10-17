class_name MapPreview
extends Control
## Disegno in piccolo di una mappa (scenario): le 10 posizioni del mare, le tessere, i ponti e i porti.
## Lo usano il menu (anteprima) e l'editor delle mappe (che ne legge i clic).

signal pos_clicked(pos: int)
signal edge_clicked(pos: int, edge: int)

var scen: Dictionary = {}
var show_empty := false
var hl_pos := -1
var hl_edge := [-1, -1]
var R := 40.0
var origin := Vector2.ZERO


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP if show_empty else Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _layout() -> void:
	# si vede tutto il tabellone del mare (col titolo in alto), centrato
	R = minf(size.x / (7.71 * 1.16), size.y / (7.99 * 1.16))
	origin = size / 2.0 + Vector2(0, (0.244 + 0.42) * R)


func hex_center(pos: int) -> Vector2:
	return origin + SKData.pos_center(pos) * R


func _hex_pts(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 6:
		var a := deg_to_rad(60.0 * k)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw() -> void:
	_layout()
	if R < 4.0:
		return
	var tiles := {}
	for k in scen.get("tiles", {}):
		tiles[int(k)] = scen["tiles"][k]
	draw_rect(Rect2(Vector2.ZERO, size), Color("#174d5c"), true)
	var sea := UI.tex("res://assets/board/mare.webp")
	if sea != null:
		var bw := R * 7.71 * 1.16
		var bh := R * 7.99 * 1.16
		draw_texture_rect(sea, Rect2(origin + Vector2(-bw / 2.0, -bh / 2.0 - (0.244 + 0.42) * R), Vector2(bw, bh)), false)
	for p in 10:
		var c := hex_center(p)
		if tiles.has(p):
			var t: String = tiles[p]
			var tex := UI.tex(SKData.TILES[t]["img"])
			var pts := _hex_pts(c, R * 0.955)
			var uvs := PackedVector2Array()
			for k in 6:
				var a := deg_to_rad(60.0 * k)
				uvs.append(Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5 / 0.8733 * 0.866))
			if tex != null:
				draw_colored_polygon(pts, Color.WHITE, uvs, tex)
			else:
				draw_colored_polygon(pts, SKData.TILES[t]["col"])
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color("#e8c97a"), 1.5)
		elif show_empty:
			var pts2 := _hex_pts(c, R * 0.93)
			draw_polyline(pts2 + PackedVector2Array([pts2[0]]), Color(1, 1, 1, 0.45), 2.0)
			draw_string(UI.font_title, c + Vector2(-6, 7), str(p), HORIZONTAL_ALIGNMENT_LEFT, -1, int(R * 0.35), Color(1, 1, 1, 0.5))
		if hl_pos == p:
			var pts3 := _hex_pts(c, R * 0.98)
			draw_polyline(pts3 + PackedVector2Array([pts3[0]]), Color("#ffd86a"), 4.0)
	# ponti
	for b in scen.get("bridges", []):
		var a := hex_center(int(b[0]))
		var c2 := hex_center(int(b[1]))
		var mid := (a + c2) / 2.0
		var d := (c2 - a).normalized()
		var n := Vector2(-d.y, d.x)
		var hw := R * 0.11
		var hl := R * 0.2
		var poly := PackedVector2Array([mid - d * hl - n * hw, mid + d * hl - n * hw, mid + d * hl + n * hw, mid - d * hl + n * hw])
		draw_colored_polygon(poly, Color("#cfc6b3"))
		draw_polyline(poly + PackedVector2Array([poly[0]]), Color("#5a4a36"), 1.5)
	# porti e rotte
	var pp := {}
	var pn := {}
	for pt in scen.get("ports", []):
		var c3 := hex_center(int(pt["pos"]))
		var em := SKData.edge_mid(int(pt["edge"]))
		var outward := em.normalized()
		var w := R * 0.68
		var d := w * 292.0 / 420.0
		var ctr := c3 + em * R * 0.955 + outward * d / 2.0
		pp[pt["id"]] = ctr + outward * d / 2.0
		pn[pt["id"]] = [SKData.pos_center(int(pt["pos"])) + em * 0.955, outward]
		var tex := UI.tex("res://assets/tokens/porto_%s.webp" % pt["id"])
		if tex != null:
			draw_set_transform(ctr, atan2(outward.y, outward.x) - PI / 2.0, Vector2.ONE)
			draw_texture_rect(tex, Rect2(-w / 2.0, -d / 2.0, w, d), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var centers := []
	for p2 in tiles:
		centers.append(SKData.pos_center(p2))
	var k := 0
	for pr in [["alba", "vespro"], ["rupe", "bruma"]]:
		if pn.has(pr[0]) and pn.has(pr[1]):
			var pts := SKData.sea_route(pn[pr[0]][0], pn[pr[0]][1], pn[pr[1]][0], pn[pr[1]][1], centers, 0.68 * 292.0 / 420.0, 1.35 + 0.3 * k, Vector2(7.71 * 1.16 / 2.0 - 0.2, 7.99 * 1.16 / 2.0 - 0.2), Vector2(0, -0.244 - 0.42))
			var scr := PackedVector2Array()
			for q in pts:
				scr.append(origin + q * R)
			_dash_line(scr, SKData.ROUTE_COLORS[pr[0]])
			k += 1
	if hl_edge[0] >= 0:
		var c4 := hex_center(hl_edge[0])
		var em2 := SKData.edge_mid(hl_edge[1])
		draw_circle(c4 + em2 * R, R * 0.12, Color(1, 0.85, 0.3, 0.8))


func _dash_line(pts: PackedVector2Array, col: Color) -> void:
	var dash := R * 0.16
	var gap := R * 0.1
	var acc := 0.0
	var on := true
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var L := a.distance_to(b)
		var t := 0.0
		while t < L:
			var stepl := minf((dash if on else gap) - acc, L - t)
			if on and stepl > 0.01:
				draw_line(a.lerp(b, t / L), a.lerp(b, (t + stepl) / L), col, maxf(2.0, R * 0.05))
			t += stepl
			acc += stepl
			if acc >= (dash if on else gap) - 0.001:
				acc = 0.0
				on = not on


func _dashes(a: Vector2, b: Vector2, col: Color) -> void:
	var mid := (a + b) / 2.0
	var away := (mid - origin).normalized()
	if away.length() < 0.1:
		away = Vector2(1, 0)
	var ctrl := mid + away * maxf(R * 1.2, a.distance_to(b) * 0.3)
	var n := 28
	for k in n:
		if k % 2 == 1:
			continue
		var t0 := float(k) / n
		var t1 := float(k + 1) / n
		var p0 := a.lerp(ctrl, t0).lerp(ctrl.lerp(b, t0), t0)
		var p1 := a.lerp(ctrl, t1).lerp(ctrl.lerp(b, t1), t1)
		draw_line(p0, p1, col, 3.0)


## Posizione e lato più vicini al punto (per l'editor).
func hit(pt: Vector2) -> Dictionary:
	_layout()
	var best_p := -1
	var bd := 1e9
	for p in 10:
		var d := hex_center(p).distance_to(pt)
		if d < bd:
			bd = d
			best_p = p
	if best_p < 0 or bd > R * 1.05:
		return {"pos": -1, "edge": -1}
	var c := hex_center(best_p)
	var edge := -1
	var ed := 1e9
	for e in 6:
		var d2 := (c + SKData.edge_mid(e) * R).distance_to(pt)
		if d2 < ed:
			ed = d2
			edge = e
	return {"pos": best_p, "edge": edge if ed < R * 0.32 else -1}


func _gui_input(ev: InputEvent) -> void:
	if not show_empty:
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var h := hit(ev.position)
		if h["pos"] < 0:
			return
		if h["edge"] >= 0:
			edge_clicked.emit(h["pos"], h["edge"])
		else:
			pos_clicked.emit(h["pos"])
	elif ev is InputEventMouseMotion:
		var h2 := hit(ev.position)
		hl_pos = h2["pos"] if h2["edge"] < 0 else -1
		hl_edge = [h2["pos"], h2["edge"]] if h2["edge"] >= 0 else [-1, -1]
		queue_redraw()
