class_name SKData
extends RefCounted
## Dati di Seven Kingdom: regni (tessere), personaggi, colori, risorse, scenari della mappa e carte obiettivo.
## Gioco originale di Stefano & Simone Ancillai.

# ------------------------------------------------------------------ giocatori

const COLORS := [
	{"id": "rosso", "n": "Rosso", "col": Color("#b3261e"), "light": Color("#e0574a"), "sym": "Corona"},
	{"id": "blu", "n": "Blu", "col": Color("#1f4fa8"), "light": Color("#4f7fd6"), "sym": "Torre"},
	{"id": "verde", "n": "Verde", "col": Color("#2f7a36"), "light": Color("#5aa55e"), "sym": "Quercia"},
	{"id": "giallo", "n": "Giallo", "col": Color("#d7a21c"), "light": Color("#f0c54a"), "sym": "Sole"},
]
const INVADER_COLOR := Color("#1c1a19")

const VILLAGES_PER_PLAYER := 20
const BISHOPS_PER_PLAYER := 7
const INVADERS := 30
const INFLUENCE := 9
const FAVORS := 4
const WAR_MARKERS := 5
const PEACE_MARKERS := 4
const START_PLACEMENTS := 3

# ------------------------------------------------------------------ risorse (da Seven Planet)

const RESOURCES := ["legno", "pietra", "grano", "ferro", "oro"]
const RES_NAME := {"legno": "Legno", "pietra": "Pietra", "grano": "Grano", "ferro": "Ferro", "oro": "Oro"}
const RES_COLOR := {"legno": Color("#9a5b2c"), "pietra": Color("#9a9a96"), "grano": Color("#d9b048"), "ferro": Color("#5b5f66"), "oro": Color("#e8b92f")}
## 45 risorse (9 per tipo): coprono tutti i 45 siti dei sette regni.
const RES_PER_TYPE := 9
## Punti di fine partita per ogni tipo di risorsa: primo, secondo, terzo.
const RES_PRIZES := [5, 3, 1]

# ------------------------------------------------------------------ regni (tessere)
## sites: centri dei riquadri numerati sull'immagine della tessera (1342×1172), nell'ordine 1, 2, 3…
## Il sito 1 (con la corona) è quello del Governatore. bishop: cerchio del Vescovo.
## wealth: i cinque cerchi della traccia Ricchezza.

const TILE_W := 1342.0
const TILE_H := 1172.0
const WEALTH_X := [482, 575, 670, 764, 858]
const WEALTH_Y := 118

const TILES := {
	"capitale": {"wealth": [434, 551, 671, 788, 905], "n": "Capitale", "short": "Capitale", "img": "res://assets/tiles/capitale.webp",
		"sites": [[671, 585], [506, 367], [764, 366], [1014, 476], [988, 735], [804, 913], [537, 897], [316, 723], [305, 476]],
		"bishop": [484, 647], "col": Color("#8a9a4a"), "relief": 0.5},
	"boschivo": {"wealth": [434, 551, 671, 788, 905], "n": "Regno Boschivo", "short": "Boschivo", "img": "res://assets/tiles/boschivo.webp",
		"sites": [[670, 584], [505, 361], [805, 362], [1021, 550], [913, 795], [616, 899], [313, 717]],
		"bishop": [473, 613], "col": Color("#3f6b2c"), "relief": 0.6},
	"fluviale": {"wealth": [434, 551, 671, 788, 905], "n": "Regno Fluviale", "short": "Fluviale", "img": "res://assets/tiles/fluviale.webp",
		"sites": [[682, 596], [490, 384], [790, 384], [1005, 580], [870, 860], [578, 906], [322, 740]],
		"bishop": [474, 628], "col": Color("#4f8a52"), "relief": 0.3},
	"montano": {"wealth": [434, 551, 671, 788, 905], "n": "Regno Montano", "short": "Montano", "img": "res://assets/tiles/montano.webp",
		"sites": [[672, 592], [494, 375], [847, 375], [1012, 681], [673, 916], [330, 680]],
		"bishop": [492, 649], "col": Color("#7c7f78"), "relief": 1.0},
	"autunnale": {"wealth": [434, 551, 671, 788, 905], "n": "Regno Autunnale", "short": "Autunnale", "img": "res://assets/tiles/autunnale.webp",
		"sites": [[672, 580], [506, 373], [834, 373], [992, 580], [666, 889], [325, 729]],
		"bishop": [487, 642], "col": Color("#b0582a"), "relief": 0.5},
	"collinare": {"wealth": [434, 551, 671, 788, 905], "n": "Regno Collinare", "short": "Collinare", "img": "res://assets/tiles/collinare.webp",
		"sites": [[677, 603], [509, 376], [837, 375], [857, 865], [464, 865]],
		"bishop": [481, 642], "col": Color("#b39a45"), "relief": 0.7},
	"palustre": {"wealth": [434, 551, 671, 788, 905], "n": "Regno Palustre", "short": "Palustre", "img": "res://assets/tiles/palustre.webp",
		"sites": [[670, 609], [448, 378], [894, 378], [893, 861], [447, 861]],
		"bishop": [428, 623], "col": Color("#5f8a6a"), "relief": 0.15},
}
const TILE_ORDER := ["capitale", "boschivo", "fluviale", "montano", "autunnale", "collinare", "palustre"]

