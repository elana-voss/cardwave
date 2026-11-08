### 界面文字的简体中文版，逐条译自英文（en.ftl，原始文件）。结构测试（structure.test.ts）检查每个键都在这里，且形式与英文相同。
### 术语表。一样东西一个名字，所有 zh-Hans.*.ftl 通用：
###   称呼：用户称“你”，不用“您”：豆包、Kimi、微信等中文消费类和 AI 聊天应用都用“你”，“您”是银行和客服的口吻，对个人聊天应用
###   太生硬；全篇一致。不预设用户的性别：用户不用“他／她”，改写句子避开；角色和账户的名字（{ $name }）也一样，用“它”或重复名字。
###   应用不自称“我”：主语是“Cardwave”或省略。只有访谈中的 AI 在英文说“me”的地方自称“我”；用户自己的按钮（“Write for me”
###   “I don't know”）也用“我”（“帮我写”“我不知道”）。按钮和标签用简短的动宾或名词（“保存”“删除”“打开聊天”）。
###   中文 AI 聊天用户熟悉的词照用。Cardwave、MCP、Claude Desktop、CSS、AI、API、token、Downtempo、Outrun、Retrowave、
###   Neon Wave 保留拉丁字母。tab = 标签页; chat = 聊天; message = 消息; character = 角色; card = 角色卡（角色的文件）;
###   figure = 3D 形象; persona = 人设; lorebook = 世界书（SillyTavern 等角色聊天应用的中文社区都这么叫，“设定集”多指作品资料）;
###   memory = 记忆（页面“记忆”）; document = 文档; library = 资料库; knowledge = 知识; account = 账户; provider = 服务商;
###   model = 模型; helper (model) = 辅助模型; tool = 工具; tag = 标签; preset = 预设（模型预设、提示词预设）; prompt = 提示词;
###   key = 密钥（API 密钥）; Settings = 设置; Advanced = 高级; Trash = 废纸篓（Cardwave 的）; Recycle Bin = Windows 回收站
###   （总带“Windows”以示区别）; backup = 备份; restore = 恢复; Sharing = 共享; companion = 桌面伙伴; voice = 语音（页面“语音”）;
###   read aloud = 朗读; dictation = 语音输入; picture = 图片（Images = 图片，image model = 图像模型）; download = 下载;
###   Showcase = 展示; Search Cardwave = 搜索 Cardwave; coding team = 编程团队; planner = 规划者; worker = 执行者;
###   auditor = 审查者; task = 任务; sign in/out = 登录／退出登录; lock = 锁定; import = 导入; export = 导出; password = 密码;
###   interview = 访谈; generator = 角色生成器; theme = 主题; first run = 初始设置; save = 保存; delete = 删除; edit = 编辑;
###   cancel = 取消; file = 文件; folder = 文件夹; search = 搜索; version = 版本; format = 格式; Appearance = 外观;
###   greeting = 开场白; entry = 条目; keyword = 关键词; Your own CSS = 自定义 CSS。
###   没有人设的用户的名字（card-user-stand-in、cw_prompt::stand_in_user）：访客（在句中读作名字，没有性别）。
###   复数（Intl.PluralRules “zh”）：只有 other。数字带量词（“{ $count } 个”“{ $count } 行”“{ $count } 天”）。
###   句中用全角标点（，。：？！“”（））；汉字与拉丁字母、数字之间空一格（如苹果的中文界面），与全角标点之间不空。占位符按其
###   内容：名字、数字、版本、路径（{ $name }、{ $count }，常为拉丁字母）两侧同样空一格；装的是中文词句的（{ $what }、{ $why }）
###   不空。并列的名字用顿号连接“、”（format-comma），分隔“ · ”，菜单路径“ › ”，省略号“……”。

## The app

app-name = Cardwave

## The pages, as tabs, the rail and Search Cardwave name them (shell/pages.ts)

page-chats = 聊天
page-characters = 角色
page-lorebooks = 世界书
page-personas = 人设
page-memories = 记忆
page-documents = 文档
page-generator = 角色生成器
page-interview = 一起创建角色
page-profile = 个人资料
page-server = 共享
page-settings = 设置
page-providers = 服务商
page-voices = 语音
page-advanced = 高级
page-css = Cardwave 的 CSS
page-written-tools = AI 编写的工具
page-coding-team = 编程团队
page-trash = 废纸篓
page-about = 关于 Cardwave
page-coding-task = 编程任务
page-chat = 聊天
page-new-card = 新建角色
page-lorebook = 世界书
page-card = 角色
page-prompt-preset = 提示词预设
page-first-run = 设置 Cardwave

## The places pages are under

place-library = 资料库
place-knowledge = 知识
place-account = 账户
place-settings = 设置
place-advanced = 设置 › 高级

## The rail (shell/rail.ts)

rail-create = 创建
rail-memories-tip = 记忆：AI 从你的聊天中记住的内容
rail-documents-tip = 文档：AI 回答时会读取的文件
rail-show-more = 再显示 { $count } 个
rail-open-menu = 打开侧边栏
rail-close-menu = 关闭侧边栏
rail-collapse = 收起侧边栏
rail-expand = 展开侧边栏
rail-account = 账户
rail-account-named = 账户：{ $name }
rail-lock = 锁定

