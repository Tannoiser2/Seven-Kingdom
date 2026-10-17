extends SceneTree
## Prova dell'interfaccia: una persona (posto 0) gioca intere partite usando solo i comandi della vista
## (scelta del personaggio, clic sui regni e sui siti, conferma), con scelte a caso fra quelle proposte.
## Segnala ogni mossa costruita dall'interfaccia che il motore rifiuterebbe.
## godot --headless --path . -s res://tests/ui_play.gd -- [partite]

var main
var rng := RandomNumberGenerator.new()
var bad := 0
var moves := {}


func _initialize() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func wait(f := 2) -> void:
	for i in f:
		await process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 3
	rng.seed = 5
	for g in games:
		var players := [{"name": "Umano", "ai": false, "level": 1}, {"name": "IA1", "ai": true, "level": 1}, {"name": "IA2", "ai": true, "level": 0}]
		var sc: Dictionary = SKData.SCENARIOS[g % SKData.SCENARIOS.size()]
		main.start_game({"players": players, "colors": [0, 1, 2], "seed": 300 + g, "ai_delay": 0.0, "opts": {"objectives": true, "dice": g % 2 == 1},
			"scenario": sc, "map3d": g % 2 == 0, "pieces3d": g % 3 != 0})
		await wait(5)
		var view = main.current
		view.auto_next = true
		var guard := 0
		while not view.game_done and guard < 20000:
			guard += 1
			await wait(1)
			if view.pending.is_empty():
				continue
			await _act(view)
		print("partita %d (%s): turni %d, fine per %s, vince %s" % [g, sc["id"], view.engine.st.turn, view.engine.st.end_reason, view.engine.pname(view.engine.results[0]["p"]) if not view.engine.results.is_empty() else "?"])
	print("mosse dell'interfaccia per personaggio: ", moves)
	print("mosse rifiutate: ", bad)
	quit(1 if bad > 0 else 0)


func _pick(a: Array):
	return a[rng.randi_range(0, a.size() - 1)]


func _act(view) -> void:
	var req: Dictionary = view.pending
	var st: SKState = view.engine.st
	match req["type"]:
		"objective":
			view._provide(rng.randi_range(0, 2))
		"setup":
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
	view._pick_char(c, st.favor[me] and rng.randf() < 0.4)
	var steps := 0
	var spy_skip := false
	while view.step != "confirm" and steps < 16:
		steps += 1
		match view.step:
			"dest":
				view._on_region(_pick(view._dests()))
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
