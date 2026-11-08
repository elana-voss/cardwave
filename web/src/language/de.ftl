### Die Wörter der Oberfläche auf Deutsch, übersetzt aus dem Englischen (en.ftl, die goldene Datei), Schlüssel für
### Schlüssel; der Strukturtest (structure.test.ts) prüft, dass alles da ist und gleich gebaut ist.
### Wortliste, ein Name je Ding, in allen de.*.ftl:
###   Anrede: du (klein, wie in Apps üblich); vom Nutzer nie mit Geschlecht (kein „Nutzer/Nutzerin“, sondern du).
###   Cardwave, MCP, Claude Desktop, CSS, Lorebook, Persona(s), Prompt, Preset, Chat, Tab: bleiben so.
###   character = Charakter (die Figur in Chats); card = Karte (die Datei, Charakterkarte); figure = Figur (3D).
###   memory = Erinnerung; document = Dokument; library = Bibliothek; knowledge = Wissen; account = Konto.
###   provider = Anbieter; model = Modell; helper (model) = Hilfsmodell; AI = KI; tool = Werkzeug.
###   Settings = Einstellungen; Advanced = Erweitert; Trash = Papierkorb (der von Cardwave);
###   Recycle Bin = Windows-Papierkorb; backup = Sicherung; restore = wiederherstellen; Sharing = Freigabe.
###   companion = Begleitung; voice = Stimme; dictation = Diktat; Search Cardwave = Cardwave durchsuchen.
###   coding team = Programmierteam; planner = Planer; worker = Arbeiter; auditor = Prüfer; task = Aufgabe.
###   sign in = anmelden; sign out = abmelden; lock = sperren; import = importieren; export = exportieren.
###   interview = Interview; generator = Charaktergenerator; theme = Erscheinungsbild; first run = Ersteinrichtung.
###   Rollen anderer Personen: beide Formen (Freund/in, Kollege/Kollegin, meinem/meiner Ex), nie nur eine.

## The app

app-name = Cardwave

## The pages, as tabs, the rail and Search Cardwave name them (shell/pages.ts)

page-chats = Chats
page-characters = Charaktere
page-lorebooks = Lorebooks
page-personas = Personas
page-memories = Erinnerungen
page-documents = Dokumente
page-generator = Charaktergenerator
page-interview = Gemeinsam einen Charakter erstellen
page-profile = Profil
page-server = Freigabe
page-settings = Einstellungen
page-providers = Anbieter
page-voices = Stimmen
page-advanced = Erweitert
page-css = Cardwaves CSS
page-written-tools = Werkzeuge der KI
page-coding-team = Programmierteam
page-trash = Papierkorb
page-about = Über Cardwave
page-coding-task = Programmieraufgabe
page-chat = Chat
page-new-card = Neuer Charakter
page-lorebook = Lorebook
page-card = Charakter
page-prompt-preset = Prompt-Preset
page-first-run = Cardwave einrichten

## The places pages are under

place-library = Bibliothek
place-knowledge = Wissen
place-account = Konto
place-settings = Einstellungen
place-advanced = Einstellungen › Erweitert

## The rail (shell/rail.ts)

rail-create = Erstellen
rail-memories-tip = Erinnerungen: was die KI aus deinen Chats behält
rail-documents-tip = Dokumente: Dateien, die die KI beim Antworten liest
rail-show-more = { $count } weitere zeigen
rail-open-menu = Seitenleiste öffnen
rail-close-menu = Seitenleiste schließen
rail-collapse = Seitenleiste einklappen
rail-expand = Seitenleiste ausklappen
rail-account = Konto
rail-account-named = Konto: { $name }
rail-lock = Sperren

## Create's lines (shell/create.ts)

create-new-chat = Neuer Chat
create-plain-chat = Chat ohne Charakter
create-new-card = Neuer Charakter
create-from-picks = Charaktergenerator
create-together = Gemeinsam einen Charakter erstellen
create-new-persona = Neue Persona
create-new-lorebook = Neues Lorebook
create-import-card = Karte importieren
create-import-lorebook = Lorebook importieren
create-new = Neu
create-import = Importieren

## The title bar and its tabs (shell/titlebar.ts)

tabs = Tabs
tab-new = Neuer Tab
tab-new-keys = Neuer Tab (Strg+T)
tabs-all = Alle Tabs
tab-close = Tab schließen
window-minimize = Minimieren
window-maximize = Maximieren
window-close = Schließen

## The view menu (shell/view-menu.ts, theme.ts)

view = Ansicht
view-compact = Kompakt
theme-system = System
theme-light = Hell
theme-dark = Dunkel
theme-downtempo = Downtempo
theme-outrun = Outrun
theme-retrowave = Retrowave
theme-neonwave-dark = Neon Wave dunkel
theme-neonwave-light = Neon Wave hell

## Search Cardwave's button (shell/search-panel.ts)

search = Cardwave durchsuchen
search-keys = Cardwave durchsuchen (Strg+K)

## The labels of the settings, as their pages and Search Cardwave name them (setting-labels.ts)

