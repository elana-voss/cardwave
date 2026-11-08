### 界面文字的简体中文版：服务器的错误回答，api/generated/Code.ts 的每个代码一条（errors.ts），
### 键为 `error-<code>`，“_”换成“-”；术语表见 zh-Hans.ftl 的开头。

## The request, as the server took it

error-request-failed = 无法完成这个操作。请再试一次。
error-internal = Cardwave 出了点问题。请再试一次。
error-bad-request = Cardwave 无法读取这个请求。请重新加载页面后再试一次。
error-forbidden = 不允许这样做。
error-no-such-path = Cardwave 没有这个页面。请重新加载页面后再试一次。
error-method-not-allowed = Cardwave 在这里不支持这个操作。请重新加载页面后再试一次。
error-too-large = 太大了。请换一个小一些的文件。
error-unsupported-type = Cardwave 在这里不接受这种文件。

## Passwords and accounts

error-locked = Cardwave 已锁定，输入密码后才能使用。
error-sign-in = 请先登录。
error-password-wrong = 密码错误。
error-password-needed = 需要输入密码。
error-current-password-needed = 需要输入当前密码。
error-backup-password-needed = 这个备份需要它的密码。
error-too-many-tries = 密码错误次数太多。请在 { $seconds } 秒后再试。
error-owner-only = 只有这台电脑上的账户才能{ $action ->
    [use_its_files] 使用这台电脑的文件
    [use_its_folders] 使用这台电脑的文件夹
    [choose_its_models] 选择这台电脑的模型
    [lock_Cardwave] 锁定 Cardwave
   *[other] 这样做
}。
error-no-password-to-lock = 只有设置了密码，Cardwave 才能锁定。
error-remote-sign-in-off = 这个账户不能从其他设备登录。请在“账户 › 共享”中开启。
error-no-password-on = 没有开启密码。
error-no-password-set = 这个账户没有设置密码。
error-password-kept = 这台电脑上有账户设置了密码：它用这个密码登录。
error-account-busy = Cardwave 还在为此账户工作：回复、图片、编程任务、新角色、读取角色或聊天的记忆；请等它完成后再试。
error-restore-busy = Cardwave 还在工作：回复、图片、编程任务、新角色、读取角色或聊天的记忆；请等它完成后再试。
error-backup-needs-password = 备份需要设置密码。

## What is asked of

error-not-found = 没有这个{ $what ->
    [account] 账户
    [asset] 角色卡中的文件
    [attachment] 附件
    [card] 角色卡
    [card_version] 角色卡版本
    [chat] 聊天
    [chat_character] 聊天中的角色
    [checkpoint] 检查点
    [deleted_message] 已删除的消息
    [document] 文档
    [expression] 表情
    [expression_pack] 表情组
    [figure] 3D 形象
    [kind_of_model] 模型类型
    [language] 语言
    [lorebook] 世界书
    [lorebook_entry] 世界书条目
    [memory] 记忆
    [message] 消息
    [model] 模型
    [persona] 人设
    [picture] 图片
    [preset] 预设
    [prompt_preset] 提示词预设
    [provider] 服务商
    [question] 问题
    [task] 任务
    [tool] 工具
    [user] 账户
    [voice] 语音
   *[other] 东西
}。它可能已被删除。
error-chat-busy = 这个聊天正在撰写回复；请先停止它。
error-no-provider = { $what ->
    [chat_model] 还没有选择聊天模型。请在 设置 › 模型 中选择一个。
   *[other] 还没有设置服务商。请在“设置 › 服务商”中添加一个。
}
error-provider-refused = { $refusal ->
    [key] 服务商没有接受这个密钥：请在“设置 › 服务商”中检查。
    [paid] 服务商要求为此付费：请充值，或选择你的套餐包含的模型。
    [busy] 服务商的额度用完了或正忙：请稍后再试。
    [down] 服务商没有响应：请稍后再试。
    [fault] 服务商那边出了故障：{ $reason } 请稍后再试。
    [no_model] 服务商已不再提供这个模型：请在 设置 › 模型 中另选一个。
    [too_long] 发给模型的内容超过了它一次能读的量：请在 设置 › 模型 中选一个能读更多内容的模型。
   *[other] 服务商拒绝了：{ $reason }
}
error-model-declined = { $model } 拒绝写这个内容。请修改消息，或换一个模型。
error-model-sees-no-pictures = { $model } 看不到图片，所以不接收图片。要发送图片，请选择能看图片的模型。
error-card-trashed = 这个角色在废纸篓中；请先恢复它。
error-lorebook-trashed = 世界书“{ $name }”在废纸篓中；恢复后才能使用。
error-own-lorebook-flags = 角色自己的世界书随角色一起：不能单独加星标、归档、移到废纸篓或用于每个聊天。

