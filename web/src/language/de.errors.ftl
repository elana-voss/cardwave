### Die Wörter der Oberfläche auf Deutsch: die Fehlerantworten des Servers, aus en.errors.ftl (die goldene Datei),
### Schlüssel für Schlüssel; die Wortliste steht im Kopf von de.ftl.

## Die Anfrage, wie der Server sie bekam

error-request-failed = Das ließ sich nicht machen. Versuch es noch einmal.
error-internal = In Cardwave ist etwas schiefgegangen. Versuch es noch einmal.
error-bad-request = Cardwave konnte diese Anfrage nicht lesen. Lade die Seite neu und versuch es noch einmal.
error-forbidden = Das ist nicht erlaubt.
error-no-such-path = Diese Seite gibt es in Cardwave nicht. Lade die Seite neu und versuch es noch einmal.
error-method-not-allowed = Das macht Cardwave hier nicht. Lade die Seite neu und versuch es noch einmal.
error-too-large = Das ist zu groß. Nimm eine kleinere Datei.
error-unsupported-type = Diese Art Datei nimmt Cardwave hier nicht an.

## Passwörter und Konten

error-locked = Cardwave ist gesperrt, bis sein Passwort eingegeben ist.
error-sign-in = Melde dich zuerst an.
error-password-wrong = Falsches Passwort.
error-password-needed = Das Passwort wird gebraucht.
error-current-password-needed = Das aktuelle Passwort wird gebraucht.
error-backup-password-needed = Diese Sicherung braucht ihr Passwort.
error-too-many-tries = Zu viele falsche Passwörter. Versuch es in { $seconds } Sekunden noch einmal.
error-owner-only = Nur das Konto dieses Computers kann { $action ->
    [use_its_files] seine Dateien verwenden
    [use_its_folders] seine Ordner verwenden
    [choose_its_models] seine Modelle wählen
    [lock_Cardwave] Cardwave sperren
   *[other] das tun
}.
error-no-password-to-lock = Cardwave lässt sich nur sperren, wenn ein Passwort eingeschaltet ist.
error-remote-sign-in-off = Dieses Konto kann sich nicht von einem anderen Gerät aus anmelden. Schalte das unter Konto › Freigabe ein.
error-no-password-on = Es ist kein Passwort eingeschaltet.
error-no-password-set = Für dieses Konto ist kein Passwort festgelegt.
error-password-kept = Ein Konto auf diesem Computer hat ein Passwort: Es meldet sich damit an.
error-account-busy = Cardwave arbeitet noch für dieses Konto: eine Antwort, ein Bild, eine Programmieraufgabe, ein neuer Charakter, das Lesen von Charakteren oder das Gedächtnis eines Chats; versuch es noch einmal, wenn das fertig ist.
error-restore-busy = Cardwave arbeitet noch: eine Antwort, ein Bild, eine Programmieraufgabe, ein neuer Charakter, das Lesen von Charakteren oder das Gedächtnis eines Chats; versuch es noch einmal, wenn das fertig ist.
error-backup-needs-password = Eine Sicherung braucht ein Passwort.

## Was verlangt wird

