### Las palabras de la interfaz en español, traducidas del inglés (en.ftl, el archivo de referencia), clave por
### clave; la prueba de estructura (structure.test.ts) comprueba que todo esté y tenga la misma forma.
### Lista de palabras, un nombre por cosa, en todos los es.*.ftl:
###   Trato: tú (informal, como es habitual en las apps); al usuario nunca con género (nada de «seguro/a»: se reformula).
###   Cardwave, MCP, Claude Desktop, CSS, Lorebook, Persona(s), prompt, preset, chat: se quedan así.
###   character = personaje (la figura de los chats); card = tarjeta (el archivo, tarjeta de personaje); figure = figura (3D).
###   memory = recuerdo; document = documento; library = biblioteca; knowledge = conocimiento; account = cuenta.
###   provider = proveedor; model = modelo; helper (model) = modelo auxiliar; AI = IA; tool = herramienta; tab = pestaña.
###   Settings = Ajustes; Advanced = Avanzado; Trash = Papelera (la de Cardwave);
###   Recycle Bin = Papelera de reciclaje (la de Windows); backup = copia de seguridad; restore = restaurar; Sharing = Compartir.
###   companion = acompañante (con «tu», sin artículo con género); voice = voz; dictation = dictado; Search Cardwave = Buscar en Cardwave.
###   coding team = equipo de programación; planner = planificador; worker = trabajador; auditor = auditor; task = tarea.
###   sign in = iniciar sesión; sign out = cerrar sesión; lock = bloquear; import = importar; export = exportar.
###   interview = entrevista; generator = generador de personajes; theme = tema; first run = primera configuración.
###   Papeles de otras personas: ambas formas (amigo/a, compañero/a, tu ex), nunca solo una.
###   Etiquetas dentro de una frase en minúscula (midSentence, como en inglés).

## The app

app-name = Cardwave

## The pages, as tabs, the rail and Search Cardwave name them (shell/pages.ts)

page-chats = Chats
page-characters = Personajes
page-lorebooks = Lorebooks
page-personas = Personas
page-memories = Recuerdos
page-documents = Documentos
page-generator = Generador de personajes
page-interview = Crear un personaje juntos
page-profile = Perfil
page-server = Compartir
page-settings = Ajustes
page-providers = Proveedores
page-voices = Voces
page-advanced = Avanzado
page-css = CSS de Cardwave
page-written-tools = Herramientas que escribió la IA
page-coding-team = Equipo de programación
page-trash = Papelera
page-about = Acerca de Cardwave
page-coding-task = Tarea de programación
page-chat = Chat
page-new-card = Nuevo personaje
page-lorebook = Lorebook
page-card = Personaje
page-prompt-preset = Preset de prompt
page-first-run = Configurar Cardwave

## The places pages are under

place-library = Biblioteca
place-knowledge = Conocimiento
place-account = Cuenta
place-settings = Ajustes
place-advanced = Ajustes › Avanzado

## The rail (shell/rail.ts)

rail-create = Crear
rail-memories-tip = Recuerdos: lo que la IA recuerda de tus chats
rail-documents-tip = Documentos: archivos que la IA lee al responder
rail-show-more = Mostrar { $count } más
rail-open-menu = Abrir barra lateral
rail-close-menu = Cerrar barra lateral
rail-collapse = Contraer barra lateral
rail-expand = Expandir barra lateral
rail-account = Cuenta
rail-account-named = Cuenta: { $name }
rail-lock = Bloquear

## Create's lines (shell/create.ts)

create-new-chat = Nuevo chat
create-plain-chat = Chat sin personaje
create-new-card = Nuevo personaje
create-from-picks = Generador de personajes
create-together = Crear un personaje juntos
create-new-persona = Nueva persona
create-new-lorebook = Nuevo lorebook
create-import-card = Importar tarjeta
create-import-lorebook = Importar lorebook
create-new = Nuevo
create-import = Importar

## The title bar and its tabs (shell/titlebar.ts)

tabs = Pestañas
tab-new = Nueva pestaña
tab-new-keys = Nueva pestaña (Ctrl+T)
tabs-all = Todas las pestañas
tab-close = Cerrar pestaña
window-minimize = Minimizar
window-maximize = Maximizar
window-close = Cerrar

## The view menu (shell/view-menu.ts, theme.ts)

view = Ver
view-compact = Compacto
theme-system = Sistema
theme-light = Claro
theme-dark = Oscuro
theme-downtempo = Downtempo
theme-outrun = Outrun
theme-retrowave = Retrowave
theme-neonwave-dark = Neon Wave oscuro
theme-neonwave-light = Neon Wave claro

## Search Cardwave's button (shell/search-panel.ts)

search = Buscar en Cardwave
search-keys = Buscar en Cardwave (Ctrl+K)

## The labels of the settings, as their pages and Search Cardwave name them (setting-labels.ts)

