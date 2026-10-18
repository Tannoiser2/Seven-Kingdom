class_name SKState
extends RefCounted
## Stato e regole di Seven Kingdom. Tutto ciò che cambia la partita passa da qui, così l'IA può
## copiare lo stato e provare le mosse. Le scelte che spettano ai giocatori durante le fasi passive
## (pareggi, Corona, battaglie) si chiedono a un "chooser": nel gioco vero è il motore (che aspetta
## la persona o la rete), nelle simulazioni dell'IA risponde subito.
##
## Pezzi sui siti: -1 libero, 0..3 villaggio del giocatore, INV invasore.

const INV := 9

var n := 4
var names: Array = []
var scen: Dictionary = {}
var opts: Dictionary = {}

## Regni, nell'ordine delle posizioni del tabellone.
## {tile, pos, sites[], res[], econ, infl, bishop, war, peace}
var regions: Array = []
var land: Array = []           # regno -> regni collegati da un ponte
var sea: Array = []            # regno -> regno collegato via porto (o -1)
var tile_index: Dictionary = {}  # id tessera -> indice regno

var chars: Dictionary = {}     # personaggio -> regno
var reserve: Array = []        # villaggi in riserva
var bishops: Array = []        # vescovi in riserva
var res: Array = []            # risorse: [{legno: n, …}]
var favor: Array = []          # ha il Favore Papale
var first := 0                 # chi ha la Corona (Primo Giocatore)
var inv_supply := SKData.INVADERS
var infl_supply := SKData.INFLUENCE
var res_removed := 0

var turn := 0
var used: Dictionary = {}      # personaggio -> giocatore che l'ha usato in questo turno
var battles: Dictionary = {}   # esercito -> giocatore che ha dichiarato battaglia
var objectives: Array = []     # obiettivo segreto di ciascuno ("" se non si usano)
var game_over := false
var end_reason := ""           # "guerre", "pace", "invasione", "fede", "papa", "limite"

# variante dell'Alchimista (opts.alchemist)
var deck: Array = []           # pila dei progetti (id), si pesca dal fondo
var pdiscard: Array = []       # scarti dell'Athanor (mai realizzati)
var hand: Array = []           # progetti in mano (segreti) per giocatore
var built: Array = []          # progetti realizzati: [{id, used}] per giocatore
var spent: Dictionary = {}     # riserva delle risorse spese
var pending_ath: Array = []    # (non più usato)
var battle_bonus: Dictionary = {}  # (non più usato)
var act_left: Array = []       # carte che si possono ancora attivare con l'Alchimista in questo turno
var free_next: Array = []      # Athanor: la prossima carta attivata in questo turno non costa risorse
var ath_count: Array = []      # attivazioni con l'Athanor girato (ogni due, una risorsa)
var jolly: Array = []          # risorse jolly (dalla passiva dell'Alchimista): valgono come qualsiasi risorsa
var turn_bonus: Array = []     # forza in più nelle proprie battaglie di questo turno (Stendardo, Polvere)

var rng := RandomNumberGenerator.new()
var log_lines: Array = []
var quiet := false             # nelle simulazioni non si scrive il registro
var events: Array = []         # eventi per l'animazione (svuotati dalla vista)


# ------------------------------------------------------------------ preparazione

func setup(p_names: Array, scenario: Dictionary, p_opts: Dictionary, seed_value: int) -> void:
	n = p_names.size()
	names = p_names.duplicate()
	scen = scenario.duplicate(true)
	opts = p_opts.duplicate(true)
	rng.seed = seed_value
	regions.clear()
	tile_index.clear()
	var tiles := {}
	for k in scen["tiles"]:
		tiles[int(k)] = scen["tiles"][k]
	var poss: Array = tiles.keys()
	poss.sort()
	var pos_to_r := {}
	for p in poss:
		var t: String = tiles[p]
		var ns: int = SKData.TILES[t]["sites"].size()
		var sites := []
		var rr := []
		for i in ns:
			sites.append(-1)
			rr.append("")
		pos_to_r[p] = regions.size()
		tile_index[t] = regions.size()
		regions.append({"tile": t, "pos": p, "sites": sites, "res": rr, "econ": 2, "infl": 0, "bishop": -1, "war": false, "peace": false})
	land.clear()
	sea.clear()
	for i in regions.size():
		land.append([])
		sea.append(-1)
	for b in scen["bridges"]:
		var a: int = pos_to_r[int(b[0])]
		var c: int = pos_to_r[int(b[1])]
		land[a].append(c)
		land[c].append(a)
	var port_r := {}
	for pt in scen["ports"]:
		port_r[pt["id"]] = pos_to_r[int(pt["pos"])]
	for pr in [["alba", "vespro"], ["rupe", "bruma"]]:
		sea[port_r[pr[0]]] = port_r[pr[1]]
		sea[port_r[pr[1]]] = port_r[pr[0]]
	for i in regions.size():
		land[i].sort()
	reserve.clear()
	bishops.clear()
	res.clear()
	favor.clear()
	for p in n:
		reserve.append(SKData.VILLAGES_PER_PLAYER)
		bishops.append(SKData.BISHOPS_PER_PLAYER)
		var d := {}
		for t in SKData.RESOURCES:
			d[t] = 0
		res.append(d)
		favor.append(false)
	for c in SKData.CHARS:
		chars[c] = tile_index[scen["start"][c]]
	# la Capitale parte da 3 di Ricchezza, gli altri regni da 2
	regions[tile_index["capitale"]]["econ"] = 3
	# risorse a caso su tutti i siti
	var bag := []
	for t in SKData.RESOURCES:
		for i in SKData.RES_PER_TYPE:
			bag.append(t)
	_shuffle(bag)
	for r in regions:
		for i in r["sites"].size():
			r["res"][i] = bag.pop_back() if not bag.is_empty() else ""
	# poi, dove parte la Spia un invasore (che distrugge la risorsa del suo sito), dove parte il Papa un'influenza religiosa sul 5
	_add_invader(chars["spia"], false)
	_place_influence(chars["papa"])
	first = 0
	objectives.clear()
	for p in n:
		objectives.append("")
	_setup_alchemy()


func alch() -> bool:
	return opts.get("alchemist", false)


