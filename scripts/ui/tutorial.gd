class_name SKTutorial
extends Control
## Tutorial: una partita di prova guidata. Una pergamena «del maestro» spiega la mappa prima di
## cominciare, poi accompagna la partita: il piazzamento, un personaggio alla volta (la prima volta
## che si gioca ognuno dei sei la scelta è guidata), le azioni passive, la fine del turno, guerre,
## pace, battaglie e infine il punteggio. Gli avversari sono due IA facili; si gioca a mano libera
## dopo che tutti i personaggi sono stati presentati.

signal closed

var gv
var card: PanelContainer
var title_lbl: Label
var body: RichTextLabel
var btn: Button
var skip_btn: Button
var showing := false
var seen := {}
var queue: Array = []
var lock_char := ""
var guided := ""
var last_step := ""
var explained: Array = []
var done := false
var pending_hint: Array = []

const ORDER := ["re", "papa", "mercante", "spia", "fanteria", "cavalleria"]

const CHAR_LESSON := {
	"re": ["Il Re", "Il Re fa crescere i casati: [b]mette villaggi[/b].\n• [b]Normale[/b]: 2 villaggi nel regno dove arriva e 1 in un regno adiacente, sempre sui siti liberi più bassi. Se ne metti due o più, almeno uno deve essere di un [b]altro casato[/b]: scegli tu chi aiutare (tocca il suo riquadro a sinistra).\n• [b]Passiva[/b]: a fine turno chi ha la maggioranza nel regno del Re prende la [b]Corona[/b] e diventa Primo Giocatore."],
	"papa": ["Il Papa", "Il Papa porta l'[b]influenza religiosa[/b]: copre il numero più alto libero della Ricchezza di un regno (il suo o uno adiacente). È un'arma a doppio taglio: abbassa ciò che vale il Governatore, ma rende preziosi i [b]Vescovi[/b] (2 punti + 2 per influenza).\n• [b]Potenziata[/b]: in più nomini un tuo Vescovo in una Cattedrale libera.\n• [b]Passiva[/b]: chi ha la maggioranza nel regno del Papa riceve il [b]Favore Papale[/b], che serve per le azioni potenziate."],
	"mercante": ["Il Mercante", "Il Mercante muove l'economia.\n• [b]Normale[/b]: ruba 1 risorsa a un avversario (tocca la fila della risorsa nel suo riquadro, a sinistra). Le risorse valgono a fine partita: 5, 3 e 1 punti a chi ne ha di più di ogni tipo.\n• [b]Passiva[/b]: la [b]Ricchezza[/b] del regno dove si trova sale di uno. Portalo dove hai tanti villaggi!"],
	"spia": ["La Spia", "La Spia semina zizzania.\n• [b]Normale[/b]: scambia un villaggio del suo regno con uno di un regno adiacente (non i Governatori). Così puoi rubare una maggioranza!\n• [b]Passiva[/b]: a fine turno porta un [b]invasore[/b] nel suo regno, sul sito libero più alto. Se il regno è pieno l'invasore scaccia un villaggio e scoppia la [b]Guerra[/b]. Puoi anche scegliere di non scambiare nulla."],
	"fanteria": ["La Fanteria", "Gli eserciti liberano i regni.\n• [b]Normale[/b]: nel regno dove arriva scaccia 1 invasore e al suo posto costruisce un tuo villaggio (sul sito libero più basso). Se non ci sono invasori, puoi usarla solo per spostarla.\n• Se il regno è in [b]Guerra[/b] dichiara battaglia (+1 all'attacco con la Fanteria).\n• Dove c'è un esercito il Re non può mettere villaggi."],
	"cavalleria": ["La Cavalleria", "La Cavalleria è l'esercito veloce: si muove di [b]1 o 2 regni[/b] (senza tornare indietro e senza usare i porti), poi agisce come la Fanteria: scaccia un invasore e costruisce un tuo villaggio, oppure dichiara battaglia in un regno in Guerra."],
}

