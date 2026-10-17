extends SceneTree
## Prova del tutorial: la persona gioca la partita guidata seguendo la pergamena (e i personaggi
## che indica), premendo «Avanti» quando serve. Con SHOTS=1 (e xvfb) salva qualche schermata.
## godot --headless --path . -s res://tests/tutorial_play.gd

var main
var rng := RandomNumberGenerator.new()
var bad := 0
var moves := {}
var shots := OS.get_environment("SHOTS") == "1"
var nshot := 0
var lessons := []
var shot_keys := {}


func _initialize() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func wait(f := 2) -> void:
	for i in f:
		await process_frame


func _shots_maybe(name: String) -> void:
	if not shots or shot_keys.has(name):
		return
	shot_keys[name] = true
	await wait(12)
	var img := root.get_viewport().get_texture().get_image()
	nshot += 1
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/tut")
	img.save_png(OS.get_user_data_dir() + "/tut/%02d_%s.png" % [nshot, name])
	print("shot ", name)


func _run() -> void:
	rng.seed = 9
	await wait(5)
	main.current._on_tutorial()
	await wait(10)
	var view = main.current
	var guard := 0
	var t0 := Time.get_ticks_msec()
	while not view.game_done and guard < 40000 and Time.get_ticks_msec() - t0 < 400000:
		guard += 1
		await wait(1)
		var tut = view.tutorial
		if tut != null and tut.card.visible and tut.btn.visible:
			var t: String = tut.title_lbl.text
			if not lessons.has(t):
				lessons.append(t)
				await _shots_maybe("lezione_%d" % lessons.size())
			tut._close()
			continue
		if not view.pending.is_empty():
			await _act(view)
			continue
		if view.btn_next.visible:
			view.next_pressed.emit()
	await wait(90)
	var tut2 = view.tutorial
	if tut2 != null and tut2.card.visible:
		lessons.append(tut2.title_lbl.text)
		await _shots_maybe("fine")
		tut2._close()
	print("lezioni viste: ", lessons)
	print("partita: turni %d, fine per %s" % [view.engine.st.turn, view.engine.st.end_reason])
	print("mosse: ", moves, " rifiutate: ", bad)
	quit(1 if bad > 0 or not view.game_done else 0)


func _pick(a: Array):
	return a[rng.randi_range(0, a.size() - 1)]


func _act(view) -> void:
	var req: Dictionary = view.pending
	var st: SKState = view.engine.st
	match req["type"]:
		"setup":
			await _shots_maybe("setup")
			view._on_region(_pick(st.setup_regions()))
		"tie":
			view._provide(_pick(req["tied"]))
		"crown":
			view._provide(rng.randi_range(0, st.n - 1))
		"battle_favor", "battle_gov":
			view._provide(rng.randf() < 0.5)
		"turn":
			await _turn(view)


func _turn(view) -> void:
	var st: SKState = view.engine.st
	var me: int = view._me()
	var chars: Array = st.available_chars()
	var c: String = _pick(chars)
	if view.tutorial != null and view.tutorial.lock_char != "":
		c = view.tutorial.lock_char
	await _shots_maybe("scelta_" + c)
	view._pick_char(c, st.favor[me] and rng.randf() < 0.4)
	await wait(2)
	var steps := 0
	var spy_skip := false
	while view.step != "confirm" and steps < 16:
		steps += 1
		match view.step:
			"dest":
				await _shots_maybe("dest_" + c)
				view._on_region(_pick(view._dests()))
				await wait(2)
				await _shots_maybe("passo_" + c)
			"king", "king_pw":
				var tg: Array = view._king_targets()
				if tg.is_empty():
					break
				if rng.randf() < 0.2:
					view._on_house(rng.randi_range(0, st.n - 1))
				var x0: Array = _pick(tg)
				var before: int = view.sel.get("pl", []).size()
				view._on_site(x0[0], x0[1])
				if view.sel.get("pl", []).size() == before:
					# colore senza villaggi in riserva: si torna al proprio
					view._on_house(me)
					view._on_site(x0[0], x0[1])
			"pope_t":
				view._on_region(_pick(st.pope_targets(view._dest(), view.sel["pw"])))
			"pope_b":
				view._on_region(_pick(st.free_cathedrals()))
			"merch":
				var qs := []
				for q in st.n:
					if q != me and st.total_res(q) > 0:
						qs.append(q)
				var q: int = _pick(qs)
				var kinds := []
				for t in st.res[q]:
					var left: int = st.res[q][t] - (view.sel["res"].count(t) if view.sel["from"] == q else 0)
					if left > 0:
						kinds.append(t)
				view._on_house_res(q, _pick(kinds))
			"spy_a":
				var sa: Array = st.spy_sites(view._dest(), view.sel["pw"])
				var ok := false
				for b in st.land[view._dest()]:
					if not st.spy_sites(b, view.sel["pw"]).is_empty():
						ok = true
				if sa.is_empty() or not ok or rng.randf() < 0.15:
					spy_skip = true
					break
				view._on_site(view._dest(), _pick(sa))
			"spy_b":
				var cand := []
				for b in st.land[view._dest()]:
					for i in st.spy_sites(b, view.sel["pw"]):
						cand.append([b, i])
				var x: Array = _pick(cand)
				view._on_site(x[0], x[1])
			_:
				break
	if spy_skip:
		view.sel.erase("a")
		view.sel.erase("b")
	var m: Dictionary = view._move()
	var err := st.check_move(me, m)
	moves[c] = moves.get(c, 0) + 1
	if err != "":
		bad += 1
		print("RIFIUTATA: ", err, " ", m, " passo ", view.step)
	view._provide(m)
	await wait(1)
