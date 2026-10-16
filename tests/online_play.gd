extends SceneTree
## Prova del gioco online: due istanze di Seven Kingdom (chi crea la stanza e un amico) giocano una
## partita intera sul finto Firebase (tests/firebase_mock.py), con due casati IA. Le persone sono simulate
## dall'IA. MN_ROLE=host|guest, MN_CODEFILE=file per il codice della stanza,
## MN_PHASE=drop: l'ospite esce a metà (per provare il rientro con MN_PHASE=back).
## Alla fine ognuno stampa l'impronta della partita: devono coincidere.

var main
var t0 := 0
var ai := SKAI.new(1, 99)


func _init() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	t0 = Time.get_ticks_msec()
	_run()


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _run() -> void:
	await _wait(0.5)
	var role := OS.get_environment("MN_ROLE")
	var cf := OS.get_environment("MN_CODEFILE")
	var phase := OS.get_environment("MN_PHASE")
	var menu = main.current
	menu.seat_mode = [0, 0, 1, 1]
	menu.speed = 3
	menu.opts = {"objectives": true, "dice": true}
	menu._online_panel()
	menu.on_name.text = "Host" if role == "host" else "Ospite"
	if role == "host":
		await menu._online_create()
		var code: String = main.lobby.get("code", "")
		print("MNTEST stanza ", code)
		var f := FileAccess.open(cf, FileAccess.WRITE)
		f.store_string(code)
		f.close()
		while true:
			var room: Dictionary = await main.net.room(code)
			if Net._as_dict(room.get("seats", {})).size() >= 2:
				break
			await _wait(0.5)
		await menu._online_start()
	else:
		var code := ""
		while code == "":
			if FileAccess.file_exists(cf):
				code = FileAccess.get_file_as_string(cf).strip_edges()
			await _wait(0.3)
		menu.on_code.text = code
		await menu._online_join()
	while true:
		await process_frame
		if Time.get_ticks_msec() - t0 > 900000:
			print("MNTEST tempo scaduto")
			quit(2)
			return
		var view = main.current
		if view == null or not ("engine" in view) or view.engine == null:
			continue
		var e: SKEngine = view.engine
		var req: Dictionary = view.pending
		if not req.is_empty() and view.online._mine_pending:
			view._provide(ai.decide(e, req["seat"], req))
		if phase == "drop" and e.st.turn >= 2:
			print("MNTEST esco a metà partita, mossa ", view.online.n)
			quit(0)
			return
		if view.game_done:
			await _wait(0.5)
			print("MNTEST impronta ", view.online.n, " | ", e.fingerprint(), " | ", e.st.end_reason)
			quit(0)
			return
