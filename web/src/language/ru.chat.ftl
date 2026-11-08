### Слова чата и общих частей на русском, из en.chat.ftl; словарь — в голове ru.ftl.

## card-block (card/card-block.ts)

card-block-text = { $madeBy } · { $under }

## coding (chat/coding.ts)

coding-the-team = ИИ-команда
coding-open-task = Открыть задачу по коду
coding-undo-all = Отменить всё
coding-put-the-folder-back = Вернуть папку в то состояние, в каком она была до задачи?
coding-add-an-export-of = Добавить экспорт чатов в Markdown, с тестом.
coding-c-users-you-projects = C:\Users\вы\Projects\app
coding-start-a-coding-task = Начать задачу для программистов
coding-start = Начать
coding-goal = Цель
coding-a-checkpoint-is-kept = Cardwave сохраняет копию папки перед каждым шагом, так что любой шаг можно отменить.

## composer (chat/composer.ts)

composer-whoever-is-named-replies = Отвечает тот, кого назвали
composer-the-character-named-in = Отвечает персонаж, названный в последних сообщениях, а если никто не назван — случайный из остальных.
composer-each-replies-in-turn = Все отвечают по очереди
composer-the-characters-reply-one = Персонажи отвечают один за другим в том порядке, в каком они перечислены на боковой панели.
composer-a-random-one-replies = Отвечает случайный
composer-one-of-the-characters = Отвечает случайный персонаж, но не тот, кто говорил последним.
composer-keep-replying-by-themselves = Персонажи продолжают говорить сами
composer-write-for-me = Написать за меня
composer-uses-what-you-typed = ИИ пишет ваше сообщение; введённое вами направляет его и не отправляется.
composer-improve = Улучшить моё сообщение
composer-rewrites-what-you-typed = Переписывает введённое вами
composer-attach-picture-or-document = Прикрепить изображение или документ
composer-ai-draws-a-picture = ИИ рисует картинку для чата; введённое вами направляет его
composer-joins-this-chat = К этому чату присоединяется ещё один персонаж
composer-add-or-write = Прикрепить или дать написать ИИ
composer-message = Сообщение
composer-send = Отправить
composer-writing-your-message = Ваше сообщение пишется…
composer-who-replies = Кто отвечает: { $says }
composer-writes-every-reply = { $name } пишет каждый ответ.
composer-who-replies-group = Кто отвечает
composer-joined-the-chat = { $name } теперь в чате.
composer-message-improved = Сообщение улучшено.
composer-message-written-for-you = Сообщение написано за вас.
composer-message-2 = Сообщение: { $whom }
composer-replies = { $name } отвечает

## dictate (chat/dictate.ts)

dictate-dictate = Диктовать
dictate-the-microphone-cannot-be = Микрофон нельзя использовать: { $reason }. Разрешите его Cardwave в параметрах конфиденциальности Windows или подключите микрофон.
dictate-dictation-failed = Диктовка не удалась: { $reason }. Попробуйте ещё раз.
dictate-writing-what-was-said = Записывается сказанное…
dictate-nothing-was-heard = Ничего не было слышно.
dictate-stop-dictating = Остановить диктовку

## header (chat/header.ts)

header-chat-title = Название чата
header-the-title-was-not = Название не сохранено: { $reason }. Попробуйте ещё раз.
header-automatic = Автоматически
header-automatic-sub = Выбирает один из режимов ниже по тому, что вы пишете
header-new-chat-with-these = Новый чат с этими персонажами
header-new-chat-with = Новый чат с { $name }
header-add-to-favourites = Добавить в избранное
header-remove-from-favourites = Убрать из избранного
header-chat-options = Параметры чата
header-with = ещё: { $join }

## messages (chat/messages.ts)

messages-ai = ИИ
messages-you = { " " }(вы)
messages-you-2 = Вы
messages-writing = Пишет…
messages-message-and-the-after = Сообщение и { $after } после него удалены.
messages-message-deleted = Сообщение удалено.
messages-branch-from-here = Попробовать иначе отсюда
messages-edit-message = Изменить сообщение
messages-stop-reading = Остановить чтение
messages-read-aloud = Прочитать вслух
messages-message-options = Параметры сообщения
messages-previous-version = Предыдущая версия
messages-next-version = Следующая версия
messages-write-again = Написать заново
messages-continue-reply = Продолжить этот ответ
messages-version-of = Версия { $at } из { $count }
messages-delete-versions = Удалить вместе со всеми версиями ({ $count })
messages-delete-version = Удалить эту версию
messages-continue-uses-what-you = Продолжить этот ответ · слова в поле задают направление
messages-generate-reply = Создать ответ

