### The UI's words in English, the language built in (language.ts). A key the UI uses that this file lacks fails the
### build (keys.ts). A further language is a file like this one, `<code>.ftl`, with the same keys; a long one is split in parts, `<code>.<part>.ftl` (en.library.ftl).

## The app

app-name = Cardwave

## The pages, as tabs, the rail and Search Cardwave name them (shell/pages.ts)

page-chats = Chats
page-characters = Characters
page-lorebooks = Lorebooks
page-personas = Personas
page-memories = Memories
page-documents = Documents
page-generator = Character generator
page-interview = Make a character together
page-profile = Profile
page-server = Sharing
page-settings = Settings
page-providers = Providers
page-voices = Voices
page-advanced = Advanced
page-css = Cardwave's CSS
page-written-tools = Tools the AI wrote
page-coding-team = Coding team
page-trash = Trash
page-about = About Cardwave
page-coding-task = Coding task
page-chat = Chat
page-new-card = New character
page-lorebook = Lorebook
page-card = Character
page-prompt-preset = Prompt preset
page-first-run = Set up Cardwave

## The places pages are under

place-library = Library
place-knowledge = Knowledge
place-account = Account
place-settings = Settings
place-advanced = Settings › Advanced

## The rail (shell/rail.ts)

rail-create = Create
rail-memories-tip = Memories: what the AI remembers from your chats
rail-documents-tip = Documents: files the AI reads when it answers
rail-show-more = Show { $count } more
rail-open-menu = Open sidebar
rail-close-menu = Close sidebar
rail-collapse = Collapse sidebar
rail-expand = Expand sidebar
rail-account = Account
rail-account-named = Account: { $name }
rail-lock = Lock

## Create's lines (shell/create.ts)

create-new-chat = New chat
create-plain-chat = Chat without a character
create-new-card = New character
create-from-picks = Character generator
create-together = Make a character together
create-new-persona = New persona
create-new-lorebook = New lorebook
create-import-card = Import card
create-import-lorebook = Import lorebook
create-new = New
create-import = Import

## The title bar and its tabs (shell/titlebar.ts)

tabs = Tabs
tab-new = New tab
tab-new-keys = New tab (Ctrl+T)
tabs-all = All tabs
tab-close = Close tab
window-minimize = Minimize
window-maximize = Maximize
window-close = Close

## The view menu (shell/view-menu.ts, theme.ts)

view = View
view-compact = Compact
theme-system = System
theme-light = Light
theme-dark = Dark
theme-downtempo = Downtempo
theme-outrun = Outrun
theme-retrowave = Retrowave
theme-neonwave-dark = Neon Wave dark
theme-neonwave-light = Neon Wave light

## Search Cardwave's button (shell/search-panel.ts)

search = Search Cardwave
search-keys = Search Cardwave (Ctrl+K)

## The labels of the settings, as their pages and Search Cardwave name them (setting-labels.ts)

label-settings-theme = Theme
label-settings-chat-layout = Chat layout
label-settings-web-pictures = Show pictures from other websites
label-settings-app-language = Language of the app
label-settings-language = Language the AI writes in
label-settings-providers = Providers
label-settings-chat = Chat
label-settings-images = Images
label-settings-voice = Voice
label-settings-search = Search
label-settings-dictation = Dictation
label-settings-web = Web
label-settings-files = Files
label-settings-commands = Commands
label-settings-image-generation = Image generation
label-settings-app = Cardwave
label-settings-dice = Dice
label-settings-folder = Folder
label-settings-written = Tools the AI wrote
label-settings-coding = Coding team
label-settings-trash = Trash
label-settings-backup = Backup
label-settings-restore = Restore
label-settings-cards-folder = Cards folder
label-settings-advanced = Advanced
label-settings-setup = Run setup again
label-settings-about = About Cardwave
label-providers-this-computer = This computer
label-voices-model = Voice model
label-voices-speed = Speed
label-voices-english = English
label-advanced-background = Helper model
label-advanced-told = What the AI is told
label-advanced-describe = Describe imported characters
label-advanced-described = Characters described
label-advanced-interview = Make a character together
label-advanced-format = Export format
label-advanced-history = Include earlier versions of each text
label-advanced-css = Your own CSS
label-coding-planner = Planner
label-coding-workers = Workers
label-coding-auditor = Auditor
label-profile-name = Name
label-profile-picture = Picture
label-profile-password = Password
label-server-network = Reachable in the home network
label-server-address = Address
label-server-mcp = Let AI apps on this computer use Cardwave

