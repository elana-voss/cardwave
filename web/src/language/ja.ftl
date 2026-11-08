### UIの言葉の日本語版。英語（en.ftl、元のファイル）からキーごとに訳したもの。構造テスト（structure.test.ts）が、
### どのキーも英語と同じ形でここにあることを確かめます。
### 用語集。ひとつのものにひとつの名前、すべての ja.*.ftl で共通:
###   呼びかけ: ユーザーを指す代名詞は書かない（「あなた」は必要なときだけ）。アプリの文は「です・ます」、ボタンとラベルは
###   短い普通形・体言止め（「保存」「削除」「チャットを開く」）。ユーザーの性別は決めない（「彼／彼女」は使わない）。キャラクターや
###   アカウントの名前（{ $name }）も同じ。アプリは自分を「私」と呼ばない: 主語は「Cardwave」か省略。インタビューのAIだけが、
###   英語が「me」と言うところで「私」と言う。ユーザー自身のボタン（「Write for me」「I don't know」）も「私」。
###   日本のユーザーが知っている外来語はカタカナで。Cardwave、MCP、Claude Desktop、CSS、AI、Downtempo、Outrun、Retrowave、
###   Neon Wave はラテン文字のまま。token = トークン; tab = タブ; chat = チャット; message = メッセージ; character = キャラクター;
###   card = カード（キャラクターのファイル）; figure = 3Dフィギュア; persona = ペルソナ; lorebook = ロアブック;
###   memory = 記憶（ページ「記憶」）; document = ドキュメント; library = ライブラリ; knowledge = ナレッジ; account = アカウント;
###   provider = プロバイダー; model = モデル; helper (model) = ヘルパーモデル; tool = ツール; tag = タグ; preset = プリセット
###   （model preset = モデルプリセット、prompt preset = プロンプトプリセット）; prompt = プロンプト; key = キー（APIキー）;
###   Settings = 設定; Advanced = 詳細設定; Trash = ゴミ箱（Cardwaveの）; Recycle Bin = Windowsのごみ箱; backup = バックアップ;
###   back up = バックアップする; restore = 復元; Sharing = 共有; companion = コンパニオン; voice = 音声（ページ「音声」）;
###   read aloud = 読み上げ; dictation = 音声入力; picture = 画像（Images = 画像、image model = 画像モデル）; download = ダウンロード;
###   Showcase = ショーケース; Search Cardwave = Cardwaveを検索; coding team = コーディングチーム; planner = プランナー;
###   worker = ワーカー; auditor = 監査役; task = タスク; sign in/out = サインイン／サインアウト; lock = ロック; import = インポート;
###   export = エクスポート; password = パスワード; interview = インタビュー; generator = キャラクタージェネレーター; theme = テーマ;
###   first run = 初回セットアップ; save = 保存; delete = 削除; edit = 編集; cancel = キャンセル; file = ファイル; folder = フォルダー;
###   search = 検索; version = バージョン; format = 形式; Appearance = 外観; greeting = 挨拶; entry = エントリー; keyword = キーワード。
###   ペルソナのないユーザーの名前（card-user-stand-in、cw_prompt::stand_in_user）: ゲスト（名前として読め、性別がない）。
###   複数形（Intl.PluralRules「ja」）: other のみ。数は「{ $count }件」「{ $count }個」のように助数詞をつける。
###   単語の間にスペースを入れない。句読点は全角「、」「。」、引用は「」（中の引用は『』）、括弧（）、コロン「：」、区切りの
###   英語の「 · 」は「・」、メニューの道筋「 › 」はそのまま、省略「…」。文中のラベル: midSentence。

## The app

app-name = Cardwave

## The pages, as tabs, the rail and Search Cardwave name them (shell/pages.ts)

page-chats = チャット
page-characters = キャラクター
page-lorebooks = ロアブック
page-personas = ペルソナ
page-memories = 記憶
page-documents = ドキュメント
page-generator = キャラクタージェネレーター
page-interview = 一緒にキャラクターを作る
page-profile = プロフィール
page-server = 共有
page-settings = 設定
page-providers = プロバイダー
page-voices = 音声
page-advanced = 詳細設定
page-css = CardwaveのCSS
page-written-tools = AIが書いたツール
page-coding-team = コーディングチーム
page-trash = ゴミ箱
page-about = Cardwaveについて
page-coding-task = コーディングタスク
page-chat = チャット
page-new-card = 新しいキャラクター
page-lorebook = ロアブック
page-card = キャラクター
page-prompt-preset = プロンプトプリセット
page-first-run = Cardwave のセットアップ

## The places pages are under

place-library = ライブラリ
place-knowledge = ナレッジ
place-account = アカウント
place-settings = 設定
place-advanced = 設定 › 詳細設定

## The rail (shell/rail.ts)

rail-create = 作成
rail-memories-tip = 記憶: AI があなたのチャットから覚えていること
rail-documents-tip = ドキュメント: AI が答えるときに読むファイル
rail-show-more = さらに{ $count }件を表示
rail-open-menu = サイドバーを開く
rail-close-menu = サイドバーを閉じる
rail-collapse = サイドバーをたたむ
rail-expand = サイドバーを広げる
rail-account = アカウント
rail-account-named = アカウント：{ $name }
rail-lock = ロック

## Create's lines (shell/create.ts)

create-new-chat = 新しいチャット
create-plain-chat = キャラクターなしのチャット
create-new-card = 新しいキャラクター
create-from-picks = キャラクタージェネレーター
create-together = 一緒にキャラクターを作る
create-new-persona = 新しいペルソナ
create-new-lorebook = 新しいロアブック
create-import-card = カードをインポート
create-import-lorebook = ロアブックをインポート
create-new = 新規
create-import = インポート