label-settings-theme = Tema
label-settings-chat-layout = Diseño del chat
label-settings-web-pictures = Mostrar imágenes de otros sitios web
label-settings-app-language = Idioma de la app
label-settings-language = Idioma en que escribe la IA
label-settings-providers = Proveedores
label-settings-chat = Chat
label-settings-images = Imágenes
label-settings-voice = Voz
label-settings-search = Búsqueda
label-settings-dictation = Dictado
label-settings-web = Web
label-settings-files = Archivos
label-settings-commands = Comandos
label-settings-image-generation = Generación de imágenes
label-settings-app = Cardwave
label-settings-dice = Dados
label-settings-folder = Carpeta
label-settings-written = Herramientas que escribió la IA
label-settings-coding = Equipo de programación
label-settings-trash = Papelera
label-settings-backup = Copia de seguridad
label-settings-restore = Restaurar
label-settings-cards-folder = Carpeta de tarjetas
label-settings-advanced = Avanzado
label-settings-setup = Repetir la configuración
label-settings-about = Acerca de Cardwave
label-providers-this-computer = Este equipo
label-voices-model = Modelo de voz
label-voices-speed = Velocidad
label-voices-english = Inglés
label-advanced-background = Modelo auxiliar
label-advanced-told = Lo que se le dice a la IA
label-advanced-describe = Describir personajes importados
label-advanced-described = Personajes descritos
label-advanced-interview = Crear un personaje juntos
label-advanced-format = Formato de exportación
label-advanced-history = Incluir versiones anteriores de cada texto
label-advanced-css = Tu propio CSS
label-coding-planner = Planificador
label-coding-workers = Trabajadores
label-coding-auditor = Auditor
label-profile-name = Nombre
label-profile-picture = Imagen
label-profile-password = Contraseña
label-server-network = Accesible en la red de casa
label-server-address = Dirección
label-server-mcp = Dejar que las apps de IA de este equipo usen Cardwave

layout-bubbles = Burbujas
layout-plain = Sencillo

## Settings (views/settings.ts)

settings-appearance = Apariencia
settings-theme-about = Sigue al sistema, salvo que elijas uno
settings-layout-about = Mensajes como burbujas o como texto sencillo
settings-web-pictures-about = Esos sitios web pueden ver cuándo abres el chat.
settings-language = Idioma
settings-data = Datos
settings-trash-about = { $count ->
    [one] 1 elemento
    [many] { $count } elementos
   *[other] { $count } elementos
  } · se vacía a los { $days } días
settings-open-trash = Abrir la Papelera
settings-open = Abrir
settings-version = Versión { $version } · licencias
settings-licences = Licencias
settings-advanced-about = Modelo auxiliar, biblioteca, exportación, chat sin personaje, muestreo, presets, tu propio CSS
settings-setup-about = Proveedores, modelos y voz, paso a paso
settings-providers-about = Direcciones y claves de los servicios que ejecutan los modelos
settings-this-computer = este equipo
settings-providers-named = Configurados: { $names }
settings-models = Modelos
settings-the-chat-model = el modelo de chat
settings-the-image-model = el modelo de imágenes

## The account's tabs and accounts (shell/account-tabs.ts, settings/accounts.ts)

account-sections = Secciones de la cuenta
account-switch = Cambiar de cuenta

account-password = Contraseña
account-switch-to = Cambiar a { $name }
account-password-asked = Escribe la contraseña de { $name }.
account-switch-button = Cambiar
account-add = Añadir cuenta
account-add-about = La cuenta de otra persona en este equipo, con sus propios chats y personajes. Inicia sesión con su contraseña, aquí o en otro dispositivo.
account-name = Nombre
account-added = Cuenta “{ $name }” añadida.
account-add-button = Añadir
account-sign-out = Cerrar sesión
account-none = No hay ninguna cuenta en la que iniciar sesión
account-none-about = Todavía ninguna cuenta puede iniciar sesión desde aquí. En el ordenador donde se ejecuta Cardwave, añade una en Cuenta › Compartir.
account-this-computer = La cuenta de este equipo
account-choose = Elige tu cuenta
account-try-again = Reintentar
account-back = Atrás
account-sign-in = Iniciar sesión

## Backup and Restore (settings/backup.ts)

backup-saving = Guardando la copia de seguridad.
backup-saving-to = Guardando la copia de seguridad en { $folder }.
backup-password = Contraseña
backup-repeat = Repite la contraseña
backup-encrypted = La copia de seguridad se cifra con esta contraseña; para restaurarla hace falta la contraseña, aquí o en otro equipo.
backup-forgotten = Una contraseña olvidada no se puede recuperar, y sin ella la copia de seguridad no se puede restaurar.
backup-with-password = Hacer una copia de seguridad con contraseña
backup-differ = Las dos contraseñas no coinciden.
backup-back-up = Guardar copia
backup-no-file = Ningún archivo elegido
backup-choose-file = Elegir archivo
backup-its-password = La contraseña de la copia de seguridad
backup-restoring = Restaurar reemplaza todo lo que hay en Cardwave: chats, personajes, personas, lorebooks, recuerdos y ajustes. No se puede deshacer. La contraseña de aquí se queda como está. También se reemplazan las otras cuentas.
backup-restored = Se restauró la copia: todo en Cardwave está como cuando se hizo la copia. Los otros dispositivos vuelven a iniciar sesión.
backup-file = Archivo
backup-restore-title = Restaurar una copia de seguridad
backup-choose-first = Elige primero el archivo de la copia de seguridad.
backup-restore = Restaurar copia
backup-from-file = Desde un archivo de copia de seguridad
backup-about-own = Chats, personajes y ajustes en un solo archivo, cifrado con tu contraseña
backup-about-chosen = Chats, personajes y ajustes en un solo archivo, cifrado con una contraseña que tú eliges

## The folder of cards (settings/card-folder.ts)

folder-watch = Importar tarjetas nuevas automáticamente
folder-watch-about = Una tarjeta puesta en la carpeta entra sola en tu biblioteca
folder-recycle = Mover los archivos importados a la Papelera de reciclaje
folder-recycle-about = Cuando un archivo se importa, va a la Papelera de reciclaje

## The companion's line (library/companion-app.ts)