func _setup_alchemy() -> void:
	SKData.alch = alch()
	deck.clear()
	pdiscard.clear()
	hand.clear()
	built.clear()
	pending_ath.clear()
	act_left.clear()
	free_next.clear()
	turn_bonus.clear()
	jolly.clear()
	ath_count.clear()
	spent = {}
	for t in SKData.RESOURCES:
		spent[t] = 0
	for p in n:
		hand.append([])
		built.append([])
		pending_ath.append([])
		act_left.append(0)
		free_next.append(false)
		turn_bonus.append(0)
		jolly.append(0)
		ath_count.append(0)
	if not alch():
		return
	# tutte le 24 carte in gioco, distribuite equamente (le eventuali avanzate restano fuori)
	for id in SKData.PROJ_IDS:
		deck.append(id)
		deck.append(id)
	_shuffle(deck)
	var each := deck.size() / n
	for k in each:
		for p in n:
			hand[p].append(deck.pop_back())


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func clone() -> SKState:
	var s := SKState.new()
	s.n = n
	s.names = names
	s.scen = scen
	s.opts = opts
	s.regions = regions.duplicate(true)
	s.land = land
	s.sea = sea
	s.tile_index = tile_index
	s.chars = chars.duplicate()
	s.reserve = reserve.duplicate()
	s.bishops = bishops.duplicate()
	s.res = res.duplicate(true)
	s.favor = favor.duplicate()
	s.first = first
	s.inv_supply = inv_supply
	s.infl_supply = infl_supply
	s.res_removed = res_removed
	s.turn = turn
	s.used = used.duplicate()
	s.battles = battles.duplicate()
	s.objectives = objectives
	s.game_over = game_over
	s.end_reason = end_reason
	s.rng.state = rng.state
	s.deck = deck.duplicate()
	s.pdiscard = pdiscard.duplicate()
	s.hand = hand.duplicate(true)
	s.built = built.duplicate(true)
	s.spent = spent.duplicate()
	s.pending_ath = pending_ath.duplicate(true)
	s.battle_bonus = battle_bonus.duplicate()
	s.act_left = act_left.duplicate()
	s.free_next = free_next.duplicate()
	s.turn_bonus = turn_bonus.duplicate()
	s.jolly = jolly.duplicate()
	s.ath_count = ath_count.duplicate()
	s.quiet = true
	return s


# ------------------------------------------------------------------ registro

func log_msg(t: String) -> void:
	if not quiet:
		log_lines.append(t)


func ev(kind: String, data := {}) -> void:
	if not quiet:
		data["k"] = kind
		events.append(data)


func pname(p: int) -> String:
	if p == INV:
		return "gli invasori"
	if p < 0 or p >= names.size():
		return "nessuno"
	return names[p]


func rname(r: int) -> String:
	return SKData.TILES[regions[r]["tile"]]["n"]


# ------------------------------------------------------------------ domande sullo stato

func neighbors(r: int, use_sea := true) -> Array:
	var out: Array = land[r].duplicate()
	if use_sea and sea[r] >= 0 and not out.has(sea[r]):
		out.append(sea[r])
	return out


func is_adj(a: int, b: int) -> bool:
	return land[a].has(b)


func sites(r: int) -> Array:
	return regions[r]["sites"]


func count(r: int, piece: int) -> int:
	var k := 0
	for s in regions[r]["sites"]:
		if s == piece:
			k += 1
	return k


func colored(r: int) -> int:
	var k := 0
	for s in regions[r]["sites"]:
		if s >= 0 and s < INV:
			k += 1
	return k


func lowest_free(r: int) -> int:
	var st: Array = regions[r]["sites"]
	for i in st.size():
		if st[i] == -1:
			return i
	return -1


func highest_free(r: int) -> int:
	var st: Array = regions[r]["sites"]
	for i in range(st.size() - 1, -1, -1):
		if st[i] == -1:
			return i
	return -1


func free_count(r: int) -> int:
	return count(r, -1)


func governor(r: int) -> int:
	var g: int = regions[r]["sites"][0]
	return g if g >= 0 and g < INV else -1


func has_army(r: int) -> bool:
	return chars["fanteria"] == r or chars["cavalleria"] == r


func chars_in(r: int) -> Array:
	var out := []
	for c in SKData.CHARS:
		if chars[c] == r:
			out.append(c)
	return out


func war_count() -> int:
	var k := 0
	for r in regions:
		if r["war"]:
			k += 1
	return k


func peace_count() -> int:
	var k := 0
	for r in regions:
		if r["peace"]:
			k += 1
	return k


## Valore del Governatore: il numero più alto della Ricchezza non coperto da un'influenza religiosa.
func gov_value(r: int) -> int:
	return 5 - int(regions[r]["infl"])


func econ(r: int) -> int:
	return int(regions[r]["econ"])


## Maggioranza in un regno: {"w": vincitore o -1, "tied": [giocatori a pari merito]}.
func majority_info(r: int) -> Dictionary:
	var cnt := []
	for p in n:
		cnt.append(0)
	for s in regions[r]["sites"]:
		if s >= 0 and s < INV:
			cnt[s] += 1
	var best := 0
	for p in n:
		best = maxi(best, cnt[p])
	if best == 0:
		return {"w": -1, "tied": []}
	var tied := []
	for p in n:
		if cnt[p] == best:
			tied.append(p)
	return {"w": tied[0] if tied.size() == 1 else -1, "tied": tied}


## Maggioranza risolta in modo automatico (per il punteggio e l'IA): a parità decide il Governatore,
## che sceglie sé stesso se è fra i pari, altrimenti nessuno vince.
func majority_auto(r: int) -> int:
	var mi := majority_info(r)
	if mi["w"] >= 0:
		return mi["w"]
	var g := governor(r)
	if g >= 0 and mi["tied"].has(g):
		return g
	return -1


func total_res(p: int) -> int:
	var k := 0
	for t in res[p]:
		k += res[p][t]
	return k


# ------------------------------------------------------------------ movimenti di pezzi

func _return_piece(piece: int) -> void:
	if piece == INV:
		inv_supply += 1
	elif piece >= 0:
		reserve[piece] += 1


## Chi arriva su un sito con una risorsa la prende (un invasore la distrugge).
## no_res: il villaggio costruito da un esercito non prende la risorsa, che va persa.
func _collect(r: int, i: int, no_res := false) -> void:
	var rg: Dictionary = regions[r]
	var t: String = rg["res"][i]
	if t == "":
		return
	var piece: int = rg["sites"][i]
	if piece == -1:
		return
	rg["res"][i] = ""
	if piece >= 0 and piece < INV and not no_res:
		res[piece][t] += 1
		ev("res", {"r": r, "i": i, "p": piece, "t": t})
		log_msg("%s prende 1 %s." % [pname(piece), SKData.RES_NAME[t]])
	else:
		res_removed += 1
		ev("res_lost", {"r": r, "i": i, "t": t})


## Mette un pezzo su un sito libero.
func _put(r: int, i: int, piece: int, no_res := false) -> void:
	regions[r]["sites"][i] = piece
	if piece == INV:
		inv_supply -= 1
	else:
		reserve[piece] -= 1
	_collect(r, i, no_res)


## Inserisce un pezzo nel sito i, facendo scalare in avanti i pezzi che seguono fino al primo sito
## libero; se non ce ne sono, l'ultimo pezzo esce e torna alla riserva.
func _insert(r: int, i: int, piece: int) -> void:
	var st: Array = regions[r]["sites"]
	var j := -1
	for k in range(i, st.size()):
		if st[k] == -1:
			j = k
			break
	if j == -1:
		var out: int = st[st.size() - 1]
		_return_piece(out)
		if out != -1:
			ev("out", {"r": r, "p": out})
			log_msg("Il pezzo di %s in fondo a %s esce e torna alla riserva." % [pname(out), rname(r)])
		j = st.size() - 1
	for k in range(j, i, -1):
		st[k] = st[k - 1]
	st[i] = -1
	if piece == INV:
		inv_supply -= 1
	else:
		reserve[piece] -= 1
	st[i] = piece
	_collect(r, j)
	if j != i:
		_collect(r, i)


func _check_peace(r: int) -> void:
	var rg: Dictionary = regions[r]
	if rg["peace"] or rg["war"]:
		return
	for s in rg["sites"]:
		if s < 0 or s >= INV:
			return
	if peace_count() >= SKData.PEACE_MARKERS:
		return
	rg["peace"] = true
	ev("peace", {"r": r})
	log_msg("%s è pacificato: d'ora in poi Spia e invasioni non hanno effetto." % rname(r))


