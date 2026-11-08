### UIの言葉の日本語版：サーバーのエラー応答。api/generated/Code.ts（errors.ts）のコードごとにひとつ、
### `error-<code>`（「_」は「-」に）。用語集は ja.ftl の冒頭にあります。

## The request, as the server took it

error-request-failed = それはできませんでした。もう一度お試しください。
error-internal = Cardwaveで問題が発生しました。もう一度お試しください。
error-bad-request = Cardwaveはそのリクエストを読み取れませんでした。ページを再読み込みして、もう一度お試しください。
error-forbidden = それは許可されていません。
error-no-such-path = Cardwaveにそのページはありません。ページを再読み込みして、もう一度お試しください。
error-method-not-allowed = Cardwaveはここではそれを行いません。ページを再読み込みして、もう一度お試しください。
error-too-large = 大きすぎます。もっと小さいファイルをお試しください。
error-unsupported-type = Cardwaveはここではその種類のファイルを受け付けません。

## Passwords and accounts

error-locked = パスワードを入力するまで、Cardwaveはロックされています。
error-sign-in = 先にサインインしてください。
error-password-wrong = パスワードが違います。
error-password-needed = パスワードが必要です。
error-current-password-needed = 現在のパスワードが必要です。
error-backup-password-needed = このバックアップにはパスワードが必要です。
error-too-many-tries = パスワードの誤りが多すぎます。{ $seconds }秒後にもう一度お試しください。
error-owner-only = { $action ->
    [use_its_files] このコンピューターのファイルを使う
    [use_its_folders] このコンピューターのフォルダーを使う
    [choose_its_models] このコンピューターのモデルを選ぶ
    [lock_Cardwave] Cardwaveをロックする
   *[other] それを行う
}ことができるのは、このコンピューターのアカウントだけです。
error-no-password-to-lock = Cardwaveをロックできるのは、パスワードがオンのときだけです。
error-remote-sign-in-off = このアカウントはほかのデバイスからサインインできません。アカウント › 共有でオンにしてください。
error-no-password-on = パスワードはオンになっていません。
error-no-password-set = このアカウントにはパスワードが設定されていません。
error-password-kept = このコンピューターのアカウントにはパスワードがあり、それでサインインします。
error-account-busy = Cardwaveはまだこのアカウントの作業中です（返信、画像、コーディングタスク、新しいキャラクター、キャラクターの読み込み、またはチャットの記憶）。終わってからもう一度お試しください。
error-restore-busy = Cardwaveはまだ作業中です（返信、画像、コーディングタスク、新しいキャラクター、キャラクターの読み込み、またはチャットの記憶）。終わってからもう一度お試しください。
error-backup-needs-password = バックアップにはパスワードが必要です。

## What is asked of

error-not-found = その{ $what ->
    [account] アカウント
    [asset] カード内のファイル
    [attachment] 添付ファイル
    [card] カード
    [card_version] カードのバージョン
    [chat] チャット
    [chat_character] チャット内のキャラクター
    [checkpoint] チェックポイント
    [deleted_message] 削除されたメッセージ
    [document] ドキュメント
    [expression] 表情
    [expression_pack] 表情のセット
    [figure] フィギュア
    [kind_of_model] モデルの種類
    [language] 言語
    [lorebook] ロアブック
    [lorebook_entry] ロアブックのエントリー
    [memory] 記憶
    [message] メッセージ
    [model] モデル
    [persona] ペルソナ
    [picture] 画像
    [preset] プリセット
    [prompt_preset] プロンプトプリセット
    [provider] プロバイダー
    [question] 質問
    [task] タスク
    [tool] ツール
    [user] アカウント
    [voice] 音声
   *[other] もの
}はありません。削除された可能性があります。
error-chat-busy = このチャットでは返信を作成中です。先に停止してください。
error-no-provider = プロバイダーがまだ設定されていません。設定 › プロバイダーで追加してください。
error-provider-refused = { $refusal ->
    [key] プロバイダーがキーを受け付けませんでした。設定 › プロバイダーで確認してください。
    [paid] プロバイダーがこの利用に支払いを求めています。クレジットを追加するか、プランに含まれるモデルを選んでください。
    [busy] プロバイダーのクレジットが残っていないか、混み合っています。あとでもう一度お試しください。
    [down] プロバイダーが応答していません。あとでもう一度お試しください。
    [fault] プロバイダー側で障害が起きました：{ $reason } あとでもう一度お試しください。
    [no_model] プロバイダーはこのモデルをもう提供していません。設定 › モデルで別のモデルを選んでください。
    [too_long] このモデルにはメッセージが長すぎます。短くするか、設定 › モデルでもっと多く受け取れるモデルを選んでください。
   *[other] プロバイダーに断られました：{ $reason }
}
error-model-declined = { $model }はこれを書くことを断りました。メッセージを変えるか、別のモデルを選んでください。
error-model-sees-no-pictures = { $model }は画像を見られないため、画像を受け取りません。画像を送るには、画像を見られるモデルを選んでください。
error-card-trashed = キャラクターはゴミ箱にあります。先に復元してください。
error-lorebook-trashed = ロアブック「{ $name }」はゴミ箱にあります。使うには復元してください。
error-own-lorebook-flags = キャラクター自身のロアブックはキャラクターと一体です。単独でスターを付けたり、アーカイブしたり、ゴミ箱に移したり、すべてのチャットで使ったりすることはできません。