## The title bar and its tabs (shell/titlebar.ts)

tabs = タブ
tab-new = 新しいタブ
tab-new-keys = 新しいタブ（Ctrl+T）
tabs-all = すべてのタブ
tab-close = タブを閉じる
window-minimize = 最小化
window-maximize = 最大化
window-close = 閉じる

## The view menu (shell/view-menu.ts, theme.ts)

view = 表示
view-compact = コンパクト
theme-system = システム
theme-light = ライト
theme-dark = ダーク
theme-downtempo = Downtempo
theme-outrun = Outrun
theme-retrowave = Retrowave
theme-neonwave-dark = Neon Wave ダーク
theme-neonwave-light = Neon Wave ライト

## Search Cardwave's button (shell/search-panel.ts)

search = Cardwaveを検索
search-keys = Cardwaveを検索（Ctrl+K）

## The labels of the settings, as their pages and Search Cardwave name them (setting-labels.ts)

label-settings-theme = テーマ
label-settings-chat-layout = チャットのレイアウト
label-settings-web-pictures = 他のウェブサイトの画像を表示
label-settings-app-language = アプリの言語
label-settings-language = AIが書く言語
label-settings-providers = プロバイダー
label-settings-chat = チャット
label-settings-images = 画像
label-settings-voice = 音声
label-settings-search = 検索
label-settings-dictation = 音声入力
label-settings-web = ウェブ
label-settings-files = ファイル
label-settings-commands = コマンド
label-settings-image-generation = 画像生成
label-settings-app = Cardwave
label-settings-dice = サイコロ
label-settings-folder = フォルダー
label-settings-written = AIが書いたツール
label-settings-coding = コーディングチーム
label-settings-trash = ゴミ箱
label-settings-backup = バックアップ
label-settings-restore = 復元
label-settings-cards-folder = カードのフォルダー
label-settings-advanced = 詳細設定
label-settings-setup = セットアップをやり直す
label-settings-about = Cardwaveについて
label-providers-this-computer = このコンピューター
label-voices-model = 音声モデル
label-voices-speed = 速さ
label-voices-english = 英語
label-advanced-background = ヘルパーモデル
label-advanced-told = AIへの指示
label-advanced-describe = インポートしたキャラクターを説明
label-advanced-described = 説明済みのキャラクター
label-advanced-interview = 一緒にキャラクターを作る
label-advanced-format = エクスポートの形式
label-advanced-history = 各テキストの以前のバージョンを含める
label-advanced-css = 自分のCSS
label-coding-planner = プランナー
label-coding-workers = ワーカー
label-coding-auditor = 監査役
label-profile-name = 名前
label-profile-picture = 画像
label-profile-password = パスワード
label-server-network = ホームネットワークからアクセス可能
label-server-address = アドレス
label-server-mcp = このコンピューターの AI アプリに Cardwave を使わせる

layout-bubbles = 吹き出し
layout-plain = プレーン

## Settings (views/settings.ts)

settings-appearance = 外観
settings-theme-about = 選ばない場合はシステムに合わせます
settings-layout-about = メッセージを吹き出しで、またはプレーンテキストで表示
settings-web-pictures-about = チャットを開いたことが、それらのウェブサイトに知られます。
settings-language = 言語
settings-data = データ
settings-trash-about = { $count ->
   *[other] { $count }件
  }・{ $days }日後に削除
settings-open-trash = ゴミ箱を開く
settings-open = 開く
settings-version = バージョン{ $version }・ライセンス
settings-licences = ライセンス
settings-advanced-about = ヘルパーモデル、ライブラリ、エクスポート、キャラクターなしのチャット、サンプリング、プリセット、自分のCSS
settings-setup-about = プロバイダー、モデル、音声を順番に設定
settings-providers-about = モデルを動かすサービスのアドレスとキー
settings-this-computer = このコンピューター
settings-providers-named = 設定済み：{ $names }
settings-models = モデル
settings-the-chat-model = チャットモデル
settings-the-image-model = 画像モデル

## The account's tabs and accounts (shell/account-tabs.ts, settings/accounts.ts)

account-sections = アカウントのセクション
account-switch = アカウントを切り替え

account-password = パスワード
account-switch-to = { $name }に切り替え
account-password-asked = { $name } のパスワードを入力してください。
account-switch-button = 切り替え
account-add = アカウントを追加
account-add-about = このコンピューター上の別の人のアカウントで、チャットとキャラクターは別々です。ここでも別のデバイスでも、そのパスワードでサインインします。
account-name = 名前
account-added = アカウント「{ $name }」を追加しました。
account-add-button = 追加
account-sign-out = サインアウト
account-none = サインインできるアカウントがありません
account-none-about = ここからサインインできるアカウントはまだありません。Cardwave が動いているコンピューターで、アカウント › 共有 から追加してください。
account-this-computer = このコンピューターのアカウント
account-choose = アカウントを選択
account-try-again = もう一度試す
account-back = 戻る
account-sign-in = サインイン

## Backup and Restore (settings/backup.ts)

