### Слова интерфейса на русском, переведённые с английского (en.ftl, эталонный файл) ключ за ключом; тест структуры
### (structure.test.ts) проверяет, что здесь есть все ключи в той же форме.
### Словарь, одно название для одной вещи, во всех ru.*.ftl:
###   Обращение: «вы» со строчной буквы, как в русских интерфейсах (Telegram, ChatGPT, Windows); к тому же глагол
###   прошедшего времени и краткое прилагательное при «вы» стоят во множественном числе и рода не имеют («вы сохранили», «готовы»).
###   Пол пользователя не предполагается: о нём никогда не прошедшее время и не краткое прилагательное в единственном числе
###   (не «ты сделал/сделала»); то же о персонаже: настоящее время, безличные обороты, существительные («{ $name } пишет»).
###   Cardwave, MCP, Claude Desktop, CSS: как есть. AI = ИИ; prompt = промпт; preset = пресет; chat = чат; token = токен.
###   character = персонаж; card = карточка (файл, карточка персонажа); figure = фигура (3D); persona = персона; lorebook = лорбук.
###   memory = воспоминание (страница «Воспоминания»); document = документ; library = библиотека; knowledge = знания; account = аккаунт.
###   provider = провайдер; model = модель; helper (model) = вспомогательная модель; tool = инструмент; tab = вкладка.
###   Settings = Настройки; Advanced = Дополнительно; Trash = Корзина (Cardwave); Recycle Bin = корзина Windows;
###   backup = резервная копия; back up = создать резервную копию; restore = восстановить; Sharing = Общий доступ.
###   companion = компаньон; voice = голос; dictation = диктовка; Search Cardwave = Поиск в Cardwave.
###   coding team = команда программистов; planner = планировщик; worker = исполнитель; auditor = аудитор; task = задача.
###   sign in = войти; sign out = выйти; lock = заблокировать; import = импорт; export = экспорт; password = пароль.
###   interview = интервью; generator = генератор персонажей; theme = тема; first run = первая настройка.
###   Замена имени пользователя без персоны (card-user-stand-in, cw_prompt::stand_in_user): Гость (так зовут и женщин; в
###   промпте за ним идёт настоящее время). Формы числа (Intl.PluralRules «ru»): one (1, 21, 31…), few (2–4, 22–24…),
###   many (5–20, 25…, 0), other (дроби); каждая написана здесь сама, в [one] всегда { $count }, никогда «1».
###   Кавычки «», тире —, многоточие «…». Метки посреди фразы со строчной буквы (midSentence).

## The app

app-name = Cardwave

## The pages, as tabs, the rail and Search Cardwave name them (shell/pages.ts)

page-chats = Чаты
page-characters = Персонажи
page-lorebooks = Лорбуки
page-personas = Персоны
page-memories = Воспоминания
page-documents = Документы
page-generator = Генератор персонажей
page-interview = Создать персонажа вместе
page-profile = Профиль
page-server = Общий доступ
page-settings = Настройки
page-providers = Провайдеры
page-voices = Голоса
page-advanced = Дополнительно
page-css = CSS Cardwave
page-written-tools = Инструменты, написанные ИИ
page-coding-team = Команда программистов
page-trash = Корзина
page-about = О Cardwave
page-coding-task = Задача для программистов
page-chat = Чат
page-new-card = Новый персонаж
page-lorebook = Лорбук
page-card = Персонаж
page-prompt-preset = Пресет промпта
page-first-run = Настройка Cardwave

## The places pages are under

place-library = Библиотека
place-knowledge = Знания
place-account = Аккаунт
place-settings = Настройки
place-advanced = Настройки › Дополнительно

## The rail (shell/rail.ts)

rail-create = Создать
rail-memories-tip = Воспоминания: что ИИ помнит из ваших чатов
rail-documents-tip = Документы: файлы, которые ИИ читает, когда отвечает
rail-show-more = Показать ещё { $count }
rail-open-menu = Открыть боковую панель
rail-close-menu = Закрыть боковую панель
rail-collapse = Свернуть боковую панель
rail-expand = Развернуть боковую панель
rail-account = Аккаунт
rail-account-named = Аккаунт: { $name }
rail-lock = Заблокировать

## Create's lines (shell/create.ts)

create-new-chat = Новый чат
create-plain-chat = Чат без персонажа
create-new-card = Новый персонаж
create-from-picks = Генератор персонажей
create-together = Создать персонажа вместе
create-new-persona = Новая персона
create-new-lorebook = Новый лорбук
create-import-card = Импорт карточки
create-import-lorebook = Импорт лорбука
create-new = Новое
create-import = Импорт

## The title bar and its tabs (shell/titlebar.ts)

tabs = Вкладки
tab-new = Новая вкладка
tab-new-keys = Новая вкладка (Ctrl+T)
tabs-all = Все вкладки
tab-close = Закрыть вкладку
window-minimize = Свернуть
window-maximize = Развернуть
window-close = Закрыть

## The view menu (shell/view-menu.ts, theme.ts)

view = Вид
view-compact = Компактно
theme-system = Как в системе
theme-light = Светлая
theme-dark = Тёмная
theme-downtempo = Downtempo
theme-outrun = Outrun
theme-retrowave = Retrowave
theme-neonwave-dark = Neon Wave тёмная
theme-neonwave-light = Neon Wave светлая

## Search Cardwave's button (shell/search-panel.ts)

search = Поиск в Cardwave
search-keys = Поиск в Cardwave (Ctrl+K)