label-settings-theme = Erscheinungsbild
label-settings-chat-layout = Chat-Layout
label-settings-web-pictures = Bilder von anderen Websites zeigen
label-settings-app-language = Sprache der App
label-settings-language = Sprache, in der die KI schreibt
label-settings-providers = Anbieter
label-settings-chat = Chat
label-settings-images = Bilder
label-settings-voice = Stimme
label-settings-search = Suche
label-settings-dictation = Diktat
label-settings-web = Web
label-settings-files = Dateien
label-settings-commands = Befehle
label-settings-image-generation = Bilderzeugung
label-settings-app = Cardwave
label-settings-dice = Würfel
label-settings-folder = Ordner
label-settings-written = Werkzeuge der KI
label-settings-coding = Programmierteam
label-settings-trash = Papierkorb
label-settings-backup = Sicherung
label-settings-restore = Wiederherstellen
label-settings-cards-folder = Kartenordner
label-settings-advanced = Erweitert
label-settings-setup = Einrichtung erneut starten
label-settings-about = Über Cardwave
label-providers-this-computer = Dieser Computer
label-voices-model = Stimmmodell
label-voices-speed = Tempo
label-voices-english = Englisch
label-advanced-background = Hilfsmodell
label-advanced-told = Was die KI gesagt bekommt
label-advanced-describe = Importierte Charaktere beschreiben
label-advanced-described = Beschriebene Charaktere
label-advanced-interview = Gemeinsam einen Charakter erstellen
label-advanced-format = Exportformat
label-advanced-history = Frühere Fassungen jedes Textes mitnehmen
label-advanced-css = Dein eigenes CSS
label-coding-planner = Planer
label-coding-workers = Arbeiter
label-coding-auditor = Prüfer
label-profile-name = Name
label-profile-picture = Bild
label-profile-password = Passwort
label-server-network = Im Heimnetz erreichbar
label-server-address = Adresse
label-server-mcp = KI-Apps auf diesem Computer Cardwave nutzen lassen

layout-bubbles = Sprechblasen
layout-plain = Schlicht

## Settings (views/settings.ts)

settings-appearance = Darstellung
settings-theme-about = Folgt dem System, außer du wählst eines
settings-layout-about = Nachrichten als Sprechblasen oder als schlichter Text
settings-web-pictures-about = Diese Websites können sehen, wann du den Chat öffnest.
settings-language = Sprache
settings-data = Daten
settings-trash-about = { $count ->
    [one] 1 Element
   *[other] { $count } Elemente
  } · geleert nach { $days } Tagen
settings-open-trash = Papierkorb öffnen
settings-open = Öffnen
settings-version = Version { $version } · Lizenzen
settings-licences = Lizenzen
settings-advanced-about = Hilfsmodell, Bibliothek, Export, Chat ohne Charakter, Sampling, Presets, dein eigenes CSS
settings-setup-about = Anbieter, Modelle und Stimme, Schritt für Schritt
settings-providers-about = Adressen und Schlüssel der Dienste, die die Modelle ausführen
settings-this-computer = dieser Computer
settings-providers-named = Eingerichtet: { $names }
settings-models = Modelle
settings-the-chat-model = das Chatmodell
settings-the-image-model = das Bildmodell

## The account's tabs and accounts (shell/account-tabs.ts, settings/accounts.ts)

account-sections = Bereiche des Kontos
account-switch = Konto wechseln

account-password = Passwort
account-switch-to = Zu { $name } wechseln
account-password-asked = Gib das Passwort von { $name } ein.
account-switch-button = Wechseln
account-add = Konto hinzufügen
account-add-about = Das Konto einer anderen Person auf diesem Computer, mit eigenen Chats und Charakteren. Angemeldet wird mit seinem Passwort, hier oder auf einem anderen Gerät.
account-name = Name
account-added = Konto „{ $name }“ hinzugefügt.
account-add-button = Hinzufügen
account-sign-out = Abmelden
account-none = Kein Konto zum Anmelden
account-none-about = Noch kann sich hier kein Konto anmelden. Füge auf dem Computer, auf dem Cardwave läuft, eins unter Konto › Freigabe hinzu.
account-this-computer = Das Konto dieses Computers
account-choose = Wähle dein Konto
account-try-again = Erneut versuchen
account-back = Zurück
account-sign-in = Anmelden

## Backup and Restore (settings/backup.ts)

backup-saving = Die Sicherung wird gespeichert.
backup-saving-to = Die Sicherung wird in { $folder } gespeichert.
backup-password = Passwort
backup-repeat = Passwort wiederholen
backup-encrypted = Die Sicherung wird mit diesem Passwort verschlüsselt; zum Wiederherstellen brauchst du es, hier oder auf einem anderen Computer.
backup-forgotten = Ein vergessenes Passwort lässt sich nicht wiederherstellen, und ohne es lässt sich die Sicherung nicht wiederherstellen.
backup-with-password = Mit Passwort sichern
backup-differ = Die beiden Passwörter sind verschieden.
backup-back-up = Sicherung speichern
backup-no-file = Keine Datei gewählt
backup-choose-file = Datei wählen
backup-its-password = Das Passwort der Sicherung
backup-restoring = Wiederherstellen ersetzt alles in Cardwave: Chats, Charaktere, Personas, Lorebooks, Erinnerungen und Einstellungen. Das lässt sich nicht rückgängig machen. Das hier gesetzte Passwort bleibt, wie es ist. Auch die anderen Konten werden ersetzt.
backup-restored = Die Sicherung wurde wiederhergestellt: Alles in Cardwave ist so, wie es beim Sichern war. Andere Geräte melden sich neu an.
backup-file = Datei
backup-restore-title = Eine Sicherung wiederherstellen
backup-choose-first = Wähle zuerst die Datei der Sicherung.
backup-restore = Sicherung wiederherstellen
backup-from-file = Aus einer Sicherungsdatei
backup-about-own = Chats, Charaktere und Einstellungen in einer Datei, verschlüsselt mit deinem Passwort
backup-about-chosen = Chats, Charaktere und Einstellungen in einer Datei, verschlüsselt mit einem Passwort deiner Wahl

## The folder of cards (settings/card-folder.ts)

folder-watch = Neue Karten automatisch importieren
folder-watch-about = Eine Kartendatei, die in den Ordner kommt, landet von selbst in deiner Bibliothek
folder-recycle = Importierte Dateien in den Windows-Papierkorb verschieben
folder-recycle-about = Sobald eine Datei importiert ist, kommt sie in den Papierkorb

## The companion's line (library/companion-app.ts)

