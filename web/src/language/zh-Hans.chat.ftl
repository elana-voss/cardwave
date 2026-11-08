

## card-block (card/card-block.ts)

card-block-text = { $madeBy } · { $under }

## coding (chat/coding.ts)

coding-the-team = AI 团队
coding-open-task = 打开编程任务
coding-undo-all = 全部撤销
coding-put-the-folder-back = 要把文件夹恢复成任务开始前的样子吗？
coding-add-an-export-of = 添加把聊天导出为 Markdown 的功能，并附一个测试。
coding-c-users-you-projects = C:\Users\you\Projects\app
coding-start-a-coding-task = 开始编程任务
coding-start = 开始
coding-goal = 目标
coding-a-checkpoint-is-kept = Cardwave 会在每一步之前保留文件夹的副本，所以每一步都能撤销。

## composer (chat/composer.ts)

composer-whoever-is-named-replies = 被点名的回复
composer-the-character-named-in = 由最新消息中点到名字的角色回复；没有点名时，随机由其他角色中的一个回复。
composer-each-replies-in-turn = 轮流回复
composer-the-characters-reply-one = 角色按侧边栏列出的顺序依次回复。
composer-a-random-one-replies = 随机一个回复
composer-one-of-the-characters = 随机由一个角色回复，但不会是刚说过话的那个。
composer-keep-replying-by-themselves = 角色们自己继续聊
composer-write-for-me = 帮我写
composer-uses-what-you-typed = AI 替你写消息；你输入的内容用来引导它，不会发送出去。
composer-improve = 润色我的消息
composer-rewrites-what-you-typed = 改写你输入的内容
composer-attach-picture-or-document = 附加图片或文档
composer-ai-draws-a-picture = AI 为聊天画一张图；你输入的内容用来引导它
composer-joins-this-chat = 另一个角色加入这个聊天
composer-add-or-write = 附加文件，或让 AI 来写
composer-message = 消息
composer-send = 发送
composer-writing-your-message = 正在撰写你的消息……
composer-who-replies = 谁来回复：{ $says }
composer-writes-every-reply = 每条回复都由 { $name } 来写。
composer-who-replies-group = 谁来回复
composer-joined-the-chat = { $name } 加入了聊天。
composer-message-improved = 消息已润色。
composer-message-written-for-you = 已帮你写好消息。
composer-message-2 = 给 { $whom } 发消息
composer-replies = { $name } 回复

## dictate (chat/dictate.ts)

dictate-dictate = 语音输入
mic-none = 没有找到麦克风：请接上一个，然后再试一次。
mic-not-allowed-desktop = Cardwave 无权使用麦克风：请在 Windows 的隐私设置的“麦克风”中允许。
mic-not-allowed-browser = 此页面无权使用麦克风：请在浏览器中此网站的设置里允许。
mic-not-started = 无法启动麦克风：请关闭正在使用它的其他程序，然后再试一次。
mic-not-offered = 在这个地址上浏览器不提供麦克风：请在运行 Cardwave 的电脑上使用麦克风。
dictate-dictation-failed = 听写失败：{ $reason }。请再试一次。
dictate-writing-what-was-said = 正在把说的话转成文字……
dictate-nothing-was-heard = 没有听到声音。
dictate-stop-dictating = 停止语音输入

## header (chat/header.ts)

header-chat-title = 聊天标题
header-the-title-was-not = 标题没有保存：{ $reason }。请再试一次。
header-automatic = 自动
header-automatic-sub = 根据你写的内容，从下面的模式中选一个
header-new-chat-with-these = 和这些角色开始新聊天
header-new-chat-with = 和{ $name }开始新聊天
header-add-to-favourites = 加入收藏
header-remove-from-favourites = 从收藏中移除
header-chat-options = 聊天选项
header-with = 与 { $join }

## messages (chat/messages.ts)

