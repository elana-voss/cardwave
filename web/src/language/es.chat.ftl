

## card-block (card/card-block.ts)

card-block-text = { $madeBy } · { $under }

## coding (chat/coding.ts)

coding-the-team = El equipo de IA
coding-open-task = Abrir tarea de programación
coding-undo-all = Deshacer todo
coding-put-the-folder-back = ¿Dejar la carpeta como estaba antes de la tarea?
coding-add-an-export-of = Añade una exportación de los chats como Markdown, con una prueba.
coding-c-users-you-projects = C:\Users\tu-usuario\Proyectos\app
coding-start-a-coding-task = Empezar una tarea de programación
coding-start = Empezar
coding-goal = Objetivo
coding-a-checkpoint-is-kept = Cardwave guarda una copia de la carpeta antes de cada paso, así cada paso se puede deshacer.

## composer (chat/composer.ts)

composer-whoever-is-named-replies = Responde quien se nombra
composer-the-character-named-in = Responde el personaje nombrado en los mensajes más recientes, y si no se nombra ninguno, otro al azar.
composer-each-replies-in-turn = Cada uno responde por turnos
composer-the-characters-reply-one = Los personajes responden uno tras otro, en el orden del panel lateral.
composer-a-random-one-replies = Responde uno al azar
composer-one-of-the-characters = Responde uno de los personajes al azar, y no el que habló el último.
composer-keep-replying-by-themselves = Los personajes siguen hablando solos
composer-write-for-me = Escribir por mí
composer-uses-what-you-typed = La IA escribe tu mensaje; lo que escribiste la guía y no se envía.
composer-improve = Mejorar mi mensaje
composer-rewrites-what-you-typed = Reescribe lo que escribiste
composer-attach-picture-or-document = Adjuntar imagen o documento
composer-ai-draws-a-picture = La IA dibuja una imagen para el chat; lo que escribiste la guía
composer-joins-this-chat = Otro personaje se une a este chat
composer-add-or-write = Adjuntar, o dejar que la IA escriba
composer-message = Mensaje
composer-send = Enviar
composer-writing-your-message = Escribiendo tu mensaje…
composer-who-replies = Quién responde: { $says }
composer-writes-every-reply = { $name } escribe todas las respuestas.
composer-who-replies-group = Quién responde
composer-joined-the-chat = { $name } se unió al chat.
composer-message-improved = Mensaje mejorado.
composer-message-written-for-you = Mensaje escrito para ti.
composer-message-2 = Mensaje a { $whom }
composer-replies = Responde { $name }

## dictate (chat/dictate.ts)

dictate-dictate = Dictar
mic-none = No se encontró ningún micrófono: conecta uno y vuelve a intentarlo.
mic-not-allowed-desktop = Cardwave no puede usar el micrófono: permítelo en la configuración de privacidad de Windows, en Micrófono.
mic-not-allowed-browser = Esta página no puede usar el micrófono: permítelo en la configuración del navegador para este sitio.
mic-not-started = No se pudo iniciar el micrófono: cierra cualquier otro programa que lo use y vuelve a intentarlo.
mic-not-offered = El navegador no ofrece micrófono en esta dirección: usa uno en el ordenador donde se ejecuta Cardwave.
dictate-dictation-failed = El dictado falló: { $reason }. Inténtalo de nuevo.
dictate-writing-what-was-said = Escribiendo lo que se dijo…
dictate-nothing-was-heard = No se oyó nada.
dictate-stop-dictating = Dejar de dictar

## header (chat/header.ts)

header-chat-title = Título del chat
header-the-title-was-not = El título no se guardó: { $reason }. Inténtalo de nuevo.
header-automatic = Automático
header-automatic-sub = Elige uno de los modos de abajo según lo que escribas
header-new-chat-with-these = Nuevo chat con estos personajes
header-new-chat-with = Nuevo chat con { $name }
header-add-to-favourites = Añadir a Favoritos
header-remove-from-favourites = Quitar de Favoritos
header-chat-options = Opciones del chat
header-with = con { $join }

## messages (chat/messages.ts)