## narration (narration.ts)

narration-show-pictures-from-the = Показывать картинки из интернета
narration-a-picture-from-another = Картинка с другого сайта скрыта: при её загрузке этот сайт узнаёт, что чат открыт.
narration-you-can-change-this = Это можно изменить в любой момент в Настройки › Оформление.

## panel (chat/panel.ts)

panel-in-trash = { " " }(в Корзине)
panel-remove-from-this-chat = Убрать из этого чата
panel-chat-details = Сведения о чате
panel-in-trash-locked = В Корзине: восстановите чат, чтобы его изменить.
panel-as-an-assistant = Характер в роли помощника
panel-kept-with-the-character = Хранится у персонажа, для каждого чата с этим персонажем.
panel-memory = Память
panel-move-up = Выше
panel-move-down = Ниже
panel-in-speaking-order = В порядке реплик
panel-options-for = Параметры: { $name }
panel-user = { card-user-stand-in }
panel-new-persona = Новая персона…
panel-from-settings = { $inUse } (из настроек)
panel-default-the-characters-own = По умолчанию (от персонажа)
panel-not-used-this-model = Не используется: эта модель сама решает длину ответа
panel-not-used-while-a = Не используется, пока ИИ работает с инструментами
panel-tokens-per-reply = Токенов на ответ
panel-very-short = Очень короткий
panel-short = Короткий
panel-medium = Средний
panel-long = Длинный
panel-very-long = Очень длинный
panel-pause-between-replies = Пауза между ответами
panel-seconds-when-they-reply = В секундах; только пока персонажи говорят сами
panel-replies-in-a-row = Ответов подряд
panel-by-themselves-then-they = Самостоятельно, затем остановка
panel-reply-length = Длина ответа
panel-small-tools-then-kept = ИИ может сам писать небольшие программы, чтобы что-то найти или посчитать; они остаются доступны в каждом чате
panel-the-characters-bring-none = Персонажи не приносят лорбук.
panel-restore = Восстановить
panel-put-back-2 = Вернуть { $name }
panel-left-out = Не используется в этом чате
panel-in-trash-2 = В Корзине
panel-used-in-last-reply = Использовано в прошлом ответе
panel-used-in-this-reply = Использовано в этом ответе
panel-read-on-the-web = Прочитано в интернете
panel-read-from-your-files = Прочитано из ваших файлов
panel-saved-to-memory = Сохранено в память
panel-this-character-has-no = У этого персонажа нет изображения.
panel-show-portrait = Показать изображение персонажа
panel-add-lorebook-to-chat = Добавить лорбук в этот чат
panel-entry-of = Запись из { $lorebook }
panel-portrait-beside = Рядом с чатом
panel-remove-from-this-chat-2 = Убрать { $name } из этого чата
panel-remove-lorebook-from-this = Убрать лорбук { $name } из этого чата

## pictures (chat/pictures.ts)

pictures-open-the-picture = Открыть изображение
pictures-change-prompt = Изменить описание
pictures-save-picture = Сохранить изображение
pictures-picture-options = Параметры изображения
pictures-prompt = Описание
pictures-make-again = Создать заново

## split (chat/split.ts)

split-open-card-page = Открыть страницу персонажа
split-hide-card-editor = Скрыть страницу персонажа
split-card-editor = Страница персонажа
split-changes-are-used-from = Изменения действуют со следующего ответа
split-this-card-is-in = Этот персонаж в Корзине.

## stats (chat/stats.ts)

stats-chat-history = Предыдущие сообщения
stats-reply-statistics = Об этом ответе
stats-context-used = Сколько из того, что может прочесть ИИ, уже занято
stats-sent-to-the-ai = Отправлено ИИ · токенов: { $count }
stats-in-all = всего { $seconds }
stats-to-the-first-word = { $seconds } до первого слова · { $all }

## talk (chat/talk.ts)

talk-the-characters-stopped-after = Персонажи остановились, ответов подряд: { $asked }.
talk-go-on = Продолжить

## title (chat-title.ts)

title-new-chat = Новый чат

## chat (companion/chat.ts)

chat-open-in-cardwave = Открыть в Cardwave
chat-compact-chat = Чат с компаньоном
chat-read-replies-aloud = Читать ответы вслух
chat-no-voice = Голос не настроен: выберите его в Настройки › Голоса
chat-the-card-has-no = В этой карточке нет персонажа для чата. Выберите другого через «Сменить персонажа».
chat-message = Сообщение: { $name }