companion = Acompañante
# The companion window's name, which the system shows in its lists of windows.
companion-window = Acompañante de Cardwave
companion-made = { $name } es tu acompañante.
companion-make = Hacer acompañante
companion-none = Aún no hay acompañante. Abre el menú “…” de un personaje y elige “Hacer acompañante”.
companion-named = { $name } · Se inicia con la app
companion-figure = Figura de acompañante
companion-figure-about = Se muestra para los personajes sin figura 3D propia
companion-figure-woman = Mujer
companion-figure-man = Hombre
companion-figure-robot = Robot
companion-size = Tamaño de acompañante
companion-size-about = La altura de la figura, como parte de la de la pantalla
companion-size-value = { $size } %

## Other programs, MCP (settings/mcp.ts)

mcp-ask-title = Dejar que las apps de IA de este equipo usen Cardwave
mcp-ask = Los programas de este ordenador, como Claude Desktop, pueden leer tus personajes y chats, escribir en tus chats y usar las herramientas activadas en Ajustes › Herramientas. Lo que Cardwave te preguntaría antes no lo pueden hacer.
mcp-switch-on = Activar
mcp-about = Como Claude Desktop, mediante MCP: usan tus personajes, chats y herramientas
mcp-copy-address = Copiar la dirección MCP
mcp-copy = Copiar
mcp-as-account = Como cuenta
mcp-as-account-about = Lo que pueden ver y hacer
mcp-remove-named = Quitar { $program }
mcp-removed = “{ $program }” quitado.
mcp-remove = Quitar
mcp-connected = Conectado
mcp-other-programs = Otros programas
mcp-only-here = Solo pueden conectarse programas de este equipo. Un programa quitado queda fuera hasta que desactives esto y lo vuelvas a activar.

## Your own CSS (settings/own-css.ts)

css-none = Ninguno
css-lines = { $count ->
    [one] 1 línea
    [many] { $count } líneas
   *[other] { $count } líneas
  }
css-about = { $lines } · cambia el aspecto de la app
css-hint = Se aplica después de la hoja de estilos de Cardwave, mientras escribes. Guardar lo conserva; Cancelar lo deshace.
css-edit-own = Editar tu propio CSS
css-edit = Editar

## The password (settings/password.ts)

password-forgotten = Una contraseña olvidada no se puede recuperar, y con ella se pierden tus chats y personajes. Guárdala en un lugar seguro.
password-on-title = Poner una contraseña
password-on-says = Cardwave la pedirá al abrirse. Sin ella nadie puede abrir Cardwave ni leer tus chats en este equipo.
password-on = Poner contraseña
password-on-done = Contraseña puesta.
password-change-title = Cambiar la contraseña
password-change-says = Cardwave pedirá la nueva al abrirse.
password-change = Cambiar
password-change-done = Contraseña cambiada.
password-off-title = Desactivar la contraseña
password-off-says = Cardwave se abrirá sin pedir ninguna. Tus chats y personajes siguen cifrados.
password-off = Desactivar
password-off-done = Contraseña desactivada.
password-differ = Las dos contraseñas no coinciden.
password-other-says = A partir de entonces inicias sesión con la nueva.
password-other-forgotten = Si la olvidas, la cuenta de este equipo puede restablecerla, en Compartir.
password-current = Contraseña actual
password-password = Contraseña
password-new = Nueva contraseña
password-repeat = Repite la contraseña
password-asked-sign-in = Se pide al iniciar sesión
password-is-on = Activada · se pide al abrir la app
password-is-off = Desactivada · cualquiera en este equipo puede abrir Cardwave
password-start-forgotten = Una contraseña olvidada no se puede recuperar.
password-open = Abrir
password-locked-elsewhere = Cardwave está bloqueado en su ordenador. Se abrirá aquí cuando se desbloquee allí.
password-back = Atrás

## Words many pages use

common-use = Usar
common-in-use = { " " }· en uso
common-more = Más
common-edit = Editar
common-duplicate = Duplicar
# The word a copy's name ends in, as in "Rig (copy)".
common-copy-word = copia
common-delete = Eliminar
common-save = Guardar
common-cancel = Cancelar
common-name = Nombre

## Model presets and prompt presets (settings/presets.ts, settings/prompt-presets.ts)

preset-what = Un preset guarda un modelo de chat con sus valores de muestreo. Usar cambia a él.
preset-temperature = temperatura { $value }
preset-new = Nuevo preset
preset-model-presets = Presets de modelo
preset-using = Usando “{ $name }”.
preset-added = Preset “{ $name }” añadido.
preset-deleted = Preset “{ $name }” eliminado.
preset-saved = Preset “{ $name }” guardado.
preset-delete-ask = ¿Eliminar este preset?
preset-replace = Usar el modelo y los ajustes actuales
preset-replace-hint = El modelo de chat, su proveedor y el muestreo de esta página. Desactivado: el preajuste conserva los suyos.
preset-keeps-hint = Conserva el modelo de chat de Ajustes › Modelos, su proveedor y el muestreo de esta página.
preset-name = Nombre
preset-edit = Editar preset
prompt-presets = Presets de prompt
prompt-system = Prompt de sistema
prompt-note = { $depth ->
    [one] Nota, 1 mensaje atrás
    [many] Nota, { $depth } mensajes atrás
   *[other] Nota, { $depth } mensajes atrás
}
prompt-system-note = { $depth ->
    [one] Prompt de sistema · nota, 1 mensaje atrás
    [many] Prompt de sistema · nota, { $depth } mensajes atrás
   *[other] Prompt de sistema · nota, { $depth } mensajes atrás
}
prompt-as-card = Como dice el personaje
prompt-default = Predeterminado
prompt-default-name = “{ $name }” es el prompt propio del personaje.

