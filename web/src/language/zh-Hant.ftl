### 介面文字的繁體中文（臺灣）版，逐條譯自英文（en.ftl，原始檔案），不是由簡體轉換而來。結構測試（structure.test.ts）檢查每個鍵都在這裡，且形式與英文相同。
### 詞彙表。一樣東西一個名字，所有 zh-Hant.*.ftl 通用：
###   用臺灣軟體的用語（蘋果、Google、LINE 的臺灣中文版），與簡體版（zh-Hans）不同的有：檔案（文件）、資料夾（文件夾）、設定（設置）、
###   軟體、程式（程序）、預設、帳號（帳戶）、連線、訊息（消息）、分頁（標籤頁）、垃圾桶（廢紙簍）、
###   資源回收筒（回收站）、供應商（服務商）、金鑰（密鑰）、進階（高級）、匯入／匯出（導入／導出）、搜尋（搜索）、儲存（保存）、
###   還原（恢復）、登入／登出（登錄／退出登錄）、聽寫（語音輸入）、預設集（預設）、自訂（自定義）、選單（菜單）、視窗（窗口）、
###   螢幕（屏幕）、網路（網絡）、伺服器（服務器）、使用者（用戶）、影片（視頻）、資訊（信息）、支援（支持）、程式設計（編程）、
###   產生器（生成器）、關鍵字（關鍵詞）、桌面夥伴（桌面伙伴）。
###   稱呼：使用者稱「你」，不用「您」：蘋果、Google 和 LINE 的臺灣中文介面都用「你」，「您」是銀行和客服的口吻，對個人聊天應用太生硬；
###   全篇一致。不預設使用者的性別：使用者不用「他／她」，改寫句子避開；角色和帳號的名字（{ $name }）也一樣，用「它」或重複名字。
###   應用不自稱「我」：主語是「Cardwave」或省略。只有訪談中的 AI 在英文說「me」的地方自稱「我」；使用者自己的按鈕（「Write for me」
###   「I don't know」）也用「我」（「幫我寫」「我不知道」）。按鈕和標籤用簡短的動賓或名詞（「儲存」「刪除」「開啟聊天」）。
###   Cardwave、MCP、Claude Desktop、CSS、AI、API、token、Downtempo、Outrun、Retrowave、Neon Wave 保留拉丁字母。
###   tab = 分頁；chat = 聊天；message = 訊息；character = 角色；card = 角色卡（角色的檔案）；figure = 3D 形象；
###   persona = 使用者角色（SillyTavern 臺灣中文版的用詞，與「角色」分得清楚；「人設」在臺灣多指作品角色的設定）；
###   lorebook = 世界書（SillyTavern 等角色聊天應用的中文社群，臺灣也這麼叫）；memory = 記憶（頁面「記憶」）；document = 文件；
###   library = 資料庫；knowledge = 知識；account = 帳號；provider = 供應商；model = 模型；helper (model) = 輔助模型；tool = 工具；
###   tag = 標籤；preset = 預設集（模型預設集、提示詞預設集）；prompt = 提示詞；key = 金鑰（API 金鑰）；Settings = 設定；Advanced = 進階；
###   Trash = 垃圾桶（Cardwave 的）；Recycle Bin = Windows 資源回收筒（總帶「Windows」以示區別）；backup = 備份；restore = 還原；
###   Sharing = 共享；companion = 桌面夥伴；voice = 語音（頁面「語音」）；read aloud = 朗讀；dictation = 聽寫；
###   picture = 圖片（Images = 圖片，image model = 圖像模型）；download = 下載；Showcase = 展示；Search Cardwave = 搜尋 Cardwave；
###   coding team = 程式設計團隊；planner = 規劃者；worker = 執行者；auditor = 審查者；task = 任務；sign in/out = 登入／登出；
###   lock = 鎖定；import = 匯入；export = 匯出；password = 密碼；interview = 訪談；generator = 角色產生器；theme = 主題；
###   first run = 初始設定；save = 儲存；delete = 刪除；edit = 編輯；cancel = 取消；file = 檔案；folder = 資料夾；search = 搜尋；
###   version = 版本；format = 格式；Appearance = 外觀；greeting = 開場白；entry = 條目；keyword = 關鍵字；Your own CSS = 自訂 CSS。
###   沒有使用者角色的使用者的名字（card-user-stand-in、cw_prompt::stand_in_user）：訪客（在句中讀作名字，沒有性別）。
###   複數（Intl.PluralRules「zh」）：只有 other。數字帶量詞（「{ $count } 個」「{ $count } 行」「{ $count } 天」）。
###   句中用全形標點（，。：？！（））；引號用臺灣的「」，引號內再引用用『』；省略號「……」。漢字與拉丁字母、數字之間空一格
###   （同蘋果的臺灣中文介面和簡體版），與全形標點之間不空；占位符按其內容：名字、數字、版本、路徑（{ $name }、{ $count }）兩側
###   同樣空一格，裝中文詞句的（{ $what }、{ $why }）不空。並列的名字用頓號「、」連接（format-comma），分隔「 · 」，選單路徑「 › 」。

## The app

app-name = Cardwave

## The pages, as tabs, the rail and Search Cardwave name them (shell/pages.ts)