## The labels of the settings, as their pages and Search Cardwave name them (setting-labels.ts)

label-settings-theme = Тема
label-settings-chat-layout = Вид чата
label-settings-web-pictures = Показывать картинки с других сайтов
label-settings-app-language = Язык приложения
label-settings-language = Язык, на котором пишет ИИ
label-settings-providers = Провайдеры
label-settings-chat = Чат
label-settings-images = Изображения
label-settings-voice = Голос
label-settings-search = Поиск
label-settings-dictation = Диктовка
label-settings-web = Интернет
label-settings-files = Файлы
label-settings-commands = Команды
label-settings-image-generation = Создание изображений
label-settings-app = Cardwave
label-settings-dice = Кости
label-settings-folder = Папка
label-settings-written = Инструменты, написанные ИИ
label-settings-coding = Команда программистов
label-settings-trash = Корзина
label-settings-backup = Резервная копия
label-settings-restore = Восстановление
label-settings-cards-folder = Папка карточек
label-settings-advanced = Дополнительно
label-settings-setup = Пройти настройку заново
label-settings-about = О Cardwave
label-providers-this-computer = Этот компьютер
label-voices-model = Модель голоса
label-voices-speed = Скорость
label-voices-english = Английский
label-advanced-background = Вспомогательная модель
label-advanced-told = Что говорится ИИ
label-advanced-describe = Описывать импортированных персонажей
label-advanced-described = Описано персонажей
label-advanced-interview = Создать персонажа вместе
label-advanced-format = Формат экспорта
label-advanced-history = Включать прежние версии каждого текста
label-advanced-css = Свой CSS
label-coding-planner = Планировщик
label-coding-workers = Исполнители
label-coding-auditor = Аудитор
label-profile-name = Имя
label-profile-picture = Изображение
label-profile-password = Пароль
label-server-network = Доступно в домашней сети
label-server-address = Адрес
label-server-mcp = Разрешить ИИ-приложениям на этом компьютере использовать Cardwave

layout-bubbles = Облачка
layout-plain = Простой текст

## Settings (views/settings.ts)

settings-appearance = Оформление
settings-theme-about = Как в системе, если не выбрать другую
settings-layout-about = Сообщения в облачках или простым текстом
settings-web-pictures-about = Эти сайты видят, когда вы открываете чат.
settings-language = Язык
settings-data = Данные
settings-trash-about = { $count ->
    [one] { $count } объект
    [few] { $count } объекта
    [many] { $count } объектов
   *[other] { $count } объекта
  } · очищается через { $days } дн.
settings-open-trash = Открыть Корзину
settings-open = Открыть
settings-version = Версия { $version } · лицензии
settings-licences = Лицензии
settings-advanced-about = Вспомогательная модель, библиотека, экспорт, чат без персонажа, сэмплинг, пресеты, свой CSS
settings-setup-about = Провайдеры, модели и голос, шаг за шагом
settings-providers-about = Адреса и ключи сервисов, на которых работают модели
settings-this-computer = этот компьютер
settings-providers-named = Настроены: { $names }
settings-models = Модели
settings-the-chat-model = модель чата
settings-the-image-model = модель изображений

## The account's tabs and accounts (shell/account-tabs.ts, settings/accounts.ts)

account-sections = Разделы аккаунта
account-switch = Сменить аккаунт

account-password = Пароль
account-switch-to = Перейти в аккаунт { $name }
account-password-asked = Введите пароль { $name }.
account-switch-button = Сменить
account-add = Добавить аккаунт
account-add-about = Аккаунт другого человека на этом компьютере, со своими чатами и персонажами. Вход в него — по его паролю, здесь или на другом устройстве.
account-name = Имя
account-added = Аккаунт «{ $name }» добавлен.
account-add-button = Добавить
account-sign-out = Выйти
account-none = Нет аккаунта для входа
account-none-about = Пока ни одна учётная запись не может войти отсюда. На компьютере, где работает Cardwave, добавьте её в Аккаунт › Общий доступ.
account-this-computer = Аккаунт этого компьютера
account-choose = Выберите свой аккаунт
account-try-again = Попробовать снова
account-back = Назад
account-sign-in = Войти

## Backup and Restore (settings/backup.ts)

backup-saving = Резервная копия сохраняется.
backup-saving-to = Резервная копия сохраняется в { $folder }.
backup-password = Пароль
backup-repeat = Повторите пароль
backup-encrypted = Резервная копия зашифрована этим паролем; для восстановления нужен пароль, здесь или на другом компьютере.
backup-forgotten = Забытый пароль восстановить нельзя, а без него нельзя восстановить и резервную копию.
backup-with-password = Создать резервную копию с паролем
backup-differ = Пароли не совпадают.
backup-back-up = Сохранить копию
backup-no-file = Файл не выбран
backup-choose-file = Выбрать файл
backup-its-password = Пароль резервной копии
backup-restoring = Восстановление заменяет всё в Cardwave: чаты, персонажей, персоны, лорбуки, воспоминания и настройки. Это нельзя отменить. Пароль, заданный здесь, остаётся прежним.
backup-file = Файл
backup-restore-title = Восстановить резервную копию
backup-choose-first = Сначала выберите файл резервной копии.
backup-restore = Восстановить копию
backup-save = Сохранить резервную копию
backup-from-file = Из файла резервной копии
backup-about-own = Чаты, персонажи и настройки в одном файле, зашифрованном вашим паролем
backup-about-chosen = Чаты, персонажи и настройки в одном файле, зашифрованном паролем, который вы выберете