## Folders and files

error-no-such-folder = このコンピューターにフォルダー{ $folder }はありません。
error-folder-not-chosen = 先にフォルダーを選んでください。
error-drive-root-to-watch = ドライブのルートは監視するには大きすぎます。その中のフォルダーを選んでください。
error-drive-root-for-model = ドライブのルートはAIに渡すには中身が多すぎます。その中のフォルダーを選んでください。
error-data-folder = そのフォルダーはCardwave自身のデータを含むか、その中にあります。別のフォルダーを選んでください。
error-commands-windows-only = コマンドはWindowsでのみ実行されます。
error-recycle-bin-windows-only = ファイルをWindowsのごみ箱に移せるのはWindowsだけです。
error-files-tool-off = 先に設定 › ツールで「ファイル」をオンにしてください。チームはそれでタスクのフォルダーを読み書きします。

## Pictures, replies and voices

error-picture-words-missing = 先に画像の内容を書いてください。
error-picture-words-too-long = 画像の内容が{ $most }文字を超えています。
error-picture-needs-words = 画像の内容を書いてください。
error-goal-missing = チームにしてほしいことを書いてください。
error-dictation-not-set-up = 音声入力が設定されていません：設定 › モデル › 音声入力。
error-direction-without-go-on = ヒントは「続ける」でだけ使えます。
error-again-or-go-on = 返信は書き直すか続けるか、どちらか一方です。
error-again-not-reply = 書き直せるのはキャラクターの返信だけです。
error-no-reply-to-write-again = このチャットには書き直す返信がありません。
error-no-text = AIがテキストを送りませんでした。もう一度お試しください。
error-worker-no-answer = ヘルパーモデルが応答しませんでした。
error-unknown-voice = 音声「{ $voice }」はありません。
error-nothing-to-read = 読み上げるものがありません。
error-voice-not-downloaded = 音声がダウンロードされていません。
error-voice-failed = 読み上げに失敗しました。もう一度お試しください。
error-stopping = Cardwaveを終了しています。
error-download-failed = ダウンロードに失敗しました。接続を確認して、もう一度お試しください。
error-search-model-failed = 検索モデルが失敗しました。Cardwaveはしばらくしてからもう一度試します。
error-models-not-listed = プロバイダーのモデル一覧を取得できませんでした。アドレスとキーを確認して、もう一度お試しください。
error-file-not-imported = ファイルを読み込めませんでした。Cardwave はこの形式を知りません。
error-describing-failed = ヘルパーモデルはキャラクターを説明できませんでした。

## The kinds an area's failures are grouped by: each picks its words by `what` (or `whose`), the thing it is about