page-chats = 聊天
page-characters = 角色
page-lorebooks = 世界書
page-personas = 使用者角色
page-memories = 記憶
page-documents = 文件
page-generator = 角色產生器
page-interview = 一起建立角色
page-profile = 個人資料
page-server = 共享
page-settings = 設定
page-providers = 供應商
page-voices = 語音
page-advanced = 進階
page-css = Cardwave 的 CSS
page-written-tools = AI 寫的工具
page-coding-team = 程式設計團隊
page-trash = 垃圾桶
page-about = 關於 Cardwave
page-coding-task = 程式設計任務
page-chat = 聊天
page-new-card = 新角色
page-lorebook = 世界書
page-card = 角色
page-prompt-preset = 提示詞預設集
page-first-run = 設定 Cardwave

## The places pages are under

place-library = 資料庫
place-knowledge = 知識
place-account = 帳號
place-settings = 設定
place-advanced = 設定 › 進階

## The rail (shell/rail.ts)

rail-create = 建立
rail-memories-tip = 記憶：AI 從你的聊天中記住的內容
rail-documents-tip = 文件：AI 回答時會讀取的檔案
rail-show-more = 再顯示 { $count } 個
rail-open-menu = 打開側邊欄
rail-close-menu = 關閉側邊欄
rail-collapse = 收合側邊欄
rail-expand = 展開側邊欄
rail-account = 帳號
rail-account-named = 帳號：{ $name }
rail-lock = 鎖定

## Create's lines (shell/create.ts)

create-new-chat = 新聊天
create-plain-chat = 不帶角色聊天
create-new-card = 新角色
create-from-picks = 角色產生器
create-together = 一起建立角色
create-new-persona = 新使用者角色
create-new-lorebook = 新世界書
create-import-card = 匯入角色卡
create-import-lorebook = 匯入世界書
create-new = 新增
create-import = 匯入

## The title bar and its tabs (shell/titlebar.ts)

tabs = 分頁
tab-new = 新分頁
tab-new-keys = 新分頁（Ctrl+T）
tabs-all = 所有分頁
tab-close = 關閉分頁
window-minimize = 最小化
window-maximize = 最大化
window-close = 關閉

## The view menu (shell/view-menu.ts, theme.ts)

view = 顯示
view-compact = 緊湊
theme-system = 跟隨系統
theme-light = 淺色
theme-dark = 深色
theme-downtempo = Downtempo
theme-outrun = Outrun
theme-retrowave = Retrowave
theme-neonwave-dark = Neon Wave 深色
theme-neonwave-light = Neon Wave 淺色

## Search Cardwave's button (shell/search-panel.ts)

search = 搜尋 Cardwave
search-keys = 搜尋 Cardwave（Ctrl+K）

## The labels of the settings, as their pages and Search Cardwave name them (setting-labels.ts)

label-settings-theme = 主題
label-settings-chat-layout = 聊天版面
label-settings-web-pictures = 顯示其他網站的圖片
label-settings-app-language = 應用程式的語言
label-settings-language = AI 寫作的語言
label-settings-providers = 供應商
label-settings-chat = 聊天
label-settings-images = 圖片
label-settings-voice = 語音
label-settings-search = 搜尋
label-settings-dictation = 聽寫
label-settings-web = 網路
label-settings-files = 檔案
label-settings-commands = 指令
label-settings-image-generation = 圖片生成
label-settings-app = Cardwave
label-settings-dice = 骰子
label-settings-folder = 資料夾
label-settings-written = AI 寫的工具
label-settings-coding = 程式設計團隊
label-settings-trash = 垃圾桶
label-settings-backup = 備份
label-settings-restore = 還原
label-settings-cards-folder = 角色卡資料夾
label-settings-advanced = 進階
label-settings-setup = 重新執行初始設定
label-settings-about = 關於 Cardwave
label-providers-this-computer = 這台電腦
label-voices-model = 語音模型
label-voices-speed = 速度
label-voices-english = 英語
label-advanced-background = 輔助模型
label-advanced-told = AI 收到的指示
label-advanced-describe = 描述匯入的角色
label-advanced-described = 已描述的角色
label-advanced-interview = 一起建立角色
label-advanced-format = 匯出格式
label-advanced-history = 包含每段文字的早期版本
label-advanced-css = 自訂 CSS
label-coding-planner = 規劃者
label-coding-workers = 執行者
label-coding-auditor = 審查者
label-profile-name = 名字
label-profile-picture = 圖片
label-profile-password = 密碼
label-server-network = 在家用網路中可連線
label-server-address = 位址
label-server-mcp = 讓這台電腦上的 AI 應用程式使用 Cardwave

layout-bubbles = 氣泡
layout-plain = 純文字

## Settings (views/settings.ts)

settings-appearance = 外觀
settings-theme-about = 跟隨系統，除非你選一個
settings-layout-about = 訊息以氣泡或純文字顯示
settings-web-pictures-about = 你開啟聊天時，那些網站會知道。
settings-language = 語言
settings-data = 資料
settings-trash-about = { $count ->
   *[other] { $count } 個項目
  } · { $days } 天後清空
settings-open-trash = 開啟垃圾桶
settings-open = 開啟
settings-version = 版本 { $version } · 授權條款
settings-licences = 授權條款
settings-advanced-about = 輔助模型、資料庫、匯出、不帶角色聊天、取樣、預設集、自訂 CSS
settings-setup-about = 供應商、模型和語音，一步一步設定
settings-providers-about = 執行模型的服務的位址和金鑰
settings-this-computer = 這台電腦
settings-providers-named = 已設定：{ $names }
settings-models = 模型
settings-the-chat-model = 聊天模型
settings-the-image-model = 圖像模型

