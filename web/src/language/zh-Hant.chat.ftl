

## card-block (card/card-block.ts)

card-block-text = { $madeBy } · { $under }

## coding (chat/coding.ts)

coding-the-team = AI 團隊
coding-open-task = 開啟程式設計任務
coding-undo-all = 全部復原
coding-put-the-folder-back = 要把資料夾還原成任務開始前的樣子嗎？
coding-add-an-export-of = 加入把聊天匯出成 Markdown 的功能，並附上測試。
coding-c-users-you-projects = C:\Users\you\Projects\app
coding-start-a-coding-task = 開始程式設計任務
coding-start = 開始
coding-goal = 目標
coding-a-checkpoint-is-kept = Cardwave 會在每一步之前保留資料夾的副本，所以每一步都能復原。

## composer (chat/composer.ts)

composer-whoever-is-named-replies = 被點名的角色回覆
composer-the-character-named-in = 由最新訊息中提到的角色回覆；沒有提到任何角色時，隨機由其他角色之一回覆。
composer-each-replies-in-turn = 輪流回覆
composer-the-characters-reply-one = 角色按側邊面板列出的順序，一個接一個回覆。
composer-a-random-one-replies = 隨機一位回覆
composer-one-of-the-characters = 隨機由一個角色回覆，但不會是上一個發言的角色。
composer-keep-replying-by-themselves = 角色們自己繼續聊
composer-write-for-me = 幫我寫
composer-uses-what-you-typed = AI 替你寫訊息；你輸入的內容用來引導它，不會送出。
composer-improve = 潤飾我的訊息
composer-rewrites-what-you-typed = 改寫你輸入的內容
composer-attach-picture-or-document = 附加圖片或文件
composer-ai-draws-a-picture = AI 為聊天畫一張圖；你輸入的內容用來引導它
composer-joins-this-chat = 另一個角色加入這個聊天
composer-add-or-write = 附加檔案，或讓 AI 來寫
composer-message = 訊息
composer-send = 傳送
composer-writing-your-message = 正在撰寫你的訊息……
composer-who-replies = 由誰回覆：{ $says }
composer-writes-every-reply = 每則回覆都由 { $name } 撰寫。
composer-who-replies-group = 誰來回覆
composer-joined-the-chat = { $name } 加入了聊天。
composer-message-improved = 訊息已潤飾。
composer-message-written-for-you = 已幫你寫好訊息。
composer-message-2 = 傳訊息給 { $whom }
composer-replies = 由 { $name } 回覆

## dictate (chat/dictate.ts)

dictate-dictate = 聽寫
mic-none = 找不到麥克風：請接上一個，然後再試一次。
mic-not-allowed-desktop = Cardwave 無權使用麥克風：請在 Windows 隱私權設定的「麥克風」中允許。
mic-not-allowed-browser = 此頁面無權使用麥克風：請在瀏覽器中此網站的設定裡允許。
mic-not-started = 無法啟動麥克風：請關閉正在使用它的其他程式，然後再試一次。
mic-not-offered = 在這個位址上瀏覽器不提供麥克風：請在執行 Cardwave 的電腦上使用麥克風。
dictate-dictation-failed = 聽寫失敗：{ $reason }。請再試一次。
dictate-writing-what-was-said = 正在寫下說出的內容……
dictate-nothing-was-heard = 沒有聽到任何聲音。
dictate-stop-dictating = 停止聽寫

## header (chat/header.ts)

header-chat-title = 聊天標題
header-the-title-was-not = 標題沒有儲存：{ $reason }。請再試一次。
header-automatic = 自動
header-automatic-sub = 根據你寫的內容，從下面的模式中選一個
header-new-chat-with-these = 和這些角色開始新聊天
header-new-chat-with = 和{ $name }開始新聊天
header-add-to-favourites = 加入最愛
header-remove-from-favourites = 從最愛中移除
header-chat-options = 聊天選項
header-with = 與 { $join }

## messages (chat/messages.ts)

