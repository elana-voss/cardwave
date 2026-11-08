### Las palabras de la interfaz en español: las respuestas de error del servidor, una por cada código de
### api/generated/Code.ts (errors.ts), `error-<código>`; traducidas de en.errors.ftl, con la lista de palabras de es.ftl.

## The request, as the server took it

error-request-failed = No se pudo hacer. Inténtalo de nuevo.
error-internal = Algo falló en Cardwave. Inténtalo de nuevo.
error-bad-request = Cardwave no pudo leer esa petición. Recarga la página e inténtalo de nuevo.
error-forbidden = Eso no está permitido.
error-no-such-path = Cardwave no tiene esa página. Recarga la página e inténtalo de nuevo.
error-method-not-allowed = Cardwave no hace eso aquí. Recarga la página e inténtalo de nuevo.
error-too-large = Es demasiado grande. Prueba con un archivo más pequeño.
error-unsupported-type = Cardwave no acepta ese tipo de archivo aquí.

## Passwords and accounts

error-locked = Cardwave está bloqueado hasta que se introduzca su contraseña.
error-sign-in = Inicia sesión primero.
error-password-wrong = Contraseña incorrecta.
error-password-needed = Hace falta la contraseña.
error-current-password-needed = Hace falta la contraseña actual.
error-backup-password-needed = Esta copia de seguridad necesita su contraseña.
error-too-many-tries = Demasiadas contraseñas incorrectas. Inténtalo de nuevo en { $seconds } segundos.
error-owner-only = Solo la cuenta de este equipo puede { $action ->
    [use_its_files] usar sus archivos
    [use_its_folders] usar sus carpetas
    [choose_its_models] elegir sus modelos
    [lock_Cardwave] bloquear Cardwave
   *[other] hacer eso
}.
error-no-password-to-lock = Cardwave solo se bloquea si hay una contraseña activada.
error-remote-sign-in-off = Esta cuenta no puede iniciar sesión desde otro dispositivo. Actívalo en Cuenta › Compartir.
error-no-password-on = No hay ninguna contraseña activada.
error-no-password-set = Esta cuenta no tiene contraseña.
error-password-kept = Una cuenta de este equipo tiene contraseña: inicia sesión con ella.
error-account-busy = Cardwave aún está escribiendo una respuesta o leyendo personajes; inténtalo de nuevo cuando termine.
error-restore-busy = Cardwave aún está escribiendo una respuesta o leyendo personajes; inténtalo de nuevo cuando termine.
error-backup-needs-password = Una copia de seguridad necesita contraseña.

## What is asked of

error-not-found = No existe { $what ->
    [account] esa cuenta
    [asset] ese archivo en la tarjeta
    [attachment] ese adjunto
    [card] esa tarjeta
    [card_version] esa versión de la tarjeta
    [chat] ese chat
    [chat_character] ese personaje en el chat
    [checkpoint] ese punto de control
    [deleted_message] ese mensaje borrado
    [document] ese documento
    [expression] esa expresión
    [expression_pack] conjunto de expresiones
    [figure] esa figura
    [kind_of_model] ese tipo de modelo
    [language] ese idioma
    [lorebook] ese lorebook
    [lorebook_entry] esa entrada del lorebook
    [memory] ese recuerdo
    [message] ese mensaje
    [model] ese modelo
    [persona] esa persona
    [picture] esa imagen
    [preset] ese preset
    [prompt_preset] ese preset de prompt
    [provider] ese proveedor
    [question] esa pregunta
    [task] esa tarea
    [tool] esa herramienta
    [user] esa cuenta
    [voice] esa voz
   *[other] cosa
}. Puede que se haya eliminado.
error-chat-busy = Se está escribiendo una respuesta en este chat; detenla primero.
error-no-provider = Aún no hay ningún proveedor configurado. Añade uno en Ajustes › Proveedores.
error-provider-refused = { $refusal ->
    [key] El proveedor no aceptó la clave: revísala en Ajustes › Proveedores.
    [busy] El proveedor no tiene saldo o está ocupado: inténtalo más tarde.
    [down] El proveedor no responde: inténtalo más tarde.
   *[other] El proveedor rechazó esto: { $reason }
}
error-model-declined = { $model } se negó a escribir esto. Cambia el mensaje o elige otro modelo.
error-model-sees-no-pictures = { $model } no puede ver imágenes, así que no acepta ninguna. Elige un modelo que vea imágenes para enviarlas.
error-card-trashed = El personaje está en la Papelera; restáuralo primero.
error-lorebook-trashed = El lorebook “{ $name }” está en la Papelera; restáuralo para usarlo.
error-own-lorebook-flags = El lorebook propio de un personaje va con el personaje: no se puede marcar con estrella, archivar, mover a la Papelera ni usar en todos los chats por sí solo.