const OF := {"re": "del Re", "papa": "del Papa", "mercante": "del Mercante", "spia": "della Spia", "fanteria": "della Fanteria", "cavalleria": "della Cavalleria"}

const STEP_HINT := {
	"dest": "Le [b]frecce dorate[/b] indicano dove può andare: un regno collegato da un ponte, oppure via mare da un porto all'altro. Tocca il regno di arrivo: il personaggio ci va subito (con «Annulla» torni indietro).",
	"king": "Si illumina il sito dove va il prossimo villaggio (sempre il più basso libero). Tocca i siti illuminati; il colore del villaggio è quello del riquadro evidenziato a sinistra. Poi «Conferma».",
	"king_pw": "Con la potenziata i villaggi vanno subito dopo il Governatore e gli altri scalano. Tocca i siti illuminati, poi «Conferma».",
	"pope_t": "Tocca la casella illuminata della Ricchezza: lì andrà l'influenza religiosa.",
	"pope_b": "Tocca la Cattedrale (Luogo Sacro) dove nomini il tuo Vescovo.",
	"merch": "Tocca la fila di una risorsa nel riquadro di un avversario, a sinistra: la ruberai.",
	"spy_a": "Tocca un villaggio illuminato nel regno della Spia (oppure «Nessuno scambio»).",
	"spy_b": "Ora tocca il villaggio con cui scambiarlo, in un regno collegato da un ponte.",
	"confirm": "Controlla il riepilogo sotto e tocca «Conferma». Ogni turno ogni personaggio si usa una volta sola: chi gioca dopo sceglie fra quelli rimasti.",
}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.parchment(20))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	vb.add_child(hb)
	hb.add_child(UI.icon("res://assets/tokens/corona.webp", 40))
	title_lbl = UI.title("", 24, UI.INK)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(title_lbl)
	body = UI.rich(18, UI.INK)
	body.custom_minimum_size = Vector2(540, 0)
	vb.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(row)
	skip_btn = UI.button("Chiudi il tutorial", 200, 42, 14)
	skip_btn.pressed.connect(_stop)
	row.add_child(skip_btn)
	btn = UI.primary(UI.button("Avanti", 160, 42, 18))
	btn.pressed.connect(_close)
	row.add_child(btn)
	card.visible = false
	get_viewport().size_changed.connect(_place)


func _place() -> void:
	var vp := get_viewport_rect().size
	card.reset_size()
	# in basso a sinistra, sul mare: lascia libere le tessere al centro
	card.position = Vector2(gv.LW + 18.0, vp.y - card.size.y - 78.0)


## Mostra la pergamena. Con want_button=false resta aperta senza bottone (la si chiude con hide_card).
func show_card(t: String, text: String, want_button := true, button_text := "Avanti") -> void:
	# un suggerimento non copre una lezione aperta: aspetta che la si chiuda
	if not want_button and showing:
		pending_hint = [t, text]
		return
	if want_button:
		pending_hint = []
	title_lbl.text = t
	body.text = ""
	body.append_text(text)
	btn.visible = want_button
	btn.text = button_text
	card.visible = true
	showing = want_button
	Audio.play("bell", -10.0)
	_place()
	_place.call_deferred()


func hide_card() -> void:
	card.visible = false
	showing = false


func _close() -> void:
	hide_card()
	closed.emit()
	if not showing and not pending_hint.is_empty() and not done:
		var h: Array = pending_hint
		pending_hint = []
		show_card(h[0], h[1], false)


func _stop() -> void:
	done = true
	lock_char = ""
	queue.clear()
	hide_card()
	closed.emit()
	gv.tutorial = null
	gv._build_prompt()
	queue_free()


func _lesson(t: String, text: String, regs := [], sites := [], pts := []) -> void:
	if done:
		return
	gv.board.set_highlight(regs, sites, pts)
	show_card(t, text)
	await closed
	if is_instance_valid(gv) and is_instance_valid(gv.board):
		gv.board.set_highlight([], [])


# ------------------------------------------------------------------ introduzione