## Create's lines (shell/create.ts)

create-new-chat = 新建聊天
create-plain-chat = 不带角色的聊天
create-new-card = 新建角色
create-from-picks = 角色生成器
create-together = 一起创建角色
create-new-persona = 新建人设
create-new-lorebook = 新建世界书
create-import-card = 导入角色卡
create-import-lorebook = 导入世界书
create-new = 新建
create-import = 导入

## The title bar and its tabs (shell/titlebar.ts)

tabs = 标签页
tab-new = 新建标签页
tab-new-keys = 新建标签页（Ctrl+T）
tabs-all = 所有标签页
tab-close = 关闭标签页
window-minimize = 最小化
window-maximize = 最大化
window-close = 关闭

## The view menu (shell/view-menu.ts, theme.ts)

view = 视图
view-compact = 紧凑
theme-system = 跟随系统
theme-light = 浅色
theme-dark = 深色
theme-downtempo = Downtempo
theme-outrun = Outrun
theme-retrowave = Retrowave
theme-neonwave-dark = Neon Wave 深色
theme-neonwave-light = Neon Wave 浅色

## Search Cardwave's button (shell/search-panel.ts)

search = 搜索 Cardwave
search-keys = 搜索 Cardwave（Ctrl+K）

## The labels of the settings, as their pages and Search Cardwave name them (setting-labels.ts)

label-settings-theme = 主题
label-settings-chat-layout = 聊天布局
label-settings-web-pictures = 显示其他网站的图片
label-settings-app-language = 应用语言
label-settings-language = AI 写作的语言
label-settings-providers = 服务商
label-settings-chat = 聊天
label-settings-images = 图片
label-settings-voice = 语音
label-settings-search = 搜索
label-settings-dictation = 语音输入
label-settings-web = 网络
label-settings-files = 文件
label-settings-commands = 命令
label-settings-image-generation = 图片生成
label-settings-app = Cardwave
label-settings-dice = 骰子
label-settings-folder = 文件夹
label-settings-written = AI 编写的工具
label-settings-coding = 编程团队
label-settings-trash = 废纸篓
label-settings-backup = 备份
label-settings-restore = 恢复
label-settings-cards-folder = 角色卡文件夹
label-settings-advanced = 高级
label-settings-setup = 重新运行初始设置
label-settings-about = 关于 Cardwave
label-providers-this-computer = 这台电脑
label-voices-model = 语音模型
label-voices-speed = 语速
label-voices-english = 英语
label-advanced-background = 辅助模型
label-advanced-told = 告诉 AI 的内容
label-advanced-describe = 描述导入的角色
label-advanced-described = 已描述的角色
label-advanced-interview = 一起创建角色
label-advanced-format = 导出格式
label-advanced-history = 包含每段文字的早期版本
label-advanced-css = 自定义 CSS
label-coding-planner = 规划者
label-coding-workers = 执行者
label-coding-auditor = 审查者
label-profile-name = 名字
label-profile-picture = 头像
label-profile-password = 密码
label-server-network = 可在家庭网络中访问
label-server-address = 地址
label-server-mcp = 让这台电脑上的 AI 应用使用 Cardwave

layout-bubbles = 气泡
layout-plain = 纯文本

## Settings (views/settings.ts)

settings-appearance = 外观
settings-theme-about = 跟随系统，除非你选择一个
settings-layout-about = 消息显示为气泡或纯文本
settings-web-pictures-about = 你打开聊天时，这些网站能知道。
settings-language = 语言
settings-data = 数据
settings-trash-about = { $count ->
   *[other] { $count } 项
  } · { $days } 天后清空
settings-open-trash = 打开废纸篓
settings-open = 打开
settings-version = 版本 { $version } · 许可证
settings-licences = 许可证
settings-advanced-about = 辅助模型、资料库、导出、不带角色的聊天、采样、预设、自定义 CSS
settings-setup-about = 服务商、模型和语音，一步一步来
settings-providers-about = 运行模型的服务的地址和密钥
settings-this-computer = 这台电脑
settings-providers-named = 已设置：{ $names }
settings-models = 模型
settings-the-chat-model = 聊天模型
settings-the-image-model = 图像模型

## The account's tabs and accounts (shell/account-tabs.ts, settings/accounts.ts)

account-sections = 账户分区
account-switch = 切换账户

account-password = 密码
account-switch-to = 切换到 { $name }
account-password-asked = 请输入 { $name } 的密码。
account-switch-button = 切换
account-add = 添加账户
account-add-about = 这台电脑上另一个人的账户，有自己的聊天和角色。它用自己的密码登录，在这里或其他设备上都可以。
account-name = 名字
account-added = 已添加账户“{ $name }”。
account-add-button = 添加
account-sign-out = 退出登录
account-none = 没有可登录的账户
account-none-about = 目前还没有账户能从这里登录。请在运行 Cardwave 的电脑上，到“账户 › 共享”中添加一个。
account-this-computer = 这台电脑的账户
account-choose = 选择你的账户
account-try-again = 重试
account-back = 返回
account-sign-in = 登录

