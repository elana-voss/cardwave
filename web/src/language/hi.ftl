### UI के शब्द हिंदी में, अंग्रेज़ी (en.ftl, मूल फ़ाइल) से एक-एक कुंजी करके अनुवादित; स्ट्रक्चर टेस्ट
### (structure.test.ts) जाँचता है कि यहाँ हर कुंजी उसी रूप में है।
### शब्द-सूची, हर चीज़ का एक नाम, सभी hi.*.ftl फ़ाइलों में:
###   संबोधन: उपयोगकर्ता «आप» है, जैसे आम ऐप में। उपयोगकर्ता का लिंग नहीं माना जाता: उसके बारे में लिंग वाली क्रिया या
###   विशेषण नहीं («आप गए/गईं», «आप थके हुए हैं» नहीं)। इनकी जगह: आज्ञार्थ («चुनें», «हटाएँ»), इनफ़िनिटिव («… करने पर»),
###   «आपने … किया» (कर्म से मेल), संज्ञा, या चीज़ को कर्ता बनाकर («पासवर्ड बदल दिया गया»)। यही नियम किसी नाम ({ $name },
###   किरदार या अकाउंट) पर: «{ $name } को … करना है», «{ $name } का …», कभी «चाहता/चाहती»। ऐप खुद को «मैं/हम» नहीं कहता:
###   कर्ता «Cardwave» (पुल्लिंग, ऐप की तरह: «Cardwave खुलेगा») या बिना कर्ता। सिर्फ़ इंटरव्यू वाला AI, जहाँ अंग्रेज़ी «me»
###   कहती है, «मैं/मेरे» कहता है; उपयोगकर्ता के अपने बटन («Write for me», «I don't know») भी «मैं/मेरे»।
###   बोलचाल की सॉफ़्टवेयर हिंदी: भारतीय उपयोगकर्ता जिन अंग्रेज़ी शब्दों को जानते हैं, वे देवनागरी में, गढ़े हुए संस्कृत शब्द नहीं।
###   Cardwave, MCP, Claude Desktop, CSS, AI, Downtempo, Outrun, Retrowave, Neon Wave: लैटिन में ही। token = टोकन; tab = टैब;
###   chat = चैट (स्त्रीलिंग); message = मैसेज; character = किरदार; card = कार्ड (किरदार की फ़ाइल); figure = 3D फ़िगर;
###   persona = पर्सोना; lorebook = लोरबुक (स्त्रीलिंग); memory = याद (पेज «यादें»); document = डॉक्यूमेंट; library = लाइब्रेरी;
###   knowledge = जानकारी; account = अकाउंट; provider = प्रोवाइडर; model = मॉडल; helper (model) = हेल्पर मॉडल; tool = टूल;
###   tag = टैग; preset = प्रीसेट (model preset = मॉडल प्रीसेट, prompt preset = प्रॉम्प्ट प्रीसेट); prompt = प्रॉम्प्ट;
###   key = कुंजी; Settings = सेटिंग्स; Advanced = एडवांस्ड; Trash = ट्रैश (Cardwave का); Recycle Bin = रीसायकल बिन (Windows का);
###   backup = बैकअप; back up = बैकअप लें; restore = रीस्टोर; Sharing = शेयरिंग; companion = साथी; voice = आवाज़;
###   read aloud = पढ़कर सुनाना; dictation = वॉइस टाइपिंग; picture = तस्वीर (Images, image model = इमेज, इमेज मॉडल);
###   download = डाउनलोड; Showcase = शोकेस; Search Cardwave = Cardwave में खोजें; coding team = कोडिंग टीम; planner = प्लानर;
###   worker = वर्कर; auditor = ऑडिटर; task = टास्क; sign in/out = साइन इन/आउट; lock = लॉक; import = इंपोर्ट; export = एक्सपोर्ट;
###   password = पासवर्ड; interview = इंटरव्यू; generator = किरदार जनरेटर; theme = थीम; first run = पहली बार सेटअप;
###   save = सेव करें; delete = हटाएँ; edit = एडिट करें; cancel = रद्द करें; file = फ़ाइल; folder = फ़ोल्डर; search (model, सेटिंग्स का हिस्सा) = सर्च; version = वर्ज़न; format = फ़ॉर्मेट; Appearance = दिखावट।
###   बिना पर्सोना वाले उपयोगकर्ता का नाम (card-user-stand-in, cw_prompt::stand_in_user): अतिथि (नाम की तरह, लिंग नहीं)।
###   बहुवचन (Intl.PluralRules «hi»): one (0 और 1) और other; [one] में संख्या हमेशा { $count }, कभी लिखा हुआ «1» नहीं।
###   पूर्ण विराम «।», उद्धरण “ ”, डैश —, «…»। वाक्य के बीच लेबल: midSentence।

## The app

app-name = Cardwave

## The pages, as tabs, the rail and Search Cardwave name them (shell/pages.ts)

page-chats = चैट
page-characters = किरदार
page-lorebooks = लोरबुक
page-personas = पर्सोना
page-memories = यादें
page-documents = डॉक्यूमेंट
page-generator = किरदार जनरेटर
page-interview = साथ मिलकर किरदार बनाएँ
page-profile = प्रोफ़ाइल
page-server = शेयरिंग
page-settings = सेटिंग्स
page-providers = प्रोवाइडर
page-voices = आवाज़ें
page-advanced = एडवांस्ड
page-css = Cardwave का CSS
page-written-tools = AI के लिखे टूल
page-coding-team = कोडिंग टीम
page-trash = ट्रैश
page-about = Cardwave के बारे में
page-coding-task = कोडिंग टास्क
page-chat = चैट
page-new-card = नया किरदार
page-lorebook = लोरबुक
page-card = किरदार
page-prompt-preset = प्रॉम्प्ट प्रीसेट
page-first-run = Cardwave सेट अप करें

## The places pages are under

place-library = लाइब्रेरी
place-knowledge = जानकारी
place-account = अकाउंट
place-settings = सेटिंग्स
place-advanced = सेटिंग्स › एडवांस्ड

## The rail (shell/rail.ts)

rail-create = बनाएँ
rail-memories-tip = यादें: AI को आपकी चैट से क्या याद है
rail-documents-tip = डॉक्यूमेंट: फ़ाइलें जिन्हें AI जवाब देते समय पढ़ता है
rail-show-more = { $count } और दिखाएँ
rail-open-menu = साइडबार खोलें
rail-close-menu = साइडबार बंद करें
rail-collapse = साइडबार छोटा करें
rail-expand = साइडबार बड़ा करें
rail-account = अकाउंट
rail-account-named = अकाउंट: { $name }
rail-lock = लॉक करें

## Create's lines (shell/create.ts)