## The account's tabs and accounts (shell/account-tabs.ts, settings/accounts.ts)

account-sections = 帳號的分區
account-switch = 切換帳號

account-password = 密碼
account-switch-to = 切換到 { $name }
account-password-asked = 請輸入 { $name } 的密碼。
account-switch-button = 切換
account-add = 新增帳號
account-add-about = 這台電腦上另一個人的帳號，有自己的聊天和角色。它用自己的密碼登入，在這裡或在其他裝置上皆可。
account-name = 名字
account-added = 已新增帳號「{ $name }」。
account-add-button = 新增
account-sign-out = 登出
account-none = 沒有可登入的帳號
account-none-about = 目前還沒有帳號能從這裡登入。請在執行 Cardwave 的電腦上，到「帳號 › 共享」中新增一個。
account-this-computer = 這台電腦的帳號
account-choose = 選擇你的帳號
account-try-again = 再試一次
account-back = 返回
account-sign-in = 登入

## Backup and Restore (settings/backup.ts)

backup-saving = 正在儲存備份。
backup-saving-to = 正在將備份儲存到 { $folder }。
backup-password = 密碼
backup-repeat = 再次輸入密碼
backup-encrypted = 備份以這個密碼加密；還原時需要這個密碼，在這裡或在其他電腦上都一樣。
backup-forgotten = 忘記的密碼無法找回，沒有密碼就無法還原備份。
backup-with-password = 以密碼備份
backup-differ = 兩次輸入的密碼不同。
backup-back-up = 儲存備份
backup-no-file = 未選擇檔案
backup-choose-file = 選擇檔案
backup-its-password = 備份的密碼
backup-restoring = 還原會取代 Cardwave 中的一切：聊天、角色、使用者角色、世界書、記憶和設定。此操作無法復原。這裡設定的密碼保持不變。
backup-file = 檔案
backup-restore-title = 還原備份
backup-choose-first = 請先選擇備份檔案。
backup-restore = 還原備份
backup-save = 儲存備份
backup-from-file = 從備份檔案
backup-about-own = 聊天、角色和設定存成一個檔案，以你的密碼加密
backup-about-chosen = 聊天、角色和設定存成一個檔案，以你選擇的密碼加密

## The folder of cards (settings/card-folder.ts)

folder-watch = 自動匯入新的角色卡
folder-watch-about = 放進資料夾的角色卡檔案會自動進入你的資料庫
folder-recycle = 將已匯入的檔案移到 Windows 資源回收筒
folder-recycle-about = 檔案匯入後會移到資源回收筒

## The companion's line (library/companion-app.ts)

companion = 桌面夥伴
# The companion window's name, which the system shows in its lists of windows.
companion-window = Cardwave 桌面夥伴
companion-made = { $name } 現在是你的桌面夥伴。
companion-make = 設為桌面夥伴
companion-none = 還沒有桌面夥伴。打開角色的「…」選單，選擇「設為桌面夥伴」。
companion-named = { $name } · 隨應用程式啟動
companion-figure = 桌面夥伴形象
companion-figure-about = 用於沒有自己 3D 形象的角色
companion-figure-woman = 女性
companion-figure-man = 男性
companion-figure-robot = 機器人
companion-size = 桌面夥伴大小
companion-size-about = 形象的高度，以螢幕高度的百分比表示
companion-size-value = { $size }%

## Other programs, MCP (settings/mcp.ts)

mcp-ask-title = 讓這台電腦上的 AI 應用程式使用 Cardwave
mcp-ask = 這台電腦上的程式（例如 Claude Desktop）可以讀取你的角色和聊天、在你的聊天中寫入，並使用在設定 › 工具中開啟的工具。Cardwave 會先問你的事，它們做不到。
mcp-switch-on = 開啟
mcp-about = 例如 Claude Desktop，透過 MCP：它們會使用你的角色、聊天和工具
mcp-copy-address = 複製 MCP 位址
mcp-copy = 複製
mcp-as-account = 以哪個帳號
mcp-as-account-about = 它們能看到和做的事
mcp-remove-named = 移除 { $program }
mcp-removed = 已移除「{ $program }」。
mcp-remove = 移除
mcp-connected = 已連線
mcp-other-programs = 其他程式
mcp-only-here = 只有這台電腦上的程式可以連線。已移除的程式會一直被擋在外面，直到你把這項關閉再開啟。

## Your own CSS (settings/own-css.ts)

css-none = 無
css-lines = { $count ->
   *[other] { $count } 行
  }
css-about = { $lines } · 改變應用程式的外觀
css-hint = 在 Cardwave 自身的樣式表之後套用，隨輸入即時生效。「儲存」保留它；「取消」撤回。
css-edit-own = 編輯自訂 CSS
css-edit = 編輯

## The password (settings/password.ts)

