# Seven Kingdom

Versione digitale di **Seven Kingdom**, gioco originale di **Stefano & Simone Ancillai**, fatta in Godot 4.7.
Si gioca nel browser: **https://tannoiser2.github.io/Seven-Kingdom/**

Da 2 a 4 casati si contendono sette regni piazzando villaggi e manovrando sei personaggi (Re, Papa, Mercante,
Spia, Fanteria, Cavalleria). Ogni giocatore fa una sola azione per turno, poi tutti i personaggi fanno la loro
azione passiva, e alla fine del turno gli invasori dilagano nei regni rimasti senza personaggi.

## Cosa c'è
- **Regole complete** del regolamento italiano, con le **risorse** di Seven Planet (legno, pietra, grano, ferro,
  oro, 9 per tipo): coprono tutti i 45 siti, le prende chi ci costruisce, gli invasori le distruggono, il Mercante le ruba agli avversari, a fine partita valgono
  5/3/1 punti per tipo. Il Mercato non c'è più.
- **Carte obiettivo** (le 27 illustrate, con i regni indicati per nome) e **guerra con dado**, entrambe opzionali.
- **Mappe**: *Il Regno dei Sette* (la mappa del gioco originale, 11 ponti e 4 porti), *La Corona di Regni*,
  *Le Terre di Ponente*, più l'**editor delle mappe** per inventarne di nuove (si salvano sul dispositivo e si
  condividono con un codice `SK1:…`).
- **Mappa 3D** (tessere in rilievo ricavato dai dipinti, mare animato, telecamera libera) o **2D** dall'alto;
  **pedine 3D** (miniature dei personaggi, villaggi e vescovi generati con Meshy dalle illustrazioni, ricolorati
  per ogni casato; risorse, accampamenti e segnalini in 3D) o **2D** (i segnalini dipinti). Si cambia anche in partita.
- **IA** a tre livelli: Facile, Normale, Difficile (guarda anche le risposte degli avversari e il turno dopo).
- **Hotseat** e **gioco online** su Firebase.

## Interpretazioni della versione digitale
Dove il regolamento lasciava dubbi (vedi anche le note delle carte):
- i villaggi si costruiscono dal sito più basso (il Governatore) verso l'alto, gli invasori arrivano dal sito più
  alto; quando un invasore non trova posto scaccia il villaggio sul sito più alto e scoppia la Guerra;
- il Re potenziato mette ogni villaggio subito dopo il Governatore (sito 2, e 3 se entrambi nello stesso regno);
- ogni giocatore ha 7 Vescovi, uno per Cattedrale; il Vescovo vale 2 punti più 2 per influenza religiosa;
- la Ricchezza è «piena» con 5 influenze religiose (l'indicatore scende a 0);
- il villaggio costruito da un esercito non prende la risorsa del sito, che va persa;
- la Spia scambia solo villaggi; il Cancelliere conta i propri villaggi nella Capitale.

## Gioco online
Dal menu, **Gioca online**. Usa lo stesso progetto Firebase degli altri giochi della ludoteca, con le stanze sotto
`sevenkingdom/rooms`: la sezione generica `$game` di `firebase/database.rules.json` lo copre già.
Chi crea la stanza sceglie nel menu casati, mappa e opzioni; gli amici entrano con il codice di 4 lettere.
Ogni decisione è una mossa numerata (`acts/0`, `acts/1`, …) e tutti i dispositivi giocano la stessa partita con lo
stesso seme. Chi cade rientra con lo stesso codice; chi tace per un minuto viene sostituito dall'IA.

## Struttura
```
scripts/data/sk_data.gd       regni, siti, personaggi, scenari, carte obiettivo
scripts/data/rules_text.gd    regolamento mostrato nel gioco
scripts/core/sk_state.gd      stato e regole (azioni, passive, fine turno, punteggio)
scripts/core/engine.gd        svolgimento della partita e decisioni
scripts/core/ai.gd            giocatori artificiali
scripts/ui/board3d.gd         tavolo 3D/2D, tessere, pezzi, telecamera
scripts/ui/game_view.gd       interfaccia della partita
scripts/ui/menu.gd            menu e stanze online
scripts/ui/editor.gd          editor delle mappe
scripts/net/                  Firebase (REST) e partita online in lockstep
tools/prepara_asset.py        ritaglia tessere, carte, segnalini e obiettivi dalle illustrazioni originali
tools/rilievo.py              mappe delle altezze delle tessere per la mappa 3D
tools/copertina.py            copertina, icona e splash
assets/models/                miniature 3D (Meshy, image-to-3D dalle illustrazioni)
```

## Test
```
godot --headless --path . -s res://tests/sim.gd -- 40 2,1,2,1 base     # partite IA contro IA (livelli per posto)
godot --headless --path . -s res://tests/ui_play.gd -- 6               # partite giocate dall'interfaccia
python3 tests/firebase_mock.py 8765 & …tests/online_play.gd            # due dispositivi online sul finto Firebase
xvfb-run godot --path . -s res://tests/shot.gd -- game 1 1 2           # screenshot (mappa 3D, pedine 3D)
```
