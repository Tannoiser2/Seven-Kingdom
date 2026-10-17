extends SceneTree
func _init():
	var players := []
	for i in 3:
		players.append({"name": "IA%d" % i, "ai": true, "level": 1})
	var eng := SKEngine.new()
	eng.setup({"players": players, "scenario": SKData.scenario("base"), "opts": {"alchemist": true}, "seed": 1000, "headless": true})
	root.add_child(eng)
	var st: SKState = eng.st
	print("mani ", st.hand, " deck ", st.deck.size())
	await eng.run()
	print("mani ", st.hand, " costruiti ", st.built, " risorse ", st.res)
	for p in 3:
		for id in st.hand[p]:
			print(p, " ", id, " paga? ", st.can_afford(p, id), " possibile ", st.projects_possible(p))
	var ai := SKAI.new(1, 3)
	for p in 3:
		print("scelta ", p, " ", ai.best_projects(st, p))
		var c := st.clone()
		print(" valuta vuoto ", ai.evaluate(c, p))
		if not c.hand[p].is_empty():
			print(" do ", c._do_projects(p, {"b": c.hand[p][0]}), " -> ", ai.evaluate(c, p))
	quit()