func intro() -> void:
	var st: SKState = gv.engine.st
	var cap := 0
	for r in st.regions.size():
		if st.regions[r]["tile"] == "capitale":
			cap = r
	await _lesson("Benvenuto in Seven Kingdom", "Questa è una [b]partita di prova[/b] contro due avversari dell'IA (facili). Ti spiego le regole mentre giochi: segui questa pergamena e tocca «Avanti».\n\nSei il [b]Casato Rosso[/b]. Vince chi ha più [b]punti vittoria[/b] (PV) alla fine: li danno i villaggi, i Governatori, i Vescovi, le risorse, la Corona e il Favore Papale.")
	if done:
		return
	var all := []
	for r in st.regions.size():
		all.append(r)
	await _lesson("La mappa: i sette regni", "Sette regni su un mare. I [b]ponti[/b] collegano i regni adiacenti; le quattro [b]carte porto[/b] sulle coste collegano due regni via mare (servono solo per muovere i personaggi).\n\nLa cornice colorata di un regno mostra [b]chi vi ha la maggioranza[/b] di villaggi. Tasto destro su un regno per vederne i dettagli.", all)
	if done:
		return
	var sts := []
	for i in st.regions[cap]["sites"].size():
		sts.append([cap, i])
	await _lesson("I siti e il Governatore", "Ogni regno ha una fila di [b]siti numerati[/b] (qui la Capitale ne ha 9). I villaggi si costruiscono dal sito più basso; gli invasori arrivano dal più alto.\n\nIl [b]sito 1[/b], con la corona, è quello del [b]Governatore[/b] (in 3D è il palazzo): vale di più e, in caso di parità di villaggi, decide lui chi ha la maggioranza.", [cap], sts)
	if done:
		return
	var pts := []
	for k in 5:
		pts.append(gv.board.wealth_pos(cap, k + 1))
	await _lesson("Ricchezza e Cattedrale", "La traccia della [b]Ricchezza[/b] (1–5) dice quanto vale ogni villaggio del regno; il Governatore vale il numero più alto non coperto dall'[b]influenza religiosa[/b] del Papa.\n\nIl [b]Luogo Sacro[/b] (Cattedrale) ospita un Vescovo: vale 2 PV più 2 per ogni influenza religiosa del regno.", [cap], [], pts + [gv.board.bishop_pos(cap)])
	if done:
		return
	await _lesson("Le risorse", "Su ogni sito libero c'è una [b]risorsa[/b] (legno, pietra, grano, ferro, oro). Chi costruisce un villaggio su quel sito la prende; gli invasori la distruggono.\n\nLe tue risorse sono nel tuo riquadro a sinistra, una fila per tipo. A fine partita, per ogni tipo, chi ne ha di più prende 5 PV, il secondo 3, il terzo 1.")
	if done:
		return
	await _lesson("I sei personaggi", "A destra ci sono i [b]sei personaggi[/b]: Re, Papa, Mercante, Spia, Fanteria e Cavalleria. Nessuno appartiene a un casato: a turno ognuno ne sceglie uno ancora libero, lo [b]sposta[/b] di un regno e ne fa l'azione.\n\nAccanto al ritratto trovi l'azione [b]Normale[/b], la [b]Potenziata ✦[/b] (costa il Favore Papale) e la [b]Passiva[/b], che avviene da sola a fine turno nel regno dove il personaggio si trova.")


# ------------------------------------------------------------------ durante la partita

## Chiamata quando la partita chiede una decisione alla persona.
func on_decision(req: Dictionary) -> void:
	if done:
		return
	match req["type"]:
		"setup":
			if not seen.has("setup"):
				seen["setup"] = true
				show_card("Il piazzamento iniziale", "Ognuno mette a turno [b]3 villaggi[/b]. Tocca uno dei siti illuminati: ci metti un tuo villaggio e [b]prendi la risorsa[/b] che c'era.\n\nConsiglio: punta ai regni dove puoi diventare [b]Governatore[/b] (sito 1) e cerca risorse diverse.", false)
		"turn":
			await _show_queue()
			_turn_lesson()
		"crown":
			show_card("La Corona", "Hai la maggioranza nel regno del Re: decidi tu a chi va la [b]Corona[/b]. Chi la ha gioca per primo il turno dopo, ha +1 in battaglia e a fine partita vale 2 PV. Tenerla di solito conviene!", false)
		"tie":
			show_card("Parità", "C'è parità di villaggi in un regno e tu sei il [b]Governatore[/b]: decidi tu chi ha la maggioranza.", false)
		"battle_favor":
			show_card("La battaglia", "Puoi spendere il Favore Papale per avere [b]+1[/b] all'attacco. L'attacco è: tuoi villaggi nel regno, +1 Corona, +1 Fanteria, +1 Favore, +1 se il Governatore ti aiuta. Vinci se è almeno pari al numero di invasori.", false)