companion = Begleitung
# The companion window's name, which the system shows in its lists of windows.
companion-window = Cardwave-Begleitung
companion-made = { $name } ist jetzt deine Begleitung.
companion-make = Zur Begleitung machen
companion-none = Noch keine Begleitung. Öffne das Menü „…“ eines Charakters und wähle „Zur Begleitung machen“.
companion-named = { $name } · Startet mit der App
companion-figure = Figur der Begleitung
companion-figure-about = Gezeigt bei Charakteren ohne eigene 3D-Figur
companion-figure-woman = Frau
companion-figure-man = Mann
companion-figure-robot = Roboter
companion-size = Größe der Begleitung
companion-size-about = Die Höhe der Figur, als Anteil an der des Bildschirms
companion-size-value = { $size } %

## Other programs, MCP (settings/mcp.ts)

mcp-ask-title = KI-Apps auf diesem Computer Cardwave nutzen lassen
mcp-ask = Programme auf diesem Computer, etwa Claude Desktop, können deine Figuren und Chats lesen, in deinen Chats schreiben und die in Einstellungen › Werkzeuge eingeschalteten Werkzeuge nutzen. Was Cardwave dich zuerst fragen würde, können sie nicht tun.
mcp-switch-on = Einschalten
mcp-about = Etwa Claude Desktop, über MCP: Sie nutzen deine Charaktere, Chats und Werkzeuge
mcp-copy-address = MCP-Adresse kopieren
mcp-copy = Kopieren
mcp-as-account = Als Konto
mcp-as-account-about = Was sie sehen und tun können
mcp-remove-named = { $program } entfernen
mcp-removed = „{ $program }“ entfernt.
mcp-remove = Entfernen
mcp-connected = Verbunden
mcp-other-programs = Andere Programme
mcp-only-here = Nur Programme auf diesem Computer können sich verbinden. Ein entferntes Programm bleibt draußen, bis du dies aus- und wieder einschaltest.

## Your own CSS (settings/own-css.ts)

css-none = Keines
css-lines = { $count ->
    [one] 1 Zeile
   *[other] { $count } Zeilen
  }
css-about = { $lines } · ändert das Aussehen der App
css-hint = Wird nach Cardwaves eigenem Stylesheet angewandt, während du tippst. Speichern behält es; Abbrechen nimmt es zurück.
css-edit-own = Dein eigenes CSS bearbeiten
css-edit = Bearbeiten

## The password (settings/password.ts)

password-forgotten = Ein vergessenes Passwort lässt sich nicht wiederherstellen, und deine Chats und Charaktere sind damit verloren. Bewahre es sicher auf.
password-on-title = Ein Passwort festlegen
password-on-says = Cardwave fragt beim Öffnen danach. Ohne es kann niemand Cardwave öffnen oder deine Chats auf diesem Computer lesen.
password-on = Passwort festlegen
password-on-done = Passwort festgelegt.
password-change-title = Das Passwort ändern
password-change-says = Cardwave fragt beim Öffnen nach dem neuen.
password-change = Ändern
password-change-done = Passwort geändert.
password-off-title = Das Passwort ausschalten
password-off-says = Cardwave öffnet sich, ohne danach zu fragen. Deine Chats und Charaktere bleiben verschlüsselt.
password-off = Ausschalten
password-off-done = Passwort ausgeschaltet.
password-differ = Die beiden Passwörter sind verschieden.
password-other-says = Von da an meldest du dich mit dem neuen an.
password-other-forgotten = Vergisst du es, kann das Konto dieses Computers es zurücksetzen, unter Freigabe.
password-current = Aktuelles Passwort
password-password = Passwort
password-new = Neues Passwort
password-repeat = Passwort wiederholen
password-asked-sign-in = Wird beim Anmelden abgefragt
password-is-on = An · wird beim Öffnen der App abgefragt
password-is-off = Aus · jeder an diesem Computer kann Cardwave öffnen
password-start-forgotten = Ein vergessenes Passwort lässt sich nicht wiederherstellen.
password-open = Öffnen
password-locked-elsewhere = Cardwave ist auf seinem Computer gesperrt. Es öffnet sich hier, sobald es dort entsperrt wird.
password-back = Zurück

## Words many pages use

common-use = Verwenden
common-in-use = { " " }· in Verwendung
common-more = Mehr
common-edit = Bearbeiten
common-duplicate = Duplizieren
# The word a copy's name ends in, as in "Rig (copy)".
common-copy-word = Kopie
common-delete = Löschen
common-save = Speichern
common-cancel = Abbrechen
common-name = Name

## Model presets and prompt presets (settings/presets.ts, settings/prompt-presets.ts)

preset-what = Ein Preset speichert ein Chatmodell mit seinen Sampling-Werten. Verwenden wechselt zu ihm.
preset-temperature = Temperatur { $value }
preset-new = Neues Preset
preset-model-presets = Modell-Presets
preset-using = „{ $name }“ wird verwendet.
preset-added = Preset „{ $name }“ hinzugefügt.
preset-deleted = Preset „{ $name }“ gelöscht.
preset-saved = Preset „{ $name }“ gespeichert.
preset-delete-ask = Dieses Preset löschen?
preset-replace = Aktuelles Modell und Einstellungen verwenden
preset-replace-hint = Das Chatmodell, sein Anbieter und das Sampling auf dieser Seite. Aus: Die Vorlage behält ihre eigenen.
preset-keeps-hint = Es behält das Chatmodell unter Einstellungen › Modelle, seinen Anbieter und das Sampling auf dieser Seite.
preset-name = Name
preset-edit = Preset bearbeiten
prompt-presets = Prompt-Presets
prompt-system = Systemprompt
prompt-note = { $depth ->
    [one] Notiz, 1 Nachricht zurück
   *[other] Notiz, { $depth } Nachrichten zurück
}
prompt-system-note = { $depth ->
    [one] Systemprompt · Notiz, 1 Nachricht zurück
   *[other] Systemprompt · Notiz, { $depth } Nachrichten zurück
}
prompt-as-card = Wie der Charakter es sagt
prompt-default = Standard
prompt-default-name = „{ $name }“ ist der eigene Prompt des Charakters.