layout-bubbles = Bubbles
layout-plain = Plain

## Settings (views/settings.ts)

settings-appearance = Appearance
settings-theme-about = Follows the system unless you pick one
settings-layout-about = Messages as bubbles, or as plain text
settings-web-pictures-about = Those websites can see when you open the chat.
settings-language = Language
settings-data = Data
settings-trash-about = { $count ->
    [one] 1 item
   *[other] { $count } items
  } · emptied after { $days } days
settings-open-trash = Open Trash
settings-open = Open
settings-version = Version { $version } · licences
settings-licences = Licences
settings-advanced-about = Helper model, library, export, chat without a character, sampling, presets, your own CSS
settings-setup-about = Providers, models and voice, step by step
settings-providers-about = Addresses and keys of the services that run the models
settings-this-computer = this computer
settings-providers-named = Set up: { $names }
settings-models = Models
settings-the-chat-model = the chat model
settings-the-image-model = the image model

## The account's tabs and accounts (shell/account-tabs.ts, settings/accounts.ts)

account-sections = Account sections
account-switch = Switch account

account-password = Password
account-switch-to = Switch to { $name }
account-password-asked = Type { $name }’s password.
account-switch-button = Switch
account-add = Add account
account-add-about = Someone else’s account on this computer, with chats and characters of its own. It signs in with its password, here or on another device.
account-name = Name
account-added = Account “{ $name }” added.
account-add-button = Add
account-sign-out = Sign out
account-none = No account to sign in to
account-none-about = No account can sign in from here yet. On the computer Cardwave runs on, add one in Account › Sharing.
account-this-computer = This computer’s account
account-choose = Choose your account
account-try-again = Try again
account-back = Back
account-sign-in = Sign in

## Backup and Restore (settings/backup.ts)

backup-saving = Saving the backup.
backup-saving-to = Saving the backup to { $folder }.
backup-password = Password
backup-repeat = Repeat password
backup-encrypted = The backup is encrypted with this password; restoring it needs the password, here or on another computer.
backup-forgotten = A forgotten password cannot be recovered, and the backup cannot be restored without it.
backup-with-password = Back up with a password
backup-differ = The two passwords differ.
backup-back-up = Save backup
backup-no-file = No file chosen
backup-choose-file = Choose file
backup-its-password = The backup’s password
backup-restoring = Restoring replaces everything in Cardwave: chats, characters, personas, lorebooks, memories and settings. This cannot be undone. The password set here stays as it is.
backup-file = File
backup-restore-title = Restore a backup
backup-choose-first = Choose the backup’s file first.
backup-restore = Restore backup
backup-save = Save a backup
backup-from-file = From a backup file
backup-about-own = Chats, characters and settings in one file, encrypted with your password
backup-about-chosen = Chats, characters and settings in one file, encrypted with a password you choose

## The folder of cards (settings/card-folder.ts)

folder-watch = Import new cards automatically
folder-watch-about = A card file put in the folder comes into your library by itself
folder-recycle = Move imported files to the Recycle Bin
folder-recycle-about = Once a file is imported, it goes to the Recycle Bin

## The companion's line (library/companion-app.ts)

companion = Companion
# The companion window's name, which the system shows in its lists of windows.
companion-window = Cardwave companion
companion-made = { $name } is your companion.
companion-make = Make companion
companion-none = No companion yet. Open a character’s “…” menu and choose Make companion.
companion-named = { $name } · Starts with the app
companion-figure = Companion figure
companion-figure-about = Shown for characters without a 3D figure of their own
companion-figure-woman = Woman
companion-figure-man = Man
companion-figure-robot = Robot
companion-size = Companion size
companion-size-about = The figure's height, as a share of the screen's
companion-size-value = { $size }%

## Other programs, MCP (settings/mcp.ts)