## Tools (settings/tools.ts, chat/tool-ask.ts)

tools-written-ask = { $count ->
    [0] Ninguna todavía
    [one] 1 herramienta
    [many] { $count } herramientas
   *[other] { $count } herramientas
  } · preguntar antes de que se ejecute una nueva
tools-written-free = { $count ->
    [0] Ninguna todavía
    [one] 1 herramienta
    [many] { $count } herramientas
   *[other] { $count } herramientas
  } · una nueva se ejecuta sin preguntar
tools-folder-first = Elige primero una carpeta
tools-web = Buscar y leer páginas web
tools-files = Solo { $folder }
tools-ask-writes = Preguntar antes de escribir
tools-ask-writes-says = Cada archivo se te muestra antes de escribirlo
tools-commands = Ejecutar en { $folder }, aislado del resto del equipo y de internet
tools-ask-commands = Preguntar antes de ejecutar
tools-ask-commands-says = Cada comando se te muestra antes de ejecutarlo
tools-pictures = Usa el modelo de imágenes
tools-pictures-first = Configura primero el modelo de imágenes
tools-app = Usar y cambiar tus personajes, chats y ajustes; cada cambio se pregunta antes
tools-dice = Deja que la IA tire dados; Cardwave los tira, así el resultado es justo.
tools-folder-example = C:\Users\tu-usuario\Documents\Compartido
tools-folder-says = Los archivos y comandos llegan a esta carpeta y a lo que contiene, y a nada más.
tools-change-folder = Cambiar de carpeta
tools-change = Cambiar
tools-choose = Elegir
tools-none-chosen = Ninguna elegida
tools-title = Herramientas
tools-ask-new = { $name } quiere usar una herramienta nueva: { $what }
tools-ask-write = { $name } quiere escribir “{ $what }” en tu carpeta:
tools-ask-read = { $name } quiere leer en tu carpeta:
tools-ask-install = { $name } quiere descargar e instalar programas que necesita:
tools-ask-web = { $name } quiere usar la web:
tools-ask-app = { $name } quiere cambiar Cardwave:
tools-ask-command = { $name } quiere ejecutar un comando en tu carpeta:
tools-allow = Permitir
tools-deny = Denegar
tools-allow-writing = Permitir escribir archivos en este chat
tools-allow-commands = Permitir comandos en este chat

## Updates (settings/update.ts)

update-title = Buscar actualizaciones
update-available = Cardwave { $version } está disponible
update-you-have = Tienes la { $version }.
update-up-to-date = Cardwave está actualizado ({ $version }).
update-connection-error = No se pudo buscar actualizaciones. Revisa tu conexión.
update-check-failed = No se pudo buscar actualizaciones: GitHub no respondió con la versión más reciente.
update-whats-new = Novedades
update-close = Cerrar
update-ok = Aceptar
update-download = Descargar
update-install = Actualizar y reiniciar
update-installing = Descargando Cardwave { $version }…
update-auto = Buscar automáticamente
update-auto-about = Buscar una versión nueva al iniciar y una vez al día
update-check = Buscar
update-checking = Buscando…
update-about = Comprueba si hay una versión más nueva de la app.

## The breadcrumbs of a page under Settings

crumbs = Dónde estás

## Providers (views/providers.ts)

providers-key-end = { $where } · clave ····{ $end }
providers-key-saved = { $where } · clave guardada
providers-no-key = { $where } · sin clave
providers-thinking-cannot = { $provider } no puede desactivar el razonamiento de este modelo
providers-thinking-off = El modelo responde sin razonar antes
providers-thinking-on = El modelo razona antes de responder
providers-comfy-default = El predeterminado de ComfyUI
providers-workflow-note = Este flujo de trabajo usa sus propios modelos y tamaño, no el modelo de Imágenes.
providers-testing-model = Probando el modelo…
providers-thinking-of = { $label }: razonamiento
providers-thinking = Razonamiento
providers-testing-workflow = Probando el flujo de trabajo…
providers-workflows-from = De los flujos de trabajo que tiene ComfyUI
providers-pictures-by = Imágenes con “{ $name }”.
providers-pictures-default = Imágenes con el flujo de trabajo predeterminado de ComfyUI.
providers-workflow = Flujo de trabajo
providers-not-used = Aún no se usa para nada
providers-folder-saved = Carpeta guardada.
providers-change-folder = Cambiar la carpeta de modelos
providers-choose-folder = Elegir una carpeta de modelos
providers-change = Cambiar
providers-not-set-up = Sin configurar
providers-folder-not-set-up = Ejecuta modelos de una carpeta de este equipo · sin configurar
providers-menu = Menú del proveedor: editar, quitar
providers-remove = Quitar
providers-removed = Proveedor “{ $name }” quitado.
providers-remove-with-models = ¿Quitar este proveedor? Los modelos elegidos de él dejan de usarse.
providers-remove-ask = ¿Quitar este proveedor?
providers-remove-key = Quitar clave
providers-key-removed = La clave se quita al guardar
providers-edit = Editar proveedor
providers-keep-key = Déjalo vacío para conservar la clave guardada.
providers-saved = Proveedor “{ $name }” guardado.
providers-added = Proveedor “{ $name }” añadido.
providers-add = Añadir proveedor
providers-about = Dónde funciona la IA: un servicio en internet o un programa en este equipo. Debajo de cada uno, para qué se usa.