## The folder of cards (settings/card-folder.ts)

folder-watch = Импортировать новые карточки автоматически
folder-watch-about = Файл карточки, положенный в папку, сам попадает в вашу библиотеку
folder-recycle = Перемещать импортированные файлы в корзину Windows
folder-recycle-about = Как только файл импортирован, он отправляется в Корзину

## The companion's line (library/companion-app.ts)

companion = Компаньон
# The companion window's name, which the system shows in its lists of windows.
companion-window = Компаньон Cardwave
companion-made = { $name } — ваш компаньон.
companion-make = Сделать компаньоном
companion-none = Компаньона пока нет. Откройте меню «…» персонажа и выберите «Сделать компаньоном».
companion-named = { $name } · Запускается вместе с приложением
companion-figure = Фигура компаньона
companion-figure-about = Показывается у персонажей без своей 3D-фигуры
companion-figure-woman = Женщина
companion-figure-man = Мужчина
companion-figure-robot = Робот
companion-size = Размер компаньона
companion-size-about = Высота фигуры в процентах от высоты экрана
companion-size-value = { $size }%

## Other programs, MCP (settings/mcp.ts)

mcp-ask-title = Разрешить ИИ-приложениям на этом компьютере использовать Cardwave
mcp-ask = Программы на этом компьютере, например Claude Desktop, могут читать ваших персонажей и чаты, писать в ваших чатах и использовать инструменты, включённые в Настройки › Инструменты. То, о чём Cardwave сначала спросил бы вас, они сделать не могут.
mcp-switch-on = Включить
mcp-about = Например, Claude Desktop, через MCP: они используют ваших персонажей, чаты и инструменты
mcp-copy-address = Копировать адрес MCP
mcp-copy = Копировать
mcp-as-account = От имени аккаунта
mcp-as-account-about = Что они могут видеть и делать
mcp-remove-named = Удалить { $program }
mcp-removed = Программа «{ $program }» удалена.
mcp-remove = Удалить
mcp-connected = Подключено
mcp-other-programs = Другие программы
mcp-only-here = Подключаться могут только программы на этом компьютере. Удалённая программа не подключится, пока вы не выключите и снова не включите этот параметр.

## Your own CSS (settings/own-css.ts)

css-none = Нет
css-lines = { $count ->
    [one] { $count } строка
    [few] { $count } строки
    [many] { $count } строк
   *[other] { $count } строки
  }
css-about = { $lines } · меняет вид приложения
css-hint = Применяется поверх стилей Cardwave прямо по мере ввода. «Сохранить» оставляет его, «Отмена» возвращает прежний.
css-edit-own = Изменить свой CSS
css-edit = Изменить

## The password (settings/password.ts)

password-forgotten = Забытый пароль нельзя восстановить, и вместе с ним пропадут ваши чаты и персонажи. Храните его в надёжном месте.
password-on-title = Задать пароль
password-on-says = Cardwave будет спрашивать его при открытии. Без него никто не откроет Cardwave и не прочтёт ваши чаты на этом компьютере.
password-on = Задать пароль
password-on-done = Пароль задан.
password-change-title = Сменить пароль
password-change-says = Cardwave будет запрашивать новый пароль при открытии.
password-change = Сменить
password-change-done = Пароль изменён.
password-off-title = Выключить пароль
password-off-says = Cardwave будет открываться без пароля. Ваши чаты и персонажи остаются зашифрованными.
password-off = Выключить
password-off-done = Пароль выключен.
password-differ = Пароли не совпадают.
password-other-says = С этого момента вход — с новым паролем.
password-other-forgotten = Если его забыть, аккаунт этого компьютера может сбросить его в разделе «Общий доступ».
password-current = Текущий пароль
password-password = Пароль
password-new = Новый пароль
password-repeat = Повторите пароль
password-asked-sign-in = Запрашивается при входе
password-is-on = Включён · запрашивается при открытии приложения
password-is-off = Выключен · любой за этим компьютером может открыть Cardwave
password-start-forgotten = Забытый пароль восстановить нельзя.
password-open = Открыть
password-back = Назад

## Words many pages use

common-use = Использовать
common-in-use = { " " }· используется
common-more = Ещё
common-edit = Изменить
common-duplicate = Дублировать
# The word a copy's name ends in, as in "Rig (copy)".
common-copy-word = копия
common-delete = Удалить
common-save = Сохранить
common-cancel = Отмена
common-name = Имя

## Model presets and prompt presets (settings/presets.ts, settings/prompt-presets.ts)

preset-what = Пресет сохраняет модель чата вместе с её параметрами сэмплинга. «Использовать» переключает на него.
preset-temperature = температура { $value }
preset-new = Новый пресет
preset-model-presets = Пресеты моделей
preset-using = Используется «{ $name }».
preset-added = Пресет «{ $name }» добавлен.
preset-deleted = Пресет «{ $name }» удалён.
preset-saved = Пресет «{ $name }» сохранён.
preset-delete-ask = Удалить этот пресет?
preset-replace = Взять текущую модель и настройки
preset-replace-hint = Модель чата, её провайдер и сэмплинг на этой странице. Выключено: пресет сохраняет свои.
preset-keeps-hint = Он сохраняет модель чата из Настройки › Модели, её провайдера и сэмплинг на этой странице.
preset-name = Имя
preset-edit = Изменить пресет
prompt-presets = Пресеты промптов
prompt-system = Системный промпт
prompt-note = { $depth ->
    [one] Заметка, { $depth } сообщение назад
    [few] Заметка, { $depth } сообщения назад
    [many] Заметка, { $depth } сообщений назад
   *[other] Заметка, { $depth } сообщения назад
}
prompt-system-note = { $depth ->
    [one] Системный промпт · заметка, { $depth } сообщение назад
    [few] Системный промпт · заметка, { $depth } сообщения назад
    [many] Системный промпт · заметка, { $depth } сообщений назад
   *[other] Системный промпт · заметка, { $depth } сообщения назад
}
prompt-as-card = Как у персонажа
prompt-default = По умолчанию
prompt-default-name = «{ $name }» — собственный промпт персонажа.