password-forgotten = 忘記的密碼無法找回，你的聊天和角色也會隨之遺失。請把它保存在安全的地方。
password-on-title = 設定密碼
password-on-says = Cardwave 開啟時會要求輸入它。沒有它，任何人都無法在這台電腦上開啟 Cardwave 或讀取你的聊天。
password-on = 設定密碼
password-on-done = 已設定密碼。
password-change-title = 變更密碼
password-change-says = Cardwave 開啟時會要求輸入新密碼。
password-change = 變更
password-change-done = 已變更密碼。
password-off-title = 關閉密碼
password-off-says = Cardwave 開啟時將不再要求密碼。你的聊天和角色仍保持加密。
password-off = 關閉
password-off-done = 已關閉密碼。
password-differ = 兩次輸入的密碼不同。
password-other-says = 從那時起，用新密碼登入。
password-other-forgotten = 如果忘了密碼，這台電腦的帳號可以在「共享」中重設它。
password-current = 目前的密碼
password-password = 密碼
password-new = 新密碼
password-repeat = 再次輸入密碼
password-asked-sign-in = 登入時詢問
password-is-on = 開啟 · 應用程式開啟時詢問
password-is-off = 關閉 · 這台電腦前的任何人都能開啟 Cardwave
password-start-forgotten = 忘記的密碼無法找回。
password-open = 開啟
password-back = 返回

## Words many pages use

common-use = 使用
common-in-use = { " " }· 使用中
common-more = 更多
common-edit = 編輯
common-duplicate = 複製一份
# The word a copy's name ends in, as in "Rig (copy)".
common-copy-word = 副本
common-delete = 刪除
common-save = 儲存
common-cancel = 取消
common-name = 名字

## Model presets and prompt presets (settings/presets.ts, settings/prompt-presets.ts)

preset-what = 預設集會儲存一個聊天模型及其取樣值。「使用」會切換到它。
preset-temperature = 溫度 { $value }
preset-new = 新預設集
preset-model-presets = 模型預設集
preset-using = 正在使用「{ $name }」。
preset-added = 已新增預設集「{ $name }」。
preset-deleted = 已刪除預設集「{ $name }」。
preset-saved = 已儲存預設集「{ $name }」。
preset-delete-ask = 要刪除這個預設集嗎？
preset-replace = 使用目前的模型和設定
preset-replace-hint = 聊天模型、它的提供者和本頁的取樣。關閉：預設保留自己的。
preset-keeps-hint = 它保留「設定 › 模型」中的聊天模型、它的供應商和本頁的取樣。
preset-name = 名字
preset-edit = 編輯預設集
prompt-presets = 提示詞預設集
prompt-system = 系統提示詞
prompt-note = { $depth ->
   *[other] 註記，往前 { $depth } 則訊息
}
prompt-system-note = { $depth ->
   *[other] 系統提示詞 · 註記，往前 { $depth } 則訊息
}
prompt-as-card = 依角色
prompt-default = 預設
prompt-default-name = 「{ $name }」是角色自己的提示詞。

## Tools (settings/tools.ts, chat/tool-ask.ts)

tools-written-ask = { $count ->
    [0] 還沒有
   *[other] { $count } 個工具
  } · 新工具執行前先詢問
tools-written-free = { $count ->
    [0] 還沒有
   *[other] { $count } 個工具
  } · 新工具不經詢問直接執行
tools-folder-first = 請先選擇資料夾
tools-web = 搜尋並閱讀網頁
tools-files = 僅限 { $folder }
tools-ask-writes = 寫入前先詢問
tools-ask-writes-says = 每個檔案寫入前都會先給你看
tools-commands = 在 { $folder } 中執行，與電腦其他部分和網際網路隔絕
tools-ask-commands = 執行前先詢問
tools-ask-commands-says = 每個指令執行前都會先給你看
tools-pictures = 使用圖像模型
tools-pictures-first = 請先設定圖像模型
tools-app = 使用和變更你的角色、聊天和設定；每項變更都先詢問
tools-dice = 讓 AI 擲骰子；由 Cardwave 來擲，結果公平。
tools-folder-example = C:\Users\you\Documents\Shared
tools-folder-says = 檔案和指令只能觸及這個資料夾及其內容，別的都不行。
tools-change-folder = 變更資料夾
tools-change = 變更
tools-choose = 選擇
tools-none-chosen = 未選擇
tools-title = 工具
tools-ask-new = { $name } 想使用一個新工具：{ $what }
tools-ask-write = { $name } 想在你的資料夾中寫入「{ $what }」：
tools-ask-read = { $name } 想讀取你資料夾中的內容：
tools-ask-install = { $name } 想要下載並安裝它需要的程式：
tools-ask-web = { $name } 想使用網路：
tools-ask-app = { $name } 想變更 Cardwave：
tools-ask-command = { $name } 想在你的資料夾中執行指令：
tools-allow = 允許
tools-deny = 拒絕
tools-allow-writing = 在這個聊天中允許寫入檔案
tools-allow-commands = 在這個聊天中允許執行指令

## Updates (settings/update.ts)

update-title = 檢查更新
update-available = Cardwave { $version } 已推出
update-you-have = 你目前的版本是 { $version }。
update-up-to-date = Cardwave 已是最新版本（{ $version }）。
update-connection-error = 無法檢查更新。請檢查你的網路連線。
update-whats-new = 新功能
update-close = 關閉
update-ok = 好
update-download = 下載
update-install = 更新並重新啟動
update-installing = 正在下載 Cardwave { $version }……
update-auto = 自動檢查
update-auto-about = 啟動時和每天一次檢查新版本
update-check = 檢查
update-about = 檢查是否有更新版本的應用程式。