messages-ai = IA
messages-you = { " " }(tú)
messages-you-2 = Tú
messages-writing = Escribiendo…
messages-message-and-the-after = Se borró el mensaje y los { $after } siguientes.
messages-message-deleted = Mensaje eliminado.
messages-branch-from-here = Probar otro camino desde aquí
messages-edit-message = Editar mensaje
messages-stop-reading = Dejar de leer
messages-read-aloud = Leer en voz alta
messages-message-options = Opciones del mensaje
messages-previous-version = Versión anterior
messages-next-version = Versión siguiente
messages-write-again = Escribir de nuevo
messages-continue-reply = Continuar esta respuesta
messages-version-of = Versión { $at } de { $count }
messages-delete-versions = Eliminar, con todas sus versiones ({ $count })
messages-delete-version = Eliminar esta versión
messages-continue-uses-what-you = Continuar esta respuesta · las palabras del campo la guían
messages-generate-reply = Generar respuesta

## narration (narration.ts)

narration-show-pictures-from-the = Mostrar imágenes de la web
narration-a-picture-from-another = Una imagen de otro sitio web está oculta: cargarla le dice a ese sitio que se abrió el chat.
narration-you-can-change-this = Puedes cambiarlo cuando quieras en Ajustes › Apariencia.

## panel (chat/panel.ts)

panel-in-trash = { " " }(en la Papelera)
panel-remove-from-this-chat = Quitar de este chat
panel-chat-details = Detalles del chat
panel-in-trash-locked = En la Papelera: restaura el chat para cambiarlo.
panel-as-an-assistant = Personalidad como asistente
panel-kept-with-the-character = Se guarda con el personaje, para cada chat con este personaje.
panel-memory = Recuerdo
panel-move-up = Subir
panel-move-down = Bajar
panel-in-speaking-order = En orden de turno
panel-options-for = Opciones de { $name }
panel-user = { card-user-stand-in }
panel-new-persona = Nueva persona…
panel-from-settings = { $inUse } (de Ajustes)
panel-default-the-characters-own = Predeterminado (el del personaje)
panel-not-used-this-model = No se usa: este modelo decide la longitud de su respuesta
panel-not-used-while-a = No se usa mientras la IA usa herramientas
panel-tokens-per-reply = Tokens por respuesta
panel-very-short = Muy corta
panel-short = Corta
panel-medium = Media
panel-long = Larga
panel-very-long = Muy larga
panel-pause-between-replies = Pausa entre respuestas
panel-seconds-when-they-reply = En segundos; solo mientras los personajes hablan solos
panel-replies-in-a-row = Respuestas seguidas
panel-by-themselves-then-they = Solos; luego se detienen
panel-reply-length = Longitud de la respuesta
panel-small-tools-then-kept = La IA puede escribirse pequeños programas para buscar o calcular cosas; siguen disponibles en todos los chats
panel-the-characters-bring-none = Los personajes no traen ningún lorebook.
panel-restore = Restaurar
panel-put-back-2 = Volver a poner a { $name }
panel-left-out = No se usa en este chat
panel-in-trash-2 = En la Papelera
panel-used-in-last-reply = Usado en la última respuesta
panel-used-in-this-reply = Usado en esta respuesta
panel-read-on-the-web = Leído en la web
panel-read-from-your-files = Leído de tus archivos
panel-saved-to-memory = Guardado en la memoria
panel-this-character-has-no = Este personaje no tiene imagen.
panel-show-portrait = Mostrar la imagen del personaje
panel-add-lorebook-to-chat = Añadir un lorebook a este chat
panel-entry-of = Entrada de { $lorebook }
panel-portrait-beside = Junto al chat
panel-remove-from-this-chat-2 = Quitar a { $name } de este chat
panel-remove-lorebook-from-this = Quitar el lorebook { $name } de este chat

## pictures (chat/pictures.ts)

pictures-open-the-picture = Abrir la imagen
pictures-change-prompt = Editar descripción
pictures-save-picture = Guardar imagen
pictures-picture-options = Opciones de la imagen
pictures-prompt = Descripción
pictures-make-again = Crear de nuevo

## split (chat/split.ts)

split-open-card-page = Abrir página del personaje
split-hide-card-editor = Ocultar página del personaje
split-card-editor = Página del personaje
split-changes-are-used-from = Los cambios se usan desde la siguiente respuesta
split-this-card-is-in = Este personaje está en la Papelera.

## stats (chat/stats.ts)

stats-chat-history = Mensajes anteriores
stats-reply-statistics = Sobre esta respuesta
stats-context-used = Cuánto de lo que la IA puede leer está en uso
stats-sent-to-the-ai = Enviado a la IA · { $count } tokens
stats-in-all = { $seconds } en total
stats-to-the-first-word = { $seconds } hasta la primera palabra · { $all }

## talk (chat/talk.ts)