## Voices (views/voices.ts)

voices-stop = Detener { $name }
voices-try = Probar { $name }
voices-model-about = Lee los mensajes en voz alta en este equipo · { $size }
voices-default-of = Voz predeterminada: { $name }
voices-menu = Menú de la voz: renombrar, eliminar
voices-rename = Renombrar
voices-delete-ask = ¿Eliminar la voz «{ $name }»? Los personajes que la usan vuelven a la voz predeterminada.
voices-rename-title = Renombrar voz
voices-name = Nombre
voices-speed-value = { $speed }×
voices-speed = Velocidad
voices-speed-about = Con qué rapidez se leen las respuestas, para todas las voces
voices-make = Crear una voz a partir de una grabación
voices-provider-failed = No se pudieron cargar las voces del proveedor.
voices-provider-none = El proveedor no lista voces
voices-provider-own = Los mensajes se leen con la voz propia del proveedor.
voices-voices = Voces
voices-voices-about = La voz que lee los mensajes en voz alta. Un personaje puede tener la suya en «Voces de los personajes».
voices-default = Voz predeterminada
voices-voice-of = Voz de { $name }
voices-back-default = Volver a la voz predeterminada
voices-name-title = { $name } · { $title }
voices-choose-character = Elige un personaje
voices-all-have = Todos los personajes tienen voz.
voices-set-for = Asignar una voz a un personaje
voices-character = Personaje
voices-voice = Voz
voices-character-first = Elige primero un personaje.
voices-characters = Voces de los personajes
voices-downloading = Descargando · { $size } · { $percent } %
voices-downloaded = Descargado · { $size }
voices-download-size = Descarga de { $size }
voices-action-of = { $action } { $name }
voices-language-downloaded = { $name } descargado
voices-built-in = Incluido
voices-languages = Idiomas que lee
voices-download = Descargar
voices-cancel = Cancelar
voices-delete = Eliminar

## Advanced (views/advanced.ts)

advanced-context-size = Tamaño del contexto (tokens)
advanced-context-hint = Déjalo vacío para 128.000
advanced-temperature = Temperatura
advanced-temperature-about = Más alto: respuestas más sorprendentes. De 0 a 2
advanced-top-p = Top P
advanced-top-p-about = Más bajo: solo las palabras más probables. De 0 a 1
advanced-frequency = Penalización por frecuencia
advanced-frequency-about = Más alto: menos palabras repetidas. De −2 a 2
advanced-presence = Penalización por presencia
advanced-presence-about = Más alto: más temas nuevos. De −2 a 2
advanced-seed = Semilla
advanced-seed-about = El mismo número vuelve a dar la misma respuesta
advanced-from-to = De { $min } a { $max }
advanced-whole-from = Un número entero desde { $min }
advanced-whole = Un número entero
advanced-number = Un número
advanced-sampling = Muestreo
advanced-sampling-about = Para el modelo de chat. Deja un valor vacío para usar el predeterminado del proveedor. Se guarda mientras escribes.
advanced-describing = Describiendo… quedan { $count }
advanced-all-described = Todos los personajes están descritos
advanced-not-described = { $count ->
    [one] 1 personaje sin describir todavía
    [many] { $count } personajes sin describir todavía
   *[other] { $count } personajes sin describir todavía
  }
advanced-describe-cards = Describir personajes
advanced-describe-cost = Unos { $low } a { $high } tokens para { $count ->
    [one] 1 personaje
    [many] { $count } personajes
   *[other] { $count } personajes
  }
advanced-failed = { $count ->
    [one] 1 falló
    [many] { $count } fallaron
   *[other] { $count } fallaron
  }: { $failure }. Pulsa Describir personajes para volver a intentarlo.
advanced-describe-again = Describir todo de nuevo
advanced-describe-again-stop = Detener
advanced-describe-again-about = Con el modelo auxiliar, reescribe la descripción de una línea, el resumen y las etiquetas de cada personaje y aquello por lo que «Por necesidad» lo encuentra, unos 11.000 a 12.000 tokens cada uno. Lo que editaste tú se mantiene. Los proveedores cobran por tokens.
advanced-no-characters = No hay personajes que describir
advanced-describe-again-far = { $done } de { $all } descritos de nuevo
advanced-describe-again-stopped = Detenido en { $done } de { $all } descritos de nuevo
advanced-describe-again-failed = { $count ->
    [one] 1 falló y se queda como estaba
    [many] { $count } fallaron y se quedan como estaban
   *[other] { $count } fallaron y se quedan como estaban
  }: { $failure }. Pulsa Describir todo de nuevo para intentarlo otra vez.
advanced-describe-about = Para cada uno, una descripción de una línea, un resumen y etiquetas, escritos por el modelo auxiliar
advanced-plain = Chat sin personaje
advanced-told-about = Las mismas en cada chat sin personaje. Escribe { "{{date}}" } o { "{{time}}" } y la IA recibe la fecha de hoy o la hora
advanced-library = Biblioteca
advanced-interview-about = Cómo te hace la IA sus preguntas
advanced-interview-tree = Árbol
advanced-interview-cloud = Nube
advanced-interview-hybrid = Híbrido
advanced-data = Datos
advanced-format-about = El formato en que Exportar escribe cada tarjeta; la mayoría de las apps abren SillyTavern V3
advanced-history-about = Las versiones anteriores de cada texto; solo en el formato de tarjeta propio de Cardwave
advanced-helper = Modelo auxiliar
advanced-the-helper = el modelo auxiliar

## Cardwave's CSS (views/css-reference.ts)