## Tools (settings/tools.ts, chat/tool-ask.ts)

tools-written-ask = { $count ->
    [0] Пока нет
    [one] { $count } инструмент
    [few] { $count } инструмента
    [many] { $count } инструментов
   *[other] { $count } инструмента
  } · спрашивать, прежде чем запустить новый
tools-written-free = { $count ->
    [0] Пока нет
    [one] { $count } инструмент
    [few] { $count } инструмента
    [many] { $count } инструментов
   *[other] { $count } инструмента
  } · новый запускается без вопроса
tools-folder-first = Сначала выберите папку
tools-web = Искать и читать веб-страницы
tools-files = Только { $folder }
tools-ask-writes = Спрашивать перед записью
tools-ask-writes-says = Каждый файл показывается вам до того, как будет записан
tools-commands = Выполнять в папке { $folder }, отрезанной от остального компьютера и интернета
tools-ask-commands = Спрашивать перед выполнением
tools-ask-commands-says = Каждая команда показывается вам до выполнения
tools-pictures = Использует модель изображений
tools-pictures-first = Сначала настройте модель изображений
tools-app = Пользоваться вашими персонажами, чатами и настройками и менять их; о каждом изменении сначала спрашивается
tools-dice = Позволяет ИИ бросать кости; бросает их Cardwave, поэтому результат честный.
tools-folder-example = C:\Users\вы\Documents\Общая
tools-folder-says = Файлы и команды достигают только этой папки и её содержимого, и ничего больше.
tools-change-folder = Сменить папку
tools-change = Сменить
tools-choose = Выбрать
tools-none-chosen = Не выбрана
tools-title = Инструменты
tools-ask-new = { $name } хочет использовать новый инструмент: { $what }
tools-ask-write = { $name } хочет записать «{ $what }» в вашу папку:
tools-ask-read = { $name } хочет прочитать в вашей папке:
tools-ask-install = { $name } хочет скачать и установить нужные ему программы:
tools-ask-web = { $name } хочет воспользоваться интернетом:
tools-ask-app = { $name } хочет изменить Cardwave:
tools-ask-command ={ $name } хочет выполнить команду в вашей папке:
tools-allow = Разрешить
tools-deny = Запретить
tools-allow-writing = Разрешить запись файлов в этом чате
tools-allow-commands = Разрешить команды в этом чате

## Updates (settings/update.ts)

update-title = Проверить обновления
update-available = Доступна версия Cardwave { $version }
update-you-have = У вас версия { $version }.
update-up-to-date = У вас последняя версия Cardwave ({ $version }).
update-connection-error = Не удалось проверить обновления. Проверьте подключение.
update-whats-new = Что нового
update-close = Закрыть
update-ok = ОК
update-download = Скачать
update-install = Обновить и перезапустить
update-installing = Скачивается Cardwave { $version }…
update-auto = Проверять автоматически
update-auto-about = Искать новую версию при запуске и раз в день
update-check = Проверить
update-about = Проверить, есть ли более новая версия приложения.

## The breadcrumbs of a page under Settings

crumbs = Где вы находитесь

## Providers (views/providers.ts)

providers-key-end = { $where } · ключ ····{ $end }
providers-key-saved = { $where } · ключ сохранён
providers-no-key = { $where } · без ключа
providers-thinking-cannot = { $provider } не может отключить размышление у этой модели
providers-thinking-off = Модель отвечает, не размышляя сначала
providers-thinking-on = Модель размышляет перед ответом
providers-comfy-default = По умолчанию в ComfyUI
providers-workflow-note = Этот воркфлоу использует свои модели и размер, а не модель изображений.
providers-testing-model = Проверка модели…
providers-thinking-of = { $label }: размышление
providers-thinking = Размышление
providers-testing-workflow = Проверка воркфлоу…
providers-workflows-from = Из воркфлоу, которые хранит ComfyUI
providers-pictures-by = Изображения по воркфлоу «{ $name }».
providers-pictures-default = Изображения по воркфлоу ComfyUI по умолчанию.
providers-workflow = Воркфлоу
providers-not-used = Пока ни для чего не используется
providers-folder-saved = Папка сохранена.
providers-change-folder = Сменить папку моделей
providers-choose-folder = Выбрать папку моделей
providers-change = Сменить
providers-not-set-up = Не настроено
providers-folder-not-set-up = Запускает модели из папки на этом компьютере · не настроено
providers-menu = Меню провайдера: изменить, удалить
providers-remove = Удалить
providers-removed = Провайдер «{ $name }» удалён.
providers-remove-with-models = Удалить этого провайдера? Выбранные у него модели больше не будут использоваться.
providers-remove-ask = Удалить этого провайдера?
providers-remove-key = Удалить ключ
providers-key-removed = Ключ удалится при сохранении
providers-edit = Изменить провайдера
providers-keep-key = Оставьте пустым, чтобы сохранить прежний ключ.
providers-saved = Провайдер «{ $name }» сохранён.
providers-added = Провайдер «{ $name }» добавлен.
providers-add = Добавить провайдера
providers-about = Где работает ИИ: сервис в интернете или программа на этом компьютере. Под каждым — для чего он используется.