## The breadcrumbs of a page under Settings

crumbs = 目前位置

## Providers (views/providers.ts)

providers-key-end = { $where } · 金鑰 ····{ $end }
providers-key-saved = { $where } · 已儲存金鑰
providers-no-key = { $where } · 沒有金鑰
providers-thinking-cannot = { $provider } 無法為這個模型關閉思考
providers-thinking-off = 模型不先思考就回覆
providers-thinking-on = 模型先思考再回覆
providers-comfy-default = ComfyUI 的預設
providers-workflow-note = 這個工作流程使用自己的模型和尺寸，而不是「圖片」中的模型。
providers-testing-model = 正在測試模型……
providers-thinking-of = { $label }：思考
providers-thinking = 思考
providers-testing-workflow = 正在測試工作流程……
providers-workflows-from = 從 ComfyUI 中的工作流程
providers-pictures-by = 圖片由「{ $name }」產生。
providers-pictures-default = 圖片由 ComfyUI 的預設工作流程產生。
providers-workflow = 工作流程
providers-not-used = 尚未用於任何功能
providers-folder-saved = 已儲存資料夾。
providers-change-folder = 變更模型資料夾
providers-choose-folder = 選擇模型資料夾
providers-change = 變更
providers-not-set-up = 未設定
providers-folder-not-set-up = 執行這台電腦上某個資料夾裡的模型 · 未設定
providers-menu = 供應商選單：編輯、移除
providers-remove = 移除
providers-removed = 已移除供應商「{ $name }」。
providers-remove-with-models = 移除此提供者？從它選用的模型將不再使用。
providers-remove-ask = 要移除這個供應商嗎？
providers-remove-key = 移除金鑰
providers-key-removed = 儲存時會移除金鑰
providers-edit = 編輯供應商
providers-keep-key = 留空即保留已儲存的金鑰。
providers-saved = 已儲存供應商「{ $name }」。
providers-added = 已新增供應商「{ $name }」。
providers-add = 新增供應商
providers-about = AI 在哪裡執行：網路上的服務，或這台電腦上的程式。每一項下面寫著它用來做什麼。

## Voices (views/voices.ts)

voices-stop = 停止 { $name }
voices-try = 試聽 { $name }
voices-model-about = 在這台電腦上朗讀訊息 · { $size }
voices-default-of = 預設語音：{ $name }
voices-menu = 語音選單：重新命名、刪除
voices-rename = 重新命名
voices-delete-ask = 刪除聲音「{ $name }」？使用它的角色將改回預設聲音。
voices-rename-title = 重新命名語音
voices-name = 名字
voices-speed-value = { $speed }×
voices-speed = 速度
voices-speed-about = 回覆朗讀的速度，適用於所有語音
voices-make = 用錄音製作語音
voices-provider-failed = 無法載入供應商的語音。
voices-provider-none = 供應商沒有列出語音
voices-provider-own = 訊息用提供者自己的聲音朗讀。
voices-voices = 語音
voices-voices-about = 朗讀訊息的語音。角色可以在「角色的語音」中有自己的語音。
voices-default = 預設語音
voices-voice-of = { $name } 的語音
voices-back-default = 改回預設語音
voices-name-title = { $name } · { $title }
voices-choose-character = 選擇角色
voices-all-have = 每個角色都有語音了。
voices-set-for = 為角色設定語音
voices-character = 角色
voices-voice = 語音
voices-character-first = 請先選擇角色。
voices-characters = 角色的語音
voices-downloading = 正在下載 · { $size } · { $percent }%
voices-downloaded = 已下載 · { $size }
voices-download-size = 下載 { $size }
voices-action-of = { $action } { $name }
voices-language-downloaded = 已下載 { $name }
voices-built-in = 內建
voices-languages = 它朗讀的語言
voices-download = 下載
voices-cancel = 取消
voices-delete = 刪除

## Advanced (views/advanced.ts)

advanced-context-size = 上下文大小（token）
advanced-context-hint = 留空即為 128,000
advanced-temperature = 溫度
advanced-temperature-about = 越高，回覆越出人意料。從 0 到 2
advanced-top-p = Top P
advanced-top-p-about = 越低，越只用最可能的詞。從 0 到 1
advanced-frequency = 頻率懲罰
advanced-frequency-about = 越高，重複的詞越少。從 −2 到 2
advanced-presence = 存在懲罰
advanced-presence-about = 越高，新話題越多。從 −2 到 2
advanced-seed = 種子
advanced-seed-about = 同一個數字會再次給出同樣的回覆
advanced-from-to = 從 { $min } 到 { $max }
advanced-whole-from = 從 { $min } 起的整數
advanced-whole = 整數
advanced-number = 數字
advanced-sampling = 取樣
advanced-sampling-about = 用於聊天模型。某個值留空即使用供應商的預設值。隨輸入自動儲存。
advanced-describing = 正在描述……還剩 { $count } 張
advanced-all-described = 每個角色都已描述
advanced-not-described = { $count ->
   *[other] { $count } 個角色
  }尚未描述
advanced-describe-cards = 描述角色
advanced-describe-cost = { $count ->
   *[other] { $count } 個角色
  }約需 { $low } 至 { $high } 個 token
advanced-failed = { $count ->
   *[other] { $count } 張失敗
  }：{ $failure }。按「描述角色」再試一次。
