extends SceneTree
## Partite simulate fra IA, senza grafica: godot --headless --path . -s tests/sim.gd -- [partite] [livelli] [scenario]
## Esempio: -- 50 1,1,1,1 base

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 10
	var levels: Array = (args[1] if args.size() > 1 else "1,1,1,1").split(",")
	var scen_id: String = args[2] if args.size() > 2 else "base"
	var opts := {"objectives": args.size() > 3 and args[3].contains("o"), "dice": args.size() > 3 and args[3].contains("d"), "alchemist": args.size() > 3 and args[3].contains("a")}
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
		turns += eng.st.turn
		for d in rk:
			pts[d["p"]] = pts.get(d["p"], 0) + d["tot"]
		for l in eng.st.log_lines:
			if l.contains("sceglie L'Alchimista") or l.contains("sceglie Il Mercante"):
				alch_used += 1
		if opts["alchemist"]:
			var stt: SKState = eng.st
			for q in stt.n:
				pj_pts += stt.proj_points(q)
				ord_pts += stt.score(q) - stt.proj_points(q)
				res_left += stt.total_res(q)
				for b in stt.built[q]:
					var a: Array = pb.get(b["id"], [0, 0, 0])
					a[0] += 1
					if b["used"]:
						a[1] += 1
					pb[b["id"]] = a
					if SKData.PROJECTS[b["id"]]["kind"] == "art":
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
	print("Mercante/Alchimista scelto in media %.1f volte a partita" % (float(alch_used) / games))
	if opts["alchemist"]:
		var np: int = games * levels.size()
		print("PV medi a giocatore: progetti %.1f, ordinari %.1f; risorse rimaste %.1f" % [float(pj_pts) / np, float(ord_pts) / np, float(res_left) / np])
		for id in SKData.PROJ_IDS:
			var a: Array = pb.get(id, [0, 0, 0])
			var tt: Array = art_turn.get(id, [])
			var avg := 0.0
			for x in tt:
				avg += x
			print("  %s %-24s realizzati %3d  usati %3d  rimasti in mano %3d%s" % [id, SKData.PROJECTS[id]["n"], a[0], a[1], a[2],
				("  turno medio %.1f, nel vincitore %d" % [avg / maxf(1, tt.size()), win_art.get(id, 0)]) if id.begins_with("A") else ""])
	quit()