talk-the-characters-stopped-after = Los personajes se detuvieron tras { $asked } respuestas.
talk-go-on = Seguir

## title (chat-title.ts)

title-new-chat = Nuevo chat

## chat (companion/chat.ts)

chat-open-in-cardwave = Abrir en Cardwave
chat-compact-chat = Chatea con tu acompañante
chat-read-replies-aloud = Leer las respuestas en voz alta
chat-no-voice = No hay ninguna voz configurada: elige una en Ajustes › Voces
chat-the-card-has-no = Esta tarjeta no tiene ningún personaje con quien chatear. Elige otro con «Cambiar de personaje».
chat-message = Mensaje a { $name }

## main (companion/main.ts)

main-open-chat = Abrir el chat
main-figure-hint = Doble clic para chatear, clic derecho para más
main-walk-around = Pasear
main-sit-still = No moverse
main-change-character = Cambiar de personaje
main-hide-until-tomorrow = Ocultar hasta mañana
main-quit-companion = Cerrar acompañante

## dialogs (dialogs.ts)

dialogs-folder-on-this-computer = Carpeta en este equipo

## dom (dom.ts)

dom-text = { $name }: { $reason }
dom-keep-all = Conservar todos los cambios
dom-chosen-by-you = Elegido por ti
dom-address-copied = Dirección copiada.
dom-the-browser-did-not = aquí no se permitió copiar; selecciona el texto y pulsa Ctrl+C

## edit-form (edit-form.ts)

edit-form-from-to = De { $least } a { $most }
edit-form-a-whole-number-from = Un número entero desde { $least }

## load (figures/load.ts)

load-this-figure-has-no = Cardwave no puede mover esta figura. Las figuras hechas para Mixamo, VRChat, Unity o Ready Player Me sí.

## format (format.ts)

format-today = Hoy
format-comma = { ", " }
format-day-at = { $day }, { $time }
format-yesterday = Ayer
format-kb = { $kb } KB
format-seconds = { $seconds } s

## downloaded (models/downloaded.ts)

downloaded-set-up = Configurar
downloaded-text = { $action } { $toLowerCase }
downloaded-local = En este equipo

## fit-models (models/fit-models.ts)

fit-models-cancel = Cancelar { $name }
fit-models-download = Descargar { $name }
fit-models-model-menu-delete = Menú del modelo: eliminar { $name }
fit-models-delete-this-model = ¿Eliminar este modelo de este equipo? Libera { $size }.
fit-models-gb-of-memory = { $round } GB de RAM · { $folder }
fit-models-downloading = { $fits } · descargando { $percent } %
fit-models-downloaded = { $fits } · descargado
fit-models-model-deleted = Modelo “{ $name }” eliminado.

## images-setup (models/images-setup.ts)

images-setup-image-model = Modelo de imágenes
images-not-set-up = Imágenes de tus personajes · sin configurar

## kinds (models/kinds.ts)

kinds-chat-model = Modelo de chat
kinds-models-from-all-your = Modelos de todos tus proveedores que escriben texto. El que elijas escribe los chats, venga del proveedor que venga.
kinds-models-from-all-your-2 = Modelos de todos tus proveedores que escriben texto. El que elijas es el modelo auxiliar, venga del proveedor que venga.
kinds-images-model = Modelo de imágenes
kinds-models-from-all-your-3 = Modelos de todos tus proveedores que crean imágenes. El que elijas crea las imágenes, venga del proveedor que venga.
kinds-search-model = Modelo de búsqueda
kinds-models-on-this-computer = Modelos de este equipo y de todos tus proveedores que encuentran textos por su significado. El que elijas hace las búsquedas, venga de donde venga.
kinds-models-on-this-computer-2 = Modelos de este equipo y de todos tus proveedores que leen los mensajes en voz alta. El que elijas lee los mensajes, venga de donde venga.
kinds-loading-models = Cargando modelos…
kinds-couldnt-load-the-models = No se pudieron cargar los modelos.
kinds-search-the-models = Buscar en los modelos
kinds-use-this-model = Usar este modelo
kinds-model = Modelo
kinds-type-unknown = { " " }· no se sabe si puede hacerlo
kinds-address = { " " }· { $address }
kinds-this-computer = Un programa de este equipo
kinds-asking-the-provider = Preguntando al proveedor…
kinds-own-on-this-computer = { $own } · en este equipo
kinds-none-of-the-kind = Ninguno de tus proveedores tiene un modelo que haga esto.

## language-line (models/language-line.ts, settings/app-language.ts)

