class_name SKAI
extends RefCounted
## Giocatori artificiali. Per ogni mossa possibile copiano lo stato, applicano la mossa, giocano le
## azioni passive e la fine del turno e valutano il risultato (punti attesi propri contro quelli degli
## avversari, Favore, Corona, rischi d'invasione).
## Livelli: 0 Facile (sceglie fra le mosse buone con molto caso), 1 Normale (la mossa migliore),
## 2 Difficile (prova anche le risposte degli avversari che giocano dopo nel turno).
## L'IA non sbircia gli obiettivi segreti degli altri.

var level := 1
var rng := RandomNumberGenerator.new()


func _init(p_level := 1, seed_value := 1) -> void:
	level = p_level
	rng.seed = seed_value


## Scelte automatiche durante le simulazioni (nessuna attesa).
class SimChooser:
	var me := 0
	var st: SKState
	func _init(p_me: int, p_st: SKState) -> void:
		me = p_me
		st = p_st
	func tie(g: int, tied: Array, _r: int, _why: String):
		if tied.has(g):
			return g
		# favorisce il più debole fra i pari merito
		var best: int = tied[0]
		for q in tied:
			if st.score(q, false) < st.score(best, false):
				best = q
		return best
	func crown(p: int):
		return p
	func battle_favor(p: int, r: int):
		return _need(p, r, 1)
	func battle_gov(g: int, p: int, _r: int):
		return g == p
	func alch_act(p: int):
		var best := ""
		var bv := -1
		for id in st.hand[p]:
			if st.can_afford(p, id) and int(SKData.PROJECTS[id]["pv"]) > bv:
				bv = int(SKData.PROJECTS[id]["pv"])
				best = id
		return {"b": best} if best != "" else {}
	func _need(p: int, r: int, extra: int) -> bool:
		var inv := st.count(r, SKState.INV)
		var atk := st.count(r, p) + (1 if st.first == p else 0) + (1 if st.chars["fanteria"] == r else 0)
		if st.governor(r) == p:
			atk += 1
		return atk < inv and atk + extra >= inv


# ------------------------------------------------------------------ decisioni

func decide(eng, s: int, req: Dictionary):
	var st: SKState = eng.st
	match req.get("type", ""):
		"objective":
			return _pick_objective(st, s, req["options"])
		"setup":
			return _pick_setup(st, s)
		"turn":
			return best_move(st, s)
		"tie":
			var ch := SimChooser.new(s, st)
			return ch.tie(s, req["tied"], req["r"], req.get("why", ""))
		"crown":
			return s
		"battle_favor":
			var ch2 := SimChooser.new(s, st)
			return ch2.battle_favor(s, int(req["r"]))
		"battle_gov":
			return int(req["p"]) == s
		"athanor":
			# si scarta il progetto meno utile (lo stesso criterio di auto_athanor)
			var cards: Array = req["cards"]
			var worst := 0
			for i in cards.size():
				if st.proj_value(s, cards[i]) < st.proj_value(s, cards[worst]):
					worst = i
			return worst
		"projects":
			return best_projects(st, s, req.get("passive", false))
	return null


func fallback(eng, s: int) -> Dictionary:
	var moves := legal_moves(eng.st, s)
	return moves[0] if not moves.is_empty() else {}


func _pick_objective(st: SKState, s: int, options: Array) -> int:
	# preferisce gli obiettivi che già oggi darebbero punti, poi quelli territoriali vicini alla Capitale
	var best := 0
	var bv := -999.0
	for i in options.size():
		var id: String = options[i]
		var o := SKData.objective(id)
		var v := 0.0
		match id:
			"nemico", "usurpatore": v = 3.0
			"camerlengo", "conquistatore", "cancelliere", "balivo": v = 6.0
			"politico", "pacificatore", "regina": v = 5.0
			"infiltrato", "dittatore": v = 4.0
		if o.get("kind", "") == "terr":
			v = 5.0
			if o["r"].has("capitale"):
				v += 1.0
		v += rng.randf() * 2.0
		if v > bv:
			bv = v
			best = i
	return best