cssref-rail = La barra lateral izquierda
cssref-main = Una pantalla junto a la barra lateral
cssref-crumbs = La ruta en lo alto de una página
cssref-group = Un cuadro de líneas, como en los ajustes
cssref-item = Una línea de un cuadro
cssref-row = Una línea de una lista
cssref-tile = Una tarjeta en la cuadrícula de la biblioteca
cssref-msg = Un mensaje en un chat
cssref-bubble = La burbuja de un mensaje
cssref-composer = El campo de mensaje bajo un chat
cssref-dialog = Un diálogo
cssref-btn-primary = El botón azul
cssref-switch = Un interruptor
cssref-pill = Una píldora
cssref-notice = El aviso al pie de la ventana
cssref-snippet-green = Un acento verde
cssref-snippet-square = Burbujas cuadradas
cssref-snippet-larger = Texto más grande
cssref-snippet-wider = Diálogos más anchos
cssref-snippet-tighter = Espaciado más ajustado
cssref-snippet-black = Un tema oscuro negro
cssref-in-dark = { $light } · en oscuro { $dark }
cssref-none = Ninguna variable con ese nombre.
cssref-copy-of = Copiar “{ $title }”
cssref-copied = Copiado.
cssref-copy = Copiar
cssref-about-1 = Las variables y los nombres de clase que puede usar tu propio CSS. Cada color y tamaño de la app es una variable en{ " " }
cssref-about-2 = , con un valor claro y uno oscuro.
cssref-variables = Variables
cssref-search = Buscar
cssref-find = Buscar una variable
cssref-all = { $count } variables en total.
cssref-classes = Nombres de clase
cssref-snippets = Fragmentos

## Tools the AI wrote (views/written-tools.ts)

written-about = { $what } · creada { $made }
written-about-in = { $what } · creada { $made } en { $chat }
written-used = { $count ->
    [0] sin usar todavía
    [one] usada una vez
    [many] usada { $count } veces
   *[other] usada { $count } veces
  }
written-none = Aún no hay herramientas. Activa «Dejar que la IA escriba herramientas» en un chat y lo que escriba aparecerá aquí.
written-ask = Preguntar antes de que se ejecute una herramienta nueva
written-ask-about = Una vez por herramienta: la permites la primera vez que se ejecuta
written-in = { " " }en{ " " }
written-made = Creada { $made }
written-dot-used = { " " }· { $used }
written-switch-off = Desactivar
written-switch-on = Activar
written-intro = Pequeñas herramientas que la IA escribió para sí en chats con «Dejar que la IA escriba herramientas» activado. Solo tocan tus archivos si lo permites y se guardan para chats posteriores.
written-deleted = Herramienta “{ $name }” eliminada.
written-on = { $name } activada
written-view-code = Ver el código

## The coding team, shared by the chat and its pages (chat/coding.ts)

coding-quick = Rápido
coding-balanced = Equilibrado
coding-thorough = Minucioso
coding-custom = Personalizado
coding-running = En curso
coding-done = Hecha
coding-failed = Fallida
coding-stopped = Detenida
coding-team-says-alone = { $name }: un planificador, { $workers ->
    [1] un trabajador
    [2] dos trabajadores
   *[other] tres trabajadores
  }, sin auditor.
coding-team-says-tests = { $name }: un planificador, { $workers ->
    [1] un trabajador
    [2] dos trabajadores
   *[other] tres trabajadores
  } y un auditor que ejecuta las pruebas.
coding-team-says-steps = { $name }: un planificador, { $workers ->
    [1] un trabajador
    [2] dos trabajadores
   *[other] tres trabajadores
  } y un auditor que revisa cada paso y ejecuta las pruebas.
coding-team-label = { $name } · { $workers ->
    [one] 1 trabajador
    [many] { $workers } trabajadores
   *[other] { $workers } trabajadores
  }
coding-team-label-auditor = { $name } · { $workers ->
    [one] 1 trabajador
    [many] { $workers } trabajadores
   *[other] { $workers } trabajadores
  }, auditor
coding-team-label-steps = { $name } · { $workers ->
    [one] 1 trabajador
    [many] { $workers } trabajadores
   *[other] { $workers } trabajadores
  }, auditor en cada paso
coding-tests-pass = Pasan { $passed } de { $total } pruebas
coding-passed = Superada
coding-problems = Encontró problemas

## Coding team (views/coding-team.ts)

team-audit-end = Al final
team-audit-each = Después de cada paso
team-audit-never = Nunca
team-change = Cambiar
team-workers-of = { $model } · { $workers } a la vez
team-worker-model = Modelo de los trabajadores
team-change-worker = Cambiar el modelo de los trabajadores
team-how-many = Cuántos trabajadores
team-none = Ninguno
team-auditor-tests = { $model } · ejecuta las pruebas
team-auditor-steps = { $model } · revisa cada paso
team-auditor-model = Modelo del auditor
team-change-auditor = Cambiar el modelo del auditor
team-when = Cuándo revisa el auditor
team-team = Equipo
team-roles = Papeles
team-planner-model = Modelo del planificador
team-change-planner = Cambiar el modelo del planificador
team-recent = Tareas recientes
team-intro = IA que escriben juntas un programa para ti en este equipo, empezadas desde un chat.
team-no-tasks = Aún no hay tareas. Una tarea se empieza en un chat, con el «+» junto al campo del mensaje › Empezar una tarea de programación.

## Trash (views/trash.ts)