## main (companion/main.ts)

main-open-chat = Открыть чат
main-figure-hint = Двойной щелчок, чтобы поговорить, правый щелчок — другие действия
main-walk-around = Ходить
main-sit-still = Сидеть на месте
main-change-character = Сменить персонажа
main-hide-until-tomorrow = Скрыть до завтра
main-quit-companion = Закрыть компаньона

## dialogs (dialogs.ts)

dialogs-folder-on-this-computer = Папка на этом компьютере

## dom (dom.ts)

dom-text = { $name }: { $reason }
dom-keep-all = Оставить все изменения
dom-address-copied = Адрес скопирован.
dom-the-browser-did-not = копировать здесь не разрешено; выделите текст и нажмите Ctrl+C

## edit-form (edit-form.ts)

edit-form-from-to = От { $least } до { $most }
edit-form-a-whole-number-from = Целое число от { $least }

## load (figures/load.ts)

load-this-figure-has-no = Cardwave не может двигать эту фигуру. Фигуры, сделанные для Mixamo, VRChat, Unity или Ready Player Me, может.

## format (format.ts)

format-today = Сегодня
format-comma = { ", " }
format-day-at = { $day }, { $time }
format-yesterday = Вчера
format-kb = { $kb } КБ
format-seconds = { $seconds } с

## downloaded (models/downloaded.ts)

downloaded-set-up = Настроить
downloaded-text = { $action } { $toLowerCase }
downloaded-local = На этом компьютере

## fit-models (models/fit-models.ts)

fit-models-cancel = Отменить: { $name }
fit-models-download = Скачать { $name }
fit-models-model-menu-delete = Меню модели: удалить { $name }
fit-models-delete-this-model = Удалить эту модель с этого компьютера? Освободится { $size }.
fit-models-gb-of-memory = { $round } ГБ ОЗУ · { $folder }
fit-models-downloading = { $fits } · скачивается { $percent }%
fit-models-downloaded = { $fits } · скачано
fit-models-model-deleted = Модель «{ $name }» удалена.

## images-setup (models/images-setup.ts)

images-setup-image-model = Модель изображений
images-not-set-up = Изображения ваших персонажей · не настроено

## kinds (models/kinds.ts)

kinds-chat-model = Модель чата
kinds-models-from-all-your = Модели всех ваших провайдеров, которые пишут текст. Выбранная пишет чаты, от какого бы провайдера она ни была.
kinds-models-from-all-your-2 = Модели всех ваших провайдеров, которые пишут текст. Выбранная становится вспомогательной моделью, от какого бы провайдера она ни была.
kinds-images-model = Модель изображений
kinds-models-from-all-your-3 = Модели всех ваших провайдеров, которые создают изображения. Выбранная создаёт изображения, от какого бы провайдера она ни была.
kinds-search-model = Модель поиска
kinds-models-on-this-computer = Модели на этом компьютере и у всех ваших провайдеров, которые находят тексты по смыслу. Выбранная выполняет поиск, откуда бы она ни была.
kinds-models-on-this-computer-2 = Модели на этом компьютере и у всех ваших провайдеров, которые читают сообщения вслух. Выбранная читает сообщения, откуда бы она ни была.
kinds-loading-models = Загрузка моделей…
kinds-couldnt-load-the-models = Не удалось загрузить модели.
kinds-search-the-models = Поиск моделей
kinds-use-this-model = Использовать эту модель
kinds-model = Модель
kinds-type-unknown = { " " }· неизвестно, умеет ли она это
kinds-address = { " " }· { $address }
kinds-this-computer = Программа на этом компьютере
kinds-asking-the-provider = Запрос к провайдеру…
kinds-no-such-model = Такой модели нет
kinds-own-on-this-computer = { $own } · на этом компьютере

## language-line (models/language-line.ts, settings/app-language.ts)

language-line-taken-from-this-computer = Как на этом компьютере, пока вы не выберете другой
language-line-follows-the-app = Совпадает с языком приложения, пока вы его не смените

## models-group (models/models-group.ts)

models-group-not-configured = Не настроено

## provider-form (models/provider-form.ts)