func _pick_setup(st: SKState, s: int) -> int:
	var best := -1
	var bv := -999.0
	for r in st.setup_regions():
		var c := st.clone()
		c.setup_place(s, r)
		var v := _setup_value(c, s, r) + rng.randf() * (2.0 if level == 0 else 0.4)
		if v > bv:
			bv = v
			best = r
	return best


func _setup_value(c: SKState, s: int, r: int) -> float:
	var v := 0.0
	var mine := c.count(r, s)
	var tot := c.colored(r)
	# essere Governatore conta molto, la Capitale vale di più
	if c.governor(r) == s:
		v += 3.0
	v += c.econ(r) * 1.2
	if mine > tot - mine:
		v += 2.0
	v -= float(mine) * 0.8
	# la risorsa presa
	for t in SKData.RESOURCES:
		v += c.res_prize(s, t) * 0.5
	if c.count(r, SKState.INV) > 0:
		v -= 1.0
	return v


# ------------------------------------------------------------------ mosse possibili

func legal_moves(st: SKState, p: int) -> Array:
	var out := []
	var pws := [false]
	if st.favor[p]:
		pws.append(true)
	for c in st.available_chars():
		for path in st.move_paths(c, p):
			var dest: int = path[path.size() - 1]
			for pw in pws:
				out.append_array(_moves_for(st, p, c, path, dest, pw))
	var ok := []
	for m in out:
		if st.check_move(p, m) == "":
			ok.append(m)
	return ok


func _moves_for(st: SKState, p: int, c: String, path: Array, dest: int, pw: bool) -> Array:
	var base := {"c": c, "path": path, "pw": pw}
	var out := []
	match c:
		"re":
			if pw:
				var cand := []
				for r in [dest] + st.land[dest]:
					if st._king_region_ok(r, true):
						cand.append(r)
				if cand.is_empty():
					out.append(base)
				for i in cand.size():
					for j in range(i, cand.size()):
						# al massimo un regno adiacente oltre a quello del Re
						if cand[i] != dest and cand[j] != dest and cand[i] != cand[j]:
							continue
						var m := base.duplicate()
						m["pl"] = [[cand[i], p], [cand[j], p]]
						out.append(m)
				return out
			var sl := st.king_normal_slots(dest)
			var adjs: Array = sl["adj"].duplicate()
			if adjs.is_empty():
				adjs = [-1]
			for a in adjs:
				var slots := []
				for i in sl["main"]:
					slots.append(dest)
				if a >= 0:
					slots.append(a)
				if slots.is_empty():
					out.append(base)
					continue
				if slots.size() == 1:
					var m := base.duplicate()
					m["pl"] = [[slots[0], p]]
					out.append(m)
					continue
				# un villaggio va a un avversario: si prova ogni avversario e ogni posizione
				for q in st.n:
					if q == p or st.reserve[q] <= 0:
						continue
					var tried := {}
					for k in slots.size():
						if tried.has(slots[k]):
							continue
						tried[slots[k]] = true
						var pl := []
						for z in slots.size():
							pl.append([slots[z], q if z == k else p])
						var m := base.duplicate()
						m["pl"] = pl
						out.append(m)
		"papa":
			var targets := st.pope_targets(dest, pw)
			if targets.is_empty():
				targets = [-1]
			var cats := [-1]
			if pw and st.bishops[p] > 0:
				var fc := st.free_cathedrals()
				if not fc.is_empty():
					cats = fc
			for t in targets:
				for b in cats:
					var m := base.duplicate()
					m["r"] = t
					if pw:
						m["b"] = b
					out.append(m)
		"mercante":
			var any := false
			for q in st.n:
				if q == p or st.total_res(q) <= 0:
					continue
				any = true
				var kinds := []
				for t in SKData.RESOURCES:
					if st.res[q][t] > 0:
						kinds.append(t)
				if not pw or st.total_res(q) == 1:
					for t in kinds:
						var m := base.duplicate()
						m["from"] = q
						m["res"] = [t]
						out.append(m)
				else:
					for i in kinds.size():
						for j in range(i, kinds.size()):
							if i == j and st.res[q][kinds[i]] < 2:
								continue
							var m := base.duplicate()
							m["from"] = q
							m["res"] = [kinds[i], kinds[j]]
							out.append(m)
			if not any:
				var m := base.duplicate()
				m["from"] = -1
				out.append(m)
		"spia":
			out.append(base)
			var sa := st.spy_sites(dest, pw)
			for b in st.land[dest]:
				var sb := st.spy_sites(b, pw)
				for ia in sa:
					var pa: int = st.regions[dest]["sites"][ia]
					for ib in sb:
						var pb: int = st.regions[b]["sites"][ib]
						if pa == pb:
							continue
						if pa != p and pb != p and ia != 0 and ib != 0:
							continue
						var m := base.duplicate()
						m["a"] = [dest, ia]
						m["b"] = [b, ib]
						out.append(m)
		"fanteria", "cavalleria":
			if st.regions[dest]["war"]:
				if not pw:
					var m := base.duplicate()
					m["battle"] = true
					out.append(m)
					out.append(base)
			else:
				out.append(base)
	return out