# ------------------------------------------------------------------ tabellone del mare
## 10 posizioni esagonali (esagoni con il lato in alto): colonna sinistra 0-2, centrale 3-6, destra 7-9.
## Lati di un esagono: 0 Nord, 1 Nord-Est, 2 Sud-Est, 3 Sud, 4 Sud-Ovest, 5 Nord-Ovest.

const POS_COL := [0, 0, 0, 1, 1, 1, 1, 2, 2, 2]
const POS_ROW := [0, 1, 2, 0, 1, 2, 3, 0, 1, 2]
const EDGE_NAMES := ["Nord", "Nord-Est", "Sud-Est", "Sud", "Sud-Ovest", "Nord-Ovest"]


static func pos_of(col: int, row: int) -> int:
	for i in 10:
		if POS_COL[i] == col and POS_ROW[i] == row:
			return i
	return -1


## Posizione vicina sul lato e (oppure -1 se fuori dal tabellone).
static func neighbor(pos: int, e: int) -> int:
	var c: int = POS_COL[pos]
	var r: int = POS_ROW[pos]
	match e:
		0: return pos_of(c, r - 1)
		3: return pos_of(c, r + 1)
	if c == 1:
		# colonna centrale (4 esagoni): a destra e a sinistra le colonne da 3, sfalsate di mezzo esagono
		match e:
			1: return pos_of(2, r - 1)
			2: return pos_of(2, r)
			5: return pos_of(0, r - 1)
			4: return pos_of(0, r)
	else:
		match e:
			1: return pos_of(1, r) if c == 0 else -1
			2: return pos_of(1, r + 1) if c == 0 else -1
			5: return pos_of(1, r) if c == 2 else -1
			4: return pos_of(1, r + 1) if c == 2 else -1
	return -1


## Lato di a che tocca b (oppure -1).
static func edge_between(a: int, b: int) -> int:
	for e in 6:
		if neighbor(a, e) == b:
			return e
	return -1


## Centro di una posizione, in unità di esagono (raggio 1).
static func pos_center(pos: int) -> Vector2:
	var c: int = POS_COL[pos]
	var r: int = POS_ROW[pos]
	var x := (c - 1) * 1.5
	var y := r * sqrt(3.0)
	if c != 1:
		y += sqrt(3.0) / 2.0
	return Vector2(x, y - sqrt(3.0) * 1.5)


## Punto medio del lato e (unità di esagono), relativo al centro.
static func edge_mid(e: int) -> Vector2:
	var a := deg_to_rad(-90.0 + 60.0 * e)
	return Vector2(cos(a), sin(a)) * (sqrt(3.0) / 2.0)


# ------------------------------------------------------------------ porti

const PORT_NAMES := {
	"alba": {"n": "Porto Alba", "pair": "I", "img": "res://assets/tokens/porto_alba.webp"},
	"vespro": {"n": "Porto Vespro", "pair": "I", "img": "res://assets/tokens/porto_vespro.webp"},
	"rupe": {"n": "Porto della Rupe", "pair": "II", "img": "res://assets/tokens/porto_rupe.webp"},
	"bruma": {"n": "Porto Bruma", "pair": "II", "img": "res://assets/tokens/porto_bruma.webp"},
}

# ------------------------------------------------------------------ scenari
## tiles: posizione -> regno. bridges: coppie di posizioni (11 ponti). ports: 4 porti in due coppie,
## ciascuno su un lato esterno. start: regno di partenza dei personaggi.
## Lo scenario base riproduce la mappa del gioco originale: quattro regni a sinistra (colonna centrale),
## tre a destra con la Capitale nel mezzo, i porti che collegano Nord e Sud su ciascun lato.