## Voices (views/voices.ts)

voices-stop = Остановить: { $name }
voices-try = Прослушать: { $name }
voices-model-about = Читает сообщения вслух на этом компьютере · { $size }
voices-default-of = Голос по умолчанию: { $name }
voices-menu = Меню голоса: переименовать, удалить
voices-rename = Переименовать
voices-delete-ask = Удалить голос «{ $name }»? Персонажи с этим голосом снова будут читать голосом по умолчанию.
voices-rename-title = Переименовать голос
voices-name = Название
voices-speed-value = { $speed }×
voices-speed = Скорость
voices-speed-about = Как быстро читаются ответы, для всех голосов
voices-make = Создать голос из записи
voices-provider-failed = Не удалось загрузить голоса провайдера.
voices-provider-none = Провайдер не перечисляет голосов
voices-provider-own = Сообщения читаются собственным голосом провайдера.
voices-voices = Голоса
voices-voices-about = Голос, который читает сообщения вслух. У персонажа может быть свой — в разделе «Голоса персонажей».
voices-default = Голос по умолчанию
voices-voice-of = Голос персонажа { $name }
voices-back-default = Вернуть голос по умолчанию
voices-name-title = { $name } · { $title }
voices-choose-character = Выберите персонажа
voices-all-have = У каждого персонажа есть голос.
voices-set-for = Задать голос персонажу
voices-character = Персонаж
voices-voice = Голос
voices-character-first = Сначала выберите персонажа.
voices-characters = Голоса персонажей
voices-downloading = Загрузка · { $size } · { $percent }%
voices-downloaded = Скачано · { $size }
voices-download-size = Загрузка { $size }
voices-action-of = { $action }: { $name }
voices-language-downloaded = { $name }: скачано
voices-built-in = Встроенный
voices-languages = Языки, на которых он читает
voices-download = Скачать
voices-cancel = Отмена
voices-delete = Удалить

## Advanced (views/advanced.ts)

advanced-context-size = Размер контекста (токены)
advanced-context-hint = Оставьте пустым для 128 000
advanced-temperature = Температура
advanced-temperature-about = Выше: более неожиданные ответы. От 0 до 2
advanced-top-p = Top P
advanced-top-p-about = Ниже: только самые вероятные слова. От 0 до 1
advanced-frequency = Штраф за частоту
advanced-frequency-about = Выше: меньше повторов слов. От −2 до 2
advanced-presence = Штраф за присутствие
advanced-presence-about = Выше: больше новых тем. От −2 до 2
advanced-seed = Seed
advanced-seed-about = То же число снова даёт тот же ответ
advanced-from-to = От { $min } до { $max }
advanced-whole-from = Целое число от { $min }
advanced-whole = Целое число
advanced-number = Число
advanced-sampling = Сэмплинг
advanced-sampling-about = Для модели чата. Оставьте значение пустым, чтобы использовать значение провайдера по умолчанию. Сохраняется по мере ввода.
advanced-describing = Описание… осталось { $count }
advanced-all-described = Все персонажи описаны
advanced-not-described = Ещё не описано: { $count ->
    [one] { $count } персонаж
    [few] { $count } персонажа
    [many] { $count } персонажей
   *[other] { $count } персонажа
  }
advanced-describe-cards = Описать персонажей
advanced-describe-cost = Около { $low }–{ $high } токенов на { $count ->
    [one] { $count } персонажа
    [few] { $count } персонажей
    [many] { $count } персонажей
   *[other] { $count } персонажа
  }
advanced-failed = { $count ->
    [one] { $count } сбой
    [few] { $count } сбоя
    [many] { $count } сбоев
   *[other] { $count } сбоя
  }: { $failure }. Нажмите «Описать персонажей», чтобы попробовать снова.
advanced-describe-again = Описать все заново
advanced-describe-again-stop = Остановить
advanced-describe-again-about = Заново пишет вспомогательной моделью однострочное описание, сводку, теги каждого персонажа и то, по чему его находит «По потребности», примерно 11 000–12 000 токенов на каждого. То, что вы правили сами, остаётся. Провайдеры берут плату за токены.
advanced-no-characters = Нет персонажей для описания
advanced-describe-again-far = Заново описано { $done } из { $all }
advanced-describe-again-stopped = Остановлено: заново описано { $done } из { $all }
advanced-describe-again-failed = { $count ->
    [one] { $count } сбой, при нём персонаж остаётся прежним
    [few] { $count } сбоя, при них персонажи остаются прежними
    [many] { $count } сбоев, при них персонажи остаются прежними
   *[other] { $count } сбоя, при них персонажи остаются прежними
  }: { $failure }. Нажмите «Описать все заново», чтобы попробовать ещё раз.