backup-saving = バックアップを保存しています。
backup-saving-to = バックアップを{ $folder }に保存しています。
backup-password = パスワード
backup-repeat = パスワードをもう一度入力
backup-encrypted = バックアップはこのパスワードで暗号化されます。ここでも別のコンピューターでも、復元にはこのパスワードが必要です。
backup-forgotten = パスワードを忘れると取り戻せず、バックアップも復元できません。
backup-with-password = パスワードつきでバックアップ
backup-differ = 2つのパスワードが一致しません。
backup-back-up = バックアップを保存
backup-no-file = ファイルが選択されていません
backup-choose-file = ファイルを選択
backup-its-password = バックアップのパスワード
backup-restoring = 復元すると、Cardwaveの中身（チャット、キャラクター、ペルソナ、ロアブック、記憶、設定）がすべて置き換えられます。元に戻せません。ここで設定したパスワードはそのまま残ります。 ほかのアカウントも置き換わります。
backup-restored = バックアップを復元しました：Cardwaveのすべてがバックアップ作成時の状態に戻りました。ほかのデバイスはもう一度サインインします。
backup-file = ファイル
backup-restore-title = バックアップを復元
backup-choose-first = 先にバックアップのファイルを選択してください。
backup-restore = バックアップを復元
backup-from-file = バックアップファイルから
backup-about-own = チャット、キャラクター、設定をひとつのファイルに。自分のパスワードで暗号化
backup-about-chosen = チャット、キャラクター、設定をひとつのファイルに。選んだパスワードで暗号化

## The folder of cards (settings/card-folder.ts)

folder-watch = 新しいカードを自動でインポート
folder-watch-about = フォルダーに置いたカードファイルが、自動でライブラリに入ります
folder-recycle = インポートしたファイルをWindowsのごみ箱へ移動
folder-recycle-about = ファイルは取り込まれるとごみ箱に移ります

## The companion's line (library/companion-app.ts)

companion = コンパニオン
# The companion window's name, which the system shows in its lists of windows.
companion-window = Cardwaveコンパニオン
companion-made = { $name }がコンパニオンになりました。
companion-make = コンパニオンにする
companion-none = コンパニオンはまだいません。キャラクターの「…」メニューを開き、「コンパニオンにする」を選んでください。
companion-named = { $name }・アプリと一緒に起動
companion-figure = コンパニオンのフィギュア
companion-figure-about = 自分の3Dフィギュアがないキャラクターに表示
companion-figure-woman = 女性
companion-figure-man = 男性
companion-figure-robot = ロボット
companion-size = コンパニオンの大きさ
companion-size-about = フィギュアの高さ（画面の高さに対する割合）
companion-size-value = { $size }%

## Other programs, MCP (settings/mcp.ts)

mcp-ask-title = このコンピューターの AI アプリに Cardwave を使わせる
mcp-ask = このコンピューターのプログラム（Claude Desktop など）は、キャラクターとチャットを読み、チャットに書き込み、設定 › ツールでオンにしたツールを使えます。Cardwave が先にあなたに尋ねることは、それらにはできません。
mcp-switch-on = オンにする
mcp-about = Claude Desktop など、MCP 経由で：キャラクター、チャット、ツールを使います
mcp-copy-address = MCPのアドレスをコピー
mcp-copy = コピー
mcp-as-account = 使うアカウント
mcp-as-account-about = 見られるものとできること
mcp-remove-named = { $program }を削除
mcp-removed = 「{ $program }」を削除しました。
mcp-remove = 削除
mcp-connected = 接続済み
mcp-other-programs = 他のプログラム
mcp-only-here = 接続できるのはこのコンピューター上のプログラムだけです。削除したプログラムは、これをオフにしてオンに戻すまで接続できません。

## Your own CSS (settings/own-css.ts)

css-none = なし
css-lines = { $count ->
   *[other] { $count }行
  }
css-about = { $lines }・アプリの見た目を変えます
css-hint = 入力したそばから、Cardwave自身のスタイルシートの後に適用されます。「保存」で残し、「キャンセル」で元に戻します。
css-edit-own = 自分のCSSを編集
css-edit = 編集

## The password (settings/password.ts)

password-forgotten = 忘れたパスワードは取り戻せず、チャットとキャラクターも失われます。安全な場所に控えておいてください。
password-on-title = パスワードを設定する
password-on-says = Cardwave は開くときにこれを求めます。これがないと、このコンピューターで誰も Cardwave を開けず、チャットも読めません。
password-on = パスワードを設定
password-on-done = パスワードを設定しました。
password-change-title = パスワードを変更
password-change-says = Cardwaveを開くときに新しいパスワードを求めます。
password-change = 変更
password-change-done = パスワードを変更しました。
password-off-title = パスワードをオフにする
password-off-says = Cardwaveはパスワードを求めずに開きます。チャットとキャラクターは暗号化されたままです。
password-off = オフにする
password-off-done = パスワードをオフにしました。
password-differ = 2つのパスワードが一致しません。
password-other-says = 次からは新しいパスワードでサインインします。
password-other-forgotten = 忘れた場合は、このコンピューターのアカウントが「共有」でリセットできます。
password-current = 現在のパスワード
password-password = パスワード
password-new = 新しいパスワード
password-repeat = パスワードをもう一度入力
password-asked-sign-in = サインイン時に入力
password-is-on = オン・アプリを開くときに入力
password-is-off = オフ・このコンピューターなら誰でも Cardwave を開けます
password-start-forgotten = パスワードを忘れると取り戻せません。
password-open = 開く
password-locked-elsewhere = Cardwaveはそのコンピューターでロックされています。あちらでロックが解除されると、ここでも開きます。
password-back = 戻る

## Words many pages use

common-use = 使う
common-in-use = ・使用中
common-more = その他
common-edit = 編集
common-duplicate = 複製
# The word a copy's name ends in, as in "Rig (copy)".
common-copy-word = コピー
common-delete = 削除
common-save = 保存
common-cancel = キャンセル
common-name = 名前