func _start_war(r: int) -> void:
	var rg: Dictionary = regions[r]
	if rg["war"]:
		return
	if war_count() >= SKData.WAR_MARKERS:
		return
	rg["war"] = true
	ev("war", {"r": r})
	log_msg("Scoppia la GUERRA in %s!" % rname(r))


## Un invasore arriva: sul sito libero più alto; se non c'è posto, prende il posto del villaggio sul
## sito più alto e scoppia una Guerra. Restituisce false se non è stato possibile.
func _add_invader(r: int, can_war := true) -> bool:
	var rg: Dictionary = regions[r]
	if rg["peace"] or inv_supply <= 0:
		return false
	var hf := highest_free(r)
	if hf >= 0:
		_put(r, hf, INV)
		ev("inv", {"r": r, "i": hf})
		return true
	var st: Array = rg["sites"]
	for i in range(st.size() - 1, -1, -1):
		if st[i] >= 0 and st[i] < INV:
			var p: int = st[i]
			_return_piece(p)
			st[i] = INV
			inv_supply -= 1
			ev("inv", {"r": r, "i": i, "kill": p})
			log_msg("Un invasore scaccia un villaggio di %s in %s." % [pname(p), rname(r)])
			if can_war:
				_start_war(r)
			return true
	return false


## Un invasore sostituisce il villaggio sul sito più alto (costo della guerra, battaglia persa).
func _invader_replaces(r: int) -> void:
	if inv_supply <= 0:
		return
	var st: Array = regions[r]["sites"]
	for i in range(st.size() - 1, -1, -1):
		if st[i] >= 0 and st[i] < INV:
			var p: int = st[i]
			_return_piece(p)
			st[i] = INV
			inv_supply -= 1
			ev("inv", {"r": r, "i": i, "kill": p})
			log_msg("Un invasore prende il posto di un villaggio di %s in %s." % [pname(p), rname(r)])
			return
	var hf := highest_free(r)
	if hf >= 0:
		_put(r, hf, INV)
		ev("inv", {"r": r, "i": hf})


## Influenza religiosa sul numero più alto libero della Ricchezza. Se lì c'è l'indicatore della
## Ricchezza, questo scende di un numero (fino a 0, quando la traccia è tutta coperta: fine partita).
func can_influence(r: int) -> bool:
	return int(regions[r]["infl"]) < 5 and infl_supply > 0


func _place_influence(r: int) -> void:
	var rg: Dictionary = regions[r]
	if not can_influence(r):
		return
	rg["infl"] += 1
	infl_supply -= 1
	var slot := 6 - int(rg["infl"])
	if int(rg["econ"]) >= slot:
		rg["econ"] = slot - 1
	ev("infl", {"r": r})


func _econ_up(r: int, force := false) -> bool:
	var rg: Dictionary = regions[r]
	var e: int = rg["econ"]
	if e >= 5:
		return false
	if e + 1 > 5 - int(rg["infl"]):
		if not force:
			return false
		# solo la vittoria in battaglia può togliere un'influenza religiosa
		rg["infl"] -= 1
		ev("infl_out", {"r": r})
		log_msg("Un'influenza religiosa lascia %s." % rname(r))
	rg["econ"] = e + 1
	ev("econ", {"r": r})
	return true


# ------------------------------------------------------------------ azioni dei giocatori

## Preparazione: un villaggio sul sito libero più basso del regno scelto (prendendone la risorsa).
func setup_regions() -> Array:
	var out := []
	for r in regions.size():
		if lowest_free(r) >= 0:
			out.append(r)
	return out


func setup_place(p: int, r: int) -> void:
	var i := lowest_free(r)
	if i < 0 or reserve[p] <= 0:
		return
	_put(r, i, p)
	ev("place", {"r": r, "i": i, "p": p})
	log_msg("%s pone un villaggio in %s." % [pname(p), rname(r)])
	_check_peace(r)


func available_chars() -> Array:
	var out := []
	for c in SKData.CHARS:
		if not used.has(c):
			out.append(c)
	return out


## Destinazioni possibili per un personaggio: elenco di percorsi (array di regni).
## p: chi muove (con la Bussola celeste dell'Alchimista si fa un passo in più).
func move_paths(c: String, p := -1) -> Array:
	var from: int = chars[c]
	var out := []
	var extra: bool = p >= 0 and has_art(p, "A02")
	if c == "cavalleria":
		for a in land[from]:
			out.append([a])
			for b in land[a]:
				if b != from:
					out.append([a, b])
					if extra:
						for d in land[b]:
							if d != from and d != a:
								out.append([a, b, d])
	else:
		for a in neighbors(from):
			out.append([a])
			if extra:
				for b in neighbors(a):
					if b != from:
						out.append([a, b])
	return out


func _king_region_ok(r: int, powered: bool) -> bool:
	var rg: Dictionary = regions[r]
	if rg["war"]:
		return false
	if not powered and has_army(r):
		return false
	return true


## Regni dove il Papa può mettere influenza, dopo essersi mosso in dest.
func pope_targets(dest: int, powered: bool) -> Array:
	var out := []
	for r in [dest] + land[dest]:
		if (powered or not regions[r]["war"]) and can_influence(r):
			out.append(r)
	return out


func free_cathedrals() -> Array:
	var out := []
	for i in regions.size():
		if regions[i]["bishop"] == -1:
			out.append(i)
	return out


## Siti scambiabili dalla Spia in un regno.
func spy_sites(r: int, powered: bool) -> Array:
	var out := []
	var st: Array = regions[r]["sites"]
	for i in st.size():
		if st[i] >= 0 and st[i] < INV and (powered or i > 0):
			out.append(i)
	return out


## Numero massimo di villaggi che il Re (azione normale) deve mettere: {"main": n nel suo regno, "adj": [regni adiacenti ammessi]}.
func king_normal_slots(dest: int) -> Dictionary:
	var main := 0
	if _king_region_ok(dest, false):
		main = mini(2, free_count(dest))
	var adj := []
	for a in land[dest]:
		if _king_region_ok(a, false) and free_count(a) > 0:
			adj.append(a)
	return {"main": main, "adj": adj}