create-new-chat = नई चैट
create-plain-chat = बिना किरदार की चैट
create-new-card = नया किरदार
create-from-picks = किरदार जनरेटर
create-together = साथ मिलकर किरदार बनाएँ
create-new-persona = नया पर्सोना
create-new-lorebook = नई लोरबुक
create-import-card = कार्ड इंपोर्ट करें
create-import-lorebook = लोरबुक इंपोर्ट करें
create-new = नया
create-import = इंपोर्ट करें

## The title bar and its tabs (shell/titlebar.ts)

tabs = टैब
tab-new = नया टैब
tab-new-keys = नया टैब (Ctrl+T)
tabs-all = सभी टैब
tab-close = टैब बंद करें
window-minimize = छोटा करें
window-maximize = बड़ा करें
window-close = बंद करें

## The view menu (shell/view-menu.ts, theme.ts)

view = व्यू
view-compact = कॉम्पैक्ट
theme-system = सिस्टम
theme-light = लाइट
theme-dark = डार्क
theme-downtempo = Downtempo
theme-outrun = Outrun
theme-retrowave = Retrowave
theme-neonwave-dark = Neon Wave डार्क
theme-neonwave-light = Neon Wave लाइट

## Search Cardwave's button (shell/search-panel.ts)

search = Cardwave में खोजें
search-keys = Cardwave में खोजें (Ctrl+K)

## The labels of the settings, as their pages and Search Cardwave name them (setting-labels.ts)

label-settings-theme = थीम
label-settings-chat-layout = चैट लेआउट
label-settings-web-pictures = दूसरी वेबसाइटों की तस्वीरें दिखाएँ
label-settings-app-language = ऐप की भाषा
label-settings-language = AI किस भाषा में लिखे
label-settings-providers = प्रोवाइडर
label-settings-chat = चैट
label-settings-images = इमेज
label-settings-voice = आवाज़
label-settings-search = सर्च
label-settings-dictation = वॉइस टाइपिंग
label-settings-web = वेब
label-settings-files = फ़ाइलें
label-settings-commands = कमांड
label-settings-image-generation = इमेज बनाना
label-settings-app = Cardwave
label-settings-dice = पासे
label-settings-folder = फ़ोल्डर
label-settings-written = AI के लिखे टूल
label-settings-coding = कोडिंग टीम
label-settings-trash = ट्रैश
label-settings-backup = बैकअप
label-settings-restore = रीस्टोर
label-settings-cards-folder = कार्ड फ़ोल्डर
label-settings-advanced = एडवांस्ड
label-settings-setup = सेटअप फिर से चलाएँ
label-settings-about = Cardwave के बारे में
label-providers-this-computer = यह कंप्यूटर
label-voices-model = आवाज़ मॉडल
label-voices-speed = रफ़्तार
label-voices-english = अंग्रेज़ी
label-advanced-background = हेल्पर मॉडल
label-advanced-told = AI को क्या बताया जाता है
label-advanced-describe = इम्पोर्ट किए गए किरदारों का विवरण लिखें
label-advanced-described = विवरण लिखे गए किरदार
label-advanced-interview = साथ मिलकर किरदार बनाएँ
label-advanced-format = एक्सपोर्ट फ़ॉर्मेट
label-advanced-history = हर टेक्स्ट के पुराने वर्ज़न भी शामिल करें
label-advanced-css = आपका अपना CSS
label-coding-planner = प्लानर
label-coding-workers = वर्कर
label-coding-auditor = ऑडिटर
label-profile-name = नाम
label-profile-picture = तस्वीर
label-profile-password = पासवर्ड
label-server-network = होम नेटवर्क में उपलब्ध
label-server-address = पता
label-server-mcp = इस कंप्यूटर के AI ऐप को Cardwave इस्तेमाल करने दें

layout-bubbles = बबल
layout-plain = सादा

## Settings (views/settings.ts)

settings-appearance = दिखावट
settings-theme-about = सिस्टम के अनुसार, जब तक आप कोई और न चुनें
settings-layout-about = मैसेज बबल में, या सादे टेक्स्ट में
settings-web-pictures-about = चैट खोलने पर वे वेबसाइटें यह देख सकती हैं।
settings-language = भाषा
settings-data = डेटा
settings-trash-about = { $count ->
    [one] { $count } आइटम
   *[other] { $count } आइटम
  } · { $days } दिन बाद खाली किया जाता है
settings-open-trash = ट्रैश खोलें
settings-open = खोलें
settings-version = वर्ज़न { $version } · लाइसेंस
settings-licences = लाइसेंस
settings-advanced-about = हेल्पर मॉडल, लाइब्रेरी, एक्सपोर्ट, बिना किरदार की चैट, सैंपलिंग, प्रीसेट, आपका अपना CSS
settings-setup-about = प्रोवाइडर, मॉडल और आवाज़, एक-एक कदम करके
settings-providers-about = मॉडल चलाने वाली सेवाओं के पते और कुंजियाँ
settings-this-computer = यह कंप्यूटर
settings-providers-named = सेट किए गए: { $names }
settings-models = मॉडल
settings-the-chat-model = चैट मॉडल
settings-the-image-model = इमेज मॉडल

## The account's tabs and accounts (shell/account-tabs.ts, settings/accounts.ts)

account-sections = अकाउंट के हिस्से
account-switch = अकाउंट बदलें

account-password = पासवर्ड
account-switch-to = { $name } पर जाएँ
account-password-asked = { $name } का पासवर्ड लिखें।
account-switch-button = बदलें
account-add = अकाउंट जोड़ें
account-add-about = इस कंप्यूटर पर किसी और का अकाउंट, अपनी चैट और किरदारों के साथ। इसमें इसके पासवर्ड से साइन इन होता है, यहाँ या किसी दूसरे डिवाइस पर।
account-name = नाम
account-added = अकाउंट “{ $name }” जोड़ा गया।
account-add-button = जोड़ें
account-sign-out = साइन आउट करें
account-none = साइन इन के लिए कोई अकाउंट नहीं
account-none-about = अभी यहाँ से कोई खाता साइन इन नहीं कर सकता। जिस कंप्यूटर पर Cardwave चलता है, वहाँ अकाउंट › शेयरिंग में एक जोड़ें।
account-this-computer = इस कंप्यूटर का अकाउंट
account-choose = अपना अकाउंट चुनें
account-try-again = फिर कोशिश करें
account-back = वापस
account-sign-in = साइन इन करें

## Backup and Restore (settings/backup.ts)