language-line-taken-from-this-computer = La de este equipo hasta que elijas otra
language-line-follows-the-app = Sigue el idioma de la app hasta que lo cambies

## models-group (models/models-group.ts)

models-group-not-configured = Sin configurar
models-group-no-longer-offered = Tu proveedor ya no ofrece este modelo: elige otro.

## provider-form (models/provider-form.ts)

provider-form-a-key-is-saved = Hay una clave guardada
provider-form-asking-the-provider-for = Pidiendo sus modelos al proveedor…
provider-form-the-provider-lists-no = El proveedor no lista modelos. Escribe el nombre del modelo tal como lo escribe el sitio del proveedor.
provider-form-text = { $action } { $what }
provider-form-test-passed = { " " }· prueba superada
provider-form-testing = { " " }· probando…
provider-form-is-saved = ····{ $key_end } está guardada
provider-form-or-type-the-models = { $listedCount }{ $have }. O escribe el nombre del modelo tal como lo escribe el sitio del proveedor.
provider-form-test-failed = La prueba falló: { $failed }. Revisa la clave y la dirección.
provider-form-test-failed-own = La prueba falló: { $failed }. Elige otro modelo o vuelve a descargar este.

## search-setup (models/search-setup.ts)

search-setup-not-downloaded = Sin descargar
search-setup-ready = Listo
search-setup-on-this-computer-download = { $name } · en este equipo · descarga de { $bytes }
search-setup-the-librarys-search-then = Así, la búsqueda de la biblioteca encuentra personajes por aquello de lo que tratan, no solo por sus palabras.
search-setup-reading-cards-left = { " " }· leyendo personajes, quedan { $left }
search-setup-reading-cards-left-2 = Leyendo personajes · quedan { $left }

## find (shell/find.ts)

find-pages = Páginas
find-page = Página

## search-panel (shell/search-panel.ts)

search-panel-nothing-found-for = No se encontró nada para “{ $asked }”.
search-panel-show-all = Mostrar los { $count }
search-panel-open-in-a-new = Abrir en una pestaña nueva
search-panel-what = Personajes, chats, lorebooks, recuerdos, documentos y páginas
search-panel-not-messages = No se busca en el texto de los mensajes; prueba con el personaje del chat.

## advanced (views/advanced.ts)

advanced-sillytavern-v3 = SillyTavern V3
advanced-ccv4 = Character Card V4

## chat (views/chat.ts)

chat-your-next-message-starts = Tu próximo mensaje prueba otro camino desde el mensaje marcado.{ " " }
chat-this-chat-is-in = Este chat está en la Papelera. Restáuralo para seguir escribiendo.
chat-hide-side-panel = Ocultar el panel lateral
chat-show-side-panel = Mostrar el panel lateral
chat-show-card-editor = Mostrar la página del personaje
chat-set-up-a-model = Configurar un modelo
chat-the-characters-keep-replying = Los personajes siguen respondiendo solos: { $asked } de { $talk_replies } respuestas.{ " " }

## chats (views/chats.ts)

chats-last-message = Último mensaje
chats-date-started = Fecha de inicio
chats-no-chats-yet = Todavía no hay chats.
chats-search-chats = Buscar chats
chats-couldnt-load = No se pudieron cargar tus chats.
chats-chat-character-or-card = Buscar un chat o personaje
chats-with = con { $others }
chats-from = en Personajes como { $join }

## coding-task (views/coding-task.ts)

coding-task-checkpoints = Puntos para deshacer
coding-task-put-the-folder-back = ¿Dejar la carpeta como { $toLowerCase }?
coding-task-none-yet = Ninguno todavía
coding-task-changed-files = Archivos cambiados
coding-task-text = { " " }· { $stepSays }
coding-task-team-started = { $folder } · equipo { $team } · empezada { $format } ·{ " " }
coding-task-steps = Pasos
coding-task-undone = { $detail } · deshecho

## documents (views/documents.ts)

documents-no-documents-yet-a = Todavía no hay documentos. Añade uno aquí o adjunta uno en un chat.
documents-what-they-are = La IA lee estos archivos al responder: los de un personaje en cada chat con ese personaje, los de un chat en ese chat.
documents-found-by-meaning-once = La IA encuentra las partes adecuadas por su significado cuando la Búsqueda está configurada.
documents-set-up-search = Configurar la Búsqueda en Ajustes
documents-no-document-found = No se encontró ningún documento.
documents-search-documents = Buscar documentos
documents-name-chat-or-character = Nombre, chat o personaje
documents-document-deleted = Documento eliminado.
documents-for-the-character = Para el personaje{ " " }
documents-for-the-chat = Para el chat{ " " }

