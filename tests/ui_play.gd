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
	if st.favor[me] and rng.randf() < 0.4:
		view.sel = {"pw": true}
	view._pick_char(c)
	var steps := 0
	while view.step != "confirm" and steps < 12:
		steps += 1
		match view.step:
			"dest":
				view._on_region(_pick(view._dests()))
			"king_adj":
				view._on_region(_pick(st.king_normal_slots(view._dest())["adj"]))
			"king_pw":
				view._on_region(_pick(view._king_pw_cand()))
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
				view.sel["from"] = q
				view.sel["res"] = []
				var need := mini(2 if view.sel["pw"] else 1, st.total_res(q))
				var tmp: Dictionary = st.res[q].duplicate()
				for k in need:
					var kinds := []
					for t in tmp:
						if tmp[t] > 0:
							kinds.append(t)
					var t2: String = _pick(kinds)
					tmp[t2] -= 1
					view.sel["res"].append(t2)
				view.step = "confirm"
			"spy_a":
				var sa: Array = st.spy_sites(view._dest(), view.sel["pw"])
				var ok := false
				for b in st.land[view._dest()]:
					if not st.spy_sites(b, view.sel["pw"]).is_empty():
						ok = true
				if sa.is_empty() or not ok or rng.randf() < 0.15:
					view.step = "confirm"
				else:
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
	# a volte si cambiano i colori dei villaggi del Re
	if c == "re" and view.sel.has("pl") and rng.randf() < 0.5:
		for x in view.sel["pl"]:
			x[1] = rng.randi_range(0, st.n - 1)
	var m: Dictionary = view._move()
	var err := st.check_move(me, m)
	moves[c] = moves.get(c, 0) + 1
	if err != "":
		# colori del Re non validi sono un errore dell'utente, non dell'interfaccia: si rimette quello di base
		if c == "re":
			view._king_default() if not view.sel["pw"] else null
			m = view._move()
			err = st.check_move(me, m)
		if err != "":
			bad += 1
			print("RIFIUTATA: ", err, " ", m, " passo ", view.step)
	view._provide(m)
	await wait(1)