messages-ai = AI
messages-you = （你）
messages-you-2 = 你
messages-writing = 正在撰寫……
messages-message-and-the-after = 已刪除這則訊息及其後的 { $after }。
messages-message-deleted = 訊息已刪除。
messages-branch-from-here = 從這裡換個走向
messages-edit-message = 編輯訊息
messages-stop-reading = 停止朗讀
messages-read-aloud = 朗讀
messages-message-options = 訊息選項
messages-previous-version = 上一個版本
messages-next-version = 下一個版本
messages-write-again = 重新寫
messages-continue-reply = 繼續寫這則回覆
messages-version-of = 第 { $at } 版，共 { $count } 版
messages-delete-versions = 刪除，連同所有版本（{ $count }）
messages-delete-version = 刪除此版本
messages-continue-uses-what-you = 繼續這則回覆 · 輸入框裡的話會引導它
messages-generate-reply = 產生回覆

## narration (narration.ts)

narration-show-pictures-from-the = 顯示網路上的圖片
narration-a-picture-from-another = 已隱藏一張來自其他網站的圖片：載入它會讓該網站知道這個聊天被開啟了。
narration-you-can-change-this = 你隨時可以在「設定 › 外觀」中更改。

## panel (chat/panel.ts)

panel-in-trash = （在垃圾桶中）
panel-remove-from-this-chat = 從這個聊天移除
panel-chat-details = 聊天詳細資訊
panel-in-trash-locked = 在垃圾桶中：還原聊天後才能更改。
panel-as-an-assistant = 作為助理時的個性
panel-kept-with-the-character = 隨角色保存，用於與這個角色的每個聊天。
panel-memory = 記憶
panel-move-up = 上移
panel-move-down = 下移
panel-in-speaking-order = 按發言順序
panel-options-for = { $name } 的選項
panel-user = { card-user-stand-in }
panel-new-persona = 新增使用者角色……
panel-from-settings = { $inUse }（來自設定）
panel-default-the-characters-own = 預設（角色自己的）
panel-not-used-this-model = 未使用：這個模型自己決定回覆長度
panel-not-used-while-a = AI 使用工具時不使用
panel-tokens-per-reply = 每則回覆的 token 數
panel-very-short = 很短
panel-short = 短
panel-medium = 中等
panel-long = 長
panel-very-long = 很長
panel-pause-between-replies = 回覆之間的停頓
panel-seconds-when-they-reply = 以秒計；僅在角色們自己聊天時
panel-replies-in-a-row = 連續回覆次數
panel-by-themselves-then-they = 角色自己回覆這麼多次後停下
panel-reply-length = 回覆長度
panel-small-tools-then-kept = AI 可以自己寫小程式來查找或計算；這些程式在每個聊天中都能繼續使用
panel-the-characters-bring-none = 這些角色沒有帶世界書。
panel-restore = 還原
panel-put-back-2 = 把 { $name } 放回
panel-left-out = 此聊天中不使用
panel-in-trash-2 = 在垃圾桶中
panel-used-in-last-reply = 上一則回覆中用到
panel-used-in-this-reply = 這則回覆中用到
panel-read-on-the-web = 在網路上讀到
panel-read-from-your-files = 從你的檔案讀到
panel-saved-to-memory = 已存入記憶
panel-this-character-has-no = 這個角色沒有圖片。
panel-show-portrait = 顯示角色圖片
panel-add-lorebook-to-chat = 為此聊天新增世界書
panel-entry-of = { $lorebook } 的條目
panel-portrait-beside = 在聊天旁邊
panel-remove-from-this-chat-2 = 從這個聊天移除 { $name }
panel-remove-lorebook-from-this = 從這個聊天移除世界書 { $name }

## pictures (chat/pictures.ts)

pictures-open-the-picture = 開啟圖片
pictures-change-prompt = 編輯描述
pictures-save-picture = 儲存圖片
pictures-picture-options = 圖片選項
pictures-prompt = 描述
pictures-make-again = 重新產生

## split (chat/split.ts)

split-open-card-page = 開啟角色頁面
split-hide-card-editor = 隱藏角色頁面
split-card-editor = 角色頁面
split-changes-are-used-from = 更改從下一則回覆開始生效
split-this-card-is-in = 這個角色在垃圾桶中。

## stats (chat/stats.ts)