## memories (views/memories.ts)

memories-nothing-remembered-yet = Todavía no hay recuerdos.
memories-come-from-chats = Los recuerdos salen de tus chats: cada 20 mensajes, Cardwave guarda lo que cada personaje debería recordar. Aquí puedes cambiarlos o eliminarlos.
memories-no-memory-found = No se encontró ningún recuerdo.
memories-search-memories = Buscar recuerdos
memories-text-chat-or-character = Texto, chat o personaje
memories-known-by = Lo saben
memories-known-by-hint = Quién en el chat lo sabe y puede mencionarlo.
memories-you = tú
memories-you-alone = Tú
memories-edit-memory = Editar recuerdo
memories-memory-deleted = Recuerdo eliminado.
memories-from-the-chat = { " " }· Del chat{ " " }
memories-from-your-chat-with = { " " }· De tu chat con{ " " }
memories-because = porque { $end }
memories-so = así que { $end }

## dictation-setup (voice/dictation-setup.ts)

dictation-setup-on-this-computers-graphics = { $name } · en la tarjeta gráfica de este equipo · { $bytes }
dictation-setup-the-microphone-beside-the = El micrófono junto al campo del mensaje escribirá entonces lo que digas, en español, inglés y otros idiomas. Lo que dices se queda en este ordenador.

## make-voice (voice/make-voice.ts)

make-voice-my-voice = Mi voz
make-voice-make-voice = Crear voz
make-voice-choose-a-file = Elegir un archivo
make-voice-record = Grabar
make-voice-play-back = Reproducir
make-voice-record-again = Grabar de nuevo
make-voice-the-recording-is-too = La grabación es demasiado corta: al menos { $SHORTEST } segundos.
make-voice-cardwave-cant-read-choose = Cardwave no puede leer “{ $name }”. Elige un archivo WAV o MP3.
make-voice-recording = Grabación
make-voice-a-short-recording-of = Una grabación corta de una persona que habla con claridad: de 10 a { $LONGEST } segundos. WAV o MP3.
make-voice-use-only-a-voice = Usa solo una voz que tengas derecho a usar: la tuya, o una cuyo dueño o dueña lo haya aceptado.
make-voice-give-the-voice-a = Ponle un nombre a la voz.

## voice-setup (voice/voice-setup.ts)

voice-setup-made-from-your-recording = Creada a partir de tu grabación
voice-setup-on-this-computer-download = En este equipo · descarga de { $bytes }
voice-setup-play-a-sample-of = Reproducir una muestra de { $name }
voice-setup-stop-the-sample-of = Detener la muestra de { $name }
voice-setup-messages-are-read-aloud = Los mensajes se leen en voz alta en inglés, en este equipo.
voice-setup-use-this-voice = Usar esta voz
voice-setup-hello-im-this-is = Hola, soy { $name }. Así suenan tus mensajes cuando se leen en voz alta.

## voice (voice/voice.ts)

voice-the-voice-stopped-answering = La voz dejó de responder. Inténtalo de nuevo o elige otra voz en Ajustes › Voces.
voice-this-window-cannot-play = Esta ventana no puede reproducir sonido: { $reason }. Revisa la salida de sonido en Windows.

## Written by hand: plurals, conditions and numbers

client-backup-failed = No se pudo hacer la copia de seguridad. Comprueba que se puede escribir en la carpeta y vuelve a intentarlo.
composer-tokens-of = { NUMBER($used, useGrouping: "auto") } de { NUMBER($size, useGrouping: "auto") } tokens
header-chat = Chat
header-chat-archived = Chat archivado.
header-chat-unarchived = El chat volvió del archivo.
messages-tokens = { $count ->
    [one] 1 token
    [many] { NUMBER($count, useGrouping: "auto") } tokens
   *[other] { NUMBER($count, useGrouping: "auto") } tokens
  }
dom-texts-changed-by-ai = { $count ->
    [one] 1 texto cambiado
    [many] { $count } textos cambiados
   *[other] { $count } textos cambiados
  } por la IA
format-days-ago = { $count ->
    [one] hace 1 día
    [many] hace { $count } días
   *[other] hace { $count } días
  }
format-weeks-ago = { $count ->
    [one] hace 1 semana
    [many] hace { $count } semanas
   *[other] hace { $count } semanas
  }