messages-ai = AI
messages-you = （你）
messages-you-2 = 你
messages-writing = 正在撰写……
messages-message-and-the-after = 已删除这条消息及其后的 { $after }。
messages-message-deleted = 消息已删除。
messages-branch-from-here = 从这里换个走向
messages-edit-message = 编辑消息
messages-stop-reading = 停止朗读
messages-read-aloud = 朗读
messages-message-options = 消息选项
messages-previous-version = 上一个版本
messages-next-version = 下一个版本
messages-write-again = 重新写
messages-continue-reply = 继续写这条回复
messages-version-of = 第 { $at } 版，共 { $count } 版
messages-delete-versions = 删除，连同所有版本（{ $count }）
messages-delete-version = 删除此版本
messages-continue-uses-what-you = 继续这条回复 · 输入框里的话会引导它
messages-generate-reply = 生成回复

## narration (narration.ts)

narration-show-pictures-from-the = 显示网上的图片
narration-a-picture-from-another = 已隐藏一张来自其他网站的图片：加载它会让那个网站知道这个聊天被打开了。
narration-you-can-change-this = 你可以随时在“设置 › 外观”中更改。

## panel (chat/panel.ts)

panel-in-trash = （在废纸篓中）
panel-remove-from-this-chat = 从这个聊天中移除
panel-chat-details = 聊天详情
panel-in-trash-locked = 在废纸篓中：恢复聊天后才能更改。
panel-as-an-assistant = 作为助手时的性格
panel-kept-with-the-character = 随角色保存，用于与这个角色的每个聊天。
panel-memory = 记忆
panel-move-up = 上移
panel-move-down = 下移
panel-in-speaking-order = 按发言顺序
panel-options-for = { $name } 的选项
panel-user = { card-user-stand-in }
panel-new-persona = 新建人设……
panel-from-settings = { $inUse }（来自设置）
panel-default-the-characters-own = 默认（角色自带的）
panel-not-used-this-model = 未使用：这个模型自己决定回复长度
panel-not-used-while-a = AI 使用工具时不使用
panel-tokens-per-reply = 每条回复的 token 数
panel-very-short = 很短
panel-short = 短
panel-medium = 中等
panel-long = 长
panel-very-long = 很长
panel-pause-between-replies = 回复间隔
panel-seconds-when-they-reply = 以秒计；仅在角色们自己聊天时
panel-replies-in-a-row = 连续回复次数
panel-by-themselves-then-they = 自动回复这么多次后停下
panel-reply-length = 回复长度
panel-small-tools-then-kept = AI 可以自己写小程序来查找或计算；这些程序在每个聊天中都能继续使用
panel-the-characters-bring-none = 这些角色没有带世界书。
panel-restore = 恢复
panel-put-back-2 = 放回 { $name }
panel-left-out = 此聊天中不使用
panel-in-trash-2 = 在废纸篓中
panel-used-in-last-reply = 用于上一条回复
panel-used-in-this-reply = 用于这条回复
panel-read-on-the-web = 在网上读到
panel-read-from-your-files = 从你的文件中读到
panel-saved-to-memory = 已存入记忆
panel-this-character-has-no = 这个角色没有图片。
panel-show-portrait = 显示角色图片
panel-add-lorebook-to-chat = 为此聊天添加世界书
panel-entry-of = { $lorebook } 的条目
panel-portrait-beside = 在聊天旁边
panel-remove-from-this-chat-2 = 从这个聊天中移除 { $name }
panel-remove-lorebook-from-this = 从这个聊天中移除世界书 { $name }

## pictures (chat/pictures.ts)

pictures-open-the-picture = 打开图片
pictures-change-prompt = 编辑描述
pictures-save-picture = 保存图片
pictures-picture-options = 图片选项
pictures-prompt = 描述
pictures-make-again = 重新生成

## split (chat/split.ts)

split-open-card-page = 打开角色页面
split-hide-card-editor = 隐藏角色页面
split-card-editor = 角色页面
split-changes-are-used-from = 修改从下一条回复起生效
split-this-card-is-in = 这个角色在废纸篓中。

## stats (chat/stats.ts)

stats-chat-history = 之前的消息
stats-reply-statistics = 关于这条回复
stats-context-used = AI 能读取的内容已用了多少
stats-sent-to-the-ai = 发送给 AI · { $count } 个 token
stats-in-all = 共 { $seconds }
stats-to-the-first-word = 到第一个字用时 { $seconds } · { $all }

