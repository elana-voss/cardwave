### The UI's words in English: the server's error answers, one for each code of api/generated/Code.ts (errors.ts),
### `error-<code>` with "-" for "_"; the build fails on a code without its words (en.ftl's head says how).

## The request, as the server took it

error-request-failed = That could not be done. Try again.
error-internal = Something went wrong in Cardwave. Try again.
error-bad-request = Cardwave could not read that request. Reload the page and try again.
error-forbidden = That is not allowed.
error-no-such-path = Cardwave has no such page. Reload the page and try again.
error-method-not-allowed = Cardwave does not do that here. Reload the page and try again.
error-too-large = That is too large. Try a smaller file.
error-unsupported-type = Cardwave does not take that kind of file here.

## Passwords and accounts

error-locked = Cardwave is locked until its password is given.
error-sign-in = Sign in first.
error-password-wrong = Wrong password.
error-password-needed = The password is needed.
error-current-password-needed = The current password is needed.
error-backup-password-needed = This backup needs its password.
error-too-many-tries = Too many wrong passwords. Try again in { $seconds } seconds.
error-owner-only = Only this computer's account can { $action ->
    [use_its_files] use its files
    [use_its_folders] use its folders
    [choose_its_models] choose its models
    [lock_Cardwave] lock Cardwave
   *[other] do that
}.
error-no-password-to-lock = Cardwave locks only while a password is on.
error-remote-sign-in-off = This account cannot sign in from another device. Turn that on in Account › Sharing.
error-no-password-on = No password is on.
error-no-password-set = No password is set for this account.
error-password-kept = An account on this computer keeps a password: it signs in with it.
error-account-busy = Cardwave is still writing a reply or reading characters; try again when it is done.
error-restore-busy = Cardwave is still writing a reply or reading characters; try again when it is done.
error-backup-needs-password = A backup needs a password.

## What is asked of

error-not-found = There is no such { $what ->
    [account] account
    [asset] file in the card
    [attachment] attachment
    [card] card
    [card_version] card version
    [chat] chat
    [chat_character] character in the chat
    [checkpoint] checkpoint
    [deleted_message] deleted message
    [document] document
    [expression] expression
    [expression_pack] set of expressions
    [figure] figure
    [kind_of_model] kind of model
    [language] language
    [lorebook] lorebook
    [lorebook_entry] lorebook entry
    [memory] memory
    [message] message
    [model] model
    [persona] persona
    [picture] picture
    [preset] preset
    [prompt_preset] prompt preset
    [provider] provider
    [question] question
    [task] task
    [tool] tool
    [user] account
    [voice] voice
   *[other] thing
}. It may have been deleted.
error-chat-busy = A reply is being written in this chat; stop it first.
error-no-provider = No provider is set up yet. Add one in Settings › Providers.
error-provider-refused = { $refusal ->
    [key] The provider did not take the key: check it in Settings › Providers.
    [busy] The provider has no credit left or is busy: try again later.
    [down] The provider is not answering: try again later.
   *[other] The provider refused this: { $reason }
}
error-model-declined = { $model } declined to write this. Change the message, or pick another model.
error-model-sees-no-pictures = { $model } cannot see pictures, so it takes none. Pick a model that sees pictures to send them.
error-card-trashed = The character is in the Trash; restore it first.
error-lorebook-trashed = The lorebook “{ $name }” is in the Trash; restore it to use it.
error-own-lorebook-flags = A character's own lorebook goes with the character: it cannot be starred, archived, moved to the Trash or used in every chat on its own.

## Folders and files

error-no-such-folder = There is no folder { $folder } on this computer.
error-folder-not-chosen = Choose a folder first.
error-drive-root-to-watch = A drive's root holds too much to watch; choose a folder in it.
error-drive-root-for-model = A drive's root holds too much to give the AI; choose a folder in it.
error-data-folder = That folder holds Cardwave's own data, or is in it; choose another.
error-commands-windows-only = Commands are run only on Windows.
error-recycle-bin-windows-only = Files are moved to the Recycle Bin only on Windows.
error-files-tool-off = Switch on Files in Settings › Tools first: the team reads and writes the task's folder with it.