## Model presets and prompt presets (settings/presets.ts, settings/prompt-presets.ts)

preset-what = プリセットは、チャットモデルとそのサンプリングの値を保存します。「使う」でそれに切り替えます。
preset-temperature = temperature { $value }
preset-new = 新しいプリセット
preset-model-presets = モデルプリセット
preset-using = 「{ $name }」を使用中です。
preset-added = プリセット「{ $name }」を追加しました。
preset-deleted = プリセット「{ $name }」を削除しました。
preset-saved = プリセット「{ $name }」を保存しました。
preset-delete-ask = このプリセットを削除しますか？
preset-replace = 今のモデルと設定を使う
preset-replace-hint = チャットモデル、そのプロバイダー、このページのサンプリング。オフ：プリセットは自分のものを保ちます。
preset-keeps-hint = 設定 › モデルのチャットモデル、そのプロバイダー、このページのサンプリングを保存します。
preset-name = 名前
preset-edit = プリセットを編集
prompt-presets = プロンプトプリセット
prompt-system = システムプロンプト
prompt-note = { $depth ->
   *[other] メモ、{ $depth }件前のメッセージ
}
prompt-system-note = { $depth ->
   *[other] システムプロンプト・メモ、{ $depth }件前のメッセージ
}
prompt-as-card = キャラクターの指定どおり
prompt-default = デフォルト
prompt-default-name = 「{ $name }」はキャラクター自身のプロンプトです。

## Tools (settings/tools.ts, chat/tool-ask.ts)

tools-written-ask = { $count ->
    [0] まだありません
   *[other] { $count }個のツール
  }・新しいツールは実行前に確認
tools-written-free = { $count ->
    [0] まだありません
   *[other] { $count }個のツール
  }・新しいツールは確認なしで実行
tools-folder-first = 先にフォルダーを選択してください
tools-web = ウェブページを検索して読む
tools-files = { $folder }のみ
tools-ask-writes = 書き込む前に確認
tools-ask-writes-says = 各ファイルは書き込む前に表示されます
tools-commands = { $folder }で実行。コンピューターの他の部分とインターネットからは切り離されます
tools-ask-commands = 実行する前に確認
tools-ask-commands-says = 各コマンドは実行する前に表示されます
tools-pictures = 画像モデルを使います
tools-pictures-first = 先に画像モデルを設定してください
tools-app = キャラクター、チャット、設定を使い、変更します。変更はそれぞれ先に確認します
tools-dice = AI がサイコロを振れるようにします。振るのは Cardwave なので結果は公平です。
tools-folder-example = C:\Users\you\Documents\Shared
tools-folder-says = ファイルとコマンドが届くのは、このフォルダーとその中身だけです。
tools-change-folder = フォルダーを変更
tools-change = 変更
tools-choose = 選択
tools-none-chosen = 未選択
tools-title = ツール
tools-ask-new = { $name }が新しいツールを使おうとしています：{ $what }
tools-ask-write = { $name }がフォルダーに「{ $what }」を書き込もうとしています：
tools-ask-read = { $name }がフォルダーの中を読もうとしています：
tools-ask-install = { $name } が必要なプログラムをダウンロードしてインストールしようとしています:
tools-ask-web = { $name }がウェブを使おうとしています：
tools-ask-app = { $name }がCardwaveを変更しようとしています：
tools-ask-command = { $name }がフォルダーでコマンドを実行しようとしています：
tools-allow = 許可
tools-deny = 拒否
tools-allow-writing = このチャットでファイルの書き込みを許可
tools-allow-commands = このチャットでコマンドを許可

## Updates (settings/update.ts)

update-title = アップデートを確認
update-available = Cardwave { $version }が利用できます
update-you-have = 現在のバージョンは{ $version }です。
update-up-to-date = Cardwaveは最新です（{ $version }）。
update-connection-error = アップデートを確認できませんでした。接続を確認してください。
update-check-failed = アップデートを確認できませんでした：GitHub から最新バージョンの情報が返ってきませんでした。
update-whats-new = 新機能
update-close = 閉じる
update-ok = OK
update-download = ダウンロード
update-install = アップデートして再起動
update-installing = Cardwave { $version }をダウンロードしています…
update-auto = 自動で確認
update-auto-about = 起動時と1日1回、新しいバージョンを探します
update-check = 確認
update-checking = 確認中…
update-about = アプリの新しいバージョンがあるか確認します。

## The breadcrumbs of a page under Settings

crumbs = 現在の場所

## Providers (views/providers.ts)