## Backup and Restore (settings/backup.ts)

backup-saving = 正在保存备份。
backup-saving-to = 正在把备份保存到 { $folder }。
backup-password = 密码
backup-repeat = 再次输入密码
backup-encrypted = 备份用这个密码加密；恢复时需要这个密码，在这台或其他电脑上都一样。
backup-forgotten = 忘记的密码无法找回，没有它备份就无法恢复。
backup-with-password = 用密码备份
backup-differ = 两次输入的密码不一致。
backup-back-up = 保存备份
backup-no-file = 未选择文件
backup-choose-file = 选择文件
backup-its-password = 备份的密码
backup-restoring = 恢复会替换 Cardwave 中的所有内容：聊天、角色、人设、世界书、记忆和设置。此操作无法撤销。这里设置的密码保持不变。 其他账户也会被替换。
backup-restored = 备份已恢复：Cardwave 中的一切都回到了备份时的样子。其他设备需要重新登录。
backup-file = 文件
backup-restore-title = 恢复备份
backup-choose-first = 请先选择备份文件。
backup-restore = 恢复备份
backup-from-file = 从备份文件恢复
backup-about-own = 聊天、角色和设置存为一个文件，用你的密码加密
backup-about-chosen = 聊天、角色和设置存为一个文件，用你选择的密码加密

## The folder of cards (settings/card-folder.ts)

folder-watch = 自动导入新的角色卡
folder-watch-about = 放进这个文件夹的角色卡文件会自动进入你的资料库
folder-recycle = 把已导入的文件移到 Windows 回收站
folder-recycle-about = 文件导入后会移到回收站

## The companion's line (library/companion-app.ts)

companion = 桌面伙伴
# The companion window's name, which the system shows in its lists of windows.
companion-window = Cardwave 桌面伙伴
companion-made = { $name } 现在是你的桌面伙伴。
companion-make = 设为桌面伙伴
companion-none = 还没有桌面伙伴。打开角色的“…”菜单，选择“设为桌面伙伴”。
companion-named = { $name } · 随应用启动
companion-figure = 桌面伙伴形象
companion-figure-about = 用于没有自己 3D 形象的角色
companion-figure-woman = 女性
companion-figure-man = 男性
companion-figure-robot = 机器人
companion-size = 桌面伙伴大小
companion-size-about = 形象的高度，占屏幕高度的比例
companion-size-value = { $size }%

## Other programs, MCP (settings/mcp.ts)

mcp-ask-title = 让这台电脑上的 AI 应用使用 Cardwave
mcp-ask = 这台电脑上的程序（例如 Claude Desktop）可以读取你的角色和聊天、在你的聊天中写入，并使用在设置 › 工具中打开的工具。Cardwave 会先问你的事，它们做不了。
mcp-switch-on = 打开
mcp-about = 例如 Claude Desktop，通过 MCP：它们会使用你的角色、聊天和工具
mcp-copy-address = 复制 MCP 地址
mcp-copy = 复制
mcp-as-account = 使用的账户
mcp-as-account-about = 它们能看到和做的事
mcp-remove-named = 移除 { $program }
mcp-removed = 已移除“{ $program }”。
mcp-remove = 移除
mcp-connected = 已连接
mcp-other-programs = 其他程序
mcp-only-here = 只有这台电脑上的程序可以连接。已移除的程序会一直被挡在外面，直到你把这里关闭再打开。

## Your own CSS (settings/own-css.ts)

css-none = 无
css-lines = { $count ->
   *[other] { $count } 行
  }
css-about = { $lines } · 改变应用的外观
css-hint = 在 Cardwave 自身的样式表之后应用，边输入边生效。“保存”保留它；“取消”撤回它。
css-edit-own = 编辑自定义 CSS
css-edit = 编辑

## The password (settings/password.ts)

password-forgotten = 忘记的密码无法找回，你的聊天和角色也会随之丢失。请把它保存在安全的地方。
password-on-title = 设置密码
password-on-says = Cardwave 打开时会要求输入它。没有它，任何人都无法在这台电脑上打开 Cardwave 或读取你的聊天。
password-on = 设置密码
password-on-done = 已设置密码。
password-change-title = 更改密码
password-change-says = Cardwave 打开时会要求输入新密码。
password-change = 更改
password-change-done = 已更改密码。
password-off-title = 关闭密码
password-off-says = Cardwave 打开时将不再要求输入密码。你的聊天和角色仍保持加密。
password-off = 关闭
password-off-done = 已关闭密码。
password-differ = 两次输入的密码不一致。
password-other-says = 从那以后，用新密码登录。
password-other-forgotten = 如果忘记了，这台电脑的账户可以在“共享”中重设它。
password-current = 当前密码
password-password = 密码
password-new = 新密码
password-repeat = 再次输入密码
password-asked-sign-in = 登录时需要输入
password-is-on = 已打开 · 应用打开时需要输入
password-is-off = 关闭 · 这台电脑前的任何人都能打开 Cardwave
password-start-forgotten = 忘记的密码无法找回。
password-open = 打开
password-locked-elsewhere = Cardwave 在它的电脑上已锁定。那边解锁后，这里会自动打开。
password-back = 返回

