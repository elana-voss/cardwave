### UI 문구의 한국어판: 서버의 오류 응답. 영어(en.errors.ftl, 원본 파일)에서 키마다 옮긴 것; 용어집은 ko.ftl 머리말.

## The request, as the server took it

error-request-failed = 그 작업을 할 수 없었어요. 다시 시도하세요.
error-internal = Cardwave에서 문제가 생겼어요. 다시 시도하세요.
error-bad-request = Cardwave가 그 요청을 읽을 수 없었어요. 페이지를 새로 고친 뒤 다시 시도하세요.
error-forbidden = 허용되지 않은 작업이에요.
error-no-such-path = Cardwave에 그런 페이지가 없어요. 페이지를 새로 고친 뒤 다시 시도하세요.
error-method-not-allowed = Cardwave는 여기서 그 작업을 하지 않아요. 페이지를 새로 고친 뒤 다시 시도하세요.
error-too-large = 너무 커요. 더 작은 파일로 시도하세요.
error-unsupported-type = Cardwave는 여기서 그런 종류의 파일을 받지 않아요.

## Passwords and accounts

error-locked = 비밀번호를 입력할 때까지 Cardwave가 잠겨 있어요.
error-sign-in = 먼저 로그인하세요.
error-password-wrong = 비밀번호가 틀렸어요.
error-password-needed = 비밀번호가 필요해요.
error-current-password-needed = 현재 비밀번호가 필요해요.
error-backup-password-needed = 이 백업에는 비밀번호가 필요해요.
error-too-many-tries = 비밀번호가 너무 많이 틀렸어요. { $seconds }초 후에 다시 시도하세요.
error-owner-only = 이 컴퓨터의 계정만 { $action ->
    [use_its_files] 이 컴퓨터의 파일을 사용할 수 있어요
    [use_its_folders] 이 컴퓨터의 폴더를 사용할 수 있어요
    [choose_its_models] 이 컴퓨터의 모델을 고를 수 있어요
    [lock_Cardwave] Cardwave를 잠글 수 있어요
   *[other] 그 작업을 할 수 있어요
}.
error-no-password-to-lock = Cardwave는 비밀번호가 켜져 있을 때만 잠겨요.
error-remote-sign-in-off = 이 계정은 다른 기기에서 로그인할 수 없어요. 계정 › 공유에서 켜세요.
error-no-password-on = 켜져 있는 비밀번호가 없어요.
error-no-password-set = 이 계정에는 비밀번호가 설정되어 있지 않아요.
error-password-kept = 이 컴퓨터의 계정에 비밀번호가 있어요: 그 비밀번호로 로그인해요.
error-account-busy = Cardwave가 아직 답장을 쓰거나 캐릭터를 읽고 있어요. 끝나면 다시 시도하세요.
error-restore-busy = Cardwave가 아직 답장을 쓰거나 캐릭터를 읽고 있어요. 끝나면 다시 시도하세요.
error-backup-needs-password = 백업에는 비밀번호가 필요해요.

## What is asked of

error-not-found = 그런 { $what ->
    [account] 계정이
    [asset] 카드 속 파일이
    [attachment] 첨부 파일이
    [card] 카드가
    [card_version] 카드 버전이
    [chat] 채팅이
    [chat_character] 채팅 속 캐릭터가
    [checkpoint] 체크포인트가
    [deleted_message] 삭제된 메시지가
    [document] 문서가
    [expression] 표정이
    [expression_pack] 표정 세트
    [figure] 피규어가
    [kind_of_model] 모델 종류가
    [language] 언어가
    [lorebook] 로어북이
    [lorebook_entry] 로어북 항목이
    [memory] 기억이
    [message] 메시지가
    [model] 모델이
    [persona] 페르소나가
    [picture] 이미지가
    [preset] 프리셋이
    [prompt_preset] 프롬프트 프리셋이
    [provider] 제공자가
    [question] 질문이
    [task] 작업이
    [tool] 도구가
    [user] 계정이
    [voice] 음성이
   *[other] 것이
} 없어요. 삭제되었을 수 있어요.
error-chat-busy = 이 채팅에서 답장을 쓰는 중이에요. 먼저 멈추세요.
error-no-provider = 아직 설정한 제공자가 없어요. 설정 › 제공자에서 추가하세요.
error-provider-refused = { $refusal ->
    [key] 제공자가 키를 받지 않았어요. 설정 › 제공자에서 확인하세요.
    [busy] 제공자의 크레딧이 없거나 바빠요. 나중에 다시 해 보세요.
    [down] 제공자가 응답하지 않아요. 나중에 다시 해 보세요.
   *[other] 제공자가 거절했어요: { $reason }
}
error-model-declined = { $model } 모델이 이 글을 쓰기를 거부했어요. 메시지를 바꾸거나 다른 모델을 고르세요.
error-model-sees-no-pictures = { $model } 모델은 이미지를 볼 수 없어서 받지 않아요. 그림을 보내려면 그림을 볼 수 있는 모델을 고르세요.
error-card-trashed = 이 캐릭터는 휴지통에 있어요. 먼저 복원하세요.
error-lorebook-trashed = “{ $name }” 로어북이 휴지통에 있어요. 사용하려면 복원하세요.
error-own-lorebook-flags = 캐릭터 자체의 로어북은 캐릭터와 함께해요. 따로 별표를 달거나, 보관하거나, 휴지통으로 옮기거나, 모든 채팅에서 쓸 수 없어요.

