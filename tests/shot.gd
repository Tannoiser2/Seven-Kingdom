extends SceneTree
## Screenshot automatici dell'interfaccia (serve un display: xvfb-run).
## xvfb-run godot --path . -s res://tests/shot.gd -- <modo: menu|rules|editor|game> [mappa3d 1/0] [pedine3d 1/0] [turni]

var main
var n := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/shots")
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func shot(name: String) -> void:
	for i in 6:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	n += 1
	img.save_png(OS.get_user_data_dir() + "/shots/%02d_%s.png" % [n, name])
	print("shot ", name)


func wait(f := 10) -> void:
	for i in range(f):
		await process_frame


func gv():
	return main.current


func auto_answer() -> bool:
	var g = gv()
	var req: Dictionary = g.pending
	if req.is_empty():
		return false
	var r = g.engine.ais[int(req["seat"])].decide(g.engine, int(req["seat"]), req)
	g._provide(r)
	return true


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "game"
	var m3 := (args[1] if args.size() > 1 else "1") == "1"
	var p3 := (args[2] if args.size() > 2 else "1") == "1"
	var turns := int(args[3]) if args.size() > 3 else 2
	await wait(5)
	if mode == "menu":
		await shot("menu")
		quit()
		return
	if mode == "rules":
		main.show_rules()
		await wait(5)
		await shot("rules")
		quit()
		return
	if mode == "editor":
		main.show_editor()
		await wait(5)
		await shot("editor")
		quit()
		return
	var players := [{"name": "Stefano", "ai": false, "level": 1}, {"name": "Simone", "ai": true, "level": 1},
		{"name": "Laura", "ai": true, "level": 1}, {"name": "Marco", "ai": true, "level": 1}]
	main.start_game({"players": players, "colors": [0, 1, 2, 3], "seed": 77, "ai_delay": 0.0, "opts": {"objectives": true},
		"scenario": SKData.scenario(args[4] if args.size() > 4 else "base"), "map3d": m3, "pieces3d": p3})
	await wait(20)
	gv().auto_next = true
	if mode == "fx":
		auto_answer()
		var t2 := Time.get_ticks_msec()
		while gv().engine.st.turn < 1 and Time.get_ticks_msec() - t2 < 120000:
			await wait(2)
			auto_answer()
		var g2 = gv()
		var s2: SKState = g2.engine.st
		s2.regions[0]["war"] = true
		s2.regions[2]["peace"] = true
		s2.regions[3]["infl"] = 2
		g2.refresh()
		await wait(60)
		await shot("fx_tutto")
		for r in [0, 2, 3]:
			g2.board.zoom(0.4)
			g2.board.target = g2.board.region_center[r]
			g2.board._update_cam()
			await wait(40)
			await shot("fx_%d" % r)
		quit()
		return
	await shot("obiettivo")
	auto_answer()
	await wait(10)
	await shot("setup")
	# piazzamento e turni giocati dall'IA anche per la persona
	var t0 := Time.get_ticks_msec()
	while gv().engine.st.turn < turns and Time.get_ticks_msec() - t0 < 120000:
		await wait(2)
		auto_answer()
	# una pausa dopo la mossa di un avversario: la barra di stato con «Avanti»
	var g = gv()
	g.auto_next = false
	var t1 := Time.get_ticks_msec()
	while not (g.btn_next.visible and g.status_pc.visible) and Time.get_ticks_msec() - t1 < 60000:
		await wait(2)
		auto_answer()
	await wait(20)
	await shot("pausa")
	g.auto_next = true
	g.next_pressed.emit()
	# una mossa a metà: il Re scelto e la destinazione
	var safety := 0
	while (g.pending.is_empty() or g.pending["type"] != "turn") and safety < 400:
		await wait(2)
		if not g.pending.is_empty() and g.pending["type"] != "turn":
			auto_answer()
		safety += 1
	await wait(30)
	await shot("turno")
	var st: SKState = g.engine.st
	var c: String = "re" if not st.used.has("re") else st.available_chars()[0]
	g._pick_char(c)
	await wait(10)
	await shot("scegli_destinazione")
	var d: int = g._dests()[0]
	g._on_region(d)
	print("passo ", g.step, " bersagli ", g._king_targets() if c == "re" else [])
	await wait(10)
	await shot("mossa_" + c)
	g._on_info(d, 0)
	await wait(5)
	await shot("info_regno")
	g.board.zoom(0.45)
	var zt: Array = g._king_targets() if c == "re" else []
	g.board.target = g.board.region_center[int(zt[0][0]) if not zt.is_empty() else d]
	g.board._update_cam()
	g.tip.visible = false
	await wait(10)
	await shot("zoom")
	quit()