## Pictures, replies and voices

error-picture-words-missing = Say what the picture shows first.
error-picture-words-too-long = What the picture shows is longer than { $most } letters.
error-picture-needs-words = Say what the picture shows.
error-goal-missing = Say what the team is to do.
error-dictation-not-set-up = Dictation is not set up: Settings › Models › Dictation.
error-direction-without-go-on = A hint works only with Continue.
error-again-or-go-on = A reply is either written again or continued, not both.
error-again-not-reply = Only a character's reply can be written again.
error-no-reply-to-write-again = The chat has no reply to write again.
error-no-text = The AI sent no text. Try again.
error-worker-no-answer = The helper model gave no answer.
error-unknown-voice = There is no voice “{ $voice }”.
error-nothing-to-read = There is nothing to read.
error-voice-not-downloaded = The voice is not downloaded.
error-voice-failed = Reading aloud failed. Try again.
error-stopping = Cardwave is stopping.
error-download-failed = The download failed. Check the connection and try again.
error-search-model-failed = The search model failed. Cardwave tries it again in a while.
error-models-not-listed = The provider's models could not be listed. Check the address and the key, then try again.
error-file-not-imported = The file could not be read: Cardwave does not know its format.
error-describing-failed = The helper model could not describe the character.

## The kinds an area's failures are grouped by: each picks its words by `what` (or `whose`), the thing it is about