## talk (chat/talk.ts)

talk-the-characters-stopped-after = 角色们在 { $asked } 条回复后停了下来。
talk-go-on = 继续

## title (chat-title.ts)

title-new-chat = 新聊天

## chat (companion/chat.ts)

chat-open-in-cardwave = 在 Cardwave 中打开
chat-compact-chat = 和桌面伙伴聊天
chat-read-replies-aloud = 朗读回复
chat-no-voice = 尚未设置语音：请在 设置 › 语音 中选择一个
chat-the-card-has-no = 这张卡没有可以聊天的角色。请用“换个角色”选另一个。
chat-message = 给 { $name } 发消息

## main (companion/main.ts)

main-open-chat = 打开聊天
main-figure-hint = 双击聊天，右键查看更多
main-walk-around = 四处走动
main-sit-still = 坐着别动
main-change-character = 换个角色
main-hide-until-tomorrow = 隐藏到明天
main-quit-companion = 关闭桌面伙伴

## dialogs (dialogs.ts)

dialogs-folder-on-this-computer = 这台电脑上的文件夹

## dom (dom.ts)

dom-text = { $name }：{ $reason }
dom-keep-all = 保留全部更改
dom-chosen-by-you = 由你选择
dom-address-copied = 地址已复制。
dom-the-browser-did-not = 这里不允许复制；请选中文字后按 Ctrl+C

## edit-form (edit-form.ts)

edit-form-from-to = 从 { $least } 到 { $most }
edit-form-a-whole-number-from = 不小于 { $least } 的整数

## load (figures/load.ts)

load-this-figure-has-no = Cardwave 无法让这个 3D 形象动起来。为 Mixamo、VRChat、Unity 或 Ready Player Me 制作的形象可以。

## format (format.ts)

format-today = 今天
format-comma = 、
format-day-at = { $day } { $time }
format-yesterday = 昨天
format-kb = { $kb } KB
format-seconds = { $seconds } 秒

## downloaded (models/downloaded.ts)

downloaded-set-up = 设置
downloaded-text = { $action }{ $toLowerCase }
downloaded-local = 在这台电脑上

## fit-models (models/fit-models.ts)

fit-models-cancel = 取消 { $name }
fit-models-download = 下载 { $name }
fit-models-model-menu-delete = 模型菜单：删除 { $name }
fit-models-delete-this-model = 从这台电脑上删除这个模型？将释放 { $size }。
fit-models-gb-of-memory = { $round } GB 运行内存 · { $folder }
fit-models-downloading = { $fits } · 正在下载 { $percent }%
fit-models-downloaded = { $fits } · 已下载
fit-models-model-deleted = 模型“{ $name }”已删除。

## images-setup (models/images-setup.ts)

images-setup-image-model = 图像模型
images-not-set-up = 你的角色的图片 · 未设置

## kinds (models/kinds.ts)

kinds-chat-model = 聊天模型
kinds-models-from-all-your = 你所有服务商中会写文字的模型。你选的那个负责写聊天，无论它来自哪个服务商。
kinds-models-from-all-your-2 = 你所有服务商中会写文字的模型。你选的那个就是辅助模型，无论它来自哪个服务商。
kinds-images-model = 图像模型
kinds-models-from-all-your-3 = 你所有服务商中会生成图片的模型。你选的那个负责生成图片，无论它来自哪个服务商。
kinds-search-model = 搜索模型
kinds-models-on-this-computer = 这台电脑上和你所有服务商中按意思查找文字的模型。你选的那个负责搜索，无论它来自哪里。
kinds-models-on-this-computer-2 = 这台电脑上和你所有服务商中朗读消息的模型。你选的那个负责朗读消息，无论它来自哪里。
kinds-loading-models = 正在加载模型……
kinds-couldnt-load-the-models = 无法加载模型。
kinds-search-the-models = 在模型中搜索
kinds-use-this-model = 使用这个模型
kinds-model = 模型
kinds-type-unknown = { " " }· 不确定能否做到
kinds-address = { " " }· { $address }
kinds-this-computer = 这台电脑上的程序
kinds-asking-the-provider = 正在询问服务商……
kinds-own-on-this-computer = { $own } · 在这台电脑上
kinds-none-of-the-kind = 你的服务商都没有能做这件事的模型。