error-needed = { $what ->
    [persona_name] ペルソナには名前が必要です。
    [account_name] アカウントには名前が必要です。
    [card_title] キャラクターにはタイトルが必要です。
    [character_name] キャラクターには名前が必要です。
    [chat_character] チャットにはキャラクターが必要です。
    [chat_title] チャットのタイトルを入力してください。
    [entry_name] エントリーには名前が必要です。
    [expression_files] zipファイル（まとめたフォルダー）か、セットの画像を選んでください。
    [language] 言語が指定されていません。
    [lorebook_name] ロアブックには名前が必要です。
    [memory_text] 記憶にはテキストが必要です。
    [message_to_improve] 改善するメッセージがありません。
    [model_name] モデルの名前を指定してください。
    [models_folder] 先にモデルのフォルダーを選んでください。
    [password] パスワードは空にできません。
    [preset_name] プリセットには名前が必要です。
    [rewrite_given] 必要なものが足りません。もう一度お試しください。
    [summary] 要約を入力してください。
    [text_to_change] 変更するテキストがありません。
    [text_to_read] 読み上げるものがありません。
    [voice_name] 音声には名前が必要です。
   *[other] 必要なものが足りません。もう一度お試しください。
}
error-too-long = { $what ->
    [account_name] アカウントの名前は{ $name_limit }文字までです。
    [chat_title] チャットのタイトルは{ $title_limit }文字までです。
    [document] { $name }は長すぎます：ドキュメントは2,000,000文字までです。
    [entry_name] エントリーの名前は{ $max_name }文字までです。
    [field_name] 項目の名前は1〜{ $max_field }文字です。
    [lorebook_name] ロアブックの名前は{ $max_name }文字までです。
    [memory_text] 記憶は{ $text_limit }文字までです。
    [persona_name] ペルソナの名前は{ $max_name }文字までです。
    [provider_name] 名前は{ $name_limit }文字までです。
    [unsaved_text] 保存していないテキストは{ $max_text }文字まで残ります。
    [voice_name] 音声の名前は{ $name_most }文字までです。
   *[other] { $most }文字を超えています。
}
error-out-of-range = { $what ->
    [authors_note_depth] メモは1メッセージ以上前に入れます。
    [companion_size] コンパニオンの大きさは画面の高さの{ $start }〜{ $end }パーセントです。
    [context_size] コンテキストのサイズは512トークン以上にしてください。
    [entry_chance] エントリーの確率は100パーセントまでです。
    [provider_setting] { $name }は{ $min }〜{ $max }にしてください。
    [reply_length] 返信の長さは1〜{ $most_reply_length }トークンにしてください。
    [slider] スライダーは0〜100です。
    [talk_pause] 間隔は0〜{ $most_talk_pause }秒にしてください。
    [talk_replies] 連続返信の回数は1〜{ $most_talk_replies }にしてください。
    [talkativeness] おしゃべり度は 0 から 100 までです。
    [voice_speed] 速さは { $start }% から { $end }% までです。
   *[other] { $least }〜{ $most }にしてください。
}
error-taken = { $what ->
    [card_in_library] すでにライブラリにあります。
    [account_name] 「{ $name }」という名前のアカウントがほかにあります。
    [card_language] カードはすでに{ $name }です。
    [chat_character] { $name }はすでにこのチャットにいます。
    [chat_character_twice] { $name }がこのチャットに2回います。
    [lorebook_same_name] カードには同じ名前のロアブックかエントリーがすでにあります。
    [model_file] { $name }はすでにフォルダーにあります。
    [preset_name] 「{ $name }」という名前のプリセットがほかにあります。
    [tool_name] { $name }という名前のツールはすでにあります。別の名前を選んでください。
   *[other] それはすでにあります。
}
error-in-trash = { $what ->
    [card] キャラクターはゴミ箱にあります。先に復元してください。
    [card_to_chat] キャラクターはゴミ箱にあります。もう一度チャットするにはキャラクターを復元してください。
    [chat] チャットはゴミ箱にあります。先に復元してください。
    [chat_card] キャラクター「{ $title }」がゴミ箱にあります。先にキャラクターを復元してください。
    [lorebook] ロアブック「{ $name }」はゴミ箱にあります。先に復元してください。
    [lorebook_to_use] ロアブック「{ $name }」はゴミ箱にあります。使うには復元してください。
    [persona_default] ゴミ箱にあるペルソナはデフォルトにできません。先に復元してください。
    [persona_to_use] ペルソナ「{ $name }」はゴミ箱にあります。使うには復元してください。
   *[other] それはゴミ箱にあります。先に復元してください。
}
error-not-readable = { $what ->
    [damaged_key] キーが壊れています。
    [json] このファイルは有効なJSONではありません。
    [lorebook] このファイルにはロアブックがありません。
    [lorebook_not_card] このファイルはキャラクターカードで、ロアブックではありません。
    [account_picture] この画像は、読み取れる一辺4,096ピクセル以下のPNGまたはJPEGではありません。
    [attachment_picture] 画像はPNG、JPEG、WebPのいずれかのファイルです。
    [backup] このファイルはCardwaveのバックアップではありません。
    [backup_damaged] このバックアップは壊れています。
    [backup_newer] このバックアップは新しい Cardwave で作られています。復元するには Cardwave を更新してください。
    [backup_key] このバックアップは壊れています：キーを読み取れません。
    [base64] それはbase64ではありません。
    [base64_file] { $name }はbase64ではありません。
    [card_defined_twice] このファイルは Cardwave が読めるキャラクターカードではありません。元のアプリからもう一度書き出してください。
    [card_file_name] カード内のファイル名を使えません。
    [card_reference] それはカードのどの部分も指していません。
    [ccv4_version] このカードは新しい Cardwave で作られています。開くには Cardwave を更新してください。
    [comfyui_address] ComfyUIのアドレスを読み取れません。
    [comfyui_answer] ComfyUIの応答を読み取れません。
    [dictation_recording] 録音を読み込めませんでした。もう一度録音してください。
    [document_text] { $name }には読み取れるテキストがありません。
    [document_type] ドキュメントは.txt、.md、.pdf、.docxのいずれかのファイルです。
    [downloaded_model] ダウンロードしたファイルはモデルではありません。
    [expression_pack] 気分の英語名（joy.png、anger.png など）がついた画像がありません（PNG、JPEG、WebP、GIF）。
    [figure_file] { $file_name }はその種類のファイルではありません。
    [figure_still] フィギュアの静止画が、4 MB以下のPNGではありません。
    [figure_type] 3DフィギュアはVRM、GLB、FBXのいずれかのファイルです。
    [folder_read] フォルダーを読み取れません。
    [format_version] このファイルは Cardwave が読めるキャラクターカードではありません。元のアプリからもう一度書き出してください。
    [image_model_answer] 画像モデルの応答を読み取れません。
    [image_model_picture] 画像モデルの画像を読み取れません。
    [key_characters] キーにキーで使えない文字が含まれています。プロバイダーのサイトからもう一度コピーしてください。
    [lorebook_empty] ロアブックが空です。
    [lorebook_entries] ロアブックにエントリーがありません。
    [lorebook_file] ロアブックを読み取れません。
    [lorebook_named] ロアブック「{ $name }」を読み取れません。
    [lorebook_named_empty] ロアブック「{ $name }」は空です。
    [models_dev_list] モデルの一覧を読み取れません。
    [models_list_answer] アドレスは応答しますが、モデルの一覧ではありません。
    [models_list_missing] モデルの一覧が届きませんでした。
    [name_characters] 名前に使えない文字が含まれています。
    [no_lorebook] これはロアブックではありません。
    [pdf] PDFを読み取れません。
    [picture] 画像がPNG、JPEG、WebPのいずれでもありません。
    [picture_server_answer] 画像サーバーの応答を読み取れません。
    [picture_unreadable] 画像を読み取れません。
    [png] PNGファイルではありません。
    [no_card] このファイルにはキャラクターカードがありません。
    [png_damaged] PNGが壊れています。
    [charx] Cardwave はまだ CHARX カードファイルを読み込めません。カードを PNG か JSON で書き出してください。
    [provider_address] アドレスは https://api.openai.com/v1 のような普通のウェブアドレスにしてください。
    [provider_website] プロバイダーのウェブサイトは example.com のような名前で入力してください。
    [recording_format] 録音の形式を読み取れません。
    [recording_pcm] 録音を読み込めませんでした。もう一度録音してください。
    [recording_rate] 録音のサンプルレートを読み取れません。
    [recording_short] 録音が短すぎます：{ $shortest }秒以上必要です。
    [recording_silent] 録音に音がありません。
    [recording_wav] 録音がWAVファイルではありません。
    [sillytavern_base64] このファイルは Cardwave が読めるキャラクターカードではありません。元のアプリからもう一度書き出してください。
    [sillytavern_empty] カードが空です。
    [sillytavern_file] このファイルのSillyTavernカードを読み取れません。
    [sillytavern_json] このファイルは Cardwave が読めるキャラクターカードではありません。元のアプリからもう一度書き出してください。
    [sillytavern_object] このファイルは Cardwave が読めるキャラクターカードではありません。元のアプリからもう一度書き出してください。
    [sillytavern_png] このPNGのSillyTavernカードを読み取れません。
    [spec_version] このファイルは Cardwave が読めるキャラクターカードではありません。元のアプリからもう一度書き出してください。
    [spec_version_form] このファイルは Cardwave が読めるキャラクターカードではありません。元のアプリからもう一度書き出してください。
    [toml] このファイルは Cardwave が読めるキャラクターカードではありません。元のアプリからもう一度書き出してください。
    [word_file] Wordファイルを読み取れません。
    [word_text] Wordファイルにテキストがありません。
    [workflow] ワークフロー「{ $name }」を読み取れません。
    [workflow_api_form] このワークフローはAPI用の形式で保存されています。ComfyUIでワークフローとして保存してください。
    [workflow_broken] ワークフローを読み取れません。
    [workflow_fields] ワークフローのノード「{ $kind }」に、Cardwaveが読み取れない項目があります。
    [workflow_no_node] ワークフローに、このComfyUIで実行できるノードがありません。
    [workflow_node] ワークフローのノード「{ $class }」は、このComfyUIにありません。
    [zip] { $name }をzipとして読み取れません。
   *[other] それを読み取れません。
}
error-too-big = { $what ->
    [card_for_worker] キャラクターがヘルパーモデルには長すぎます。もっと多く読めるヘルパーモデルを選んでください。
    [card_file] ファイルが{ $most } MBを超えています。
    [checkpoint_folder] フォルダーが大きすぎて、各ステップの前にコピーを残せません。
    [expression_pack_size] { $name }の画像が大きすぎます。
    [expression_zip_files] { $name }には{ $max_entries }個を超えるファイルがあります。
    [figure] 3Dフィギュアが大きすぎます。
    [model_for_computer] { $name }はこのコンピューターには大きすぎます。
    [models_dev_list] モデルの一覧が長すぎます。
    [picture_pixels] 画像が大きすぎます（{ $wide }×{ $high }ピクセル）。
    [reply] 返信が長くなりすぎたため、途中で切れました。
   *[other] 大きすぎます。
}
error-not-now = { $what ->
    [character_has_written] { $name }はこのチャットで発言しているため、チャットに残ります。
    [coding_folder_busy] そのフォルダーでは別のコーディングタスクが実行中です。終わるまで待つか、停止してください。
    [database_busy] Cardwave が処理中でした。もう一度お試しください。
    [download_cancelling] ダウンロードをキャンセル中です。少ししてからもう一度お試しください。
    [held_by_card] キャラクターが使っています。先にキャラクターから外してください。
    [lorebook_used_elsewhere] このロアブックはほかの場所でも使われるようになったため、ライブラリに残ります。
    [model_downloading] モデルをダウンロード中です。
    [model_replying] モデルが返信中です。返信が終わってから削除してください。
    [search_model_not_downloaded] 検索モデルがダウンロードされていません。
    [task_running] タスクはまだ実行中です。先に停止してください。
   *[other] 今はそれを行えません。少ししてからもう一度お試しください。
}
error-changed = { $what ->
    [lorebook_entry] ロアブックに別のエントリーができています。
    [card_version] カードがその間に変更されたため、読み込み直します。
    [tool_name] 今は別のツールが{ $name }という名前です。
    [two_ways] { $reference } が同時に二度変更されました。もう一度お試しください。
    [workflow] ワークフロー「{ $name }」はComfyUIで変更されました：設定 › プロバイダーでもう一度選んでください。
   *[other] その間に変更されました。もう一度お試しください。
}
error-not-possible = { $what ->
    [back_to_computer] このコンピューターに戻せるのは検索と音声だけです。
    [card_about_itself] カードが自分自身について記している内容は変更できません。
    [card_change] それはこのカードでは変更できません。
    [card_character] カードにそのキャラクターはいません。
    [card_character_change] カードのキャラクターは変更できません。
    [card_language_beside] このカードには、最初の言語に加えて{ $name }を入れることはできません。
    [card_lorebook] カードにそのロアブックはありません。
    [card_lorebook_attached] カードにそのロアブックはつけられていません。
    [card_mode] カードにそのモードはありません。
    [card_no_character] カードにキャラクターがいません。
    [card_not_changed] カードは変更されませんでした。
    [card_part] それはカードの変更できる部分ではありません。
    [card_takes_no] このカードには、その種類の新しいものを追加できません。
    [card_takes_no_lorebook] このカードにはロアブックを追加できません。
    [character_change] このカードではそのキャラクターを変更できません。
    [chat_character] チャットにそのキャラクターはいません。
    [chat_lore] チャットにそのロアブックまたはロアブックのエントリーはありません。
    [chat_lorebook] チャットにそのロアブックはありません。
    [chat_mode] チャットにそのモードはありません。
    [chat_no_character] チャットにキャラクターがいません。
    [chat_without_character] キャラクターのいないチャットにはキャラクターがいません。
    [chat_without_character_add] キャラクターのいないチャットにはキャラクターを追加できません。
    [checkpoint_put_back] { $path }を元に戻せません。
    [comfyui_no_picture] ComfyUIは画像を作りませんでした。
    [companion_not_answering] コンパニオンが応答しませんでした。
    [companion_not_shown] コンパニオンは表示されていません。
    [comfyui_queue] ComfyUIは画像をキューに入れませんでした。
    [comfyui_said] ComfyUIの応答：{ $said }
    [continue_no_text] 返信に続けるテキストがありません。
    [continue_only_reply] 続けられるのはキャラクターの返信だけです。
    [depth_note] 深さを指定したメモは追加できません。
    [dictation_failed] 音声入力モデルが失敗しました。
    [dictation_model_load] 音声入力モデルを読み込めません。
    [dictation_model_start] 音声入力モデルを起動できません。
    [draft_made_by] 下書きは「{ $made }」では作られません。
    [edit_breaks_card] この変更をすると、カードが読み取れなくなります。
    [entry_change] このロアブックでは、エントリーを指定どおりに変更できません。
    [entry_taken_out] これは取り出されたロアブックのエントリーではありません。
    [export_no_character] カードにエクスポートするキャラクターがいません。
    [greeting] それはこのキャラクターの挨拶ではありません。
    [improve_direction] 改善は入力欄の言葉を使います。ヒントは使えません。
    [key_refused] キーが拒否されました。
    [llama_server_start] 検索モデルを起動できません。Cardwave を再起動して、もう一度お試しください。
    [local_address] このコンピューターのモデルは、設定 › プロバイダーでフォルダーから探します。
    [lorebook_change] このロアブックは変更できません。
    [lorebook_change_breaks] この変更をすると、ロアブックが読み取れなくなります。
    [lorebook_new_entry] このロアブックには新しいエントリーを追加できません。
    [lorebook_put_in] このロアブックはこのカードに入れられません。
    [lorebook_take_out] このロアブックはこのカードから取り出せません。
    [message_not_in_chat] そのメッセージはこのチャットのものではありません。
    [message_not_in_view] そのメッセージは表示されていません。
    [model_remove] { $path }を削除できません。
    [no_folder] このコンピューターにそのフォルダーはありません。
    [no_image_model] 画像モデルがまだ設定されていません：設定 › モデル › 画像で設定してください。
    [no_local_model] そのフォルダーにモデル「{ $id }」はありません。
    [no_local_models] ローカルモデルが設定されていません。
    [no_recycle_bin] { $path }にはWindowsのごみ箱がありません。
    [no_summary] カードにはまだ要約がありません。
    [no_voice] その音声はありません。
    [no_vulkan] このコンピューターのグラフィックカードではモデルを動かせません。代わりにプロバイダーを使ってください。
    [no_vulkan_dictation] このコンピューターのグラフィックカードでは音声入力を動かせません。
    [prompt_change] このカードではそのキャラクターのプロンプトを変更できません。
    [recycle_bin_move] { $path }をWindowsのごみ箱に移せませんでした。
    [speaker_not_in_chat] 話し手はこのチャットの参加者ではありません。
    [speaker_only_character] 話し手がいるのはキャラクターのメッセージだけです。
    [unknown_language] それはこのアプリが知っている言語ではありません。
    [version_lacks_character] 最新のバージョンにないキャラクターとのチャットがあります。
    [voice_runtime] 読み上げに必要なMicrosoftの部品がありません。microsoft.com から Visual C++ 再頒布可能パッケージをインストールし、Cardwaveを再起動してください。
    [workflow_no_text] ワークフロー「{ $name }」に、画像の言葉を入れるテキスト欄がありません。
    [workflow_use] ワークフロー「{ $name }」は使えません。
    [written_tools_full] ツールは最大 { $most_tools } 個までです。先に 設定 › AIが書いたツール で一つ削除してください。
    [delete_not_in_trash] 完全に削除できるのはゴミ箱にあるものだけです。先にゴミ箱に移してください。
   *[other] それはできません。
}
error-model-answer = { $what ->
    [no_greeting] AIは挨拶を書きませんでした。
    [background_answer] 補助モデルの答えを使えませんでした。もう一度試すか、別の補助モデルを選んでください。
    [background_text] 補助モデルの答えを使えませんでした。もう一度試すか、別の補助モデルを選んでください。
    [card_texts] AIの応答はキャラクターのテキストではありませんでした。
    [classification] 補助モデルの答えを使えませんでした。もう一度試すか、別の補助モデルを選んでください。
    [example_messages] AIは例文のメッセージを書きませんでした。
    [no_example_message] AIはテキストのない例文のメッセージを書きました。
    [json] AIの応答は求めた形式ではありませんでした。
    [keywords] 補助モデルの答えを使えませんでした。もう一度試すか、別の補助モデルを選んでください。
    [logline] 補助モデルの答えを使えませんでした。もう一度試すか、別の補助モデルを選んでください。
    [no_chat_reply] AIのプロバイダーがチャットの返信を送りませんでした。
    [no_fitting_answer] AIは3回試しても使える応答を返しませんでした。
    [no_picture] 画像モデルが画像なしで応答しました。
    [no_plan] プランナーは計画を作りませんでした。
    [no_text] AIがテキストを送りませんでした。
    [picture_address] 画像モデルの画像は、取得しないアドレスにあります。
    [picture_art] 画像を作れませんでした。もう一度お試しください。
    [picture_field] ヘルパーモデルは画像の言葉を入れる欄を見つけられませんでした。
    [picture_server_no_picture] 画像サーバーが画像なしで応答しました。
    [picture_words] ヘルパーモデルは画像の言葉を書きませんでした。
    [rating] 補助モデルの答えを使えませんでした。もう一度試すか、別の補助モデルを選んでください。
    [reply_broke_off] 返信が途中で切れました。
    [needs] 補助モデルの答えを使えませんでした。もう一度試すか、別の補助モデルを選んでください。
    [rounds] チームは{ $rounds }ラウンドで作業を終えませんでした。
    [search_left_out] 検索モデルがテキストをひとつ抜かしました。
    [search_model] 検索モデルの応答を読み取れません。
    [search_tokens] 検索モデルのトークンを読み取れません。
    [title] 補助モデルの答えを使えませんでした。もう一度試すか、別の補助モデルを選んでください。
    [too_many_tools] AIがツールを呼び出しすぎました。
    [worker_mode] 補助モデルの答えを使えませんでした。もう一度試すか、別の補助モデルを選んでください。
    [worker_texts] 補助モデルの答えを使えませんでした。もう一度試すか、別の補助モデルを選んでください。
    [server_reported] AIのプロバイダーからの報告：{ $reason }
   *[other] AIの応答を使えません。
}
error-timed-out = { $whose ->
    [comfyui] ComfyUIが時間内に画像を作りませんでした。
    [llama_server] 検索モデルの準備が間に合いませんでした。もう一度お試しください。
    [model] AIが時間内に応答しませんでした。もう一度お試しください。
    [model_server] AIのプロバイダーが時間内に応答しませんでした。もう一度お試しください。
    [search_model] 検索モデルが時間内に応答しませんでした。
   *[other] 時間内に応答がありませんでした。
}
error-unreachable = { $whose ->
    [comfyui] ComfyUIに接続できません。
    [image_model] 画像モデルに接続できません。
    [model_download] モデルのファイルをダウンロードできません。
    [model_server] AIのプロバイダーが応答していません。あとでもう一度試すか、接続を確認してください。
    [picture_address] 画像を取得できません。
    [picture_server] 画像サーバーに接続できません。
    [provider_voices] プロバイダーの音声に接続できません。
    [search_model] 検索モデルが応答しません。
    [provider_voice] プロバイダーの音声に接続できません。
    [provider_search_model] プロバイダーの検索モデルに接続できません。
   *[other] 接続できません。
}
error-answered = { $whose ->
    [comfyui] ComfyUIの応答：{ $status }。
    [model_server] AIのプロバイダーが{ $status }を返しました。後でもう一度お試しください。
    [picture_server] 画像サーバーの応答：{ $status }。
    [provider_voices] プロバイダーの音声の応答：{ $status }。
    [search_model] 検索モデルの応答：{ $status }。
   *[other] 応答：{ $status }。
}
