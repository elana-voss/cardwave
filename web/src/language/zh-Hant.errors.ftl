### 介面文字的繁體中文（臺灣）版：伺服器的錯誤回覆，api/generated/Code.ts 的每個代碼一條（errors.ts），
### 鍵為 `error-<code>`，「_」換成「-」；詞彙表見 zh-Hant.ftl 的開頭。

## The request, as the server took it

error-request-failed = 無法完成這項操作。請再試一次。
error-internal = Cardwave 發生錯誤，請再試一次。
error-bad-request = Cardwave 無法讀取這個請求。請重新載入頁面後再試一次。
error-forbidden = 不允許這項操作。
error-no-such-path = Cardwave 沒有這個頁面。請重新載入頁面後再試一次。
error-method-not-allowed = Cardwave 在這裡不能這麼做。請重新載入頁面後再試一次。
error-too-large = 這太大了。請換一個小一點的檔案。
error-unsupported-type = Cardwave 在這裡不接受這種檔案。

## Passwords and accounts

error-locked = Cardwave 已鎖定，要輸入密碼才能使用。
error-sign-in = 請先登入。
error-password-wrong = 密碼錯誤。
error-password-needed = 需要密碼。
error-current-password-needed = 需要目前的密碼。
error-backup-password-needed = 這個備份需要它的密碼。
error-too-many-tries = 密碼錯誤次數太多，請在 { $seconds } 秒後再試。
error-owner-only = 只有這台電腦的帳號才能{ $action ->
    [use_its_files] 使用它的檔案
    [use_its_folders] 使用它的資料夾
    [choose_its_models] 選擇它的模型
    [lock_Cardwave] 鎖定 Cardwave
   *[other] 這麼做
}。
error-no-password-to-lock = 只有設定了密碼，Cardwave 才能鎖定。
error-remote-sign-in-off = 這個帳號不能從其他裝置登入。請在「帳號 › 共享」中開啟。
error-no-password-on = 沒有設定密碼。
error-no-password-set = 這個帳號沒有設定密碼。
error-password-kept = 這台電腦上已有帳號設定了密碼：該帳號要用密碼登入。
error-account-busy = Cardwave 還在為此帳戶工作：回覆、圖片、程式設計任務、新角色、讀取角色或聊天的記憶；請在完成後再試。
error-restore-busy = Cardwave 還在工作：回覆、圖片、程式設計任務、新角色、讀取角色或聊天的記憶；請在完成後再試。
error-backup-needs-password = 備份需要密碼。

## What is asked of

error-not-found = 沒有這個{ $what ->
    [account] 帳號
    [asset] 角色卡中的檔案
    [attachment] 附件
    [card] 角色卡
    [card_version] 角色卡版本
    [chat] 聊天
    [chat_character] 聊天中的角色
    [checkpoint] 檢查點
    [deleted_message] 已刪除的訊息
    [document] 文件
    [expression] 表情
    [expression_pack] 表情組
    [figure] 3D 形象
    [kind_of_model] 模型種類
    [language] 語言
    [lorebook] 世界書
    [lorebook_entry] 世界書條目
    [memory] 記憶
    [message] 訊息
    [model] 模型
    [persona] 使用者角色
    [picture] 圖片
    [preset] 預設集
    [prompt_preset] 提示詞預設集
    [provider] 供應商
    [question] 問題
    [task] 任務
    [tool] 工具
    [user] 帳號
    [voice] 語音
   *[other] 項目
}。它可能已被刪除。
error-chat-busy = 這個聊天正在撰寫回覆，請先停止。
error-no-provider = 還沒有設定任何供應商。請在「設定 › 供應商」中新增一個。
error-provider-refused = { $refusal ->
    [key] 供應商沒有接受這組金鑰：請到「設定 › 供應商」檢查。
    [paid] 供應商要求為此付費：請儲值，或選擇你的方案包含的模型。
    [busy] 供應商的額度已用完或正忙碌：請稍後再試。
    [down] 供應商沒有回應：請稍後再試。
    [fault] 供應商那邊出了故障：{ $reason } 請稍後再試。
    [no_model] 供應商已不再提供這個模型：請在 設定 › 模型 中另選一個。
    [too_long] 這則訊息對這個模型來說太長了：請縮短它，或在 設定 › 模型 中選一個能接收更多內容的模型。
   *[other] 供應商拒絕了：{ $reason }
}
error-model-declined = { $model } 拒絕撰寫這段內容。請修改訊息，或換一個模型。
error-model-sees-no-pictures = { $model } 看不到圖片，所以不接受圖片。要傳送圖片，請選擇能看圖片的模型。
error-card-trashed = 這個角色在垃圾桶中，請先還原。
error-lorebook-trashed = 世界書「{ $name }」在垃圾桶中，請還原後再使用。
error-own-lorebook-flags = 角色自己的世界書隨角色一起：不能單獨加星號、封存、移到垃圾桶或用於每個聊天。