mcp-ask-title = Let AI apps on this computer use Cardwave
mcp-ask = Programs on this computer, such as Claude Desktop, can read your characters and chats, write in your chats and use the tools switched on in Settings › Tools. What Cardwave would ask you first, they cannot do.
mcp-switch-on = Switch on
mcp-about = Such as Claude Desktop, through MCP: they use your characters, chats and tools
mcp-copy-address = Copy the MCP address
mcp-copy = Copy
mcp-as-account = As account
mcp-as-account-about = What they can see and do
mcp-remove-named = Remove { $program }
mcp-removed = “{ $program }” removed.
mcp-remove = Remove
mcp-connected = Connected
mcp-other-programs = Other programs
mcp-only-here = Only programs on this computer can connect. A removed program stays out until you switch this off and on.

## Your own CSS (settings/own-css.ts)

css-none = None
css-lines = { $count ->
    [one] 1 line
   *[other] { $count } lines
  }
css-about = { $lines } · changes the app's look
css-hint = Applied after Cardwave's own stylesheet, as you type. Save keeps it; Cancel takes it back.
css-edit-own = Edit your own CSS
css-edit = Edit

## The password (settings/password.ts)

password-forgotten = A forgotten password cannot be recovered, and your chats and characters are lost with it. Keep it somewhere safe.
password-on-title = Set a password
password-on-says = Cardwave will ask for it when it opens. Without it nobody can open Cardwave or read your chats on this computer.
password-on = Set password
password-on-done = Password set.
password-change-title = Change the password
password-change-says = Cardwave will ask for the new one when it opens.
password-change = Change
password-change-done = Password changed.
password-off-title = Switch off the password
password-off-says = Cardwave will open without asking for one. Your chats and characters stay encrypted.
password-off = Switch off
password-off-done = Password switched off.
password-differ = The two passwords differ.
password-other-says = You sign in with the new one from then on.
password-other-forgotten = If you forget it, this computer’s account can reset it, in Sharing.
password-current = Current password
password-password = Password
password-new = New password
password-repeat = Repeat password
password-asked-sign-in = Asked when you sign in
password-is-on = On · asked when the app opens
password-is-off = Off · anyone at this computer can open Cardwave
password-start-forgotten = A forgotten password cannot be recovered.
password-open = Open
password-back = Back

## Words many pages use

common-use = Use
common-in-use = { " " }· in use
common-more = More
common-edit = Edit
common-duplicate = Duplicate
# The word a copy's name ends in, as in "Rig (copy)".
common-copy-word = copy
common-delete = Delete
common-save = Save
common-cancel = Cancel
common-name = Name

## Model presets and prompt presets (settings/presets.ts, settings/prompt-presets.ts)

preset-what = A preset saves a chat model with its sampling values. Use switches to it.
preset-temperature = temperature { $value }
preset-new = New preset
preset-model-presets = Model presets
preset-using = Using “{ $name }”.
preset-added = Preset “{ $name }” added.
preset-deleted = Preset “{ $name }” deleted.
preset-saved = Preset “{ $name }” saved.
preset-delete-ask = Delete this preset?
preset-replace = Use the current model and settings
preset-replace-hint = The chat model, its provider and the sampling on this page. Off: the preset keeps its own.
preset-keeps-hint = It keeps the chat model in Settings › Models, its provider and the sampling on this page.
preset-name = Name
preset-edit = Edit preset
prompt-presets = Prompt presets
prompt-system = System prompt
prompt-note = { $depth ->
    [one] Note, 1 message back
   *[other] Note, { $depth } messages back
}
prompt-system-note = { $depth ->
    [one] System prompt · note, 1 message back
   *[other] System prompt · note, { $depth } messages back
}
prompt-as-card = As the character says
prompt-default = Default
prompt-default-name = “{ $name }” is the character's own prompt.

## Tools (settings/tools.ts, chat/tool-ask.ts)

tools-written-ask = { $count ->
    [0] None yet
    [one] 1 tool
   *[other] { $count } tools
  } · ask before a new one runs
tools-written-free = { $count ->
    [0] None yet
    [one] 1 tool
   *[other] { $count } tools
  } · a new one runs without asking
