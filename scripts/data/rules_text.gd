class_name RulesText
extends RefCounted
## Il regolamento di Seven Kingdom come lo applica la versione digitale.

const TEXT := """[b]SEVEN KINGDOM[/b] — un gioco di Stefano & Simone Ancillai. Da 2 a 4 casati si contendono i sette regni piazzando villaggi e manovrando i sei personaggi che governano politica, economia e religione. Zero fortuna (salvo la regola opzionale del dado): vince chi sceglie la mossa giusta al momento giusto.

[b]LA MAPPA[/b]
Sette tessere esagonali sul mare: la Capitale (9 siti) e i regni Boschivo e Fluviale (7), Montano e Autunnale (6), Collinare e Palustre (5). I regni collegati da un [b]ponte[/b] sono adiacenti (11 ponti; meno solo nelle mappe dove i regni si toccano in meno punti). Quattro [b]porti[/b], a coppie (I: Alba–Vespro, II: Rupe–Bruma), collegano due regni via mare: valgono [i]solo per il movimento[/i], mai per gli effetti delle azioni. La Cavalleria non usa i porti.
Ogni regno ha una traccia di [b]siti[/b] numerati: il sito 1, con la corona, è quello del [b]Governatore[/b], che decide le parità di maggioranza. Ha poi la traccia della [b]Ricchezza[/b] (1–5) e la [b]Cattedrale[/b] per un Vescovo.
Le mappe si scelgono nel menu (Il Regno dei Sette è quella del gioco originale) e se ne possono inventare di nuove con l'editor.

[b]PREPARAZIONE[/b]
Ricchezza 2 in ogni regno, 3 nella Capitale. Su tutti i 45 siti si mettono a caso i 45 segnalini [b]risorsa[/b] (9 ciascuno di legno, pietra, grano, ferro, oro); poi dove parte la Spia arriva un invasore (che distrugge la risorsa del suo sito) e dove parte il Papa un'influenza religiosa sul 5. A turno, dal Primo Giocatore, ognuno mette per tre giri un villaggio sul sito libero più basso di un regno a scelta e prende la risorsa che c'era. L'ultimo giocatore riceve un Favore Papale.
Con le [b]carte obiettivo[/b] ognuno ne pesca 3 e ne tiene una, segreta.

[b]IL TURNO[/b]
1. [b]Azioni dei giocatori[/b] — dal Primo Giocatore in senso orario, ognuno fa UNA azione: sceglie un personaggio non ancora usato, lo [b]muove[/b] (obbligatorio: di un regno, anche via porto; la Cavalleria di 1 o 2 senza tornare indietro) e poi ne fa l'azione [b]normale[/b] o, scartando il Favore Papale, quella [b]potenziata[/b].
2. [b]Azioni passive[/b] di tutti i personaggi, nell'ordine Re, Papa, Mercante, Spia, Eserciti.
3. [b]Fine del turno[/b]: costo delle guerre, controllo di fine partita, invasione.

[b]I PERSONAGGI[/b]
[b]Il Re[/b] — Normale: 2 villaggi nel suo regno e 1 in un regno adiacente, sui siti liberi in ordine crescente. Se ne metti 2 o più almeno uno è di un altro colore; se ne metti uno solo è tuo. Vanno messi tutti quelli possibili. Vietato nei regni in guerra o con un esercito. Potenziata: 2 villaggi di qualsiasi colore nel suo regno e/o in uno adiacente, in seconda (e terza) posizione: gli altri scalano in avanti, chi esce torna alla riserva (anche gli invasori); ammesso con un esercito o in un regno pacificato, mai in guerra. Passiva: chi ha la maggioranza nel regno del Re prende la Corona e la dà a chi vuole: diventa Primo Giocatore.
[b]Il Papa[/b] — Normale: 1 influenza religiosa nel suo regno o in uno adiacente non in guerra, sul numero più alto libero della Ricchezza; se lì c'è l'indicatore della Ricchezza, scende di uno. Potenziata: anche in guerra, e in più metti un tuo [b]Vescovo[/b] in una Cattedrale libera qualsiasi (ne hai 7, uno per regno). Passiva: chi ha la maggioranza nel regno del Papa riceve un Favore Papale, se non ne ha già uno.
[b]Il Mercante[/b] — Normale: prendi 1 risorsa a scelta dalla riserva di un altro giocatore. Potenziata: prendine 2 da un avversario. Passiva: la Ricchezza del suo regno sale di uno, non oltre il 5 né oltre un'influenza religiosa; non in guerra.
[b]La Spia[/b] — Normale: scambia un villaggio del suo regno con uno di un regno adiacente (non i Governatori). Potenziata: anche i Governatori. Passiva: aggiunge un invasore nel suo regno (sito libero più alto; se non c'è posto scaccia il villaggio sul sito più alto e scoppia una Guerra). Non nei regni pacificati.
[b]La Fanteria e la Cavalleria[/b] (gli eserciti) — Normale: nel regno raggiunto, non in guerra, eliminano 1 invasore e costruiscono 1 tuo villaggio sul sito libero più basso (senza prenderne la risorsa, che va persa). Potenziata: 2 invasori, 2 villaggi. Oppure entrano in un regno [b]in guerra[/b] e dichiarano [b]battaglia[/b], che si risolve nella fase passiva.

[b]BATTAGLIA[/b]
Attacco = tuoi villaggi nel regno, +1 se hai la Corona, +1 se c'è la Fanteria, +1 se spendi il Favore Papale, +1 se il Governatore del regno ti aiuta. Vinci se l'attacco è almeno pari agli invasori: li elimini tutti, la guerra finisce, metti un tuo villaggio come Governatore (gli altri scalano) e la Ricchezza sale di uno, togliendo un'influenza religiosa se serve. Se perdi, un invasore prende il posto del villaggio sul sito più alto.
[i]Guerra con dado[/i] (opzionale): tiri un dado e vinci se superi il numero di invasori, con +1 per Favore, Fanteria e Governatore.

[b]REGNI IN GUERRA E PACIFICATI[/b]
Una Guerra scoppia quando un invasore deve entrare in un regno senza siti liberi. In guerra non si fanno le azioni di Re, Papa ed eserciti (ci si può però muovere); a fine turno la guerra abbassa di uno la Ricchezza, o se è già a 1 un invasore prende il posto del villaggio sul sito più alto.
Un regno con tutti i siti occupati da villaggi è [b]pacificato[/b] per sempre: Spia e invasioni non hanno più effetto.

[b]FINE DEL TURNO[/b]
Costo delle guerre, poi la partita finisce subito se: ci sono tre Guerre; ci sono tre regni pacificati; un regno è pieno di invasori; la Ricchezza di un regno è tutta coperta dall'influenza religiosa; il Papa ha finito le influenze (9). Altrimenti [b]invasione[/b]: ogni regno senza personaggi, non pacificato e non in guerra riceve un invasore.

[b]PUNTEGGIO[/b]
Ogni Governatore vale il numero più alto della Ricchezza non coperto dall'influenza religiosa; ogni altro villaggio vale la Ricchezza del suo regno. Ogni Vescovo vale 2 punti più 2 per ogni influenza religiosa del suo regno. Corona e Favore Papale valgono 2 punti ciascuno. Per ognuna delle cinque [b]risorse[/b] chi ne ha di più prende 5 punti, il secondo 3, il terzo 1 (a parità il premio scala al posto inferiore). Si aggiungono le carte obiettivo. A parità vince chi ha la Corona.

[b]VARIANTE: LA BOTTEGA DELL'ALCHIMISTA[/b] (regola opzionale, prototipo 0.5)
L'[b]Alchimista[/b] prende il posto del Mercante (stessa partenza). All'inizio le 24 carte (12 tipi, due copie) si distribuiscono equamente fra i giocatori. Le [b]risorse non danno più punti[/b]: servono a pagare le carte (1 o 2 risorse ciascuna, 4 icone per tipo di risorsa in tutto il mazzo) e quelle pagate vanno nella riserva delle risorse spese.
Normale: [b]attivi 1 tua carta[/b]: ne paghi il costo, ne risolvi l'effetto e la giri; girata vale a fine partita i PV stampati. Potenziata: ne attivi 2 e ricevi una [b]risorsa jolly[/b]. Passiva: la Ricchezza del suo regno sale di uno e [b]chi vi ha la maggioranza[/b] riceve una risorsa jolly e può attivare 1 delle sue carte. Il jolly vale come una risorsa qualsiasi e si conserva finché non lo usi. Ogni volta che una carta viene attivata l'Alchimista [b]scaccia un invasore[/b] dal regno in cui si trova (se il regno era in guerra e non restano invasori, la guerra finisce): la partita dura di più. Con questa variante la partita finisce con [b]4 regni pacificati[/b] invece di 3. Una carta si può attivare anche senza bersaglio, solo per i PV.
[b]Invenzioni[/b] (effetto una volta sola, quando la giri): Cantiere istantaneo (un villaggio dove sei presente), Solvente degli invasori (fino a 2, anche in guerra: se non ne restano la guerra finisce), Elisir della fortuna (Ricchezza ±1), Stivali del vento (un personaggio fa un passo), Incenso consacrato (aggiungi 1 influenza o togline fino a 2), Mano invisibile (prendi una risorsa), Specchio degli scambi.
[b]Artefatti[/b] (effetto permanente da quando li giri): Athanor (ogni due tue attivazioni prendi 1 risorsa fra quelle spese), Polvere del tuono (+1 in tutte le tue battaglie), Bussola celeste (i personaggi che scegli fanno un passo in più), Stendardo animato (+1 in tutte le tue battaglie), Trasmutatore (un'icona del costo si paga con una risorsa qualsiasi).

[b]NOTE DELLA VERSIONE DIGITALE[/b]
· Dal gioco spaziale Seven Planet vengono le risorse: il Mercante non manda più cubetti al Mercato, che non c'è più, ma ruba risorse agli avversari.
· I villaggi si costruiscono dal sito più basso (il Governatore) verso l'alto; gli invasori arrivano dal sito più alto verso il basso.
· Il Re potenziato mette ogni villaggio sul primo sito dopo il Governatore (se entrambi nello stesso regno, sul 2 e sul 3).
· La Ricchezza è «tutta coperta» quando ha 5 influenze religiose (l'indicatore scende a 0).
· La Spia scambia solo villaggi dei giocatori, non invasori.
· Gli invasori distruggono la risorsa del sito che occupano.
· Un esercito si può scegliere anche solo per spostarlo, se nel regno non ci sono invasori da scacciare.
· Senza Governatore (sito 1 vuoto o di un invasore) una parità non si risolve: nessuno ha la maggioranza.
· Se c'è parità di maggioranza decide il Governatore fra i pari merito.
"""