# ------------------------------------------------------------------ valutazione

## Simula la mossa fino alla fine del turno e ne valuta l'esito per p.
## deep: gli avversari che giocano dopo rispondono con la loro mossa migliore e si gioca anche
## il turno successivo (tutti con l'IA Normale veloce).
func simulate(st: SKState, p: int, m: Dictionary, deep := false) -> float:
	var c := st.clone()
	c.apply_move(p, m)
	if c.alch():
		_quick_projects(c, p)
	if deep:
		var helper := SKAI.new(1, 7)
		_finish_actions(c, p, helper)
	c.call("passive_phase", SimChooser.new(p, c))
	c.call("end_phase", null)
	if deep and not c.game_over:
		var helper2 := SKAI.new(1, 11)
		var v_now := evaluate(c, p)
		_finish_actions(c, -1, helper2)
		c.call("passive_phase", SimChooser.new(p, c))
		c.call("end_phase", null)
		return 0.45 * v_now + 0.55 * evaluate(c, p)
	return evaluate(c, p)


## Fa giocare le azioni rimanenti del turno (dopo after; -1 = tutto il turno) con l'IA veloce.
func _finish_actions(c: SKState, after: int, helper: SKAI) -> void:
	var order := []
	for k in c.n:
		order.append((c.first + k) % c.n)
	var from := order.find(after) + 1 if after >= 0 else 0
	for k in range(from, order.size()):
		var q: int = order[k]
		var mq := helper.best_move(c, q, true)
		if not mq.is_empty():
			c.apply_move(q, mq)


func evaluate(c: SKState, p: int) -> float:
	var mine := float(c.score(p, true))
	var best_o := -999.0
	var sum_o := 0.0
	for q in c.n:
		if q == p:
			continue
		var s := float(c.score(q, false))
		best_o = maxf(best_o, s)
		sum_o += s
	var mean_o := sum_o / maxf(1.0, c.n - 1)
	var v := mine - 0.65 * best_o - 0.35 * mean_o
	if c.favor[p]:
		v += 2.5
	# villaggi esposti: regni senza personaggi e non pacificati rischiano l'invasione
	for r in c.regions.size():
		var rg: Dictionary = c.regions[r]
		var mine_here := c.count(r, p)
		if mine_here == 0:
			continue
		if rg["war"]:
			v -= 0.6 * mine_here
		elif not rg["peace"] and c.chars_in(r).is_empty() and c.free_count(r) <= 1:
			v -= 0.5 * mine_here
	# villaggi ancora in riserva: possibilità future
	v += 0.15 * c.reserve[p]
	if c.alch():
		v += _alch_potential(c, p)
	if c.game_over:
		# chiudere la partita conviene solo a chi è davanti; nei primi turni l'IA non ha fretta
		var rk := c.ranking()
		var lead := float(rk[0]["tot"] - (rk[1]["tot"] if rk.size() > 1 else 0))
		if rk[0]["p"] == p:
			v += (25.0 if lead >= 4.0 else 8.0) * (1.0 if c.turn >= 6 else 0.3)
		else:
			v -= 20.0
	return v