## Folders and files

error-no-such-folder = 이 컴퓨터에 { $folder } 폴더가 없어요.
error-folder-not-chosen = 먼저 폴더를 선택하세요.
error-drive-root-to-watch = 드라이브의 최상위 폴더는 지켜보기에 너무 많은 것을 담고 있어요. 그 안의 폴더를 선택하세요.
error-drive-root-for-model = 드라이브의 루트는 AI에게 주기에는 담긴 것이 너무 많아요. 그 안의 폴더를 고르세요.
error-data-folder = 그 폴더는 Cardwave 자체의 데이터를 담고 있거나 그 안에 있어요. 다른 폴더를 선택하세요.
error-commands-windows-only = 명령은 Windows에서만 실행돼요.
error-recycle-bin-windows-only = 파일은 Windows에서만 Windows 휴지통으로 옮겨져요.
error-files-tool-off = 먼저 설정 › 도구에서 파일을 켜세요: 팀이 이 도구로 작업 폴더를 읽고 써요.

## Pictures, replies and voices

error-picture-words-missing = 먼저 이미지에 무엇이 보일지 적으세요.
error-picture-words-too-long = 이미지 설명이 { $most }자보다 길어요.
error-picture-needs-words = 이미지에 무엇이 보일지 적으세요.
error-goal-missing = 팀이 할 일을 적으세요.
error-dictation-not-set-up = 음성 입력이 설정되지 않았어요: 설정 › 모델 › 음성 입력.
error-direction-without-go-on = 힌트는 이어 쓰기에서만 쓸 수 있어요.
error-again-or-go-on = 답장은 다시 쓰거나 이어 쓰거나 둘 중 하나만 돼요.
error-again-not-reply = 캐릭터의 답장만 다시 쓸 수 있어요.
error-no-reply-to-write-again = 이 채팅에는 다시 쓸 답장이 없어요.
error-no-text = AI가 글을 보내지 않았어요. 다시 시도하세요.
error-worker-no-answer = 보조 모델이 답하지 않았어요.
error-unknown-voice = “{ $voice }” 음성이 없어요.
error-nothing-to-read = 읽을 것이 없어요.
error-voice-not-downloaded = 음성을 다운로드하지 않았어요.
error-voice-failed = 읽어 주기에 실패했어요. 다시 시도하세요.
error-stopping = Cardwave를 종료하는 중이에요.
error-download-failed = 다운로드에 실패했어요. 연결을 확인하고 다시 시도하세요.
error-search-model-failed = 검색 모델이 실패했어요. Cardwave가 잠시 후 다시 시도해요.
error-models-not-listed = 제공자의 모델 목록을 가져오지 못했어요. 주소와 키를 확인한 뒤 다시 시도하세요.
error-file-not-imported = 파일을 읽을 수 없었어요. Cardwave가 모르는 형식이에요.
error-describing-failed = 보조 모델이 캐릭터를 설명하지 못했어요.

## The kinds an area's failures are grouped by: each picks its words by `what` (or `whose`), the thing it is about