provider-form-a-key-is-saved = Ключ сохранён
provider-form-asking-the-provider-for = Запрос моделей у провайдера…
provider-form-the-provider-lists-no = Провайдер не перечисляет моделей. Введите название модели точно так, как оно написано на сайте провайдера.
provider-form-text = { $action } { $what }
provider-form-test-passed = { " " }· проверка пройдена
provider-form-testing = { " " }· проверка…
provider-form-is-saved = ····{ $key_end } сохранён
provider-form-or-type-the-models = { $listedCount }{ $have }. Или введите название модели точно так, как оно написано на сайте провайдера.
provider-form-test-failed = Проверка не пройдена: { $failed }. Проверьте ключ и адрес.

## search-setup (models/search-setup.ts)

search-setup-not-downloaded = Не скачано
search-setup-ready = Готово
search-setup-on-this-computer-download = { $name } · на этом компьютере · загрузка { $bytes }
search-setup-the-librarys-search-then = Тогда поиск по библиотеке находит персонажей по тому, о чём они, а не только по словам.
search-setup-reading-cards-left = { " " }· чтение персонажей, осталось { $left }
search-setup-reading-cards-left-2 = Чтение персонажей · осталось { $left }

## find (shell/find.ts)

find-pages = Страницы
find-page = Страница

## search-panel (shell/search-panel.ts)

search-panel-nothing-found-for = По запросу «{ $asked }» ничего не найдено.
search-panel-show-all = Показать все ({ $count })
search-panel-open-in-a-new = Открыть в новой вкладке
search-panel-what = Персонажи, чаты, лорбуки, воспоминания, документы и страницы
search-panel-not-messages = Текст сообщений не ищется; попробуйте персонажа чата.

## advanced (views/advanced.ts)

advanced-sillytavern-v3 = SillyTavern V3
advanced-ccv4 = Character Card V4

## chat (views/chat.ts)

chat-your-next-message-starts = Ваше следующее сообщение продолжит иначе от отмеченного сообщения.{ " " }
chat-this-chat-is-in = Этот чат в Корзине. Восстановите его, чтобы писать дальше.
chat-hide-side-panel = Скрыть боковую панель
chat-show-side-panel = Показать боковую панель
chat-show-card-editor = Показать страницу персонажа
chat-set-up-a-model = Настроить модель
chat-the-characters-keep-replying = Персонажи отвечают дальше сами, ответов: { $asked } из { $talk_replies }.{ " " }

## chats (views/chats.ts)

chats-last-message = Последнее сообщение
chats-date-started = Дата начала
chats-no-chats-yet = Чатов пока нет.
chats-search-chats = Поиск по чатам
chats-couldnt-load = Не удалось загрузить ваши чаты.
chats-chat-character-or-card = Найти чат или персонажа
chats-with = ещё: { $others }
chats-from = в Персонажах: { $join }

## coding-task (views/coding-task.ts)

coding-task-checkpoints = Точки отмены
coding-task-put-the-folder-back = Вернуть папку в состояние { $toLowerCase }?
coding-task-none-yet = Пока нет
coding-task-changed-files = Изменённые файлы
coding-task-text = { " " }· { $stepSays }
coding-task-team-started = { $folder } · команда «{ $team }» · начато { $format } ·{ " " }
coding-task-steps = Шаги
coding-task-undone = { $detail } · отменено

## documents (views/documents.ts)

documents-no-documents-yet-a = Документов пока нет. Добавьте документ здесь или прикрепите его в чате.
documents-what-they-are = ИИ читает эти файлы, когда отвечает: файлы персонажа — в каждом чате с этим персонажем, файлы чата — в этом чате.
documents-found-by-meaning-once = ИИ находит нужные места по смыслу, когда настроен Поиск.
documents-set-up-search = Настроить Поиск в настройках
documents-no-document-found = Документ не найден.
documents-search-documents = Поиск по документам
documents-name-chat-or-character = Название, чат или персонаж
documents-document-deleted = Документ удалён.
documents-for-the-character = Для персонажа{ " " }
documents-for-the-chat = Для чата{ " " }

## memories (views/memories.ts)

memories-nothing-remembered-yet = Воспоминаний пока нет.
memories-come-from-chats = Воспоминания берутся из ваших чатов: каждые 20 сообщений Cardwave сохраняет то, что каждому персонажу стоит запомнить. Здесь их можно изменить или удалить.
memories-no-memory-found = Воспоминание не найдено.
memories-search-memories = Поиск по воспоминаниям
memories-text-chat-or-character = Текст, чат или персонаж
memories-known-by = Кто знает
memories-known-by-hint = Кто в чате знает это и может об этом заговорить.
memories-you = вы
memories-you-alone = Вы
memories-edit-memory = Изменить воспоминание
memories-memory-deleted = Воспоминание удалено.
memories-from-the-chat = { " " }· Из чата{ " " }
memories-from-your-chat-with = { " " }· Из вашего чата с персонажем{ " " }
memories-because = потому что { $end }
memories-so = поэтому { $end }