advanced-describe-again = 全部重新描述
advanced-describe-again-stop = 停止
advanced-describe-again-about = 用輔助模型重寫每個角色的一句話描述、摘要、標籤，以及「依需求」用來找到它的內容，每個約 11,000 到 12,000 個 token。你自己編輯過的內容保留。 供應商按 token 計費。
advanced-no-characters = 沒有要描述的角色
advanced-describe-again-far = 已重新描述 { $done } / { $all }
advanced-describe-again-stopped = 已停止：已重新描述 { $done } / { $all }
advanced-describe-again-failed = { $count ->
   *[other] { $count } 張失敗，維持原樣
  }：{ $failure }。按「全部重新描述」再試一次。
advanced-describe-about = 每個角色的一句話簡介、摘要和標籤，由輔助模型撰寫
advanced-plain = 不帶角色聊天
advanced-told-about = 在每個沒有角色的聊天中都相同。寫下 { "{{date}}" } 或 { "{{time}}" }，AI 就會得到今天的日期或時間
advanced-library = 資料庫
advanced-interview-about = AI 如何向你提問
advanced-interview-tree = 樹狀
advanced-interview-cloud = 雲狀
advanced-interview-hybrid = 混合
advanced-data = 資料
advanced-format-about = 匯出時每張卡片所用的格式；大多數應用程式都能開啟 SillyTavern V3
advanced-history-about = 每段文字的早期版本；僅限 Cardwave 自己的卡片格式
advanced-helper = 輔助模型
advanced-the-helper = 輔助模型

## Cardwave's CSS (views/css-reference.ts)

cssref-rail = 左側欄
cssref-main = 側欄旁的畫面
cssref-crumbs = 頁面頂端的路徑
cssref-group = 一組行的方框，如設定中所見
cssref-item = 方框中的一行
cssref-row = 清單中的一行
cssref-tile = 資料庫格狀檢視中的一張卡片
cssref-msg = 聊天中的一則訊息
cssref-bubble = 訊息的氣泡
cssref-composer = 聊天下方的訊息欄
cssref-dialog = 對話框
cssref-btn-primary = 藍色按鈕
cssref-switch = 開關
cssref-pill = 膠囊標籤
cssref-notice = 視窗底部的通知
cssref-snippet-green = 綠色強調色
cssref-snippet-square = 方形氣泡
cssref-snippet-larger = 較大的文字
cssref-snippet-wider = 較寬的對話框
cssref-snippet-tighter = 較緊密的間距
cssref-snippet-black = 純黑深色主題
cssref-in-dark = { $light } · 深色時 { $dark }
cssref-none = 沒有這個名稱的變數。
cssref-copy-of = 複製「{ $title }」
cssref-copied = 已複製。
cssref-copy = 複製
cssref-about-1 = 你的自訂 CSS 可以使用的變數和類別名稱。應用程式的每種顏色和尺寸都是{ " " }
cssref-about-2 = { " " }中的一個變數，有淺色和深色兩個值。
cssref-variables = 變數
cssref-search = 搜尋
cssref-find = 尋找變數
cssref-all = 共 { $count } 個變數。
cssref-classes = 類別名稱
cssref-snippets = 程式碼片段

## Tools the AI wrote (views/written-tools.ts)

written-about = { $what } · 建立於 { $made }
written-about-in = { $what } · 建立於 { $made }，聊天：{ $chat }
written-used = { $count ->
    [0] 尚未使用
   *[other] 使用過 { $count } 次
  }
written-none = 還沒有工具。在聊天中開啟「讓 AI 撰寫工具」，它寫的工具會列在這裡。
written-ask = 新工具執行前先詢問
written-ask-about = 每個工具一次：首次執行時由你允許
written-in = ，聊天：
written-made = 建立於 { $made }
written-dot-used = { " " }· { $used }
written-switch-off = 關閉
written-switch-on = 開啟
written-intro = AI 在開啟了「讓 AI 撰寫工具」的聊天中為自己寫的小工具。只有你允許時它們才會動你的檔案，並會留給之後的聊天使用。
written-deleted = 已刪除工具「{ $name }」。
written-on = { $name } 已開啟
written-view-code = 檢視程式碼

## The coding team, shared by the chat and its pages (chat/coding.ts)

coding-quick = 快速
coding-balanced = 平衡
coding-thorough = 徹底
coding-custom = 自訂
coding-running = 執行中
coding-done = 完成
coding-failed = 失敗
coding-stopped = 已停止
coding-team-says-alone = { $name }：一位規劃者、{ $workers ->
    [1] 一位執行者
    [2] 兩位執行者
   *[other] 三位執行者
  }，沒有審查者。
coding-team-says-tests = { $name }：一位規劃者、{ $workers ->
    [1] 一位執行者
    [2] 兩位執行者
   *[other] 三位執行者
  }，以及一位執行測試的審查者。
coding-team-says-steps = { $name }：一位規劃者、{ $workers ->
    [1] 一位執行者
    [2] 兩位執行者
   *[other] 三位執行者
  }，以及一位檢查每一步並執行測試的審查者。
coding-team-label = { $name } · { $workers ->
   *[other] { $workers } 位執行者
  }
coding-team-label-auditor = { $name } · { $workers ->
   *[other] { $workers } 位執行者
  }、審查者