## Words many pages use

common-use = 使用
common-in-use = { " " }· 使用中
common-more = 更多
common-edit = 编辑
common-duplicate = 复制一份
# The word a copy's name ends in, as in "Rig (copy)".
common-copy-word = 副本
common-delete = 删除
common-save = 保存
common-cancel = 取消
common-name = 名字

## Model presets and prompt presets (settings/presets.ts, settings/prompt-presets.ts)

preset-what = 预设保存一个聊天模型及其采样值。“使用”会切换到它。
preset-temperature = 温度 { $value }
preset-new = 新建预设
preset-model-presets = 模型预设
preset-using = 正在使用“{ $name }”。
preset-added = 已添加预设“{ $name }”。
preset-deleted = 已删除预设“{ $name }”。
preset-saved = 已保存预设“{ $name }”。
preset-delete-ask = 删除这个预设？
preset-replace = 使用当前的模型和设置
preset-replace-hint = 聊天模型、它的提供方和本页的采样。关闭：预设保留自己的。
preset-keeps-hint = 它保存“设置 › 模型”中的聊天模型、它的服务商和本页的采样。
preset-name = 名字
preset-edit = 编辑预设
prompt-presets = 提示词预设
prompt-system = 系统提示词
prompt-note = { $depth ->
   *[other] 注释，往前 { $depth } 条消息
}
prompt-system-note = { $depth ->
   *[other] 系统提示词 · 注释，往前 { $depth } 条消息
}
prompt-as-card = 按角色所写
prompt-default = 默认
prompt-default-name = “{ $name }”是角色自己的提示词。

## Tools (settings/tools.ts, chat/tool-ask.ts)

tools-written-ask = { $count ->
    [0] 还没有
   *[other] { $count } 个工具
  } · 新工具运行前先询问
tools-written-free = { $count ->
    [0] 还没有
   *[other] { $count } 个工具
  } · 新工具无需询问即可运行
tools-folder-first = 请先选择一个文件夹
tools-web = 搜索和阅读网页
tools-files = 仅限 { $folder }
tools-ask-writes = 写入前先询问
tools-ask-writes-says = 每个文件写入前都会先给你看
tools-commands = 在 { $folder } 中运行，与电脑的其他部分和互联网隔离
tools-ask-commands = 运行前先询问
tools-ask-commands-says = 每条命令运行前都会先给你看
tools-pictures = 使用图像模型
tools-pictures-first = 请先设置图像模型
tools-app = 使用和更改你的角色、聊天和设置；每次更改都先询问
tools-dice = 让 AI 掷骰子；由 Cardwave 来掷，结果公平。
tools-folder-example = C:\Users\you\Documents\Shared
tools-folder-says = 文件和命令只能访问这个文件夹及其中的内容，别的都不行。
tools-change-folder = 更改文件夹
tools-change = 更改
tools-choose = 选择
tools-none-chosen = 未选择
tools-title = 工具
tools-ask-new = { $name } 想使用一个新工具：{ $what }
tools-ask-write = { $name } 想在你的文件夹中写入“{ $what }”：
tools-ask-read = { $name } 想读取你的文件夹：
tools-ask-install = { $name } 想要下载并安装它需要的程序：
tools-ask-web = { $name } 想访问网络：
tools-ask-app = { $name } 想更改 Cardwave：
tools-ask-command = { $name } 想在你的文件夹中运行一条命令：
tools-allow = 允许
tools-deny = 拒绝
tools-allow-writing = 在这个聊天中允许写入文件
tools-allow-commands = 在这个聊天中允许运行命令

## Updates (settings/update.ts)

update-title = 检查更新
update-available = Cardwave { $version } 已发布
update-you-have = 你的版本是 { $version }。
update-up-to-date = Cardwave 已是最新版本（{ $version }）。
update-connection-error = 无法检查更新。请检查你的网络连接。
update-check-failed = 无法检查更新：GitHub 没有返回最新版本的信息。
update-whats-new = 更新内容
update-close = 关闭
update-ok = 好
update-download = 下载
update-install = 更新并重启
update-installing = 正在下载 Cardwave { $version }……
update-auto = 自动检查
update-auto-about = 启动时和每天一次查找新版本
update-check = 检查
update-checking = 检查中…
update-about = 检查是否有更新版本的应用。

## The breadcrumbs of a page under Settings

crumbs = 当前位置

## Providers (views/providers.ts)

