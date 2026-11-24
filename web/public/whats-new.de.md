# 0.3.3

Cardwave weiß jetzt, wie viel jede KI auf einmal liest, und du wählst, wie viel sie nachdenkt, und färbst deine Chats.

- In Einstellungen › Anbieter bietet ein Modell, das mehr oder weniger nachdenken kann, jetzt Aus, Leicht, Normal oder Gründlich an, für jedes Modell gemerkt. Wo ein Anbieter das Nachdenken für ein Modell nicht ausschalten kann, sagt Cardwave es dir.
- Neu im Ansichtsmenü: „Farben der Chatnachrichten“ (Aus, Hell oder Dunkel) zeigt Gesprochenes in Anführungszeichen, Kursives, Fettes, Links und Code in eigenen Farben, im Chat einer Figur und im Begleiter.
- Eine Antwort, die an ihrer Längengrenze abbricht, endet jetzt beim letzten ganzen Satz. Eine Antwort, die an der eigenen Grenze der KI stoppt, bleibt so, wie sie kam, mit einer grauen Zeile darunter, die es sagt, und „Diese Antwort fortsetzen“ macht beim letzten Wort weiter.
- Wenn das Hilfsmodell das Gedächtnis eines Chats nicht behalten kann, sagt dir der Chat, warum.
- Lange Chats mit einem Claude-Modell über OpenRouter oder NanoGPT kosten weniger und antworten schneller, durch Prompt-Caching.
- In einer Programmieraufgabe stehen die Zeilen jedes Schritts in deiner Sprache, und Webseiten werden genauer gelesen.
- Jede Antwort passt zu dem, was ihr Modell lesen kann. Cardwave nimmt die Größe aus seiner eingebauten Modellliste oder fragt eine KI auf deinem Computer (LM Studio, Ollama oder KoboldCpp) oder in deinem lokalen Netz selbst. Bisher bekam jedes Modell 128.000 Tokens.
- Ein langer Chat mit einem Modell, das mehr liest, behält jetzt mehr von seinem Verlauf.
- Wo die Größe einer KI nicht bekannt ist, sagt es dir die Antwort, und du legst sie einmal als Kontextgröße in Einstellungen › Erweitert fest. Bis dahin wird nichts gesendet.
- Die Kontextgröße in Einstellungen › Erweitert begrenzt jetzt, was an jedes Modell gesendet wird.

# 0.3.2

Das Gesicht des Begleiters wird lebendig, und er antwortet auf deine Berührung.

- Eine 3D-Figur mit Gesichtsformen blinzelt, schaut dich an und zeigt ihre Gefühle und ihre Stimme im Gesicht, bei VRM, GLB und FBX.
- Ohne Stimme bewegen sich die Lippen des Begleiters trotzdem, während eine Antwort hereinkommt.
- Klicke auf den Kopf des Begleiters, eine Hand oder einen anderen Teil seines Körpers: Er schreckt auf, und die Figur antwortet in ihrer Sprechblase. Ein Doppelklick öffnet weiterhin den Chat.
- In jeder Größe steht, liegt und geht der Begleiter mit den Füßen auf dem unteren Fensterrand und rutscht beim Gehen nicht mehr.
- Eine VRM-Figur, die du hinzufügst, nennt ihren Urheber.
- Die Seitenleiste des Chats listet jedes Werkzeug, das eine Antwort benutzt hat, unter „In dieser Antwort verwendet“.
- Neu in Einstellungen › Erweitert › Werkzeuge für die KI: „Namen für neue Figuren“ lässt die KI den Namen jeder neuen Figur aus einer großen Liste nehmen, passend zu Kultur, Epoche und Genre.

# 0.3.1

Eine kleine Korrektur für Linux.

- Wenn das Vorlesen unter Linux nicht starten kann, bittet dich Cardwave jetzt, es neu zu installieren, statt nach einem Teil von Microsoft zu fragen, den es unter Linux nicht gibt.

# 0.3.0

Cardwave unter Linux.

- Cardwave läuft unter Linux: Die Release-Seite hat ein AppImage, das auf den meisten Linux-Computern läuft, und ein .deb, das sich unter Ubuntu und Debian installiert.
- Auch unter Linux werden Gesichter auf deiner Grafikkarte gefunden, das Mikrofon funktioniert in Cardwaves Fenster, und die Programmierwerkzeuge der KI führen Befehle aus.
- Kleine Korrekturen: Die Knöpfe oben auf einer Seite passen in ein schmales Fenster, und das Kontomenü bleibt offen, während deine Konten laden.

# 0.2.0

Cardwave auf dem Handy und viele Korrekturen.

