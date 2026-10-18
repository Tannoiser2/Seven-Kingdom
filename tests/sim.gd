extends SceneTree
## Partite simulate fra IA, senza grafica: godot --headless --path . -s tests/sim.gd -- [partite] [livelli] [scenario]
## Esempio: -- 50 1,1,1,1 base

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 10
	var levels: Array = (args[1] if args.size() > 1 else "1,1,1,1").split(",")
	var scen_id: String = args[2] if args.size() > 2 else "base"
	var fl: String = args[3] if args.size() > 3 else ""
	# lettere: o obiettivi, d dado, a Alchimista (con le regole attuali); T senza turno di tregua
	var opts := {"objectives": fl.contains("o"), "dice": fl.contains("d"), "alchemist": fl.contains("a")}
	if fl.contains("T"):
		opts["inv_alt"] = false
	var wins := {}
	var reasons := {}
	var turns := 0
	var pts := {}
	var t0 := Time.get_ticks_msec()
	var pb := {}   # progetto -> [realizzati, usati, rimasti in mano]
	var art_turn := {}
	var pj_pts := 0
	var ord_pts := 0
	var res_left := 0
	var win_art := {}
	var alch_used := 0
	var alch_pw := 0
	var alch_turn := {}
	var built_hist := {}
	var drawn := 0
	var games_with_alch := 0
	var passive_acts := 0
	for g in games:
		var players := []
		for i in levels.size():
			players.append({"name": "IA%d(L%s)" % [i, levels[i]], "ai": true, "level": int(levels[i])})
		var eng := SKEngine.new()
		eng.setup({"players": players, "scenario": SKData.scenario(scen_id), "opts": opts, "seed": 1000 + g, "headless": true})
		root.add_child(eng)
		await eng.run()
		var rk: Array = eng.results
		var w: int = rk[0]["p"]
		wins[w] = wins.get(w, 0) + 1
		reasons[eng.st.end_reason] = reasons.get(eng.st.end_reason, 0) + 1
		if eng.st.end_reason == "invasione":
			for r in eng.st.regions.size():
				if eng.st.count(r, SKState.INV) == eng.st.regions[r]["sites"].size():
					var k := "inv_war" if eng.st.log_lines.any(func(l): return l.contains("GUERRA in " + eng.st.rname(r))) else "inv_empty"
					k += str(eng.st.regions[r]["sites"].size())
					reasons[k] = reasons.get(k, 0) + 1
					break
		turns += eng.st.turn
		for d in rk:
			pts[d["p"]] = pts.get(d["p"], 0) + d["tot"]
		var tcur := 0
		var any_a := false
		for l in eng.st.log_lines:
			if l.begins_with("— Turno "):
				tcur = int(l.split(" ")[2])
			if l.contains("ha la maggioranza nel regno dell'Alchimista e attiva"):
				passive_acts += 1
			if l.contains("sceglie L'Alchimista") or l.contains("sceglie Il Mercante"):
				alch_used += 1
				any_a = true
				alch_turn[tcur] = alch_turn.get(tcur, 0) + 1
				if l.contains("(potenziata)"):
					alch_pw += 1
		if any_a:
			games_with_alch += 1
		if opts["alchemist"]:
			var stt: SKState = eng.st
			for q in stt.n:
				var nb: int = stt.built[q].size()
				built_hist[nb] = built_hist.get(nb, 0) + 1
				pj_pts += stt.proj_points(q)
				ord_pts += stt.score(q) - stt.proj_points(q)
				res_left += stt.total_res(q)
				for b in stt.built[q]:
					var a: Array = pb.get(b["id"], [0, 0, 0])
					a[0] += 1
					if b["used"]:
						a[1] += 1
					pb[b["id"]] = a
					if true:
						art_turn[b["id"]] = art_turn.get(b["id"], []) + [b["turn"] + 1]
						if q == w:
							win_art[b["id"]] = win_art.get(b["id"], 0) + 1
				for id in stt.hand[q]:
					var a2: Array = pb.get(id, [0, 0, 0])
					a2[2] += 1
					pb[id] = a2
		if g == 0:
			for l in eng.st.log_lines.slice(0, 80):
				print(l)
		eng.queue_free()
	print("partite %d, tempo %.1fs, turni medi %.1f" % [games, (Time.get_ticks_msec() - t0) / 1000.0, float(turns) / games])
	print("vittorie per posto: ", wins)
	print("punti medi: ", pts.keys().map(func(k): return "%d=%.1f" % [k, float(pts[k]) / games]))
	print("fine per: ", reasons)
	print("Mercante/Alchimista scelto in media %.2f volte a partita (potenziata %d volte su %d); partite in cui viene scelto almeno una volta: %d su %d" % [float(alch_used) / games, alch_pw, alch_used, games_with_alch, games])
	print("  scelte per turno: ", alch_turn)
	if opts["alchemist"]:
		print("attivazioni dalla passiva (maggioranza nel regno dell'Alchimista): %.2f a partita" % (float(passive_acts) / games))
		print("carte attivate per giocatore (quanti giocatori ne hanno attivate 0, 1, 2…): ", built_hist)
	if opts["alchemist"]:
		var np: int = games * levels.size()
		print("PV medi a giocatore: progetti %.1f, ordinari %.1f; risorse rimaste %.1f" % [float(pj_pts) / np, float(ord_pts) / np, float(res_left) / np])
		for id in SKData.PROJ_IDS:
			var a: Array = pb.get(id, [0, 0, 0])
			var tt: Array = art_turn.get(id, [])
			var avg := 0.0
			for x in tt:
				avg += x
			print("  %s %-24s attivate %3d su %3d (%2d%%)  turno medio %.1f  nel vincitore %d" % [id, SKData.PROJECTS[id]["n"], a[0], a[0] + a[2], roundi(100.0 * a[0] / maxf(1, a[0] + a[2])),
				avg / maxf(1, tt.size()), win_art.get(id, 0)])
	quit()