providers-key-end = { $where } · 密钥 ····{ $end }
providers-key-saved = { $where } · 已保存密钥
providers-no-key = { $where } · 无密钥
providers-thinking-cannot = { $provider } 无法为这个模型关闭思考
providers-thinking-off = 模型不先思考，直接回复
providers-thinking-on = 模型回复前先思考
providers-comfy-default = ComfyUI 的默认值
providers-workflow-note = 这个工作流使用自己的模型和尺寸，而不是“图片”中的模型。
providers-testing-model = 正在测试模型……
providers-thinking-of = { $label }：思考
providers-thinking = 思考
providers-testing-workflow = 正在测试工作流……
providers-workflows-from = 来自 ComfyUI 中的工作流
providers-pictures-by = 图片由“{ $name }”生成。
providers-pictures-default = 图片由 ComfyUI 的默认工作流生成。
providers-workflow = 工作流
providers-not-used = 尚未用于任何功能
providers-folder-saved = 已保存文件夹。
providers-change-folder = 更改模型文件夹
providers-choose-folder = 选择模型文件夹
providers-change = 更改
providers-not-set-up = 未设置
providers-folder-not-set-up = 运行这台电脑上某个文件夹里的模型 · 未设置
providers-menu = 服务商菜单：编辑、移除
providers-remove = 移除
providers-removed = 已移除服务商“{ $name }”。
providers-remove-with-models = 移除此提供商？从它选用的模型将不再使用。
providers-remove-ask = 移除这个服务商？
providers-remove-key = 移除密钥
providers-key-removed = 保存时将移除密钥
providers-edit = 编辑服务商
providers-keep-key = 留空则保留已保存的密钥。
providers-saved = 已保存服务商“{ $name }”。
providers-added = 已添加服务商“{ $name }”。
providers-add = 添加服务商
providers-about = AI 在哪里运行：互联网上的服务，或这台电脑上的程序。每一项下面写着它用来做什么。

## Voices (views/voices.ts)

voices-stop = 停止 { $name }
voices-try = 试听 { $name }
voices-model-about = 在这台电脑上朗读消息 · { $size }
voices-default-of = 默认语音：{ $name }
voices-menu = 语音菜单：重命名、删除
voices-rename = 重命名
voices-delete-ask = 删除声音“{ $name }”？使用它的角色将改回默认声音。
voices-rename-title = 重命名语音
voices-name = 名字
voices-speed-value = { $speed }×
voices-speed = 语速
voices-speed-about = 回复朗读的快慢，对所有语音生效
voices-make = 用一段录音制作语音
voices-provider-failed = 无法加载服务商的语音。
voices-provider-none = 服务商没有列出语音
voices-provider-own = 消息用提供商自己的声音朗读。
voices-voices = 语音
voices-voices-about = 朗读消息的语音。角色可以在“角色的语音”中有自己的语音。
voices-default = 默认语音
voices-voice-of = { $name } 的语音
voices-back-default = 恢复默认语音
voices-name-title = { $name } · { $title }
voices-choose-character = 选择角色
voices-all-have = 每个角色都有语音了。
voices-set-for = 为角色设置语音
voices-character = 角色
voices-voice = 语音
voices-character-first = 请先选择角色。
voices-characters = 角色的语音
voices-downloading = 正在下载 · { $size } · { $percent }%
voices-downloaded = 已下载 · { $size }
voices-download-size = 下载 { $size }
voices-action-of = { $action } { $name }
voices-language-downloaded = 已下载 { $name }
voices-built-in = 内置
voices-languages = 它朗读的语言
voices-download = 下载
voices-cancel = 取消
voices-delete = 删除

## Advanced (views/advanced.ts)

advanced-context-size = 上下文大小（token）
advanced-context-hint = 留空即为 128,000
advanced-temperature = 温度
advanced-temperature-about = 越高，回复越出人意料。从 0 到 2
advanced-top-p = Top P
advanced-top-p-about = 越低，越只用最可能的词。从 0 到 1
advanced-frequency = 频率惩罚
advanced-frequency-about = 越高，重复的词越少。从 −2 到 2
advanced-presence = 存在惩罚
advanced-presence-about = 越高，新话题越多。从 −2 到 2
advanced-seed = 种子
advanced-seed-about = 同一个数字会再次给出同样的回复
advanced-from-to = 从 { $min } 到 { $max }
advanced-whole-from = 从 { $min } 起的整数
advanced-whole = 整数
advanced-number = 数字
advanced-sampling = 采样
advanced-sampling-about = 用于聊天模型。某项留空则使用服务商的默认值。边输入边保存。
advanced-describing = 正在描述……还剩 { $count } 个
advanced-all-described = 所有角色都已描述
advanced-not-described = { $count ->
   *[other] { $count } 个角色
  }尚未描述
advanced-describe-cards = 描述角色
advanced-describe-cost = { $count ->
   *[other] { $count } 个角色
  }约需 { $low } 至 { $high } 个 token
advanced-failed = { $count ->
   *[other] { $count } 个失败
  }：{ $failure }。按“描述角色”再试一次。
advanced-describe-again = 全部重新描述
advanced-describe-again-stop = 停止
advanced-describe-again-about = 用辅助模型重写每个角色的一句话描述、摘要、标签，以及“按需求”用来找到它的内容，每个约 11,000 到 12,000 个 token。你自己编辑过的内容保留。 提供方按 token 计费。
advanced-no-characters = 没有要描述的角色
advanced-describe-again-far = 已重新描述 { $done } 个，共 { $all } 个
advanced-describe-again-stopped = 已停止：已重新描述 { $done } 个，共 { $all } 个
advanced-describe-again-failed = { $count ->
   *[other] { $count } 个失败，保持原样
  }：{ $failure }。按“全部重新描述”再试一次。