func _turn_lesson() -> void:
	var st: SKState = gv.engine.st
	lock_char = ""
	for c in ORDER:
		if not explained.has(c) and not st.used.has(c):
			lock_char = c
			break
	if lock_char == "":
		if not seen.has("free"):
			seen["free"] = true
			await _lesson("Ora tocca a te", "Hai conosciuto tutti e sei i personaggi. Da qui in avanti gioca liberamente: pensa a [b]dove[/b] lasciare ogni personaggio, perché la sua azione passiva avverrà lì a fine turno, e a quali personaggi lasci agli avversari.\n\nIl tutorial ti avviserà ancora quando succede qualcosa di nuovo (guerre, regni pacificati, battaglie, fine partita).")
		return
	explained.append(lock_char)
	guided = lock_char
	last_step = ""
	var l: Array = CHAR_LESSON[lock_char]
	var extra := ""
	if st.favor[gv._me()]:
		extra = "\n\nHai il [b]Favore Papale[/b]: puoi toccare «Potenziata ✦» per l'azione più forte (il Favore si consuma)."
	show_card("Scegli: " + l[0], l[1] + "\n\n[color=#7a1a1a][b]Tocca «Normale» accanto al ritratto %s, a destra.[/b][/color]%s" % [OF[lock_char], extra], false)


## Chiamata da game_view dopo che il passo della mossa è cambiato.
func on_step(step: String) -> void:
	if done or gv.pending.get("type", "") != "turn":
		return
	if not gv.sel.has("c"):
		return
	var c: String = gv.sel["c"]
	if c != guided or step == last_step:
		return
	last_step = step
	var name: String = CHAR_LESSON[c][0]
	if STEP_HINT.has(step):
		var t: String = STEP_HINT[step]
		if step == "confirm" and c in ["fanteria", "cavalleria"] and not gv.engine.st.regions[gv._dest()]["war"]:
			t = "Se nel regno c'è un invasore, l'esercito lo scaccia e costruisce un tuo villaggio; altrimenti si è solo spostato. Tocca «Conferma»."
		show_card(name, t, false)


## Il personaggio che il tutorial chiede di scegliere ("" = libero).
func allowed(c: String) -> bool:
	return done or lock_char == "" or c == lock_char


func after_provide() -> void:
	lock_char = ""
	guided = ""
	last_step = ""
	pending_hint = []
	if not showing:
		hide_card()


## Chiamata dalla barra di stato (mosse degli altri, fasi passive, fine turno).
## Restituisce true se la lezione ha già fatto da «Avanti».
func on_pause(kind: String) -> bool:
	if done:
		return false
	var shown := false
	if kind == "move" and not seen.has("ai_move"):
		seen["ai_move"] = true
		await _lesson("Le mosse degli avversari", "Quando muove un avversario la partita si ferma: nella [b]barra in alto[/b] leggi cosa ha fatto e sulla mappa si illuminano i regni toccati. Tocca «Avanti» per proseguire.\n\nIl tasto «Automatico» fa andare avanti da solo: utile quando conosci il gioco.")
		shown = true
	elif kind == "passive" and not seen.has("passive"):
		seen["passive"] = true
		await _lesson("Le azioni passive", "Tutti hanno scelto: ora i personaggi agiscono [b]da soli[/b], nell'ordine Re, Papa, Mercante, Spia, eserciti, nel regno dove sono stati lasciati:\n• Re → la [b]Corona[/b] a chi ha la maggioranza;\n• Papa → il [b]Favore Papale[/b] a chi ha la maggioranza;\n• Mercante → la Ricchezza sale;\n• Spia → arriva un invasore;\n• eserciti → si combattono le battaglie dichiarate.")
		shown = true
	elif kind == "end" and not seen.has("end"):
		seen["end"] = true
		await _lesson("La fine del turno", "A fine turno: ogni Guerra abbassa la Ricchezza del suo regno; poi c'è l'[b]invasione[/b]: ogni regno [b]senza personaggi[/b], non pacificato e non in guerra, riceve un invasore.\n\nLa partita finisce quando ci sono 3 Guerre, 3 regni pacificati, un regno pieno di invasori, una Ricchezza tutta coperta dall'influenza o il Papa senza influenze.")
		shown = true
	if await _show_queue():
		shown = true
	return shown