## Verifica una mossa senza applicarla. Restituisce "" se va bene, altrimenti il motivo.
func check_move(p: int, m: Dictionary) -> String:
	var c: String = m.get("c", "")
	if not SKData.CHARS.has(c):
		return "personaggio sconosciuto"
	if used.has(c):
		return "personaggio già usato in questo turno"
	var pw: bool = m.get("pw", false)
	if pw and not favor[p]:
		return "serve un Favore Papale per l'azione potenziata"
	var path: Array = m.get("path", [])
	var ok_path := false
	var path_i := []
	for x in path:
		path_i.append(int(x))
	for mp in move_paths(c, p):
		if mp == path_i:
			ok_path = true
			break
	if not ok_path:
		return "movimento non consentito"
	var dest: int = path[path.size() - 1]
	match c:
		"re":
			return _check_king(p, dest, pw, m.get("pl", []))
		"papa":
			var t := int(m.get("r", -1))
			var targets := pope_targets(dest, pw)
			if t == -1:
				if not targets.is_empty():
					return "scegli dove mettere l'influenza"
			elif not targets.has(t):
				return "lì non si può mettere influenza"
			if pw:
				var b := int(m.get("b", -1))
				if b == -1:
					if bishops[p] > 0 and not free_cathedrals().is_empty():
						return "scegli la Cattedrale del Vescovo"
				elif not free_cathedrals().has(b) or bishops[p] <= 0:
					return "Cattedrale non disponibile"
			return ""
		"mercante":
			if alch():
				return ""
			var q := int(m.get("from", -1))
			var take: Array = m.get("res", [])
			var any := false
			for o in n:
				if o != p and total_res(o) > 0:
					any = true
			if q == -1:
				return "" if not any else "scegli a chi prendere le risorse"
			if q == p or q < 0 or q >= n:
				return "giocatore non valido"
			var need := mini(2 if pw else 1, total_res(q))
			if take.size() != need:
				return "numero di risorse sbagliato"
			var tmp: Dictionary = res[q].duplicate()
			for t in take:
				if not tmp.has(t) or tmp[t] <= 0:
					return "risorsa non disponibile"
				tmp[t] -= 1
			return ""
		"spia":
			if not m.has("a"):
				return ""
			if not m.has("b"):
				return "scegli il secondo villaggio da scambiare"
			var a: Array = m["a"]
			var b: Array = m["b"]
			if int(a[0]) != dest:
				return "il primo villaggio deve essere nel regno della Spia"
			if not land[dest].has(int(b[0])):
				return "il secondo villaggio deve essere in un regno adiacente"
			if not spy_sites(dest, pw).has(int(a[1])) or not spy_sites(int(b[0]), pw).has(int(b[1])):
				return "scambio non consentito"
			return ""
		"fanteria", "cavalleria":
			if m.get("battle", false):
				if not regions[dest]["war"]:
					return "si dà battaglia solo in un regno in guerra"
				if pw:
					return "per dare battaglia non serve l'azione potenziata (il Favore lo tieni per il +1)"
			return ""
	return ""


func _check_king(p: int, dest: int, pw: bool, pl: Array) -> String:
	var need := {}
	if pw:
		var cand: Array = [dest] + land[dest]
		var max_n := 0
		var space := 0
		for r in cand:
			if _king_region_ok(r, true):
				space += 1
		if space > 0:
			max_n = 2
		var tot := 0
		for o in n:
			tot += reserve[o]
		max_n = mini(max_n, tot)
		if pl.size() != max_n:
			return "con l'azione potenziata il Re mette 2 villaggi"
		var cnt := {}
		var adj_used := -1
		for x in pl:
			var r := int(x[0])
			var o := int(x[1])
			if not cand.has(r) or not _king_region_ok(r, true):
				return "regno non consentito"
			if r != dest:
				if adj_used != -1 and adj_used != r:
					return "al massimo un regno adiacente oltre a quello del Re"
				adj_used = r
			if o < 0 or o >= n:
				return "colore non valido"
			cnt[o] = cnt.get(o, 0) + 1
		for o in cnt:
			if reserve[o] < cnt[o]:
				return "%s non ha abbastanza villaggi" % pname(o)
		return ""
	var sl := king_normal_slots(dest)
	var in_main := 0
	var adj_r := -1
	var cnt2 := {}
	for x in pl:
		var r := int(x[0])
		var o := int(x[1])
		if o < 0 or o >= n:
			return "colore non valido"
		cnt2[o] = cnt2.get(o, 0) + 1
		if r == dest:
			in_main += 1
		elif sl["adj"].has(r):
			if adj_r != -1:
				return "un solo villaggio nel regno adiacente"
			adj_r = r
		else:
			return "regno non consentito"
	if in_main > sl["main"]:
		return "troppi villaggi nel regno del Re"
	# vanno messi tutti i villaggi possibili (riserve permettendo)
	var tot_res := 0
	for o in n:
		tot_res += reserve[o]
	var want := mini(sl["main"] + (1 if not sl["adj"].is_empty() else 0), tot_res)
	if pl.size() < want:
		return "il Re deve mettere %d villaggi" % want
	for o in cnt2:
		if reserve[o] < cnt2[o]:
			return "%s non ha abbastanza villaggi" % pname(o)
	if pl.size() == 1 and int(pl[0][1]) != p and reserve[p] > 0:
		return "se metti un solo villaggio deve essere tuo"
	if pl.size() >= 2:
		var other := false
		for x in pl:
			if int(x[1]) != p:
				other = true
		if not other:
			return "almeno un villaggio deve essere di un altro colore"
	return ""


## Applica una mossa già verificata.
func apply_move(p: int, m: Dictionary) -> void:
	var c: String = m["c"]
	var pw: bool = m.get("pw", false)
	used[c] = p
	if pw:
		favor[p] = false
		log_msg("%s scarta il Favore Papale per l'azione potenziata." % pname(p))
	var path: Array = m["path"]
	var from: int = chars[c]
	var dest: int = path[path.size() - 1]
	chars[c] = dest
	ev("move", {"c": c, "path": [from] + path})
	var via_sea: bool = path.size() == 1 and not land[from].has(dest)
	log_msg("%s sceglie %s%s e lo porta in %s%s." % [pname(p), SKData.cn(c), " (potenziata)" if pw else "", rname(dest), " via mare" if via_sea else ""])
	match c:
		"re":
			if pw:
				var done := {}
				for x in m.get("pl", []):
					var r := int(x[0])
					var o := int(x[1])
					var at := 1 + int(done.get(r, 0))
					at = mini(at, regions[r]["sites"].size() - 1)
					_insert(r, at, o)
					done[r] = int(done.get(r, 0)) + 1
					ev("place", {"r": r, "i": at, "p": o})
					log_msg("Il Re pone un villaggio di %s in %s (posizione %d)." % [pname(o), rname(r), at + 1])
					_check_peace(r)
			else:
				for x in m.get("pl", []):
					var r := int(x[0])
					var o := int(x[1])
					var i := lowest_free(r)
					if i < 0:
						continue
					_put(r, i, o)
					ev("place", {"r": r, "i": i, "p": o})
					log_msg("Il Re pone un villaggio di %s in %s." % [pname(o), rname(r)])
					_check_peace(r)
		"papa":
			var t := int(m.get("r", -1))
			if t >= 0:
				_place_influence(t)
				log_msg("Il Papa pone un'influenza religiosa in %s (Ricchezza %d)." % [rname(t), econ(t)])
			if pw:
				var b := int(m.get("b", -1))
				if b >= 0:
					regions[b]["bishop"] = p
					bishops[p] -= 1
					ev("bishop", {"r": b, "p": p})
					log_msg("%s nomina un Vescovo nella Cattedrale di %s." % [pname(p), rname(b)])
		"mercante":
			if alch():
				act_left[p] = 2 if pw else 1
				if pw:
					jolly[p] += 1
					log_msg("%s riceve una risorsa jolly dall'Alchimista." % pname(p))
				return
			var q := int(m.get("from", -1))
			for t in m.get("res", []):
				res[q][t] -= 1
				res[p][t] += 1
				log_msg("Il Mercante prende 1 %s a %s." % [SKData.RES_NAME[t], pname(q)])
			if q >= 0:
				ev("steal", {"from": q, "to": p, "res": m.get("res", [])})
		"spia":
			if m.has("a"):
				var a: Array = m["a"]
				var b: Array = m["b"]
				var ra := int(a[0])
				var rb := int(b[0])
				var pa: int = regions[ra]["sites"][int(a[1])]
				var pb: int = regions[rb]["sites"][int(b[1])]
				regions[ra]["sites"][int(a[1])] = pb
				regions[rb]["sites"][int(b[1])] = pa
				ev("swap", {"a": a, "b": b})
				log_msg("La Spia scambia un villaggio di %s in %s con uno di %s in %s." % [pname(pa), rname(ra), pname(pb), rname(rb)])
				_check_peace(ra)
				_check_peace(rb)
		"fanteria", "cavalleria":
			if m.get("battle", false):
				battles[c] = p
				log_msg("%s dichiara battaglia in %s: si combatterà alla fine del turno." % [pname(p), rname(dest)])
			elif not regions[dest]["war"]:
				var k := 2 if pw else 1
				for z in k:
					var st: Array = regions[dest]["sites"]
					var idx := st.find(INV)
					if idx < 0:
						break
					st[idx] = -1
					inv_supply += 1
					ev("inv_out", {"r": dest, "i": idx})
					var lf := lowest_free(dest)
					if lf >= 0 and reserve[p] > 0:
						_put(dest, lf, p, true)
						ev("place", {"r": dest, "i": lf, "p": p})
					log_msg("%s scaccia un invasore da %s e vi costruisce un villaggio." % [SKData.cn(c), rname(dest)])
				_check_peace(dest)