advanced-describe-about = Для каждого — описание в одну строку, сводка и теги от вспомогательной модели
advanced-plain = Чат без персонажа
advanced-told-about = Одинаковы во всех чатах без персонажа. Напишите { "{{date}}" } или { "{{time}}" }, и ИИ получит сегодняшнюю дату или время
advanced-library = Библиотека
advanced-interview-about = Как ИИ задаёт вам вопросы
advanced-interview-tree = Дерево
advanced-interview-cloud = Облако
advanced-interview-hybrid = Смешанный
advanced-data = Данные
advanced-format-about = Формат, в котором Экспорт записывает каждую карточку; большинство приложений открывают SillyTavern V3
advanced-history-about = Прежние версии каждого текста; только в собственном формате карточек Cardwave
advanced-helper = Вспомогательная модель
advanced-the-helper = вспомогательная модель

## Cardwave's CSS (views/css-reference.ts)

cssref-rail = Левая панель
cssref-main = Экран рядом с панелью
cssref-crumbs = Путь вверху страницы
cssref-group = Блок строк, как в настройках
cssref-item = Строка блока
cssref-row = Строка списка
cssref-tile = Карточка в сетке библиотеки
cssref-msg = Сообщение в чате
cssref-bubble = Облачко сообщения
cssref-composer = Поле сообщения под чатом
cssref-dialog = Диалог
cssref-btn-primary = Синяя кнопка
cssref-switch = Переключатель
cssref-pill = Плашка
cssref-notice = Уведомление внизу окна
cssref-snippet-green = Зелёный акцент
cssref-snippet-square = Квадратные облачка
cssref-snippet-larger = Крупнее текст
cssref-snippet-wider = Шире диалоги
cssref-snippet-tighter = Плотнее отступы
cssref-snippet-black = Чёрная тёмная тема
cssref-in-dark = { $light } · в тёмной теме { $dark }
cssref-none = Нет переменной с таким именем.
cssref-copy-of = Копировать «{ $title }»
cssref-copied = Скопировано.
cssref-copy = Копировать
cssref-about-1 = Переменные и имена классов, которые может использовать ваш CSS. Каждый цвет и размер приложения — переменная в{ " " }
cssref-about-2 = , со светлым и тёмным значением.
cssref-variables = Переменные
cssref-search = Поиск
cssref-find = Найти переменную
cssref-all = Всего переменных: { $count }.
cssref-classes = Имена классов
cssref-snippets = Фрагменты

## Tools the AI wrote (views/written-tools.ts)

written-about = { $what } · создан { $made }
written-about-in = { $what } · создан { $made } в чате { $chat }
written-used = { $count ->
    [0] ещё не использовался
    [one] использован { $count } раз
    [few] использован { $count } раза
    [many] использован { $count } раз
   *[other] использован { $count } раза
  }
written-none = Инструментов пока нет. Включите «ИИ пишет инструменты» в чате, и написанное им появится здесь.
written-ask = Спрашивать перед запуском нового инструмента
written-ask-about = Один раз для каждого инструмента: вы разрешаете его при первом запуске
written-in = { " " }в чате{ " " }
written-made = Создан { $made }
written-dot-used = { " " }· { $used }
written-switch-off = Выключить
written-switch-on = Включить
written-intro = Небольшие инструменты, которые ИИ написал для себя в чатах с включённым «ИИ пишет инструменты». Они трогают ваши файлы только с вашего разрешения и сохраняются для следующих чатов.
written-deleted = Инструмент «{ $name }» удалён.
written-on = { $name }: включён
written-view-code = Посмотреть код

## The coding team, shared by the chat and its pages (chat/coding.ts)

coding-quick = Быстро
coding-balanced = Сбалансированно
coding-thorough = Тщательно
coding-custom = Своя
coding-running = Выполняется
coding-done = Готово
coding-failed = Сбой
coding-stopped = Остановлено
coding-team-says-alone = { $name }: один планировщик, { $workers ->
    [1] один исполнитель
    [2] два исполнителя
   *[other] три исполнителя
  }, без аудитора.
coding-team-says-tests = { $name }: один планировщик, { $workers ->
    [1] один исполнитель
    [2] два исполнителя
   *[other] три исполнителя
  } и аудитор, который запускает тесты.
coding-team-says-steps = { $name }: один планировщик, { $workers ->
    [1] один исполнитель
    [2] два исполнителя
   *[other] три исполнителя
  } и аудитор, который проверяет каждый шаг и запускает тесты.
coding-team-label = { $name } · { $workers ->
    [one] { $workers } исполнитель
    [few] { $workers } исполнителя
    [many] { $workers } исполнителей
   *[other] { $workers } исполнителя
  }
coding-team-label-auditor = { $name } · { $workers ->
    [one] { $workers } исполнитель
    [few] { $workers } исполнителя
    [many] { $workers } исполнителей
   *[other] { $workers } исполнителя
  }, аудитор
coding-team-label-steps = { $name } · { $workers ->
    [one] { $workers } исполнитель
    [few] { $workers } исполнителя
    [many] { $workers } исполнителей
   *[other] { $workers } исполнителя
  }, аудитор на каждом шаге
coding-tests-pass = Пройдено тестов: { $passed } из { $total }
coding-passed = Пройдено
coding-problems = Найдены проблемы

## Coding team (views/coding-team.ts)

team-audit-end = В конце
team-audit-each = После каждого шага
team-audit-never = Никогда
team-change = Сменить
team-workers-of = { $model } · { $workers } одновременно
team-worker-model = Модель исполнителя
team-change-worker = Сменить модель исполнителя
team-how-many = Сколько исполнителей
team-none = Нет
team-auditor-tests = { $model } · запускает тесты
team-auditor-steps = { $model } · проверяет каждый шаг
team-auditor-model = Модель аудитора
team-change-auditor = Сменить модель аудитора
team-when = Когда проверяет аудитор
team-team = Команда
team-roles = Роли
team-planner-model = Модель планировщика
team-change-planner = Сменить модель планировщика
team-recent = Недавние задачи
team-intro = ИИ, которые вместе пишут для вас программу на этом компьютере; запускаются из чата.
team-no-tasks = Задач пока нет. Задача начинается в чате: «+» рядом с полем сообщения › Начать задачу по программированию.