## language-line (models/language-line.ts, settings/app-language.ts)

language-line-taken-from-this-computer = 与这台电脑相同，直到你另选一种
language-line-follows-the-app = 跟随应用的语言，直到你更改为止

## models-group (models/models-group.ts)

models-group-not-configured = 未设置
models-group-no-longer-offered = 你的服务商已不再提供此模型：请另选一个。

## provider-form (models/provider-form.ts)

provider-form-a-key-is-saved = 已保存一个密钥
provider-form-asking-the-provider-for = 正在向服务商获取模型列表……
provider-form-the-provider-lists-no = 这个服务商没有列出模型。请按服务商网站上的写法准确输入模型的名称。
provider-form-text = { $action }{ $what }
provider-form-test-passed = { " " }· 测试通过
provider-form-testing = { " " }· 正在测试……
provider-form-is-saved = ····{ $key_end } 已保存
provider-form-or-type-the-models = { $listedCount }{ $have }。也可以按服务商网站上的写法准确输入模型的名称。
provider-form-test-failed = 测试失败：{ $failed }。请检查密钥和地址。

## search-setup (models/search-setup.ts)

search-setup-not-downloaded = 未下载
search-setup-ready = 就绪
search-setup-on-this-computer-download = { $name } · 在这台电脑上 · 下载 { $bytes }
search-setup-the-librarys-search-then = 这样，资料库的搜索就能按角色的内容找到角色，而不只是按字面。
search-setup-reading-cards-left = { " " }· 正在读取角色，还剩 { $left } 个
search-setup-reading-cards-left-2 = 正在读取角色 · 还剩 { $left } 个

## find (shell/find.ts)

find-pages = 页面
find-page = 页面

## search-panel (shell/search-panel.ts)

search-panel-nothing-found-for = 没有找到“{ $asked }”的结果。
search-panel-show-all = 显示全部 { $count } 项
search-panel-open-in-a-new = 在新标签页中打开
search-panel-what = 角色、聊天、世界书、记忆、文档和页面
search-panel-not-messages = 不会搜索消息内容；试试搜索聊天的角色。

## advanced (views/advanced.ts)

advanced-sillytavern-v3 = SillyTavern V3
advanced-ccv4 = Character Card V4

## chat (views/chat.ts)

chat-your-next-message-starts = 你的下一条消息会从标记的消息开始换个走向。
chat-this-chat-is-in = 这个聊天在废纸篓中。恢复它即可继续写。
chat-hide-side-panel = 隐藏侧边栏
chat-show-side-panel = 显示侧边栏
chat-show-card-editor = 显示角色页面
chat-set-up-a-model = 设置模型
chat-the-characters-keep-replying = 角色们正在自动继续回复：第 { $asked } 条，共 { $talk_replies } 条。

## chats (views/chats.ts)

chats-last-message = 最后一条消息
chats-date-started = 开始日期
chats-no-chats-yet = 还没有聊天。
chats-search-chats = 搜索聊天
chats-couldnt-load = 无法加载你的聊天。
chats-chat-character-or-card = 查找聊天或角色
chats-with = 与 { $others }
chats-from = 在角色中名为 { $join }

## coding-task (views/coding-task.ts)

coding-task-checkpoints = 撤销点
coding-task-put-the-folder-back = 要把文件夹恢复到{ $toLowerCase }吗？
coding-task-none-yet = 还没有
coding-task-changed-files = 改动的文件
coding-task-text = { " " }· { $stepSays }
coding-task-team-started = { $folder } · { $team } 团队 · 开始于 { $format } ·{ " " }
coding-task-steps = 步骤
coding-task-undone = { $detail } · 已撤销

## documents (views/documents.ts)