## Tools (settings/tools.ts, chat/tool-ask.ts)

tools-written-ask = { $count ->
    [0] Noch keine
    [one] 1 Werkzeug
   *[other] { $count } Werkzeuge
  } · vor dem ersten Lauf eines neuen fragen
tools-written-free = { $count ->
    [0] Noch keine
    [one] 1 Werkzeug
   *[other] { $count } Werkzeuge
  } · ein neues läuft ohne Nachfrage
tools-folder-first = Wähle zuerst einen Ordner
tools-web = Webseiten durchsuchen und lesen
tools-files = Nur { $folder }
tools-ask-writes = Vor dem Schreiben fragen
tools-ask-writes-says = Jede Datei wird dir gezeigt, bevor sie geschrieben wird
tools-commands = Ausführen in { $folder }, abgeschirmt vom Rest des Computers und vom Internet
tools-ask-commands = Vor dem Ausführen fragen
tools-ask-commands-says = Jeder Befehl wird dir gezeigt, bevor er läuft
tools-pictures = Verwendet das Bildmodell
tools-pictures-first = Richte zuerst das Bildmodell ein
tools-app = Deine Charaktere, Chats und Einstellungen nutzen und ändern; jede Änderung wird vorher erfragt
tools-dice = Lässt die KI würfeln; Cardwave würfelt, damit das Ergebnis fair ist.
tools-folder-example = C:\Users\du\Dokumente\Geteilt
tools-folder-says = Dateien und Befehle erreichen diesen Ordner und seinen Inhalt, sonst nichts.
tools-change-folder = Ordner ändern
tools-change = Ändern
tools-choose = Wählen
tools-none-chosen = Keiner gewählt
tools-title = Werkzeuge
tools-ask-new = { $name } möchte ein neues Werkzeug verwenden: { $what }
tools-ask-write = { $name } möchte „{ $what }“ in deinen Ordner schreiben:
tools-ask-read = { $name } möchte in deinem Ordner lesen:
tools-ask-install = { $name } möchte Programme herunterladen und installieren, die es braucht:
tools-ask-web = { $name } möchte das Web nutzen:
tools-ask-app = { $name } möchte Cardwave ändern:
tools-ask-command = { $name } möchte einen Befehl in deinem Ordner ausführen:
tools-allow = Erlauben
tools-deny = Ablehnen
tools-allow-writing = Schreiben von Dateien für diesen Chat erlauben
tools-allow-commands = Befehle für diesen Chat erlauben

## Updates (settings/update.ts)

update-title = Nach Updates suchen
update-available = Cardwave { $version } ist verfügbar
update-you-have = Du hast { $version }.
update-up-to-date = Cardwave ist auf dem neuesten Stand ({ $version }).
update-connection-error = Konnte nicht nach Updates suchen. Prüf deine Verbindung.
update-whats-new = Was ist neu
update-close = Schließen
update-ok = OK
update-download = Herunterladen
update-install = Aktualisieren und neu starten
update-installing = Cardwave { $version } wird heruntergeladen…
update-auto = Automatisch suchen
update-auto-about = Beim Start und einmal am Tag nach einer neuen Version suchen
update-check = Suchen
update-about = Prüfen, ob eine neuere Version der App verfügbar ist.

## The breadcrumbs of a page under Settings

crumbs = Wo du bist

## Providers (views/providers.ts)

providers-key-end = { $where } · Schlüssel ····{ $end }
providers-key-saved = { $where } · Schlüssel gespeichert
providers-no-key = { $where } · kein Schlüssel
providers-thinking-cannot = { $provider } kann das Denken für dieses Modell nicht abschalten
providers-thinking-off = Das Modell antwortet, ohne vorher nachzudenken
providers-thinking-on = Das Modell denkt nach, bevor es antwortet
providers-comfy-default = Standard von ComfyUI
providers-workflow-note = Dieser Workflow verwendet eigene Modelle und eine eigene Größe, nicht das Bildmodell.
providers-testing-model = Das Modell wird getestet…
providers-thinking-of = { $label }: Denken
providers-thinking = Denken
providers-testing-workflow = Der Workflow wird getestet…
providers-workflows-from = Aus den Workflows in ComfyUI
providers-pictures-by = Bilder von „{ $name }“.
providers-pictures-default = Bilder vom Standard-Workflow von ComfyUI.
providers-workflow = Workflow
providers-not-used = Noch für nichts verwendet
providers-folder-saved = Ordner gespeichert.
providers-change-folder = Den Ordner der Modelle ändern
providers-choose-folder = Einen Ordner mit Modellen wählen
providers-change = Ändern
providers-not-set-up = Nicht eingerichtet
providers-folder-not-set-up = Führt Modelle aus einem Ordner auf diesem Computer aus · nicht eingerichtet
providers-menu = Menü des Anbieters: bearbeiten, entfernen
providers-remove = Entfernen
providers-removed = Anbieter „{ $name }“ entfernt.
providers-remove-with-models = Diesen Anbieter entfernen? Die von ihm gewählten Modelle werden nicht mehr verwendet.
providers-remove-ask = Diesen Anbieter entfernen?
providers-remove-key = Schlüssel entfernen
providers-key-removed = Der Schlüssel wird beim Speichern entfernt
providers-edit = Anbieter bearbeiten
providers-keep-key = Leer lassen, um den gespeicherten Schlüssel zu behalten.
providers-saved = Anbieter „{ $name }“ gespeichert.
providers-added = Anbieter „{ $name }“ hinzugefügt.
providers-add = Anbieter hinzufügen
providers-about = Wo die KI läuft: ein Dienst im Internet oder ein Programm auf diesem Computer. Unter jedem steht, wofür er genutzt wird.

## Voices (views/voices.ts)