## Folders and files

error-no-such-folder = 這台電腦上沒有資料夾 { $folder }。
error-folder-not-chosen = 請先選擇資料夾。
error-drive-root-to-watch = 磁碟機的根目錄內容太多，無法監看；請選擇其中的資料夾。
error-drive-root-for-model = 磁碟機的根目錄內容太多，無法交給 AI；請選擇其中的一個資料夾。
error-data-folder = 這個資料夾存放 Cardwave 自己的資料，或位於其中；請選擇其他資料夾。
error-commands-windows-only = 只有在 Windows 上才能執行指令。
error-recycle-bin-windows-only = 只有在 Windows 上才能把檔案移到資源回收筒。
error-files-tool-off = 請先在「設定 › 工具」中開啟「檔案」：團隊要用它讀寫任務的資料夾。

## Pictures, replies and voices

error-picture-words-missing = 請先說明圖片的內容。
error-picture-words-too-long = 圖片內容的說明超過 { $most } 個字元。
error-picture-needs-words = 請說明圖片的內容。
error-goal-missing = 請說明團隊要做什麼。
error-dictation-not-set-up = 尚未設定聽寫：設定 › 模型 › 聽寫。
error-direction-without-go-on = 提示只在「繼續」時有效。
error-again-or-go-on = 回覆只能重新撰寫或繼續，不能兩者都要。
error-again-not-reply = 只有角色的回覆才能重新撰寫。
error-no-reply-to-write-again = 這個聊天沒有可以重新撰寫的回覆。
error-no-text = AI 沒有傳回文字。請再試一次。
error-worker-no-answer = 輔助模型沒有回應。
error-unknown-voice = 沒有語音「{ $voice }」。
error-nothing-to-read = 沒有可朗讀的內容。
error-voice-not-downloaded = 尚未下載這個語音。
error-voice-failed = 朗讀失敗，請再試一次。
error-stopping = Cardwave 正在停止。
error-download-failed = 下載失敗。請檢查連線後再試一次。
error-search-model-failed = 搜尋模型失敗。Cardwave 稍後會再試一次。
error-models-not-listed = 無法列出供應商的模型。請檢查位址和金鑰，然後再試一次。
error-file-not-imported = 無法讀取這個檔案：Cardwave 不認得它的格式。
error-describing-failed = 輔助模型無法描述這個角色。

## The kinds an area's failures are grouped by: each picks its words by `what` (or `whose`), the thing it is about