# ------------------------------------------------------------------ fasi passive e fine turno
## ch: chi risponde alle scelte. Metodi: tie(gov, tied, r, why) -> giocatore,
## crown(p) -> giocatore, battle_favor(p, r) -> bool, battle_gov(g, p, r) -> bool.

func _majority(ch, r: int, why: String):
	var mi := majority_info(r)
	if mi["w"] >= 0:
		return mi["w"]
	if mi["tied"].is_empty():
		return -1
	var g := governor(r)
	if g < 0:
		return -1
	var w = await ch.tie(g, mi["tied"], r, why)
	w = int(w)
	if not mi["tied"].has(w):
		w = mi["tied"][0]
	log_msg("Parità in %s: decide il Governatore %s, che sceglie %s." % [rname(r), pname(g), pname(w)])
	return w


func passive_phase(ch) -> void:
	# Re
	var rk: int = chars["re"]
	var w = await _majority(ch, rk, "corona")
	if w >= 0:
		var to = await ch.crown(w)
		to = clampi(int(to), 0, n - 1)
		if to != first:
			log_msg("%s ha la maggioranza in %s e dà la Corona a %s." % [pname(w), rname(rk), pname(to)])
			ev("crown", {"p": to})
		else:
			log_msg("%s ha la maggioranza in %s: la Corona resta a %s." % [pname(w), rname(rk), pname(to)])
		first = to
	# Papa
	var rp: int = chars["papa"]
	w = await _majority(ch, rp, "favore")
	if w >= 0:
		if not favor[w]:
			var held := 0
			for q in n:
				if favor[q]:
					held += 1
			if held < SKData.FAVORS:
				favor[w] = true
				ev("favor", {"p": w})
				log_msg("%s ha la maggioranza in %s e riceve un Favore Papale." % [pname(w), rname(rp)])
	# Mercante
	var rm: int = chars["mercante"]
	if not regions[rm]["war"]:
		if _econ_up(rm):
			log_msg(SKData.cn("mercante") + " fa crescere la Ricchezza di %s a %d." % [rname(rm), econ(rm)])
	if alch():
		var wa = await _majority(ch, rm, "alchimista")
		if wa >= 0:
			jolly[wa] += 1
			ev("jolly", {"p": wa})
			log_msg("%s ha la maggioranza nel regno dell'Alchimista e riceve una risorsa jolly." % pname(wa))
		if wa >= 0 and can_activate_any(wa):
			var v = await ch.alch_act(wa)
			if v is Dictionary and not v.is_empty() and check_projects(wa, v) == "":
				log_msg("%s ha la maggioranza nel regno dell'Alchimista e attiva una carta." % pname(wa))
				apply_projects(wa, v)
	# Spia
	var rs: int = chars["spia"]
	if not regions[rs]["peace"]:
		if _add_invader(rs):
			log_msg("La Spia fomenta una rivolta: un invasore entra in %s." % rname(rs))
	# Eserciti: battaglie
	for c in ["fanteria", "cavalleria"]:
		if battles.has(c):
			await _battle(ch, battles[c], chars[c], c)
	battles.clear()


## Attacco già calcolato quando si chiede l'aiuto al Governatore (solo per l'interfaccia).
var battle_atk := 0


func _battle(ch, p: int, r: int, army: String) -> void:
	var rg: Dictionary = regions[r]
	if not rg["war"]:
		return
	var inv := count(r, INV)
	var dice: bool = opts.get("dice", false)
	var atk := 0
	var parts := []
	if not dice:
		atk = count(r, p)
		parts.append("%d villaggi" % atk)
		if first == p:
			atk += 1
			parts.append("Corona +1")
	if chars["fanteria"] == r:
		atk += 1
		parts.append("Fanteria +1")
	if alch() and has_art(p, "A03"):
		atk += 1
		parts.append("Stendardo animato +1")
	if alch() and has_art(p, "I06"):
		atk += 1
		parts.append("Polvere del tuono +1")
	if alch() and int(turn_bonus[p]) > 0:
		atk += int(turn_bonus[p])
		parts.append("carte dell'Alchimista +%d" % int(turn_bonus[p]))
	if favor[p]:
		var use = await ch.battle_favor(p, r)
		if use:
			favor[p] = false
			atk += 1
			parts.append("Favore Papale +1")
	var g := governor(r)
	if g >= 0:
		var help = true
		if g != p:
			battle_atk = atk
			help = await ch.battle_gov(g, p, r)
		if help:
			atk += 1
			parts.append("Governatore +1")
	var win := false
	var roll := 0
	if dice:
		roll = rng.randi_range(1, 6)
		win = roll + atk > inv
		log_msg("Battaglia in %s: %s tira %d%s contro %d invasori." % [rname(r), pname(p), roll, (" (+%d: %s)" % [atk, ", ".join(parts)]) if atk > 0 else "", inv])
	else:
		win = atk >= inv
		log_msg("Battaglia in %s: %s attacca con %d (%s) contro %d invasori." % [rname(r), pname(p), atk, ", ".join(parts), inv])
	ev("battle", {"r": r, "p": p, "win": win, "atk": atk, "inv": inv, "roll": roll})
	if win:
		var st: Array = rg["sites"]
		for i in st.size():
			if st[i] == INV:
				st[i] = -1
				inv_supply += 1
		rg["war"] = false
		# il vincitore diventa Governatore: i villaggi presenti scalano in avanti
		if reserve[p] > 0:
			_insert(r, 0, p)
		_econ_up(r, true)
		log_msg("VITTORIA! %s libera %s e ne diventa Governatore." % [pname(p), rname(r)])
		_check_peace(r)
	else:
		_invader_replaces(r)
		log_msg("Sconfitta: gli invasori resistono in %s." % rname(r))


