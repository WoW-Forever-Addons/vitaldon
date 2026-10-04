# Vitaldon 1.0.0 (WoW Forever)

Text auf den Gesundheits- und Energieleisten (Mana, Wut, Energie, Fokus) der Standard-Einheitenfenster von Blizzard für World of Warcraft: Forever (Client "Camelot", Interface 16001).

## Installation
Ordner `Vitaldon` in den AddOns-Ordner des Forever-Clients kopieren (`...\Interface\AddOns\`). Im Spiel `/reload` oder neu einloggen. Beim ersten Start steht einmal pro Sitzung eine kurze Zeile im Chat ("Text liegt auf deinen Einheitenfenstern. Optionen: /vd, Befehle: /vd help.").

## Funktionen

### Einheitenfenster
Unter `/vd` > Einheiten lässt sich jede Gruppe einzeln schalten:
- An (Standard): Spieler, Ziel, Fokus, Begleiter, Gruppe (party1 bis party4) und Bossfenster (boss1 bis boss5, bei Bossbegegnungen).
- Aus (Standard): Ziel des Ziels (gilt für Ziel und Fokus), Gruppenfenster im Schlachtzugsstil und Schlachtzugsfenster.
- Fahrzeuge und Gedankenkontrolle: Zeigt Blizzards Spielerfenster das Fahrzeug, zeigt Vitaldon dort dessen Werte (am Begleiterfenster deine eigenen). Vitaldon liest dafür nur, welche Einheit das Blizzard-Fenster gerade zeigt.
- Gruppenfenster im Schlachtzugsstil (Bearbeitungsmodus: "Gruppenfenster im Schlachtzugsstil" an, dazu die Option in Vitaldon): Text auf den fünf Gesundheitsleisten. Vitaldon liest die angezeigte Einheit und folgt Umsortierungen innerhalb einer Viertelsekunde.
- Schlachtzugsfenster (bis 40 Spieler, mit und ohne "Gruppen zusammenhalten"): Blizzard baut sie erst bei Bedarf, Vitaldon findet neue bei Gruppenänderungen und alle 2 Sekunden. Ihre Werte werden viermal pro Sekunde aufgefrischt.
- Auf beiden Arten von Schlachtzugsfenstern gibt es nur Gesundheitstext (die Energieleisten sind zu flach), mit eigenem Format je Gruppe. Tot und Offline zeigt Blizzard dort selbst, Vitaldons Text bleibt dann leer. Zeigt Blizzards Schlachtzugsprofil seinen eigenen Gesundheitstext, können sich beide überlagern: im Profil auf "Keiner" stellen (`/vd diag` warnt dann).
- Arenafenster gibt es im Forever-Client nicht. Die Begleiter- und Zielfenster innerhalb der Schlachtzugsfenster zeigen den Text nur, wenn Blizzard sie als `CompactRaidFrame` anzeigt.

### Formate
Gesundheit und Energie haben getrennte Formate (`/vd` > Text):
- Prozent (`87%`)
- Aktuell (`12,3k`), Standard für Energie
- Aktuell / Max (`12,3k / 15k`)
- Aktuell (Prozent) (`12,3k (82%)`), Standard für Gesundheit
- Aktuell / Max (Prozent) (`12,3k / 15k (82%)`)
- Fehlbetrag (`-2,7k`)

Die Formatlisten zeigen jedes Format mit Beispielwerten und deinen aktuellen Einstellungen. `/vd formats` listet alle Formate im Chat.

Formate je Fenster (`/vd` > Formate je Fenster): Jede Gruppe (Spieler, Ziel, Fokus, Begleiter, Gruppenfenster, Ziel des Ziels, Bossfenster, Gruppenfenster im Schlachtzugsstil, Schlachtzugsfenster) hat ein eigenes Gesundheitsformat, eine eigene Option "Bei voller Gesundheit ausblenden" und, außer an den beiden Schlachtzugsarten, ein eigenes Energieformat. Standard ist "Wie allgemein" (das Format von der Seite Text). Ausnahme: Begleiter und Ziel des Ziels zeigen bei Gesundheit nur Prozent (`82%`), weil "Aktuell (Prozent)" auf den 70 Pixel breiten Leisten kaum Platz hat. "Aktuell / Max (Prozent)" bleibt wählbar, wird mit Millionenwerten im deutschen Client für kleine Leisten aber zu breit.

### Aussehen und Zahlen
- Stil (`/vd` > Allgemein): "Klar" (Standard) zeigt den Wert in der Textfarbe, " / Max" und " (Prozent)" in ruhigem Grau, z. B. `12,3k / 15k (82%)` mit grauem `/ 15k (82%)`. "Einfarbig" zeigt alles in einer Farbe. Das Grau steckt als Farbcode im Formattext und funktioniert deshalb auch mit gesperrten Werten.
- Textfarbe: Weiß (Standard), Nach Gesundheit (grün über 50 %, gelb über 20 %, sonst rot; nur bei lesbaren Werten, sonst Weiß) oder Klassenfarbe (nur bei Spielern).
- Große Zahlen abkürzen (an): Die Abkürzung kommt vom Spiel in deiner Sprache (`12K`, im deutschen Client `1,2 Mio.`). Aus: volle Zahlen mit Tausenderpunkt. Fehlt dem Client die Spielfunktion, kürzt Vitaldon selbst; der Dezimaltrenner folgt dann dem Client (`1,2k`).
- Nachkommastellen bei Prozent (0, 1 oder 2): `82%`, `82.3%`, `82.35%`. Prozent steht immer mit Punkt, weil das Format für gesperrte Prozentwerte direkt an das Spiel geht. Ein Komma wäre nur bei lesbaren Werten möglich und würde im Kampf zwischen `82,3%` und `82.3%` wechseln.
- Absorptionsschilde (`/vd` > Text > Gesundheit, Standard aus): Schilde wie Machtwort: Schild stehen in Hellblau hinter dem Gesundheitstext, z. B. `12,3k (82%) +3,4k`. Ohne Schild steht nichts da. Ist der Wert gesperrt, baut das Spiel den Text selbst (`C_StringUtil.TruncateWhenZero` und `C_StringUtil.WrapString`); die Zahl ist dann nicht abgekürzt (`+3400`). Fehlen diese Funktionen, bleibt der Schildteil leer.
- Druidenmana (`/vd` > Text, Standard an): Zeigt deine Energieleiste Energie oder Wut, steht dein Mana in Blau auf der anderen Seite derselben Leiste (Text mittig oder links: Mana rechts, Text rechts: Mana links). Format wählbar, Standard Prozent. Nur am eigenen Spielerfenster und nur, wenn dein Charakter Mana hat; bei gesperrtem Mana-Maximum nur für Druiden. Im Fahrzeug, als Tot oder in Gestalten mit Mana bleibt die Zeile leer.
- Text für Tot, Geist und Offline (Standard an): Zeigt "Tot", "Geist" oder "Offline" statt Zahlen. Zeigt Blizzard selbst "Tot" oder "Bewusstlos" (Ziel, Fokus, Boss, Ziel des Ziels, Schlachtzugsfenster), bleibt Vitaldons Gesundheitstext leer. An den Standard-Gruppenfenstern zeigt Vitaldon "Tot". Kennt das Spiel für eine Einheit noch kein Maximum, bleibt der Gesundheitstext leer statt `0 (0%)`.

### Schrift
Alles unter `/vd` > Schrift:
- Schriftart: "Wie der Leistentext von Blizzard" (Standard), Friz Quadrata, Arial Narrow, Skurri oder Morpheus (nur Schriften, die im Spiel enthalten sind). Lässt sich eine Schrift nicht laden, nimmt Vitaldon die Schrift des Leistentexts von Blizzard und sonst die von `GameFontNormal`.
- Schriftgröße: Standard 12. Energieleisten sind flacher, ihr Text ist einen Punkt kleiner (11), außer "Gleiche Größe auf Energieleisten" (Standard aus) ist an. Die Druidenmanazeile folgt dem Energietext.
- Schatten (Standard an) und Umrandung (Standard an). Der Text bleibt senkrecht mittig auf der Leiste. Die Position (links, mittig, rechts) stellst du für Gesundheit und Energie getrennt unter Text ein; links und rechts halten 4 Pixel Abstand zum Rand.
- Text an Leiste anpassen (Standard an): Ist ein Text breiter als seine Leiste (Begleiter, Ziel des Ziels, Gruppenmana, Bossfenster, lange Zahlen wie `1,2 Mio. / 1,5 Mio. (82%)`), wird er schrittweise kleiner, höchstens bis Größe 8, und wächst zurück, wenn er wieder passt (höchstens bis zur eingestellten Größe). Auf flachen Leisten begrenzt die Höhe die Größe (etwa das 1,4-Fache der Leistenhöhe). Aus: immer die eingestellte Größe. Es wird nur Vitaldons eigener Text gemessen, Blizzards Schriften und Leisten werden weder gelesen noch verändert. Mit gesperrten Werten kann das Spiel auch die Textbreite sperren: Vitaldon nutzt sie, wenn sie lesbar ist, und misst sonst mit einer unsichtbaren eigenen Schrift dasselbe Format mit lesbaren Beispielwerten (einmal je Format, Größe und Beispielwert, danach aus dem Speicher). Ist auch das nicht möglich, bleibt die eingestellte Größe. Es gibt kein Hin und Her zwischen zwei Größen.

### Bei voller Gesundheit ausblenden
Die Option gibt es allgemein (`/vd` > Text, Standard aus) und je Fenstergruppe (`/vd` > Formate je Fenster, unter jeder Überschrift): "Wie allgemein" (Standard), "Ausblenden" oder "Anzeigen". So lässt sich z. B. der Text am Spielerfenster und an Schlachtzugsfenstern bei voller Gesundheit ausblenden, am Ziel aber nicht. Sie gilt nur für den Gesundheitstext; die Vorschau (`/vd preview`) zeigt den Text immer.

Grenze: Die Option braucht einen Vergleich (aktuell gegen Maximum) und geht deshalb nur, wenn das Spiel die Werte lesbar liefert (Spielerfenster, meist außerhalb des Kampfs). Bei gesperrten Werten (Ziel, im Kampf auch die meisten anderen) bleibt der Text sichtbar, ohne Fehler. Vitaldon darf gesperrte Werte nicht vergleichen; ein Umweg über Kurven oder Transparenz ist nicht eingebaut, weil er sich ohne Client nicht prüfen lässt.

### Text über der Füllung
Vitaldons Text hängt als Kind direkt an der Leiste und liegt immer über ihr, auch über Füllungen anderer Addons (z. B. der eigenen Füllung von "Smooth Bars") und über Füllleisten daneben. Dafür liest Vitaldon nur Stufe und Ebene der Rahmen auf der Leiste und verändert sie nie. Geprüft wird sofort, wenn die Leiste ihre Stufe ändert oder ein neuer Rahmen auf ihr liegt (Klick auf Welt oder Ziel, Zielwechsel), sonst alle 5 Sekunden je Leiste.

"Text immer im Vordergrund" (`/vd` > Allgemein > Ebene, Standard an): Liegt ein Rahmen eines anderen Addons in einer höheren Ebene auf der Leiste oder reicht die Stufe nicht mehr, hebt Vitaldon seinen Text eine Ebene über die Leiste, nur dann. Nachteil: In dieser Ebene kann der Text auch über Fenstern stehen, die das Einheitenfenster verdecken. Aus: Der Text bleibt in der Ebene der Leiste.

### Zusammenspiel mit anderen Addons
- Ausblenden und Durchsichtigkeit (Forever Clean UI, BetterBlizzFrames und ähnliche): Der Text ist ein Kind der Leiste und erbt deren Alpha und Sichtbarkeit. Wird das Spielerfenster ausgeblendet oder durchsichtig gemacht, verschwindet der Text mit. Vitaldon setzt selbst nie Alpha und nie "Alpha des Elternrahmens ignorieren".
- Versteckt ein Addon Blizzards Leiste und zeigt eine eigene, zeigt `/vd diag` "von anderem Addon ersetzt". Vitaldon schreibt nur auf Blizzards eigene Leisten. Für solche Fenster dann den Text des anderen Addons nutzen.
- BetterBlizzFrames (am Quellcode geprüft, github.com/Bodify/BetterBlizzFrames, Stand 26.09.2026, mit eigener Forever-TOC `BetterBlizzFrames_Camelot.toc`):
  - "Smooth Bars" legt eine eigene Füllleiste als Kind auf Blizzards Leiste (gleiche Stufe) und macht Blizzards Füllung durchsichtig. Vitaldons Text liegt darüber.
  - "Classic Frames" und "No Portrait": eigene Rahmengrafik in Ebene MEDIUM (Stufe 9996) bzw. HIGH über dem Fenster, Blizzards Leistentexte werden dorthin umgehängt. Die Rahmengrafik ist über den Leisten offen. Der Pixelrahmen ("No Portrait") liegt als Kind der Leiste in MEDIUM, dann hebt "Text immer im Vordergrund" den Text eine Ebene an. Auch Leisten auf Stufe 9998 (Ziel des Ziels im Classic-Stil) bleiben unter dem Text.
  - "Zahlen formatieren" und "Current HP Only & Center on Bars" schreiben Blizzards eigenen Leistentext. Die zweite Option schaltet Blizzards Statustext dauerhaft ein (`statusTextDisplay` = `BOTH`); Vitaldons Knopf "Statustext von Blizzard ausschalten" hält dann nicht. Entweder in BetterBlizzFrames ausschalten oder Vitaldon für diese Fenster abschalten. Vitaldon weist einmal im Chat darauf hin.
  - Vitaldon liest nur, ob BetterBlizzFrames geladen ist, und dessen Einstellungstabelle. Nichts davon wird geändert.
- Blizzards Statustext (Optionen > Interface > Statustext) kann sich mit Vitaldons Text überlagern. Dann zeigt `/vd` einen Hinweis und den Knopf "Statustext von Blizzard ausschalten" (im Kampf gesperrt).

## Bedienung
- `/vd` oder `/vitaldon`: Optionen (auch Esc > Optionen > AddOns > Vitaldon). `/vd options` und `/vd config` tun dasselbe. Im Kampf lassen sich die Optionen nicht öffnen.
- Seiten: Allgemein (Stil, Textfarbe, Zahlen, Zustände, Ebene), Einheiten, Text (Gesundheit, Energie, Druidenmana), Formate je Fenster, Schrift. Dazu zeigen die Optionen den Status (Version, gefundene Leisten, Blizzards Statustext) und Werkzeuge.
- Werkzeuge: "Statustext von Blizzard ausschalten" (setzt `statusTextDisplay` auf `NONE` und `statusText` auf `0`, wie Blizzards Auswahl "Keiner"; nur auf Klick, im Kampf nicht möglich), "Einheitenfenster neu suchen", "Format-Vorschau", "Alle Formate zeigen" und "Diagnose".
- `/vd preview`: Beispielwerte für 5 Sekunden auf deinem Spielerfenster (wie das Werkzeug "Format-Vorschau"), um Format, Position, Farbe und Schrift ohne Kampf zu sehen.
- `/vd formats`: alle Formate mit Beispielwerten und deinen Einstellungen im Chat.
- `/vd refresh`: Einheitenfenster neu suchen.
- `/vd help`: Befehle (auch `/vd ?`). Unbekannte Befehle melden "Unbekannter Befehl" und zeigen diese Liste.
- `/vd diag`: Diagnosefenster mit den Abschnitten Allgemein, Leisten, Werte, Funktionen und Fehler (Kopf zum Verschieben, Position wird gespeichert). Eine Zeile pro Einheit, die Pfade stehen im Tooltip. Der Tooltip jeder Leiste nennt, woran der Text hängt, Stufe und Ebene von Leiste und Text, andere Rahmen auf der Leiste, die Schriftgröße (an Breite angepasst oder Leistenhöhe), woher die Textbreite kam (lesbar, gesperrt mit Beispielwerten gemessen oder kein Beispiel) und "Deckkraft Leiste / Text". Steht der Text deutlich über der Leiste, ignoriert ein anderes Addon die Deckkraft des Elternrahmens (Warnfarbe). Unten steht ein Bericht zum Kopieren (Strg+A, Strg+C). Keine Namen.
- `/vd diag chat`: dieselben Angaben im Chat: welche Leisten gefunden wurden (und über welchen Pfad), welche Spielfunktionen es gibt, ob die Werte jeder Einheit gerade gesperrt sind, Stand des Blizzard-Statustexts, die Zahlenabkürzung (Ausgabe des Spiels für 12.345 und 1.234.567) und abgefangene Fehler.
- Meldungen der Diagnose: "von anderem Addon ersetzt" gilt nur mit Beleg (eine fremde sichtbare Leiste daneben oder geladenes BetterBlizzFrames). Sonst steht neutral "Leiste verborgen (keine Energie)" (z. B. Gegner ohne Mana) oder "Leiste von Blizzard verborgen". Ist die Leiste durchsichtig, weil das ganze Fenster ausgeblendet ist, steht "Leiste durchsichtig (Fenster ausgeblendet)". Gesperrte Werte des Ziels, auch außerhalb des Kampfs, werden als normal erklärt.
- Bearbeitungsmodus: Nach Änderungen am Layout sucht Vitaldon die Leisten neu. Ersetzt Blizzard eine Leiste (z. B. Gruppenfenster neu aufgebaut), merkt Vitaldon das spätestens nach 2 Sekunden. Beim Verschieben und Skalieren folgt der Text der Leiste, weil er ihr Kind ist; nach einer Größenänderung passt sich die Textgröße mit dem nächsten Wert an.
- Fehlerschutz: Ein Fehler in Vitaldon bricht nichts anderes ab. Wiederholte Fehler werden nur gezählt, nach 10 verschiedenen werden weitere nur gezählt ("Weitere Fehler, nicht aufgeführt"), eine nicht lesbare Meldung zählt als "(unreadable error)". Im Chat steht höchstens eine Zeile pro Sitzung. Einheitenereignisse gehen nur an die Leisten der betroffenen Einheit.

## So funktioniert es (Secret Values)
Seit den Addon-Regeln von "Midnight" (12.x, gilt auch für Forever) sind manche Werte für Addons gesperrt ("Secret Values"), z. B. Gesundheit und Energie anderer Einheiten im Kampf. Addons dürfen mit gesperrten Werten nicht rechnen und nicht vergleichen, sie aber an bestimmte Funktionen weitergeben.

Vitaldon rechnet deshalb nie mit diesen Werten:
- Prozent kommt vom Spiel selbst: `UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)` und `UnitPowerPercent(unit, nil, false, CurveConstants.ScaleTo100)`.
- Zahlen werden nur formatiert: `AbbreviateNumbers` (abgekürzt) bzw. `BreakUpLargeNumbers` (mit Tausenderpunkt), notfalls `tostring`.
- Fehlbetrag kommt von `UnitHealthMissing` / `UnitPowerMissing`.
- Der fertige Text geht über `FontString:SetFormattedText` in Vitaldons eigene Schrift.
- Sind die Werte lesbar (meist außerhalb des Kampfs, eigener Charakter), rechnet Vitaldon selbst, wo eine Spielfunktion fehlt.
- Jeder Aufruf ist geschützt (pcall). Lehnt das Spiel einen Wert ab, bleibt der Text leer, statt einen Fehler zu werfen.

Grenzen mit gesperrten Werten:
- "Bei voller Gesundheit ausblenden" (allgemein und je Fenster) braucht einen Vergleich und wirkt nur bei lesbaren Werten.
- Fehlbetrag zeigt bei gesperrten Werten auch "-0" statt leer.
- Leere Energieleisten (Maximum 0) werden nur bei lesbaren Werten ausgeblendet.
- Ein gesperrter Wert für Tot/Geist zählt als "lebt", dann stehen Zahlen da. Ein gesperrtes "Tot" von Blizzard zählt als nicht angezeigt.
- Gesperrte Schilde erscheinen ohne Abkürzung, weil nur `TruncateWhenZero` leer bei 0 liefert.

Gesperrte Rahmenwerte von Blizzard (Sichtbarkeit, Stufe, Ebene, Elternrahmen, Rahmentyp, angezeigte Einheit) behandelt Vitaldon so, dass der Text nicht still verschwindet:
- Gesperrte Sichtbarkeit einer Leiste zählt als sichtbar. Der Text ist ein Kind der Leiste, das Spiel blendet ihn mit der Leiste ohnehin aus.
- Gesperrte Ebene oder Stufe der Leiste: Vitaldon lässt Ebene und Stufe seines Texts unverändert (das Spiel legt ein Kind über die Leiste). `/vd diag` zeigt dafür "nicht lesbar".
- Gesperrte Einheit eines Gruppen- oder Schlachtzugsfensters im Schlachtzugsstil: Die zuletzt gelesene Einheit gilt weiter.
- Gesperrter Rahmentyp: Eine Leiste wird am Statusleisten-Merkmal erkannt, gefundene Leisten bleiben nach `/vd refresh` und dem Bearbeitungsmodus erhalten.
- Gesperrte Klassenfarbtabelle: Ersatz über die Klassenfarben des Spiels, sonst Weiß.

## Was Vitaldon nicht tut
Vitaldon verändert Blizzards Oberfläche nicht: keine Hooks, keine ersetzten Funktionen, keine Skripte an Blizzard-Fenstern, keine Änderung an Blizzards Texten, keine geschützten Funktionen. Vitaldon legt eigene Rahmen mit eigener Schrift auf die Leisten: Der eigene Rahmen hängt als Kind an der Leiste, liegt 20 Stufen über ihr und über jedem anderen sichtbaren Rahmen auf ihr, in der Ebene der Leiste (mit "Text immer im Vordergrund" bei Bedarf eine Ebene höher). Der Rahmen ist nicht geschützt, deshalb darf er auch im Kampf an die Leiste gehängt und eingeordnet werden. Skalierung und Deckkraft kommen von der Leiste. Ist die Leiste unsichtbar, ist es auch der Text. Von Blizzards und fremden Rahmen wird nur gelesen (Stufe, Ebene, Sichtbarkeit, Deckkraft, Kinder und deren Anzahl, bei Gruppen- und Schlachtzugsfenstern im Schlachtzugsstil die angezeigte Einheit und die Option für Blizzards Gesundheitstext).

Blizzards Statustext (Optionen > Interface > Statustext) zeigt bei Mausberührung oder dauerhaft eigenen Text auf den Leisten. Vitaldon ändert diese Einstellung nur, wenn du in den Optionen auf "Statustext von Blizzard ausschalten" klickst.

## Gefundene Leisten
Geprüft gegen Blizzards Quellcode (Gethe/wow-ui-source, Zweig "forever", zuletzt am 02.10.2026), mit Ersatzpfaden. Forever lädt laut `Blizzard_UnitFrame.toc` die Mainline-Vorlagen; die eigenen Camelot-Dateien (`Camelot/PlayerFrameTemplates.xml`, `Camelot/TargetFrameTemplates.xml`, `Camelot/PlayerFrame.lua`, `Camelot/TargetFrame.lua`) ändern nur Stufenkreis, PvP-Symbol und Namensbreite, nicht die Leisten:
- Spieler: `PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.HealthBar` und `...PlayerFrameContentMain.ManaBarArea.ManaBar`
- Ziel und Fokus: `TargetFrame/FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar` und `...TargetFrameContentMain.ManaBar`; Blizzards "Tot" und "Bewusstlos" in `HealthBarsContainer.DeadText` / `.UnconsciousText` (Mainline/TargetFrame.xml, `TargetFrameMixin:CheckDead`)
- Ziel des Ziels: `TargetFrame.totFrame.HealthBar` / `.ManaBar` (bzw. `TargetFrameToT`), "Tot" in `HealthBar.DeadText`
- Ziel des Fokus: `FocusFrame.totFrame.HealthBar` / `.ManaBar` (bzw. `FocusFrameToT`)
- Begleiter: `PetFrameHealthBar`, `PetFrameManaBar`
- Gruppe: `PartyFrame.MemberFrame1..4.HealthBarContainer.HealthBar` und `.ManaBar` (Shared/PartyFrame.lua vergibt `MemberFrame1..4` per `SetParentKey`, Vorlage Mainline/PartyFrameTemplates.xml). Kein eigener Totentext von Blizzard, dort zeigt Vitaldon "Tot".
- Bosse: `Boss1TargetFrame..Boss5TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar` und `...TargetFrameContentMain.ManaBar` (gleiche Vorlage wie das Zielfenster)
- Gruppenfenster im Schlachtzugsstil: `CompactPartyFrameMember1..5.healthBar`, Einheit aus `.displayedUnit` bzw. `.unit` (Shared/CompactPartyFrame.xml, Shared/CompactUnitFrame.xml)
- Schlachtzugsfenster: `CompactRaidFrame1..80.healthBar` und `CompactRaidGroup1..8Member1..5.healthBar` (Blizzard_CompactRaidFrameContainer.lua, Shared/CompactRaidGroup.xml)
- Arenafenster: im Forever-Client nicht geladen (Blizzard_UnitFrame.toc: `CompactArenaFrame` mit `ExcludeLoadGameType camelot`)

Fehlt eine Leiste, sucht Vitaldon beim Betreten der Welt, bei Gruppenänderungen und alle 2 Sekunden erneut. Begleiter, Ziel des Ziels und Ziel des Fokus werden zusätzlich viermal pro Sekunde aufgefrischt, weil der Client für sie nicht zuverlässig Ereignisse sendet.

## Noch nicht im Spiel geprüft
- Ob `AbbreviateNumbers`, `BreakUpLargeNumbers` und `SetFormattedText` gesperrte Werte im Forever-Client wirklich annehmen (laut warcraft.wiki.gg ja, `BreakUpLargeNumbers` dort nicht ausdrücklich gelistet).
- Ob `UnitHealthMissing` / `UnitPowerMissing` in Forever existieren (sonst bleibt der Fehlbetrag bei gesperrten Werten leer).
- Ob die Ebene/Stufe über allen Rahmentexturen liegt und die Position bei verschobenen Fenstern (Bearbeitungsmodus) stimmt.
- Gruppen- und Schlachtzugsfenster im Schlachtzugsstil: Pfade und Felder stammen aus dem Quellcode, im Forever-Client noch nicht gesehen (Schlachtzug erst mit einer Schlachtzugsgruppe in der Welt prüfbar).
- Abkürzung in deutscher Sprache (Ausgabe stammt vom Spiel). Erwartet laut den deutschen GlobalStrings des aktuellen Clients (Ketho/BlizzardInterfaceResources, `FIRST_NUMBER_CAP_NO_SPACE = "K"`, `SECOND_NUMBER_CAP_NO_SPACE = " Mio."`): `12K`, `1,2 Mio.`. `/vd diag` zeigt die echte Ausgabe.
- Ob das Spiel die Breite gesperrter Texte freigibt (`/vd diag`, Tooltip einer Zielzeile, Textbreite "lesbar") oder der Ersatzweg mit Beispielwerten greift.
- Fahrzeug: ob `PlayerFrame.unit` in Forever auf "vehicle" wechselt (sonst entscheidet `UnitHasVehicleUI`).
- Ob alle vier Schriftdateien (`FRIZQT__`, `ARIALN`, `SKURRI`, `MORPHEUS`) im Forever-Client unter `Fonts\` liegen.
- `EDIT_MODE_LAYOUTS_UPDATED` gibt es laut Quellcode im Zweig "forever" (Blizzard_EditMode/Shared/EditModeManager.lua). Es kommt beim Laden und Speichern eines Layouts, nicht während des Ziehens; beim Verschieben und Skalieren folgt der Text der Leiste ohnehin.
- Bossfenster: ob Forever-Begegnungen Blizzards Bossfenster zeigen und ob `INSTANCE_ENCOUNTER_ENGAGE_UNIT` kommt (sonst erscheint der Text über die Prüfung viermal pro Sekunde).
- Schilde: ob `UnitGetTotalAbsorbs` im Forever-Client gesperrt liefert und ob `C_StringUtil.TruncateWhenZero` / `C_StringUtil.WrapString` gesperrte Werte aus Addon-Code annehmen (laut warcraft.wiki.gg in Forever 1.60.1 bzw. 12.1 vorhanden, Verhalten mit gesperrten Werten nicht dokumentiert).
- Druidenmana: ob `UnitPower("player", Enum.PowerType.Mana)` in Katzen- und Bärengestalt im Kampf lesbar oder gesperrt ist, und ob die Manazeile neben langen Energietexten genug Platz hat.
- Aussehen: ob Schatten und das Grau der Details (`|cffc4c8cf`) auf allen Leistenfarben gut lesbar sind, und ob Farbcodes in `SetFormattedText` mit gesperrten Werten im Forever-Client wie erwartet angezeigt werden.

## Im Spiel prüfen
- Bei voller Gesundheit ausblenden: `/vd` > Formate je Fenster > Spieler > "Bei voller Gesundheit ausblenden" auf "Ausblenden". Außerhalb des Kampfs verschwindet der Gesundheitstext bei voller Gesundheit, der Energietext bleibt, unter voller Gesundheit erscheint er sofort wieder. Beim Ziel (gesperrte Werte) bleibt der Text, auch bei "Ausblenden". Bitte melden, ob andere Fenster (Gruppe, Fokus) lesbare Werte liefern. Allgemeine Option auf der Seite Text einschalten und einem Fenster "Anzeigen" geben: Nur dieses Fenster zeigt den Text bei voller Gesundheit.
- Forever Clean UI oder ein ähnliches Addon, das das Spielerfenster ausblendet: Der Text darf nicht stehen bleiben und nicht flackern, weder beim Ausblenden noch beim Einblenden (Maus darüber, Kampfbeginn). Ein ausgeblendetes Fenster mit sichtbarem Text bitte mit `/vd diag` melden (Tooltip der Spielerzeile, Zeile "Deckkraft Leiste / Text"). Dort steht bei ausgeblendetem Fenster "Leiste durchsichtig (Fenster ausgeblendet)" oder keine Meldung, nicht "von anderem Addon ersetzt".
- Text an Leiste anpassen: Ziel des Ziels und Begleiter einschalten, unter Formate je Fenster "Aktuell / Max (Prozent)" wählen. Der Text wird kleiner und bleibt innerhalb der Leiste (ab Größe 8 darf er überstehen), bei "Prozent" ist wieder Größe 12. Im Kampf gegen einen Boss oder Elite (große Zahlen) passt der Text auf Ziel- und Bossfenster, ohne Fehlermeldung und ohne Größensprünge bei jedem Treffer.
- Prozent: Nachkommastellen auf 1 stellen. Die Anzeige hat einen Punkt (`82.3%`), auch im deutschen Client.

## Hinweise
Der Beta-Client lädt SavedVariables derzeit zeitweise nicht (Fehler des Clients, nicht von Vitaldon). Solange das so ist, erscheint die Startzeile im Chat bei jedem Einloggen.

## Lizenz
MIT License, Copyright (c) 2026 DonCoohd. Frei nutzbar, veränderbar und weitergebbar, solange dieser Hinweis erhalten bleibt. Ohne Gewähr.