documents-no-documents-yet-a = 还没有文档。在这里添加，或在聊天中附加。
documents-what-they-are = AI 回答时会读这些文件：角色的文件用于与它的每个聊天，聊天的文件用于该聊天。
documents-found-by-meaning-once = 设置好搜索后，AI 会按意思找到合适的部分。
documents-set-up-search = 在设置中设置搜索
documents-no-document-found = 没有找到文档。
documents-search-documents = 搜索文档
documents-name-chat-or-character = 名称、聊天或角色
documents-document-deleted = 文档已删除。
documents-for-the-character = 属于角色{ " " }
documents-for-the-chat = 属于聊天{ " " }

## memories (views/memories.ts)

memories-nothing-remembered-yet = 还没有记忆。
memories-come-from-chats = 记忆来自你的聊天：每隔 20 条消息，Cardwave 会保留每个角色应该记住的内容。你可以在这里修改或删除它们。
memories-no-memory-found = 没有找到记忆。
memories-search-memories = 搜索记忆
memories-text-chat-or-character = 文字、聊天或角色
memories-known-by = 谁知道
memories-known-by-hint = 聊天中谁知道这件事并可能提起它。
memories-you = 你
memories-you-alone = 你
memories-edit-memory = 编辑记忆
memories-memory-deleted = 记忆已删除。
memories-from-the-chat = { " " }· 来自聊天{ " " }
memories-from-your-chat-with = { " " }· 来自你与此角色的聊天：{ " " }
memories-because = 因为{ $end }
memories-so = 所以{ $end }

## dictation-setup (voice/dictation-setup.ts)

dictation-setup-on-this-computers-graphics = { $name } · 在这台电脑的显卡上 · { $bytes }
dictation-setup-the-microphone-beside-the = 之后，消息框旁的麦克风会把你说的话写下来，支持中文、英文等多种语言。你说的话只留在这台电脑上。

## make-voice (voice/make-voice.ts)

make-voice-my-voice = 我的语音
make-voice-make-voice = 制作语音
make-voice-choose-a-file = 选择文件
make-voice-record = 录音
make-voice-play-back = 回放
make-voice-record-again = 重新录音
make-voice-the-recording-is-too = 录音太短：至少需要 { $SHORTEST } 秒。
make-voice-cardwave-cant-read-choose = Cardwave 无法读取“{ $name }”。请选择 WAV 或 MP3 文件。
make-voice-recording = 录音
make-voice-a-short-recording-of = 一段一个人清楚说话的短录音：10 到 { $LONGEST } 秒。WAV 或 MP3 格式。
make-voice-use-only-a-voice = 只使用你有权使用的语音：你自己的，或者声音的主人同意过的。
make-voice-give-the-voice-a = 给这个语音起个名字。

## voice-setup (voice/voice-setup.ts)

voice-setup-made-from-your-recording = 用你的录音制作
voice-setup-on-this-computer-download = 在这台电脑上 · 下载 { $bytes }
voice-setup-play-a-sample-of = 播放 { $name } 的试听
voice-setup-stop-the-sample-of = 停止 { $name } 的试听
voice-setup-messages-are-read-aloud = 消息会在这台电脑上用英语朗读。
voice-setup-use-this-voice = 使用这个语音
voice-setup-hello-im-this-is = 你好，我是 { $name }。你的消息被朗读时就是这个语音。

## voice (voice/voice.ts)

voice-the-voice-stopped-answering = 语音没有响应了。请再试一次，或在 设置 › 语音 中选择其他语音。
voice-this-window-cannot-play = 此窗口无法播放声音：{ $reason }。请检查 Windows 的声音输出。

## Written by hand: plurals, conditions and numbers

client-backup-failed = 无法创建备份。请确认该文件夹可以写入，然后再试一次。
composer-tokens-of = { NUMBER($used, useGrouping: "auto") } / { NUMBER($size, useGrouping: "auto") } 个 token
header-chat = 聊天
header-chat-archived = 聊天已归档。
header-chat-unarchived = 聊天已从归档中移回。
messages-tokens = { $count ->
   *[other] { NUMBER($count, useGrouping: "auto") } 个 token
  }