trash-expressions = Expresiones · ningún personaje las tiene
trash-figure = Figura 3D · ningún personaje la tiene
trash-chat-with = Chat con { $names }
trash-chat = Chat
trash-persona = Persona
trash-persona-used = Persona · usada en { $count ->
    [one] 1 chat
    [many] { $count } chats
   *[other] { $count } chats
  }
trash-lorebook = Lorebook
trash-lorebook-used = Lorebook · usado en { $count ->
    [one] 1 chat
    [many] { $count } chats
   *[other] { $count } chats
  }
trash-character = Personaje
trash-character-chats = Personaje · con { $count ->
    [one] 1 chat
    [many] { $count } chats
   *[other] { $count } chats
  }
trash-empty = La Papelera está vacía.
trash-about = Lo que se mueve aquí se guarda { $days } días y luego se elimina para siempre.
trash-emptied = Papelera vaciada.
trash-empty-trash = Vaciar la Papelera
trash-delete-all-ask = ¿Eliminar { $count ->
    [one] el elemento
    [many] los { $count } elementos
   *[other] los { $count } elementos
  } para siempre?
trash-restored = “{ $title }” restaurado.
trash-deleted = “{ $title }” eliminado para siempre.
trash-deleted-at = Movido aquí { $when }
trash-days-left = { $count ->
    [one] Queda 1 día
    [many] Quedan { $count } días
   *[other] Quedan { $count } días
  }
trash-restore = Restaurar
trash-restore-chats = Recupera el personaje y { $count ->
    [one] su chat
    [many] sus { $count } chats
   *[other] sus { $count } chats
  }
trash-delete-forever = Eliminar para siempre
trash-delete-forever-ask = ¿Eliminar “{ $title }” para siempre? No se podrá recuperar.
trash-delete-forever-ask-chats = ¿Eliminar “{ $title }” y { $count ->
    [one] su chat
    [many] sus { $count } chats
   *[other] sus { $count } chats
  } para siempre? No se podrán recuperar.

## About Cardwave (views/about.ts)

about-no-package = Ningún paquete con ese nombre.
about-no-notes = Esta versión no trae notas.
about-by = de { $by }
about-licence-of = Licencia de { $name }
about-licence = Licencia
about-folder-failed = La carpeta no se abrió: { $reason }. Está en { $where }.
about-open-folder = Abrir carpeta
about-logs-where = en la carpeta «logs» de la carpeta de datos de Cardwave, en el ordenador donde se ejecuta Cardwave
about-logs = Registros
about-logs-about = Lo que hizo Cardwave y los fallos, un archivo por día, guardados 7 días: para ayudar cuando algo sale mal · { $where }
about-version = Versión { $version }
about-whats-new = Novedades
about-packages = { $count } paquetes
about-open-source = Software de código abierto
about-search = Buscar
about-find = Buscar un paquete
about-version-built = Versión { $version } · { $built }
about-models = Modelos
about-figures = Figuras y animaciones
about-voices = Voces
about-voice-donations = Voces donadas
about-voice-acted-by = Interpretada por { $name }
about-voice-vctk = Hablante { $speaker } del CSTR VCTK Corpus de Junichi Yamagishi, Christophe Veaux y Kirsten MacDonald, University of Edinburgh; limpiada por Kyutai
about-voice-cml-tts = Hablante { $speaker } de CML-TTS de Frederico S. Oliveira, Edresson Casanova, Arnaldo Candido Junior, Anderson S. Soares y Arlindo R. Galvão Filho, leída para LibriVox
about-voice-cml-tts-cleaned = Hablante { $speaker } de CML-TTS de Frederico S. Oliveira, Edresson Casanova, Arnaldo Candido Junior, Anderson S. Soares y Arlindo R. Galvão Filho, leída para LibriVox; limpiada por Kyutai
about-lists = Lista de proveedores y modelos

about-or = o
about-and = y
about-with = con

## Prompt preset (views/prompt-preset.ts)

prompt-new = Nuevo preset de prompt
promptpage-system = Prompt de sistema
prompt-system-about = Ocupa el lugar del prompt de sistema de la tarjeta. Déjalo vacío para conservar el de la tarjeta.
promptpage-note = Nota
prompt-note-about = La IA la lee antes de cada respuesta; tú no la ves en el chat. Va tantos mensajes atrás como se indica abajo.
prompt-depth = Mensajes atrás
prompt-intro = Instrucciones para la IA. Elige el preset en el panel lateral de un chat para usarlo allí.
prompt-depth-about = 1 la pone justo antes del mensaje más reciente; 4, cuatro mensajes atrás.
prompt-saved = Preset “{ $name }” guardado.
prompt-gone = Este preajuste de prompt se eliminó. Vuelve atrás y elige otro.

## Profile (views/profile.ts)

profile-change-picture = Cambiar la imagen
profile-change = Cambiar
profile-remove-picture = Quitar la imagen
profile-remove = Quitar
profile-picture-changed = Imagen cambiada.
profile-picture-removed = Imagen quitada.
profile-your-picture = Tu imagen
profile-no-picture = Sin imagen: se muestra tu inicial { $letter }
profile-change-name = Cambiar el nombre
profile-this-computer = La cuenta de este equipo
profile-on-server = Cuenta en este equipo
profile-account = Cuenta

## Server (views/server.ts)