tools-folder-first = Choose a folder first
tools-web = Search and read web pages
tools-files = { $folder } only
tools-ask-writes = Ask before writing
tools-ask-writes-says = Each file is shown to you before it is written
tools-commands = Run in { $folder }, shut off from the rest of the computer and the internet
tools-ask-commands = Ask before running
tools-ask-commands-says = Each command is shown to you before it runs
tools-pictures = Uses the image model
tools-pictures-first = Set up the image model first
tools-app = Use and change your characters, chats and settings; each change asked first
tools-dice = Lets the AI roll dice; Cardwave rolls them, so the result is fair.
tools-folder-example = C:\Users\you\Documents\Shared
tools-folder-says = Files and commands reach this folder and what it holds, and nothing else.
tools-change-folder = Change folder
tools-change = Change
tools-choose = Choose
tools-none-chosen = None chosen
tools-title = Tools
tools-ask-new = { $name } wants to use a new tool: { $what }
tools-ask-write = { $name } wants to write “{ $what }” in your folder:
tools-ask-read = { $name } wants to read in your folder:
tools-ask-install = { $name } wants to download and install programs it needs:
tools-ask-web = { $name } wants to use the web:
tools-ask-app = { $name } wants to change Cardwave:
tools-ask-command = { $name } wants to run a command in your folder:
tools-allow = Allow
tools-deny = Deny
tools-allow-writing = Allow writing files for this chat
tools-allow-commands = Allow commands for this chat

## Updates (settings/update.ts)

update-title = Check for updates
update-available = Cardwave { $version } is available
update-you-have = You have { $version }.
update-up-to-date = Cardwave is up to date ({ $version }).
update-connection-error = Couldn't check for updates. Check your connection.
update-whats-new = What's new
update-close = Close
update-ok = OK
update-download = Download
update-install = Update and restart
update-installing = Downloading Cardwave { $version }…
update-auto = Check automatically
update-auto-about = Look for a new version at start and once a day
update-check = Check
update-about = Check if a newer version of the app is available.

## The breadcrumbs of a page under Settings

crumbs = Where you are

## Providers (views/providers.ts)

providers-key-end = { $where } · key ····{ $end }
providers-key-saved = { $where } · key saved
providers-no-key = { $where } · no key
providers-thinking-cannot = { $provider } can't turn thinking off for this model
providers-thinking-off = The model replies without thinking first
providers-thinking-on = The model thinks before it replies
providers-comfy-default = ComfyUI's default
providers-workflow-note = This workflow uses its own models and size, not the Images model.
providers-testing-model = Testing the model…
providers-thinking-of = { $label }: thinking
providers-thinking = Thinking
providers-testing-workflow = Testing the workflow…
providers-workflows-from = From the workflows ComfyUI holds
providers-pictures-by = Pictures by “{ $name }”.
providers-pictures-default = Pictures by ComfyUI's default workflow.
providers-workflow = Workflow
providers-not-used = Not used for anything yet
providers-folder-saved = Folder saved.
providers-change-folder = Change the folder of models
providers-choose-folder = Choose a folder of models
providers-change = Change
providers-not-set-up = Not set up
providers-folder-not-set-up = Runs models from a folder on this computer · not set up
providers-menu = Provider menu: edit, remove
providers-remove = Remove
providers-removed = Provider “{ $name }” removed.
providers-remove-with-models = Remove this provider? The models picked from it are no longer used.
providers-remove-ask = Remove this provider?
providers-remove-key = Remove key
providers-key-removed = The key is removed when you save
providers-edit = Edit provider
providers-keep-key = Leave empty to keep the saved key.
providers-saved = Provider “{ $name }” saved.
providers-added = Provider “{ $name }” added.
providers-add = Add provider
providers-about = Where the AI runs: a service on the internet or a program on this computer. Under each, what it is used for.

## Voices (views/voices.ts)