const SCENARIOS := [
	{
		"id": "base", "n": "Il Regno dei Sette", "desc": "La mappa del gioco originale: quattro regni a ponente lungo il fiume, la Capitale e due regni a levante. I porti uniscono il Nord al Sud lungo le due coste.",
		"tiles": {3: "montano", 4: "fluviale", 5: "autunnale", 6: "palustre", 7: "boschivo", 8: "capitale", 9: "collinare"},
		"bridges": [[3, 4], [4, 5], [5, 6], [7, 8], [8, 9], [3, 7], [4, 7], [4, 8], [5, 8], [5, 9], [6, 9]],
		"ports": [{"id": "rupe", "pos": 3, "edge": 5}, {"id": "bruma", "pos": 6, "edge": 4}, {"id": "alba", "pos": 7, "edge": 1}, {"id": "vespro", "pos": 9, "edge": 2}],
		"start": {"re": "capitale", "papa": "capitale", "spia": "fluviale", "mercante": "autunnale", "fanteria": "montano", "cavalleria": "palustre"},
	},
	{
		"id": "corona", "n": "La Corona di Regni", "desc": "La Capitale al centro, circondata dagli altri sei regni come gemme di una corona. Un ponte crollato spezza l'anello a ponente; i porti attraversano il regno da costa a costa.",
		"tiles": {4: "capitale", 3: "montano", 7: "boschivo", 8: "fluviale", 5: "collinare", 1: "palustre", 0: "autunnale"},
		"bridges": [[4, 3], [4, 7], [4, 8], [4, 5], [4, 1], [4, 0], [3, 7], [7, 8], [8, 5], [5, 1], [0, 3]],
		"ports": [{"id": "rupe", "pos": 0, "edge": 4}, {"id": "bruma", "pos": 8, "edge": 2}, {"id": "alba", "pos": 3, "edge": 0}, {"id": "vespro", "pos": 5, "edge": 3}],
		"start": {"re": "capitale", "papa": "capitale", "spia": "palustre", "mercante": "fluviale", "fanteria": "montano", "cavalleria": "collinare"},
	},
	{
		"id": "ponente", "n": "Le Terre di Ponente", "desc": "Il regno si sposta a ovest: la Capitale guarda il mare aperto, la lunga dorsale dei quattro regni orientali la protegge. Le rotte dei porti si incrociano da un angolo all'altro.",
		"tiles": {0: "autunnale", 1: "capitale", 2: "fluviale", 3: "palustre", 4: "collinare", 5: "boschivo", 6: "montano"},
		"bridges": [[0, 1], [1, 2], [3, 4], [4, 5], [5, 6], [0, 3], [0, 4], [1, 4], [1, 5], [2, 5], [2, 6]],
		"ports": [{"id": "rupe", "pos": 3, "edge": 1}, {"id": "bruma", "pos": 2, "edge": 4}, {"id": "alba", "pos": 0, "edge": 0}, {"id": "vespro", "pos": 6, "edge": 2}],
		"start": {"re": "capitale", "papa": "capitale", "spia": "collinare", "mercante": "fluviale", "fanteria": "palustre", "cavalleria": "montano"},
	},
	{
		"id": "diagonale", "n": "La Diagonale", "desc": "I regni corrono in diagonale da nord-ovest a sud-est, con la Capitale nel cuore della striscia: chi la controlla tiene insieme il regno. I porti tagliano il mare da un capo all'altro.",
		"tiles": {5: "capitale", 4: "boschivo", 1: "fluviale", 8: "montano", 9: "autunnale", 0: "collinare", 6: "palustre"},
		"bridges": [[0, 1], [0, 4], [1, 4], [1, 5], [4, 5], [4, 8], [5, 6], [5, 8], [5, 9], [6, 9], [8, 9]],
		"ports": [{"id": "alba", "pos": 0, "edge": 0}, {"id": "vespro", "pos": 6, "edge": 3}, {"id": "rupe", "pos": 1, "edge": 4}, {"id": "bruma", "pos": 8, "edge": 1}],
		"start": {"re": "capitale", "papa": "capitale", "spia": "fluviale", "mercante": "autunnale", "fanteria": "montano", "cavalleria": "palustre"},
	},
	{
		"id": "golfo", "n": "Il Golfo del Nord", "desc": "Il mare entra da nord in un ampio golfo; la Capitale, a sud del golfo, tocca tutti e sei gli altri regni. Un ponte crollato separa il Montano dal Palustre.",
		"tiles": {5: "capitale", 1: "montano", 2: "palustre", 4: "boschivo", 6: "collinare", 8: "fluviale", 9: "autunnale"},
		"bridges": [[1, 4], [1, 5], [2, 5], [2, 6], [4, 5], [4, 8], [5, 6], [5, 8], [5, 9], [6, 9], [8, 9]],
		"ports": [{"id": "alba", "pos": 1, "edge": 5}, {"id": "vespro", "pos": 9, "edge": 2}, {"id": "rupe", "pos": 2, "edge": 3}, {"id": "bruma", "pos": 8, "edge": 1}],
		"start": {"re": "capitale", "papa": "capitale", "spia": "montano", "mercante": "autunnale", "fanteria": "boschivo", "cavalleria": "palustre"},
	},
	{
		"id": "arcipelago", "n": "L'Arcipelago", "desc": "Solo 8 ponti: il Collinare e il Palustre sono isole appese a un solo ponte, e i porti diventano vie preziose. La Capitale, al centro, è il crocevia di tutto.",
		"tiles": {4: "capitale", 3: "boschivo", 5: "fluviale", 0: "montano", 7: "autunnale", 2: "collinare", 9: "palustre"},
		"bridges": [[0, 3], [0, 4], [2, 5], [3, 4], [3, 7], [4, 5], [4, 7], [5, 9]],
		"ports": [{"id": "alba", "pos": 2, "edge": 3}, {"id": "vespro", "pos": 9, "edge": 3}, {"id": "rupe", "pos": 0, "edge": 5}, {"id": "bruma", "pos": 7, "edge": 1}],
		"start": {"re": "capitale", "papa": "capitale", "spia": "fluviale", "mercante": "collinare", "fanteria": "montano", "cavalleria": "autunnale"},
	},
	{
		"id": "ferro", "n": "Il Ferro di Cavallo", "desc": "Sei regni a ferro di cavallo attorno a una baia, uniti da soli 6 ponti, con la Capitale in cima. Le due rotte dei porti chiudono il ferro a sud: senza il mare il cammino è lunghissimo.",
		"tiles": {3: "capitale", 0: "boschivo", 7: "fluviale", 1: "montano", 8: "autunnale", 2: "palustre", 9: "collinare"},
		"bridges": [[0, 1], [0, 3], [1, 2], [3, 7], [7, 8], [8, 9]],
		"ports": [{"id": "alba", "pos": 2, "edge": 3}, {"id": "vespro", "pos": 9, "edge": 3}, {"id": "rupe", "pos": 1, "edge": 4}, {"id": "bruma", "pos": 8, "edge": 2}],
		"start": {"re": "capitale", "papa": "capitale", "spia": "montano", "mercante": "autunnale", "fanteria": "boschivo", "cavalleria": "fluviale"},
	},
]