stats-chat-history = 之前的訊息
stats-reply-statistics = 關於這則回覆
stats-context-used = AI 能讀取的內容已用了多少
stats-sent-to-the-ai = 傳送給 AI · { $count } 個 token
stats-in-all = 共 { $seconds }
stats-to-the-first-word = { $seconds } 後出現第一個字 · { $all }

## talk (chat/talk.ts)

talk-the-characters-stopped-after = 角色回覆 { $asked } 次後停下了。
talk-go-on = 繼續

## title (chat-title.ts)

title-new-chat = 新聊天

## chat (companion/chat.ts)

chat-open-in-cardwave = 在 Cardwave 中開啟
chat-compact-chat = 和桌面夥伴聊天
chat-read-replies-aloud = 朗讀回覆
chat-no-voice = 尚未設定語音：請在 設定 › 語音 中選擇一個
chat-the-card-has-no = 這張卡沒有可以聊天的角色。請用「更換角色」選另一個。
chat-message = 傳訊息給 { $name }

## main (companion/main.ts)

main-open-chat = 開啟聊天
main-figure-hint = 按兩下聊天，按右鍵查看更多
main-walk-around = 四處走動
main-sit-still = 坐著不動
main-change-character = 更換角色
main-hide-until-tomorrow = 隱藏到明天
main-quit-companion = 關閉桌面夥伴

## dialogs (dialogs.ts)

dialogs-folder-on-this-computer = 這台電腦上的資料夾

## dom (dom.ts)

dom-text = { $name }：{ $reason }
dom-keep-all = 保留全部變更
dom-chosen-by-you = 由你選擇
dom-address-copied = 已複製網址。
dom-the-browser-did-not = 這裡不允許複製；請選取文字後按 Ctrl+C

## edit-form (edit-form.ts)

edit-form-from-to = 從 { $least } 到 { $most }
edit-form-a-whole-number-from = 不小於 { $least } 的整數

## load (figures/load.ts)

load-this-figure-has-no = Cardwave 無法讓這個 3D 形象動起來。為 Mixamo、VRChat、Unity 或 Ready Player Me 製作的形象可以。

## format (format.ts)

format-today = 今天
format-comma = 、
format-day-at = { $day } { $time }
format-yesterday = 昨天
format-kb = { $kb } KB
format-seconds = { $seconds } 秒

## downloaded (models/downloaded.ts)

downloaded-set-up = 設定
downloaded-text = { $action }{ $toLowerCase }
downloaded-local = 在這台電腦上

## fit-models (models/fit-models.ts)

fit-models-cancel = 取消 { $name }
fit-models-download = 下載 { $name }
fit-models-model-menu-delete = 模型選單：刪除 { $name }
fit-models-delete-this-model = 從這台電腦刪除這個模型？將釋放 { $size }。
fit-models-gb-of-memory = { $round } GB 主記憶體 · { $folder }
fit-models-downloading = { $fits } · 正在下載 { $percent }%
fit-models-downloaded = { $fits } · 已下載
fit-models-model-deleted = 已刪除模型「{ $name }」。

## images-setup (models/images-setup.ts)

images-setup-image-model = 圖像模型
images-not-set-up = 你的角色的圖片 · 未設定

## kinds (models/kinds.ts)

kinds-chat-model = 聊天模型
kinds-models-from-all-your = 你所有供應商中會寫文字的模型。你選的那個負責寫聊天，不論它來自哪個供應商。
kinds-models-from-all-your-2 = 你所有供應商中會寫文字的模型。你選的那個就是輔助模型，不論它來自哪個供應商。
kinds-images-model = 圖像模型
kinds-models-from-all-your-3 = 你所有供應商中會產生圖片的模型。你選的那個負責產生圖片，不論它來自哪個供應商。
kinds-search-model = 搜尋模型
kinds-models-on-this-computer = 這台電腦上和你所有供應商中依意思尋找文字的模型。你選的那個負責搜尋，不論它來自哪裡。
kinds-models-on-this-computer-2 = 這台電腦上和你所有供應商中朗讀訊息的模型。你選的那個負責朗讀訊息，不論它來自哪裡。
kinds-loading-models = 正在載入模型……
kinds-couldnt-load-the-models = 無法載入模型。
kinds-search-the-models = 搜尋模型
kinds-use-this-model = 使用這個模型
kinds-model = 模型
kinds-type-unknown = { " " }· 不確定能否做到
kinds-address = { " " }· { $address }
kinds-this-computer = 這台電腦上的程式
kinds-asking-the-provider = 正在詢問供應商……
kinds-own-on-this-computer = { $own } · 在這台電腦上
kinds-none-of-the-kind = 你的供應商都沒有能做這件事的模型。