## dictation-setup (voice/dictation-setup.ts)

dictation-setup-on-this-computers-graphics = { $name } · на видеокарте этого компьютера · загрузка { $bytes }
dictation-setup-the-microphone-beside-the = Тогда микрофон рядом с полем сообщения будет записывать сказанное, на русском, английском и других языках. Сказанное остаётся на этом компьютере.

## make-voice (voice/make-voice.ts)

make-voice-my-voice = Мой голос
make-voice-make-voice = Создать голос
make-voice-choose-a-file = Выбрать файл
make-voice-record = Записать
make-voice-play-back = Прослушать
make-voice-record-again = Записать заново
make-voice-the-recording-is-too = Запись слишком короткая: нужно не меньше { $SHORTEST } с.
make-voice-cardwave-cant-read-choose = Cardwave не может прочитать «{ $name }». Выберите файл WAV или MP3.
make-voice-recording = Запись
make-voice-a-short-recording-of = Короткая запись, где один человек говорит чётко: от 10 до { $LONGEST } с. WAV или MP3.
make-voice-use-only-a-voice = Используйте только голос, на который у вас есть право: свой или чужой с согласия его владельца.
make-voice-give-the-voice-a = Дайте голосу название.

## voice-setup (voice/voice-setup.ts)

voice-setup-made-from-your-recording = Создан из вашей записи
voice-setup-on-this-computer-download = На этом компьютере · загрузка { $bytes }
voice-setup-play-a-sample-of = Прослушать образец: { $name }
voice-setup-stop-the-sample-of = Остановить образец: { $name }
voice-setup-messages-are-read-aloud = Сообщения читаются вслух на английском, на этом компьютере.
voice-setup-use-this-voice = Использовать этот голос
voice-setup-hello-im-this-is = Привет, я { $name }. Так звучат ваши сообщения, когда их читают вслух.

## voice (voice/voice.ts)

voice-the-voice-stopped-answering = Голос перестал отвечать. Попробуйте ещё раз или выберите другой голос в Настройки › Голоса.
voice-this-window-cannot-play = Это окно не может воспроизвести звук: { $reason }. Проверьте вывод звука в Windows.

## Written by hand: plurals, conditions and numbers

client-backup-failed = Не удалось создать резервную копию. Проверьте, что в папку можно записывать, и попробуйте ещё раз.
composer-tokens-of = Токенов: { NUMBER($used, useGrouping: "auto") } из { NUMBER($size, useGrouping: "auto") }
header-chat = Чат
header-chat-archived = Чат перемещён в архив.
header-chat-unarchived = Чат возвращён из архива.
messages-tokens = { $count ->
    [one] { NUMBER($count, useGrouping: "auto") } токен
    [few] { NUMBER($count, useGrouping: "auto") } токена
    [many] { NUMBER($count, useGrouping: "auto") } токенов
   *[other] { NUMBER($count, useGrouping: "auto") } токена
  }
dom-texts-changed-by-ai = Изменено ИИ: { $count ->
    [one] { $count } текст
    [few] { $count } текста
    [many] { $count } текстов
   *[other] { $count } текста
  }
format-days-ago = { $count ->
    [one] { $count } день назад
    [few] { $count } дня назад
    [many] { $count } дней назад
   *[other] { $count } дня назад
  }
format-weeks-ago = { $count ->
    [one] { $count } неделю назад
    [few] { $count } недели назад
    [many] { $count } недель назад
   *[other] { $count } недели назад
  }
format-months-ago = { $count ->
    [one] { $count } месяц назад
    [few] { $count } месяца назад
    [many] { $count } месяцев назад
   *[other] { $count } месяца назад
  }
format-years-ago = { $count ->
    [one] { $count } год назад
    [few] { $count } года назад
    [many] { $count } лет назад
   *[other] { $count } года назад
  }