providers-key-end = { $where }・キー ····{ $end }
providers-key-saved = { $where }・キー保存済み
providers-no-key = { $where }・キーなし
providers-thinking-cannot = { $provider }はこのモデルの思考をオフにできません
providers-thinking-off = モデルは考えずに返信します
providers-thinking-on = モデルは返信する前に考えます
providers-comfy-default = ComfyUIのデフォルト
providers-workflow-note = このワークフローは画像モデルではなく、自分のモデルとサイズを使います。
providers-testing-model = モデルをテストしています…
providers-thinking-of = { $label }：思考
providers-thinking = 思考
providers-testing-workflow = ワークフローをテストしています…
providers-workflows-from = ComfyUIにあるワークフローから
providers-pictures-by = 「{ $name }」で作る画像。
providers-pictures-default = ComfyUIのデフォルトのワークフローで作る画像。
providers-workflow = ワークフロー
providers-not-used = まだ何にも使われていません
providers-folder-saved = フォルダーを保存しました。
providers-change-folder = モデルのフォルダーを変更
providers-choose-folder = モデルのフォルダーを選択
providers-change = 変更
providers-not-set-up = 未設定
providers-folder-not-set-up = このコンピューターのフォルダーにあるモデルを動かします・未設定
providers-menu = プロバイダーのメニュー：編集、削除
providers-remove = 削除
providers-removed = プロバイダー「{ $name }」を削除しました。
providers-remove-with-models = このプロバイダーを削除しますか？ここから選んだモデルは使われなくなります。
providers-remove-ask = このプロバイダーを削除しますか？
providers-remove-key = キーを削除
providers-key-removed = 保存するとキーが削除されます
providers-edit = プロバイダーを編集
providers-keep-key = 保存済みのキーを残すには空欄のままにしてください。
providers-saved = プロバイダー「{ $name }」を保存しました。
providers-added = プロバイダー「{ $name }」を追加しました。
providers-add = プロバイダーを追加
providers-about = AI が動く場所：インターネット上のサービスか、このコンピューターのプログラムです。それぞれの下に、何に使われているかが表示されます。

## Voices (views/voices.ts)

voices-stop = { $name }を停止
voices-try = { $name }を試す
voices-model-about = このコンピューターでメッセージを読み上げます・{ $size }
voices-default-of = デフォルトの音声：{ $name }
voices-menu = 音声のメニュー：名前を変更、削除
voices-rename = 名前を変更
voices-delete-ask = 声「{ $name }」を削除しますか？この声を使うキャラクターは標準の声に戻ります。
voices-rename-title = 音声の名前を変更
voices-name = 名前
voices-speed-value = { $speed }×
voices-speed = 速さ
voices-speed-about = 返信を読み上げる速さ。すべての音声に共通
voices-make = 録音から音声を作る
voices-provider-failed = プロバイダーの音声を読み込めませんでした。
voices-provider-none = プロバイダーが音声を公開していません
voices-provider-own = メッセージはプロバイダー自身の声で読み上げられます。
voices-voices = 音声
voices-voices-about = メッセージを読み上げる音声です。キャラクターごとの音声は「キャラクターの音声」で設定できます。
voices-default = デフォルトの音声
voices-voice-of = { $name }の音声
voices-back-default = デフォルトの音声に戻す
voices-name-title = { $name }・{ $title }
voices-choose-character = キャラクターを選択
voices-all-have = すべてのキャラクターに音声があります。
voices-set-for = キャラクターの音声を設定
voices-character = キャラクター
voices-voice = 音声
voices-character-first = 先にキャラクターを選択してください。
voices-characters = キャラクターの音声
voices-downloading = ダウンロード中・{ $size }・{ $percent }%
voices-downloaded = ダウンロード済み・{ $size }
voices-download-size = { $size }のダウンロード
voices-action-of = { $name }：{ $action }
voices-language-downloaded = { $name }をダウンロードしました
voices-built-in = 内蔵
voices-languages = 読み上げる言語
voices-download = ダウンロード
voices-cancel = キャンセル
voices-delete = 削除

## Advanced (views/advanced.ts)

advanced-context-size = コンテキストのサイズ（トークン）
advanced-context-hint = 空欄なら 128,000
advanced-temperature = Temperature
advanced-temperature-about = 高いほど意外な返事になります。0 から 2 まで
advanced-top-p = Top P
advanced-top-p-about = 低いほど最もありそうな語だけを使います。0 から 1 まで
advanced-frequency = Frequency penalty
advanced-frequency-about = 高いほど同じ語の繰り返しが減ります。−2 から 2 まで
advanced-presence = Presence penalty
advanced-presence-about = 高いほど新しい話題が増えます。−2 から 2 まで
advanced-seed = シード
advanced-seed-about = 同じ数なら同じ返事がもう一度出ます
advanced-from-to = { $min }〜{ $max }
advanced-whole-from = { $min }以上の整数
advanced-whole = 整数
advanced-number = 数値
advanced-sampling = サンプリング
advanced-sampling-about = チャットモデル用。プロバイダーのデフォルトを使うには空欄のままにしてください。入力するとすぐ保存されます。
advanced-describing = 説明を作成中…残り{ $count }件
advanced-all-described = すべてのキャラクターに説明があります
advanced-not-described = { $count ->
   *[other] { $count }人のキャラクター
  }にまだ説明がありません
advanced-describe-cards = キャラクターに説明をつける
advanced-describe-cost = { $count ->
   *[other] { $count } 人のキャラクター
  }で約 { $low }〜{ $high } トークン
advanced-failed = { $count ->
   *[other] { $count }件が失敗
  }：{ $failure }。もう一度試すには「キャラクターに説明をつける」を押してください。
advanced-describe-again = すべて説明し直す
advanced-describe-again-stop = 停止
advanced-describe-again-about = ヘルパーモデルで各キャラクターの一行説明、要約、タグ、「ニーズ別」で見つけるための内容を書き直します。1 人あたり約 11,000〜12,000 トークン。自分で編集した部分はそのまま残ります。 トークンはプロバイダーの課金単位です。
advanced-no-characters = 説明するキャラクターがありません
advanced-describe-again-far = { $all }件中{ $done }件を説明し直しました
advanced-describe-again-stopped = { $all }件中{ $done }件を説明し直したところで止めました
advanced-describe-again-failed = { $count ->
   *[other] { $count }件が失敗し、元のままです
  }：{ $failure }。もう一度試すには「すべて説明し直す」を押してください。