## Trash (views/trash.ts)

trash-expressions = Эмоции · нет ни у одного персонажа
trash-figure = 3D-фигура · нет ни у одного персонажа
trash-chat-with = Чат: { $names }
trash-chat = Чат
trash-persona = Персона
trash-persona-used = Персона · используется в { $count ->
    [one] { $count } чате
    [few] { $count } чатах
    [many] { $count } чатах
   *[other] { $count } чата
  }
trash-lorebook = Лорбук
trash-lorebook-used = Лорбук · используется в { $count ->
    [one] { $count } чате
    [few] { $count } чатах
    [many] { $count } чатах
   *[other] { $count } чата
  }
trash-character = Персонаж
trash-character-chats = Персонаж · { $count ->
    [one] { $count } чат
    [few] { $count } чата
    [many] { $count } чатов
   *[other] { $count } чата
  }
trash-empty = Корзина пуста.
trash-about = Перемещённое сюда хранится { $days } дн., затем удаляется навсегда.
trash-emptied = Корзина очищена.
trash-empty-trash = Очистить Корзину
trash-delete-all-ask = Удалить { $count ->
    [one] { $count } объект
    [few] все { $count } объекта
    [many] все { $count } объектов
   *[other] все { $count } объекта
  } навсегда?
trash-restored = «{ $title }» восстановлено.
trash-deleted = «{ $title }» удалено навсегда.
trash-deleted-at = Перемещено сюда { $when }
trash-days-left = { $count ->
    [one] Остался { $count } день
    [few] Осталось { $count } дня
    [many] Осталось { $count } дней
   *[other] Осталось { $count } дня
  }
trash-restore = Восстановить
trash-restore-chats = Возвращает персонажа и { $count ->
    [one] его { $count } чат
    [few] его { $count } чата
    [many] его { $count } чатов
   *[other] его { $count } чата
  }
trash-delete-forever = Удалить навсегда
trash-delete-forever-ask = Удалить «{ $title }» навсегда? Вернуть будет нельзя.
trash-delete-forever-ask-chats = Удалить «{ $title }» и { $count ->
    [one] его { $count } чат
    [few] его { $count } чата
    [many] его { $count } чатов
   *[other] его { $count } чата
  } навсегда? Вернуть будет нельзя.

## About Cardwave (views/about.ts)

about-no-package = Нет пакета с таким именем.
about-no-notes = К этой версии нет заметок.
about-by = автор: { $by }
about-licence-of = Лицензия { $name }
about-licence = Лицензия
about-folder-failed = Папка не открылась: { $reason }. Она находится здесь: { $where }.
about-open-folder = Открыть папку
about-logs-where = в папке «logs» в папке данных Cardwave, на компьютере, где работает Cardwave
about-logs = Журналы
about-logs-about = Что делал Cardwave и сбои, по файлу в день, хранятся 7 дней: для помощи, когда что-то идёт не так · { $where }
about-version = Версия { $version }
about-whats-new = Что нового
about-packages = Пакетов: { $count }
about-open-source = Программы с открытым кодом
about-search = Поиск
about-find = Найти пакет
about-version-built = Версия { $version } · { $built }
about-models = Модели
about-figures = Фигуры и анимации
about-voices = Голоса
about-lists = Список провайдеров и моделей

about-or = или
about-and = и
about-with = с

## Prompt preset (views/prompt-preset.ts)

prompt-new = Новый пресет промпта
promptpage-system = Системный промпт
prompt-system-about = Заменяет системный промпт карточки. Оставьте пустым, чтобы сохранить промпт карточки.
promptpage-note = Заметка
prompt-note-about = ИИ читает её перед каждым ответом; в чате вы её не видите. Она ставится на столько сообщений назад, сколько задано ниже.
prompt-depth = Сообщений назад
prompt-intro = Указания для ИИ. Выберите этот пресет на боковой панели чата, чтобы он действовал там.
prompt-depth-about = 1 ставит её прямо перед самым новым сообщением, 4 — на четыре сообщения назад.
prompt-saved = Пресет «{ $name }» сохранён.
prompt-gone = Этот пресет промпта удалён. Вернитесь и выберите другой.

## Profile (views/profile.ts)

profile-change-picture = Сменить изображение
profile-change = Сменить
profile-remove-picture = Удалить изображение
profile-remove = Удалить
profile-picture-changed = Изображение изменено.
profile-picture-removed = Изображение удалено.
profile-your-picture = Ваше изображение
profile-no-picture = Без изображения: показывается ваша буква { $letter }
profile-change-name = Сменить имя
profile-this-computer = Аккаунт этого компьютера
profile-on-server = Аккаунт на этом компьютере
profile-account = Аккаунт

## Server (views/server.ts)