error-needed = { $what ->
    [persona_name] 페르소나에는 이름이 필요해요.
    [account_name] 계정에는 이름이 필요해요.
    [card_title] 캐릭터에 제목이 필요해요.
    [character_name] 캐릭터에는 이름이 필요해요.
    [chat_character] 채팅에는 캐릭터가 필요해요.
    [chat_title] 채팅 제목이 비어 있어요.
    [entry_name] 항목에는 이름이 필요해요.
    [expression_files] zip 파일(묶은 폴더)이나 세트의 이미지들을 고르세요.
    [language] 언어가 빠졌어요.
    [lorebook_name] 로어북에는 이름이 필요해요.
    [memory_text] 기억에는 내용이 필요해요.
    [message_to_improve] 다듬을 메시지가 없어요.
    [model_name] 모델 이름을 적어야 해요.
    [models_folder] 먼저 모델 폴더를 선택하세요.
    [password] 비밀번호는 비워 둘 수 없어요.
    [preset_name] 프리셋에는 이름이 필요해요.
    [rewrite_given] 필요한 것이 빠졌어요. 다시 시도하세요.
    [summary] 요약이 비어 있어요.
    [text_to_change] 바꿀 텍스트가 없어요.
    [text_to_read] 읽을 것이 없어요.
    [voice_name] 음성에는 이름이 필요해요.
   *[other] 필요한 것이 빠졌어요. 다시 시도하세요.
}
error-too-long = { $what ->
    [account_name] 계정 이름은 최대 { $name_limit }자예요.
    [chat_title] 채팅 제목은 최대 { $title_limit }자예요.
    [document] “{ $name }” 문서가 너무 길어요: 문서는 최대 2,000,000자예요.
    [entry_name] 항목 이름은 최대 { $max_name }자예요.
    [field_name] 필드 이름은 1~{ $max_field }자예요.
    [lorebook_name] 로어북 이름은 최대 { $max_name }자예요.
    [memory_text] 기억은 최대 { $text_limit }자예요.
    [persona_name] 페르소나 이름은 최대 { $max_name }자예요.
    [provider_name] 이름은 최대 { $name_limit }자예요.
    [unsaved_text] 저장하지 않은 텍스트는 최대 { $max_text }자까지 보관해요.
    [voice_name] 음성 이름은 최대 { $name_most }자예요.
   *[other] { $most }자보다 길어요.
}
error-out-of-range = { $what ->
    [authors_note_depth] 노트는 메시지 하나 이상 앞에 넣어요.
    [companion_size] 컴패니언의 크기는 화면 높이의 { $start }~{ $end }%예요.
    [context_size] 컨텍스트 크기는 512 토큰 이상이어야 해요.
    [entry_chance] 항목의 확률은 최대 100%예요.
    [provider_setting] { $name } 값은 { $min }~{ $max }여야 해요.
    [reply_length] 답장 길이는 1~{ $most_reply_length } 토큰이어야 해요.
    [slider] 슬라이더는 0~100이에요.
    [talk_pause] 간격은 0~{ $most_talk_pause }초여야 해요.
    [talk_replies] 연속 답장 수는 1~{ $most_talk_replies }여야 해요.
    [talkativeness] 수다스러움은 0부터 100까지예요.
    [voice_speed] 속도는 { $start }%부터 { $end }%까지예요.
   *[other] { $least }~{ $most } 사이여야 해요.
}
error-taken = { $what ->
    [card_in_library] 이미 라이브러리에 있어요.
    [account_name] “{ $name }” 이름의 계정이 이미 있어요.
    [card_language] 이 카드는 이미 { $name } 언어로 되어 있어요.
    [chat_character] { $name } 캐릭터가 이미 이 채팅에 있어요.
    [chat_character_twice] { $name } 캐릭터가 이 채팅에 두 번 있어요.
    [lorebook_same_name] 카드에 이미 같은 이름의 로어북이나 항목이 있어요.
    [model_file] { $name } 파일이 이미 폴더에 있어요.
    [preset_name] “{ $name }” 이름의 프리셋이 이미 있어요.
    [tool_name] { $name } 이름의 도구가 이미 있어요. 다른 이름을 고르세요.
   *[other] 이미 있어요.
}
error-in-trash = { $what ->
    [card] 이 캐릭터는 휴지통에 있어요. 먼저 복원하세요.
    [card_to_chat] 캐릭터가 휴지통에 있어요. 다시 채팅하려면 캐릭터를 복원하세요.
    [chat] 이 채팅은 휴지통에 있어요. 먼저 복원하세요.
    [chat_card] 이 채팅의 “{ $title }” 캐릭터가 휴지통에 있어요. 먼저 캐릭터를 복원하세요.
    [lorebook] “{ $name }” 로어북이 휴지통에 있어요. 먼저 복원하세요.
    [lorebook_to_use] “{ $name }” 로어북이 휴지통에 있어요. 사용하려면 복원하세요.
    [persona_default] 휴지통에 있는 페르소나는 기본값이 될 수 없어요. 먼저 복원하세요.
    [persona_to_use] “{ $name }” 페르소나가 휴지통에 있어요. 사용하려면 복원하세요.
   *[other] 휴지통에 있어요. 먼저 복원하세요.
}
error-not-readable = { $what ->
    [damaged_key] 키가 손상되었어요.
    [json] 올바른 JSON 파일이 아니에요.
    [lorebook] 파일에 로어북이 없어요.
    [lorebook_not_card] 이 파일은 로어북이 아니라 캐릭터 카드예요.
    [account_picture] 이미지는 한 변이 최대 4,096픽셀인 PNG나 JPEG여야 하고, 읽을 수 있어야 해요.
    [attachment_picture] 이미지는 PNG, JPEG, WebP 파일이에요.
    [backup] 이 파일은 Cardwave 백업이 아니에요.
    [backup_damaged] 이 백업이 손상되었어요.
    [backup_key] 이 백업이 손상되었어요: 키를 읽을 수 없어요.
    [base64] base64가 아니에요.
    [base64_file] { $name } 파일이 base64가 아니에요.
    [card_defined_twice] 이 파일은 Cardwave가 읽을 수 있는 캐릭터 카드가 아니에요. 원래 앱에서 다시 내보내세요.
    [card_file_name] 카드 속 파일 이름을 사용할 수 없어요.
    [card_reference] 카드의 어떤 부분도 가리키지 않아요.
    [ccv4_version] 이 카드는 더 새로운 Cardwave에서 만들어졌어요. 열려면 Cardwave를 업데이트하세요.
    [comfyui_address] ComfyUI의 주소를 읽을 수 없어요.
    [comfyui_answer] ComfyUI의 응답을 읽을 수 없어요.
    [dictation_recording] 녹음을 읽을 수 없었어요. 다시 녹음하세요.
    [document_text] { $name } 문서에 읽을 수 있는 텍스트가 없어요.
    [document_type] 문서는 .txt, .md, .pdf, .docx 파일이에요.
    [downloaded_model] 다운로드한 파일이 그 모델이 아니에요.
    [expression_pack] 감정의 영어 이름(joy.png, anger.png 등)으로 된 이미지가 하나도 없어요(PNG, JPEG, WebP 또는 GIF).
    [figure_file] { $file_name } 파일은 그런 종류의 파일이 아니에요.
    [figure_still] 피규어의 정지 이미지가 최대 4 MB의 PNG가 아니에요.
    [figure_type] 3D 피규어는 VRM, GLB, FBX 파일이에요.
    [folder_read] 폴더를 읽을 수 없어요.
    [format_version] 이 파일은 Cardwave가 읽을 수 있는 캐릭터 카드가 아니에요. 원래 앱에서 다시 내보내세요.
    [image_model_answer] 이미지 모델의 응답을 읽을 수 없어요.
    [image_model_picture] 이미지 모델의 이미지를 읽을 수 없어요.
    [key_characters] 키에 쓸 수 없는 문자가 들어 있어요. 제공자 사이트에서 다시 복사하세요.
    [lorebook_empty] 로어북이 비어 있어요.
    [lorebook_entries] 로어북에 항목이 없어요.
    [lorebook_file] 로어북을 읽을 수 없어요.
    [lorebook_named] “{ $name }” 로어북을 읽을 수 없어요.
    [lorebook_named_empty] “{ $name }” 로어북이 비어 있어요.
    [models_dev_list] 모델 목록을 읽을 수 없어요.
    [models_list_answer] 주소가 응답하지만 모델 목록을 보내지 않아요.
    [models_list_missing] 모델 목록이 오지 않았어요.
    [name_characters] 이름에 들어갈 수 없는 문자가 있어요.
    [no_lorebook] 로어북이 아니에요.
    [pdf] PDF를 읽을 수 없어요.
    [picture] 이미지가 PNG, JPEG, WebP가 아니에요.
    [picture_server_answer] 이미지 서버의 응답을 읽을 수 없어요.
    [picture_unreadable] 이미지를 읽을 수 없어요.
    [png] PNG 파일이 아니에요.
    [png_damaged] PNG가 손상되었어요.
    [provider_address] 주소는 https://api.openai.com/v1 같은 일반 웹 주소여야 해요.
    [provider_website] 제공자의 웹사이트를 example.com 같은 이름으로 적으세요.
    [recording_format] 녹음의 형식을 읽을 수 없어요.
    [recording_pcm] 녹음을 읽을 수 없었어요. 다시 녹음하세요.
    [recording_rate] 녹음의 샘플링 레이트를 읽을 수 없어요.
    [recording_short] 녹음이 너무 짧아요: 최소 { $shortest }초가 필요해요.
    [recording_silent] 녹음에 소리가 없어요.
    [recording_wav] 녹음이 WAV 파일이 아니에요.
    [sillytavern_base64] 이 파일은 Cardwave가 읽을 수 있는 캐릭터 카드가 아니에요. 원래 앱에서 다시 내보내세요.
    [sillytavern_empty] 카드가 비어 있어요.
    [sillytavern_file] 이 파일의 SillyTavern 카드를 읽을 수 없어요.
    [sillytavern_json] 이 파일은 Cardwave가 읽을 수 있는 캐릭터 카드가 아니에요. 원래 앱에서 다시 내보내세요.
    [sillytavern_object] 이 파일은 Cardwave가 읽을 수 있는 캐릭터 카드가 아니에요. 원래 앱에서 다시 내보내세요.
    [sillytavern_png] 이 PNG의 SillyTavern 카드를 읽을 수 없어요.
    [spec_version] 이 파일은 Cardwave가 읽을 수 있는 캐릭터 카드가 아니에요. 원래 앱에서 다시 내보내세요.
    [spec_version_form] 이 파일은 Cardwave가 읽을 수 있는 캐릭터 카드가 아니에요. 원래 앱에서 다시 내보내세요.
    [toml] 이 파일은 Cardwave가 읽을 수 있는 캐릭터 카드가 아니에요. 원래 앱에서 다시 내보내세요.
    [word_file] Word 파일을 읽을 수 없어요.
    [word_text] Word 파일에 텍스트가 없어요.
    [workflow] “{ $name }” 워크플로를 읽을 수 없어요.
    [workflow_api_form] 워크플로가 API용 형식으로 저장되어 있어요: ComfyUI에서 워크플로로 저장하세요.
    [workflow_broken] 워크플로를 읽을 수 없어요.
    [workflow_fields] 워크플로의 노드 “{ $kind }”에 Cardwave가 읽을 수 없는 필드가 있어요.
    [workflow_no_node] 워크플로에 이 ComfyUI가 실행할 수 있는 노드가 없어요.
    [workflow_node] 워크플로의 “{ $class }” 노드는 이 ComfyUI에 없어요.
    [zip] { $name } 파일을 zip으로 읽을 수 없어요.
   *[other] 읽을 수 없어요.
}
error-too-big = { $what ->
    [card_for_worker] 캐릭터가 보조 모델에게 너무 길어요. 더 많이 읽는 보조 모델을 고르세요.
    [card_file] 파일이 { $most } MB보다 커요.
    [checkpoint_folder] 폴더가 너무 커서 단계마다 그 전에 사본을 남길 수 없어요.
    [expression_pack_size] { $name }의 이미지가 너무 커요.
    [expression_zip_files] { $name } 파일에 파일이 { $max_entries }개보다 많아요.
    [figure] 3D 피규어가 너무 커요.
    [model_for_computer] { $name } 모델은 이 컴퓨터에 너무 커요.
    [models_dev_list] 모델 목록이 너무 길어요.
    [picture_pixels] 이미지가 너무 커요({ $wide }×{ $high }픽셀).
    [reply] 답장이 너무 길어져서 잘렸어요.
   *[other] 너무 커요.
}
error-not-now = { $what ->
    [character_has_written] { $name } 캐릭터는 이 채팅에 글을 써서 채팅에 남아요.
    [coding_folder_busy] 그 폴더에서 다른 코딩 작업이 실행 중이에요. 끝날 때까지 기다리거나 멈추세요.
    [database_busy] Cardwave가 바빴어요. 다시 시도하세요.
    [download_cancelling] 다운로드를 취소하는 중이에요. 잠시 후 다시 시도하세요.
    [held_by_card] 캐릭터가 이것을 쓰고 있어요. 먼저 캐릭터에서 빼세요.
    [lorebook_used_elsewhere] 이 로어북은 이제 다른 곳에서도 쓰여서 라이브러리에 남아요.
    [model_downloading] 모델을 다운로드하는 중이에요.
    [model_replying] 모델이 답장하는 중이에요. 답장이 끝난 뒤에 삭제하세요.
    [search_model_not_downloaded] 검색 모델을 다운로드하지 않았어요.
    [task_running] 작업이 아직 실행 중이에요. 먼저 멈추세요.
   *[other] 지금은 할 수 없어요. 잠시 후 다시 시도하세요.
}
error-changed = { $what ->
    [lorebook_entry] 그 사이 로어북의 항목이 바뀌었어요.
    [card_version] 그 사이 카드가 바뀌어서 다시 읽어요.
    [tool_name] 이제 다른 도구가 { $name } 이름을 써요.
    [two_ways] { $reference }이(가) 동시에 두 번 바뀌었어요. 다시 시도하세요.
    [workflow] “{ $name }” 워크플로가 ComfyUI에서 바뀌었어요: 설정 › 제공자에서 다시 고르세요.
   *[other] 그 사이 바뀌었어요. 다시 시도하세요.
}
error-not-possible = { $what ->
    [back_to_computer] 검색과 음성만 이 컴퓨터로 되돌릴 수 있어요.
    [card_about_itself] 카드가 자신에 대해 적은 내용은 바꿀 수 없어요.
    [card_change] 이 카드에서는 그것을 바꿀 수 없어요.
    [card_character] 카드에 그런 캐릭터가 없어요.
    [card_character_change] 카드의 캐릭터를 바꿀 수 없어요.
    [card_language_beside] 카드에 첫 번째 언어와 함께 { $name } 언어를 넣을 수 없어요.
    [card_lorebook] 카드에 그런 로어북이 없어요.
    [card_lorebook_attached] 카드에 그런 로어북이 연결되어 있지 않아요.
    [card_mode] 카드에 그런 모드가 없어요.
    [card_no_character] 카드에 캐릭터가 없어요.
    [card_not_changed] 카드가 바뀌지 않았어요.
    [card_part] 바꿀 수 있는 카드의 부분이 아니에요.
    [card_takes_no] 이 카드에는 그런 종류의 새 항목을 넣을 수 없어요.
    [card_takes_no_lorebook] 이 카드에는 로어북을 넣을 수 없어요.
    [character_change] 이 카드에서 그 캐릭터를 바꿀 수 없어요.
    [chat_character] 채팅에 그런 캐릭터가 없어요.
    [chat_lore] 채팅에 그런 로어북이나 로어북 항목이 없어요.
    [chat_lorebook] 채팅에 그런 로어북이 없어요.
    [chat_mode] 채팅에 그런 모드가 없어요.
    [chat_no_character] 채팅에 캐릭터가 없어요.
    [chat_without_character] 캐릭터 없는 채팅에는 캐릭터가 없어요.
    [chat_without_character_add] 캐릭터 없는 채팅에는 캐릭터를 넣을 수 없어요.
    [checkpoint_put_back] { $path } 파일을 되돌릴 수 없어요.
    [comfyui_no_picture] ComfyUI가 이미지를 만들지 않았어요.
    [companion_not_answering] 컴패니언이 응답하지 않았어요.
    [companion_not_shown] 컴패니언이 표시되어 있지 않아요.
    [comfyui_queue] ComfyUI가 이미지를 대기열에 넣지 않았어요.
    [comfyui_said] ComfyUI의 응답: { $said }
    [continue_no_text] 답장에 이어 쓸 텍스트가 없어요.
    [continue_only_reply] 캐릭터의 답장만 이어 쓸 수 있어요.
    [depth_note] 깊이를 지정한 노트는 추가할 수 없어요.
    [dictation_failed] 음성 입력 모델이 실패했어요.
    [dictation_model_load] 음성 입력 모델을 불러올 수 없어요.
    [dictation_model_start] 음성 입력 모델을 시작할 수 없어요.
    [draft_made_by] “{ $made }”이(가) 만든 초안이 아니에요.
    [edit_breaks_card] 이렇게 바꾸면 카드를 읽을 수 없게 돼요.
    [entry_change] 이 로어북에서는 요청한 대로 항목을 바꿀 수 없어요.
    [entry_taken_out] 꺼낸 로어북 항목이 아니에요.
    [export_no_character] 카드에 내보낼 캐릭터가 없어요.
    [greeting] 이 캐릭터의 인사말이 아니에요.
    [improve_direction] 다듬기는 입력란의 글을 써요. 힌트는 받지 않아요.
    [key_refused] 키가 거부되었어요.
    [llama_server_start] 검색 모델을 시작할 수 없어요. Cardwave를 다시 시작하고 다시 시도하세요.
    [local_address] 이 컴퓨터의 모델은 설정 › 제공자에서 폴더로 찾아요.
    [lorebook_change] 이 로어북은 바꿀 수 없어요.
    [lorebook_change_breaks] 이렇게 바꾸면 로어북을 읽을 수 없게 돼요.
    [lorebook_new_entry] 이 로어북에는 새 항목을 넣을 수 없어요.
    [lorebook_put_in] 이 로어북을 이 카드에 넣을 수 없어요.
    [lorebook_take_out] 이 로어북을 이 카드에서 꺼낼 수 없어요.
    [message_not_in_chat] 이 메시지는 이 채팅에 속하지 않아요.
    [message_not_in_view] 이 메시지가 화면에 없어요.
    [model_remove] { $path } 파일을 제거할 수 없어요.
    [no_folder] 이 컴퓨터에 그런 폴더가 없어요.
    [no_image_model] 아직 설정한 이미지 모델이 없어요: 설정 › 모델 › 이미지에서 설정하세요.
    [no_local_model] 그 폴더에 “{ $id }” 모델이 없어요.
    [no_local_models] 로컬 모델이 설정되지 않았어요.
    [no_recycle_bin] { $path } 경로에는 Windows 휴지통이 없어요.
    [no_summary] 카드에 아직 요약이 없어요.
    [no_voice] 그런 음성이 없어요.
    [no_vulkan] 이 컴퓨터의 그래픽 카드로는 모델을 실행할 수 없어요. 대신 제공자를 쓰세요.
    [no_vulkan_dictation] 이 컴퓨터의 그래픽 카드로는 받아쓰기를 실행할 수 없어요.
    [prompt_change] 이 카드에서 그 캐릭터의 프롬프트를 바꿀 수 없어요.
    [recycle_bin_move] { $path } 파일을 Windows 휴지통으로 옮기지 못했어요.
    [speaker_not_in_chat] 말하는 캐릭터가 이 채팅에 속하지 않아요.
    [speaker_only_character] 캐릭터의 메시지에만 말하는 캐릭터가 있어요.
    [unknown_language] 이 앱이 아는 언어가 아니에요.
    [version_lacks_character] 최신 버전에 없는 캐릭터와의 채팅이 있어요.
    [voice_runtime] 소리 내어 읽기에 필요한 Microsoft 구성 요소가 없어요. microsoft.com에서 Visual C++ 재배포 가능 패키지를 설치한 뒤 Cardwave를 다시 시작하세요.
    [workflow_no_text] “{ $name }” 워크플로에 이미지 설명을 넣을 텍스트 필드가 없어요.
    [workflow_use] “{ $name }” 워크플로를 사용할 수 없어요.
    [written_tools_full] 도구는 최대 { $most_tools }개까지 둘 수 있어요. 먼저 설정 › AI가 만든 도구에서 하나를 삭제하세요.
    [delete_not_in_trash] 휴지통에 있는 것만 영구 삭제할 수 있어요. 먼저 휴지통으로 옮기세요.
   *[other] 그 작업은 할 수 없어요.
}
error-model-answer = { $what ->
    [no_greeting] AI가 인사말을 쓰지 않았어요.
    [background_answer] 보조 모델의 답을 쓸 수 없었어요. 다시 시도하거나 다른 보조 모델을 고르세요.
    [background_text] 보조 모델의 답을 쓸 수 없었어요. 다시 시도하거나 다른 보조 모델을 고르세요.
    [card_texts] AI의 응답이 캐릭터의 글이 아니었어요.
    [classification] 보조 모델의 답을 쓸 수 없었어요. 다시 시도하거나 다른 보조 모델을 고르세요.
    [example_messages] AI가 예시 메시지를 쓰지 않았어요.
    [no_example_message] AI가 내용 없는 예시 메시지를 썼어요.
    [json] AI의 응답이 요청한 형식이 아니었어요.
    [keywords] 보조 모델의 답을 쓸 수 없었어요. 다시 시도하거나 다른 보조 모델을 고르세요.
    [logline] 보조 모델의 답을 쓸 수 없었어요. 다시 시도하거나 다른 보조 모델을 고르세요.
    [no_chat_reply] AI 제공자가 채팅 답장을 보내지 않았어요.
    [no_fitting_answer] AI가 세 번 시도하는 동안 쓸 만한 응답을 주지 않았어요.
    [no_picture] 이미지 모델이 이미지 없이 응답했어요.
    [no_plan] 플래너가 계획을 세우지 않았어요.
    [no_text] AI가 글을 보내지 않았어요.
    [picture_address] 이미지 모델의 이미지가 가져오지 않는 주소에 있어요.
    [picture_art] 이미지를 만들 수 없었어요. 다시 시도하세요.
    [picture_field] 보조 모델이 이미지 설명을 넣을 필드를 찾지 못했어요.
    [picture_server_no_picture] 이미지 서버가 이미지 없이 응답했어요.
    [picture_words] 보조 모델이 이미지 설명을 쓰지 않았어요.
    [rating] 보조 모델의 답을 쓸 수 없었어요. 다시 시도하거나 다른 보조 모델을 고르세요.
    [reply_broke_off] 답장이 중간에 끊겼어요.
    [needs] 보조 모델의 답을 쓸 수 없었어요. 다시 시도하거나 다른 보조 모델을 고르세요.
    [rounds] 팀이 { $rounds }라운드 안에 작업을 끝내지 못했어요.
    [search_left_out] 검색 모델이 텍스트 하나를 빠뜨렸어요.
    [search_model] 검색 모델의 응답을 읽을 수 없어요.
    [search_tokens] 검색 모델의 토큰을 읽을 수 없어요.
    [title] 보조 모델의 답을 쓸 수 없었어요. 다시 시도하거나 다른 보조 모델을 고르세요.
    [too_many_tools] AI가 도구를 너무 많이 호출했어요.
    [worker_mode] 보조 모델의 답을 쓸 수 없었어요. 다시 시도하거나 다른 보조 모델을 고르세요.
    [worker_texts] 보조 모델의 답을 쓸 수 없었어요. 다시 시도하거나 다른 보조 모델을 고르세요.
    [server_reported] AI 제공자의 보고: { $reason }
   *[other] AI의 응답을 쓸 수 없어요.
}
error-timed-out = { $whose ->
    [comfyui] ComfyUI가 제시간에 이미지를 만들지 못했어요.
    [llama_server] 검색 모델이 제때 준비되지 않았어요. 다시 시도하세요.
    [model] AI가 제때 응답하지 않았어요. 다시 시도하세요.
    [model_server] AI 제공자가 제때 응답하지 않았어요. 다시 시도하세요.
    [search_model] 검색 모델이 제시간에 응답하지 않았어요.
   *[other] 제시간에 응답하지 않았어요.
}
error-unreachable = { $whose ->
    [comfyui] ComfyUI에 연결할 수 없어요.
    [image_model] 이미지 모델에 연결할 수 없어요.
    [model_download] 모델 파일을 다운로드할 수 없어요.
    [model_server] AI 제공자가 응답하지 않아요. 나중에 다시 해 보거나 연결을 확인하세요.
    [picture_address] 이미지를 가져올 수 없어요.
    [picture_server] 이미지 서버에 연결할 수 없어요.
    [provider_voices] 제공자의 음성에 연결할 수 없어요.
    [search_model] 검색 모델이 응답하지 않아요.
    [provider_voice] 제공자의 음성에 연결할 수 없어요.
    [provider_search_model] 제공자의 검색 모델에 연결할 수 없어요.
   *[other] 연결할 수 없어요.
}
error-answered = { $whose ->
    [comfyui] ComfyUI의 응답: { $status }.
    [model_server] AI 제공자가 { $status }(으)로 응답했어요. 나중에 다시 시도하세요.
    [picture_server] 이미지 서버의 응답: { $status }.
    [provider_voices] 제공자 음성의 응답: { $status }.
    [search_model] 검색 모델의 응답: { $status }.
   *[other] 응답: { $status }.
}