advanced-describe-about = それぞれのひとこと紹介、要約、タグをヘルパーモデルが書きます
advanced-plain = キャラクターなしのチャット
advanced-told-about = キャラクターのいないすべてのチャットで共通です。{ "{{date}}" } または { "{{time}}" } と書くと、AI に今日の日付または時刻が渡されます
advanced-library = ライブラリ
advanced-interview-about = AIがあなたに質問する方法
advanced-interview-tree = ツリー
advanced-interview-cloud = クラウド
advanced-interview-hybrid = ハイブリッド
advanced-data = データ
advanced-format-about = エクスポートがすべてのカードを書き出す形式。ほとんどのアプリは SillyTavern V3 を開けます
advanced-history-about = 各テキストの以前の版。Cardwave 独自のカード形式のときのみ
advanced-helper = ヘルパーモデル
advanced-the-helper = ヘルパーモデル

## Cardwave's CSS (views/css-reference.ts)

cssref-rail = 左のレール
cssref-main = レールの横の画面
cssref-crumbs = ページ上部の道筋
cssref-group = 設定にあるような、行をまとめた枠
cssref-item = 枠の中の1行
cssref-row = リストの1行
cssref-tile = ライブラリのグリッドのカード
cssref-msg = チャットのメッセージ
cssref-bubble = メッセージの吹き出し
cssref-composer = チャットの下のメッセージ欄
cssref-dialog = ダイアログ
cssref-btn-primary = 青いボタン
cssref-switch = スイッチ
cssref-pill = ピル
cssref-notice = ウィンドウ下部のお知らせ
cssref-snippet-green = 緑のアクセント
cssref-snippet-square = 四角い吹き出し
cssref-snippet-larger = 大きめの文字
cssref-snippet-wider = 幅の広いダイアログ
cssref-snippet-tighter = 詰めた余白
cssref-snippet-black = 黒いダークテーマ
cssref-in-dark = { $light }・ダークでは{ $dark }
cssref-none = その名前の変数はありません。
cssref-copy-of = 「{ $title }」をコピー
cssref-copied = コピーしました。
cssref-copy = コピー
cssref-about-1 = 自分のCSSで使える変数とクラス名です。アプリの色とサイズはすべて、
cssref-about-2 = の変数で、ライトとダークの値があります。
cssref-variables = 変数
cssref-search = 検索
cssref-find = 変数を探す
cssref-all = 変数は全部で{ $count }個です。
cssref-classes = クラス名
cssref-snippets = スニペット

## Tools the AI wrote (views/written-tools.ts)

written-about = { $what }・{ $made }に作成
written-about-in = { $what }・{ $made }に{ $chat }で作成
written-used = { $count ->
    [0] 未使用
   *[other] { $count }回使用
  }
written-none = ツールはまだありません。チャットで「AIにツールを書かせる」をオンにすると、書いたものがここに並びます。
written-ask = 新しいツールを実行する前に確認
written-ask-about = ツールごとに一度だけ：初めて動くときに許可します
written-in = 、チャット：
written-made = 作成：{ $made }
written-dot-used = ・{ $used }
written-switch-off = オフにする
written-switch-on = オンにする
written-intro = 「AIにツールを書かせる」がオンのチャットで AI が自分用に書いた小さなツールです。許可しない限りファイルには触れず、後のチャットのために残ります。
written-deleted = ツール「{ $name }」を削除しました。
written-on = { $name }：オン
written-view-code = コードを見る

## The coding team, shared by the chat and its pages (chat/coding.ts)

coding-quick = 速さ優先
coding-balanced = バランス
coding-thorough = 念入り
coding-custom = カスタム
coding-running = 実行中
coding-done = 完了
coding-failed = 失敗
coding-stopped = 停止
coding-team-says-alone = { $name }：プランナー1人、{ $workers ->
    [1] ワーカー1人
    [2] ワーカー2人
   *[other] ワーカー3人
  }、監査役なし。
coding-team-says-tests = { $name }：プランナー1人、{ $workers ->
    [1] ワーカー1人
    [2] ワーカー2人
   *[other] ワーカー3人
  }、テストを実行する監査役。
coding-team-says-steps = { $name }：プランナー1人、{ $workers ->
    [1] ワーカー1人
    [2] ワーカー2人
   *[other] ワーカー3人
  }、各ステップを確認してテストを実行する監査役。
coding-team-label = { $name }・{ $workers ->
   *[other] ワーカー{ $workers }人
  }
coding-team-label-auditor = { $name }・{ $workers ->
   *[other] ワーカー{ $workers }人
  }、監査役
coding-team-label-steps = { $name }・{ $workers ->
   *[other] ワーカー{ $workers }人
  }、ステップごとの監査役
coding-tests-pass = { $total }件中{ $passed }件のテストに合格
coding-passed = 合格
coding-problems = 問題あり

## Coding team (views/coding-team.ts)

team-audit-end = 最後に
team-audit-each = 各ステップの後
team-audit-never = しない
team-change = 変更
team-workers-of = { $model }・同時に { $workers }
team-worker-model = ワーカーのモデル
team-change-worker = ワーカーのモデルを変更
team-how-many = ワーカーの人数
team-none = なし
team-auditor-tests = { $model }・テストを実行
team-auditor-steps = { $model }・各ステップを確認
team-auditor-model = 監査役のモデル
team-change-auditor = 監査役のモデルを変更
team-when = 監査役が確認するタイミング
team-team = チーム
team-roles = 役割
team-planner-model = プランナーのモデル
team-change-planner = プランナーのモデルを変更
team-recent = 最近のタスク
team-intro = このコンピューターで力を合わせてプログラムを書く AI たち。チャットから始めます。
team-no-tasks = タスクはまだありません。タスクはチャットで、メッセージ欄の横の「+」›「コーディングタスクを開始」から始めます。