error-not-found = { $what ->
    [account] Dieses Konto gibt es nicht.
    [asset] Diese Datei gibt es in der Karte nicht.
    [attachment] Diesen Anhang gibt es nicht.
    [card] Diese Karte gibt es nicht.
    [card_version] Diese Kartenversion gibt es nicht.
    [chat] Diesen Chat gibt es nicht.
    [chat_character] Diesen Charakter gibt es im Chat nicht.
    [checkpoint] Diesen Prüfpunkt gibt es nicht.
    [deleted_message] Diese gelöschte Nachricht gibt es nicht.
    [document] Dieses Dokument gibt es nicht.
    [expression] Diesen Ausdruck gibt es nicht.
    [expression_pack] Satz Ausdrücke
    [figure] Diese Figur gibt es nicht.
    [kind_of_model] Diese Art Modell gibt es nicht.
    [language] Diese Sprache gibt es nicht.
    [lorebook] Dieses Lorebook gibt es nicht.
    [lorebook_entry] Diesen Lorebook-Eintrag gibt es nicht.
    [memory] Diese Erinnerung gibt es nicht.
    [message] Diese Nachricht gibt es nicht.
    [model] Dieses Modell gibt es nicht.
    [persona] Diese Persona gibt es nicht.
    [picture] Dieses Bild gibt es nicht.
    [preset] Dieses Preset gibt es nicht.
    [prompt_preset] Dieses Prompt-Preset gibt es nicht.
    [provider] Diesen Anbieter gibt es nicht.
    [question] Diese Frage gibt es nicht.
    [task] Diese Aufgabe gibt es nicht.
    [tool] Dieses Werkzeug gibt es nicht.
    [user] Dieses Konto gibt es nicht.
    [voice] Diese Stimme gibt es nicht.
   *[other] Das gibt es nicht.
} Vielleicht wurde das gelöscht.
error-chat-busy = In diesem Chat wird gerade eine Antwort geschrieben; halte sie zuerst an.
error-no-provider = { $what ->
    [chat_model] Es ist noch kein Chatmodell gewählt. Wähle eines unter Einstellungen › Modelle.
   *[other] Es ist noch kein Anbieter eingerichtet. Füge einen unter Einstellungen › Anbieter hinzu.
}
error-provider-refused = { $refusal ->
    [key] Der Anbieter hat den Schlüssel nicht angenommen: Prüfe ihn unter Einstellungen › Anbieter.
    [paid] Der Anbieter verlangt dafür eine Zahlung: Lade Guthaben auf oder wähle ein Modell, das dein Abo enthält.
    [busy] Der Anbieter hat kein Guthaben mehr oder ist ausgelastet: Versuche es später noch einmal.
    [down] Der Anbieter antwortet nicht: Versuche es später noch einmal.
    [fault] Beim Anbieter ist ein Fehler aufgetreten: { $reason } Versuche es später noch einmal.
    [no_model] Der Anbieter bietet dieses Modell nicht mehr an: Wähle ein anderes unter Einstellungen › Modelle.
    [too_long] Das Modell hat mehr bekommen, als es auf einmal lesen kann: Wähle unter Einstellungen › Modelle ein Modell, das mehr liest.
   *[other] Der Anbieter hat das abgelehnt: { $reason }
}
error-model-declined = { $model } hat es abgelehnt, das zu schreiben. Ändere die Nachricht oder wähle ein anderes Modell.
error-model-sees-no-pictures = { $model } kann keine Bilder sehen und nimmt deshalb keine an. Wähle ein Modell, das Bilder sieht, um sie zu senden.
error-card-trashed = Der Charakter liegt im Papierkorb; stell ihn zuerst wieder her.
error-lorebook-trashed = Das Lorebook „{ $name }“ liegt im Papierkorb; stell es wieder her, um es zu verwenden.
error-own-lorebook-flags = Das eigene Lorebook eines Charakters gehört zum Charakter: Es kann nicht für sich allein markiert, archiviert, in den Papierkorb gelegt oder in jedem Chat verwendet werden.

## Ordner und Dateien

error-no-such-folder = Den Ordner { $folder } gibt es auf diesem Computer nicht.
error-folder-not-chosen = Wähle zuerst einen Ordner.
error-drive-root-to-watch = Das Stammverzeichnis eines Laufwerks enthält zu viel zum Beobachten; wähle einen Ordner darin.
error-drive-root-for-model = Das Stammverzeichnis eines Laufwerks enthält zu viel, um es der KI zu geben; wähle einen Ordner darin.
error-data-folder = Dieser Ordner enthält Cardwaves eigene Daten oder liegt darin; wähle einen anderen.
error-commands-windows-only = Befehle werden nur unter Windows ausgeführt.
error-recycle-bin-windows-only = Dateien werden nur unter Windows in den Windows-Papierkorb verschoben.
error-files-tool-off = Schalte zuerst Dateien unter Einstellungen › Werkzeuge ein: Damit liest und schreibt das Team den Ordner der Aufgabe.

## Bilder, Antworten und Stimmen

error-picture-words-missing = Sag zuerst, was das Bild zeigt.
error-picture-words-too-long = Was das Bild zeigt, ist länger als { $most } Zeichen.
error-picture-needs-words = Sag, was das Bild zeigt.
error-goal-missing = Sag, was das Team tun soll.
error-dictation-not-set-up = Diktat ist nicht eingerichtet: Einstellungen › Modelle › Diktat.
error-direction-without-go-on = Ein Hinweis wirkt nur mit Fortsetzen.
error-again-or-go-on = Eine Antwort wird entweder neu geschrieben oder fortgesetzt, nicht beides.
error-again-not-reply = Nur die Antwort eines Charakters kann neu geschrieben werden.
error-no-reply-to-write-again = Der Chat hat keine Antwort, die neu geschrieben werden kann.
error-no-text = Die KI hat keinen Text gesendet. Versuch es noch einmal.
error-worker-no-answer = Das Hilfsmodell hat keine Antwort gegeben.
error-unknown-voice = Es gibt keine Stimme „{ $voice }“.
error-nothing-to-read = Es gibt nichts zum Vorlesen.
error-voice-not-downloaded = Die Stimme ist nicht heruntergeladen.
error-voice-failed = Das Vorlesen ist fehlgeschlagen. Versuch es noch einmal.
error-stopping = Cardwave wird beendet.
error-download-failed = Der Download ist fehlgeschlagen. Prüfe die Verbindung und versuch es noch einmal.
error-search-model-failed = Das Suchmodell ist ausgefallen. Cardwave versucht es in einer Weile noch einmal.
error-models-not-listed = Die Modelle des Anbieters ließen sich nicht abrufen. Prüfe die Adresse und den Schlüssel und versuch es dann noch einmal.
error-file-not-imported = Die Datei konnte nicht gelesen werden: Cardwave kennt ihr Format nicht.
error-describing-failed = Das Hilfsmodell konnte den Charakter nicht beschreiben.