## Folders and files

error-no-such-folder = 这台电脑上没有文件夹 { $folder }。
error-folder-not-chosen = 请先选择文件夹。
error-drive-root-to-watch = 磁盘的根目录内容太多，无法监视；请选择其中的一个文件夹。
error-drive-root-for-model = 驱动器的根目录内容太多，无法交给 AI；请选择其中的一个文件夹。
error-data-folder = 这个文件夹存放着 Cardwave 自己的数据，或者位于其中；请选择其他文件夹。
error-commands-windows-only = 只有在 Windows 上才能运行命令。
error-recycle-bin-windows-only = 只有在 Windows 上才能把文件移到 Windows 回收站。
error-files-tool-off = 请先在“设置 › 工具”中开启“文件”：团队用它读写任务的文件夹。

## Pictures, replies and voices

error-picture-words-missing = 请先说明图片里画的是什么。
error-picture-words-too-long = 图片内容的描述超过了 { $most } 个字符。
error-picture-needs-words = 请说明图片里画的是什么。
error-goal-missing = 请说明团队要做什么。
error-dictation-not-set-up = 语音输入还没有设置：设置 › 模型 › 语音输入。
error-direction-without-go-on = 提示只在“继续”时有效。
error-again-or-go-on = 回复只能重新生成或继续，不能同时进行。
error-again-not-reply = 只有角色的回复才能重新生成。
error-no-reply-to-write-again = 这个聊天中没有可以重新生成的回复。
error-no-text = AI 没有发来文字。请再试一次。
error-worker-no-answer = 辅助模型没有回答。
error-unknown-voice = 没有语音“{ $voice }”。
error-nothing-to-read = 没有可朗读的内容。
error-voice-not-downloaded = 这个语音还没有下载。
error-voice-failed = 朗读失败。请再试一次。
error-stopping = Cardwave 正在停止。
error-download-failed = 下载失败。请检查网络连接后再试。
error-search-model-failed = 搜索模型出错了。Cardwave 稍后会再试。
error-models-not-listed = 无法列出服务商的模型。请检查地址和密钥，然后再试一次。
error-file-not-imported = 无法读取该文件：Cardwave 不认识它的格式。
error-describing-failed = 辅助模型无法描述这个角色。

## The kinds an area's failures are grouped by: each picks its words by `what` (or `whose`), the thing it is about