backup-saving = बैकअप सेव हो रहा है।
backup-saving-to = बैकअप { $folder } में सेव हो रहा है।
backup-password = पासवर्ड
backup-repeat = पासवर्ड दोबारा लिखें
backup-encrypted = बैकअप इस पासवर्ड से एन्क्रिप्ट होता है; इसे रीस्टोर करने के लिए यही पासवर्ड चाहिए, यहाँ या किसी दूसरे कंप्यूटर पर।
backup-forgotten = भूला हुआ पासवर्ड वापस नहीं मिल सकता, और उसके बिना बैकअप रीस्टोर नहीं हो सकता।
backup-with-password = पासवर्ड के साथ बैकअप लें
backup-differ = दोनों पासवर्ड अलग हैं।
backup-back-up = बैकअप सहेजें
backup-no-file = कोई फ़ाइल नहीं चुनी गई
backup-choose-file = फ़ाइल चुनें
backup-its-password = बैकअप का पासवर्ड
backup-restoring = रीस्टोर करने पर Cardwave की हर चीज़ बदल जाती है: चैट, किरदार, पर्सोना, लोरबुक, यादें और सेटिंग्स। इसे पलटा नहीं जा सकता। यहाँ का पासवर्ड जैसा है वैसा ही रहता है।
backup-file = फ़ाइल
backup-restore-title = बैकअप रीस्टोर करें
backup-choose-first = पहले बैकअप की फ़ाइल चुनें।
backup-restore = बैकअप बहाल करें
backup-save = बैकअप सेव करें
backup-from-file = बैकअप फ़ाइल से
backup-about-own = चैट, किरदार और सेटिंग्स एक फ़ाइल में, आपके पासवर्ड से एन्क्रिप्टेड
backup-about-chosen = चैट, किरदार और सेटिंग्स एक फ़ाइल में, आपके चुने हुए पासवर्ड से एन्क्रिप्टेड

## The folder of cards (settings/card-folder.ts)

folder-watch = नए कार्ड अपने-आप इंपोर्ट करें
folder-watch-about = फ़ोल्डर में रखी गई कार्ड फ़ाइल अपने-आप आपकी लाइब्रेरी में आ जाती है
folder-recycle = इंपोर्ट हो चुकी फ़ाइलें रीसायकल बिन में डालें
folder-recycle-about = फ़ाइल इंपोर्ट होते ही रीसायकल बिन में चली जाती है

## The companion's line (library/companion-app.ts)

companion = साथी
# The companion window's name, which the system shows in its lists of windows.
companion-window = Cardwave साथी
companion-made = { $name } अब आपका साथी है।
companion-make = साथी बनाएँ
companion-none = अभी कोई साथी नहीं। किसी किरदार का “…” मेन्यू खोलें और “साथी बनाएँ” चुनें।
companion-named = { $name } · ऐप के साथ शुरू
companion-figure = साथी का फ़िगर
companion-figure-about = उन किरदारों के लिए दिखता है जिनका अपना 3D फ़िगर नहीं है
companion-figure-woman = महिला
companion-figure-man = पुरुष
companion-figure-robot = रोबोट
companion-size = साथी का आकार
companion-size-about = फ़िगर की ऊँचाई, स्क्रीन की ऊँचाई के हिस्से के रूप में
companion-size-value = { $size }%

## Other programs, MCP (settings/mcp.ts)

mcp-ask-title = इस कंप्यूटर के AI ऐप को Cardwave इस्तेमाल करने दें
mcp-ask = इस कंप्यूटर के प्रोग्राम, जैसे Claude Desktop, आपके किरदार और चैट पढ़ सकते हैं, आपकी चैट में लिख सकते हैं और सेटिंग्स › टूल में चालू टूल इस्तेमाल कर सकते हैं। जो Cardwave आपसे पहले पूछता, वह वे नहीं कर सकते।
mcp-switch-on = चालू करें
mcp-about = जैसे Claude Desktop, MCP के ज़रिए: ये आपके किरदार, चैट और टूल इस्तेमाल करते हैं
mcp-copy-address = MCP पता कॉपी करें
mcp-copy = कॉपी करें
mcp-as-account = किस अकाउंट के रूप में
mcp-as-account-about = वे क्या देख और कर सकते हैं
mcp-remove-named = { $program } हटाएँ
mcp-removed = “{ $program }” हटाया गया।
mcp-remove = हटाएँ
mcp-connected = कनेक्टेड
mcp-other-programs = दूसरे प्रोग्राम
mcp-only-here = सिर्फ़ इस कंप्यूटर के प्रोग्राम कनेक्ट हो सकते हैं। हटाया गया प्रोग्राम तब तक बाहर रहता है जब तक इसे बंद करके फिर से चालू न किया जाए।

## Your own CSS (settings/own-css.ts)

css-none = कोई नहीं
css-lines = { $count ->
    [one] { $count } लाइन
   *[other] { $count } लाइनें
  }
css-about = { $lines } · ऐप का रूप बदलता है
css-hint = Cardwave की अपनी स्टाइलशीट के बाद, लिखते ही लागू होता है। “सेव करें” इसे रखता है; “रद्द करें” इसे वापस ले लेता है।
css-edit-own = अपना CSS एडिट करें
css-edit = एडिट करें

## The password (settings/password.ts)

password-forgotten = भूला हुआ पासवर्ड वापस नहीं मिल सकता, और उसके साथ आपकी चैट और किरदार खो जाते हैं। इसे सुरक्षित जगह रखें।
password-on-title = पासवर्ड सेट करें
password-on-says = Cardwave खुलते समय इसे माँगेगा। इसके बिना कोई Cardwave नहीं खोल सकता, न इस कंप्यूटर पर आपकी चैट पढ़ सकता है।
password-on = पासवर्ड सेट करें
password-on-done = पासवर्ड सेट किया गया।
password-change-title = पासवर्ड बदलें
password-change-says = Cardwave खुलते समय नया पासवर्ड माँगेगा।
password-change = बदलें
password-change-done = पासवर्ड बदल दिया गया।
password-off-title = पासवर्ड बंद करें
password-off-says = Cardwave बिना पासवर्ड माँगे खुलेगा। आपकी चैट और किरदार एन्क्रिप्टेड रहते हैं।
password-off = बंद करें
password-off-done = पासवर्ड बंद किया गया।
password-differ = दोनों पासवर्ड अलग हैं।
password-other-says = इसके बाद साइन इन नए पासवर्ड से होता है।
password-other-forgotten = भूल जाने पर इस कंप्यूटर का अकाउंट इसे शेयरिंग में रीसेट कर सकता है।
password-current = मौजूदा पासवर्ड
password-password = पासवर्ड
password-new = नया पासवर्ड
password-repeat = पासवर्ड दोबारा लिखें
password-asked-sign-in = साइन इन करते समय पूछा जाता है
password-is-on = चालू · ऐप खुलते समय पूछा जाता है
password-is-off = बंद · इस कंप्यूटर पर कोई भी Cardwave खोल सकता है
password-start-forgotten = भूला हुआ पासवर्ड वापस नहीं मिल सकता।
password-open = खोलें
password-back = वापस

## Words many pages use

common-use = इस्तेमाल करें
common-in-use = { " " }· इस्तेमाल में
common-more = और
common-edit = एडिट करें
common-duplicate = डुप्लिकेट करें
# The word a copy's name ends in, as in "Rig (copy)".
common-copy-word = कॉपी
common-delete = हटाएँ
common-save = सेव करें
common-cancel = रद्द करें
common-name = नाम