dom-texts-changed-by-ai = { $count ->
   *[other] { $count } 段文字
  }已被 AI 修改
format-days-ago = { $count ->
   *[other] { $count } 天前
  }
format-weeks-ago = { $count ->
   *[other] { $count } 周前
  }
format-months-ago = { $count ->
   *[other] { $count } 个月前
  }
format-years-ago = { $count ->
   *[other] { $count } 年前
  }
format-mb = { NUMBER($mb, minimumFractionDigits: 1, maximumFractionDigits: 1) } MB
format-gb = { NUMBER($gb, minimumFractionDigits: 1, maximumFractionDigits: 1) } GB
fit-models-fits = { $size } · 可在这台电脑上运行
fit-models-too-large = { $size } · 对这台电脑来说太大
fit-models-used-for = { $fits } · 用于{ $kinds }
provider-form-models = { $count ->
   *[other] { NUMBER($count, useGrouping: "auto") } 个模型
  }
provider-form-listed = 列出了 { $count ->
   *[other] { NUMBER($count, useGrouping: "auto") } 个模型
  }
provider-form-listed-not-all = 列出了 { $count ->
   *[other] { NUMBER($count, useGrouping: "auto") } 个模型
  }；其余的无法加载
provider-form-have = ；其中 { NUMBER($count, useGrouping: "auto") } 个包含“{ $part }”
coding-task-verdict-passed = 审查者的结论：通过
coding-task-verdict-not-passed = 审查者的结论：未通过
documents-words = { $count ->
   *[other] { NUMBER($count, useGrouping: "auto") } 个字
  }
memories-known-by-everyone = 所有角色都知道
memories-known-by-these = { $names } 知道
memories-known-by-nobody = 没有角色知道
lore-tools-entries-changed-by-ai = { $count ->
   *[other] { $count } 个条目
  }已被 AI 修改
coding-failed-with-error = 失败：{ $error }
coding-planner-doing = 规划者：{ $what }
coding-step-doing = 第 { $begun } 步，共 { $planned } 步 · { $who }：{ $what }
coding-worker = 执行者 { $number }
coding-plans = 规划步骤
coding-planned = { $steps ->
   *[other] 已规划 { $steps } 步
  }
coding-fixes = 修复审查者发现的问题
coding-checks-step = 检查第 { $step } 步
coding-checks-all = 检查每一步并运行测试
coding-verdict-tests = { $said } · { $tests }
coding-show-plan = 显示计划
coding-before-step = 第 { $step } 步之前
coding-before-fix = 修复之前
coding-looking-at-folder = 正在查看文件夹
coding-looking-at = 正在查看 { $target }
coding-reading = 正在读取 { $target }
coding-writing = 正在写入 { $target }
coding-running-command = 正在运行：{ $target }
coding-installing = 正在安装：{ $target }
coding-searching-web = 正在网上搜索：{ $target }
coding-files = { $files ->
   *[other] { $files } 个文件
  }
coding-no-files-changed = 没有改动文件
coding-lines-files = { $lines } · { $files }
messages-copy-refused = 这里不允许复制；请选中文字后按 Ctrl+C
panel-book-persona = 人设
panel-book-every-chat = 每个聊天
stats-model = 模型
stats-response-time = 响应时间
stats-context = 上下文
stats-context-says = 已用 { $used } / { $size } 个 token · 剩余 { $free }
documents-the-chat = 这个聊天
models-download-recommended = 按内容查找角色 · 下载 { $size } · 推荐
models-downloading = { $name } · 正在下载 { $percent }%
models-on-this-computer = { $name } · 这台电脑{ $reading }
voice-setup-voice-download = 朗读回复 · { $name }（{ $about }） · 下载 { $size }
voice-setup-downloading = 正在下载 { $percent }%
panel-persona-default = 用于新聊天
panel-who-you-are-in-this-chat = 你在这个聊天中的身份
panel-use-in-this-chat = 在这个聊天中使用
panel-click-a-reply = 点击一条回复，查看它用了什么。