error-needed = { $what ->
    [persona_name] 人设需要一个名字。
    [account_name] 账户需要一个名字。
    [card_title] 角色需要一个标题。
    [character_name] 角色需要一个名字。
    [chat_character] 聊天需要一个角色。
    [chat_title] 聊天标题不能为空。
    [entry_name] 条目需要一个名字。
    [expression_files] 请选择一个 zip 文件（打包的文件夹）或一组表情的图片。
    [language] 缺少语言。
    [lorebook_name] 世界书需要一个名字。
    [memory_text] 记忆需要内容。
    [message_to_improve] 没有可以润色的消息。
    [model_name] 必须写出模型的名字。
    [models_folder] 请先选择存放模型的文件夹。
    [password] 密码不能为空。
    [preset_name] 预设需要一个名字。
    [rewrite_given] 缺少必要的内容。请再试一次。
    [summary] 摘要不能为空。
    [text_to_change] 没有要修改的文字。
    [text_to_read] 没有可朗读的内容。
    [voice_name] 语音需要一个名字。
   *[other] 缺少必要的内容。请再试一次。
}
error-too-long = { $what ->
    [account_name] 账户名最多 { $name_limit } 个字符。
    [chat_title] 聊天标题最多 { $title_limit } 个字符。
    [document] { $name } 太长了：文档最多 2,000,000 个字符。
    [entry_name] 条目名最多 { $max_name } 个字符。
    [field_name] 字段名为 1 到 { $max_field } 个字符。
    [lorebook_name] 世界书的名字最多 { $max_name } 个字符。
    [memory_text] 记忆最多 { $text_limit } 个字符。
    [persona_name] 人设的名字最多 { $max_name } 个字符。
    [provider_name] 名字最多 { $name_limit } 个字符。
    [unsaved_text] 未保存的文字最多保留 { $max_text } 个字符。
    [voice_name] 语音的名字最多 { $name_most } 个字符。
   *[other] 超过了 { $most } 个字符。
}
error-out-of-range = { $what ->
    [authors_note_depth] 注释至少要放在往前一条消息的位置。
    [companion_size] 桌面伙伴的大小为屏幕高度的 { $start }% 到 { $end }%。
    [context_size] 上下文长度至少要 512 个 token。
    [entry_chance] 条目的触发概率最多为 100%。
    [provider_setting] { $name } 必须在 { $min } 到 { $max } 之间。
    [reply_length] 回复长度必须在 1 到 { $most_reply_length } 个 token 之间。
    [slider] 滑块的范围是 0 到 100。
    [talk_pause] 间隔必须在 0 到 { $most_talk_pause } 秒之间。
    [talk_replies] 连续回复次数必须在 1 到 { $most_talk_replies } 之间。
    [talkativeness] 健谈程度在 0 到 100 之间。
    [voice_speed] 速度在 { $start }% 到 { $end }% 之间。
   *[other] 应在 { $least } 到 { $most } 之间。
}
error-taken = { $what ->
    [card_in_library] 已经在你的资料库中了。
    [account_name] 已经有一个账户叫“{ $name }”。
    [card_language] 这张角色卡已经有{ $name }版本了。
    [chat_character] { $name } 已经在这个聊天中了。
    [chat_character_twice] { $name } 在这个聊天中出现了两次。
    [lorebook_same_name] 这张角色卡现在已经有同名的世界书或条目。
    [model_file] { $name } 已经在这个文件夹中了。
    [preset_name] 已经有一个预设叫“{ $name }”。
    [tool_name] 已经有名为 { $name } 的工具；请换个名字。
   *[other] 已经存在了。
}
error-in-trash = { $what ->
    [card] 这个角色在废纸篓中；请先恢复它。
    [card_to_chat] 角色在废纸篓里；恢复角色后才能再聊天。
    [chat] 这个聊天在废纸篓中；请先恢复它。
    [chat_card] 它的角色“{ $title }”在废纸篓中；请先恢复这个角色。
    [lorebook] 世界书“{ $name }”在废纸篓中；请先恢复它。
    [lorebook_to_use] 世界书“{ $name }”在废纸篓中；恢复后才能使用。
    [persona_default] 废纸篓中的人设不能设为默认；请先恢复它。
    [persona_to_use] 人设“{ $name }”在废纸篓中；恢复后才能使用。
   *[other] 它在废纸篓中；请先恢复它。
}
error-not-readable = { $what ->
    [damaged_key] 它的密钥已损坏。
    [json] 这个文件不是有效的 JSON。
    [lorebook] 这个文件里没有世界书。
    [lorebook_not_card] 这个文件是角色卡，不是世界书。
    [account_picture] 这张图片不是可读取的、每边最多 4,096 像素的 PNG 或 JPEG。
    [attachment_picture] 图片须为 PNG、JPEG 或 WebP 文件。
    [backup] 这个文件不是 Cardwave 备份。
    [backup_damaged] 这个备份已损坏。
    [backup_newer] 这个备份由更新版本的 Cardwave 制作。请更新 Cardwave 后再恢复。
    [backup_key] 这个备份已损坏：无法读取它的密钥。
    [base64] 这不是 base64。
    [base64_file] { $name } 不是 base64。
    [card_defined_twice] 这个文件不是 Cardwave 能读取的角色卡。请从它原来的应用重新导出。
    [card_file_name] 角色卡中的某个文件名无法使用。
    [card_reference] 这没有指向角色卡的任何部分。
    [ccv4_version] 这张卡由更新版本的 Cardwave 制作。请更新 Cardwave 后再打开。
    [comfyui_address] 无法读取 ComfyUI 的地址。
    [comfyui_answer] 无法读取 ComfyUI 的回答。
    [dictation_recording] 无法读取录音。请重新录制。
    [document_text] { $name } 中没有可读取的文字。
    [document_type] 文档须为 .txt、.md、.pdf 或 .docx 文件。
    [downloaded_model] 下载的文件不是这个模型。
    [expression_pack] 没有一张图片以情绪的英文名命名，如 joy.png 或 anger.png（PNG、JPEG、WebP 或 GIF）。
    [figure_file] { $file_name } 不是这种文件。
    [figure_still] 3D 形象的静态图不是 4 MB 以内的 PNG。
    [figure_type] 3D 形象须为 VRM、GLB 或 FBX 文件。
    [folder_read] 无法读取这个文件夹。
    [format_version] 这个文件不是 Cardwave 能读取的角色卡。请从它原来的应用重新导出。
    [image_model_answer] 无法读取图像模型的回答。
    [image_model_picture] 无法读取图像模型的图片。
    [key_characters] 密钥中含有密钥不能有的字符。请从服务商网站重新复制。
    [lorebook_empty] 这本世界书是空的。
    [lorebook_entries] 这本世界书没有条目。
    [lorebook_file] 无法读取这本世界书。
    [lorebook_named] 无法读取世界书“{ $name }”。
    [lorebook_named_empty] 世界书“{ $name }”是空的。
    [models_dev_list] 无法读取模型列表。
    [models_list_answer] 这个地址有回应，但回应的不是模型列表。
    [models_list_missing] 没有收到模型列表。
    [name_characters] 名字中含有名字不能有的字符。
    [no_lorebook] 这不是世界书。
    [pdf] 无法读取这个 PDF。
    [picture] 这张图片不是 PNG、JPEG 或 WebP。
    [picture_server_answer] 无法读取图片服务器的回答。
    [picture_unreadable] 无法读取这张图片。
    [png] 不是 PNG 文件。
    [no_card] 此文件不含角色卡。
    [png_damaged] 这个 PNG 已损坏。
    [charx] Cardwave 暂不能导入 CHARX 角色卡文件。请将角色卡导出为 PNG 或 JSON。
    [provider_address] 地址必须是普通的网址，比如 https://api.openai.com/v1。
    [provider_website] 请以域名的形式填写服务商的网站，比如 example.com。
    [recording_format] 无法读取录音的格式。
    [recording_pcm] 无法读取录音。请重新录制。
    [recording_rate] 无法读取录音的采样率。
    [recording_short] 录音太短：至少需要 { $shortest } 秒。
    [recording_silent] 这段录音没有声音。
    [recording_wav] 这段录音不是 WAV 文件。
    [sillytavern_base64] 这个文件不是 Cardwave 能读取的角色卡。请从它原来的应用重新导出。
    [sillytavern_empty] 这张角色卡是空的。
    [sillytavern_file] 无法读取这个文件中的 SillyTavern 角色卡。
    [sillytavern_json] 这个文件不是 Cardwave 能读取的角色卡。请从它原来的应用重新导出。
    [sillytavern_object] 这个文件不是 Cardwave 能读取的角色卡。请从它原来的应用重新导出。
    [sillytavern_png] 无法读取这个 PNG 中的 SillyTavern 角色卡。
    [spec_version] 这个文件不是 Cardwave 能读取的角色卡。请从它原来的应用重新导出。
    [spec_version_form] 这个文件不是 Cardwave 能读取的角色卡。请从它原来的应用重新导出。
    [toml] 这个文件不是 Cardwave 能读取的角色卡。请从它原来的应用重新导出。
    [word_file] 无法读取这个 Word 文件。
    [word_text] 这个 Word 文件中没有文字。
    [workflow] 无法读取工作流“{ $name }”。
    [workflow_api_form] 这个工作流是以 API 格式保存的：请在 ComfyUI 中把它另存为工作流。
    [workflow_broken] 无法读取这个工作流。
    [workflow_fields] 工作流的节点“{ $kind }”中有 Cardwave 无法读取的字段。
    [workflow_no_node] 这个工作流中没有这个 ComfyUI 能运行的节点。
    [workflow_node] 工作流的节点“{ $class }”在这个 ComfyUI 中不存在。
    [zip] 无法把 { $name } 当作 zip 读取。
   *[other] 无法读取。
}
error-too-big = { $what ->
    [card_for_worker] 角色太长，辅助模型读不完；请选择能读取更多内容的辅助模型。
    [card_for_chat] 角色太长，聊天模型读不完，角色就不再是自己；请选择能读取更多内容的聊天模型，或缩短角色。
    [card_file] 文件大于 { $most } MB。
    [checkpoint_folder] 文件夹太大，无法在每一步之前保留副本。
    [expression_pack_size] { $name } 的图片太大了。
    [expression_zip_files] { $name } 中的文件超过了 { $max_entries } 个。
    [figure] 这个 3D 形象太大了。
    [model_for_computer] { $name } 对这台电脑来说太大了。
    [models_dev_list] 模型列表太长了。
    [picture_pixels] 这张图片太大了（{ $wide } × { $high } 像素）。
    [reply] 回复被截断了：它太长了。
   *[other] 太大了。
}
error-not-now = { $what ->
    [character_has_written] { $name } 已经在这个聊天中发过言，所以会留在聊天中。
    [coding_folder_busy] 那个文件夹中正在运行另一个编程任务；请等它结束，或者停止它。
    [database_busy] Cardwave 正忙；请再试一次。
    [download_cancelling] 正在取消它的下载；请稍后再试。
    [held_by_card] 有角色在使用它；请先把它从角色中移除。
    [lorebook_used_elsewhere] 这本世界书现在已在别处使用，所以会留在资料库中。
    [model_downloading] 这个模型正在下载。
    [model_replying] 模型正在回复；等回复结束后再删除它。
    [search_model_not_downloaded] 搜索模型还没有下载。
    [task_running] 任务还在运行；请先停止它。
   *[other] 现在无法这样做。请稍后再试。
}
error-changed = { $what ->
    [lorebook_entry] 这本世界书现在已经有了另一个条目。
    [card_version] 角色卡在此期间被修改了；已重新读取。
    [tool_name] 现在已经有另一个工具叫 { $name }。
    [two_ways] { $reference } 同时被修改了两次；请再试一次。
    [workflow] 工作流“{ $name }”已在 ComfyUI 中被修改：请在“设置 › 服务商”中重新选择它。
   *[other] 在此期间已被修改；请再试一次。
}
error-not-possible = { $what ->
    [back_to_computer] 只有搜索和语音可以换回这台电脑。
    [card_about_itself] 角色卡关于自身的信息无法修改。
    [card_change] 这张角色卡中的这一项无法修改。
    [card_character] 这张角色卡中没有这个角色。
    [card_character_change] 无法修改这张角色卡的角色。
    [card_language_beside] 这张角色卡在第一语言之外无法再加入{ $name }。
    [card_lorebook] 这张角色卡没有自带这本世界书。
    [card_lorebook_attached] 这张角色卡没有附加这本世界书。
    [card_mode] 这张角色卡没有这个模式。
    [card_no_character] 这张角色卡里没有角色。
    [card_not_changed] 角色卡没有被修改。
    [card_part] 这不是角色卡中可以修改的部分。
    [card_takes_no] 这张角色卡不接受这类新内容。
    [card_takes_no_lorebook] 这张角色卡不接受世界书。
    [character_change] 这张角色卡中的该角色无法修改。
    [chat_character] 这个聊天中没有这个角色。
    [chat_lore] 这个聊天中没有这本世界书或这个世界书条目。
    [chat_lorebook] 这个聊天中没有这本世界书。
    [chat_mode] 这个聊天没有这个模式。
    [chat_no_character] 这个聊天中没有角色。
    [chat_without_character] 不带角色的聊天没有角色。
    [chat_without_character_add] 不带角色的聊天不能加入角色。
    [checkpoint_put_back] 无法恢复 { $path }。
    [comfyui_no_picture] ComfyUI 没有生成图片。
    [companion_not_answering] 桌面伙伴没有响应。
    [companion_not_shown] 桌面伙伴没有显示。
    [comfyui_queue] ComfyUI 没有把这张图片加入队列。
    [comfyui_said] ComfyUI 说：{ $said }
    [continue_no_text] 这条回复没有可以继续的文字。
    [continue_only_reply] 只有角色的回复才能继续。
    [depth_note] 无法添加指定深度的注释。
    [dictation_failed] 语音输入模型出错了。
    [dictation_model_load] 无法加载语音输入模型。
    [dictation_model_start] 无法启动语音输入模型。
    [draft_made_by] 草稿不是由“{ $made }”生成的。
    [edit_breaks_card] 这样修改后角色卡将无法读取。
    [entry_change] 无法在这本世界书中按要求修改这个条目。
    [entry_taken_out] 这不是被取出的世界书条目。
    [export_no_character] 这张角色卡没有可以导出的角色。
    [greeting] 这不是该角色的开场白。
    [improve_direction] 润色只用输入框里的文字，不接受提示。
    [key_refused] 密钥被拒绝了。
    [llama_server_start] 无法启动搜索模型。请重启 Cardwave 后再试。
    [local_address] 这台电脑上的模型是按文件夹查找的，在“设置 › 服务商”中。
    [lorebook_change] 无法修改这本世界书。
    [lorebook_change_breaks] 这样修改后世界书将无法读取。
    [lorebook_new_entry] 这本世界书不接受新条目。
    [lorebook_put_in] 无法把这本世界书放进这张角色卡。
    [lorebook_take_out] 无法把这本世界书从这张角色卡中取出。
    [message_not_in_chat] 这条消息不属于这个聊天。
    [message_not_in_view] 这条消息不在当前视图中。
    [model_remove] 无法移除 { $path }。
    [no_folder] 这台电脑上没有这个文件夹。
    [no_image_model] 还没有设置图像模型：请在“设置 › 模型 › 图片”中设置。
    [no_local_model] 那个文件夹中没有模型“{ $id }”。
    [no_local_models] 还没有设置本地模型。
    [no_recycle_bin] { $path } 没有 Windows 回收站。
    [no_summary] 这张角色卡还没有摘要。
    [no_voice] 没有这个语音。
    [no_vulkan] 这台电脑的显卡无法运行模型。请改用服务商。
    [no_vulkan_dictation] 这台电脑的显卡无法运行听写。
    [prompt_change] 这张角色卡中该角色的提示词无法修改。
    [recycle_bin_move] { $path } 没有被移到 Windows 回收站。
    [speaker_not_in_chat] 说话者不属于这个聊天。
    [speaker_only_character] 只有角色的消息才有说话者。
    [unknown_language] 这不是这个应用认识的语言。
    [version_lacks_character] 有一个聊天中的角色在最新版本中不存在。
    [voice_runtime] 朗读缺少一个 Microsoft 组件：请从 microsoft.com 安装 Visual C++ Redistributable，然后重新启动 Cardwave。
    [workflow_no_text] 工作流“{ $name }”中没有用于图片描述的文字字段。
    [workflow_use] 无法使用工作流“{ $name }”。
    [written_tools_full] 最多只能保留 { $most_tools } 个工具；请先在“设置 › AI 编写的工具”中删除一个。
    [delete_not_in_trash] 只有废纸篓中的内容才能永久删除；请先把它移到废纸篓。
   *[other] 无法这样做。
}
error-model-answer = { $what ->
    [no_greeting] AI 没有写开场白。
    [background_answer] 无法使用辅助模型的回答。请再试一次，或换一个辅助模型。
    [background_text] 无法使用辅助模型的回答。请再试一次，或换一个辅助模型。
    [card_texts] AI 的回答不是角色的文字。
    [classification] 无法使用辅助模型的回答。请再试一次，或换一个辅助模型。
    [example_messages] AI 没有写示例消息。
    [no_example_message] AI 写了一条没有内容的示例消息。
    [json] AI 的回答不是所要求的格式。
    [keywords] 无法使用辅助模型的回答。请再试一次，或换一个辅助模型。
    [logline] 无法使用辅助模型的回答。请再试一次，或换一个辅助模型。
    [no_chat_reply] AI 的服务商没有发来聊天回复。
    [no_fitting_answer] AI 试了三次都没有给出可用的回答。
    [no_picture] 图像模型的回答中没有图片。
    [no_plan] 规划者没有制定计划。
    [no_text] AI 没有发来文字。
    [picture_address] 图像模型的图片所在的地址不会被获取。
    [picture_art] 无法生成图片；请再试一次。
    [picture_field] 辅助模型没有找到用于图片描述的字段。
    [picture_server_no_picture] 图片服务器的回答中没有图片。
    [picture_words] 辅助模型没有为图片写描述。
    [rating] 无法使用辅助模型的回答。请再试一次，或换一个辅助模型。
    [reply_broke_off] 回复中断了。
    [needs] 无法使用辅助模型的回答。请再试一次，或换一个辅助模型。
    [rounds] 团队在 { $rounds } 轮内没有完成工作。
    [search_left_out] 搜索模型漏掉了一段文字。
    [search_model] 无法读取搜索模型的回答。
    [search_tokens] 无法读取搜索模型的 token。
    [title] 无法使用辅助模型的回答。请再试一次，或换一个辅助模型。
    [too_many_tools] AI 调用的工具太多了。
    [worker_mode] 无法使用辅助模型的回答。请再试一次，或换一个辅助模型。
    [worker_texts] 无法使用辅助模型的回答。请再试一次，或换一个辅助模型。
    [server_reported] AI 的服务商报告：{ $reason }
   *[other] AI 的回答无法使用。
}
error-timed-out = { $whose ->
    [comfyui] ComfyUI 没有及时生成图片。
    [llama_server] 搜索模型没有及时准备好。请再试一次。
    [model] AI 没有及时回答。请再试一次。
    [model_server] AI 的服务商没有及时回答。请再试一次。
    [search_model] 搜索模型没有及时回答。
   *[other] 没有及时回答。
}
error-unreachable = { $whose ->
    [comfyui] 无法连接到 ComfyUI。
    [image_model] 无法连接到图像模型。
    [model_download] 无法下载模型的文件。
    [model_server] AI 的服务商没有响应：请稍后再试，或检查网络连接。
    [picture_address] 无法获取这张图片。
    [picture_server] 无法连接到图片服务器。
    [provider_voices] 无法连接到服务商的语音列表。
    [search_model] 搜索模型没有响应。
    [provider_voice] 无法连接到服务商的语音。
    [provider_search_model] 无法连接到服务商的搜索模型。
   *[other] 无法连接。
}
error-answered = { $whose ->
    [comfyui] ComfyUI 返回了 { $status }。
    [model_server] AI 的服务商返回了 { $status }。请稍后再试。
    [picture_server] 图片服务器返回了 { $status }。
    [provider_voices] 服务商的语音列表返回了 { $status }。
    [search_model] 搜索模型返回了 { $status }。
   *[other] 返回了 { $status }。
}
error-answered-said = { $said ->
    [did_not_take_the_key] 服务商没有接受这个密钥。
    [asks_for_a_key] 服务商需要一个密钥。
   *[other] 服务商在这个地址没有模型列表。
}