func end_phase(_ch = null) -> void:
	# costo della guerra
	for r in regions.size():
		var rg: Dictionary = regions[r]
		if rg["war"]:
			if int(rg["econ"]) > 1:
				rg["econ"] -= 1
				ev("econ", {"r": r})
				log_msg("La guerra impoverisce %s (Ricchezza %d)." % [rname(r), econ(r)])
			else:
				_invader_replaces(r)
	if check_end():
		return
	# invasione: nei regni senza personaggi, non pacificati e non in guerra
	# (regola di prova «invasione a turni alterni»: solo nei turni pari)
	var invade: bool = not (truce_turn())
	if not invade:
		log_msg("Turno di tregua: questa volta non arrivano invasori.")
	for r in regions.size():
		if not invade:
			break
		var rg: Dictionary = regions[r]
		if rg["peace"] or rg["war"]:
			continue
		if not chars_in(r).is_empty():
			continue
		if alch() and opts.get("alch_inv_soft", false) and colored(r) > 0:
			continue
		if _add_invader(r):
			log_msg("Invasione! Gli invasori dilagano in %s, lasciato senza personaggi." % rname(r))
	used.clear()
	for q in act_left.size():
		act_left[q] = 0
		free_next[q] = false
		turn_bonus[q] = 0
	turn += 1
	# tre guerre o un regno pieno di invasori fanno terminare subito la partita
	check_end()


## Turno di tregua (variante dell'Alchimista): a turni alterni, a fine turno non arrivano invasori.
func truce_turn() -> bool:
	return opts.get("inv_alt", alch()) and turn % 2 == 0


## Controllo di fine gioco. Restituisce true (e imposta game_over) se la partita è finita.
func check_end() -> bool:
	# variante dell'Alchimista, regola di durata: nessuna fine prima del 5° turno
	if alch() and opts.get("alch_late", false) and turn < 4:
		return false
	var peace_need := 4 if alch() and opts.get("alch_peace4", true) else 3
	var war_need := 4 if alch() and opts.get("alch_wars4", false) else 3
	if war_count() >= war_need:
		end_reason = "guerre"
	elif peace_count() >= peace_need:
		end_reason = "pace"
	else:
		for r in regions.size():
			if count(r, INV) == regions[r]["sites"].size():
				end_reason = "invasione"
				break
			if int(regions[r]["infl"]) >= 5:
				end_reason = "fede"
				break
		if end_reason == "" and infl_supply <= 0:
			end_reason = "papa"
	if end_reason != "":
		game_over = true
		return true
	return false


const END_TEXT := {
	"guerre": "Tre Guerre infuriano contemporaneamente nel regno.",
	"pace": "I regni pacificati sono abbastanza (tre, quattro con l'Alchimista).",
	"invasione": "Un regno è caduto interamente in mano agli invasori.",
	"fede": "La Ricchezza di un regno è tutta coperta dall'influenza religiosa.",
	"papa": "Il Papa ha esaurito l'influenza religiosa.",
	"limite": "È stato raggiunto il limite di turni.",
}


# ------------------------------------------------------------------ punteggio

## Punteggio dettagliato di un giocatore: {tot, villaggi, gov, vescovi, risorse, corona, favore, obiettivo}.
func score_detail(p: int, with_obj := true) -> Dictionary:
	var vil := 0
	var gov := 0
	var bis := 0
	for r in regions.size():
		var rg: Dictionary = regions[r]
		var st: Array = rg["sites"]
		for i in st.size():
			if st[i] == p:
				if i == 0:
					gov += gov_value(r)
				else:
					vil += int(rg["econ"])
		if rg["bishop"] == p:
			bis += 2 + 2 * int(rg["infl"])
	var rs := 0
	var pj := 0
	if alch():
		pj = proj_points(p)
	else:
		for t in SKData.RESOURCES:
			rs += res_prize(p, t)
	var cr := 2 if first == p else 0
	var fv := 2 if favor[p] else 0
	var ob := 0
	if with_obj and objectives.size() > p and objectives[p] != "":
		ob = objective_points(p, objectives[p])
	return {"tot": vil + gov + bis + rs + pj + cr + fv + ob, "villaggi": vil, "gov": gov, "vescovi": bis, "risorse": rs, "progetti": pj, "corona": cr, "favore": fv, "obiettivo": ob}


func score(p: int, with_obj := true) -> int:
	return score_detail(p, with_obj)["tot"]


## Premio di un tipo di risorsa: 5 al primo, 3 al secondo, 1 al terzo; a parità il premio scala al
## piazzamento inferiore (due primi a pari merito prendono 3 ciascuno). Con zero risorse niente premio.
func res_prize(p: int, t: String) -> int:
	var mine: int = res[p][t]
	if mine <= 0:
		return 0
	var better := 0
	var same := 0
	for q in n:
		if res[q][t] > mine:
			better += 1
		elif res[q][t] == mine:
			same += 1
	var place := better + same - 1
	return SKData.RES_PRIZES[place] if place < SKData.RES_PRIZES.size() else 0


func objective_points(p: int, id: String) -> int:
	var o := SKData.objective(id)
	if o.is_empty():
		return 0
	if o["kind"] == "terr":
		var k := 0
		for t in o["r"]:
			if tile_index.has(t) and majority_auto(tile_index[t]) == p:
				k += 1
		return SKData.OBJ_TERR_PTS[k]
	match id:
		"pacificatore":
			return [0, 4, 8, 12][mini(3, peace_count())]
		"infiltrato":
			return [0, 4, 8, 12][mini(3, war_count())]
		"camerlengo":
			var k := 0
			for r in regions:
				k += int(r["infl"])
			return 2 * k
		"conquistatore":
			var k := 0
			for r in regions.size():
				k += count(r, p)
			return k / 2
		"cancelliere":
			return 2 * count(tile_index["capitale"], p)
		"politico":
			var k := 0
			for r in regions.size():
				if governor(r) == p:
					k += 1
			return [0, 3, 6, 9][mini(3, k)]
		"dittatore":
			for r in regions.size():
				if count(r, p) > 0 and count(r, p) + free_count(r) == regions[r]["sites"].size():
					return 10
			return 0
		"balivo":
			var k := 0
			for r in regions.size():
				k += count(r, INV)
			return k / 2
		"regina":
			var cap: int = tile_index["capitale"]
			return 10 if majority_auto(cap) == p and governor(cap) == p else 0
	return 0


## Vincitori istantanei (Nemico, Usurpatore), altrimenti [] .
func instant_winners() -> Array:
	var out := []
	var cap: int = tile_index["capitale"]
	for p in n:
		var id: String = objectives[p] if objectives.size() > p else ""
		if id == "nemico" and end_reason == "invasione" and majority_auto(cap) == p:
			out.append(p)
		elif id == "usurpatore" and end_reason == "guerre" and majority_auto(cap) == p:
			out.append(p)
	return out


## Classifica finale: [{p, tot, …}] in ordine. A parità vince chi ha la Corona.
func ranking() -> Array:
	var out := []
	var inst := instant_winners()
	for p in n:
		var d := score_detail(p)
		d["p"] = p
		d["instant"] = inst.has(p)
		out.append(d)
	out.sort_custom(func(a, b):
		if a["instant"] != b["instant"]:
			return a["instant"]
		if a["tot"] != b["tot"]:
			return a["tot"] > b["tot"]
		if (a["p"] == first) != (b["p"] == first):
			return a["p"] == first
		return a["p"] < b["p"])
	return out