## language-line (models/language-line.ts, settings/app-language.ts)

language-line-taken-from-this-computer = 與這台電腦相同，直到你另選一種
language-line-follows-the-app = 跟隨應用程式的語言，直到你更改為止

## models-group (models/models-group.ts)

models-group-not-configured = 未設定
models-group-no-longer-offered = 你的服務商已不再提供此模型：請另選一個。

## provider-form (models/provider-form.ts)

provider-form-a-key-is-saved = 已儲存一個金鑰
provider-form-asking-the-provider-for = 正在向供應商詢問它的模型……
provider-form-the-provider-lists-no = 供應商沒有列出任何模型。請依供應商網站上的寫法準確輸入模型的名稱。
provider-form-text = { $action }{ $what }
provider-form-test-passed = { " " }· 測試通過
provider-form-testing = { " " }· 正在測試……
provider-form-is-saved = ····{ $key_end } 已儲存
provider-form-or-type-the-models = { $listedCount }{ $have }。也可以依供應商網站上的寫法準確輸入模型的名稱。
provider-form-test-failed = 測試失敗：{ $failed }。請檢查金鑰和位址。

## search-setup (models/search-setup.ts)

search-setup-not-downloaded = 未下載
search-setup-ready = 就緒
search-setup-on-this-computer-download = { $name } · 在這台電腦上 · 下載 { $bytes }
search-setup-the-librarys-search-then = 之後，資料庫的搜尋就能依角色的內容找到角色，不只是比對字詞。
search-setup-reading-cards-left = { " " }· 正在讀取角色，剩下 { $left } 個
search-setup-reading-cards-left-2 = 正在讀取角色 · 剩下 { $left } 個

## find (shell/find.ts)

find-pages = 頁面
find-page = 頁面

## search-panel (shell/search-panel.ts)

search-panel-nothing-found-for = 找不到「{ $asked }」的結果。
search-panel-show-all = 顯示全部 { $count } 個
search-panel-open-in-a-new = 在新分頁中開啟
search-panel-what = 角色、聊天、世界書、記憶、文件和頁面
search-panel-not-messages = 不會搜尋訊息內容；試試搜尋聊天的角色。

## advanced (views/advanced.ts)

advanced-sillytavern-v3 = SillyTavern V3
advanced-ccv4 = Character Card V4

## chat (views/chat.ts)

chat-your-next-message-starts = 你的下一則訊息會從標記的訊息開始換個走向。
chat-this-chat-is-in = 這個聊天在垃圾桶中。還原它即可繼續寫。
chat-hide-side-panel = 隱藏側邊面板
chat-show-side-panel = 顯示側邊面板
chat-show-card-editor = 顯示角色頁面
chat-set-up-a-model = 設定模型
chat-the-characters-keep-replying = 角色正在自己持續回覆：第 { $asked } / { $talk_replies } 則。

## chats (views/chats.ts)

chats-last-message = 最後一則訊息
chats-date-started = 開始日期
chats-no-chats-yet = 還沒有聊天。
chats-search-chats = 搜尋聊天
chats-couldnt-load = 無法載入你的聊天。
chats-chat-character-or-card = 尋找聊天或角色
chats-with = 與 { $others }
chats-from = 在角色中名為 { $join }

## coding-task (views/coding-task.ts)

coding-task-checkpoints = 復原點
coding-task-put-the-folder-back = 要把資料夾還原到「{ $toLowerCase }」嗎？
coding-task-none-yet = 還沒有
coding-task-changed-files = 已變更的檔案
coding-task-text = { " " }· { $stepSays }
coding-task-team-started = { $folder } · { $team }團隊 · 開始於 { $format } ·{ " " }
coding-task-steps = 步驟
coding-task-undone = { $detail } · 已復原