- Cardwave von überall öffnen: Mit Tailscale zeigt Konto › Freigabe die Adresse, unter der es sich auf dem Handy oder einem anderen Computer öffnet, und jeder Bildschirm passt auf ein Handy.
- Erinnerungen gehören zu einer Figur und deiner Persona: Wechselt ein Chat die Persona, beginnen neue Erinnerungen, und beim Zurückwechseln sind die alten wieder da.
- Der Begleiter bewegt sich mehr: viel mehr Bewegungen, nach seiner Stimmung gewählt, und vier weitere Gefühle: ängstlich, verspielt, schüchtern und müde.
- 3D-Figuren werden mit WebGPU gezeichnet, wo dein Computer es kann.
- Eine Sicherung lässt sich gleich beim ersten Start wiederherstellen, und eine wiederhergestellte Sicherung behält ihr Passwort.
- Aufgeräumtere Einstellungen: Die Werkzeuge der KI stehen jetzt unter Erweitert, und die Tabs lassen sich unter Einstellungen › Darstellung ausschalten.
- Die Texte einer Figur zeigen „Zum Bearbeiten klicken“, wenn du auf sie zeigst, und das Symbol in der Taskleiste füllt sein Feld.
- Viele Korrekturen aus einer Suche durch die ganze App.

# 0.1.3

Kleine Korrekturen.

- Wird Cardwave gestartet, während es schon offen ist, kommt sein Fenster nach vorn; kann es nicht starten, weil andere Programme seine Ports belegen, sagt es das.
- Besser lesbar: die Worte auf blauen Schaltflächen und die Hinweise auf leere Felder im dunklen Design, deine Initialen im hellen Design.
- Chats: Würfel, Zufallswahlen und Variablen in einer gesendeten Nachricht bleiben in jeder späteren Antwort, wie sie waren.
- Datum und Uhrzeit in der Bibliothek und auf der Seite eines Charakters folgen deiner Sprache.
- Das Diktat hört auch ein einzelnes kurzes Wort, und lange Sätze ohne Satzzeichen werden ganz vorgelesen.

# 0.1.2

Weitere Korrekturen aus einer dritten Testrunde.

- Erinnerungen: Was du geändert oder gelöscht hast, bleibt, wenn eine frühere Nachricht bearbeitet wird, und ein umbenannter Charakter oder eine umbenannte Persona behält, woran sie sich erinnern.
- Chats: Während des Sendens getippte Worte bleiben im Feld, das Diktat behält seine letzten Worte, wenn du den Tab wechselst, und Daten in Begrüßungen folgen deiner Sprache.
- Klarere Meldungen, wenn ein Modell auf diesem Computer seinen Test nicht besteht, wenn der Server eines Downloads versagt und wenn die Suche nach Updates nicht abgeschlossen werden kann.
- Tabs passen in ein schmales Fenster, wie auch immer es schmal wurde.

# 0.1.1

Korrekturen aus einer zweiten Testrunde.

- Backups: Eine Wiederherstellung wartet auf Arbeit, die noch läuft, und eine Backup-Datei trägt dein eigenes Datum.
- Erster Start: Ein in den Einstellungen hinzugefügter Anbieter geht weiter zur Wahl seiner Modelle, ein abgelehnter Schlüssel wird als abgelehnt gemeldet, und eine neue Einrichtung mit korrigiertem Schlüssel behält einen Anbieter.
- Chats: Ein Charakter, der für das Modell zu lang ist, wird gemeldet statt weggelassen; angehängte Bilder werden einmal verkleinert und bleiben angehängt, wenn du den Chat verlässt.
- Der Passwortbildschirm und die Anmeldung anderer Geräte in deiner Sprache, und Einstellungen, die auf die Breite eines Handys passen.
- Viele kleinere Korrekturen an Texten, Tabs, Bildern und Importen.

# 0.1.0

Cardwave, von Grund auf neu gemacht: Chatte mit den Charakteren deiner Bibliothek, mit Modellen auf diesem Computer oder bei einem Anbieter.

- Deine Bibliothek: Importiere SillyTavern- und CCV4-Karten oder erstelle eigene, und finde sie über ihre Worte oder ihre Bedeutung.
- Chats mit einem Charakter oder mehreren, die abwechselnd oder von selbst antworten, mit Versionen, anderen Verläufen, Personas und Lorebooks.
- Jeder Anbieter: Füge einen API-Schlüssel ein, und Cardwave erkennt, von wem er ist, oder wähle ein GGUF-Modell auf diesem Computer.
- Erinnerungen: Charaktere behalten, was in deinen Chats geschah.
- Stimmen: Antworten werden auf diesem Computer vorgelesen, in der eigenen Stimme jedes Charakters, und Diktieren.
- Werkzeuge, so wie du sie einschaltest: Websuche, die Dateien eines Ordners, Bilder.
- Zwölf Sprachen, ein helles und ein dunkles Erscheinungsbild, ein Passwort und Sicherungen.