server-copy = Copiar
server-no-network = Este ordenador no está conectado a una red. Conéctalo por wifi o cable para dejar entrar a otros dispositivos.
server-switch-on-about = Así, los teléfonos y otros equipos de esta red podrán abrir Cardwave. Cada cuenta inicia sesión con su contraseña.
server-switch-on = Activar
server-network-about = Los teléfonos y otros equipos abren Cardwave en un navegador
server-other-devices = Otros dispositivos
server-inside = Solo los dispositivos de esta red pueden acceder, salvo que configures tu router para dejar entrar a otros.
server-add-account = Añadir cuenta
server-owner = Este equipo · puede añadir y quitar cuentas
server-more-of = Más: { $name }
server-reset-password = Restablecer contraseña
server-delete-account = Eliminar cuenta
server-deleted = Cuenta “{ $name }” eliminada.
server-delete-ask = ¿Eliminar esta cuenta con sus personajes, chats y ajustes? No se puede deshacer.
server-reset-title = Restablecer la contraseña de { $name }
server-reset-about = La cuenta inicia sesión con la nueva, y se cierra su sesión allí donde esté iniciada.
server-new-password = Nueva contraseña
server-reset-done = Contraseña de { $name } restablecida.
server-reset = Restablecer
server-accounts = Cuentas

## Character generator (views/generator.ts)

gen-gender-woman = Mujer
gen-gender-man = Hombre
gen-gender-non-binary = Persona no binaria
gen-being-human = Ser humano
gen-being-not-human = Ser no humano
gen-age-20s = De 20 a 29
gen-age-30s = De 30 a 39
gen-age-40s = De 40 a 49
gen-age-50s-and-older = 50 o más
gen-build-slim = Delgada
gen-build-average = Media
gen-build-athletic = Atlética
gen-build-strong = Fuerte
gen-hair-short = Corto
gen-hair-medium = Media melena
gen-hair-long = Largo
gen-colour-black = Negro
gen-colour-brown = Castaño
gen-colour-blonde = Rubio
gen-colour-red = Pelirrojo
gen-colour-grey = Canoso
gen-colour-white = Blanco
gen-relation-stranger = Desconocido/a
gen-relation-friend = Amigo/a
gen-relation-partner = Pareja
gen-relation-rival = Rival
gen-relation-colleague = Compañero/a de trabajo
gen-relation-mentor = Mentor/a
gen-shy = Timidez
gen-outgoing = Extroversión
gen-gentle = Dulzura
gen-harsh = Dureza
gen-serious = Seriedad
gen-playful = Desenfado
gen-cautious = Cautela
gen-bold = Audacia
gen-random = Al azar
gen-slider = De { $low } a { $high }
gen-looks = Aspecto
gen-gender = Género
gen-being = Humano o no
gen-any = Cualquiera
gen-age = Edad
gen-build = Complexión
gen-hair = Pelo
gen-hair-colour = Color de pelo
gen-personality = Personalidad
gen-relates = Quién es el personaje para ti
gen-make = Crear el personaje
gen-what = Elige unos rasgos; la IA escribe el primer mensaje del personaje y cómo habla.
interview-goes-to = Tus respuestas van a { $provider } para escribir el personaje.
interview-stays = Tus respuestas se quedan en este equipo.
interview-own-words = O añade tus propias palabras
interview-in-own-words = Con tus palabras
interview-your-answer = Tu respuesta
interview-pick-one = Elige una
interview-pick-two = Elige una o dos
interview-pick-three = Elige hasta tres
interview-pick-many = Elige todas las que encajen
interview-few-words = Bastan unas pocas palabras
interview-wanted-hint = ¿Qué echabas en falta con personas, o con personajes que probaste?
interview-needs-hint = Para tu tiempo con el personaje, no para el resto de tu vida
interview-next = Siguiente
interview-skip = Omitir
interview-dont-know = No lo sé
interview-back = Atrás
interview-just-make-it = Créalo ya
interview-more = Más tipos
interview-writing-next = Escribiendo la siguiente pregunta
interview-try-again = Reintentar
interview-failed-where = Si sigue fallando, revisa el proveedor y el modelo en Ajustes › Proveedores.
gen-stop = Detener
gen-writing = Escribiendo el personaje…
interview-understood = Esto es lo que he entendido.
interview-you-said = dijiste: “{ $words }”
interview-own-guess = una suposición propia de la IA
interview-keep = Conservar
interview-change = Cambiar
interview-remove = Quitar
interview-not-it = No es eso
interview-not-it-off = Esta línea no se basa en ninguna pregunta que se pueda volver a hacer
interview-own-sentence = Tu propia frase
interview-private-line = ¿Algo que quieras en el mundo de tu personaje, o nunca?
interview-private-sub = Romance, violencia, palabrotas y más · opcional
interview-make = Crear el personaje
interview-make-after = Después puedes cambiarlo en su página.
interview-skip-all = Omitir todo
interview-private-hint = Algunas personas quieren estas cosas en el mundo de su personaje y otras no. Tus respuestas se quedan con este personaje en tu equipo y solo van a la IA que escribe el personaje.
interview-private-free = Cualquier otra cosa que quieras, o que nunca quieras
interview-yes = Sí
interview-no = No
interview-maybe = Quizá
interview-fantasy-only = Solo en la fantasía
interview-never = Nunca
interview-try-another = Probar otro modelo
interview-without-topic = Escribirlo sin ese tema
interview-model-provider = { $model } · { $provider }
interview-reading = Leyendo tus respuestas
interview-persona-title = ¿Añadir a tu persona lo que dijiste de ti?
interview-persona-field = Persona
interview-persona-in-use = { $persona } · en uso
interview-persona-new = Nueva persona
interview-persona-add = Añadir
interview-persona-not-now = Ahora no
interview-persona-added = Añadido a “{ $persona }”.
interview-persona-you = Tú