advanced-describe-about = 每个角色的一句话简介、摘要和标签，由辅助模型撰写
advanced-plain = 不带角色的聊天
advanced-told-about = 在每个没有角色的聊天中都相同。写下 { "{{date}}" } 或 { "{{time}}" }，AI 就会得到今天的日期或时间
advanced-library = 资料库
advanced-interview-about = AI 如何向你提问
advanced-interview-tree = 树状
advanced-interview-cloud = 云状
advanced-interview-hybrid = 混合
advanced-data = 数据
advanced-format-about = 导出时每张卡片所用的格式；大多数应用都能打开 SillyTavern V3
advanced-history-about = 每段文字的早期版本；仅限 Cardwave 自己的卡片格式
advanced-helper = 辅助模型
advanced-the-helper = 辅助模型

## Cardwave's CSS (views/css-reference.ts)

cssref-rail = 左侧栏
cssref-main = 侧栏旁的界面
cssref-crumbs = 页面顶部的路径
cssref-group = 一组条目的框，如设置中那样
cssref-item = 框中的一行
cssref-row = 列表中的一行
cssref-tile = 资料库网格中的卡片
cssref-msg = 聊天中的一条消息
cssref-bubble = 消息的气泡
cssref-composer = 聊天下方的消息输入框
cssref-dialog = 对话框
cssref-btn-primary = 蓝色按钮
cssref-switch = 开关
cssref-pill = 胶囊标签
cssref-notice = 窗口底部的提示
cssref-snippet-green = 绿色强调色
cssref-snippet-square = 方形气泡
cssref-snippet-larger = 更大的文字
cssref-snippet-wider = 更宽的对话框
cssref-snippet-tighter = 更紧凑的间距
cssref-snippet-black = 纯黑的深色主题
cssref-in-dark = { $light } · 深色时 { $dark }
cssref-none = 没有这个名字的变量。
cssref-copy-of = 复制“{ $title }”
cssref-copied = 已复制。
cssref-copy = 复制
cssref-about-1 = 自定义 CSS 可用的变量和类名。应用的每种颜色和尺寸都是{ " " }
cssref-about-2 = { " " }中的一个变量，有浅色和深色两个值。
cssref-variables = 变量
cssref-search = 搜索
cssref-find = 查找变量
cssref-all = 共 { $count } 个变量。
cssref-classes = 类名
cssref-snippets = 代码片段

## Tools the AI wrote (views/written-tools.ts)

written-about = { $what } · 创建于 { $made }
written-about-in = { $what } · { $made }在 { $chat } 中创建
written-used = { $count ->
    [0] 尚未使用
   *[other] 已使用 { $count } 次
  }
written-none = 还没有工具。在聊天中打开“让 AI 编写工具”，它写的工具会列在这里。
written-ask = 新工具运行前先询问
written-ask-about = 每个工具一次：首次运行时由你允许
written-in = ，聊天：
written-made = 创建于 { $made }
written-dot-used = { " " }· { $used }
written-switch-off = 关闭
written-switch-on = 打开
written-intro = AI 在打开了“让 AI 编写工具”的聊天中为自己写的小工具。只有你允许时它们才会动你的文件，并会留给以后的聊天使用。
written-deleted = 已删除工具“{ $name }”。
written-on = { $name }：打开
written-view-code = 查看代码

## The coding team, shared by the chat and its pages (chat/coding.ts)

coding-quick = 快速
coding-balanced = 均衡
coding-thorough = 周全
coding-custom = 自定义
coding-running = 运行中
coding-done = 完成
coding-failed = 失败
coding-stopped = 已停止
coding-team-says-alone = { $name }：一个规划者，{ $workers ->
    [1] 一个执行者
    [2] 两个执行者
   *[other] 三个执行者
  }，没有审查者。
coding-team-says-tests = { $name }：一个规划者，{ $workers ->
    [1] 一个执行者
    [2] 两个执行者
   *[other] 三个执行者
  }，以及一个运行测试的审查者。
coding-team-says-steps = { $name }：一个规划者，{ $workers ->
    [1] 一个执行者
    [2] 两个执行者
   *[other] 三个执行者
  }，以及一个检查每一步并运行测试的审查者。
coding-team-label = { $name } · { $workers ->
   *[other] { $workers } 个执行者
  }
coding-team-label-auditor = { $name } · { $workers ->
   *[other] { $workers } 个执行者
  }，审查者
coding-team-label-steps = { $name } · { $workers ->
   *[other] { $workers } 个执行者
  }，每步审查
coding-tests-pass = { $total } 个测试中通过 { $passed } 个
coding-passed = 通过
coding-problems = 发现问题

## Coding team (views/coding-team.ts)

team-audit-end = 结束时
team-audit-each = 每一步之后
team-audit-never = 从不
team-change = 更改
team-workers-of = { $model } · 同时 { $workers } 个
team-worker-model = 执行者模型
team-change-worker = 更改执行者模型
team-how-many = 执行者数量
team-none = 无
team-auditor-tests = { $model } · 运行测试
team-auditor-steps = { $model } · 检查每一步
team-auditor-model = 审查者模型
team-change-auditor = 更改审查者模型
team-when = 审查者何时检查
team-team = 团队
team-roles = 角色分工
team-planner-model = 规划者模型
team-change-planner = 更改规划者模型
team-recent = 最近的任务
team-intro = 在这台电脑上一起为你编写程序的 AI，从聊天中启动。
team-no-tasks = 还没有任务。任务在聊天中开始：消息框旁的“+”› 开始编程任务。