## Model presets and prompt presets (settings/presets.ts, settings/prompt-presets.ts)

preset-what = प्रीसेट एक चैट मॉडल को उसकी सैंपलिंग वैल्यू के साथ सेव करता है। “इस्तेमाल करें” उस पर स्विच करता है।
preset-temperature = टेम्परेचर { $value }
preset-new = नया प्रीसेट
preset-model-presets = मॉडल प्रीसेट
preset-using = “{ $name }” इस्तेमाल हो रहा है।
preset-added = प्रीसेट “{ $name }” जोड़ा गया।
preset-deleted = प्रीसेट “{ $name }” हटाया गया।
preset-saved = प्रीसेट “{ $name }” सेव किया गया।
preset-delete-ask = यह प्रीसेट हटाएँ?
preset-replace = मौजूदा मॉडल और सेटिंग्स इस्तेमाल करें
preset-replace-hint = चैट मॉडल, उसका प्रदाता और इस पेज की सैंपलिंग। बंद: प्रीसेट अपने ही रखता है।
preset-keeps-hint = यह सेटिंग्स › मॉडल का चैट मॉडल, उसका प्रोवाइडर और इस पेज की सैंपलिंग रखता है।
preset-name = नाम
preset-edit = प्रीसेट एडिट करें
prompt-presets = प्रॉम्प्ट प्रीसेट
prompt-system = सिस्टम प्रॉम्प्ट
prompt-note = { $depth ->
    [one] नोट, { $depth } मैसेज पहले
   *[other] नोट, { $depth } मैसेज पहले
}
prompt-system-note = { $depth ->
    [one] सिस्टम प्रॉम्प्ट · नोट, { $depth } मैसेज पहले
   *[other] सिस्टम प्रॉम्प्ट · नोट, { $depth } मैसेज पहले
}
prompt-as-card = जैसा किरदार में है
prompt-default = डिफ़ॉल्ट
prompt-default-name = “{ $name }” किरदार का अपना प्रॉम्प्ट है।

## Tools (settings/tools.ts, chat/tool-ask.ts)

tools-written-ask = { $count ->
    [0] अभी कोई नहीं
    [one] { $count } टूल
   *[other] { $count } टूल
  } · नया टूल चलने से पहले पूछा जाता है
tools-written-free = { $count ->
    [0] अभी कोई नहीं
    [one] { $count } टूल
   *[other] { $count } टूल
  } · नया टूल बिना पूछे चलता है
tools-folder-first = पहले एक फ़ोल्डर चुनें
tools-web = खोजें और वेब पेज पढ़ें
tools-files = सिर्फ़ { $folder }
tools-ask-writes = लिखने से पहले पूछें
tools-ask-writes-says = हर फ़ाइल लिखे जाने से पहले आपको दिखाई जाती है
tools-commands = { $folder } में चलाएँ, बाकी कंप्यूटर और इंटरनेट से अलग
tools-ask-commands = चलाने से पहले पूछें
tools-ask-commands-says = हर कमांड चलने से पहले आपको दिखाई जाती है
tools-pictures = इमेज मॉडल इस्तेमाल करता है
tools-pictures-first = पहले इमेज मॉडल सेट करें
tools-app = आपके किरदार, चैट और सेटिंग्स इस्तेमाल करना और बदलना; हर बदलाव पहले पूछा जाता है
tools-dice = AI को पासे फेंकने देता है; पासे Cardwave फेंकता है, ताकि नतीजा निष्पक्ष रहे।
tools-folder-example = C:\Users\aap\Documents\Shared
tools-folder-says = फ़ाइलें और कमांड सिर्फ़ इस फ़ोल्डर और इसके अंदर की चीज़ों तक पहुँचती हैं, और कहीं नहीं।
tools-change-folder = फ़ोल्डर बदलें
tools-change = बदलें
tools-choose = चुनें
tools-none-chosen = कुछ नहीं चुना गया
tools-title = टूल
tools-ask-new = { $name } को एक नया टूल इस्तेमाल करना है: { $what }
tools-ask-write = { $name } को आपके फ़ोल्डर में “{ $what }” लिखना है:
tools-ask-read = { $name } को आपके फ़ोल्डर में पढ़ना है:
tools-ask-install = { $name } अपनी ज़रूरत के प्रोग्राम डाउनलोड और इंस्टॉल करना चाहता है:
tools-ask-web = { $name } को वेब इस्तेमाल करना है:
tools-ask-app = { $name } को Cardwave में बदलाव करना है:
tools-ask-command = { $name } को आपके फ़ोल्डर में एक कमांड चलानी है:
tools-allow = अनुमति दें
tools-deny = मना करें
tools-allow-writing = इस चैट के लिए फ़ाइलें लिखने की अनुमति दें
tools-allow-commands = इस चैट के लिए कमांड चलाने की अनुमति दें

## Updates (settings/update.ts)

update-title = अपडेट देखें
update-available = Cardwave { $version } उपलब्ध है
update-you-have = आपके पास { $version } है।
update-up-to-date = Cardwave अप टू डेट है ({ $version })।
update-connection-error = अपडेट नहीं देखे जा सके। अपना कनेक्शन जाँचें।
update-whats-new = नया क्या है
update-close = बंद करें
update-ok = ठीक है
update-download = डाउनलोड करें
update-install = अपडेट करके रीस्टार्ट करें
update-installing = Cardwave { $version } डाउनलोड हो रहा है…
update-auto = अपने-आप देखें
update-auto-about = शुरू होते समय और दिन में एक बार नया वर्ज़न देखें
update-check = देखें
update-about = देखें कि ऐप का नया वर्ज़न उपलब्ध है या नहीं।

## The breadcrumbs of a page under Settings

crumbs = आप कहाँ हैं

## Providers (views/providers.ts)