voices-stop = { $name } stoppen
voices-try = { $name } anhören
voices-model-about = Liest Nachrichten auf diesem Computer vor · { $size }
voices-default-of = Standardstimme: { $name }
voices-menu = Menü der Stimme: umbenennen, löschen
voices-rename = Umbenennen
voices-delete-ask = Die Stimme „{ $name }“ löschen? Figuren, die sie nutzen, lesen wieder mit der Standardstimme.
voices-rename-title = Stimme umbenennen
voices-name = Name
voices-speed-value = { $speed }×
voices-speed = Tempo
voices-speed-about = Wie schnell Antworten vorgelesen werden, für jede Stimme
voices-make = Eine Stimme aus einer Aufnahme machen
voices-provider-failed = Die Stimmen des Anbieters ließen sich nicht laden.
voices-provider-none = Der Anbieter listet keine Stimmen
voices-provider-own = Nachrichten werden mit der eigenen Stimme des Anbieters gelesen.
voices-voices = Stimmen
voices-voices-about = Die Stimme, die Nachrichten vorliest. Ein Charakter kann unter „Stimmen der Charaktere“ eine eigene haben.
voices-default = Standardstimme
voices-voice-of = Stimme von { $name }
voices-back-default = Zurück zur Standardstimme
voices-name-title = { $name } · { $title }
voices-choose-character = Wähle einen Charakter
voices-all-have = Jeder Charakter hat eine Stimme.
voices-set-for = Eine Stimme für einen Charakter festlegen
voices-character = Charakter
voices-voice = Stimme
voices-character-first = Wähle zuerst einen Charakter.
voices-characters = Stimmen der Charaktere
voices-downloading = Wird heruntergeladen · { $size } · { $percent } %
voices-downloaded = Heruntergeladen · { $size }
voices-download-size = { $size } Download
voices-action-of = { $name }: { $action }
voices-language-downloaded = { $name } heruntergeladen
voices-built-in = Eingebaut
voices-languages = Sprachen, die sie liest
voices-download = Herunterladen
voices-cancel = Abbrechen
voices-delete = Löschen

## Advanced (views/advanced.ts)

advanced-context-size = Kontextgröße (Tokens)
advanced-context-hint = Leer lassen für 128.000
advanced-temperature = Temperatur
advanced-temperature-about = Höher: überraschendere Antworten. Von 0 bis 2
advanced-top-p = Top P
advanced-top-p-about = Niedriger: nur die wahrscheinlichsten Wörter. Von 0 bis 1
advanced-frequency = Frequency Penalty
advanced-frequency-about = Höher: weniger wiederholte Wörter. Von −2 bis 2
advanced-presence = Presence Penalty
advanced-presence-about = Höher: mehr neue Themen. Von −2 bis 2
advanced-seed = Seed
advanced-seed-about = Dieselbe Zahl ergibt wieder dieselbe Antwort
advanced-from-to = Von { $min } bis { $max }
advanced-whole-from = Eine ganze Zahl ab { $min }
advanced-whole = Eine ganze Zahl
advanced-number = Eine Zahl
advanced-sampling = Sampling
advanced-sampling-about = Für das Chatmodell. Lass einen Wert leer, um den Standard des Anbieters zu verwenden. Wird beim Tippen gespeichert.
advanced-describing = Wird beschrieben… noch { $count }
advanced-all-described = Jeder Charakter ist beschrieben
advanced-not-described = { $count ->
    [one] 1 Charakter
   *[other] { $count } Charaktere
  } noch nicht beschrieben
advanced-describe-cards = Charaktere beschreiben
advanced-describe-cost = Etwa { $low } bis { $high } Tokens für { $count ->
    [one] 1 Charakter
   *[other] { $count } Charaktere
  }
advanced-failed = { $count ->
    [one] 1 fehlgeschlagen
   *[other] { $count } fehlgeschlagen
  }: { $failure }. Tippe auf „Charaktere beschreiben“, um es erneut zu versuchen.
advanced-describe-again = Alle neu beschreiben
advanced-describe-again-stop = Stoppen
advanced-describe-again-about = Schreibt mit dem Hilfsmodell die Kurzbeschreibung, Zusammenfassung und Schlagwörter jeder Figur neu und das, wonach „Nach Bedürfnis“ sie findet, etwa 11.000 bis 12.000 Tokens je Figur. Was du selbst bearbeitet hast, bleibt. Nach Tokens rechnen Anbieter ab.
advanced-no-characters = Keine Charaktere zu beschreiben
advanced-describe-again-far = { $done } von { $all } neu beschrieben
advanced-describe-again-stopped = Angehalten bei { $done } von { $all } neu beschrieben
advanced-describe-again-failed = { $count ->
    [one] 1 fehlgeschlagen, bleibt wie er war
   *[other] { $count } fehlgeschlagen, bleiben wie sie waren
  }: { $failure }. Tippe auf „Alle neu beschreiben“, um es noch einmal zu versuchen.
advanced-describe-about = Für jeden eine Kurzbeschreibung, eine Zusammenfassung und Tags, geschrieben vom Hilfsmodell
advanced-plain = Chat ohne Charakter
advanced-told-about = Dieselben in jedem Chat ohne Charakter. Schreibe { "{{date}}" } oder { "{{time}}" }, und die KI erhält das heutige Datum oder die Uhrzeit
advanced-library = Bibliothek
advanced-interview-about = Wie die KI dir ihre Fragen stellt
advanced-interview-tree = Baum
advanced-interview-cloud = Wolke
advanced-interview-hybrid = Hybrid
advanced-data = Daten
advanced-format-about = Das Format, in dem Exportieren jede Karte schreibt; die meisten Apps öffnen SillyTavern V3
advanced-history-about = Die früheren Fassungen jedes Textes; nur im eigenen Kartenformat von Cardwave
advanced-helper = Hilfsmodell
advanced-the-helper = das Hilfsmodell

## Cardwave's CSS (views/css-reference.ts)