format-mb = { NUMBER($mb, minimumFractionDigits: 1, maximumFractionDigits: 1) } МБ
format-gb = { NUMBER($gb, minimumFractionDigits: 1, maximumFractionDigits: 1) } ГБ
fit-models-fits = { $size } · Работает на этом компьютере
fit-models-too-large = { $size } · Слишком большая для этого компьютера
fit-models-used-for = { $fits } · используется для: { $kinds }
provider-form-models = { $count ->
    [one] { NUMBER($count, useGrouping: "auto") } модель
    [few] { NUMBER($count, useGrouping: "auto") } модели
    [many] { NUMBER($count, useGrouping: "auto") } моделей
   *[other] { NUMBER($count, useGrouping: "auto") } модели
  }
provider-form-listed = { $count ->
    [one] { NUMBER($count, useGrouping: "auto") } модель в списке
    [few] { NUMBER($count, useGrouping: "auto") } модели в списке
    [many] { NUMBER($count, useGrouping: "auto") } моделей в списке
   *[other] { NUMBER($count, useGrouping: "auto") } модели в списке
  }
provider-form-listed-not-all = { $count ->
    [one] { NUMBER($count, useGrouping: "auto") } модель в списке
    [few] { NUMBER($count, useGrouping: "auto") } модели в списке
    [many] { NUMBER($count, useGrouping: "auto") } моделей в списке
   *[other] { NUMBER($count, useGrouping: "auto") } модели в списке
  }; остальные загрузить не удалось
provider-form-have = ; содержат «{ $part }»: { NUMBER($count, useGrouping: "auto") }
coding-task-verdict-passed = Вердикт аудитора: пройдено
coding-task-verdict-not-passed = Вердикт аудитора: не пройдено
documents-words = { $count ->
    [one] { NUMBER($count, useGrouping: "auto") } слово
    [few] { NUMBER($count, useGrouping: "auto") } слова
    [many] { NUMBER($count, useGrouping: "auto") } слов
   *[other] { NUMBER($count, useGrouping: "auto") } слова
  }
memories-known-by-everyone = Знают все
memories-known-by-these = Знают: { $names }
memories-known-by-nobody = Не знает никто
lore-tools-entries-changed-by-ai = Изменено ИИ: { $count ->
    [one] { $count } запись
    [few] { $count } записи
    [many] { $count } записей
   *[other] { $count } записи
  }
coding-failed-with-error = Сбой: { $error }
coding-planner-doing = Планировщик: { $what }
coding-step-doing = Шаг { $begun } из { $planned } · { $who }: { $what }
coding-worker = Исполнитель { $number }
coding-plans = Планирует шаги
coding-planned = { $steps ->
    [one] Запланирован { $steps } шаг
    [few] Запланировано { $steps } шага
    [many] Запланировано { $steps } шагов
   *[other] Запланировано { $steps } шага
  }
coding-fixes = Исправляет найденное аудитором
coding-checks-step = Проверяет шаг { $step }
coding-checks-all = Проверяет каждый шаг и запускает тесты
coding-verdict-tests = { $said } · { $tests }
coding-show-plan = Показать план
coding-before-step = Перед шагом { $step }
coding-before-fix = Перед исправлением
coding-looking-at-folder = Просматривает папку
coding-looking-at = Просматривает { $target }
coding-reading = Читает { $target }
coding-writing = Пишет { $target }
coding-running-command = Выполняет: { $target }
coding-installing = Устанавливает: { $target }
coding-searching-web = Ищет в интернете: { $target }
coding-files = { $files ->
    [one] { $files } файл
    [few] { $files } файла
    [many] { $files } файлов
   *[other] { $files } файла
  }
coding-no-files-changed = Файлы не изменены
coding-lines-files = { $lines } · { $files }
messages-copy-refused = копировать здесь не разрешено; выделите текст и нажмите Ctrl+C
panel-book-persona = персона
panel-book-every-chat = каждый чат
stats-model = Модель
stats-response-time = Время ответа
stats-context = Контекст
stats-context-says = Использовано токенов: { $used } из { $size } · свободно { $free }
documents-the-chat = чат
models-download-recommended = Находит персонажей по их содержанию · загрузка { $size } · рекомендуется
models-downloading = { $name } · скачивается { $percent }%
models-on-this-computer = { $name } · Этот компьютер{ $reading }
voice-setup-voice-download = Читает ответы вслух · { $name } ({ $about }) · загрузка { $size }
voice-setup-downloading = Скачивается { $percent }%
panel-persona-default = Для новых чатов
panel-who-you-are-in-this-chat = Кто вы в этом чате
panel-use-in-this-chat = Использовать в этом чате
panel-click-a-reply = Нажмите на ответ, чтобы увидеть, что он использовал.