error-needed = { $what ->
    [persona_name] A persona needs a name.
    [account_name] The account needs a name.
    [card_title] The character needs a title.
    [character_name] The character needs a name.
    [chat_character] A chat needs a character.
    [chat_title] A chat's title needs words.
    [entry_name] An entry needs a name.
    [expression_files] Choose a zip file (a packed folder) or the pictures of a set.
    [language] The language is missing.
    [lorebook_name] A lorebook needs a name.
    [memory_text] A memory needs a text.
    [message_to_improve] There is no message to improve.
    [model_name] The model must be named.
    [models_folder] Choose a folder of models first.
    [password] A password cannot be empty.
    [preset_name] The preset needs a name.
    [rewrite_given] Something needed is missing. Try again.
    [summary] A summary needs words.
    [text_to_change] There is no text to change.
    [text_to_read] There is nothing to read.
    [voice_name] The voice needs a name.
   *[other] Something needed is missing. Try again.
}
error-too-long = { $what ->
    [account_name] An account's name has at most { $name_limit } letters.
    [chat_title] A chat's title has at most { $title_limit } letters.
    [document] { $name } is too long: a document has 2,000,000 letters at most.
    [entry_name] An entry's name has at most { $max_name } letters.
    [field_name] A field's name has 1 to { $max_field } letters.
    [lorebook_name] A lorebook's name has at most { $max_name } letters.
    [memory_text] A memory has { $text_limit } letters at most.
    [persona_name] A persona's name has at most { $max_name } letters.
    [provider_name] The name has at most { $name_limit } letters.
    [unsaved_text] An unsaved text keeps at most { $max_text } letters.
    [voice_name] A voice's name is at most { $name_most } letters.
   *[other] That is longer than { $most } letters.
}
error-out-of-range = { $what ->
    [authors_note_depth] The note is put one message back or more.
    [companion_size] The companion's size is from { $start } to { $end } percent of the screen's height.
    [context_size] The context size must be at least 512 tokens.
    [entry_chance] An entry's chance is at most 100 percent.
    [provider_setting] { $name } must be from { $min } to { $max }.
    [reply_length] The reply length must be from 1 to { $most_reply_length } tokens.
    [slider] A slider goes from 0 to 100.
    [talk_pause] The pause must be from 0 to { $most_talk_pause } seconds.
    [talk_replies] The replies in a row must be from 1 to { $most_talk_replies }.
    [talkativeness] Talkativeness is from 0 to 100.
    [voice_speed] The speed is from { $start }% to { $end }%.
   *[other] That is to be from { $least } to { $most }.
}
error-taken = { $what ->
    [card_in_library] Already in your library.
    [account_name] Another account is called “{ $name }”.
    [card_language] The card is in { $name } already.
    [chat_character] { $name } is in this chat already.
    [chat_character_twice] { $name } is in this chat twice.
    [lorebook_same_name] The card has a lorebook or an entry of the same name by now.
    [model_file] { $name } is in the folder already.
    [preset_name] Another preset is called “{ $name }”.
    [tool_name] A tool named { $name } exists already; choose another name.
   *[other] That is there already.
}
error-in-trash = { $what ->
    [card] The character is in the Trash; restore it first.
    [card_to_chat] The character is in the Trash; restore the character to chat again.
    [chat] The chat is in the Trash; restore it first.
    [chat_card] Its character “{ $title }” is in the Trash; restore the character first.
    [lorebook] The lorebook “{ $name }” is in the Trash; restore it first.
    [lorebook_to_use] The lorebook “{ $name }” is in the Trash; restore it to use it.
    [persona_default] A persona in the Trash cannot be the default; restore it first.
    [persona_to_use] The persona “{ $name }” is in the Trash; restore it to use it.
   *[other] That is in the Trash; restore it first.
}
error-not-readable = { $what ->
    [damaged_key] Its key is damaged.
    [json] The file is not valid JSON.
    [lorebook] The file holds no lorebook.
    [lorebook_not_card] The file is a character card, not a lorebook.
    [account_picture] The picture is not a PNG or JPEG of at most 4,096 pixels a side that can be read.
    [attachment_picture] A picture is a PNG, JPEG or WebP file.
    [backup] This file is not a Cardwave backup.
    [backup_damaged] This backup is damaged.
    [backup_key] This backup is damaged: its key cannot be read.
    [base64] That is not base64.
    [base64_file] { $name } is not base64.
    [card_defined_twice] This file is not a character card Cardwave can read. Export it again from the app it came from.
    [card_file_name] A file name in the card cannot be used.
    [card_reference] That names no part of the card.
    [ccv4_version] This card was made by a newer Cardwave. Update Cardwave to open it.
    [comfyui_address] ComfyUI's address cannot be read.
    [comfyui_answer] ComfyUI's answer cannot be read.
    [dictation_recording] The recording could not be read. Record again.
    [document_text] { $name } has no text that can be read.
    [document_type] A document is a .txt, .md, .pdf or .docx file.
    [downloaded_model] The file downloaded is not the model.
    [expression_pack] None of its pictures is named by a mood in English, as joy.png or anger.png are (PNG, JPEG, WebP or GIF).
    [figure_file] { $file_name } is not a file of that kind.
    [figure_still] The figure's still is not a PNG of at most 4 MB.
    [figure_type] A 3D figure is a VRM, GLB or FBX file.
    [folder_read] The folder cannot be read.
    [format_version] This file is not a character card Cardwave can read. Export it again from the app it came from.
    [image_model_answer] The image model's answer cannot be read.
    [image_model_picture] The image model's picture cannot be read.
    [key_characters] The key holds letters a key cannot have. Copy it again from the provider's site.
    [lorebook_empty] The lorebook is empty.
    [lorebook_entries] The lorebook has no entries.
    [lorebook_file] The lorebook cannot be read.
    [lorebook_named] The lorebook “{ $name }” cannot be read.
    [lorebook_named_empty] The lorebook “{ $name }” is empty.
    [models_dev_list] The list of models cannot be read.
    [models_list_answer] The address answers, but not with a list of models.
    [models_list_missing] The list of models did not come.
    [name_characters] The name holds characters a name cannot have.
    [no_lorebook] This file is not a lorebook.
    [pdf] The PDF cannot be read.
    [picture] The picture is not a PNG, JPEG or WebP.
    [picture_server_answer] The picture server's answer cannot be read.
    [picture_unreadable] The picture cannot be read.
    [png] Not a PNG file.
    [png_damaged] The PNG is damaged.
    [provider_address] The address must be a plain web address such as https://api.openai.com/v1.
    [provider_website] Give the provider's website as a name such as example.com.
    [recording_format] The recording's format cannot be read.
    [recording_pcm] The recording could not be read. Record again.
    [recording_rate] The recording's rate cannot be read.
    [recording_short] The recording is too short: at least { $shortest } seconds are needed.
    [recording_silent] The recording has no sound.
    [recording_wav] The recording is not a WAV file.
    [sillytavern_base64] This file is not a character card Cardwave can read. Export it again from the app it came from.
    [sillytavern_empty] The card is empty.
    [sillytavern_file] The SillyTavern card in this file cannot be read.
    [sillytavern_json] This file is not a character card Cardwave can read. Export it again from the app it came from.
    [sillytavern_object] This file is not a character card Cardwave can read. Export it again from the app it came from.
    [sillytavern_png] The SillyTavern card in this PNG cannot be read.
    [spec_version] This file is not a character card Cardwave can read. Export it again from the app it came from.
    [spec_version_form] This file is not a character card Cardwave can read. Export it again from the app it came from.
    [toml] This file is not a character card Cardwave can read. Export it again from the app it came from.
    [word_file] The Word file cannot be read.
    [word_text] The Word file has no text.
    [workflow] The workflow “{ $name }” cannot be read.
    [workflow_api_form] The workflow is saved in the form for the API: save it in ComfyUI as a workflow.
    [workflow_broken] The workflow cannot be read.
    [workflow_fields] The workflow's node “{ $kind }” has fields Cardwave cannot read.
    [workflow_no_node] The workflow has no node this ComfyUI can run.
    [workflow_node] The workflow's node “{ $class }” is not one this ComfyUI has.
    [zip] { $name } cannot be read as a zip.
   *[other] That cannot be read.
}
error-too-big = { $what ->
    [card_for_worker] The character is too long for the helper model; pick a helper model that reads more.
    [card_file] The file is larger than { $most } MB.
    [checkpoint_folder] The folder is too large to keep copies of before each step.
    [expression_pack_size] { $name }'s pictures are too large.
    [expression_zip_files] { $name } holds more than { $max_entries } files.
    [figure] The 3D figure is too large.
    [model_for_computer] { $name } is too large for this computer.
    [models_dev_list] The list of models is too long.
    [picture_pixels] The picture is too large ({ $wide } by { $high } pixels).
    [reply] The reply was cut off: it grew too long.
   *[other] That is too large.
}
error-not-now = { $what ->
    [character_has_written] { $name } has written in this chat and stays in it.
    [coding_folder_busy] Another coding task is running in that folder; wait for it, or stop it.
    [database_busy] Cardwave was busy; try again.
    [download_cancelling] Its download is being cancelled; try again in a moment.
    [held_by_card] A character uses this; remove it from the character first.
    [lorebook_used_elsewhere] The lorebook is used elsewhere by now, so it stays in the library.
    [model_downloading] The model is being downloaded.
    [model_replying] The model is replying; delete it once the reply has ended.
    [search_model_not_downloaded] The search model is not downloaded.
    [task_running] The task is still running; stop it first.
   *[other] That cannot be done now. Try again in a moment.
}
error-changed = { $what ->
    [lorebook_entry] The lorebook has another entry by now.
    [card_version] The card was changed meanwhile; it is read anew.
    [tool_name] Another tool is named { $name } now.
    [two_ways] { $reference } was changed twice at once; try again.
    [workflow] The workflow “{ $name }” was changed in ComfyUI: pick it again in Settings › Providers.
   *[other] That was changed meanwhile; try again.
}
error-not-possible = { $what ->
    [back_to_computer] Only search and voice can go back to this computer.
    [card_about_itself] What the card says about itself cannot be changed.
    [card_change] That cannot be changed in this card.
    [card_character] The card has no such character.
    [card_character_change] The card's character cannot be changed.
    [card_language_beside] The card cannot hold { $name } beside its first language.
    [card_lorebook] The card brings no such lorebook.
    [card_lorebook_attached] The card has no such lorebook attached.
    [card_mode] The card has no such mode.
    [card_no_character] The card has no character.
    [card_not_changed] The card was not changed.
    [card_part] That is no part of the card to change.
    [card_takes_no] This card takes nothing new of that kind.
    [card_takes_no_lorebook] The card takes no lorebook.
    [character_change] That character cannot be changed in this card.
    [chat_character] The chat has no such character.
    [chat_lore] The chat has no such lorebook or lorebook entry.
    [chat_lorebook] The chat has no such lorebook.
    [chat_mode] The chat has no such mode.
    [chat_no_character] The chat has no character.
    [chat_without_character] A chat without a character has no characters.
    [chat_without_character_add] A chat without a character takes none.
    [checkpoint_put_back] { $path } cannot be put back.
    [comfyui_no_picture] ComfyUI made no picture.
    [companion_not_answering] The companion did not answer.
    [companion_not_shown] The companion is not showing.
    [comfyui_queue] ComfyUI did not queue the picture.
    [comfyui_said] ComfyUI said: { $said }
    [continue_no_text] The reply has no text to continue.
    [continue_only_reply] Only a character's reply can be continued.
    [depth_note] A note at a depth cannot be added.
    [dictation_failed] The dictation model failed.
    [dictation_model_load] The dictation model cannot be loaded.
    [dictation_model_start] The dictation model cannot be started.
    [draft_made_by] A draft is not made by “{ $made }”.
    [edit_breaks_card] The card would not read after this change.
    [entry_change] The entry cannot be changed as asked in this lorebook.
    [entry_taken_out] This is no lorebook entry that was taken out.
    [export_no_character] The card has no character to export.
    [greeting] That is not one of this character's greetings.
    [improve_direction] Improve uses the words in the field; it takes no hint.
    [key_refused] The key was refused.
    [llama_server_start] The search model cannot be started. Restart Cardwave and try again.
    [local_address] This computer's models are found by their folder, in Settings › Providers.
    [lorebook_change] This lorebook cannot be changed.
    [lorebook_change_breaks] The lorebook would not read after this change.
    [lorebook_new_entry] This lorebook takes no new entry.
    [lorebook_put_in] The lorebook cannot be put into this card.
    [lorebook_take_out] The lorebook cannot be taken out of this card.
    [message_not_in_chat] The message is not part of this chat.
    [message_not_in_view] The message is not in view.
    [model_remove] { $path } cannot be removed.
    [no_folder] There is no such folder on this computer.
    [no_image_model] No image model is set up yet: set one up in Settings › Models › Images.
    [no_local_model] There is no model “{ $id }” in that folder.
    [no_local_models] Local models are not set up.
    [no_recycle_bin] There is no Recycle Bin for { $path }.
    [no_summary] The card has no summary yet.
    [no_voice] There is no such voice.
    [no_vulkan] This computer's graphics card cannot run models. Use a provider instead.
    [no_vulkan_dictation] This computer's graphics card cannot run dictation.
    [prompt_change] That character's prompt cannot be changed in this card.
    [recycle_bin_move] { $path } was not moved to the Recycle Bin.
    [speaker_not_in_chat] The speaker is not part of this chat.
    [speaker_only_character] Only a character's message has a speaker.
    [unknown_language] That is no language this app knows.
    [version_lacks_character] A chat is with a character the newest version lacks.
    [voice_runtime] Reading aloud needs a Microsoft part that is missing: install the Visual C++ Redistributable from microsoft.com, then restart Cardwave.
    [workflow_no_text] The workflow “{ $name }” has no text field for the picture's words.
    [workflow_use] The workflow “{ $name }” cannot be used.
    [written_tools_full] You can keep { $most_tools } tools at most; delete one in Settings › Tools the AI wrote first.
    [delete_not_in_trash] Only what is in the Trash can be deleted for good; move it there first.
   *[other] That cannot be done.
}
error-model-answer = { $what ->
    [no_greeting] The AI wrote no greeting.
    [background_answer] The helper model's answer could not be used. Try again, or pick another helper model.
    [background_text] The helper model's answer could not be used. Try again, or pick another helper model.
    [card_texts] The AI's answer was not the character's texts.
    [classification] The helper model's answer could not be used. Try again, or pick another helper model.
    [example_messages] The AI wrote no example messages.
    [no_example_message] The AI wrote an example message without its text.
    [json] The AI's answer was not in the form asked for.
    [keywords] The helper model's answer could not be used. Try again, or pick another helper model.
    [logline] The helper model's answer could not be used. Try again, or pick another helper model.
    [no_chat_reply] The AI's provider sent no chat reply.
    [no_fitting_answer] The AI gave no usable answer in three tries.
    [no_picture] The image model answered without a picture.
    [no_plan] The planner made no plan.
    [no_text] The AI sent no text.
    [picture_address] The image model's picture is at an address that is not fetched.
    [picture_art] The picture could not be made; try again.
    [picture_field] The helper model found no field for the picture's words.
    [picture_server_no_picture] The picture server answered without a picture.
    [picture_words] The helper model wrote no words for the picture.
    [rating] The helper model's answer could not be used. Try again, or pick another helper model.
    [reply_broke_off] The reply broke off.
    [needs] The helper model's answer could not be used. Try again, or pick another helper model.
    [rounds] The team did not end its work in { $rounds } rounds.
    [search_left_out] The search model left out a text.
    [search_model] The search model's answer cannot be read.
    [search_tokens] The search model's tokens cannot be read.
    [title] The helper model's answer could not be used. Try again, or pick another helper model.
    [too_many_tools] The AI called too many tools.
    [worker_mode] The helper model's answer could not be used. Try again, or pick another helper model.
    [worker_texts] The helper model's answer could not be used. Try again, or pick another helper model.
    [server_reported] The AI's provider reported: { $reason }
   *[other] The AI's answer cannot be used.
}
error-timed-out = { $whose ->
    [comfyui] ComfyUI did not make the picture in time.
    [llama_server] The search model was not ready in time. Try again.
    [model] The AI did not answer in time. Try again.
    [model_server] The AI's provider did not answer in time. Try again.
    [search_model] The search model did not answer in time.
   *[other] It did not answer in time.
}
error-unreachable = { $whose ->
    [comfyui] ComfyUI cannot be reached.
    [image_model] The image model cannot be reached.
    [model_download] The model's file cannot be downloaded.
    [model_server] The AI's provider is not answering: try again later, or check the connection.
    [picture_address] The picture cannot be fetched.
    [picture_server] The picture server cannot be reached.
    [provider_voices] The provider's voices cannot be reached.
    [search_model] The search model does not answer.
    [provider_voice] The provider's voice cannot be reached.
    [provider_search_model] The provider's search model cannot be reached.
   *[other] It cannot be reached.
}
error-answered = { $whose ->
    [comfyui] ComfyUI answered { $status }.
    [model_server] The AI's provider answered { $status }. Try again later.
    [picture_server] The picture server answered { $status }.
    [provider_voices] The provider's voices answered { $status }.
    [search_model] The search model answered { $status }.
   *[other] It answered { $status }.
}