cssref-rail = Die linke Leiste
cssref-main = Ein Bildschirm neben der Leiste
cssref-crumbs = Der Pfad oben auf einer Seite
cssref-group = Ein Kasten mit Zeilen, wie in den Einstellungen
cssref-item = Eine Zeile eines Kastens
cssref-row = Eine Zeile einer Liste
cssref-tile = Eine Karte im Raster der Bibliothek
cssref-msg = Eine Nachricht in einem Chat
cssref-bubble = Die Sprechblase einer Nachricht
cssref-composer = Das Nachrichtenfeld unter einem Chat
cssref-dialog = Ein Dialog
cssref-btn-primary = Die blaue Schaltfläche
cssref-switch = Ein Schalter
cssref-pill = Eine Pille
cssref-notice = Der Hinweis am Fuß des Fensters
cssref-snippet-green = Ein grüner Akzent
cssref-snippet-square = Eckige Sprechblasen
cssref-snippet-larger = Größerer Text
cssref-snippet-wider = Breitere Dialoge
cssref-snippet-tighter = Engere Abstände
cssref-snippet-black = Ein schwarzes dunkles Design
cssref-in-dark = { $light } · im Dunkeln { $dark }
cssref-none = Keine Variable mit diesem Namen.
cssref-copy-of = „{ $title }“ kopieren
cssref-copied = Kopiert.
cssref-copy = Kopieren
cssref-about-1 = Die Variablen und Klassennamen, die dein eigenes CSS verwenden kann. Jede Farbe und Größe der App ist eine Variable in{ " " }
cssref-about-2 = , mit einem hellen und einem dunklen Wert.
cssref-variables = Variablen
cssref-search = Suchen
cssref-find = Eine Variable finden
cssref-all = { $count } Variablen insgesamt.
cssref-classes = Klassennamen
cssref-snippets = Schnipsel

## Tools the AI wrote (views/written-tools.ts)

written-about = { $what } · erstellt { $made }
written-about-in = { $what } · erstellt { $made } in { $chat }
written-used = { $count ->
    [0] noch nicht verwendet
    [one] einmal verwendet
   *[other] { $count }-mal verwendet
  }
written-none = Noch keine Werkzeuge. Schalte in einem Chat „Die KI Werkzeuge schreiben lassen“ ein, und was sie schreibt, steht hier.
written-ask = Fragen, bevor ein neues Werkzeug läuft
written-ask-about = Einmal je Werkzeug: Du erlaubst es beim ersten Lauf
written-in = { " " }in{ " " }
written-made = Erstellt { $made }
written-dot-used = { " " }· { $used }
written-switch-off = Ausschalten
written-switch-on = Einschalten
written-intro = Kleine Werkzeuge, die die KI sich in Chats geschrieben hat, in denen „Die KI Werkzeuge schreiben lassen“ an ist. Sie greifen nur auf deine Dateien zu, wenn du es erlaubst, und bleiben für spätere Chats.
written-deleted = Werkzeug „{ $name }“ gelöscht.
written-on = { $name } an
written-view-code = Code ansehen

## The coding team, shared by the chat and its pages (chat/coding.ts)

coding-quick = Schnell
coding-balanced = Ausgewogen
coding-thorough = Gründlich
coding-custom = Eigenes
coding-running = Läuft
coding-done = Fertig
coding-failed = Fehlgeschlagen
coding-stopped = Gestoppt
coding-team-says-alone = { $name }: ein Planer, { $workers ->
    [1] ein Arbeiter
    [2] zwei Arbeiter
   *[other] drei Arbeiter
  }, ohne Prüfer.
coding-team-says-tests = { $name }: ein Planer, { $workers ->
    [1] ein Arbeiter
    [2] zwei Arbeiter
   *[other] drei Arbeiter
  } und ein Prüfer, der die Tests ausführt.
coding-team-says-steps = { $name }: ein Planer, { $workers ->
    [1] ein Arbeiter
    [2] zwei Arbeiter
   *[other] drei Arbeiter
  } und ein Prüfer, der jeden Schritt prüft und die Tests ausführt.
coding-team-label = { $name } · { $workers ->
    [one] 1 Arbeiter
   *[other] { $workers } Arbeiter
  }
coding-team-label-auditor = { $name } · { $workers ->
    [one] 1 Arbeiter
   *[other] { $workers } Arbeiter
  }, Prüfer
coding-team-label-steps = { $name } · { $workers ->
    [one] 1 Arbeiter
   *[other] { $workers } Arbeiter
  }, Prüfer je Schritt
coding-tests-pass = { $passed } von { $total } Tests bestanden
coding-passed = Bestanden
coding-problems = Probleme gefunden

## Coding team (views/coding-team.ts)

team-audit-end = Am Ende
team-audit-each = Nach jedem Schritt
team-audit-never = Nie
team-change = Ändern
team-workers-of = { $model } · { $workers } gleichzeitig
team-worker-model = Modell der Arbeiter
team-change-worker = Das Modell der Arbeiter ändern
team-how-many = Wie viele Arbeiter
team-none = Keiner
team-auditor-tests = { $model } · führt die Tests aus
team-auditor-steps = { $model } · prüft jeden Schritt
team-auditor-model = Modell des Prüfers
team-change-auditor = Das Modell des Prüfers ändern
team-when = Wann der Prüfer prüft
team-team = Team
team-roles = Rollen
team-planner-model = Modell des Planers
team-change-planner = Das Modell des Planers ändern
team-recent = Letzte Aufgaben
team-intro = KIs, die gemeinsam auf diesem Computer ein Programm für dich schreiben, gestartet aus einem Chat.
team-no-tasks = Noch keine Aufgaben. Eine Aufgabe startest du in einem Chat, mit dem „+“ neben dem Nachrichtenfeld › Programmieraufgabe starten.

## Trash (views/trash.ts)