providers-key-end = { $where } · कुंजी ····{ $end }
providers-key-saved = { $where } · कुंजी सेव है
providers-no-key = { $where } · कोई कुंजी नहीं
providers-thinking-cannot = { $provider } इस मॉडल के लिए थिंकिंग बंद नहीं कर सकता
providers-thinking-off = मॉडल पहले सोचे बिना जवाब देता है
providers-thinking-on = मॉडल जवाब देने से पहले सोचता है
providers-comfy-default = ComfyUI का डिफ़ॉल्ट
providers-workflow-note = यह वर्कफ़्लो अपने मॉडल और साइज़ इस्तेमाल करता है, इमेज मॉडल नहीं।
providers-testing-model = मॉडल जाँचा जा रहा है…
providers-thinking-of = { $label }: थिंकिंग
providers-thinking = थिंकिंग
providers-testing-workflow = वर्कफ़्लो जाँचा जा रहा है…
providers-workflows-from = ComfyUI में रखे वर्कफ़्लो में से
providers-pictures-by = तस्वीरें “{ $name }” से।
providers-pictures-default = तस्वीरें ComfyUI के डिफ़ॉल्ट वर्कफ़्लो से।
providers-workflow = वर्कफ़्लो
providers-not-used = अभी किसी काम में इस्तेमाल नहीं
providers-folder-saved = फ़ोल्डर सेव हुआ।
providers-change-folder = मॉडलों का फ़ोल्डर बदलें
providers-choose-folder = मॉडलों का फ़ोल्डर चुनें
providers-change = बदलें
providers-not-set-up = सेट नहीं है
providers-folder-not-set-up = इस कंप्यूटर के एक फ़ोल्डर से मॉडल चलाता है · सेट नहीं है
providers-menu = प्रोवाइडर मेन्यू: एडिट करें, हटाएँ
providers-remove = हटाएँ
providers-removed = प्रोवाइडर “{ $name }” हटाया गया।
providers-remove-with-models = यह प्रदाता हटाएँ? इससे चुने गए मॉडल अब इस्तेमाल नहीं होंगे।
providers-remove-ask = यह प्रोवाइडर हटाएँ?
providers-remove-key = कुंजी हटाएँ
providers-key-removed = सेव करने पर कुंजी हट जाती है
providers-edit = प्रोवाइडर एडिट करें
providers-keep-key = सेव की हुई कुंजी रखने के लिए खाली छोड़ें।
providers-saved = प्रोवाइडर “{ $name }” सेव किया गया।
providers-added = प्रोवाइडर “{ $name }” जोड़ा गया।
providers-add = प्रोवाइडर जोड़ें
providers-about = AI कहाँ चलता है: इंटरनेट की कोई सेवा या इस कंप्यूटर का कोई प्रोग्राम। हर एक के नीचे लिखा है कि वह किस काम आता है।

## Voices (views/voices.ts)

voices-stop = { $name } रोकें
voices-try = { $name } सुनें
voices-model-about = इस कंप्यूटर पर संदेश पढ़कर सुनाता है · { $size }
voices-default-of = डिफ़ॉल्ट आवाज़: { $name }
voices-menu = आवाज़ मेन्यू: नाम बदलें, हटाएँ
voices-rename = नाम बदलें
voices-delete-ask = आवाज़ “{ $name }” हटाएँ? जो किरदार इसे इस्तेमाल करते हैं, वे फिर से डिफ़ॉल्ट आवाज़ में पढ़ेंगे।
voices-rename-title = आवाज़ का नाम बदलें
voices-name = नाम
voices-speed-value = { $speed }×
voices-speed = रफ़्तार
voices-speed-about = जवाब कितनी तेज़ी से पढ़े जाते हैं, हर आवाज़ के लिए
voices-make = रिकॉर्डिंग से आवाज़ बनाएँ
voices-provider-failed = प्रोवाइडर की आवाज़ें लोड नहीं हो सकीं।
voices-provider-none = प्रोवाइडर कोई आवाज़ नहीं बताता
voices-provider-own = संदेश प्रदाता की अपनी आवाज़ में पढ़े जाते हैं।
voices-voices = आवाज़ें
voices-voices-about = वह आवाज़ जो संदेश पढ़कर सुनाती है। किसी किरदार की अपनी आवाज़ "किरदारों की आवाज़ें" में हो सकती है।
voices-default = डिफ़ॉल्ट आवाज़
voices-voice-of = { $name } की आवाज़
voices-back-default = डिफ़ॉल्ट आवाज़ पर वापस
voices-name-title = { $name } · { $title }
voices-choose-character = एक किरदार चुनें
voices-all-have = हर किरदार की एक आवाज़ है।
voices-set-for = किसी किरदार के लिए आवाज़ चुनें
voices-character = किरदार
voices-voice = आवाज़
voices-character-first = पहले एक किरदार चुनें।
voices-characters = किरदारों की आवाज़ें
voices-downloading = डाउनलोड हो रहा है · { $size } · { $percent }%
voices-downloaded = डाउनलोड हुआ · { $size }
voices-download-size = { $size } डाउनलोड
voices-action-of = { $name } { $action }
voices-language-downloaded = { $name } डाउनलोड हुई
voices-built-in = पहले से मौजूद
voices-languages = जिन भाषाओं में यह पढ़ती है
voices-download = डाउनलोड करें
voices-cancel = रद्द करें
voices-delete = हटाएँ

## Advanced (views/advanced.ts)

advanced-context-size = कॉन्टेक्स्ट साइज़ (टोकन)
advanced-context-hint = 128,000 के लिए खाली छोड़ें
advanced-temperature = टेम्परेचर
advanced-temperature-about = ज़्यादा: और चौंकाने वाले जवाब। 0 से 2 तक
advanced-top-p = Top P
advanced-top-p-about = कम: सिर्फ़ सबसे संभावित शब्द। 0 से 1 तक
advanced-frequency = Frequency penalty
advanced-frequency-about = ज़्यादा: कम दोहराए गए शब्द। −2 से 2 तक
advanced-presence = Presence penalty
advanced-presence-about = ज़्यादा: ज़्यादा नए विषय। −2 से 2 तक
advanced-seed = Seed
advanced-seed-about = वही संख्या फिर से वही जवाब देती है
advanced-from-to = { $min } से { $max } तक
advanced-whole-from = { $min } या उससे बड़ी पूर्ण संख्या
advanced-whole = एक पूर्ण संख्या
advanced-number = एक संख्या
advanced-sampling = सैंपलिंग
advanced-sampling-about = चैट मॉडल के लिए। प्रोवाइडर का डिफ़ॉल्ट इस्तेमाल करने के लिए वैल्यू खाली छोड़ें। लिखते ही सेव होता है।
advanced-describing = विवरण लिखा जा रहा है… { $count } बाकी
advanced-all-described = हर किरदार का विवरण लिखा जा चुका है
advanced-not-described = { $count ->
    [one] { $count } किरदार
   *[other] { $count } किरदार
  } का विवरण अभी नहीं लिखा गया
advanced-describe-cards = किरदारों का विवरण लिखें
advanced-describe-cost = { $count ->
    [one] { $count } कैरेक्टर
   *[other] { $count } कैरेक्टर
  } के लिए लगभग { $low } से { $high } टोकन
advanced-failed = { $count ->
    [one] { $count } विफल
   *[other] { $count } विफल
  }: { $failure }। फिर से कोशिश करने के लिए किरदारों का विवरण लिखें दबाएँ।