## Folders and files

error-no-such-folder = No existe la carpeta { $folder } en este equipo.
error-folder-not-chosen = Elige una carpeta primero.
error-drive-root-to-watch = La raíz de una unidad contiene demasiado para vigilarla; elige una carpeta dentro.
error-drive-root-for-model = La raíz de una unidad contiene demasiado para dárselo a la IA; elige una carpeta dentro de ella.
error-data-folder = Esa carpeta contiene los datos propios de Cardwave, o está dentro de ellos; elige otra.
error-commands-windows-only = Los comandos solo se ejecutan en Windows.
error-recycle-bin-windows-only = Los archivos solo se mueven a la Papelera de reciclaje en Windows.
error-files-tool-off = Activa primero Archivos en Ajustes › Herramientas: con ella el equipo de programación lee y escribe la carpeta de la tarea.

## Pictures, replies and voices

error-picture-words-missing = Di primero qué muestra la imagen.
error-picture-words-too-long = Lo que muestra la imagen supera los { $most } caracteres.
error-picture-needs-words = Di qué muestra la imagen.
error-goal-missing = Di qué debe hacer el equipo.
error-dictation-not-set-up = El dictado no está configurado: Ajustes › Modelos › Dictado.
error-direction-without-go-on = Una pista solo sirve con Continuar.
error-again-or-go-on = Una respuesta se vuelve a escribir o se continúa, no ambas cosas.
error-again-not-reply = Solo la respuesta de un personaje se puede volver a escribir.
error-no-reply-to-write-again = El chat no tiene ninguna respuesta que volver a escribir.
error-no-text = La IA no envió texto. Inténtalo de nuevo.
error-worker-no-answer = El modelo auxiliar no dio respuesta.
error-unknown-voice = No existe la voz “{ $voice }”.
error-nothing-to-read = No hay nada que leer.
error-voice-not-downloaded = La voz no está descargada.
error-voice-failed = La lectura en voz alta falló. Inténtalo de nuevo.
error-stopping = Cardwave se está cerrando.
error-download-failed = La descarga falló. Comprueba la conexión e inténtalo de nuevo.
error-search-model-failed = El modelo de búsqueda falló. Cardwave lo volverá a intentar dentro de un rato.
error-models-not-listed = No se pudo obtener la lista de modelos del proveedor. Revisa la dirección y la clave, y vuelve a intentarlo.
error-file-not-imported = No se pudo leer el archivo: Cardwave no conoce su formato.
error-describing-failed = El modelo auxiliar no pudo describir el personaje.

## The kinds an area's failures are grouped by: each picks its words by `what` (or `whose`), the thing it is about