coding-team-label-steps = { $name } · { $workers ->
   *[other] { $workers } 位執行者
  }、每步審查
coding-tests-pass = { $passed } / { $total } 個測試通過
coding-passed = 通過
coding-problems = 發現問題

## Coding team (views/coding-team.ts)

team-audit-end = 最後
team-audit-each = 每一步之後
team-audit-never = 從不
team-change = 變更
team-workers-of = { $model } · 同時 { $workers } 個
team-worker-model = 執行者模型
team-change-worker = 變更執行者模型
team-how-many = 執行者人數
team-none = 無
team-auditor-tests = { $model } · 執行測試
team-auditor-steps = { $model } · 檢查每一步
team-auditor-model = 審查者模型
team-change-auditor = 變更審查者模型
team-when = 審查者何時檢查
team-team = 團隊
team-roles = 角色分工
team-planner-model = 規劃者模型
team-change-planner = 變更規劃者模型
team-recent = 最近的任務
team-intro = 在這台電腦上一起為你編寫程式的 AI，從聊天中啟動。
team-no-tasks = 還沒有任務。任務在聊天中開始：訊息欄旁的「+」› 開始程式任務。

## Trash (views/trash.ts)

trash-expressions = 表情 · 沒有角色使用
trash-figure = 3D 形象 · 沒有角色使用
trash-chat-with = 與 { $names } 的聊天
trash-chat = 聊天
trash-persona = 使用者角色
trash-persona-used = 使用者角色 · 用於 { $count ->
   *[other] { $count } 個聊天
  }
trash-lorebook = 世界書
trash-lorebook-used = 世界書 · 用於 { $count ->
   *[other] { $count } 個聊天
  }
trash-character = 角色
trash-character-chats = 角色 · { $count ->
   *[other] { $count } 個聊天
  }
trash-empty = 垃圾桶是空的。
trash-about = 移到這裡的內容會保留 { $days } 天，之後永久刪除。
trash-emptied = 已清空垃圾桶。
trash-empty-trash = 清空垃圾桶
trash-delete-all-ask = 要永久刪除{ $count ->
   *[other]全部 { $count } 個項目
  }嗎？
trash-restored = 已還原「{ $title }」。
trash-deleted = 已永久刪除「{ $title }」。
trash-deleted-at = 移到這裡於 { $when }
trash-days-left = { $count ->
   *[other] 還剩 { $count } 天
  }
trash-restore = 還原
trash-restore-chats = 還原角色及其{ $count ->
   *[other] { $count } 個聊天
  }
trash-delete-forever = 永久刪除
trash-delete-forever-ask = 永久刪除「{ $title }」？刪除後無法還原。
trash-delete-forever-ask-chats = 永久刪除「{ $title }」及其{ $count ->
   *[other] { $count } 個聊天
  }？刪除後無法還原。

## About Cardwave (views/about.ts)

about-no-package = 沒有這個名稱的套件。
about-no-notes = 這個版本沒有附帶說明。
about-by = 作者：{ $by }
about-licence-of = { $name } 的授權條款
about-licence = 授權條款
about-folder-failed = 資料夾沒有開啟：{ $reason }。它位於 { $where }。
about-open-folder = 開啟資料夾
about-logs-where = 在執行 Cardwave 的電腦上，Cardwave 資料夾中的「logs」資料夾裡
about-logs = 日誌
about-logs-about = Cardwave 的執行紀錄和當機紀錄，每天一個檔案，保留 7 天：出問題時用於求助 · { $where }
about-version = 版本 { $version }
about-whats-new = 新功能
about-packages = { $count } 個套件
about-open-source = 開放原始碼軟體
about-search = 搜尋
about-find = 尋找套件
about-version-built = 版本 { $version } · { $built }
about-models = 模型
about-figures = 形象和動畫
about-voices = 語音
about-lists = 供應商和模型清單

about-or = 或
about-and = 和
about-with = 搭配

## Prompt preset (views/prompt-preset.ts)

prompt-new = 新提示詞預設集
promptpage-system = 系統提示詞
prompt-system-about = 取代角色卡的系統提示詞。留空即保留角色卡的。
promptpage-note = 註記
prompt-note-about = AI 在每次回覆前都會讀它；你在聊天中看不到它。它放在下面設定的往前幾則訊息處。
prompt-depth = 往前幾則訊息
prompt-intro = 給 AI 的指示。在聊天的側邊欄中選擇此預設集，即可在那裡使用。
prompt-depth-about = 1 表示放在最新訊息之前，4 表示往前四則訊息。
prompt-saved = 已儲存預設集「{ $name }」。
prompt-gone = 此提示詞預設已刪除。請返回並另選一個。

## Profile (views/profile.ts)

profile-change-picture = 變更圖片
profile-change = 變更
profile-remove-picture = 移除圖片
profile-remove = 移除
profile-picture-changed = 已變更圖片。
profile-picture-removed = 已移除圖片。
profile-your-picture = 你的圖片
profile-no-picture = 無圖片：顯示你的首字母 { $letter }
profile-change-name = 變更名字
profile-this-computer = 這台電腦的帳號
profile-on-server = 這台電腦上的帳號
profile-account = 帳號

## Server (views/server.ts)