error-needed = { $what ->
    [persona_name] 使用者角色需要名字。
    [account_name] 帳號需要名字。
    [card_title] 角色需要一個標題。
    [character_name] 角色需要名字。
    [chat_character] 聊天需要角色。
    [chat_title] 聊天標題不能空白。
    [entry_name] 條目需要名稱。
    [expression_files] 請選擇一個 zip 檔（打包的資料夾）或一組表情的圖片。
    [language] 缺少語言。
    [lorebook_name] 世界書需要名稱。
    [memory_text] 記憶需要文字。
    [message_to_improve] 沒有可以潤飾的訊息。
    [model_name] 必須指定模型名稱。
    [models_folder] 請先選擇模型資料夾。
    [password] 密碼不能空白。
    [preset_name] 預設集需要名稱。
    [rewrite_given] 缺少必要的內容。請再試一次。
    [summary] 摘要不能空白。
    [text_to_change] 沒有可以修改的文字。
    [text_to_read] 沒有可朗讀的內容。
    [voice_name] 語音需要名字。
   *[other] 缺少必要的內容。請再試一次。
}
error-too-long = { $what ->
    [account_name] 帳號名稱最多 { $name_limit } 個字元。
    [chat_title] 聊天標題最多 { $title_limit } 個字元。
    [document] { $name } 太長了：文件最多 2,000,000 個字元。
    [entry_name] 條目名稱最多 { $max_name } 個字元。
    [field_name] 欄位名稱為 1 到 { $max_field } 個字元。
    [lorebook_name] 世界書名稱最多 { $max_name } 個字元。
    [memory_text] 記憶最多 { $text_limit } 個字元。
    [persona_name] 使用者角色的名字最多 { $max_name } 個字。
    [provider_name] 名稱最多 { $name_limit } 個字元。
    [unsaved_text] 未儲存的文字最多保留 { $max_text } 個字元。
    [voice_name] 語音名稱最多 { $name_most } 個字元。
   *[other] 超過 { $most } 個字元。
}
error-out-of-range = { $what ->
    [authors_note_depth] 註記至少要放在往前一則訊息的位置。
    [companion_size] 桌面夥伴的大小為螢幕高度的 { $start }% 到 { $end }%。
    [context_size] 上下文大小至少要 512 個 token。
    [entry_chance] 條目的機率最多 100%。
    [provider_setting] { $name } 必須在 { $min } 到 { $max } 之間。
    [reply_length] 回覆長度必須在 1 到 { $most_reply_length } 個 token 之間。
    [slider] 滑桿的範圍是 0 到 100。
    [talk_pause] 停頓必須在 0 到 { $most_talk_pause } 秒之間。
    [talk_replies] 連續回覆次數必須在 1 到 { $most_talk_replies } 之間。
    [talkativeness] 健談程度在 0 到 100 之間。
    [voice_speed] 速度在 { $start }% 到 { $end }% 之間。
   *[other] 必須在 { $least } 到 { $most } 之間。
}
error-taken = { $what ->
    [card_in_library] 已經在你的資料庫中。
    [account_name] 已有其他帳號叫「{ $name }」。
    [card_language] 這張角色卡已經是以{ $name }撰寫的。
    [chat_character] { $name } 已經在這個聊天中。
    [chat_character_twice] { $name } 在這個聊天中出現了兩次。
    [lorebook_same_name] 這張角色卡現在已有同名的世界書或條目。
    [model_file] { $name } 已經在資料夾中。
    [preset_name] 已有其他預設集叫「{ $name }」。
    [tool_name] 已有名為 { $name } 的工具；請換一個名稱。
   *[other] 這已經存在了。
}
error-in-trash = { $what ->
    [card] 這個角色在垃圾桶中，請先還原。
    [card_to_chat] 角色在垃圾桶裡；還原角色後才能再聊天。
    [chat] 這個聊天在垃圾桶中，請先還原。
    [chat_card] 它的角色「{ $title }」在垃圾桶中，請先還原這個角色。
    [lorebook] 世界書「{ $name }」在垃圾桶中，請先還原。
    [lorebook_to_use] 世界書「{ $name }」在垃圾桶中，請還原後再使用。
    [persona_default] 垃圾桶中的使用者角色不能設為預設，請先還原。
    [persona_to_use] 使用者角色「{ $name }」在垃圾桶中，請還原後再使用。
   *[other] 這在垃圾桶中，請先還原。
}
error-not-readable = { $what ->
    [damaged_key] 它的金鑰已損壞。
    [json] 這個檔案不是有效的 JSON。
    [lorebook] 這個檔案沒有世界書。
    [lorebook_not_card] 這個檔案是角色卡，不是世界書。
    [account_picture] 這張圖片不是可讀取、每邊最多 4,096 像素的 PNG 或 JPEG。
    [attachment_picture] 圖片必須是 PNG、JPEG 或 WebP 檔案。
    [backup] 這個檔案不是 Cardwave 的備份。
    [backup_damaged] 這個備份已損壞。
    [backup_newer] 這個備份由較新版本的 Cardwave 製作。請更新 Cardwave 後再還原。
    [backup_key] 這個備份已損壞：無法讀取它的金鑰。
    [base64] 這不是 base64。
    [base64_file] { $name } 不是 base64。
    [card_defined_twice] 這個檔案不是 Cardwave 能讀取的角色卡。請從它原本的應用程式重新匯出。
    [card_file_name] 角色卡中有無法使用的檔案名稱。
    [card_reference] 這沒有指向角色卡的任何部分。
    [ccv4_version] 這張卡由較新版本的 Cardwave 製作。請更新 Cardwave 後再開啟。
    [comfyui_address] 無法讀取 ComfyUI 的位址。
    [comfyui_answer] 無法讀取 ComfyUI 的回應。
    [dictation_recording] 無法讀取錄音。請重新錄製。
    [document_text] { $name } 沒有可讀取的文字。
    [document_type] 文件必須是 .txt、.md、.pdf 或 .docx 檔案。
    [downloaded_model] 下載的檔案不是這個模型。
    [expression_pack] 沒有一張圖片以情緒的英文名命名，如 joy.png 或 anger.png（PNG、JPEG、WebP 或 GIF）。
    [figure_file] { $file_name } 不是這種檔案。
    [figure_still] 3D 形象的靜態圖不是 4 MB 以內的 PNG。
    [figure_type] 3D 形象必須是 VRM、GLB 或 FBX 檔案。
    [folder_read] 無法讀取這個資料夾。
    [format_version] 這個檔案不是 Cardwave 能讀取的角色卡。請從它原本的應用程式重新匯出。
    [image_model_answer] 無法讀取圖像模型的回應。
    [image_model_picture] 無法讀取圖像模型產生的圖片。
    [key_characters] 金鑰中含有金鑰不能有的字元。請從服務商網站重新複製。
    [lorebook_empty] 世界書是空的。
    [lorebook_entries] 世界書沒有條目。
    [lorebook_file] 無法讀取世界書。
    [lorebook_named] 無法讀取世界書「{ $name }」。
    [lorebook_named_empty] 世界書「{ $name }」是空的。
    [models_dev_list] 無法讀取模型清單。
    [models_list_answer] 這個位址有回應，但回應的不是模型清單。
    [models_list_missing] 沒有收到模型清單。
    [name_characters] 名稱含有名稱不能有的字元。
    [no_lorebook] 這不是世界書。
    [pdf] 無法讀取這個 PDF。
    [picture] 這張圖片不是 PNG、JPEG 或 WebP。
    [picture_server_answer] 無法讀取圖片伺服器的回應。
    [picture_unreadable] 無法讀取這張圖片。
    [png] 不是 PNG 檔案。
    [no_card] 此檔案不含角色卡。
    [png_damaged] 這個 PNG 已損壞。
    [charx] Cardwave 暫不能匯入 CHARX 角色卡檔案。請將角色卡匯出為 PNG 或 JSON。
    [provider_address] 位址必須是單純的網址，例如 https://api.openai.com/v1。
    [provider_website] 請以名稱的形式填寫供應商的網站，例如 example.com。
    [recording_format] 無法讀取錄音的格式。
    [recording_pcm] 無法讀取錄音。請重新錄製。
    [recording_rate] 無法讀取錄音的取樣率。
    [recording_short] 錄音太短：至少需要 { $shortest } 秒。
    [recording_silent] 錄音沒有聲音。
    [recording_wav] 錄音不是 WAV 檔案。
    [sillytavern_base64] 這個檔案不是 Cardwave 能讀取的角色卡。請從它原本的應用程式重新匯出。
    [sillytavern_empty] 角色卡是空的。
    [sillytavern_file] 無法讀取這個檔案中的 SillyTavern 角色卡。
    [sillytavern_json] 這個檔案不是 Cardwave 能讀取的角色卡。請從它原本的應用程式重新匯出。
    [sillytavern_object] 這個檔案不是 Cardwave 能讀取的角色卡。請從它原本的應用程式重新匯出。
    [sillytavern_png] 無法讀取這個 PNG 中的 SillyTavern 角色卡。
    [spec_version] 這個檔案不是 Cardwave 能讀取的角色卡。請從它原本的應用程式重新匯出。
    [spec_version_form] 這個檔案不是 Cardwave 能讀取的角色卡。請從它原本的應用程式重新匯出。
    [toml] 這個檔案不是 Cardwave 能讀取的角色卡。請從它原本的應用程式重新匯出。
    [word_file] 無法讀取這個 Word 檔案。
    [word_text] 這個 Word 檔案沒有文字。
    [workflow] 無法讀取工作流程「{ $name }」。
    [workflow_api_form] 這個工作流程是以 API 格式儲存的：請在 ComfyUI 中把它儲存為工作流程。
    [workflow_broken] 無法讀取這個工作流程。
    [workflow_fields] 工作流程的節點「{ $kind }」有 Cardwave 無法讀取的欄位。
    [workflow_no_node] 工作流程中沒有這個 ComfyUI 能執行的節點。
    [workflow_node] 工作流程的節點「{ $class }」不是這個 ComfyUI 擁有的節點。
    [zip] 無法把 { $name } 當作 zip 讀取。
   *[other] 無法讀取。
}
error-too-big = { $what ->
    [card_for_worker] 角色太長，輔助模型讀不完；請選擇能讀取更多內容的輔助模型。
    [card_file] 檔案大於 { $most } MB。
    [checkpoint_folder] 資料夾太大，無法在每一步之前保留副本。
    [expression_pack_size] { $name } 的圖片太大。
    [expression_zip_files] { $name } 含有超過 { $max_entries } 個檔案。
    [figure] 這個 3D 形象太大。
    [model_for_computer] { $name } 對這台電腦來說太大。
    [models_dev_list] 模型清單太長。
    [picture_pixels] 圖片太大（{ $wide } × { $high } 像素）。
    [reply] 回覆被截斷了：內容太長。
   *[other] 這太大了。
}
error-not-now = { $what ->
    [character_has_written] { $name } 已經在這個聊天中發言，會留在聊天中。
    [coding_folder_busy] 這個資料夾中有另一個程式設計任務正在執行；請等它完成，或停止它。
    [database_busy] Cardwave 正忙；請再試一次。
    [download_cancelling] 正在取消它的下載，請稍後再試。
    [held_by_card] 有角色正在使用它；請先將它從角色移除。
    [lorebook_used_elsewhere] 這本世界書現在也用在其他地方，所以會留在資料庫中。
    [model_downloading] 正在下載這個模型。
    [model_replying] 模型正在回覆；等回覆結束後再刪除它。
    [search_model_not_downloaded] 尚未下載搜尋模型。
    [task_running] 任務還在執行，請先停止。
   *[other] 現在無法這麼做。請稍後再試。
}
error-changed = { $what ->
    [lorebook_entry] 世界書現在已有另一個條目。
    [card_version] 角色卡在這段期間已被修改，正在重新讀取。
    [tool_name] 現在已有另一個工具名為 { $name }。
    [two_ways] { $reference } 同時被修改了兩次；請再試一次。
    [workflow] 工作流程「{ $name }」已在 ComfyUI 中修改：請在「設定 › 供應商」中重新選擇。
   *[other] 這在這段期間已被修改，請再試一次。
}
error-not-possible = { $what ->
    [back_to_computer] 只有搜尋和語音能改回這台電腦。
    [card_about_itself] 角色卡對自身的描述不能修改。
    [card_change] 這張角色卡中的這項內容不能修改。
    [card_character] 角色卡中沒有這個角色。
    [card_character_change] 角色卡的角色不能修改。
    [card_language_beside] 角色卡不能在第一語言之外再加上{ $name }。
    [card_lorebook] 角色卡沒有附帶這本世界書。
    [card_lorebook_attached] 角色卡沒有附加這本世界書。
    [card_mode] 角色卡沒有這種模式。
    [card_no_character] 角色卡沒有角色。
    [card_not_changed] 角色卡沒有被修改。
    [card_part] 這不是角色卡中可以修改的部分。
    [card_takes_no] 這張角色卡不接受這類新內容。
    [card_takes_no_lorebook] 這張角色卡不接受世界書。
    [character_change] 這張角色卡中的該角色不能修改。
    [chat_character] 聊天中沒有這個角色。
    [chat_lore] 聊天中沒有這本世界書或這個世界書條目。
    [chat_lorebook] 聊天中沒有這本世界書。
    [chat_mode] 聊天沒有這種模式。
    [chat_no_character] 聊天沒有角色。
    [chat_without_character] 沒有角色的聊天中沒有任何角色。
    [chat_without_character_add] 沒有角色的聊天不能加入角色。
    [checkpoint_put_back] 無法還原 { $path }。
    [comfyui_no_picture] ComfyUI 沒有產生圖片。
    [companion_not_answering] 桌面夥伴沒有回應。
    [companion_not_shown] 桌面夥伴目前沒有顯示。
    [comfyui_queue] ComfyUI 沒有把這張圖片排入佇列。
    [comfyui_said] ComfyUI 回應：{ $said }
    [continue_no_text] 這則回覆沒有可以繼續的文字。
    [continue_only_reply] 只有角色的回覆才能繼續。
    [depth_note] 無法加入指定深度的註記。
    [dictation_failed] 聽寫模型失敗。
    [dictation_model_load] 無法載入聽寫模型。
    [dictation_model_start] 無法啟動聽寫模型。
    [draft_made_by] 草稿不是由「{ $made }」產生的。
    [edit_breaks_card] 這樣修改後，角色卡將無法讀取。
    [entry_change] 這本世界書中的條目無法照要求修改。
    [entry_taken_out] 這不是被取出的世界書條目。
    [export_no_character] 角色卡沒有可以匯出的角色。
    [greeting] 這不是該角色的開場白。
    [improve_direction] 潤飾只用輸入框裡的文字，不接受提示。
    [key_refused] 金鑰被拒絕。
    [llama_server_start] 無法啟動搜尋模型。請重新啟動 Cardwave 後再試一次。
    [local_address] 這台電腦上的模型是依資料夾找到的，請到「設定 › 供應商」。
    [lorebook_change] 這本世界書不能修改。
    [lorebook_change_breaks] 這樣修改後，世界書將無法讀取。
    [lorebook_new_entry] 這本世界書不接受新條目。
    [lorebook_put_in] 無法把這本世界書放入這張角色卡。
    [lorebook_take_out] 無法把這本世界書從這張角色卡中取出。
    [message_not_in_chat] 這則訊息不屬於這個聊天。
    [message_not_in_view] 這則訊息不在目前的檢視中。
    [model_remove] 無法移除 { $path }。
    [no_folder] 這台電腦上沒有這個資料夾。
    [no_image_model] 還沒有設定圖像模型：請在「設定 › 模型 › 圖片」中設定。
    [no_local_model] 那個資料夾中沒有模型「{ $id }」。
    [no_local_models] 尚未設定本機模型。
    [no_recycle_bin] { $path } 沒有 Windows 資源回收筒。
    [no_summary] 角色卡還沒有摘要。
    [no_voice] 沒有這個語音。
    [no_vulkan] 這台電腦的顯示卡無法執行模型。請改用服務商。
    [no_vulkan_dictation] 這台電腦的顯示卡無法執行聽寫。
    [prompt_change] 這張角色卡中該角色的提示詞不能修改。
    [recycle_bin_move] { $path } 沒有移到 Windows 資源回收筒。
    [speaker_not_in_chat] 發言者不屬於這個聊天。
    [speaker_only_character] 只有角色的訊息才有發言者。
    [unknown_language] 這不是這個應用程式認得的語言。
    [version_lacks_character] 有一個聊天的角色在最新版本中已不存在。
    [voice_runtime] 朗讀缺少一個 Microsoft 元件：請從 microsoft.com 安裝 Visual C++ Redistributable，然後重新啟動 Cardwave。
    [workflow_no_text] 工作流程「{ $name }」沒有放圖片文字的文字欄位。
    [workflow_use] 無法使用工作流程「{ $name }」。
    [written_tools_full] 最多只能保留 { $most_tools } 個工具；請先在「設定 › AI 寫的工具」中刪除一個。
    [delete_not_in_trash] 只有垃圾桶中的項目才能永久刪除；請先移到垃圾桶。
   *[other] 無法這麼做。
}
error-model-answer = { $what ->
    [no_greeting] AI 沒有寫出開場白。
    [background_answer] 無法使用輔助模型的回答。請再試一次，或換一個輔助模型。
    [background_text] 無法使用輔助模型的回答。請再試一次，或換一個輔助模型。
    [card_texts] AI 的回應不是角色的文字。
    [classification] 無法使用輔助模型的回答。請再試一次，或換一個輔助模型。
    [example_messages] AI 沒有寫出範例訊息。
    [no_example_message] AI 寫出的範例訊息沒有文字。
    [json] AI 的回應不是所要求的格式。
    [keywords] 無法使用輔助模型的回答。請再試一次，或換一個輔助模型。
    [logline] 無法使用輔助模型的回答。請再試一次，或換一個輔助模型。
    [no_chat_reply] AI 的供應商沒有傳回聊天回覆。
    [no_fitting_answer] AI 試了三次都沒有給出可用的回應。
    [no_picture] 圖像模型的回應中沒有圖片。
    [no_plan] 規劃者沒有擬出計畫。
    [no_text] AI 沒有傳回文字。
    [picture_address] 圖像模型的圖片位於不會被擷取的位址。
    [picture_art] 無法產生圖片；請再試一次。
    [picture_field] 輔助模型找不到放圖片文字的欄位。
    [picture_server_no_picture] 圖片伺服器的回應中沒有圖片。
    [picture_words] 輔助模型沒有為圖片寫出文字。
    [rating] 無法使用輔助模型的回答。請再試一次，或換一個輔助模型。
    [reply_broke_off] 回覆中斷了。
    [needs] 無法使用輔助模型的回答。請再試一次，或換一個輔助模型。
    [rounds] 團隊在 { $rounds } 輪內沒有完成工作。
    [search_left_out] 搜尋模型漏掉了一段文字。
    [search_model] 無法讀取搜尋模型的回應。
    [search_tokens] 無法讀取搜尋模型的 token。
    [title] 無法使用輔助模型的回答。請再試一次，或換一個輔助模型。
    [too_many_tools] AI 呼叫了太多工具。
    [worker_mode] 無法使用輔助模型的回答。請再試一次，或換一個輔助模型。
    [worker_texts] 無法使用輔助模型的回答。請再試一次，或換一個輔助模型。
    [server_reported] AI 的供應商回報：{ $reason }
   *[other] 無法使用 AI 的回應。
}
error-timed-out = { $whose ->
    [comfyui] ComfyUI 沒有及時產生圖片。
    [llama_server] 搜尋模型沒有及時準備好。請再試一次。
    [model] AI 沒有及時回應。請再試一次。
    [model_server] AI 的供應商沒有及時回應。請再試一次。
    [search_model] 搜尋模型沒有及時回應。
   *[other] 沒有及時回應。
}
error-unreachable = { $whose ->
    [comfyui] 無法連線到 ComfyUI。
    [image_model] 無法連線到圖像模型。
    [model_download] 無法下載模型的檔案。
    [model_server] AI 的供應商沒有回應：請稍後再試，或檢查網路連線。
    [picture_address] 無法擷取這張圖片。
    [picture_server] 無法連線到圖片伺服器。
    [provider_voices] 無法連線到供應商的語音。
    [search_model] 搜尋模型沒有回應。
    [provider_voice] 無法連線到供應商的語音。
    [provider_search_model] 無法連線到供應商的搜尋模型。
   *[other] 無法連線。
}
error-answered = { $whose ->
    [comfyui] ComfyUI 回應 { $status }。
    [model_server] AI 的供應商回傳了 { $status }。請稍後再試。
    [picture_server] 圖片伺服器回應 { $status }。
    [provider_voices] 供應商的語音服務回應 { $status }。
    [search_model] 搜尋模型回應 { $status }。
   *[other] 回應 { $status }。
}