advanced-describe-again = सबका विवरण फिर से लिखें
advanced-describe-again-stop = रोकें
advanced-describe-again-about = हेल्पर मॉडल से हर किरदार का एक-पंक्ति विवरण, सारांश, टैग और वह सब फिर से लिखता है जिससे "ज़रूरत के हिसाब से" उसे ढूँढता है, हर एक पर लगभग 11,000 से 12,000 टोकन। जो आपने खुद बदला, वह बना रहता है। प्रदाता टोकन के हिसाब से शुल्क लेते हैं।
advanced-no-characters = विवरण लिखने के लिए कोई किरदार नहीं
advanced-describe-again-far = { $all } में से { $done } का विवरण फिर से लिखा गया
advanced-describe-again-stopped = { $all } में से { $done } का विवरण फिर से लिखने के बाद रोका गया
advanced-describe-again-failed = { $count ->
    [one] { $count } विफल, पहले जैसा ही रहता है
   *[other] { $count } विफल, पहले जैसे ही रहते हैं
  }: { $failure }। एक बार और कोशिश करने के लिए सबका विवरण फिर से लिखें दबाएँ।
advanced-describe-about = हर एक के लिए एक लाइन का विवरण, सारांश और टैग, हेल्पर मॉडल के लिखे हुए
advanced-plain = बिना किरदार की चैट
advanced-told-about = बिना किरदार वाली हर चैट में यही। { "{{date}}" } या { "{{time}}" } लिखें और AI को आज की तारीख़ या समय मिलता है
advanced-library = लाइब्रेरी
advanced-interview-about = AI आपसे अपने सवाल कैसे पूछता है
advanced-interview-tree = ट्री
advanced-interview-cloud = क्लाउड
advanced-interview-hybrid = हाइब्रिड
advanced-data = डेटा
advanced-format-about = वह फ़ॉर्मेट जिसमें निर्यात हर कार्ड लिखता है; ज़्यादातर ऐप SillyTavern V3 खोलते हैं
advanced-history-about = हर टेक्स्ट के पिछले संस्करण; सिर्फ़ Cardwave के अपने कार्ड फ़ॉर्मैट में
advanced-helper = हेल्पर मॉडल
advanced-the-helper = हेल्पर मॉडल

## Cardwave's CSS (views/css-reference.ts)

cssref-rail = बाईं ओर का रेल
cssref-main = रेल के बगल वाली स्क्रीन
cssref-crumbs = पेज के ऊपर का रास्ता
cssref-group = लाइनों का एक बॉक्स, जैसे सेटिंग्स में
cssref-item = बॉक्स की एक लाइन
cssref-row = सूची की एक लाइन
cssref-tile = लाइब्रेरी के ग्रिड में एक कार्ड
cssref-msg = चैट में एक मैसेज
cssref-bubble = मैसेज का बबल
cssref-composer = चैट के नीचे का मैसेज फ़ील्ड
cssref-dialog = एक डायलॉग
cssref-btn-primary = नीला बटन
cssref-switch = एक स्विच
cssref-pill = एक पिल
cssref-notice = विंडो के नीचे का नोटिस
cssref-snippet-green = हरा एक्सेंट
cssref-snippet-square = चौकोर बबल
cssref-snippet-larger = बड़ा टेक्स्ट
cssref-snippet-wider = चौड़े डायलॉग
cssref-snippet-tighter = कम जगह
cssref-snippet-black = काली डार्क थीम
cssref-in-dark = { $light } · डार्क में { $dark }
cssref-none = इस नाम का कोई वैरिएबल नहीं।
cssref-copy-of = “{ $title }” कॉपी करें
cssref-copied = कॉपी हुआ।
cssref-copy = कॉपी करें
cssref-about-1 = वे वैरिएबल और क्लास नाम जो आपका अपना CSS इस्तेमाल कर सकता है। ऐप का हर रंग और साइज़{ " " }
cssref-about-2 = { " " }में एक वैरिएबल है, एक लाइट और एक डार्क वैल्यू के साथ।
cssref-variables = वैरिएबल
cssref-search = खोज
cssref-find = वैरिएबल ढूँढें
cssref-all = कुल { $count } वैरिएबल।
cssref-classes = क्लास नाम
cssref-snippets = स्निपेट

## Tools the AI wrote (views/written-tools.ts)

written-about = { $what } · बनाया गया: { $made }
written-about-in = { $what } · बनाया गया: { $made }, { $chat } में
written-used = { $count ->
    [0] अभी इस्तेमाल नहीं हुआ
    [one] एक बार इस्तेमाल हुआ
   *[other] { $count } बार इस्तेमाल हुआ
  }
written-none = अभी कोई टूल नहीं। किसी चैट में “AI को टूल लिखने दें” चालू करें, और जो वह लिखेगा वह यहाँ दिखेगा।
written-ask = नया टूल चलने से पहले पूछें
written-ask-about = हर टूल के लिए एक बार: पहली बार चलने पर आप अनुमति देते हैं
written-in = { " " }· चैट:{ " " }
written-made = बनाया गया: { $made }
written-dot-used = { " " }· { $used }
written-switch-off = बंद करें
written-switch-on = चालू करें
written-intro = छोटे टूल जो AI ने उन चैट में अपने लिए लिखे जहाँ “AI को टूल लिखने दें” चालू है। वे आपकी फ़ाइलें तभी छूते हैं जब आप अनुमति दें, और आगे की चैट के लिए रखे जाते हैं।
written-deleted = टूल “{ $name }” हटाया गया।
written-on = { $name } चालू
written-view-code = कोड देखें

## The coding team, shared by the chat and its pages (chat/coding.ts)

coding-quick = तेज़
coding-balanced = संतुलित
coding-thorough = पूरी जाँच वाला
coding-custom = कस्टम
coding-running = चल रहा है
coding-done = हो गया
coding-failed = विफल
coding-stopped = रोका गया
coding-team-says-alone = { $name }: एक प्लानर, { $workers ->
    [1] एक वर्कर
    [2] दो वर्कर
   *[other] तीन वर्कर
  }, बिना ऑडिटर के।
coding-team-says-tests = { $name }: एक प्लानर, { $workers ->
    [1] एक वर्कर
    [2] दो वर्कर
   *[other] तीन वर्कर
  } और एक ऑडिटर जो टेस्ट चलाता है।
coding-team-says-steps = { $name }: एक प्लानर, { $workers ->
    [1] एक वर्कर
    [2] दो वर्कर
   *[other] तीन वर्कर
  } और एक ऑडिटर जो हर चरण जाँचता है और टेस्ट चलाता है।
coding-team-label = { $name } · { $workers ->
    [one] { $workers } वर्कर
   *[other] { $workers } वर्कर
  }
coding-team-label-auditor = { $name } · { $workers ->
    [one] { $workers } वर्कर
   *[other] { $workers } वर्कर
  }, ऑडिटर
coding-team-label-steps = { $name } · { $workers ->
    [one] { $workers } वर्कर
   *[other] { $workers } वर्कर
  }, हर चरण पर ऑडिटर
coding-tests-pass = { $total } में से { $passed } टेस्ट पास
coding-passed = पास
coding-problems = समस्याएँ मिलीं

## Coding team (views/coding-team.ts)