# ------------------------------------------------------------------ personaggi

const CHARS := ["re", "papa", "mercante", "spia", "fanteria", "cavalleria"]
const CHAR_NAME := {"re": "Il Re", "papa": "Il Papa", "mercante": "Il Mercante", "spia": "La Spia", "fanteria": "La Fanteria", "cavalleria": "La Cavalleria"}
const CHAR_SHORT := {"re": "Re", "papa": "Papa", "mercante": "Mercante", "spia": "Spia", "fanteria": "Fanteria", "cavalleria": "Cavalleria"}
const CHAR_CARD := {"re": "res://assets/cards/01_re.webp", "papa": "res://assets/cards/02_papa.webp", "mercante": "res://assets/cards/03_mercante.webp",
	"spia": "res://assets/cards/04_spia.webp", "fanteria": "res://assets/cards/05_fanteria.webp", "cavalleria": "res://assets/cards/06_cavalleria.webp"}
const CHAR_PORTRAIT := {"re": "res://assets/chars/re.webp", "papa": "res://assets/chars/papa.webp", "mercante": "res://assets/chars/mercante.webp",
	"spia": "res://assets/chars/spia.webp", "fanteria": "res://assets/chars/fanteria.webp", "cavalleria": "res://assets/chars/cavalleria.webp"}
const CHAR_MODEL := {"re": "res://assets/models/re.glb", "papa": "res://assets/models/papa.glb", "mercante": "res://assets/models/mercante.glb",
	"spia": "res://assets/models/spia.glb", "fanteria": "res://assets/models/fanteria.glb", "cavalleria": "res://assets/models/cavalleria.glb"}
const CHAR_COLOR := {"re": Color("#a31f24"), "papa": Color("#e9dcb5"), "mercante": Color("#c08a2e"), "spia": Color("#5b2f7a"), "fanteria": Color("#9b2a22"), "cavalleria": Color("#7a1f1a")}

## Riassunto di una riga delle azioni (normale, potenziata), mostrato sotto il ritratto.
const CHAR_BRIEF := {
	"re": ["2 villaggi qui + 1 in un regno vicino, uno di un altro colore.", "2 villaggi di qualsiasi colore al 2° (e 3°) posto."],
	"papa": ["1 influenza religiosa qui o in un regno vicino.", "Anche in guerra, e nomini un tuo Vescovo."],
	"mercante": ["Ruba 1 risorsa a un avversario.", "Ruba 2 risorse a un avversario."],
	"spia": ["Scambia un villaggio qui con uno vicino (no Governatori).", "Scambia anche i Governatori."],
	"fanteria": ["Scaccia 1 invasore e costruisci; o battaglia (+1).", "Scaccia 2 invasori e costruisci 2 villaggi."],
	"cavalleria": ["Muove 1-2 (no porti): scaccia 1 invasore e costruisci; o battaglia.", "Scaccia 2 invasori e costruisci 2 villaggi."],
}

## Riassunto della passiva, sotto il ritratto.
const CHAR_PASSIVE := {
	"re": "Chi ha la maggioranza qui dà la Corona.",
	"papa": "Chi ha la maggioranza qui riceve il Favore.",
	"mercante": "La Ricchezza di questo regno sale di 1.",
	"spia": "Un invasore entra in questo regno.",
	"fanteria": "Se c'è battaglia, si combatte (+1).",
	"cavalleria": "Se c'è battaglia, si combatte.",
}