voices-stop = Stop { $name }
voices-try = Try { $name }
voices-model-about = Reads messages aloud on this computer · { $size }
voices-default-of = Default voice: { $name }
voices-menu = Voice menu: rename, delete
voices-rename = Rename
voices-delete-ask = Delete the voice “{ $name }”? Characters that use it read in the default voice again.
voices-rename-title = Rename voice
voices-name = Name
voices-speed-value = { $speed }×
voices-speed = Speed
voices-speed-about = How fast replies are read, for every voice
voices-make = Make a voice from a recording
voices-provider-failed = Couldn't load the provider's voices.
voices-provider-none = The provider lists no voices
voices-provider-own = Messages are read in the provider's own voice.
voices-voices = Voices
voices-voices-about = The voice that reads messages aloud. A character can have its own under Characters' voices.
voices-default = Default voice
voices-voice-of = Voice of { $name }
voices-back-default = Back to the default voice
voices-name-title = { $name } · { $title }
voices-choose-character = Choose a character
voices-all-have = Every character has a voice.
voices-set-for = Set a voice for a character
voices-character = Character
voices-voice = Voice
voices-character-first = Choose a character first.
voices-characters = Characters' voices
voices-downloading = Downloading · { $size } · { $percent }%
voices-downloaded = Downloaded · { $size }
voices-download-size = { $size } download
voices-action-of = { $action } { $name }
voices-language-downloaded = { $name } downloaded
voices-built-in = Built in
voices-languages = Languages it reads
voices-download = Download
voices-cancel = Cancel
voices-delete = Delete

## Advanced (views/advanced.ts)

advanced-context-size = Context size (tokens)
advanced-context-hint = Leave empty for 128,000
advanced-temperature = Temperature
advanced-temperature-about = Higher: more surprising replies. From 0 to 2
advanced-top-p = Top P
advanced-top-p-about = Lower: only the likeliest words. From 0 to 1
advanced-frequency = Frequency penalty
advanced-frequency-about = Higher: fewer repeated words. From −2 to 2
advanced-presence = Presence penalty
advanced-presence-about = Higher: more new topics. From −2 to 2
advanced-seed = Seed
advanced-seed-about = The same number gives the same reply again
advanced-from-to = From { $min } to { $max }
advanced-whole-from = A whole number from { $min }
advanced-whole = A whole number
advanced-number = A number
advanced-sampling = Sampling
advanced-sampling-about = For the chat model. Leave a value empty to use the provider's default. Saved as you type.
advanced-describing = Describing… { $count } left
advanced-all-described = Every character is described
advanced-not-described = { $count ->
    [one] 1 character
   *[other] { $count } characters
  } not described yet
advanced-describe-cards = Describe characters
advanced-describe-cost = About { $low } to { $high } tokens for { $count ->
    [one] 1 character
   *[other] { $count } characters
  }
advanced-failed = { $count ->
    [one] 1 failed
   *[other] { $count } failed
  }: { $failure }. Press Describe characters to try them again.
advanced-describe-again = Describe all again
advanced-describe-again-stop = Stop
advanced-describe-again-about = With the helper model, rewrites every character's one-line description, summary, tags and what By need finds them by, about 11,000 to 12,000 tokens each. What you edited yourself stays. Tokens are what providers bill by.
advanced-no-characters = No characters to describe
advanced-describe-again-far = { $done } of { $all } described again
advanced-describe-again-stopped = Stopped at { $done } of { $all } described again
advanced-describe-again-failed = { $count ->
    [one] 1 failed and stays as it was
   *[other] { $count } failed and stay as they were
  }: { $failure }. Press Describe all again to try once more.
advanced-describe-about = A one-line description, a summary and tags for each, written by the helper model
advanced-plain = Chat without a character
advanced-told-about = The same in every chat without a character. Write { "{{date}}" } or { "{{time}}" } and the AI gets today's date or the time
advanced-library = Library
advanced-interview-about = How the AI asks you its questions
advanced-interview-tree = Tree
advanced-interview-cloud = Cloud
advanced-interview-hybrid = Hybrid
advanced-data = Data
advanced-format-about = The format Export writes every card in; most apps open SillyTavern V3
advanced-history-about = Each text's earlier versions; only in Cardwave's own card format
advanced-helper = Helper model
advanced-the-helper = the helper model

## Cardwave's CSS (views/css-reference.ts)