trash-expressions = Ausdrücke · kein Charakter hat sie
trash-figure = 3D-Figur · kein Charakter hat sie
trash-chat-with = Chat mit { $names }
trash-chat = Chat
trash-persona = Persona
trash-persona-used = Persona · verwendet in { $count ->
    [one] 1 Chat
   *[other] { $count } Chats
  }
trash-lorebook = Lorebook
trash-lorebook-used = Lorebook · verwendet in { $count ->
    [one] 1 Chat
   *[other] { $count } Chats
  }
trash-character = Charakter
trash-character-chats = Charakter · mit { $count ->
    [one] 1 Chat
   *[other] { $count } Chats
  }
trash-empty = Der Papierkorb ist leer.
trash-about = Was hierher verschoben wird, bleibt { $days } Tage und wird dann endgültig gelöscht.
trash-emptied = Papierkorb geleert.
trash-empty-trash = Papierkorb leeren
trash-delete-all-ask = { $count ->
    [one] Das eine Element
   *[other] Alle { $count } Elemente
  } endgültig löschen?
trash-restored = „{ $title }“ wiederhergestellt.
trash-deleted = „{ $title }“ endgültig gelöscht.
trash-deleted-at = Hierher verschoben { $when }
trash-days-left = { $count ->
    [one] noch 1 Tag
   *[other] noch { $count } Tage
  }
trash-restore = Wiederherstellen
trash-restore-chats = Holt den Charakter und { $count ->
    [one] seinen Chat
   *[other] seine { $count } Chats
  } zurück
trash-delete-forever = Endgültig löschen
trash-delete-forever-ask = „{ $title }“ endgültig löschen? Das lässt sich nicht rückgängig machen.
trash-delete-forever-ask-chats = „{ $title }“ und { $count ->
    [one] seinen Chat
   *[other] seine { $count } Chats
  } endgültig löschen? Das lässt sich nicht rückgängig machen.

## About Cardwave (views/about.ts)

about-no-package = Kein Paket mit diesem Namen.
about-no-notes = Zu dieser Version gibt es keine Hinweise.
about-by = von { $by }
about-licence-of = Lizenz von { $name }
about-licence = Lizenz
about-folder-failed = Der Ordner ließ sich nicht öffnen: { $reason }. Er liegt unter { $where }.
about-open-folder = Ordner öffnen
about-logs-where = im Ordner „logs“ in Cardwaves Datenordner, auf dem Computer, auf dem Cardwave läuft
about-logs = Protokolle
about-logs-about = Was Cardwave getan hat und etwaige Abstürze, eine Datei pro Tag, 7 Tage aufbewahrt: zur Hilfe, wenn etwas schiefgeht · { $where }
about-version = Version { $version }
about-whats-new = Was ist neu
about-packages = { $count } Pakete
about-open-source = Open-Source-Software
about-search = Suchen
about-find = Ein Paket finden
about-version-built = Version { $version } · { $built }
about-models = Modelle
about-figures = Figuren und Animationen
about-voices = Stimmen
about-voice-donations = Gespendete Stimmen
about-voice-acted-by = Gesprochen von { $name }
about-voice-vctk = Sprecher { $speaker } des CSTR VCTK Corpus von Junichi Yamagishi, Christophe Veaux und Kirsten MacDonald, University of Edinburgh; bereinigt von Kyutai
about-voice-cml-tts = Sprecher { $speaker } von CML-TTS von Frederico S. Oliveira, Edresson Casanova, Arnaldo Candido Junior, Anderson S. Soares und Arlindo R. Galvão Filho, gelesen für LibriVox
about-voice-cml-tts-cleaned = Sprecher { $speaker } von CML-TTS von Frederico S. Oliveira, Edresson Casanova, Arnaldo Candido Junior, Anderson S. Soares und Arlindo R. Galvão Filho, gelesen für LibriVox; bereinigt von Kyutai
about-lists = Liste der Anbieter und Modelle

about-or = oder
about-and = und
about-with = mit

## Prompt preset (views/prompt-preset.ts)

prompt-new = Neues Prompt-Preset
promptpage-system = Systemprompt
prompt-system-about = Tritt an die Stelle des Systemprompts der Karte. Leer lassen, um den der Karte zu behalten.
promptpage-note = Notiz
prompt-note-about = Die KI liest sie vor jeder Antwort; du siehst sie im Chat nicht. Sie steht so viele Nachrichten zurück wie unten eingestellt.
prompt-depth = Nachrichten zurück
prompt-intro = Anweisungen für die KI. Wähle das Preset in der Seitenleiste eines Chats, um sie dort zu nutzen.
prompt-depth-about = 1 setzt sie direkt vor die neueste Nachricht, 4 vier Nachrichten zurück.
prompt-saved = Preset „{ $name }“ gespeichert.
prompt-gone = Diese Prompt-Vorlage wurde gelöscht. Geh zurück und wähle eine andere.

## Profile (views/profile.ts)

profile-change-picture = Das Bild ändern
profile-change = Ändern
profile-remove-picture = Das Bild entfernen
profile-remove = Entfernen
profile-picture-changed = Bild geändert.
profile-picture-removed = Bild entfernt.
profile-your-picture = Dein Bild
profile-no-picture = Kein Bild: dein Anfangsbuchstabe { $letter } wird gezeigt
profile-change-name = Den Namen ändern
profile-this-computer = Das Konto dieses Computers
profile-on-server = Konto auf diesem Computer
profile-account = Konto

## Server (views/server.ts)