const CHAR_TEXT := {
	"re": {"normale": "Piazza 2 villaggi nel regno del Re e 1 in un regno adiacente, sui siti liberi in ordine crescente. Se ne piazzi 2 o più, almeno uno è di un altro colore; se ne piazzi solo 1, è tuo. Vietato nei regni in guerra o con un esercito.",
		"potenziata": "Piazza 2 villaggi di qualsiasi colore nel regno del Re e/o in uno adiacente, in seconda (e terza) posizione: i villaggi presenti scalano in avanti, chi esce torna alla riserva (anche gli invasori). Ammesso nei regni pacificati o con un esercito, mai in guerra.",
		"passiva": "Chi ha la maggioranza nel regno del Re ottiene la Corona e la dà a chi vuole (anche a sé): diventa Primo Giocatore."},
	"papa": {"normale": "Piazza 1 influenza religiosa nel regno del Papa o in uno adiacente, non in guerra, sul numero più alto libero della Ricchezza. Se lì c'è l'indicatore della ricchezza, scende di un numero.",
		"potenziata": "Come la normale, ma anche in un regno in guerra. Inoltre metti un tuo Vescovo in una Cattedrale libera qualsiasi: a fine partita vale 2 punti più 2 per ogni influenza religiosa del suo regno.",
		"passiva": "Chi ha la maggioranza nel regno del Papa riceve un Favore Papale, se non ne ha già uno."},
	"mercante": {"normale": "Prendi 1 risorsa a scelta dalla riserva di un altro giocatore e mettila fra le tue.",
		"potenziata": "Prendi 2 risorse a scelta dalla riserva di un avversario e mettile fra le tue.",
		"passiva": "La Ricchezza del regno del Mercante sale di uno (non oltre il 5 né oltre un'influenza religiosa). Non avviene in un regno in guerra."},
	"spia": {"normale": "Scambia due villaggi: uno nel regno della Spia e uno in un regno adiacente. Non si scambiano i Governatori (sito 1). I villaggi possono essere di chiunque.",
		"potenziata": "Come la normale, ma si possono scambiare anche i Governatori, anche due Governatori fra loro.",
		"passiva": "La Spia aggiunge un invasore nel suo regno, sul sito libero più alto. Se non c'è posto, l'invasore prende il posto del villaggio sul sito più alto e scoppia una Guerra. Non avviene in un regno pacificato."},
	"fanteria": {"normale": "Nel regno raggiunto elimina 1 invasore e costruisci 1 tuo villaggio sul sito libero più basso. Oppure entra in un regno in guerra e dichiara battaglia: si risolve nella fase passiva (la Fanteria dà +1).",
		"potenziata": "Elimina 2 invasori e costruisci 2 tuoi villaggi. Non in un regno in guerra.",
		"passiva": "Se è stata dichiarata battaglia, si risolve la battaglia."},
	"cavalleria": {"normale": "Muove di 1 o 2 regni (senza tornare alla partenza, senza porti). Nel regno raggiunto elimina 1 invasore e costruisci 1 tuo villaggio sul sito libero più basso. Oppure entra in un regno in guerra e dichiara battaglia (nessun bonus).",
		"potenziata": "Elimina 2 invasori e costruisci 2 tuoi villaggi. Non in un regno in guerra.",
		"passiva": "Se è stata dichiarata battaglia, si risolve la battaglia."},
}

# ------------------------------------------------------------------ carte obiettivo
## kind "terr": controllo (maggioranza) dei regni indicati, 3/7/12 punti per 1/2/3 regni.
## I regni sono indicati per nome, perché la mappa può cambiare da scenario a scenario.

const OBJ_TERR_PTS := [0, 3, 7, 12]

const OBJECTIVES := [
	{"id": "pacificatore", "code": "O01", "n": "Il Pacificatore", "kind": "pg", "t": "4 PV per ogni regno pacificato sulla mappa: 4 PV con uno, 8 con due, 12 con tre."},
	{"id": "infiltrato", "code": "O02", "n": "L'Infiltrato", "kind": "pg", "t": "4 PV per ogni regno in guerra sulla mappa: 4 PV con uno, 8 con due, 12 con tre."},
	{"id": "camerlengo", "code": "O03", "n": "Il Camerlengo", "kind": "pg", "t": "2 PV per ogni influenza religiosa presente sulla mappa a fine partita."},
	{"id": "conquistatore", "code": "O04", "n": "Il Conquistatore", "kind": "pg", "t": "1 PV ogni 2 tuoi villaggi presenti sulla mappa a fine partita (le coppie incomplete non danno punti)."},
	{"id": "cancelliere", "code": "O05", "n": "Il Cancelliere", "kind": "pg", "t": "2 PV per ogni tuo villaggio nella Capitale a fine partita."},
	{"id": "politico", "code": "O06", "n": "Il Politico", "kind": "pg", "t": "Governatore in un regno 3 PV, in due regni 6 PV, in tre o più regni 9 PV."},
	{"id": "dittatore", "code": "O07", "n": "Il Dittatore", "kind": "pg", "t": "10 PV se a fine partita in almeno un regno ci sono soltanto villaggi del tuo colore (nessun altro villaggio né invasore)."},
	{"id": "balivo", "code": "O08", "n": "Il Balivo", "kind": "pg", "t": "1 PV ogni 2 invasori presenti sulla mappa a fine partita (le coppie incomplete non danno punti)."},
	{"id": "regina", "code": "O09", "n": "La Regina", "kind": "pg", "t": "10 PV se a fine partita hai sia la maggioranza sia il Governatore della Capitale."},
	{"id": "nemico", "code": "O10", "n": "Il Nemico", "kind": "pg", "t": "Se la partita termina per invasione e hai la maggioranza nella Capitale, VINCI la partita."},
	{"id": "usurpatore", "code": "O11", "n": "L'Usurpatore", "kind": "pg", "t": "Se la partita termina con tre guerre e hai la maggioranza nella Capitale, VINCI la partita."},
	{"id": "t01", "code": "O12", "kind": "terr", "r": ["capitale", "boschivo", "palustre"]},
	{"id": "t02", "code": "O13", "kind": "terr", "r": ["capitale", "fluviale", "palustre"]},
	{"id": "t03", "code": "O14", "kind": "terr", "r": ["capitale", "montano", "autunnale"]},
	{"id": "t04", "code": "O15", "kind": "terr", "r": ["capitale", "montano", "collinare"]},
	{"id": "t05", "code": "O16", "kind": "terr", "r": ["capitale", "autunnale", "collinare"]},
	{"id": "t06", "code": "O17", "kind": "terr", "r": ["capitale", "collinare", "palustre"]},
	{"id": "t07", "code": "O18", "kind": "terr", "r": ["boschivo", "fluviale", "montano"]},
	{"id": "t08", "code": "O19", "kind": "terr", "r": ["boschivo", "fluviale", "collinare"]},
	{"id": "t09", "code": "O20", "kind": "terr", "r": ["boschivo", "montano", "autunnale"]},
	{"id": "t10", "code": "O21", "kind": "terr", "r": ["boschivo", "montano", "palustre"]},
	{"id": "t11", "code": "O22", "kind": "terr", "r": ["boschivo", "autunnale", "palustre"]},
	{"id": "t12", "code": "O23", "kind": "terr", "r": ["boschivo", "collinare", "palustre"]},
	{"id": "t13", "code": "O24", "kind": "terr", "r": ["fluviale", "montano", "autunnale"]},
	{"id": "t14", "code": "O25", "kind": "terr", "r": ["fluviale", "montano", "collinare"]},
	{"id": "t15", "code": "O26", "kind": "terr", "r": ["fluviale", "autunnale", "collinare"]},
	{"id": "t16", "code": "O27", "kind": "terr", "r": ["fluviale", "autunnale", "palustre"]},
]


