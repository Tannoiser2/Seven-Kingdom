class_name SKEngine
extends Node
## Motore di una partita di Seven Kingdom: fa girare i turni sullo stato (SKState) e chiede ogni
## decisione con ask(). L'IA risponde subito; per le persone si emette decision_requested e si
## attende provide_decision(); online le decisioni passano dal registro delle mosse (OnlineSession).

signal changed
signal log_added(text: String)
signal decision_requested(req: Dictionary)
signal decision_provided(result)
signal game_ended(results: Array)
signal phase_changed(phase: String)

const MAX_TURNS := 60

var st: SKState
var players: Array = []        # [{name, ai, level}]
var ais := {}
var online = null
var ai_delay := 0.0
var headless := false
var abort := false
var config := {}
var phase := ""
var cur := -1
var results: Array = []
var _log_seen := 0


func setup(cfg: Dictionary) -> void:
	config = cfg
	players = cfg["players"]
	ai_delay = float(cfg.get("ai_delay", 0.0))
	headless = cfg.get("headless", false)
	st = SKState.new()
	var names := []
	for p in players:
		names.append(p["name"])
	var sc: Dictionary = cfg.get("scenario", SKData.SCENARIOS[0])
	st.setup(names, sc, cfg.get("opts", {}), int(cfg.get("seed", 1)))
	for i in players.size():
		ais[i] = SKAI.new(players[i].get("level", 1), int(cfg.get("seed", 1)) * 31 + i)


func pname(p: int) -> String:
	return st.pname(p)


func flush_log() -> void:
	while _log_seen < st.log_lines.size():
		log_added.emit(st.log_lines[_log_seen])
		_log_seen += 1


func log_msg(t: String) -> void:
	st.log_msg(t)
	flush_log()


func ask(p: int, req: Dictionary):
	req["seat"] = p
	flush_log()
	changed.emit()
	if abort:
		return ais[p].decide(self, p, req)
	if online != null:
		return await online.decide(self, p, req)
	if players[p]["ai"]:
		if ai_delay > 0.0 and not headless and is_inside_tree():
			await get_tree().create_timer(ai_delay).timeout
		return ais[p].decide(self, p, req)
	decision_requested.emit(req)
	var r = await decision_provided
	return r


func provide_decision(r) -> void:
	decision_provided.emit(r)


func _set_phase(ph: String) -> void:
	phase = ph
	phase_changed.emit(ph)
	changed.emit()


# ------------------------------------------------------------------ partita

func run() -> void:
	var n := players.size()
	log_msg("Comincia la partita di Seven Kingdom: %s." % st.scen.get("n", "mappa"))
	# obiettivi segreti
	if st.opts.get("objectives", false):
		_set_phase("obiettivi")
		var deck := []
		for o in SKData.OBJECTIVES:
			if o["kind"] == "terr":
				var ok := true
				for t in o["r"]:
					if not st.tile_index.has(t):
						ok = false
				if not ok:
					continue
			deck.append(o["id"])
		st._shuffle(deck)
		for p in n:
			var opts3 := [deck.pop_back(), deck.pop_back(), deck.pop_back()]
			var i = await ask(p, {"type": "objective", "options": opts3})
			i = clampi(int(i), 0, 2)
			st.objectives[p] = opts3[i]
		log_msg("Ognuno ha scelto in segreto la sua carta obiettivo.")
	# piazzamento iniziale: tre giri, dal Primo Giocatore in senso orario
	_set_phase("preparazione")
	for rnd in SKData.START_PLACEMENTS:
		for k in n:
			var p := (st.first + k) % n
			cur = p
			var r = await ask(p, {"type": "setup", "round": rnd})
			r = int(r)
			if not st.setup_regions().has(r):
				r = st.setup_regions()[0]
			st.setup_place(p, r)
			flush_log()
			changed.emit()
	var last := (st.first + n - 1) % n
	st.favor[last] = true
	log_msg("%s, ultimo a giocare, riceve un Favore Papale." % pname(last))
	# turni
	while not st.game_over:
		await play_turn()
		if st.turn >= MAX_TURNS and not st.game_over:
			st.game_over = true
			st.end_reason = "limite"
	cur = -1
	_set_phase("fine")
	log_msg("FINE DELLA PARTITA: " + SKState.END_TEXT.get(st.end_reason, ""))
	results = st.ranking()
	for d in results:
		log_msg("%s: %d punti%s" % [pname(d["p"]), d["tot"], " — vittoria per obiettivo!" if d["instant"] else ""])
	flush_log()
	changed.emit()
	game_ended.emit(results)


func play_turn() -> void:
	var n := players.size()
	_set_phase("azioni")
	log_msg("— Turno %d — Primo Giocatore: %s" % [st.turn + 1, pname(st.first)])
	var start := st.first
	for k in n:
		var p := (start + k) % n
		cur = p
		var tries := 0
		while true:
			var m = await ask(p, {"type": "turn"})
			if m is Dictionary and st.check_move(p, m) == "":
				st.apply_move(p, m)
				break
			tries += 1
			if tries >= 3 or players[p]["ai"] or online != null:
				var fb = ais[p].fallback(self, p)
				st.apply_move(p, fb)
				break
			log_msg("(mossa non consentita: %s)" % st.check_move(p, m if m is Dictionary else {}))
		flush_log()
		changed.emit()
	cur = -1
	_set_phase("passive")
	log_msg("Azioni passive dei personaggi.")
	await st.passive_phase(self)
	flush_log()
	changed.emit()
	_set_phase("fine turno")
	st.end_phase()
	flush_log()
	changed.emit()


# ------------------------------------------------------------------ scelte durante le fasi passive

func tie(g: int, tied: Array, r: int, why: String):
	cur = g
	return await ask(g, {"type": "tie", "tied": tied, "r": r, "why": why})


func crown(p: int):
	cur = p
	return await ask(p, {"type": "crown"})


func battle_favor(p: int, r: int):
	cur = p
	return await ask(p, {"type": "battle_favor", "r": r})


func battle_gov(g: int, p: int, r: int):
	cur = g
	return await ask(g, {"type": "battle_gov", "p": p, "r": r})


## Impronta della partita (per le prove online).
func fingerprint() -> String:
	return st.fingerprint()