## Trash (views/trash.ts)

trash-expressions = 表情・どのキャラクターにも使われていません
trash-figure = 3Dフィギュア・どのキャラクターにも使われていません
trash-chat-with = { $names }とのチャット
trash-chat = チャット
trash-persona = ペルソナ
trash-persona-used = ペルソナ・{ $count ->
   *[other] { $count }件のチャット
  }で使用
trash-lorebook = ロアブック
trash-lorebook-used = ロアブック・{ $count ->
   *[other] { $count }件のチャット
  }で使用
trash-character = キャラクター
trash-character-chats = キャラクター・チャット{ $count ->
   *[other] { $count }件
  }
trash-empty = ゴミ箱は空です。
trash-about = ここに移したものは{ $days }日間保管され、その後完全に削除されます。
trash-emptied = ゴミ箱を空にしました。
trash-empty-trash = ゴミ箱を空にする
trash-delete-all-ask = { $count ->
   *[other] { $count }件すべて
  }を完全に削除しますか？
trash-restored = 「{ $title }」を復元しました。
trash-deleted = 「{ $title }」を完全に削除しました。
trash-deleted-at = { $when }にここへ移動
trash-days-left = { $count ->
   *[other] 残り{ $count }日
  }
trash-restore = 復元
trash-restore-chats = キャラクターと{ $count ->
   *[other] その{ $count }件のチャット
  }を元に戻します
trash-delete-forever = 完全に削除
trash-delete-forever-ask = 「{ $title }」を完全に削除しますか？元に戻すことはできません。
trash-delete-forever-ask-chats = 「{ $title }」と{ $count ->
   *[other] その{ $count }件のチャット
  }を完全に削除しますか？元に戻すことはできません。

## About Cardwave (views/about.ts)

about-no-package = その名前のパッケージはありません。
about-no-notes = このバージョンにはノートがありません。
about-by = 作者：{ $by }
about-licence-of = { $name }のライセンス
about-licence = ライセンス
about-folder-failed = フォルダーを開けませんでした: { $reason }。場所は { $where } です。
about-open-folder = フォルダーを開く
about-logs-where = Cardwave が動いているコンピューターの、Cardwave のデータフォルダー内の「logs」フォルダー
about-logs = ログ
about-logs-about = Cardwave の動作とクラッシュの記録。1 日 1 ファイル、7 日間保存。問題が起きたときの手がかりに · { $where }
about-version = バージョン{ $version }
about-whats-new = 新機能
about-packages = { $count }個のパッケージ
about-open-source = オープンソースソフトウェア
about-search = 検索
about-find = パッケージを探す
about-version-built = バージョン{ $version }・{ $built }
about-models = モデル
about-figures = フィギュアとアニメーション
about-voices = 音声
about-voice-donations = 寄付された声
about-voice-acted-by = 声の出演：{ $name }
about-voice-vctk = CSTR VCTK Corpus（Junichi Yamagishi、Christophe Veaux、Kirsten MacDonald、University of Edinburgh）の話者 { $speaker }、Kyutai がクリーニング
about-voice-cml-tts = CML-TTS（Frederico S. Oliveira、Edresson Casanova、Arnaldo Candido Junior、Anderson S. Soares、Arlindo R. Galvão Filho）の話者 { $speaker }、LibriVox のための朗読
about-voice-cml-tts-cleaned = CML-TTS（Frederico S. Oliveira、Edresson Casanova、Arnaldo Candido Junior、Anderson S. Soares、Arlindo R. Galvão Filho）の話者 { $speaker }、LibriVox のための朗読、Kyutai がクリーニング
about-lists = プロバイダーとモデルのリスト

about-or = または
about-and = および
about-with = と

## Prompt preset (views/prompt-preset.ts)

prompt-new = 新しいプロンプトプリセット
promptpage-system = システムプロンプト
prompt-system-about = カードのシステムプロンプトの代わりに使われます。カードのものを残すには空欄のままにしてください。
promptpage-note = メモ
prompt-note-about = AI は返信のたびにこれを読みます。チャットには表示されません。下で設定した数だけ前のメッセージの位置に入ります。
prompt-depth = 何件前のメッセージか
prompt-intro = AI への指示です。チャットのサイドパネルでこのプリセットを選ぶと、そこで使われます。
prompt-depth-about = 1 なら最新のメッセージの直前、4 なら 4 つ前です。
prompt-saved = プリセット「{ $name }」を保存しました。
prompt-gone = このプロンプトプリセットは削除されました。戻って別のものを選んでください。

## Profile (views/profile.ts)

profile-change-picture = 画像を変更
profile-change = 変更
profile-remove-picture = 画像を削除
profile-remove = 削除
profile-picture-changed = 画像を変更しました。
profile-picture-removed = 画像を削除しました。
profile-your-picture = 自分の画像
profile-no-picture = 画像なし：頭文字 { $letter } が表示されます
profile-change-name = 名前を変更
profile-this-computer = このコンピューターのアカウント
profile-on-server = このコンピューター上のアカウント
profile-account = アカウント

## Server (views/server.ts)