static func objective(id: String) -> Dictionary:
	for o in OBJECTIVES:
		if o["id"] == id:
			return o
	return {}


## Immagine della carta obiettivo (fronti illustrati v02).
static func obj_image(id: String) -> String:
	var o := objective(id)
	return "res://assets/cards/obiettivi/%s.webp" % o.get("code", "O01")


static func obj_name(id: String) -> String:
	var o := objective(id)
	if o.get("kind", "") == "terr":
		return "Dominio: " + ", ".join(o["r"].map(func(t): return TILES[t]["short"]))
	return o.get("n", id)


static func obj_text(id: String) -> String:
	var o := objective(id)
	if o.get("kind", "") == "terr":
		var names: Array = o["r"].map(func(t): return TILES[t]["n"])
		return "Maggioranza in %s: 1 regno 3 PV, 2 regni 7 PV, 3 regni 12 PV." % ", ".join(names)
	return o.get("t", "")


static func scenario(id: String) -> Dictionary:
	for s in SCENARIOS:
		if s["id"] == id:
			return s.duplicate(true)
	return SCENARIOS[0].duplicate(true)


## Controlla uno scenario (anche fatto con l'editor). Restituisce l'elenco dei problemi (vuoto se va bene).
const ROUTE_COLORS := {"alba": Color("#ffc94a"), "rupe": Color("#c58bff")}


## Rotta via mare fra due porti che gira ATTORNO alle tessere: esce dal porto verso il largo, segue
## il contorno (convesso, allargato di margin) della mappa dal lato più corto ed entra nell'altro porto.
## a/b: punto sul lato della tessera; na/nb: direzione verso il mare; centers: centri delle tessere.
## half/center: limiti del tabellone, per non uscire dal bordo.
static func sea_route(a: Vector2, na: Vector2, b: Vector2, nb: Vector2, centers: Array, port_d: float, margin: float, half: Vector2, center: Vector2) -> Array:
	var g := Vector2.ZERO
	for c in centers:
		g += c
	g /= maxf(1.0, centers.size())
	var pa := a + na * port_d
	var pb := b + nb * port_d
	var oa := a + na * (port_d + 0.35)
	var ob := b + nb * (port_d + 0.35)
	var ta := (oa - g).angle()
	var tb := (ob - g).angle()
	var d := wrapf(tb - ta, -PI, PI)
	var pts := [pa, oa]
	var n := maxi(6, int(absf(d) / 0.12))
	for k in range(1, n):
		var th := ta + d * k / n
		var u := Vector2(cos(th), sin(th))
		var h := -INF
		for c in centers:
			h = maxf(h, (c - g).dot(u))
		var q := g + u * (h + margin)
		q.x = clampf(q.x, center.x - half.x, center.x + half.x)
		q.y = clampf(q.y, center.y - half.y, center.y + half.y)
		pts.append(q)
	pts.append(ob)
	pts.append(pb)
	# un po' di morbidezza: media mobile sui punti interni
	var sm := [pts[0]]
	for i in range(1, pts.size() - 1):
		sm.append((pts[i - 1] + pts[i] * 2.0 + pts[i + 1]) / 4.0)
	sm.append(pts[pts.size() - 1])
	return sm