cssref-rail = The left rail
cssref-main = A screen beside the rail
cssref-crumbs = The path at a page's top
cssref-group = A box of lines, as in the settings
cssref-item = A line of a box
cssref-row = A line of a list
cssref-tile = A card in the library's grid
cssref-msg = A message in a chat
cssref-bubble = A message's bubble
cssref-composer = The message field under a chat
cssref-dialog = A dialog
cssref-btn-primary = The blue button
cssref-switch = A switch
cssref-pill = A pill
cssref-notice = The notice at the window's foot
cssref-snippet-green = A green accent
cssref-snippet-square = Square bubbles
cssref-snippet-larger = Larger text
cssref-snippet-wider = Wider dialogs
cssref-snippet-tighter = Tighter spacing
cssref-snippet-black = A black dark theme
cssref-in-dark = { $light } · in the dark { $dark }
cssref-none = No variable by that name.
cssref-copy-of = Copy “{ $title }”
cssref-copied = Copied.
cssref-copy = Copy
cssref-about-1 = The variables and class names your own CSS can use. Every colour and size of the app is a variable in{ " " }
cssref-about-2 = , with a light and a dark value.
cssref-variables = Variables
cssref-search = Search
cssref-find = Find a variable
cssref-all = { $count } variables in all.
cssref-classes = Class names
cssref-snippets = Snippets

## Tools the AI wrote (views/written-tools.ts)

written-about = { $what } · made { $made }
written-about-in = { $what } · made { $made } in { $chat }
written-used = { $count ->
    [0] not used yet
    [one] used once
   *[other] used { $count } times
  }
written-none = No tools yet. Turn on “Let the AI write tools” in a chat, and what it writes is listed here.
written-ask = Ask before a new tool runs
written-ask-about = Once per tool: you allow it the first time it runs
written-in = { " " }in{ " " }
written-made = Made { $made }
written-dot-used = { " " }· { $used }
written-switch-off = Switch off
written-switch-on = Switch on
written-intro = Small tools the AI wrote for itself in chats where “Let the AI write tools” is on. They touch your files only if you allow it, and are kept for later chats.
written-deleted = Tool “{ $name }” deleted.
written-on = { $name } on
written-view-code = View code

## The coding team, shared by the chat and its pages (chat/coding.ts)

coding-quick = Quick
coding-balanced = Balanced
coding-thorough = Thorough
coding-custom = Custom
coding-running = Running
coding-done = Done
coding-failed = Failed
coding-stopped = Stopped
coding-team-says-alone = { $name }: one planner, { $workers ->
    [1] one worker
    [2] two workers
   *[other] three workers
  }, without an auditor.
coding-team-says-tests = { $name }: one planner, { $workers ->
    [1] one worker
    [2] two workers
   *[other] three workers
  } and an auditor who runs the tests.
coding-team-says-steps = { $name }: one planner, { $workers ->
    [1] one worker
    [2] two workers
   *[other] three workers
  } and an auditor who checks every step and runs the tests.
coding-team-label = { $name } · { $workers ->
    [one] 1 worker
   *[other] { $workers } workers
  }
coding-team-label-auditor = { $name } · { $workers ->
    [one] 1 worker
   *[other] { $workers } workers
  }, auditor
coding-team-label-steps = { $name } · { $workers ->
    [one] 1 worker
   *[other] { $workers } workers
  }, auditor per step
coding-tests-pass = { $passed } of { $total } tests pass
coding-passed = Passed
coding-problems = Found problems

## Coding team (views/coding-team.ts)

team-audit-end = At the end
team-audit-each = After each step
team-audit-never = Never
team-change = Change
team-workers-of = { $model } · { $workers } at once
team-worker-model = Worker model
team-change-worker = Change the worker model
team-how-many = How many workers
team-none = None
team-auditor-tests = { $model } · runs the tests
team-auditor-steps = { $model } · checks every step
team-auditor-model = Auditor model
team-change-auditor = Change the auditor model
team-when = When the auditor checks
team-team = Team
team-roles = Roles
team-planner-model = Planner model
team-change-planner = Change the planner model
team-recent = Recent tasks
team-intro = AIs that write a program for you together on this computer, started from a chat.
team-no-tasks = No tasks yet. A task is started in a chat, with the “+” beside the message field › Start a coding task.

## Trash (views/trash.ts)