func best_move(st: SKState, p: int, fast := false) -> Dictionary:
	var moves := legal_moves(st, p)
	if moves.is_empty():
		return {}
	var scored := []
	for m in moves:
		scored.append([simulate(st, p, m), m])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	if fast:
		return scored[0][1]
	if level == 0:
		var k := maxi(1, int(scored.size() * 0.35))
		var pick := rng.randi_range(0, mini(k, scored.size()) - 1)
		return scored[pick][1]
	if level >= 2:
		var top := mini(5, scored.size())
		var best = scored[0][1]
		var bv := -9999.0
		for i in top:
			var v: float = simulate(st, p, scored[i][1], true) + 0.25 * scored[i][0]
			if v > bv:
				bv = v
				best = scored[i][1]
		return best
	# Normale: un pizzico di varietà fra mosse quasi uguali
	var near := []
	for s in scored:
		if s[0] >= scored[0][0] - 0.25:
			near.append(s[1])
	return near[rng.randi_range(0, near.size() - 1)]


# ------------------------------------------------------------------ variante dell'Alchimista

## Valore futuro dei progetti: in mano (secondo quanto manca a pagarli), Invenzioni pronte,
## risorse ancora utili per pagare, effetti degli Artefatti.
func _alch_potential(c: SKState, p: int) -> float:
	# le carte ancora da attivare valgono una parte dei loro PV (di più se si possono già pagare)
	var v := 0.0
	for id in c.hand[p]:
		v += 0.35 * float(SKData.PROJECTS[id]["pv"]) * (1.0 if c.can_afford(p, id) else 0.5)
	v += 0.3 * c.total_res(p) + 0.6 * int(c.jolly[p])
	# Artefatti girati: effetti permanenti
	if c.has_art(p, "A01"):
		v += 1.5
	if c.has_art(p, "A02"):
		v += 1.0
	if c.has_art(p, "A03"):
		v += 0.8
	if c.has_art(p, "A04"):
		v += 1.0
	return v


## Nelle simulazioni: attiva le carte che l'Alchimista consente, le più ricche fra quelle pagabili.
func _quick_projects(c: SKState, p: int) -> void:
	while c.act_left[p] > 0:
		c.act_left[p] -= 1
		var best := ""
		var bv := -1
		for id in c.hand[p]:
			if c.can_afford(p, id) and int(SKData.PROJECTS[id]["pv"]) > bv:
				bv = int(SKData.PROJECTS[id]["pv"])
				best = id
		if best == "":
			break
		c._do_projects(p, {"b": best})
	c.act_left[p] = 0


## Attivazione dell'IA: per ogni carta pagabile e ogni suo effetto (o nessun effetto) si simula l'esito;
## se attivare non conviene si passa. passive: nella fase passiva (si valuta subito, senza rifare la fase).
func best_projects(st: SKState, p: int, passive := false) -> Dictionary:
	var base_v := evaluate(st, p) if passive else _after_turn(st, p)
	var best := {}
	var bvv := base_v + 0.1
	var tried := {}
	for id in st.hand[p]:
		if tried.has(id) or not st.can_afford(p, id):
			continue
		tried[id] = true
		var uses := st.invention_uses(p, id)
		if uses.size() > 30:
			for i in range(uses.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var tmp = uses[i]
				uses[i] = uses[j]
				uses[j] = tmp
			uses = uses.slice(0, 30)
		var opts := [{}]
		for u in uses:
			var uu: Dictionary = u.duplicate()
			uu.erase("id")
			uu.erase("x")
			if uu.is_empty():
				opts = [{}]
				break
			opts.append(uu)
		for u in opts:
			var v := {"b": id}
			if not u.is_empty():
				v["u"] = u
			var c := st.clone()
			if c._do_projects(p, v) != "":
				continue
			var val := (evaluate(c, p) if passive else _after_turn(c, p)) + rng.randf() * (0.6 if level == 0 else 0.05)
			if val > bvv:
				bvv = val
				best = v
	return best


func _after_turn(c: SKState, p: int) -> float:
	var x := c.clone()
	x.call("passive_phase", SimChooser.new(p, x))
	x.call("end_phase", null)
	return evaluate(x, p)