## Ponti richiesti: 11, o tutti i lati in comune fra regni se la disposizione ne ha meno.
static func bridges_needed(s: Dictionary) -> int:
	var tiles := {}
	for k in s.get("tiles", {}):
		tiles[int(k)] = true
	var pairs := 0
	for a in tiles:
		for b in tiles:
			if a < b and edge_between(a, b) >= 0:
				pairs += 1
	return mini(11, pairs)


static func validate_scenario(s: Dictionary) -> Array:
	var errs := []
	var tiles: Dictionary = {}
	for k in s.get("tiles", {}):
		tiles[int(k)] = s["tiles"][k]
	var used := {}
	for p in tiles:
		if p < 0 or p > 9:
			errs.append("Posizione %d inesistente." % p)
		if used.has(tiles[p]):
			errs.append("%s compare due volte." % TILES.get(tiles[p], {}).get("n", tiles[p]))
		used[tiles[p]] = true
	if tiles.size() != 7:
		errs.append("Servono 7 regni sul tabellone (ce ne sono %d)." % tiles.size())
	var br: Array = s.get("bridges", [])
	var need := bridges_needed(s)
	if br.size() != need:
		errs.append("Servono %d ponti (ce ne sono %d)." % [need, br.size()] + ("" if need == 11 else " Con questa disposizione i regni si toccano solo in %d punti." % need))
	var seen := {}
	for b in br:
		var a := int(b[0])
		var c := int(b[1])
		if not tiles.has(a) or not tiles.has(c):
			errs.append("Un ponte non collega due regni.")
			continue
		if edge_between(a, c) < 0:
			errs.append("Ponte fra %s e %s: i due regni non si toccano." % [TILES[tiles[a]]["short"], TILES[tiles[c]]["short"]])
		var key := "%d-%d" % [mini(a, c), maxi(a, c)]
		if seen.has(key):
			errs.append("Ponte doppio fra %s e %s." % [TILES[tiles[a]]["short"], TILES[tiles[c]]["short"]])
		seen[key] = true
	var ports: Array = s.get("ports", [])
	if ports.size() != 4:
		errs.append("Servono 4 porti (ce ne sono %d)." % ports.size())
	var pids := {}
	var port_tiles := {}
	for pt in ports:
		var p := int(pt["pos"])
		pids[pt["id"]] = true
		if not tiles.has(p):
			errs.append("%s non è su un regno." % PORT_NAMES[pt["id"]]["n"])
			continue
		if port_tiles.has(p):
			errs.append("Due porti sullo stesso regno (%s)." % TILES[tiles[p]]["short"])
		port_tiles[p] = true
		if tiles.has(neighbor(p, int(pt["edge"]))):
			errs.append("%s deve stare su un lato verso il mare aperto." % PORT_NAMES[pt["id"]]["n"])
	for id in PORT_NAMES:
		if not pids.has(id):
			errs.append("Manca %s." % PORT_NAMES[id]["n"])
	if not tiles.values().has("capitale"):
		errs.append("Manca la Capitale.")
	# il regno deve essere tutto raggiungibile (ponti e porti)
	if errs.is_empty():
		var adj := {}
		for p in tiles:
			adj[p] = []
		for b in br:
			adj[int(b[0])].append(int(b[1]))
			adj[int(b[1])].append(int(b[0]))
		var by_id := {}
		for pt in ports:
			by_id[pt["id"]] = int(pt["pos"])
		for pr in [["alba", "vespro"], ["rupe", "bruma"]]:
			adj[by_id[pr[0]]].append(by_id[pr[1]])
			adj[by_id[pr[1]]].append(by_id[pr[0]])
		var start: int = tiles.keys()[0]
		var stack := [start]
		var vis := {start: true}
		while not stack.is_empty():
			var q: int = stack.pop_back()
			for x in adj[q]:
				if not vis.has(x):
					vis[x] = true
					stack.append(x)
		if vis.size() != tiles.size():
			errs.append("Alcuni regni non si possono raggiungere né via ponte né via mare.")
	var st: Dictionary = s.get("start", {})
	for c in CHARS:
		if not used.has(st.get(c, "")):
			errs.append("Manca la partenza di %s." % CHAR_NAME[c])
	return errs


# ------------------------------------------------------------------ variante dell'Alchimista
## «La bottega dell'Alchimista» (prototipo 0.2 di Stefano Ancillai): l'Alchimista prende il posto del
## Mercante (stessa pedina, stessa partenza e stessa passiva) e invece di rubare pesca progetti.
## Internamente il personaggio resta "mercante": cambiano nomi, testi e immagini.

static var alch := false