## Impronta della partita (per verificare che due dispositivi online abbiano giocato la stessa).
func fingerprint() -> String:
	var s := str(turn) + "|" + str(first)
	for r in regions:
		s += "|" + str(r["sites"]) + str(r["econ"]) + str(r["infl"]) + str(r["bishop"]) + str(r["war"]) + str(r["peace"])
	s += str(chars) + str(res) + str(favor) + str(reserve)
	if alch():
		s += str(hand) + str(built) + str(deck.size()) + str(spent) + str(jolly)
	return s.md5_text()


# ------------------------------------------------------------------ variante dell'Alchimista
## Tutte le carte sono distribuite all'inizio. Con l'Alchimista (o con la maggioranza nel suo regno,
## nella passiva) si attiva una carta: si paga il costo in risorse, se ne risolve l'effetto e la si gira:
## da quel momento non ha più effetto e a fine partita vale i PV stampati.

## Artefatto girato (il suo effetto è permanente).
func has_art(p: int, id: String) -> bool:
	if p < 0 or p >= built.size():
		return false
	for b in built[p]:
		if b["id"] == id:
			return true
	return false


func proj_points(p: int) -> int:
	var k := 0
	for b in built[p]:
		k += int(SKData.PROJECTS[b["id"]]["pv"])
	return k


func ready_inventions(_p: int) -> Array:
	return []


## Si può pagare? Col Trasmutatore un'icona del costo si paga con una risorsa qualsiasi.
func can_afford(p: int, id: String, r_: Dictionary = {}) -> bool:
	var have: Dictionary = r_ if not r_.is_empty() else res[p]
	var cost: Dictionary = SKData.PROJECTS[id]["cost"]
	var miss := 0
	var tot_cost := 0
	var tot_have := 0
	for t in cost:
		miss += maxi(0, int(cost[t]) - int(have[t]))
		tot_cost += int(cost[t])
	for t in have:
		tot_have += int(have[t])
	if miss == 0:
		return true
	var spare := tot_have - (tot_cost - miss)
	var tras := mini(1, spare) if has_art(p, "A04") else 0
	return miss <= tras + (int(jolly[p]) if jolly.size() > p else 0)


## Paga il costo (con l'eventuale icona jolly del Trasmutatore: la risorsa di cui si ha di più).
func _pay(p: int, id: String) -> void:
	var cost: Dictionary = SKData.PROJECTS[id]["cost"]
	var wild := 0
	for t in cost:
		var k := int(cost[t])
		var own := mini(k, int(res[p][t]))
		res[p][t] -= own
		spent[t] += own
		wild += k - own
	var tras_left := 1 if has_art(p, "A04") else 0
	for w in wild:
		if tras_left <= 0:
			jolly[p] -= 1
			log_msg("%s paga un'icona con una risorsa jolly." % pname(p))
			continue
		var best := ""
		for t in SKData.RESOURCES:
			if int(res[p][t]) > 0 and (best == "" or int(res[p][t]) > int(res[p][best])):
				best = t
		if best == "":
			jolly[p] -= 1
			log_msg("%s paga un'icona con una risorsa jolly." % pname(p))
			continue
		tras_left -= 1
		if best != "":
			res[p][best] -= 1
			spent[best] += 1
			log_msg("Il Trasmutatore di %s paga un'icona con 1 %s." % [pname(p), SKData.RES_NAME[best]])


## Athanor: dopo un'attivazione si prende 1 risorsa dalle spese, quella che manca di più per le carte in mano.
func _athanor_gain(p: int) -> void:
	var need := {}
	for id in hand[p]:
		var cost: Dictionary = SKData.PROJECTS[id]["cost"]
		for t in cost:
			need[t] = int(need.get(t, 0)) + maxi(0, int(cost[t]) - int(res[p][t]))
	var best := ""
	for t in SKData.RESOURCES:
		if int(spent[t]) <= 0:
			continue
		if best == "" or int(need.get(t, 0)) > int(need.get(best, 0)):
			best = t
	if best == "":
		return
	spent[best] -= 1
	res[p][best] += 1
	log_msg("L'Athanor di %s produce 1 %s." % [pname(p), SKData.RES_NAME[best]])


func build_allowed(_p: int, _id: String) -> bool:
	return true


func can_activate_any(p: int) -> bool:
	for id in hand[p]:
		if can_afford(p, id):
			return true
	return false


func projects_possible(p: int) -> bool:
	return alch() and act_left[p] > 0 and can_activate_any(p)


## Valore di una carta da attivare (per l'IA).
func proj_value(p: int, id: String) -> float:
	var d: Dictionary = SKData.PROJECTS[id]
	var miss := 0
	for t in d["cost"]:
		miss += maxi(0, int(d["cost"][t]) - int(res[p][t]))
	return float(d["pv"]) + 0.8 - 0.9 * miss


func auto_athanor(_p: int) -> void:
	pass


func resolve_athanor(_p: int, _i: int) -> void:
	pass


## Attivazione: v = {b: carta, u: {bersagli dell'effetto}}. "" se va bene, altrimenti il motivo.
func check_projects(p: int, v: Dictionary) -> String:
	var c := clone()
	return c._do_projects(p, v)


func apply_projects(p: int, v: Dictionary) -> void:
	if check_projects(p, v) == "":
		_do_projects(p, v)


func _do_projects(p: int, v: Dictionary) -> String:
	var b: String = str(v.get("b", ""))
	var u: Dictionary = v.get("u", {})
	if b == "":
		return "scegli una carta"
	if not hand[p].has(b):
		return "carta non disponibile"
	if not can_afford(p, b):
		return "risorse insufficienti"
	var free := false
	var had_ath := has_art(p, "A01")
	_pay(p, b)
	hand[p].erase(b)
	built[p].append({"id": b, "used": true, "turn": turn})
	ev("build", {"p": p, "id": b})
	log_msg("%s attiva %s%s (+%d PV a fine partita)." % [pname(p), SKData.PROJECTS[b]["n"], " senza pagare (Athanor)" if free else "", int(SKData.PROJECTS[b]["pv"])])
	if not u.is_empty():
		u["id"] = b
		var e := _use_invention(p, b, u)
		if e != "":
			return e
	elif SKData.PROJECTS[b].get("auto", false):
		_use_invention(p, b, {"id": b})
	# l'Alchimista purifica: ogni carta attivata scaccia un invasore dal suo regno
	if opts.get("alch_slow", true):
		var ra: int = chars["mercante"]
		var ix: int = regions[ra]["sites"].rfind(INV)
		if ix >= 0:
			regions[ra]["sites"][ix] = -1
			inv_supply += 1
			ev("inv_out", {"r": ra, "i": ix})
			log_msg("L'Alchimista scaccia un invasore da %s." % rname(ra))
			if regions[ra]["war"] and not regions[ra]["sites"].has(INV):
				regions[ra]["war"] = false
				log_msg("La guerra in %s finisce." % rname(ra))
	if had_ath:
		ath_count[p] += 1
		if ath_count[p] % 2 == 0:
			_athanor_gain(p)
	return ""