format-months-ago = { $count ->
    [one] hace 1 mes
    [many] hace { $count } meses
   *[other] hace { $count } meses
  }
format-years-ago = { $count ->
    [one] hace 1 año
    [many] hace { $count } años
   *[other] hace { $count } años
  }
format-mb = { NUMBER($mb, minimumFractionDigits: 1, maximumFractionDigits: 1) } MB
format-gb = { NUMBER($gb, minimumFractionDigits: 1, maximumFractionDigits: 1) } GB
fit-models-fits = { $size } · Funciona en este equipo
fit-models-too-large = { $size } · Demasiado grande para este equipo
fit-models-used-for = { $fits } · usado para { $kinds }
provider-form-models = { $count ->
    [one] 1 modelo
    [many] { NUMBER($count, useGrouping: "auto") } modelos
   *[other] { NUMBER($count, useGrouping: "auto") } modelos
  }
provider-form-listed = { $count ->
    [one] 1 modelo listado
    [many] { NUMBER($count, useGrouping: "auto") } modelos listados
   *[other] { NUMBER($count, useGrouping: "auto") } modelos listados
  }
provider-form-listed-not-all = { $count ->
    [one] 1 modelo listado
    [many] { NUMBER($count, useGrouping: "auto") } modelos listados
   *[other] { NUMBER($count, useGrouping: "auto") } modelos listados
  }; no se pudo cargar el resto
provider-form-have = ; { NUMBER($count, useGrouping: "auto") } tienen “{ $part }”
coding-task-verdict-passed = Veredicto del auditor: superada
coding-task-verdict-not-passed = Veredicto del auditor: no superada
documents-words = { $count ->
    [one] 1 palabra
    [many] { NUMBER($count, useGrouping: "auto") } palabras
   *[other] { NUMBER($count, useGrouping: "auto") } palabras
  }
memories-known-by-everyone = Lo saben todos
memories-known-by-these = Lo saben { $names }
memories-known-by-nobody = No lo sabe nadie
lore-tools-entries-changed-by-ai = { $count ->
    [one] 1 entrada cambiada
    [many] { $count } entradas cambiadas
   *[other] { $count } entradas cambiadas
  } por la IA
coding-failed-with-error = Falló: { $error }
coding-planner-doing = Planificador: { $what }
coding-step-doing = Paso { $begun } de { $planned } · { $who }: { $what }
coding-worker = Trabajador { $number }
coding-plans = Planifica los pasos
coding-planned = { $steps ->
    [one] 1 paso planificado
    [many] { $steps } pasos planificados
   *[other] { $steps } pasos planificados
  }
coding-fixes = Corrige lo que encontró el auditor
coding-checks-step = Revisa el paso { $step }
coding-checks-all = Revisa cada paso y ejecuta las pruebas
coding-verdict-tests = { $said } · { $tests }
coding-show-plan = Mostrar el plan
coding-before-step = Antes del paso { $step }
coding-before-fix = Antes de la corrección
coding-looking-at-folder = Mirando la carpeta
coding-looking-at = Mirando { $target }
coding-reading = Leyendo { $target }
coding-writing = Escribiendo { $target }
coding-running-command = Ejecutando: { $target }
coding-installing = Instalando: { $target }
coding-searching-web = Buscando en la web: { $target }
coding-files = { $files ->
    [one] 1 archivo
    [many] { $files } archivos
   *[other] { $files } archivos
  }
coding-no-files-changed = Ningún archivo cambiado
coding-lines-files = { $lines } · { $files }
messages-copy-refused = aquí no se permitió copiar; selecciona el texto y pulsa Ctrl+C
panel-book-persona = persona
panel-book-every-chat = todos los chats
stats-model = Modelo
stats-response-time = Tiempo de respuesta
stats-context = Contexto
stats-context-says = { $used } de { $size } tokens usados · { $free } libres
documents-the-chat = el chat
models-download-recommended = Encuentra personajes por aquello de lo que tratan · { $size } de descarga · recomendado
models-downloading = { $name } · descargando { $percent } %
models-on-this-computer = { $name } · Este equipo{ $reading }
voice-setup-voice-download = Lee las respuestas en voz alta · { $name } ({ $about }) · { $size } de descarga
voice-setup-downloading = Descargando { $percent } %
panel-persona-default = Se usa en los chats nuevos
panel-who-you-are-in-this-chat = Quién eres en este chat
panel-use-in-this-chat = Usar en este chat
panel-click-a-reply = Haz clic en una respuesta para ver qué usó.