## Chiamata con gli eventi nuovi della partita: prepara le lezioni su ciò che succede la prima volta.
func on_events(evs: Array) -> void:
	if done:
		return
	for e in evs:
		match e["k"]:
			"war":
				_enqueue("war", "Guerra!", "Un invasore doveva entrare in un regno senza siti liberi: è scoppiata la [b]Guerra[/b] (le spade sopra il regno). Lì non si possono fare le azioni di Re, Papa ed eserciti, e ogni fine turno la Ricchezza scende.\n\nPer liberarlo porta un esercito e dichiara [b]battaglia[/b]: se vinci scacci tutti gli invasori e diventi Governatore.", [int(e["r"])])
			"peace":
				_enqueue("peace", "Un regno pacificato", "Tutti i siti del regno sono occupati da villaggi: il regno è [b]pacificato[/b] per sempre (il sole e le colombe). La Spia e le invasioni non hanno più effetto lì. Tre regni pacificati fanno finire la partita.", [int(e["r"])])
			"battle":
				_enqueue("battle", "Una battaglia", "Si è combattuta una battaglia: l'attacco (villaggi nel regno +1 Corona, +1 Fanteria, +1 Favore, +1 aiuto del Governatore) contro il numero di invasori. Chi vince scaccia gli invasori e mette un suo villaggio come Governatore; chi perde vede un invasore prendere il posto di un villaggio.", [int(e["r"])])
			"inv":
				if not e.has("kill"):
					_enqueue("inv", "Gli invasori", "Un [b]invasore[/b] (il villaggio scuro con la palizzata) occupa un sito e distrugge la risorsa. Gli invasori non hanno maggioranza, ma tolgono spazio: Fanteria e Cavalleria li scacciano.", [int(e["r"])])
			"favor":
				_enqueue("favor", "Il Favore Papale", "Qualcuno ha ricevuto il [b]Favore Papale[/b] (il medaglione nel riquadro). Permette un'azione potenziata ✦, dà +1 in battaglia e, se lo tieni fino alla fine, vale 2 PV.", [])


func _enqueue(key: String, t: String, text: String, regs: Array) -> void:
	if seen.has(key):
		return
	seen[key] = true
	queue.append([t, text, regs])


func _show_queue() -> bool:
	var any := false
	while not queue.is_empty() and not done:
		var q: Array = queue.pop_front()
		await _lesson(q[0], q[1], q[2])
		any = true
	return any


func on_end() -> void:
	if done:
		return
	await _show_queue()
	show_card("Il punteggio", "La partita è finita! Ogni [b]villaggio[/b] vale la Ricchezza del suo regno, ogni [b]Governatore[/b] il numero più alto della Ricchezza non coperto dall'influenza religiosa, ogni [b]Vescovo[/b] 2 + 2 per influenza. Poi Corona e Favore (2 PV ciascuno) e le maggioranze di risorse (5/3/1 per tipo).\n\nOra conosci Seven Kingdom: dal menu puoi giocare contro IA più forti, aggiungere le carte obiettivo o sfidare gli amici online. Buon divertimento!", true, "Fine")
	await closed