## documents (views/documents.ts)

documents-no-documents-yet-a = 還沒有文件。在這裡新增，或在聊天中附加。
documents-what-they-are = AI 回答時會讀這些檔案：角色的檔案用於與它的每個聊天，聊天的檔案用於該聊天。
documents-found-by-meaning-once = 設定好搜尋後，AI 會依意義找到合適的部分。
documents-set-up-search = 在設定中設定搜尋
documents-no-document-found = 找不到文件。
documents-search-documents = 搜尋文件
documents-name-chat-or-character = 名稱、聊天或角色
documents-document-deleted = 文件已刪除。
documents-for-the-character = 屬於角色{ " " }
documents-for-the-chat = 屬於聊天{ " " }

## memories (views/memories.ts)

memories-nothing-remembered-yet = 還沒有任何記憶。
memories-come-from-chats = 記憶來自你的聊天：每 20 則訊息，Cardwave 會留下每個角色應該記住的事。你可以在這裡修改或刪除它們。
memories-no-memory-found = 找不到記憶。
memories-search-memories = 搜尋記憶
memories-text-chat-or-character = 文字、聊天或角色
memories-known-by = 知道的人
memories-known-by-hint = 聊天中誰知道這件事並可能提起它。
memories-you = 你
memories-you-alone = 你
memories-edit-memory = 編輯記憶
memories-memory-deleted = 記憶已刪除。
memories-from-the-chat = { " " }· 來自聊天{ " " }
memories-from-your-chat-with = { " " }· 來自你與此角色的聊天：{ " " }
memories-because = 因為{ $end }
memories-so = 所以{ $end }

## dictation-setup (voice/dictation-setup.ts)

dictation-setup-on-this-computers-graphics = { $name } · 在這台電腦的顯示卡上 · { $bytes }
dictation-setup-the-microphone-beside-the = 之後，訊息框旁的麥克風會把你說的話寫下來，支援中文、英文等多種語言。你說的話只留在這台電腦上。

## make-voice (voice/make-voice.ts)

make-voice-my-voice = 我的聲音
make-voice-make-voice = 製作語音
make-voice-choose-a-file = 選擇檔案
make-voice-record = 錄音
make-voice-play-back = 播放
make-voice-record-again = 重新錄音
make-voice-the-recording-is-too = 錄音太短：至少要 { $SHORTEST } 秒。
make-voice-cardwave-cant-read-choose = Cardwave 無法讀取「{ $name }」。請選擇 WAV 或 MP3 檔案。
make-voice-recording = 錄音
make-voice-a-short-recording-of = 一段一個人清楚說話的短錄音：10 到 { $LONGEST } 秒。WAV 或 MP3。
make-voice-use-only-a-voice = 只使用你有權使用的聲音：你自己的，或擁有者同意使用的。
make-voice-give-the-voice-a = 為這個語音取個名字。

## voice-setup (voice/voice-setup.ts)

voice-setup-made-from-your-recording = 由你的錄音製作
voice-setup-on-this-computer-download = 在這台電腦上 · 下載 { $bytes }
voice-setup-play-a-sample-of = 播放 { $name } 的試聽
voice-setup-stop-the-sample-of = 停止 { $name } 的試聽
voice-setup-messages-are-read-aloud = 訊息會在這台電腦上以英文朗讀。
voice-setup-use-this-voice = 使用這個語音
voice-setup-hello-im-this-is = 你好，我是 { $name }。你的訊息被朗讀時，聽起來就是這樣。

## voice (voice/voice.ts)

voice-the-voice-stopped-answering = 語音沒有回應了。請再試一次，或在 設定 › 語音 中選擇其他語音。
voice-this-window-cannot-play = 此視窗無法播放聲音：{ $reason }。請檢查 Windows 的聲音輸出。

## Written by hand: plurals, conditions and numbers

client-backup-failed = 無法建立備份。請確認該資料夾可以寫入，然後再試一次。
composer-tokens-of = { NUMBER($used, useGrouping: "auto") } / { NUMBER($size, useGrouping: "auto") } 個 token
header-chat = 聊天
header-chat-archived = 聊天已封存。
header-chat-unarchived = 聊天已從封存中移回。
messages-tokens = { $count ->
   *[other] { NUMBER($count, useGrouping: "auto") } 個 token
  }