team-audit-end = आखिर में
team-audit-each = हर चरण के बाद
team-audit-never = कभी नहीं
team-change = बदलें
team-workers-of = { $model } · एक साथ { $workers }
team-worker-model = वर्कर मॉडल
team-change-worker = वर्कर मॉडल बदलें
team-how-many = कितने वर्कर
team-none = कोई नहीं
team-auditor-tests = { $model } · टेस्ट चलाता है
team-auditor-steps = { $model } · हर चरण जाँचता है
team-auditor-model = ऑडिटर मॉडल
team-change-auditor = ऑडिटर मॉडल बदलें
team-when = ऑडिटर कब जाँचता है
team-team = टीम
team-roles = भूमिकाएँ
team-planner-model = प्लानर मॉडल
team-change-planner = प्लानर मॉडल बदलें
team-recent = हाल के टास्क
team-intro = AI जो इस कंप्यूटर पर मिलकर आपके लिए एक प्रोग्राम लिखते हैं, किसी चैट से शुरू।
team-no-tasks = अभी कोई कार्य नहीं। कार्य किसी चैट में शुरू होता है, संदेश फ़ील्ड के पास वाले “+” › कोडिंग कार्य शुरू करें से।

## Trash (views/trash.ts)

trash-expressions = एक्सप्रेशन · किसी किरदार के पास नहीं
trash-figure = 3D फ़िगर · किसी किरदार के पास नहीं
trash-chat-with = { $names } के साथ चैट
trash-chat = चैट
trash-persona = पर्सोना
trash-persona-used = पर्सोना · { $count ->
    [one] { $count } चैट
   *[other] { $count } चैट
  } में इस्तेमाल हुआ
trash-lorebook = लोरबुक
trash-lorebook-used = लोरबुक · { $count ->
    [one] { $count } चैट
   *[other] { $count } चैट
  } में इस्तेमाल हुई
trash-character = किरदार
trash-character-chats = किरदार · { $count ->
    [one] { $count } चैट
   *[other] { $count } चैट
  } के साथ
trash-empty = ट्रैश खाली है।
trash-about = यहाँ लाई गई चीज़ें { $days } दिन रखी जाती हैं, फिर हमेशा के लिए हटा दी जाती हैं।
trash-emptied = ट्रैश खाली किया गया।
trash-empty-trash = ट्रैश खाली करें
trash-delete-all-ask = { $count ->
    [one] { $count } आइटम
   *[other] सभी { $count } आइटम
  } हमेशा के लिए हटाएँ?
trash-restored = “{ $title }” रीस्टोर हुआ।
trash-deleted = “{ $title }” हमेशा के लिए हटाया गया।
trash-deleted-at = यहाँ भेजा गया: { $when }
trash-days-left = { $count ->
    [one] { $count } दिन बाकी
   *[other] { $count } दिन बाकी
  }
trash-restore = रीस्टोर करें
trash-restore-chats = किरदार और { $count ->
    [one] उसकी चैट
   *[other] उसकी { $count } चैट
  } वापस लाता है
trash-delete-forever = हमेशा के लिए हटाएँ
trash-delete-forever-ask = “{ $title }” को हमेशा के लिए हटाएँ? इसे वापस नहीं लाया जा सकता।
trash-delete-forever-ask-chats = “{ $title }” और { $count ->
    [one] उसकी चैट
   *[other] उसकी { $count } चैट
  } को हमेशा के लिए हटाएँ? इन्हें वापस नहीं लाया जा सकता।

## About Cardwave (views/about.ts)

about-no-package = इस नाम का कोई पैकेज नहीं।
about-no-notes = इस वर्ज़न के साथ कोई नोट नहीं आए।
about-by = { $by } द्वारा
about-licence-of = { $name } का लाइसेंस
about-licence = लाइसेंस
about-folder-failed = फ़ोल्डर नहीं खुला: { $reason }। यह { $where } पर है।
about-open-folder = फ़ोल्डर खोलें
about-logs-where = Cardwave के डेटा फ़ोल्डर के “logs” फ़ोल्डर में, उस कंप्यूटर पर जिस पर Cardwave चलता है
about-logs = लॉग
about-logs-about = Cardwave ने क्या किया और कोई क्रैश, हर दिन एक फ़ाइल, 7 दिन रखी जाती है: कुछ गड़बड़ होने पर मदद के लिए · { $where }
about-version = वर्ज़न { $version }
about-whats-new = नया क्या है
about-packages = { $count } पैकेज
about-open-source = ओपन-सोर्स सॉफ़्टवेयर
about-search = खोज
about-find = पैकेज ढूँढें
about-version-built = वर्ज़न { $version } · { $built }
about-models = मॉडल
about-figures = फ़िगर और एनिमेशन
about-voices = आवाज़ें
about-lists = प्रोवाइडर और मॉडल की सूची

about-or = या
about-and = और
about-with = के साथ

## Prompt preset (views/prompt-preset.ts)

prompt-new = नया प्रॉम्प्ट प्रीसेट
promptpage-system = सिस्टम प्रॉम्प्ट
prompt-system-about = कार्ड के सिस्टम प्रॉम्प्ट की जगह लेता है। कार्ड वाला रखने के लिए खाली छोड़ें।
promptpage-note = नोट
prompt-note-about = AI हर जवाब से पहले इसे पढ़ता है; आप इसे चैट में नहीं देखते। यह उतने संदेश पीछे जाता है जितने नीचे तय हैं।
prompt-depth = कितने मैसेज पहले
prompt-intro = AI के लिए निर्देश। किसी चैट में इसे इस्तेमाल करने के लिए उसके साइड पैनल में यह प्रीसेट चुनें।
prompt-depth-about = 1 इसे सबसे नए संदेश से ठीक पहले रखता है, 4 चार संदेश पीछे।
prompt-saved = प्रीसेट “{ $name }” सेव किया गया।
prompt-gone = यह प्रॉम्प्ट प्रीसेट हटा दिया गया। वापस जाकर कोई दूसरा चुनें।

## Profile (views/profile.ts)

profile-change-picture = तस्वीर बदलें
profile-change = बदलें
profile-remove-picture = तस्वीर हटाएँ
profile-remove = हटाएँ
profile-picture-changed = तस्वीर बदल दी गई।
profile-picture-removed = तस्वीर हटा दी गई।
profile-your-picture = आपकी तस्वीर
profile-no-picture = कोई तस्वीर नहीं: आपका पहला अक्षर { $letter } दिखता है
profile-change-name = नाम बदलें
profile-this-computer = इस कंप्यूटर का अकाउंट
profile-on-server = इस कंप्यूटर पर अकाउंट
profile-account = अकाउंट

## Server (views/server.ts)