func _use_invention(p: int, id: String, u: Dictionary) -> String:
	var nm: String = SKData.PROJECTS[id]["n"]
	match id:
		"I01", "I02", "I03", "I05":
			var r := int(u.get("r", -1))
			if r < 0 or r >= regions.size():
				return "scegli un regno"
			if regions[r]["war"] and id != "I02":
				return "non in un regno in guerra"
			if count(r, p) <= 0:
				return "serve un tuo villaggio nel regno"
			match id:
				"I01":
					if has_army(r):
						return "non dove c'è un esercito"
					var lf := lowest_free(r)
					if lf < 0 or reserve[p] <= 0:
						return "nessun sito libero o nessun villaggio in riserva"
					_put(r, lf, p)
					ev("place", {"r": r, "i": lf, "p": p})
					log_msg("%s: %s costruisce un villaggio in %s." % [nm, pname(p), rname(r)])
					_check_peace(r)
				"I02":
					var k2 := 0
					for z in 2:
						var idx: int = regions[r]["sites"].find(INV)
						if idx < 0:
							break
						regions[r]["sites"][idx] = -1
						inv_supply += 1
						k2 += 1
						ev("inv_out", {"r": r, "i": idx})
					if k2 == 0:
						return "nel regno non ci sono invasori"
					log_msg("%s: %d invasor%s lascia%s %s." % [nm, k2, "e" if k2 == 1 else "i", "" if k2 == 1 else "no", rname(r)])
					if regions[r]["war"] and not regions[r]["sites"].has(INV):
						regions[r]["war"] = false
						ev("peace_war", {"r": r})
						log_msg("La guerra in %s finisce." % rname(r))
				"I03":
					var d := int(u.get("d", 0))
					var e := int(regions[r]["econ"])
					if d == 1:
						if not _econ_up(r):
							return "la Ricchezza non può salire"
					elif d == -1:
						if e <= 1:
							return "la Ricchezza non scende sotto 1"
						regions[r]["econ"] = e - 1
						ev("econ", {"r": r})
					else:
						return "scegli +1 o -1"
					log_msg("%s: la Ricchezza di %s passa a %d." % [nm, rname(r), econ(r)])
				"I05":
					if u.get("add", true):
						if not can_influence(r):
							return "non c'è posto per l'influenza religiosa"
						_place_influence(r)
						log_msg("%s: un'influenza religiosa in più in %s." % [nm, rname(r)])
					else:
						if int(regions[r]["infl"]) <= 0:
							return "nel regno non c'è influenza religiosa"
						var k3 := 2 if opts.get("alch_incenso2", true) else 1
						for z in k3:
							if int(regions[r]["infl"]) <= 0:
								break
							regions[r]["infl"] -= 1
							infl_supply += 1
							ev("infl_out", {"r": r})
						log_msg("%s: l'influenza religiosa lascia %s e torna al Papa." % [nm, rname(r)])
		"A01", "A02", "A03", "A04":
			log_msg("%s: da ora il suo effetto è permanente per %s." % [nm, pname(p)])
		"I04":
			var c: String = str(u.get("c", ""))
			if not chars.has(c):
				return "scegli un personaggio"
			var from: int = chars[c]
			var to := int(u.get("to", -1))
			if not _steps_from(from, c, 1).has(to):
				return "passo non consentito"
			chars[c] = to
			ev("move", {"c": c, "path": [from, to]})
			log_msg("%s: %s porta %s in %s." % [nm, pname(p), SKData.cn(c), rname(to)])
		"I06":
			log_msg("%s: da ora il suo effetto è permanente per %s." % [nm, pname(p)])
		"I07":
			var q := int(u.get("q", -1))
			var t: String = str(u.get("t", ""))
			if q == p or q < 0 or q >= n or not res[q].has(t) or int(res[q][t]) <= 0:
				return "risorsa non disponibile"
			res[q][t] -= 1
			res[p][t] += 1
			ev("steal", {"from": q, "to": p, "res": [t]})
			log_msg("%s: %s prende 1 %s a %s." % [nm, pname(p), SKData.RES_NAME[t], pname(q)])
		"I08":
			var aa: Array = u.get("a", [])
			var bb: Array = u.get("b", [])
			if aa.size() != 2 or bb.size() != 2:
				return "scegli i due villaggi"
			var ra := int(aa[0])
			var ia := int(aa[1])
			var rb := int(bb[0])
			var ib := int(bb[1])
			if ra == rb or not land[ra].has(rb):
				return "i due regni devono essere collegati da un ponte"
			if ia == 0 or ib == 0:
				return "non i siti 1"
			if regions[ra]["sites"][ia] != p:
				return "il primo villaggio deve essere tuo"
			var pb: int = regions[rb]["sites"][ib]
			if pb < 0 or pb >= n or pb == p:
				return "il secondo villaggio deve essere di un avversario"
			regions[ra]["sites"][ia] = pb
			regions[rb]["sites"][ib] = p
			ev("swap", {"a": [ra, ia], "b": [rb, ib]})
			log_msg("%s: %s scambia un villaggio con %s." % [nm, pname(p), pname(pb)])
			_check_peace(ra)
			_check_peace(rb)
		_:
			return "carta sconosciuta"
	return ""


## Regni raggiungibili da un personaggio con 1 o 2 passi (la Cavalleria senza porti).
func _steps_from(from: int, c: String, k: int) -> Array:
	var out := []
	var sea_ok := c != "cavalleria"
	for a in neighbors(from, sea_ok):
		if not out.has(a):
			out.append(a)
		if k >= 2:
			for b in neighbors(a, sea_ok):
				if b != from and not out.has(b):
					out.append(b)
	return out


## Tutti gli effetti legali di una carta (per l'IA e per illuminare i bersagli). [] = nessun bersaglio
## (la carta si può comunque attivare per i PV, senza effetto); le carte senza bersaglio danno [{}].
func invention_uses(p: int, id: String) -> Array:
	var out := []
	match id:
		"I01", "I02", "I03", "I05":
			for r in regions.size():
				if (regions[r]["war"] and id != "I02") or count(r, p) <= 0:
					continue
				match id:
					"I01":
						if not has_army(r) and lowest_free(r) >= 0 and reserve[p] > 0:
							out.append({"id": id, "r": r})
					"I02":
						if regions[r]["sites"].has(INV):
							out.append({"id": id, "r": r})
					"I03":
						var e := int(regions[r]["econ"])
						if e < 5 and e + 1 <= 5 - int(regions[r]["infl"]):
							out.append({"id": id, "r": r, "d": 1})
						if e > 1:
							out.append({"id": id, "r": r, "d": -1})
					"I05":
						if can_influence(r):
							out.append({"id": id, "r": r, "add": true})
						if int(regions[r]["infl"]) > 0:
							out.append({"id": id, "r": r, "add": false})
		"I04":
			for c in SKData.CHARS:
				for to in _steps_from(chars[c], c, 1):
					out.append({"id": id, "c": c, "to": to})
		"I06", "A01", "A02", "A03", "A04":
			out.append({"id": id, "x": 1})
		"I07":
			for q in n:
				if q == p:
					continue
				for t in SKData.RESOURCES:
					if int(res[q][t]) > 0:
						out.append({"id": id, "q": q, "t": t})
		"I08":
			for ra in regions.size():
				for ia in range(1, regions[ra]["sites"].size()):
					if regions[ra]["sites"][ia] != p:
						continue
					for rb in land[ra]:
						for ib in range(1, regions[rb]["sites"].size()):
							var pb: int = regions[rb]["sites"][ib]
							if pb >= 0 and pb < n and pb != p:
								out.append({"id": id, "a": [ra, ia], "b": [rb, ib]})
	return out
