extends SceneTree
## Partite simulate fra IA, senza grafica: godot --headless --path . -s tests/sim.gd -- [partite] [livelli] [scenario]
## Esempio: -- 50 1,1,1,1 base

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 10
	var levels: Array = (args[1] if args.size() > 1 else "1,1,1,1").split(",")
	var scen_id: String = args[2] if args.size() > 2 else "base"
	var opts := {"objectives": args.size() > 3 and args[3].contains("o"), "dice": args.size() > 3 and args[3].contains("d")}
	var wins := {}
	var reasons := {}
	var turns := 0
	var pts := {}
	var t0 := Time.get_ticks_msec()
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
		if g == 0:
			for l in eng.st.log_lines.slice(0, 80):
				print(l)
		eng.queue_free()
	print("partite %d, tempo %.1fs, turni medi %.1f" % [games, (Time.get_ticks_msec() - t0) / 1000.0, float(turns) / games])
	print("vittorie per posto: ", wins)
	print("punti medi: ", pts.keys().map(func(k): return "%d=%.1f" % [k, float(pts[k]) / games]))
	print("fine per: ", reasons)
	quit()