server-copy = Kopieren
server-no-network = Dieser Computer ist mit keinem Netzwerk verbunden. Verbinde ihn per WLAN oder Kabel, um andere Geräte hereinzulassen.
server-switch-on-about = Handys und andere Computer in diesem Netzwerk können Cardwave dann öffnen. Jedes Konto meldet sich mit seinem Passwort an.
server-switch-on = Einschalten
server-network-about = Handys und andere Computer öffnen Cardwave in einem Browser
server-other-devices = Andere Geräte
server-inside = Nur Geräte in diesem Netzwerk erreichen es, außer du richtest deinen Router dafür ein, andere hereinzulassen.
server-add-account = Konto hinzufügen
server-owner = Dieser Computer · kann Konten hinzufügen und entfernen
server-more-of = Mehr: { $name }
server-reset-password = Passwort zurücksetzen
server-delete-account = Konto löschen
server-deleted = Konto „{ $name }“ gelöscht.
server-delete-ask = Dieses Konto mit seinen Figuren, Chats und Einstellungen löschen? Das lässt sich nicht rückgängig machen.
server-reset-title = Das Passwort von { $name } zurücksetzen
server-reset-about = Das Konto meldet sich mit dem neuen an und wird überall abgemeldet, wo es angemeldet ist.
server-new-password = Neues Passwort
server-reset-done = Das Passwort von { $name } wurde zurückgesetzt.
server-reset = Zurücksetzen
server-accounts = Konten

## Character generator (views/generator.ts)

gen-gender-woman = Frau
gen-gender-man = Mann
gen-gender-non-binary = Nichtbinär
gen-being-human = Mensch
gen-being-not-human = Nicht menschlich
gen-age-20s = 20er
gen-age-30s = 30er
gen-age-40s = 40er
gen-age-50s-and-older = 50er und älter
gen-build-slim = Schlank
gen-build-average = Durchschnittlich
gen-build-athletic = Sportlich
gen-build-strong = Kräftig
gen-hair-short = Kurz
gen-hair-medium = Mittellang
gen-hair-long = Lang
gen-colour-black = Schwarz
gen-colour-brown = Braun
gen-colour-blonde = Blond
gen-colour-red = Rot
gen-colour-grey = Grau
gen-colour-white = Weiß
gen-relation-stranger = Fremde Person
gen-relation-friend = Freund/in
gen-relation-partner = Partner/in
gen-relation-rival = Rivale/Rivalin
gen-relation-colleague = Kollege/Kollegin
gen-relation-mentor = Mentor/in
gen-shy = Schüchtern
gen-outgoing = Kontaktfreudig
gen-gentle = Sanft
gen-harsh = Schroff
gen-serious = Ernst
gen-playful = Verspielt
gen-cautious = Vorsichtig
gen-bold = Kühn
gen-random = Zufällig
gen-slider = { $low } bis { $high }
gen-looks = Aussehen
gen-gender = Geschlecht
gen-being = Mensch oder nicht
gen-any = Beliebig
gen-age = Alter
gen-build = Statur
gen-hair = Haare
gen-hair-colour = Haarfarbe
gen-personality = Persönlichkeit
gen-relates = Wer der Charakter für dich ist
gen-make = Den Charakter erstellen
gen-what = Wähle ein paar Eigenschaften; die KI schreibt die erste Nachricht des Charakters und wie er spricht.
interview-goes-to = Deine Antworten gehen an { $provider }, um den Charakter zu schreiben.
interview-stays = Deine Antworten bleiben auf diesem Computer.
interview-own-words = Oder füge eigene Worte hinzu
interview-in-own-words = In deinen eigenen Worten
interview-your-answer = Deine Antwort
interview-pick-one = Wähle eins
interview-pick-two = Wähle eins oder zwei
interview-pick-three = Wähle bis zu drei
interview-pick-many = Wähle so viele, wie passen
interview-few-words = Ein paar Worte genügen
interview-wanted-hint = Was hat dir bei Menschen gefehlt, oder bei Charakteren, die du ausprobiert hast?
interview-needs-hint = Für deine Zeit mit dem Charakter, nicht für den Rest deines Lebens
interview-next = Weiter
interview-skip = Überspringen
interview-dont-know = Ich weiß nicht
interview-back = Zurück
interview-just-make-it = Einfach erstellen
interview-more = Mehr Arten
interview-writing-next = Die nächste Frage wird geschrieben
interview-try-again = Erneut versuchen
interview-failed-where = Wenn es weiter scheitert, sieh unter Einstellungen › Anbieter nach dem Anbieter und Modell.
gen-stop = Stoppen
gen-writing = Der Charakter wird geschrieben…
interview-understood = Das habe ich verstanden.
interview-you-said = du hast gesagt: „{ $words }“
interview-own-guess = die eigene Vermutung der KI
interview-keep = Behalten
interview-change = Ändern
interview-remove = Entfernen
interview-not-it = Das ist es nicht
interview-not-it-off = Diese Zeile beruht auf keiner einzelnen Frage, die sich neu stellen ließe
interview-own-sentence = Dein eigener Satz
interview-private-line = Gibt es etwas, das du in der Welt deines Charakters willst, oder nie willst?
interview-private-sub = Romantik, Gewalt, Fluchen und mehr · optional
interview-make = Charakter erstellen
interview-make-after = Danach kannst du sie auf ihrer Seite ändern.
interview-skip-all = Alle überspringen
interview-private-hint = Manche wollen das in der Welt ihres Charakters, manche nicht. Deine Antworten bleiben bei diesem Charakter auf deinem Computer und gehen nur an die KI, die den Charakter schreibt.
interview-private-free = Alles andere, das du willst oder nie willst
interview-yes = Ja
interview-no = Nein
interview-maybe = Vielleicht
interview-fantasy-only = Nur als Fantasie
interview-never = Nie
interview-try-another = Ein anderes Modell versuchen
interview-without-topic = Ohne dieses Thema schreiben
interview-model-provider = { $model } · { $provider }
interview-reading = Deine Antworten werden gelesen
interview-persona-title = Was du über dich gesagt hast, zu deiner Persona hinzufügen?
interview-persona-field = Persona
interview-persona-in-use = { $persona } · in Verwendung
interview-persona-new = Neue Persona
interview-persona-add = Hinzufügen
interview-persona-not-now = Nicht jetzt
interview-persona-added = Zu „{ $persona }“ hinzugefügt.
interview-persona-you = Du