## Trash (views/trash.ts)

trash-expressions = 表情 · 没有角色使用它们
trash-figure = 3D 形象 · 没有角色使用它
trash-chat-with = 与 { $names } 的聊天
trash-chat = 聊天
trash-persona = 人设
trash-persona-used = 人设 · 用于 { $count ->
   *[other] { $count } 个聊天
  }
trash-lorebook = 世界书
trash-lorebook-used = 世界书 · 用于 { $count ->
   *[other] { $count } 个聊天
  }
trash-character = 角色
trash-character-chats = 角色 · { $count ->
   *[other] { $count } 个聊天
  }
trash-empty = 废纸篓是空的。
trash-about = 移到这里的内容会保留 { $days } 天，之后永久删除。
trash-emptied = 已清空废纸篓。
trash-empty-trash = 清空废纸篓
trash-delete-all-ask = 永久删除{ $count ->
   *[other] 全部 { $count } 项
  }？
trash-restored = 已恢复“{ $title }”。
trash-deleted = 已永久删除“{ $title }”。
trash-deleted-at = 移到这里于 { $when }
trash-days-left = { $count ->
   *[other] 还剩 { $count } 天
  }
trash-restore = 恢复
trash-restore-chats = 恢复角色及其{ $count ->
   *[other] { $count } 个聊天
  }
trash-delete-forever = 永久删除
trash-delete-forever-ask = 永久删除“{ $title }”？删除后无法恢复。
trash-delete-forever-ask-chats = 永久删除“{ $title }”及其{ $count ->
   *[other] { $count } 个聊天
  }？删除后无法恢复。

## About Cardwave (views/about.ts)

about-no-package = 没有这个名字的软件包。
about-no-notes = 这个版本没有附带说明。
about-by = 作者：{ $by }
about-licence-of = { $name } 的许可证
about-licence = 许可证
about-folder-failed = 文件夹没有打开：{ $reason }。它位于 { $where }。
about-open-folder = 打开文件夹
about-logs-where = 在运行 Cardwave 的电脑上，Cardwave 数据文件夹中的“logs”文件夹里
about-logs = 日志
about-logs-about = Cardwave 的运行记录和崩溃记录，每天一个文件，保留 7 天：出问题时用于求助 · { $where }
about-version = 版本 { $version }
about-whats-new = 更新内容
about-packages = { $count } 个软件包
about-open-source = 开源软件
about-search = 搜索
about-find = 查找软件包
about-version-built = 版本 { $version } · { $built }
about-models = 模型
about-figures = 形象和动画
about-voices = 语音
about-voice-donations = 捐赠的声音
about-voice-acted-by = 配音：{ $name }
about-voice-vctk = CSTR VCTK Corpus（Junichi Yamagishi、Christophe Veaux、Kirsten MacDonald，University of Edinburgh）的说话人 { $speaker }；由 Kyutai 清理
about-voice-cml-tts = CML-TTS（Frederico S. Oliveira、Edresson Casanova、Arnaldo Candido Junior、Anderson S. Soares、Arlindo R. Galvão Filho）的说话人 { $speaker }，为 LibriVox 朗读
about-voice-cml-tts-cleaned = CML-TTS（Frederico S. Oliveira、Edresson Casanova、Arnaldo Candido Junior、Anderson S. Soares、Arlindo R. Galvão Filho）的说话人 { $speaker }，为 LibriVox 朗读；由 Kyutai 清理
about-lists = 服务商和模型列表

about-or = 或
about-and = 和
about-with = 附带

## Prompt preset (views/prompt-preset.ts)

prompt-new = 新建提示词预设
promptpage-system = 系统提示词
prompt-system-about = 取代角色卡的系统提示词。留空则保留角色卡的。
promptpage-note = 注释
prompt-note-about = AI 在每次回复前都会读它；你在聊天中看不到它。它放在下面设定的往前几条消息处。
prompt-depth = 往前的消息数
prompt-intro = 给 AI 的指示。在聊天的侧边栏中选择此预设，即可在那里使用。
prompt-depth-about = 1 表示放在最新消息之前，4 表示往前四条消息。
prompt-saved = 已保存预设“{ $name }”。
prompt-gone = 此提示词预设已删除。请返回并另选一个。

## Profile (views/profile.ts)

profile-change-picture = 更换头像
profile-change = 更换
profile-remove-picture = 移除头像
profile-remove = 移除
profile-picture-changed = 已更换头像。
profile-picture-removed = 已移除头像。
profile-your-picture = 你的头像
profile-no-picture = 无图片：显示你的首字母 { $letter }
profile-change-name = 更改名字
profile-this-computer = 这台电脑的账户
profile-on-server = 这台电脑上的账户
profile-account = 账户

## Server (views/server.ts)