trash-expressions = Expressions · no character has them
trash-figure = 3D figure · no character has it
trash-chat-with = Chat with { $names }
trash-chat = Chat
trash-persona = Persona
trash-persona-used = Persona · used in { $count ->
    [one] 1 chat
   *[other] { $count } chats
  }
trash-lorebook = Lorebook
trash-lorebook-used = Lorebook · used in { $count ->
    [one] 1 chat
   *[other] { $count } chats
  }
trash-character = Character
trash-character-chats = Character · with { $count ->
    [one] 1 chat
   *[other] { $count } chats
  }
trash-empty = The Trash is empty.
trash-about = Things moved here are kept for { $days } days, then deleted forever.
trash-emptied = Trash emptied.
trash-empty-trash = Empty Trash
trash-delete-all-ask = Delete { $count ->
    [one] the 1 item
   *[other] all { $count } items
  } forever?
trash-restored = “{ $title }” restored.
trash-deleted = “{ $title }” deleted forever.
trash-deleted-at = Moved here { $when }
trash-days-left = { $count ->
    [one] 1 day left
   *[other] { $count } days left
  }
trash-restore = Restore
trash-restore-chats = Brings back the character and { $count ->
    [one] its chat
   *[other] its { $count } chats
  }
trash-delete-forever = Delete forever
trash-delete-forever-ask = Delete “{ $title }” forever? It can’t be brought back.
trash-delete-forever-ask-chats = Delete “{ $title }” and { $count ->
    [one] its chat
   *[other] its { $count } chats
  } forever? They can’t be brought back.

## About Cardwave (views/about.ts)

about-no-package = No package by that name.
about-no-notes = No notes come with this version.
about-by = by { $by }
about-licence-of = Licence of { $name }
about-licence = Licence
about-folder-failed = The folder did not open: { $reason }. It is at { $where }.
about-open-folder = Open folder
about-logs-where = in the folder “logs” in Cardwave's data folder, on the computer Cardwave runs on
about-logs = Logs
about-logs-about = What Cardwave did and any crashes, a file a day, kept 7 days: for help when something goes wrong · { $where }
about-version = Version { $version }
about-whats-new = What's new
about-packages = { $count } packages
about-open-source = Open-source software
about-search = Search
about-find = Find a package
about-version-built = Version { $version } · { $built }
about-models = Models
about-figures = Figures and animations
about-voices = Voices
about-lists = Provider and model list

about-or = or
about-and = and
about-with = with

## Prompt preset (views/prompt-preset.ts)

prompt-new = New prompt preset
promptpage-system = System prompt
prompt-system-about = Takes the place of the card's system prompt. Leave empty to keep the card's.
promptpage-note = Note
prompt-note-about = The AI reads it before every reply; you do not see it in the chat. It goes as many messages back as set below.
prompt-depth = Messages back
prompt-intro = Instructions for the AI. Pick the preset in a chat's side panel to use it there.
prompt-depth-about = 1 puts it just before the newest message, 4 four messages back.
prompt-saved = Preset “{ $name }” saved.
prompt-gone = This prompt preset was deleted. Go back and pick another.

## Profile (views/profile.ts)

profile-change-picture = Change the picture
profile-change = Change
profile-remove-picture = Remove the picture
profile-remove = Remove
profile-picture-changed = Picture changed.
profile-picture-removed = Picture removed.
profile-your-picture = Your picture
profile-no-picture = No picture: your initial { $letter } is shown
profile-change-name = Change the name
profile-this-computer = This computer's account
profile-on-server = Account on this computer
profile-account = Account

## Server (views/server.ts)

server-copy = Copy
server-no-network = This computer isn't connected to a network. Connect it to Wi-Fi or a cable to let other devices in.
server-switch-on-about = Phones and other computers on this network can then open Cardwave. Each account signs in with its password.
server-switch-on = Switch on
server-network-about = Phones and other computers open Cardwave in a browser
server-other-devices = Other devices
server-inside = Only devices in this network can reach it, unless you set up your router to let others in.
server-add-account = Add account
server-owner = This computer · can add and remove accounts
server-more-of = More: { $name }
server-reset-password = Reset password
server-delete-account = Delete account
server-deleted = Account “{ $name }” deleted.
server-delete-ask = Delete this account with its characters, chats and settings? This cannot be undone.
server-reset-title = Reset { $name }’s password
server-reset-about = The account signs in with the new one, and is signed out wherever it is signed in.
server-new-password = New password
server-reset-done = { $name }’s password reset.
server-reset = Reset
server-accounts = Accounts