error-needed = { $what ->
    [persona_name] Una persona necesita un nombre.
    [account_name] La cuenta necesita un nombre.
    [card_title] El personaje necesita un título.
    [character_name] El personaje necesita un nombre.
    [chat_character] Un chat necesita un personaje.
    [chat_title] El título de un chat necesita palabras.
    [entry_name] Una entrada necesita un nombre.
    [expression_files] Elige un archivo zip (una carpeta comprimida) o las imágenes de un conjunto.
    [language] Falta el idioma.
    [lorebook_name] Un lorebook necesita un nombre.
    [memory_text] Un recuerdo necesita un texto.
    [message_to_improve] No hay ningún mensaje que mejorar.
    [model_name] Hay que dar el nombre del modelo.
    [models_folder] Elige primero una carpeta de modelos.
    [password] La contraseña no puede estar vacía.
    [preset_name] El preset necesita un nombre.
    [rewrite_given] Falta algo necesario. Inténtalo de nuevo.
    [summary] Un resumen necesita palabras.
    [text_to_change] No hay ningún texto que cambiar.
    [text_to_read] No hay nada que leer.
    [voice_name] La voz necesita un nombre.
   *[other] Falta algo necesario. Inténtalo de nuevo.
}
error-too-long = { $what ->
    [account_name] El nombre de una cuenta tiene como máximo { $name_limit } caracteres.
    [chat_title] El título de un chat tiene como máximo { $title_limit } caracteres.
    [document] { $name } es demasiado largo: un documento tiene como máximo 2.000.000 caracteres.
    [entry_name] El nombre de una entrada tiene como máximo { $max_name } caracteres.
    [field_name] El nombre de un campo tiene de 1 a { $max_field } signos.
    [lorebook_name] El nombre de un lorebook tiene como máximo { $max_name } caracteres.
    [memory_text] Un recuerdo tiene como máximo { $text_limit } caracteres.
    [persona_name] El nombre de una persona tiene como máximo { $max_name } letras.
    [provider_name] El nombre tiene como máximo { $name_limit } caracteres.
    [unsaved_text] Un texto sin guardar conserva como máximo { $max_text } signos.
    [voice_name] El nombre de una voz tiene como máximo { $name_most } caracteres.
   *[other] Supera los { $most } caracteres.
}
error-out-of-range = { $what ->
    [authors_note_depth] La nota se coloca uno o más mensajes atrás.
    [companion_size] El tamaño de tu acompañante va del { $start } al { $end } por ciento de la altura de la pantalla.
    [context_size] El tamaño del contexto debe ser de al menos 512 tokens.
    [entry_chance] La probabilidad de una entrada es como máximo del 100 por ciento.
    [provider_setting] { $name } debe estar entre { $min } y { $max }.
    [reply_length] La longitud de la respuesta debe estar entre 1 y { $most_reply_length } tokens.
    [slider] Un control deslizante va de 0 a 100.
    [talk_pause] La pausa debe estar entre 0 y { $most_talk_pause } segundos.
    [talk_replies] Las respuestas seguidas deben ser de 1 a { $most_talk_replies }.
    [talkativeness] La locuacidad va de 0 a 100.
    [voice_speed] La velocidad va del { $start } % al { $end } %.
   *[other] Debe estar entre { $least } y { $most }.
}
error-taken = { $what ->
    [card_in_library] Ya está en tu biblioteca.
    [account_name] Otra cuenta se llama “{ $name }”.
    [card_language] La tarjeta ya está en { $name }.
    [chat_character] { $name } ya está en este chat.
    [chat_character_twice] { $name } está dos veces en este chat.
    [lorebook_same_name] La tarjeta ya tiene un lorebook o una entrada con el mismo nombre.
    [model_file] { $name } ya está en la carpeta.
    [preset_name] Otro preset se llama “{ $name }”.
    [tool_name] Ya existe una herramienta llamada { $name }; elige otro nombre.
   *[other] Eso ya existe.
}
error-in-trash = { $what ->
    [card] El personaje está en la Papelera; restáuralo primero.
    [card_to_chat] El personaje está en la Papelera; restaura el personaje para volver a chatear.
    [chat] El chat está en la Papelera; restáuralo primero.
    [chat_card] Su personaje “{ $title }” está en la Papelera; restaura primero el personaje.
    [lorebook] El lorebook “{ $name }” está en la Papelera; restáuralo primero.
    [lorebook_to_use] El lorebook “{ $name }” está en la Papelera; restáuralo para usarlo.
    [persona_default] Una persona en la Papelera no puede ser la predeterminada; restáurala primero.
    [persona_to_use] La persona “{ $name }” está en la Papelera; restáurala para usarla.
   *[other] Eso está en la Papelera; restáuralo primero.
}
error-not-readable = { $what ->
    [damaged_key] Su clave está dañada.
    [json] El archivo no es un JSON válido.
    [lorebook] El archivo no contiene ningún lorebook.
    [lorebook_not_card] El archivo es una tarjeta de personaje, no un lorebook.
    [account_picture] La imagen no es un PNG o JPEG legible de como máximo 4.096 píxeles por lado.
    [attachment_picture] Una imagen es un archivo PNG, JPEG o WebP.
    [backup] Este archivo no es una copia de seguridad de Cardwave.
    [backup_damaged] Esta copia de seguridad está dañada.
    [backup_key] Esta copia de seguridad está dañada: su clave no se puede leer.
    [base64] Eso no es base64.
    [base64_file] { $name } no es base64.
    [card_defined_twice] Este archivo no es una tarjeta de personaje que Cardwave pueda leer. Vuelve a exportarlo desde la app de la que viene.
    [card_file_name] Un nombre de archivo de la tarjeta no se puede usar.
    [card_reference] Eso no nombra ninguna parte de la tarjeta.
    [ccv4_version] Esta tarjeta se hizo con un Cardwave más nuevo. Actualiza Cardwave para abrirla.
    [comfyui_address] No se puede leer la dirección de ComfyUI.
    [comfyui_answer] No se puede leer la respuesta de ComfyUI.
    [dictation_recording] No se pudo leer la grabación. Graba de nuevo.
    [document_text] { $name } no tiene texto que se pueda leer.
    [document_type] Un documento es un archivo .txt, .md, .pdf o .docx.
    [downloaded_model] El archivo descargado no es el modelo.
    [expression_pack] Ninguna de sus imágenes lleva el nombre de un estado de ánimo en inglés, como joy.png o anger.png (PNG, JPEG, WebP o GIF).
    [figure_file] { $file_name } no es un archivo de ese tipo.
    [figure_still] La imagen fija de la figura no es un PNG de como máximo 4 MB.
    [figure_type] Una figura 3D es un archivo VRM, GLB o FBX.
    [folder_read] No se puede leer la carpeta.
    [format_version] Este archivo no es una tarjeta de personaje que Cardwave pueda leer. Vuelve a exportarlo desde la app de la que viene.
    [image_model_answer] No se puede leer la respuesta del modelo de imágenes.
    [image_model_picture] No se puede leer la imagen del modelo de imágenes.
    [key_characters] La clave tiene caracteres que una clave no puede tener. Cópiala de nuevo desde el sitio del proveedor.
    [lorebook_empty] El lorebook está vacío.
    [lorebook_entries] El lorebook no tiene entradas.
    [lorebook_file] No se puede leer el lorebook.
    [lorebook_named] No se puede leer el lorebook “{ $name }”.
    [lorebook_named_empty] El lorebook “{ $name }” está vacío.
    [models_dev_list] No se puede leer la lista de modelos.
    [models_list_answer] La dirección responde, pero no con una lista de modelos.
    [models_list_missing] No llegó la lista de modelos.
    [name_characters] El nombre contiene caracteres que un nombre no puede tener.
    [no_lorebook] Esto no es un lorebook.
    [pdf] No se puede leer el PDF.
    [picture] La imagen no es PNG, JPEG ni WebP.
    [picture_server_answer] No se puede leer la respuesta del servidor de imágenes.
    [picture_unreadable] No se puede leer la imagen.
    [png] No es un archivo PNG.
    [png_damaged] El PNG está dañado.
    [provider_address] La dirección debe ser una dirección web simple, como https://api.openai.com/v1.
    [provider_website] Indica el sitio web del proveedor como un nombre, por ejemplo example.com.
    [recording_format] No se puede leer el formato de la grabación.
    [recording_pcm] No se pudo leer la grabación. Graba de nuevo.
    [recording_rate] No se puede leer la frecuencia de la grabación.
    [recording_short] La grabación es demasiado corta: hacen falta al menos { $shortest } segundos.
    [recording_silent] La grabación no tiene sonido.
    [recording_wav] La grabación no es un archivo WAV.
    [sillytavern_base64] Este archivo no es una tarjeta de personaje que Cardwave pueda leer. Vuelve a exportarlo desde la app de la que viene.
    [sillytavern_empty] La tarjeta está vacía.
    [sillytavern_file] No se puede leer la tarjeta de SillyTavern de este archivo.
    [sillytavern_json] Este archivo no es una tarjeta de personaje que Cardwave pueda leer. Vuelve a exportarlo desde la app de la que viene.
    [sillytavern_object] Este archivo no es una tarjeta de personaje que Cardwave pueda leer. Vuelve a exportarlo desde la app de la que viene.
    [sillytavern_png] No se puede leer la tarjeta de SillyTavern de este PNG.
    [spec_version] Este archivo no es una tarjeta de personaje que Cardwave pueda leer. Vuelve a exportarlo desde la app de la que viene.
    [spec_version_form] Este archivo no es una tarjeta de personaje que Cardwave pueda leer. Vuelve a exportarlo desde la app de la que viene.
    [toml] Este archivo no es una tarjeta de personaje que Cardwave pueda leer. Vuelve a exportarlo desde la app de la que viene.
    [word_file] No se puede leer el archivo de Word.
    [word_text] El archivo de Word no tiene texto.
    [workflow] No se puede leer el flujo de trabajo “{ $name }”.
    [workflow_api_form] El flujo de trabajo está guardado en el formato para la API: guárdalo en ComfyUI como flujo de trabajo.
    [workflow_broken] No se puede leer el flujo de trabajo.
    [workflow_fields] El nodo “{ $kind }” del flujo de trabajo tiene campos que Cardwave no puede leer.
    [workflow_no_node] El flujo de trabajo no tiene ningún nodo que este ComfyUI pueda ejecutar.
    [workflow_node] El nodo “{ $class }” del flujo de trabajo no está en este ComfyUI.
    [zip] { $name } no se puede leer como zip.
   *[other] No se puede leer.
}
error-too-big = { $what ->
    [card_for_worker] El personaje es demasiado largo para el modelo auxiliar; elige un modelo auxiliar que lea más.
    [card_file] El archivo supera los { $most } MB.
    [checkpoint_folder] La carpeta es demasiado grande para guardar copias antes de cada paso.
    [expression_pack_size] Las imágenes de { $name } son demasiado grandes.
    [expression_zip_files] { $name } contiene más de { $max_entries } archivos.
    [figure] La figura 3D es demasiado grande.
    [model_for_computer] { $name } es demasiado grande para este equipo.
    [models_dev_list] La lista de modelos es demasiado larga.
    [picture_pixels] La imagen es demasiado grande ({ $wide } por { $high } píxeles).
    [reply] La respuesta se cortó: se hizo demasiado larga.
   *[other] Es demasiado grande.
}
error-not-now = { $what ->
    [character_has_written] { $name } ha escrito en este chat y se queda en él.
    [coding_folder_busy] Otra tarea de programación se está ejecutando en esa carpeta; espera a que termine o detenla.
    [database_busy] Cardwave estaba ocupado; inténtalo de nuevo.
    [download_cancelling] Se está cancelando su descarga; inténtalo de nuevo en un momento.
    [held_by_card] Un personaje lo usa; quítalo primero del personaje.
    [lorebook_used_elsewhere] El lorebook ya se usa en otro sitio, así que se queda en la biblioteca.
    [model_downloading] El modelo se está descargando.
    [model_replying] El modelo está respondiendo; elimínalo cuando termine la respuesta.
    [search_model_not_downloaded] El modelo de búsqueda no está descargado.
    [task_running] La tarea aún se está ejecutando; detenla primero.
   *[other] No se puede hacer ahora. Inténtalo de nuevo en un momento.
}
error-changed = { $what ->
    [lorebook_entry] El lorebook ya tiene otra entrada.
    [card_version] La tarjeta se cambió mientras tanto; se vuelve a leer.
    [tool_name] Otra herramienta se llama ahora { $name }.
    [two_ways] { $reference } se cambió dos veces a la vez; inténtalo de nuevo.
    [workflow] El flujo de trabajo “{ $name }” se cambió en ComfyUI: vuelve a elegirlo en Ajustes › Proveedores.
   *[other] Eso se cambió mientras tanto; inténtalo de nuevo.
}
error-not-possible = { $what ->
    [back_to_computer] Solo la búsqueda y la voz pueden volver a este equipo.
    [card_about_itself] Lo que la tarjeta dice de sí misma no se puede cambiar.
    [card_change] Eso no se puede cambiar en esta tarjeta.
    [card_character] La tarjeta no tiene ese personaje.
    [card_character_change] El personaje de la tarjeta no se puede cambiar.
    [card_language_beside] La tarjeta no puede contener { $name } junto a su primer idioma.
    [card_lorebook] La tarjeta no trae ese lorebook.
    [card_lorebook_attached] La tarjeta no tiene ese lorebook adjunto.
    [card_mode] La tarjeta no tiene ese modo.
    [card_no_character] La tarjeta no tiene ningún personaje.
    [card_not_changed] La tarjeta no se cambió.
    [card_part] Eso no es una parte de la tarjeta que se pueda cambiar.
    [card_takes_no] Esta tarjeta no acepta nada nuevo de ese tipo.
    [card_takes_no_lorebook] La tarjeta no acepta ningún lorebook.
    [character_change] Ese personaje no se puede cambiar en esta tarjeta.
    [chat_character] El chat no tiene ese personaje.
    [chat_lore] El chat no tiene ese lorebook ni esa entrada de lorebook.
    [chat_lorebook] El chat no tiene ese lorebook.
    [chat_mode] El chat no tiene ese modo.
    [chat_no_character] El chat no tiene ningún personaje.
    [chat_without_character] Un chat sin personaje no tiene personajes.
    [chat_without_character_add] Un chat sin personaje no acepta ninguno.
    [checkpoint_put_back] No se puede devolver { $path } a su estado.
    [comfyui_no_picture] ComfyUI no hizo ninguna imagen.
    [companion_not_answering] Tu acompañante no respondió.
    [companion_not_shown] Tu acompañante no se está mostrando.
    [comfyui_queue] ComfyUI no puso la imagen en cola.
    [comfyui_said] ComfyUI dijo: { $said }
    [continue_no_text] La respuesta no tiene texto que continuar.
    [continue_only_reply] Solo se puede continuar la respuesta de un personaje.
    [depth_note] No se puede añadir una nota a una profundidad.
    [dictation_failed] El modelo de dictado falló.
    [dictation_model_load] No se puede cargar el modelo de dictado.
    [dictation_model_start] No se puede iniciar el modelo de dictado.
    [draft_made_by] Un borrador no lo hace “{ $made }”.
    [edit_breaks_card] La tarjeta no se podría leer tras este cambio.
    [entry_change] La entrada no se puede cambiar así en este lorebook.
    [entry_taken_out] Esto no es una entrada de lorebook que se haya sacado.
    [export_no_character] La tarjeta no tiene ningún personaje que exportar.
    [greeting] Ese no es uno de los saludos de este personaje.
    [improve_direction] Mejorar usa las palabras del campo; no admite pista.
    [key_refused] La clave fue rechazada.
    [llama_server_start] No se puede iniciar el modelo de búsqueda. Reinicia Cardwave e inténtalo de nuevo.
    [local_address] Los modelos de este equipo se encuentran por su carpeta, en Ajustes › Proveedores.
    [lorebook_change] Este lorebook no se puede cambiar.
    [lorebook_change_breaks] El lorebook no se podría leer tras este cambio.
    [lorebook_new_entry] Este lorebook no acepta entradas nuevas.
    [lorebook_put_in] El lorebook no se puede poner en esta tarjeta.
    [lorebook_take_out] El lorebook no se puede sacar de esta tarjeta.
    [message_not_in_chat] El mensaje no forma parte de este chat.
    [message_not_in_view] El mensaje no está a la vista.
    [model_remove] No se puede quitar { $path }.
    [no_folder] No existe esa carpeta en este equipo.
    [no_image_model] Aún no hay ningún modelo de imágenes configurado: configura uno en Ajustes › Modelos › Imágenes.
    [no_local_model] No hay ningún modelo “{ $id }” en esa carpeta.
    [no_local_models] Los modelos locales no están configurados.
    [no_recycle_bin] No hay Papelera de reciclaje para { $path }.
    [no_summary] La tarjeta aún no tiene resumen.
    [no_voice] No existe esa voz.
    [no_vulkan] La tarjeta gráfica de este equipo no puede ejecutar modelos. Usa un proveedor en su lugar.
    [no_vulkan_dictation] La tarjeta gráfica de este equipo no puede ejecutar el dictado.
    [prompt_change] El prompt de ese personaje no se puede cambiar en esta tarjeta.
    [recycle_bin_move] { $path } no se movió a la Papelera de reciclaje.
    [speaker_not_in_chat] Quien habla no forma parte de este chat.
    [speaker_only_character] Solo el mensaje de un personaje tiene a alguien que habla.
    [unknown_language] Ese no es un idioma que esta app conozca.
    [version_lacks_character] Un chat es con un personaje que falta en la versión más reciente.
    [voice_runtime] Para leer en voz alta falta una pieza de Microsoft: instala el Visual C++ Redistributable desde microsoft.com y reinicia Cardwave.
    [workflow_no_text] El flujo de trabajo “{ $name }” no tiene ningún campo de texto para las palabras de la imagen.
    [workflow_use] No se puede usar el flujo de trabajo “{ $name }”.
    [written_tools_full] Puedes guardar { $most_tools } herramientas como máximo; borra primero una en Ajustes › Herramientas que escribió la IA.
    [delete_not_in_trash] Solo se puede borrar para siempre lo que está en la Papelera; muévelo allí primero.
   *[other] No se puede hacer.
}
error-model-answer = { $what ->
    [no_greeting] La IA no escribió ningún saludo.
    [background_answer] No se pudo usar la respuesta del modelo auxiliar. Inténtalo de nuevo o elige otro modelo auxiliar.
    [background_text] No se pudo usar la respuesta del modelo auxiliar. Inténtalo de nuevo o elige otro modelo auxiliar.
    [card_texts] La respuesta de la IA no eran los textos del personaje.
    [classification] No se pudo usar la respuesta del modelo auxiliar. Inténtalo de nuevo o elige otro modelo auxiliar.
    [example_messages] La IA no escribió mensajes de ejemplo.
    [no_example_message] La IA escribió un mensaje de ejemplo sin su texto.
    [json] La respuesta de la IA no tenía la forma pedida.
    [keywords] No se pudo usar la respuesta del modelo auxiliar. Inténtalo de nuevo o elige otro modelo auxiliar.
    [logline] No se pudo usar la respuesta del modelo auxiliar. Inténtalo de nuevo o elige otro modelo auxiliar.
    [no_chat_reply] El proveedor de la IA no envió ninguna respuesta de chat.
    [no_fitting_answer] La IA no dio ninguna respuesta útil en tres intentos.
    [no_picture] El modelo de imágenes respondió sin imagen.
    [no_plan] El planificador no hizo ningún plan.
    [no_text] La IA no envió texto.
    [picture_address] La imagen del modelo de imágenes está en una dirección que no se descarga.
    [picture_art] No se pudo hacer la imagen; inténtalo de nuevo.
    [picture_field] El modelo auxiliar no encontró ningún campo para las palabras de la imagen.
    [picture_server_no_picture] El servidor de imágenes respondió sin imagen.
    [picture_words] El modelo auxiliar no escribió palabras para la imagen.
    [rating] No se pudo usar la respuesta del modelo auxiliar. Inténtalo de nuevo o elige otro modelo auxiliar.
    [reply_broke_off] La respuesta se interrumpió.
    [needs] No se pudo usar la respuesta del modelo auxiliar. Inténtalo de nuevo o elige otro modelo auxiliar.
    [rounds] El equipo de programación no terminó su trabajo en { $rounds } rondas.
    [search_left_out] El modelo de búsqueda omitió un texto.
    [search_model] No se puede leer la respuesta del modelo de búsqueda.
    [search_tokens] No se pueden leer los tokens del modelo de búsqueda.
    [title] No se pudo usar la respuesta del modelo auxiliar. Inténtalo de nuevo o elige otro modelo auxiliar.
    [too_many_tools] La IA llamó a demasiadas herramientas.
    [worker_mode] No se pudo usar la respuesta del modelo auxiliar. Inténtalo de nuevo o elige otro modelo auxiliar.
    [worker_texts] No se pudo usar la respuesta del modelo auxiliar. Inténtalo de nuevo o elige otro modelo auxiliar.
    [server_reported] El proveedor de la IA informó: { $reason }
   *[other] La respuesta de la IA no se puede usar.
}
error-timed-out = { $whose ->
    [comfyui] ComfyUI no hizo la imagen a tiempo.
    [llama_server] El modelo de búsqueda no estuvo listo a tiempo. Inténtalo de nuevo.
    [model] La IA no respondió a tiempo. Inténtalo de nuevo.
    [model_server] El proveedor de la IA no respondió a tiempo. Inténtalo de nuevo.
    [search_model] El modelo de búsqueda no respondió a tiempo.
   *[other] No respondió a tiempo.
}
error-unreachable = { $whose ->
    [comfyui] No se puede conectar con ComfyUI.
    [image_model] No se puede conectar con el modelo de imágenes.
    [model_download] No se puede descargar el archivo del modelo.
    [model_server] El proveedor de la IA no responde: inténtalo más tarde o revisa la conexión.
    [picture_address] No se puede descargar la imagen.
    [picture_server] No se puede conectar con el servidor de imágenes.
    [provider_voices] No se puede conectar con las voces del proveedor.
    [search_model] El modelo de búsqueda no responde.
    [provider_voice] No se puede conectar con la voz del proveedor.
    [provider_search_model] No se puede conectar con el modelo de búsqueda del proveedor.
   *[other] No se puede conectar.
}
error-answered = { $whose ->
    [comfyui] ComfyUI respondió { $status }.
    [model_server] El proveedor de la IA respondió { $status }. Inténtalo más tarde.
    [picture_server] El servidor de imágenes respondió { $status }.
    [provider_voices] Las voces del proveedor respondieron { $status }.
    [search_model] El modelo de búsqueda respondió { $status }.
   *[other] Respondió { $status }.
}