server-copy = 复制
server-no-network = 此电脑未连接网络。请连上 Wi-Fi 或网线，让其他设备能连入。
server-switch-on-about = 这样，这个网络中的手机和其他电脑就能打开 Cardwave。每个账户用自己的密码登录。
server-switch-on = 打开
server-network-about = 手机和其他电脑在浏览器中打开 Cardwave
server-other-devices = 其他设备
server-inside = 只有这个网络中的设备能访问，除非你在路由器上设置允许外部访问。
server-add-account = 添加账户
server-owner = 这台电脑 · 可添加和删除账户
server-more-of = 更多：{ $name }
server-reset-password = 重设密码
server-delete-account = 删除账户
server-deleted = 已删除账户“{ $name }”。
server-delete-ask = 删除此账户及其角色、聊天和设置？此操作无法撤销。
server-reset-title = 重设 { $name } 的密码
server-reset-about = 这个账户将用新密码登录，并在所有已登录的地方退出登录。
server-new-password = 新密码
server-reset-done = 已重设 { $name } 的密码。
server-reset = 重设
server-accounts = 账户

## Character generator (views/generator.ts)

gen-gender-woman = 女性
gen-gender-man = 男性
gen-gender-non-binary = 非二元
gen-being-human = 人类
gen-being-not-human = 非人类
gen-age-20s = 20 多岁
gen-age-30s = 30 多岁
gen-age-40s = 40 多岁
gen-age-50s-and-older = 50 岁及以上
gen-build-slim = 纤瘦
gen-build-average = 普通
gen-build-athletic = 健美
gen-build-strong = 强壮
gen-hair-short = 短发
gen-hair-medium = 中长发
gen-hair-long = 长发
gen-colour-black = 黑色
gen-colour-brown = 棕色
gen-colour-blonde = 金色
gen-colour-red = 红色
gen-colour-grey = 灰色
gen-colour-white = 白色
gen-relation-stranger = 陌生人
gen-relation-friend = 朋友
gen-relation-partner = 伴侣
gen-relation-rival = 对手
gen-relation-colleague = 同事
gen-relation-mentor = 导师
gen-shy = 害羞
gen-outgoing = 外向
gen-gentle = 温柔
gen-harsh = 严厉
gen-serious = 严肃
gen-playful = 爱玩
gen-cautious = 谨慎
gen-bold = 大胆
gen-random = 随机
gen-slider = { $low } 到 { $high }
gen-looks = 外貌
gen-gender = 性别
gen-being = 是否为人类
gen-any = 不限
gen-age = 年龄
gen-build = 体型
gen-hair = 头发
gen-hair-colour = 发色
gen-personality = 性格
gen-relates = 这个角色对你来说是谁
gen-make = 生成角色
gen-what = 选几个特点，AI 会写出角色的第一条消息和说话方式。
interview-goes-to = 你的回答会发送给 { $provider }，用来写这个角色。
interview-stays = 你的回答只留在这台电脑上。
interview-own-words = 或者补充你自己的话
interview-in-own-words = 用你自己的话
interview-your-answer = 你的回答
interview-pick-one = 选一个
interview-pick-two = 选一到两个
interview-pick-three = 最多选三个
interview-pick-many = 符合的都可以选
interview-few-words = 几个词就够了
interview-wanted-hint = 和人相处时，或在你试过的角色身上，缺少了什么？
interview-needs-hint = 是为了你和角色在一起的时光，而不是你生活的其余部分
interview-next = 下一步
interview-skip = 跳过
interview-dont-know = 我不知道
interview-back = 返回
interview-just-make-it = 直接生成
interview-more = 更多类型
interview-writing-next = 正在写下一个问题
interview-try-again = 重试
interview-failed-where = 如果一直失败，请到 设置 › 服务商 查看服务商和模型。
gen-stop = 停止
gen-writing = 正在写角色……
interview-understood = 这是我理解的内容。
interview-you-said = 你说：“{ $words }”
interview-own-guess = AI 自己的猜测
interview-keep = 保留
interview-change = 更改
interview-remove = 移除
interview-not-it = 不是这样
interview-not-it-off = 这一行并非来自某个可以重新提问的问题
interview-own-sentence = 你自己的句子
interview-private-line = 有什么是你希望在你角色的世界里出现，或绝不出现的？
interview-private-sub = 恋爱、暴力、脏话等 · 可选
interview-make = 创建角色
interview-make-after = 之后可以在它的页面上修改。
interview-skip-all = 全部跳过
interview-private-hint = 有些人希望自己角色的世界里有这些，有些人不希望。你的回答随这个角色留在你的电脑上，只发送给写这个角色的 AI。
interview-private-free = 其他你想要或绝不想要的内容
interview-yes = 是
interview-no = 否
interview-maybe = 也许
interview-fantasy-only = 仅限幻想
interview-never = 绝不
interview-try-another = 换一个模型试试
interview-without-topic = 不写这个话题
interview-model-provider = { $model } · { $provider }
interview-reading = 正在读你的回答
interview-persona-title = 把你说的关于自己的内容添加到你的人设？
interview-persona-field = 人设
interview-persona-in-use = { $persona } · 使用中
interview-persona-new = 新建人设
interview-persona-add = 添加
interview-persona-not-now = 暂不
interview-persona-added = 已添加到“{ $persona }”。
interview-persona-you = 你