## Character generator (views/generator.ts)

gen-gender-woman = Woman
gen-gender-man = Man
gen-gender-non-binary = Non-binary
gen-being-human = Human
gen-being-not-human = Not human
gen-age-20s = 20s
gen-age-30s = 30s
gen-age-40s = 40s
gen-age-50s-and-older = 50s and older
gen-build-slim = Slim
gen-build-average = Average
gen-build-athletic = Athletic
gen-build-strong = Strong
gen-hair-short = Short
gen-hair-medium = Medium
gen-hair-long = Long
gen-colour-black = Black
gen-colour-brown = Brown
gen-colour-blonde = Blonde
gen-colour-red = Red
gen-colour-grey = Grey
gen-colour-white = White
gen-relation-stranger = Stranger
gen-relation-friend = Friend
gen-relation-partner = Partner
gen-relation-rival = Rival
gen-relation-colleague = Colleague
gen-relation-mentor = Mentor
gen-shy = Shy
gen-outgoing = Outgoing
gen-gentle = Gentle
gen-harsh = Harsh
gen-serious = Serious
gen-playful = Playful
gen-cautious = Cautious
gen-bold = Bold
gen-random = Random
gen-slider = { $low } to { $high }
gen-looks = Looks
gen-gender = Gender
gen-being = Human or not
gen-any = Any
gen-age = Age
gen-build = Build
gen-hair = Hair
gen-hair-colour = Hair colour
gen-personality = Personality
gen-relates = Who the character is to you
gen-make = Make the character
gen-what = Pick a few traits; the AI writes the character's first message and how they talk.
interview-goes-to = Your answers go to { $provider } to write the character.
interview-stays = Your answers stay on this computer.
interview-own-words = Or add your own words
interview-in-own-words = In your own words
interview-your-answer = Your answer
interview-pick-one = Pick one
interview-pick-two = Pick one or two
interview-pick-three = Pick up to three
interview-pick-many = Pick as many as fit
interview-few-words = A few words are enough
interview-wanted-hint = What was missing with people, or with characters you tried?
interview-needs-hint = For your time with the character, not the rest of your life
interview-next = Next
interview-skip = Skip
interview-dont-know = I don't know
interview-back = Back
interview-just-make-it = Just make it
interview-more = More kinds
interview-writing-next = Writing the next question
interview-try-again = Try again
interview-failed-where = If it keeps failing, look at the provider and model in Settings › Providers.
gen-stop = Stop
gen-writing = Writing the character…
interview-understood = Here is what I understood.
interview-you-said = you said: “{ $words }”
interview-own-guess = the AI's own guess
interview-keep = Keep
interview-change = Change
interview-remove = Remove
interview-not-it = That's not it
interview-not-it-off = This line rests on no one question that could be asked again
interview-own-sentence = Your own sentence
interview-private-line = Anything you want in your character's world, or never?
interview-private-sub = Romance, violence, swearing and more · optional
interview-make = Make the character
interview-make-after = You can change it on its page afterwards.
interview-skip-all = Skip all
interview-private-hint = Some people want these in their character's world, some don't. Your answers stay with this character on your computer and go only to the AI that writes the character.
interview-private-free = Anything else you want, or never want
interview-yes = Yes
interview-no = No
interview-maybe = Maybe
interview-fantasy-only = Fantasy only
interview-never = Never
interview-try-another = Try another model
interview-without-topic = Write it without that topic
interview-model-provider = { $model } · { $provider }
interview-reading = Reading your answers
interview-persona-title = Add what you said about yourself to your persona?
interview-persona-field = Persona
interview-persona-in-use = { $persona } · in use
interview-persona-new = New persona
interview-persona-add = Add
interview-persona-not-now = Not now
interview-persona-added = Added to “{ $persona }”.
interview-persona-you = You