const PROJ_IDS := ["I01", "I02", "I03", "I04", "I05", "I06", "I07", "I08", "A01", "A02", "A03", "A04"]
const PROJECTS := {
	"I01": {"n": "Cantiere istantaneo", "kind": "inv", "cost": {"legno": 1, "pietra": 1}, "pv": 2,
		"t": "Piazza 1 tuo villaggio nel primo sito libero di un regno dove sei già presente, senza guerra né eserciti. Raccogli l'eventuale risorsa."},
	"I02": {"n": "Solvente degli invasori", "kind": "inv", "cost": {"grano": 1, "ferro": 1}, "pv": 2,
		"t": "In un regno dove hai un villaggio (anche in guerra) rimuovi fino a 2 invasori; se non ne restano, la guerra finisce."},
	"I03": {"n": "Elisir della fortuna", "kind": "inv", "cost": {"oro": 1}, "pv": 1,
		"t": "In un regno non in guerra dove hai un villaggio, aumenta o diminuisci la Ricchezza di 1 (non sotto 1, non oltre 5 né oltre un'influenza religiosa)."},
	"I04": {"n": "Stivali del vento", "kind": "inv", "cost": {"grano": 1}, "pv": 1,
		"t": "Muovi di 1 passo legale un personaggio a scelta, anche già usato nel turno. Non compie azioni e non torna disponibile."},
	"I05": {"n": "Incenso consacrato", "kind": "inv", "cost": {"pietra": 1, "oro": 1}, "pv": 2,
		"t": "In un regno non in guerra dove hai un villaggio, aggiungi 1 influenza religiosa al valore scoperto più alto oppure togline fino a 2, che tornano al Papa."},
	"I06": {"n": "Polvere del tuono", "kind": "inv", "cost": {"legno": 1}, "pv": 1, "auto": true, "perm": true,
		"t": "Permanente: +1 alla tua forza in tutte le tue battaglie."},
	"I07": {"n": "Mano invisibile", "kind": "inv", "cost": {"oro": 1}, "pv": 1,
		"t": "Prendi 1 risorsa a scelta dalla riserva di un avversario qualsiasi."},
	"I08": {"n": "Specchio degli scambi", "kind": "inv", "cost": {"legno": 1, "oro": 1}, "pv": 2,
		"t": "Scambia 1 tuo villaggio e 1 avversario in due regni collegati da un ponte (non i siti 1 né gli invasori). Ammesso anche in guerra."},
	"A01": {"n": "Athanor", "kind": "art", "cost": {"pietra": 1, "ferro": 1}, "pv": 2, "auto": true,
		"perm": true,
		"t": "Permanente: ogni due carte che attivi prendi 1 risorsa dalla riserva delle spese (quella che ti serve di più)."},
	"A02": {"n": "Bussola celeste", "kind": "art", "cost": {"legno": 1, "ferro": 1}, "pv": 2,
		"auto": true, "perm": true,
		"t": "Permanente: i personaggi che scegli possono fare 1 passo in più (la Cavalleria fino a 3), senza tornare in un regno già visitato."},
	"A03": {"n": "Stendardo animato", "kind": "art", "cost": {"grano": 1, "ferro": 1}, "pv": 2, "auto": true,
		"perm": true,
		"t": "Permanente: +1 alla tua forza in tutte le tue battaglie."},
	"A04": {"n": "Trasmutatore", "kind": "art", "cost": {"pietra": 1, "grano": 1}, "pv": 2,
		"auto": true, "perm": true,
		"t": "Permanente: quando attivi una carta puoi pagare 1 icona del costo con una risorsa qualsiasi."},
}

static func proj_img(id: String) -> String:
	return "res://assets/alch/%s.webp" % id


static func cn(c: String) -> String:
	return "L'Alchimista" if alch and c == "mercante" else CHAR_NAME[c]


static func cshort(c: String) -> String:
	return "Alchimista" if alch and c == "mercante" else CHAR_SHORT[c]


static func cbrief(c: String) -> Array:
	if alch and c == "mercante":
		return ["Attiva 1 tua carta pagandone il costo.", "Attiva 2 tue carte e prendi 1 jolly."]
	return CHAR_BRIEF[c]


static func cpassive(c: String) -> String:
	if alch and c == "mercante":
		return "Ricchezza +1; chi ha la maggioranza prende 1 jolly e attiva 1 carta."
	return CHAR_PASSIVE[c]


static func ctext(c: String) -> Dictionary:
	if alch and c == "mercante":
		return {"normale": "Attiva 1 delle tue carte: paghi il costo in risorse, ne risolvi l'effetto e la giri. Da quel momento non ha più effetto e a fine partita vale i PV stampati.",
			"potenziata": "Attiva 2 delle tue carte e ricevi una risorsa jolly.", "passiva": CHAR_TEXT["mercante"]["passiva"] + " Inoltre chi ha la maggioranza nel regno dell'Alchimista riceve una risorsa jolly (vale come qualsiasi risorsa) e può attivare 1 delle sue carte."}
	return CHAR_TEXT[c]


static func ccard(c: String) -> String:
	return "res://assets/alch/alchimista_carta.webp" if alch and c == "mercante" else CHAR_CARD[c]


static func cart(c: String) -> String:
	return "res://assets/chars/%s_art.webp" % ("alchimista" if alch and c == "mercante" else c)


static func cmodel(c: String) -> String:
	return "alchimista" if alch and c == "mercante" and ResourceLoader.exists("res://assets/models/alchimista.glb") else c