server-copy = コピー
server-no-network = このコンピューターはネットワークにつながっていません。ほかの端末から入れるように、Wi-Fi かケーブルでつないでください。
server-switch-on-about = このネットワーク上のスマートフォンや他のコンピューターから、Cardwaveを開けるようになります。各アカウントはそれぞれのパスワードでサインインします。
server-switch-on = オンにする
server-network-about = スマートフォンや他のコンピューターから、ブラウザーでCardwaveを開きます
server-other-devices = 他のデバイス
server-inside = ルーターで外部からの接続を許可しない限り、このネットワーク内の機器だけが接続できます。
server-add-account = アカウントを追加
server-owner = このコンピューター・アカウントを追加・削除できます
server-more-of = その他：{ $name }
server-reset-password = パスワードをリセット
server-delete-account = アカウントを削除
server-deleted = アカウント「{ $name }」を削除しました。
server-delete-ask = このアカウントをキャラクター、チャット、設定ごと削除しますか？元に戻せません。
server-reset-title = { $name }のパスワードをリセット
server-reset-about = アカウントは新しいパスワードでサインインし、サインイン中のすべての場所でサインアウトされます。
server-new-password = 新しいパスワード
server-reset-done = { $name }のパスワードをリセットしました。
server-reset = リセット
server-accounts = アカウント

## Character generator (views/generator.ts)

gen-gender-woman = 女性
gen-gender-man = 男性
gen-gender-non-binary = ノンバイナリー
gen-being-human = 人間
gen-being-not-human = 人間以外
gen-age-20s = 20代
gen-age-30s = 30代
gen-age-40s = 40代
gen-age-50s-and-older = 50代以上
gen-build-slim = 細身
gen-build-average = 普通
gen-build-athletic = 引き締まった体
gen-build-strong = がっしり
gen-hair-short = ショート
gen-hair-medium = ミディアム
gen-hair-long = ロング
gen-colour-black = 黒
gen-colour-brown = 茶
gen-colour-blonde = 金
gen-colour-red = 赤
gen-colour-grey = グレー
gen-colour-white = 白
gen-relation-stranger = 見知らぬ人
gen-relation-friend = 友達
gen-relation-partner = パートナー
gen-relation-rival = ライバル
gen-relation-colleague = 同僚
gen-relation-mentor = メンター
gen-shy = 内気
gen-outgoing = 社交的
gen-gentle = 穏やか
gen-harsh = きつい
gen-serious = まじめ
gen-playful = 遊び心がある
gen-cautious = 慎重
gen-bold = 大胆
gen-random = ランダム
gen-slider = { $low }〜{ $high }
gen-looks = 見た目
gen-gender = 性別
gen-being = 人間かどうか
gen-any = 指定なし
gen-age = 年齢
gen-build = 体型
gen-hair = 髪
gen-hair-colour = 髪の色
gen-personality = 性格
gen-relates = キャラクターはあなたにとって誰か
gen-make = キャラクターを作る
gen-what = いくつか特徴を選ぶと、AI がキャラクターの最初のメッセージと話し方を書きます。
interview-goes-to = キャラクターを書くために、回答は{ $provider }に送られます。
interview-stays = 回答はこのコンピューターから出ません。
interview-own-words = または自分の言葉を足す
interview-in-own-words = 自分の言葉で
interview-your-answer = 回答
interview-pick-one = 1つ選ぶ
interview-pick-two = 1つか2つ選ぶ
interview-pick-three = 3つまで選ぶ
interview-pick-many = 当てはまるものをいくつでも
interview-few-words = ひとことで十分です
interview-wanted-hint = 人との関係や、試したキャラクターに、何が足りませんでしたか？
interview-needs-hint = キャラクターと過ごす時間のことで、生活全体のことではありません
interview-next = 次へ
interview-skip = スキップ
interview-dont-know = わからない
interview-back = 戻る
interview-just-make-it = このまま作って
interview-more = ほかの種類
interview-writing-next = 次の質問を書いています
interview-try-again = もう一度試す
interview-failed-where = 失敗が続くときは、設定 › プロバイダーでプロバイダーとモデルを確かめてください。
gen-stop = 停止
gen-writing = キャラクターを書いています…
interview-understood = 私が理解したのはこういうことです。
interview-you-said = 回答：「{ $words }」
interview-own-guess = AIの推測
interview-keep = 残す
interview-change = 変更
interview-remove = 削除
interview-not-it = そうじゃない
interview-not-it-off = この行は、もう一度聞ける1つの質問にもとづいていません
interview-own-sentence = 自分の言葉で書いた文
interview-private-line = あなたのキャラクターの世界にあってほしいもの、絶対にあってほしくないものはありますか？
interview-private-sub = 恋愛、暴力、汚い言葉など · 任意
interview-make = キャラクターを作る
interview-make-after = あとからそのページで変えられます。
interview-skip-all = すべてスキップ
interview-private-hint = キャラクターの世界にこうしたものを望む人もいれば、望まない人もいます。回答はこのキャラクターとともにこのコンピューターに保存され、キャラクターを書くAIにだけ送られます。
interview-private-free = その他、あってほしいもの、絶対にあってほしくないもの
interview-yes = はい
interview-no = いいえ
interview-maybe = たぶん
interview-fantasy-only = 空想の中だけ
interview-never = 絶対にいや
interview-try-another = 別のモデルを試す
interview-without-topic = その話題なしで書く
interview-model-provider = { $model }・{ $provider }
interview-reading = 回答を読んでいます
interview-persona-title = あなた自身について話したことをペルソナに追加しますか？
interview-persona-field = ペルソナ
interview-persona-in-use = { $persona }・使用中
interview-persona-new = 新しいペルソナ
interview-persona-add = 追加
interview-persona-not-now = 今はしない
interview-persona-added = 「{ $persona }」に追加しました。
interview-persona-you = あなた