server-copy = Копировать
server-no-network = Этот компьютер не подключён к сети. Подключите его к Wi-Fi или кабелем, чтобы пустить другие устройства.
server-switch-on-about = Тогда телефоны и другие компьютеры в этой сети смогут открывать Cardwave. Каждый аккаунт входит по своему паролю.
server-switch-on = Включить
server-network-about = Телефоны и другие компьютеры открывают Cardwave в браузере
server-other-devices = Другие устройства
server-inside = Доступ есть только у устройств этой сети, если только вы не настроите роутер, чтобы впускать других.
server-add-account = Добавить аккаунт
server-owner = Этот компьютер · может добавлять и удалять аккаунты
server-more-of = Ещё: { $name }
server-reset-password = Сбросить пароль
server-delete-account = Удалить аккаунт
server-deleted = Аккаунт «{ $name }» удалён.
server-delete-ask = Удалить эту учётную запись вместе с её персонажами, чатами и настройками? Это нельзя отменить.
server-reset-title = Сбросить пароль аккаунта { $name }
server-reset-about = Аккаунт входит с новым паролем, а везде, где в него выполнен вход, произойдёт выход.
server-new-password = Новый пароль
server-reset-done = Пароль аккаунта { $name } сброшен.
server-reset = Сбросить
server-accounts = Аккаунты

## Character generator (views/generator.ts)

gen-gender-woman = Женщина
gen-gender-man = Мужчина
gen-gender-non-binary = Небинарный человек
gen-being-human = Человек
gen-being-not-human = Не человек
gen-age-20s = 20–29 лет
gen-age-30s = 30–39 лет
gen-age-40s = 40–49 лет
gen-age-50s-and-older = 50 лет и старше
gen-build-slim = Стройное
gen-build-average = Среднее
gen-build-athletic = Спортивное
gen-build-strong = Крепкое
gen-hair-short = Короткие
gen-hair-medium = Средней длины
gen-hair-long = Длинные
gen-colour-black = Чёрные
gen-colour-brown = Каштановые
gen-colour-blonde = Светлые
gen-colour-red = Рыжие
gen-colour-grey = Седые
gen-colour-white = Белые
gen-relation-stranger = Незнакомый человек
gen-relation-friend = Друг
gen-relation-partner = Партнёр
gen-relation-rival = Соперник
gen-relation-colleague = Коллега
gen-relation-mentor = Наставник
gen-shy = Застенчивость
gen-outgoing = Общительность
gen-gentle = Мягкость
gen-harsh = Резкость
gen-serious = Серьёзность
gen-playful = Игривость
gen-cautious = Осторожность
gen-bold = Смелость
gen-random = Случайно
gen-slider = { $low } — { $high }
gen-looks = Внешность
gen-gender = Пол
gen-being = Человек или нет
gen-any = Любой
gen-age = Возраст
gen-build = Телосложение
gen-hair = Волосы
gen-hair-colour = Цвет волос
gen-personality = Характер
gen-relates = Кем персонаж вам приходится
gen-make = Создать персонажа
gen-what = Выберите несколько черт; ИИ напишет первое сообщение персонажа и то, как он говорит.
interview-goes-to = Ваши ответы отправляются в { $provider }, чтобы написать персонажа.
interview-stays = Ваши ответы остаются на этом компьютере.
interview-own-words = Или добавьте своими словами
interview-in-own-words = Своими словами
interview-your-answer = Ваш ответ
interview-pick-one = Выберите одно
interview-pick-two = Выберите одно или два
interview-pick-three = Выберите до трёх
interview-pick-many = Выберите все подходящие
interview-few-words = Хватит нескольких слов
interview-wanted-hint = Чего не хватало с людьми или с персонажами, которых вы пробовали?
interview-needs-hint = Для времени с персонажем, а не для всей остальной жизни
interview-next = Далее
interview-skip = Пропустить
interview-dont-know = Не знаю
interview-back = Назад
interview-just-make-it = Просто создать
interview-more = Другие виды
interview-writing-next = Пишется следующий вопрос
interview-try-again = Попробовать снова
interview-failed-where = Если ошибка повторяется, проверьте провайдера и модель в Настройки › Провайдеры.
gen-stop = Остановить
gen-writing = Персонаж пишется…
interview-understood = Вот что удалось понять.
interview-you-said = вы сказали: «{ $words }»
interview-own-guess = собственная догадка ИИ
interview-keep = Оставить
interview-change = Изменить
interview-remove = Удалить
interview-not-it = Не то
interview-not-it-off = Эта строка не опирается ни на один вопрос, который можно задать снова
interview-own-sentence = Своя фраза
interview-private-line = Что вы хотите видеть в мире вашего персонажа, а чего — никогда?
interview-private-sub = Романтика, насилие, ругательства и другое · необязательно
interview-make = Создать персонажа
interview-make-after = Потом его можно изменить на его странице.
interview-skip-all = Пропустить всё
interview-private-hint = Одни хотят видеть такое в мире своего персонажа, другие — нет. Ваши ответы остаются с этим персонажем на вашем компьютере и уходят только ИИ, который пишет персонажа.
interview-private-free = Что ещё вы хотите или никогда не хотите
interview-yes = Да
interview-no = Нет
interview-maybe = Возможно
interview-fantasy-only = Только в фантазиях
interview-never = Никогда
interview-try-another = Попробовать другую модель
interview-without-topic = Написать без этой темы
interview-model-provider = { $model } · { $provider }
interview-reading = Ваши ответы читаются
interview-persona-title = Добавить в вашу персону то, что вы сказали о себе?
interview-persona-field = Персона
interview-persona-in-use = { $persona } · используется
interview-persona-new = Новая персона
interview-persona-add = Добавить
interview-persona-not-now = Не сейчас
interview-persona-added = Добавлено в «{ $persona }».
interview-persona-you = Вы