server-copy = 複製
server-no-network = 此電腦未連接網路。請連上 Wi-Fi 或網路線，讓其他裝置能連入。
server-switch-on-about = 開啟後，這個網路中的手機和其他電腦就能開啟 Cardwave。每個帳號用自己的密碼登入。
server-switch-on = 開啟
server-network-about = 手機和其他電腦在瀏覽器中開啟 Cardwave
server-other-devices = 其他裝置
server-inside = 只有這個網路中的裝置能存取，除非你在路由器上設定允許外部存取。
server-add-account = 新增帳號
server-owner = 這台電腦 · 可新增和移除帳號
server-more-of = 更多：{ $name }
server-reset-password = 重設密碼
server-delete-account = 刪除帳號
server-deleted = 已刪除帳號「{ $name }」。
server-delete-ask = 刪除此帳戶及其角色、聊天和設定？此操作無法復原。
server-reset-title = 重設 { $name } 的密碼
server-reset-about = 這個帳號會用新密碼登入，並在所有已登入的地方被登出。
server-new-password = 新密碼
server-reset-done = 已重設 { $name } 的密碼。
server-reset = 重設
server-accounts = 帳號

## Character generator (views/generator.ts)

gen-gender-woman = 女性
gen-gender-man = 男性
gen-gender-non-binary = 非二元性別
gen-being-human = 人類
gen-being-not-human = 非人類
gen-age-20s = 20 多歲
gen-age-30s = 30 多歲
gen-age-40s = 40 多歲
gen-age-50s-and-older = 50 歲以上
gen-build-slim = 纖瘦
gen-build-average = 中等
gen-build-athletic = 健美
gen-build-strong = 壯碩
gen-hair-short = 短
gen-hair-medium = 中長
gen-hair-long = 長
gen-colour-black = 黑色
gen-colour-brown = 棕色
gen-colour-blonde = 金色
gen-colour-red = 紅色
gen-colour-grey = 灰色
gen-colour-white = 白色
gen-relation-stranger = 陌生人
gen-relation-friend = 朋友
gen-relation-partner = 伴侶
gen-relation-rival = 對手
gen-relation-colleague = 同事
gen-relation-mentor = 導師
gen-shy = 害羞
gen-outgoing = 外向
gen-gentle = 溫柔
gen-harsh = 嚴厲
gen-serious = 認真
gen-playful = 愛玩
gen-cautious = 謹慎
gen-bold = 大膽
gen-random = 隨機
gen-slider = { $low } 到 { $high }
gen-looks = 外貌
gen-gender = 性別
gen-being = 是否為人類
gen-any = 不限
gen-age = 年齡
gen-build = 體型
gen-hair = 頭髮
gen-hair-colour = 髮色
gen-personality = 性格
gen-relates = 這個角色對你來說是誰
gen-make = 建立角色
gen-what = 選幾個特點，AI 會寫出角色的第一則訊息和說話方式。
interview-goes-to = 你的回答會傳送到 { $provider } 來撰寫角色。
interview-stays = 你的回答會留在這台電腦上。
interview-own-words = 或補充你自己的話
interview-in-own-words = 用你自己的話
interview-your-answer = 你的回答
interview-pick-one = 選一個
interview-pick-two = 選一到兩個
interview-pick-three = 最多選三個
interview-pick-many = 符合的都可以選
interview-few-words = 幾個詞就夠了
interview-wanted-hint = 和人相處時，或在你試過的角色身上，缺少了什麼？
interview-needs-hint = 是為了你和角色在一起的時光，而不是你生活的其餘部分
interview-next = 下一步
interview-skip = 略過
interview-dont-know = 我不知道
interview-back = 返回
interview-just-make-it = 直接建立
interview-more = 更多類型
interview-writing-next = 正在撰寫下一個問題
interview-try-again = 再試一次
interview-failed-where = 如果一直失敗，請到 設定 › 供應商 查看供應商和模型。
gen-stop = 停止
gen-writing = 正在撰寫角色……
interview-understood = 這是我的理解。
interview-you-said = 你說：「{ $words }」
interview-own-guess = AI 自己的猜測
interview-keep = 保留
interview-change = 變更
interview-remove = 移除
interview-not-it = 不是這樣
interview-not-it-off = 這一行並非來自某個可以重新提問的問題
interview-own-sentence = 你自己的句子
interview-private-line = 在你角色的世界裡，有什麼是你想要的，或絕對不要的？
interview-private-sub = 戀愛、暴力、髒話等 · 選填
interview-make = 建立角色
interview-make-after = 之後可以在它的頁面上修改。
interview-skip-all = 全部略過
interview-private-hint = 有些人希望角色的世界裡有這些，有些人不希望。你的回答與這個角色一起留在你的電腦上，只會傳送給撰寫這個角色的 AI。
interview-private-free = 其他你想要或絕對不要的
interview-yes = 是
interview-no = 否
interview-maybe = 也許
interview-fantasy-only = 僅限幻想
interview-never = 絕不
interview-try-another = 試試另一個模型
interview-without-topic = 不含這個主題撰寫
interview-model-provider = { $model } · { $provider }
interview-reading = 正在閱讀你的回答
interview-persona-title = 把你說的關於自己的內容加到你的使用者角色？
interview-persona-field = 使用者角色
interview-persona-in-use = { $persona } · 使用中
interview-persona-new = 新使用者角色
interview-persona-add = 加入
interview-persona-not-now = 現在不要
interview-persona-added = 已加到「{ $persona }」。
interview-persona-you = 你