## Die Arten, nach denen die Fehler eines Bereichs gruppiert sind: jede wählt ihre Worte nach `what` (oder `whose`), der Sache, um die es geht

error-needed = { $what ->
    [persona_name] Eine Persona braucht einen Namen.
    [account_name] Das Konto braucht einen Namen.
    [card_title] Der Charakter braucht einen Titel.
    [character_name] Der Charakter braucht einen Namen.
    [chat_character] Ein Chat braucht einen Charakter.
    [chat_title] Der Titel eines Chats braucht Worte.
    [entry_name] Ein Eintrag braucht einen Namen.
    [expression_files] Wähle eine Zip-Datei (einen gepackten Ordner) oder die Bilder eines Satzes.
    [language] Die Sprache fehlt.
    [lorebook_name] Ein Lorebook braucht einen Namen.
    [memory_text] Eine Erinnerung braucht einen Text.
    [message_to_improve] Es gibt keine Nachricht zum Verbessern.
    [model_name] Das Modell muss genannt werden.
    [models_folder] Wähle zuerst einen Ordner mit Modellen.
    [password] Ein Passwort darf nicht leer sein.
    [preset_name] Das Preset braucht einen Namen.
    [rewrite_given] Etwas Nötiges fehlt. Versuch es noch einmal.
    [summary] Eine Zusammenfassung braucht Worte.
    [text_to_change] Es gibt keinen Text zum Ändern.
    [text_to_read] Es gibt nichts zum Vorlesen.
    [voice_name] Die Stimme braucht einen Namen.
   *[other] Etwas Nötiges fehlt. Versuch es noch einmal.
}
error-too-long = { $what ->
    [account_name] Der Name eines Kontos hat höchstens { $name_limit } Zeichen.
    [chat_title] Der Titel eines Chats hat höchstens { $title_limit } Zeichen.
    [document] { $name } ist zu lang: Ein Dokument hat höchstens 2.000.000 Zeichen.
    [entry_name] Der Name eines Eintrags hat höchstens { $max_name } Zeichen.
    [field_name] Der Name eines Felds hat 1 bis { $max_field } Zeichen.
    [lorebook_name] Der Name eines Lorebooks hat höchstens { $max_name } Zeichen.
    [memory_text] Eine Erinnerung hat höchstens { $text_limit } Zeichen.
    [persona_name] Der Name einer Persona hat höchstens { $max_name } Buchstaben.
    [provider_name] Der Name hat höchstens { $name_limit } Zeichen.
    [unsaved_text] Ein ungespeicherter Text behält höchstens { $max_text } Zeichen.
    [voice_name] Der Name einer Stimme hat höchstens { $name_most } Zeichen.
   *[other] Das ist länger als { $most } Zeichen.
}
error-out-of-range = { $what ->
    [authors_note_depth] Die Notiz steht eine Nachricht zurück oder weiter.
    [companion_size] Die Größe der Begleitung reicht von { $start } bis { $end } Prozent der Bildschirmhöhe.
    [context_size] Die Kontextgröße muss mindestens 512 Tokens betragen.
    [entry_chance] Die Wahrscheinlichkeit eines Eintrags beträgt höchstens 100 Prozent.
    [provider_setting] { $name } muss zwischen { $min } und { $max } liegen.
    [reply_length] Die Antwortlänge muss zwischen 1 und { $most_reply_length } Tokens liegen.
    [slider] Ein Schieberegler reicht von 0 bis 100.
    [talk_pause] Die Pause muss zwischen 0 und { $most_talk_pause } Sekunden liegen.
    [talk_replies] Die Antworten in Folge müssen zwischen 1 und { $most_talk_replies } liegen.
    [talkativeness] Die Gesprächigkeit reicht von 0 bis 100.
    [voice_speed] Die Geschwindigkeit reicht von { $start } % bis { $end } %.
   *[other] Das muss zwischen { $least } und { $most } liegen.
}
error-taken = { $what ->
    [card_in_library] Schon in deiner Bibliothek.
    [account_name] Ein anderes Konto heißt „{ $name }“.
    [card_language] Die Karte gibt es schon auf { $name }.
    [chat_character] { $name } ist schon in diesem Chat.
    [chat_character_twice] { $name } ist zweimal in diesem Chat.
    [lorebook_same_name] Die Karte hat inzwischen ein Lorebook oder einen Eintrag mit demselben Namen.
    [model_file] { $name } ist schon im Ordner.
    [preset_name] Ein anderes Preset heißt „{ $name }“.
    [tool_name] Ein Werkzeug namens { $name } gibt es schon; wähle einen anderen Namen.
   *[other] Das gibt es schon.
}
error-in-trash = { $what ->
    [card] Der Charakter liegt im Papierkorb; stell ihn zuerst wieder her.
    [card_to_chat] Der Charakter ist im Papierkorb; stelle den Charakter wieder her, um wieder zu chatten.
    [chat] Der Chat liegt im Papierkorb; stell ihn zuerst wieder her.
    [chat_card] Sein Charakter „{ $title }“ liegt im Papierkorb; stell zuerst den Charakter wieder her.
    [lorebook] Das Lorebook „{ $name }“ liegt im Papierkorb; stell es zuerst wieder her.
    [lorebook_to_use] Das Lorebook „{ $name }“ liegt im Papierkorb; stell es wieder her, um es zu verwenden.
    [persona_default] Eine Persona im Papierkorb kann nicht der Standard sein; stell sie zuerst wieder her.
    [persona_to_use] Die Persona „{ $name }“ liegt im Papierkorb; stell sie wieder her, um sie zu verwenden.
   *[other] Das liegt im Papierkorb; stell es zuerst wieder her.
}
error-not-readable = { $what ->
    [damaged_key] Sein Schlüssel ist beschädigt.
    [json] Die Datei ist kein gültiges JSON.
    [lorebook] Die Datei enthält kein Lorebook.
    [lorebook_not_card] Die Datei ist eine Charakterkarte, kein Lorebook.
    [account_picture] Das Bild ist kein lesbares PNG oder JPEG mit höchstens 4.096 Pixeln pro Seite.
    [attachment_picture] Ein Bild ist eine PNG-, JPEG- oder WebP-Datei.
    [backup] Diese Datei ist keine Sicherung von Cardwave.
    [backup_damaged] Diese Sicherung ist beschädigt.
    [backup_newer] Diese Sicherung stammt aus einem neueren Cardwave. Aktualisiere Cardwave, um sie wiederherzustellen.
    [backup_key] Diese Sicherung ist beschädigt: Ihr Schlüssel lässt sich nicht lesen.
    [base64] Das ist kein Base64.
    [base64_file] { $name } ist kein Base64.
    [card_defined_twice] Diese Datei ist keine Charakterkarte, die Cardwave lesen kann. Exportiere sie noch einmal aus der App, aus der sie stammt.
    [card_file_name] Ein Dateiname in der Karte lässt sich nicht verwenden.
    [card_reference] Das bezeichnet keinen Teil der Karte.
    [ccv4_version] Diese Karte stammt aus einem neueren Cardwave. Aktualisiere Cardwave, um sie zu öffnen.
    [comfyui_address] Die Adresse von ComfyUI lässt sich nicht lesen.
    [comfyui_answer] Die Antwort von ComfyUI lässt sich nicht lesen.
    [dictation_recording] Die Aufnahme konnte nicht gelesen werden. Nimm noch einmal auf.
    [document_text] { $name } hat keinen lesbaren Text.
    [document_type] Ein Dokument ist eine .txt-, .md-, .pdf- oder .docx-Datei.
    [downloaded_model] Die heruntergeladene Datei ist nicht das Modell.
    [expression_pack] Keines seiner Bilder ist nach einer Stimmung auf Englisch benannt, wie joy.png oder anger.png (PNG, JPEG, WebP oder GIF).
    [figure_file] { $file_name } ist keine Datei dieser Art.
    [figure_still] Das Standbild der Figur ist kein PNG mit höchstens 4 MB.
    [figure_type] Eine 3D-Figur ist eine VRM-, GLB- oder FBX-Datei.
    [folder_read] Der Ordner lässt sich nicht lesen.
    [format_version] Diese Datei ist keine Charakterkarte, die Cardwave lesen kann. Exportiere sie noch einmal aus der App, aus der sie stammt.
    [image_model_answer] Die Antwort des Bildmodells lässt sich nicht lesen.
    [image_model_picture] Das Bild des Bildmodells lässt sich nicht lesen.
    [key_characters] Der Schlüssel enthält Zeichen, die ein Schlüssel nicht haben kann. Kopiere ihn noch einmal von der Seite des Anbieters.
    [lorebook_empty] Das Lorebook ist leer.
    [lorebook_entries] Das Lorebook hat keine Einträge.
    [lorebook_file] Das Lorebook lässt sich nicht lesen.
    [lorebook_named] Das Lorebook „{ $name }“ lässt sich nicht lesen.
    [lorebook_named_empty] Das Lorebook „{ $name }“ ist leer.
    [models_dev_list] Die Liste der Modelle lässt sich nicht lesen.
    [models_list_answer] Die Adresse antwortet, aber nicht mit einer Liste von Modellen.
    [models_list_missing] Die Liste der Modelle kam nicht an.
    [name_characters] Der Name enthält Zeichen, die ein Name nicht haben kann.
    [no_lorebook] Das ist kein Lorebook.
    [pdf] Das PDF lässt sich nicht lesen.
    [picture] Das Bild ist kein PNG, JPEG oder WebP.
    [picture_server_answer] Die Antwort des Bildservers lässt sich nicht lesen.
    [picture_unreadable] Das Bild lässt sich nicht lesen.
    [png] Keine PNG-Datei.
    [no_card] Diese Datei enthält keine Charakterkarte.
    [png_damaged] Das PNG ist beschädigt.
    [charx] Cardwave kann CHARX-Kartendateien noch nicht importieren. Exportiere die Karte stattdessen als PNG oder JSON.
    [provider_address] Die Adresse muss eine einfache Webadresse sein, etwa https://api.openai.com/v1.
    [provider_website] Gib die Website des Anbieters als Namen an, etwa example.com.
    [recording_format] Das Format der Aufnahme lässt sich nicht lesen.
    [recording_pcm] Die Aufnahme konnte nicht gelesen werden. Nimm noch einmal auf.
    [recording_rate] Die Abtastrate der Aufnahme lässt sich nicht lesen.
    [recording_short] Die Aufnahme ist zu kurz: Es werden mindestens { $shortest } Sekunden gebraucht.
    [recording_silent] Die Aufnahme hat keinen Ton.
    [recording_wav] Die Aufnahme ist keine WAV-Datei.
    [sillytavern_base64] Diese Datei ist keine Charakterkarte, die Cardwave lesen kann. Exportiere sie noch einmal aus der App, aus der sie stammt.
    [sillytavern_empty] Die Karte ist leer.
    [sillytavern_file] Die SillyTavern-Karte in dieser Datei lässt sich nicht lesen.
    [sillytavern_json] Diese Datei ist keine Charakterkarte, die Cardwave lesen kann. Exportiere sie noch einmal aus der App, aus der sie stammt.
    [sillytavern_object] Diese Datei ist keine Charakterkarte, die Cardwave lesen kann. Exportiere sie noch einmal aus der App, aus der sie stammt.
    [sillytavern_png] Die SillyTavern-Karte in diesem PNG lässt sich nicht lesen.
    [spec_version] Diese Datei ist keine Charakterkarte, die Cardwave lesen kann. Exportiere sie noch einmal aus der App, aus der sie stammt.
    [spec_version_form] Diese Datei ist keine Charakterkarte, die Cardwave lesen kann. Exportiere sie noch einmal aus der App, aus der sie stammt.
    [toml] Diese Datei ist keine Charakterkarte, die Cardwave lesen kann. Exportiere sie noch einmal aus der App, aus der sie stammt.
    [word_file] Die Word-Datei lässt sich nicht lesen.
    [word_text] Die Word-Datei hat keinen Text.
    [workflow] Der Workflow „{ $name }“ lässt sich nicht lesen.
    [workflow_api_form] Der Workflow ist in der Form für die API gespeichert: Speichere ihn in ComfyUI als Workflow.
    [workflow_broken] Der Workflow lässt sich nicht lesen.
    [workflow_fields] Der Knoten „{ $kind }“ des Workflows hat Felder, die Cardwave nicht lesen kann.
    [workflow_no_node] Der Workflow hat keinen Knoten, den dieses ComfyUI ausführen kann.
    [workflow_node] Den Knoten „{ $class }“ des Workflows hat dieses ComfyUI nicht.
    [zip] { $name } lässt sich nicht als ZIP lesen.
   *[other] Das lässt sich nicht lesen.
}
error-too-big = { $what ->
    [card_for_worker] Der Charakter ist zu lang für das Hilfsmodell; wähle ein Hilfsmodell, das mehr liest.
    [card_for_chat] Der Charakter ist zu lang für das Chatmodell und wäre so nicht er selbst; wähle ein Chatmodell, das mehr liest, oder kürze den Charakter.
    [card_file] Die Datei ist größer als { $most } MB.
    [checkpoint_folder] Der Ordner ist zu groß, um vor jedem Schritt Kopien davon zu behalten.
    [expression_pack_size] Die Bilder von { $name } sind zu groß.
    [expression_zip_files] { $name } enthält mehr als { $max_entries } Dateien.
    [figure] Die 3D-Figur ist zu groß.
    [model_for_computer] { $name } ist zu groß für diesen Computer.
    [models_dev_list] Die Liste der Modelle ist zu lang.
    [picture_pixels] Das Bild ist zu groß ({ $wide } × { $high } Pixel).
    [reply] Die Antwort wurde abgeschnitten: Sie wurde zu lang.
   *[other] Das ist zu groß.
}
error-not-now = { $what ->
    [character_has_written] { $name } hat in diesem Chat geschrieben und bleibt darin.
    [coding_folder_busy] In diesem Ordner läuft eine andere Programmieraufgabe; warte auf sie oder halte sie an.
    [database_busy] Cardwave war beschäftigt; versuch es noch einmal.
    [download_cancelling] Sein Download wird abgebrochen; versuch es gleich noch einmal.
    [held_by_card] Ein Charakter verwendet das; entferne es zuerst von dem Charakter.
    [lorebook_used_elsewhere] Das Lorebook wird inzwischen anderswo verwendet und bleibt deshalb in der Bibliothek.
    [model_downloading] Das Modell wird heruntergeladen.
    [model_replying] Das Modell antwortet gerade; lösche es, wenn die Antwort fertig ist.
    [search_model_not_downloaded] Das Suchmodell ist nicht heruntergeladen.
    [task_running] Die Aufgabe läuft noch; halte sie zuerst an.
   *[other] Das geht gerade nicht. Versuch es gleich noch einmal.
}
error-changed = { $what ->
    [lorebook_entry] Das Lorebook hat inzwischen einen anderen Eintrag.
    [card_version] Die Karte wurde inzwischen geändert; sie wird neu gelesen.
    [tool_name] Ein anderes Werkzeug heißt jetzt { $name }.
    [two_ways] { $reference } wurde gleichzeitig zweimal geändert; versuch es noch einmal.
    [workflow] Der Workflow „{ $name }“ wurde in ComfyUI geändert: Wähle ihn unter Einstellungen › Anbieter noch einmal.
   *[other] Das wurde inzwischen geändert; versuch es noch einmal.
}
error-not-possible = { $what ->
    [back_to_computer] Nur Suche und Stimme können zurück auf diesen Computer.
    [card_about_itself] Was die Karte über sich selbst sagt, lässt sich nicht ändern.
    [card_change] Das lässt sich in dieser Karte nicht ändern.
    [card_character] Diesen Charakter hat die Karte nicht.
    [card_character_change] Der Charakter der Karte lässt sich nicht ändern.
    [card_language_beside] Die Karte kann { $name } nicht neben ihrer ersten Sprache enthalten.
    [card_lorebook] Dieses Lorebook bringt die Karte nicht mit.
    [card_lorebook_attached] Dieses Lorebook ist der Karte nicht beigefügt.
    [card_mode] Diesen Modus hat die Karte nicht.
    [card_no_character] Die Karte hat keinen Charakter.
    [card_not_changed] Die Karte wurde nicht geändert.
    [card_part] Das ist kein Teil der Karte, der sich ändern lässt.
    [card_takes_no] Diese Karte nimmt nichts Neues dieser Art an.
    [card_takes_no_lorebook] Die Karte nimmt kein Lorebook an.
    [character_change] Dieser Charakter lässt sich in dieser Karte nicht ändern.
    [chat_character] Diesen Charakter hat der Chat nicht.
    [chat_lore] Dieses Lorebook oder diesen Lorebook-Eintrag hat der Chat nicht.
    [chat_lorebook] Dieses Lorebook hat der Chat nicht.
    [chat_mode] Diesen Modus hat der Chat nicht.
    [chat_no_character] Der Chat hat keinen Charakter.
    [chat_without_character] Ein Chat ohne Charakter hat keine Charaktere.
    [chat_without_character_add] Ein Chat ohne Charakter nimmt keinen auf.
    [checkpoint_put_back] { $path } lässt sich nicht zurücksetzen.
    [comfyui_no_picture] ComfyUI hat kein Bild erstellt.
    [companion_not_answering] Die Begleitung hat nicht geantwortet.
    [companion_not_shown] Die Begleitung wird nicht gezeigt.
    [comfyui_queue] ComfyUI hat das Bild nicht in die Warteschlange gestellt.
    [comfyui_said] ComfyUI sagte: { $said }
    [continue_no_text] Die Antwort hat keinen Text zum Fortsetzen.
    [continue_only_reply] Nur die Antwort eines Charakters kann fortgesetzt werden.
    [depth_note] Eine Notiz in einer Tiefe lässt sich nicht hinzufügen.
    [dictation_failed] Das Diktatmodell ist ausgefallen.
    [dictation_model_load] Das Diktatmodell lässt sich nicht laden.
    [dictation_model_start] Das Diktatmodell lässt sich nicht starten.
    [draft_made_by] Ein Entwurf wird nicht von „{ $made }“ erstellt.
    [edit_breaks_card] Die Karte ließe sich nach dieser Änderung nicht mehr lesen.
    [entry_change] Der Eintrag lässt sich in diesem Lorebook nicht so ändern.
    [entry_taken_out] Das ist kein herausgenommener Lorebook-Eintrag.
    [export_no_character] Die Karte hat keinen Charakter zum Exportieren.
    [greeting] Das ist keine der Begrüßungen dieses Charakters.
    [improve_direction] Verbessern nimmt die Worte im Feld; einen Hinweis nimmt es nicht.
    [key_refused] Der Schlüssel wurde abgelehnt.
    [llama_server_start] Das Suchmodell lässt sich nicht starten. Starte Cardwave neu und versuch es noch einmal.
    [local_address] Die Modelle dieses Computers werden über ihren Ordner gefunden, unter Einstellungen › Anbieter.
    [lorebook_change] Dieses Lorebook lässt sich nicht ändern.
    [lorebook_change_breaks] Das Lorebook ließe sich nach dieser Änderung nicht mehr lesen.
    [lorebook_new_entry] Dieses Lorebook nimmt keinen neuen Eintrag an.
    [lorebook_put_in] Das Lorebook lässt sich nicht in diese Karte aufnehmen.
    [lorebook_take_out] Das Lorebook lässt sich nicht aus dieser Karte herausnehmen.
    [message_not_in_chat] Die Nachricht gehört nicht zu diesem Chat.
    [message_not_in_view] Die Nachricht ist nicht im Blick.
    [model_remove] { $path } lässt sich nicht entfernen.
    [no_folder] Diesen Ordner gibt es auf diesem Computer nicht.
    [no_image_model] Es ist noch kein Bildmodell eingerichtet: Richte eines unter Einstellungen › Modelle › Bilder ein.
    [no_local_model] In diesem Ordner gibt es kein Modell „{ $id }“.
    [no_local_models] Lokale Modelle sind nicht eingerichtet.
    [no_recycle_bin] Für { $path } gibt es keinen Windows-Papierkorb.
    [no_summary] Die Karte hat noch keine Zusammenfassung.
    [no_voice] Diese Stimme gibt es nicht.
    [no_vulkan] Die Grafikkarte dieses Computers kann keine Modelle ausführen. Nutze stattdessen einen Anbieter.
    [no_vulkan_dictation] Die Grafikkarte dieses Computers kann das Diktat nicht ausführen.
    [prompt_change] Der Prompt dieses Charakters lässt sich in dieser Karte nicht ändern.
    [recycle_bin_move] { $path } wurde nicht in den Windows-Papierkorb verschoben.
    [speaker_not_in_chat] Der Sprecher gehört nicht zu diesem Chat.
    [speaker_only_character] Nur die Nachricht eines Charakters hat einen Sprecher.
    [unknown_language] Diese Sprache kennt die App nicht.
    [version_lacks_character] Ein Chat ist mit einem Charakter, den die neueste Version nicht hat.
    [voice_runtime] Zum Vorlesen fehlt ein Teil von Microsoft: Installiere das Visual C++ Redistributable von microsoft.com und starte Cardwave dann neu.
    [workflow_no_text] Der Workflow „{ $name }“ hat kein Textfeld für die Worte des Bilds.
    [workflow_use] Der Workflow „{ $name }“ lässt sich nicht verwenden.
    [written_tools_full] Du kannst höchstens { $most_tools } Werkzeuge behalten; lösche zuerst eines unter Einstellungen › Werkzeuge der KI.
    [delete_not_in_trash] Nur was im Papierkorb liegt, lässt sich endgültig löschen; leg es zuerst dorthin.
   *[other] Das geht nicht.
}
error-model-answer = { $what ->
    [no_greeting] Die KI hat keine Begrüßung geschrieben.
    [background_answer] Die Antwort des Hilfsmodells ließ sich nicht verwenden. Versuch es noch einmal oder wähle ein anderes Hilfsmodell.
    [background_text] Die Antwort des Hilfsmodells ließ sich nicht verwenden. Versuch es noch einmal oder wähle ein anderes Hilfsmodell.
    [card_texts] Die Antwort der KI waren nicht die Texte des Charakters.
    [classification] Die Antwort des Hilfsmodells ließ sich nicht verwenden. Versuch es noch einmal oder wähle ein anderes Hilfsmodell.
    [example_messages] Die KI hat keine Beispielnachrichten geschrieben.
    [no_example_message] Die KI hat eine Beispielnachricht ohne ihren Text geschrieben.
    [json] Die Antwort der KI hatte nicht die verlangte Form.
    [keywords] Die Antwort des Hilfsmodells ließ sich nicht verwenden. Versuch es noch einmal oder wähle ein anderes Hilfsmodell.
    [logline] Die Antwort des Hilfsmodells ließ sich nicht verwenden. Versuch es noch einmal oder wähle ein anderes Hilfsmodell.
    [no_chat_reply] Der Anbieter der KI hat keine Chat-Antwort gesendet.
    [no_fitting_answer] Die KI hat in drei Versuchen keine brauchbare Antwort gegeben.
    [no_picture] Das Bildmodell hat ohne Bild geantwortet.
    [no_plan] Der Planer hat keinen Plan erstellt.
    [no_text] Die KI hat keinen Text gesendet.
    [picture_address] Das Bild des Bildmodells liegt unter einer Adresse, die nicht abgerufen wird.
    [picture_art] Das Bild konnte nicht erstellt werden; versuch es noch einmal.
    [picture_field] Das Hilfsmodell hat kein Feld für die Worte des Bilds gefunden.
    [picture_server_no_picture] Der Bildserver hat ohne Bild geantwortet.
    [picture_words] Das Hilfsmodell hat keine Worte für das Bild geschrieben.
    [rating] Die Antwort des Hilfsmodells ließ sich nicht verwenden. Versuch es noch einmal oder wähle ein anderes Hilfsmodell.
    [reply_broke_off] Die Antwort ist abgebrochen.
    [needs] Die Antwort des Hilfsmodells ließ sich nicht verwenden. Versuch es noch einmal oder wähle ein anderes Hilfsmodell.
    [rounds] Das Team hat seine Arbeit nicht in { $rounds } Runden beendet.
    [search_left_out] Das Suchmodell hat einen Text ausgelassen.
    [search_model] Die Antwort des Suchmodells lässt sich nicht lesen.
    [search_tokens] Die Tokens des Suchmodells lassen sich nicht lesen.
    [title] Die Antwort des Hilfsmodells ließ sich nicht verwenden. Versuch es noch einmal oder wähle ein anderes Hilfsmodell.
    [too_many_tools] Die KI hat zu viele Werkzeuge aufgerufen.
    [worker_mode] Die Antwort des Hilfsmodells ließ sich nicht verwenden. Versuch es noch einmal oder wähle ein anderes Hilfsmodell.
    [worker_texts] Die Antwort des Hilfsmodells ließ sich nicht verwenden. Versuch es noch einmal oder wähle ein anderes Hilfsmodell.
    [server_reported] Der Anbieter der KI meldete: { $reason }
   *[other] Die Antwort der KI lässt sich nicht verwenden.
}
error-timed-out = { $whose ->
    [comfyui] ComfyUI hat das Bild nicht rechtzeitig erstellt.
    [llama_server] Das Suchmodell war nicht rechtzeitig bereit. Versuch es noch einmal.
    [model] Die KI hat nicht rechtzeitig geantwortet. Versuch es noch einmal.
    [model_server] Der Anbieter der KI hat nicht rechtzeitig geantwortet. Versuch es noch einmal.
    [search_model] Das Suchmodell hat nicht rechtzeitig geantwortet.
   *[other] Es kam nicht rechtzeitig eine Antwort.
}
error-unreachable = { $whose ->
    [comfyui] ComfyUI ist nicht erreichbar.
    [image_model] Das Bildmodell ist nicht erreichbar.
    [model_download] Die Datei des Modells lässt sich nicht herunterladen.
    [model_server] Der Anbieter der KI antwortet nicht: Versuche es später noch einmal oder prüfe die Verbindung.
    [picture_address] Das Bild lässt sich nicht abrufen.
    [picture_server] Der Bildserver ist nicht erreichbar.
    [provider_voices] Die Stimmen des Anbieters sind nicht erreichbar.
    [search_model] Das Suchmodell antwortet nicht.
    [provider_voice] Die Stimme des Anbieters ist nicht erreichbar.
    [provider_search_model] Das Suchmodell des Anbieters ist nicht erreichbar.
   *[other] Es ist nicht erreichbar.
}
error-answered = { $whose ->
    [comfyui] ComfyUI antwortete { $status }.
    [model_download] Der Server des Modells antwortete { $status }. Die Verbindung ist in Ordnung; versuch es später noch einmal.
    [model_server] Der Anbieter der KI antwortete { $status }. Versuch es später noch einmal.
    [picture_server] Der Bildserver antwortete { $status }.
    [provider_voices] Die Stimmen des Anbieters antworteten { $status }.
    [search_model] Das Suchmodell antwortete { $status }.
   *[other] Es antwortete { $status }.
}
error-answered-said = { $said ->
    [did_not_take_the_key] Der Anbieter hat den Schlüssel nicht angenommen.
    [asks_for_a_key] Der Anbieter verlangt einen Schlüssel.
   *[other] Der Anbieter hat unter dieser Adresse keine Liste der Modelle.
}