server-copy = कॉपी करें
server-no-network = यह कंप्यूटर किसी नेटवर्क से जुड़ा नहीं है। दूसरे डिवाइस आने देने के लिए इसे वाई-फ़ाई या केबल से जोड़ें।
server-switch-on-about = फिर इस नेटवर्क के फ़ोन और दूसरे कंप्यूटर Cardwave खोल सकते हैं। हर अकाउंट अपने पासवर्ड से साइन इन करता है।
server-switch-on = चालू करें
server-network-about = फ़ोन और दूसरे कंप्यूटर Cardwave को ब्राउज़र में खोलते हैं
server-other-devices = दूसरे डिवाइस
server-inside = केवल इस नेटवर्क के डिवाइस इसे खोल सकते हैं, जब तक आप अपने राउटर को दूसरों के लिए सेट न करें।
server-add-account = अकाउंट जोड़ें
server-owner = यह कंप्यूटर · खाते जोड़ और हटा सकता है
server-more-of = और: { $name }
server-reset-password = पासवर्ड रीसेट करें
server-delete-account = अकाउंट हटाएँ
server-deleted = अकाउंट “{ $name }” हटाया गया।
server-delete-ask = इस खाते को इसके किरदारों, चैट और सेटिंग्स समेत हटाएँ? इसे वापस नहीं किया जा सकता।
server-reset-title = { $name } का पासवर्ड रीसेट करें
server-reset-about = अकाउंट नए पासवर्ड से साइन इन करता है, और जहाँ भी साइन इन है, वहाँ से साइन आउट हो जाता है।
server-new-password = नया पासवर्ड
server-reset-done = { $name } का पासवर्ड रीसेट हुआ।
server-reset = रीसेट करें
server-accounts = अकाउंट

## Character generator (views/generator.ts)

gen-gender-woman = महिला
gen-gender-man = पुरुष
gen-gender-non-binary = नॉन-बाइनरी
gen-being-human = इंसान
gen-being-not-human = इंसान नहीं
gen-age-20s = 20–29
gen-age-30s = 30–39
gen-age-40s = 40–49
gen-age-50s-and-older = 50 और ऊपर
gen-build-slim = स्लिम
gen-build-average = सामान्य
gen-build-athletic = एथलेटिक
gen-build-strong = मज़बूत
gen-hair-short = छोटे
gen-hair-medium = मध्यम
gen-hair-long = लंबे
gen-colour-black = काले
gen-colour-brown = भूरे
gen-colour-blonde = सुनहरे
gen-colour-red = लाल
gen-colour-grey = सलेटी
gen-colour-white = सफ़ेद
gen-relation-stranger = अजनबी
gen-relation-friend = दोस्त
gen-relation-partner = पार्टनर
gen-relation-rival = प्रतिद्वंद्वी
gen-relation-colleague = सहकर्मी
gen-relation-mentor = मेंटर
gen-shy = संकोची
gen-outgoing = मिलनसार
gen-gentle = सौम्य
gen-harsh = कठोर
gen-serious = गंभीर
gen-playful = चंचल
gen-cautious = सतर्क
gen-bold = निडर
gen-random = रैंडम
gen-slider = { $low } से { $high }
gen-looks = रूप-रंग
gen-gender = लिंग
gen-being = इंसान या नहीं
gen-any = कोई भी
gen-age = उम्र
gen-build = कद-काठी
gen-hair = बाल
gen-hair-colour = बालों का रंग
gen-personality = स्वभाव
gen-relates = यह किरदार आपके लिए कौन है
gen-make = किरदार बनाएँ
gen-what = कुछ ख़ूबियाँ चुनें; AI किरदार का पहला मैसेज और उसके बात करने का ढंग लिखता है।
interview-goes-to = किरदार लिखने के लिए आपके जवाब { $provider } को जाते हैं।
interview-stays = आपके जवाब इसी कंप्यूटर पर रहते हैं।
interview-own-words = या अपने शब्द जोड़ें
interview-in-own-words = अपने शब्दों में
interview-your-answer = आपका जवाब
interview-pick-one = एक चुनें
interview-pick-two = एक या दो चुनें
interview-pick-three = तीन तक चुनें
interview-pick-many = जितने ठीक लगें, चुनें
interview-few-words = कुछ शब्द काफ़ी हैं
interview-wanted-hint = लोगों के साथ, या जिन किरदारों को आपने आज़माया उनके साथ, क्या कमी थी?
interview-needs-hint = किरदार के साथ आपके समय के लिए, आपकी बाकी ज़िंदगी के लिए नहीं
interview-next = आगे
interview-skip = छोड़ें
interview-dont-know = मुझे नहीं पता
interview-back = वापस
interview-just-make-it = बस बना दें
interview-more = और प्रकार
interview-writing-next = अगला सवाल लिखा जा रहा है
interview-try-again = फिर कोशिश करें
interview-failed-where = अगर यह बार-बार विफल हो, तो सेटिंग्स › प्रोवाइडर में प्रोवाइडर और मॉडल देखें।
gen-stop = रोकें
gen-writing = किरदार लिखा जा रहा है…
interview-understood = मैंने यह समझा।
interview-you-said = आपने कहा: “{ $words }”
interview-own-guess = AI का अपना अनुमान
interview-keep = रखें
interview-change = बदलें
interview-remove = हटाएँ
interview-not-it = ऐसा नहीं है
interview-not-it-off = यह पंक्ति किसी ऐसे एक सवाल पर नहीं टिकी जिसे फिर पूछा जा सके
interview-own-sentence = आपका अपना वाक्य
interview-private-line = आपके किरदार की दुनिया में कुछ जो आप ज़रूर चाहें, या कभी नहीं?
interview-private-sub = रोमांस, हिंसा, गाली-गलौज और भी · ज़रूरी नहीं
interview-make = किरदार बनाएँ
interview-make-after = बाद में आप इसे इसके पेज पर बदल सकते हैं।
interview-skip-all = सब छोड़ें
interview-private-hint = कुछ लोग ये बातें अपने किरदार की दुनिया में चाहते हैं, कुछ नहीं। आपके जवाब इस किरदार के साथ आपके कंप्यूटर पर रहते हैं और सिर्फ़ उस AI को जाते हैं जो किरदार को लिखता है।
interview-private-free = और कुछ जो आप चाहें, या कभी न चाहें
interview-yes = हाँ
interview-no = नहीं
interview-maybe = शायद
interview-fantasy-only = सिर्फ़ फ़ैंटेसी में
interview-never = कभी नहीं
interview-try-another = दूसरा मॉडल आज़माएँ
interview-without-topic = उस विषय के बिना लिखें
interview-model-provider = { $model } · { $provider }
interview-reading = आपके जवाब पढ़े जा रहे हैं
interview-persona-title = आपने अपने बारे में जो कहा, उसे अपने पर्सोना में जोड़ें?
interview-persona-field = पर्सोना
interview-persona-in-use = { $persona } · इस्तेमाल में
interview-persona-new = नया पर्सोना
interview-persona-add = जोड़ें
interview-persona-not-now = अभी नहीं
interview-persona-added = “{ $persona }” में जोड़ा गया।
interview-persona-you = आप