dom-texts-changed-by-ai = { $count ->
   *[other] { $count } 段文字
  }已由 AI 修改
format-days-ago = { $count ->
   *[other] { $count } 天前
  }
format-weeks-ago = { $count ->
   *[other] { $count } 週前
  }
format-months-ago = { $count ->
   *[other] { $count } 個月前
  }
format-years-ago = { $count ->
   *[other] { $count } 年前
  }
format-mb = { NUMBER($mb, minimumFractionDigits: 1, maximumFractionDigits: 1) } MB
format-gb = { NUMBER($gb, minimumFractionDigits: 1, maximumFractionDigits: 1) } GB
fit-models-fits = { $size } · 可在這台電腦上執行
fit-models-too-large = { $size } · 對這台電腦來說太大
fit-models-used-for = { $fits } · 用於{ $kinds }
provider-form-models = { $count ->
   *[other] { NUMBER($count, useGrouping: "auto") } 個模型
  }
provider-form-listed = 列出了 { $count ->
   *[other] { NUMBER($count, useGrouping: "auto") } 個模型
  }
provider-form-listed-not-all = 列出了 { $count ->
   *[other] { NUMBER($count, useGrouping: "auto") } 個模型
  }；其餘的無法載入
provider-form-have = ；其中 { NUMBER($count, useGrouping: "auto") } 個包含「{ $part }」
coding-task-verdict-passed = 審查者的結論：通過
coding-task-verdict-not-passed = 審查者的結論：未通過
documents-words = { $count ->
   *[other] { NUMBER($count, useGrouping: "auto") } 字
  }
memories-known-by-everyone = 所有角色都知道
memories-known-by-these = { $names } 知道
memories-known-by-nobody = 沒有角色知道
lore-tools-entries-changed-by-ai = { $count ->
   *[other] { $count } 個條目
  }已由 AI 修改
coding-failed-with-error = 失敗：{ $error }
coding-planner-doing = 規劃者：{ $what }
coding-step-doing = 第 { $begun } / { $planned } 步 · { $who }：{ $what }
coding-worker = 執行者 { $number }
coding-plans = 規劃步驟
coding-planned = { $steps ->
   *[other] 已規劃 { $steps } 個步驟
  }
coding-fixes = 修正審查者發現的問題
coding-checks-step = 檢查第 { $step } 步
coding-checks-all = 檢查每一步並執行測試
coding-verdict-tests = { $said } · { $tests }
coding-show-plan = 顯示計畫
coding-before-step = 第 { $step } 步之前
coding-before-fix = 修正之前
coding-looking-at-folder = 正在查看資料夾
coding-looking-at = 正在查看 { $target }
coding-reading = 正在讀取 { $target }
coding-writing = 正在寫入 { $target }
coding-running-command = 正在執行：{ $target }
coding-installing = 正在安裝：{ $target }
coding-searching-web = 正在搜尋網路：{ $target }
coding-files = { $files ->
   *[other] { $files } 個檔案
  }
coding-no-files-changed = 沒有變更任何檔案
coding-lines-files = { $lines } · { $files }
messages-copy-refused = 這裡不允許複製；請選取文字後按 Ctrl+C
panel-book-persona = 使用者角色
panel-book-every-chat = 每個聊天
stats-model = 模型
stats-response-time = 回應時間
stats-context = 上下文
stats-context-says = 已使用 { $used } / { $size } 個 token · 剩餘 { $free }
documents-the-chat = 聊天
models-download-recommended = 依內容尋找角色 · 下載 { $size } · 推薦
models-downloading = { $name } · 正在下載 { $percent }%
models-on-this-computer = { $name } · 這台電腦{ $reading }
voice-setup-voice-download = 朗讀回覆 · { $name }（{ $about }） · 下載 { $size }
voice-setup-downloading = 正在下載 { $percent }%
panel-persona-default = 用於新聊天
panel-who-you-are-in-this-chat = 你在這個聊天中的身分
panel-use-in-this-chat = 在這個聊天中使用
panel-click-a-reply = 點擊一則回覆，查看它用了什麼。
