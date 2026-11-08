### Kata-kata antarmuka dalam bahasa Indonesia, diterjemahkan dari bahasa Inggris (en.ftl, berkas acuannya), kunci
### demi kunci; tes struktur (structure.test.ts) memeriksa bahwa semuanya ada di sini dengan bentuk yang sama.
### Daftar kata, satu nama untuk satu hal, di semua id.*.ftl:
###   Sapaan: kamu (-mu), seperti aplikasi konsumen dan obrolan di Indonesia (Gojek, Spotify, Duolingo); aplikasi menyebut dirinya
###   «aku» bila perlu. Tak ada jenis kelamin pengguna (bahasa Indonesia tak menandainya: dia, teman, mantanmu).
###   Cardwave, MCP, Claude Desktop, CSS, Lorebook (lorebook), Persona, prompt, preset, chat, AI, token: tetap begitu.
###   character = karakter; card = kartu (berkasnya, kartu karakter); figure = figur (3D).
###   memory = memori; document = dokumen; library = pustaka; knowledge = pengetahuan; account = akun.
###   provider = penyedia; model = model; helper (model) = model pembantu; tool = alat; tab = tab.
###   Settings = Pengaturan; Advanced = Lanjutan; Trash = Sampah (milik Cardwave);
###   Recycle Bin = Keranjang Sampah (milik Windows); backup = cadangan, back up = cadangkan; restore = pulihkan; Sharing = Berbagi.
###   companion = pendamping; voice = suara; dictation = dikte; Search Cardwave = Cari di Cardwave.
###   coding team = tim pemrograman; planner = perencana; worker = pekerja; auditor = auditor; task = tugas.
###   sign in = masuk; sign out = keluar; lock = kunci; import = impor; export = ekspor; password = kata sandi.
###   interview = wawancara; generator = generator karakter; theme = tema; first run = penyiapan awal.
###   Pengganti nama pengguna tanpa persona (card-user-stand-in, cw_prompt::stand_in_user): Tamu (tanpa gender, terbaca dalam kalimat).
###   Tak ada bentuk jamak (Intl.PluralRules «id»: hanya other); angka tak diulang («2 karakter», bukan «karakter-karakter»).
###   Label di tengah kalimat dengan huruf kecil (midSentence, seperti bahasa Inggris).

## The app

app-name = Cardwave

## The pages, as tabs, the rail and Search Cardwave name them (shell/pages.ts)

page-chats = Chat
page-characters = Karakter
page-lorebooks = Lorebook
page-personas = Persona
page-memories = Memori
page-documents = Dokumen
page-generator = Generator karakter
page-interview = Buat karakter bersama
page-profile = Profil
page-server = Berbagi
page-settings = Pengaturan
page-providers = Penyedia
page-voices = Suara
page-advanced = Lanjutan
page-css = CSS Cardwave
page-written-tools = Alat buatan AI
page-coding-team = Tim pemrograman
page-trash = Sampah
page-about = Tentang Cardwave
page-coding-task = Tugas pemrograman
page-chat = Chat
page-new-card = Karakter baru
page-lorebook = Lorebook
page-card = Karakter
page-prompt-preset = Preset prompt
page-first-run = Siapkan Cardwave

## The places pages are under

place-library = Pustaka
place-knowledge = Pengetahuan
place-account = Akun
place-settings = Pengaturan
place-advanced = Pengaturan › Lanjutan

## The rail (shell/rail.ts)

rail-create = Buat
rail-memories-tip = Memori: yang diingat AI dari chat Anda
rail-documents-tip = Dokumen: file yang dibaca AI saat menjawab
rail-show-more = Tampilkan { $count } lagi
rail-open-menu = Buka bilah samping
rail-close-menu = Tutup bilah samping
rail-collapse = Ciutkan bilah samping
rail-expand = Bentangkan bilah samping
rail-account = Akun
rail-account-named = Akun: { $name }
rail-lock = Kunci

## Create's lines (shell/create.ts)

create-new-chat = Chat baru
create-plain-chat = Chat tanpa karakter
create-new-card = Karakter baru
create-from-picks = Generator karakter
create-together = Buat karakter bersama
create-new-persona = Persona baru
create-new-lorebook = Lorebook baru
create-import-card = Impor kartu
create-import-lorebook = Impor lorebook
create-new = Baru
create-import = Impor

## The title bar and its tabs (shell/titlebar.ts)

tabs = Tab
tab-new = Tab baru
tab-new-keys = Tab baru (Ctrl+T)
tabs-all = Semua tab
tab-close = Tutup tab
window-minimize = Kecilkan
window-maximize = Besarkan
window-close = Tutup

## The view menu (shell/view-menu.ts, theme.ts)

view = Tampilan
view-compact = Ringkas
theme-system = Sistem
theme-light = Terang
theme-dark = Gelap
theme-downtempo = Downtempo
theme-outrun = Outrun
theme-retrowave = Retrowave
theme-neonwave-dark = Neon Wave gelap
theme-neonwave-light = Neon Wave terang

## Search Cardwave's button (shell/search-panel.ts)

search = Cari di Cardwave
search-keys = Cari di Cardwave (Ctrl+K)

## The labels of the settings, as their pages and Search Cardwave name them (setting-labels.ts)

label-settings-theme = Tema
label-settings-chat-layout = Tata letak chat
label-settings-web-pictures = Tampilkan gambar dari situs web lain
label-settings-app-language = Bahasa aplikasi
label-settings-language = Bahasa tulisan AI
label-settings-providers = Penyedia
label-settings-chat = Chat
label-settings-images = Gambar
label-settings-voice = Suara
label-settings-search = Pencarian
label-settings-dictation = Dikte
label-settings-web = Web
label-settings-files = Berkas
label-settings-commands = Perintah
label-settings-image-generation = Pembuatan gambar
label-settings-app = Cardwave
label-settings-dice = Dadu
label-settings-folder = Folder
label-settings-written = Alat buatan AI
label-settings-coding = Tim pemrograman
label-settings-trash = Sampah
label-settings-backup = Cadangan
label-settings-restore = Pulihkan
label-settings-cards-folder = Folder kartu
label-settings-advanced = Lanjutan
label-settings-setup = Jalankan penyiapan lagi
label-settings-about = Tentang Cardwave
label-providers-this-computer = Komputer ini
label-voices-model = Model suara
label-voices-speed = Kecepatan
label-voices-english = Inggris
label-advanced-background = Model pembantu
label-advanced-told = Yang diberitahukan kepada AI
label-advanced-describe = Deskripsikan karakter yang diimpor
label-advanced-described = Karakter yang sudah dideskripsikan
label-advanced-interview = Buat karakter bersama
label-advanced-format = Format ekspor
label-advanced-history = Sertakan versi lama setiap teks
label-advanced-css = CSS-mu sendiri
label-coding-planner = Perencana
label-coding-workers = Pekerja
label-coding-auditor = Auditor
label-profile-name = Nama
label-profile-picture = Gambar
label-profile-password = Kata sandi
label-server-network = Dapat dijangkau di jaringan rumah
label-server-address = Alamat
label-server-mcp = Izinkan aplikasi AI di komputer ini memakai Cardwave

layout-bubbles = Gelembung
layout-plain = Polos

## Settings (views/settings.ts)

settings-appearance = Tampilan
settings-theme-about = Mengikuti sistem kecuali kamu memilih satu
settings-layout-about = Pesan sebagai gelembung, atau sebagai teks polos
settings-web-pictures-about = Situs web itu dapat melihat kapan kamu membuka chat.
settings-language = Bahasa
settings-data = Data
settings-trash-about = { $count ->
   *[other] { $count } item
  } · dikosongkan setelah { $days } hari
settings-open-trash = Buka Sampah
settings-open = Buka
settings-version = Versi { $version } · lisensi
settings-licences = Lisensi
settings-advanced-about = Model pembantu, pustaka, ekspor, chat tanpa karakter, sampling, preset, CSS-mu sendiri
settings-setup-about = Penyedia, model, dan suara, langkah demi langkah
settings-providers-about = Alamat dan kunci layanan yang menjalankan model
settings-this-computer = komputer ini
settings-providers-named = Sudah disiapkan: { $names }
settings-models = Model
settings-the-chat-model = model chat
settings-the-image-model = model gambar

## The account's tabs and accounts (shell/account-tabs.ts, settings/accounts.ts)

account-sections = Bagian akun
account-switch = Ganti akun

account-password = Kata sandi
account-switch-to = Ganti ke { $name }
account-password-asked = Ketik kata sandi { $name }.
account-switch-button = Ganti
account-add = Tambah akun
account-add-about = Akun orang lain di komputer ini, dengan chat dan karakternya sendiri. Akun itu masuk dengan kata sandinya, di sini atau di perangkat lain.
account-name = Nama
account-added = Akun “{ $name }” ditambahkan.
account-add-button = Tambah
account-sign-out = Keluar
account-none = Tidak ada akun untuk dimasuki
account-none-about = Belum ada akun yang bisa masuk dari sini. Di komputer tempat Cardwave berjalan, tambahkan satu di Akun › Berbagi.
account-this-computer = Akun komputer ini
account-choose = Pilih akunmu
account-try-again = Coba lagi
account-back = Kembali
account-sign-in = Masuk

## Backup and Restore (settings/backup.ts)

backup-saving = Menyimpan cadangan.
backup-saving-to = Menyimpan cadangan ke { $folder }.
backup-password = Kata sandi
backup-repeat = Ulangi kata sandi
backup-encrypted = Cadangan dienkripsi dengan kata sandi ini; memulihkannya memerlukan kata sandi itu, di sini atau di komputer lain.
backup-forgotten = Kata sandi yang terlupa tidak dapat dipulihkan, dan cadangan tidak dapat dipulihkan tanpanya.
backup-with-password = Cadangkan dengan kata sandi
backup-differ = Kedua kata sandi berbeda.
backup-back-up = Simpan cadangan
backup-no-file = Belum ada berkas yang dipilih
backup-choose-file = Pilih berkas
backup-its-password = Kata sandi cadangan
backup-restoring = Memulihkan akan mengganti semua yang ada di Cardwave: chat, karakter, persona, lorebook, memori, dan pengaturan. Ini tidak dapat dibatalkan. Kata sandi di sini tetap seperti sekarang. Akun lain juga ikut diganti.
backup-restored = Cadangan dipulihkan: semua di Cardwave kembali seperti saat cadangan dibuat. Perangkat lain masuk lagi.
backup-file = Berkas
backup-restore-title = Pulihkan cadangan
backup-choose-first = Pilih dulu berkas cadangannya.
backup-restore = Pulihkan cadangan
backup-from-file = Dari berkas cadangan
backup-about-own = Chat, karakter, dan pengaturan dalam satu berkas, dienkripsi dengan kata sandimu
backup-about-chosen = Chat, karakter, dan pengaturan dalam satu berkas, dienkripsi dengan kata sandi pilihanmu

## The folder of cards (settings/card-folder.ts)

folder-watch = Impor kartu baru secara otomatis
folder-watch-about = Berkas kartu yang ditaruh di folder masuk ke pustakamu dengan sendirinya
folder-recycle = Pindahkan berkas yang diimpor ke Keranjang Sampah
folder-recycle-about = Setelah file diimpor, file masuk ke Recycle Bin

## The companion's line (library/companion-app.ts)

companion = Pendamping
# The companion window's name, which the system shows in its lists of windows.
companion-window = Pendamping Cardwave
companion-made = { $name } kini pendampingmu.
companion-make = Jadikan pendamping
companion-none = Belum ada pendamping. Buka menu “…” sebuah karakter lalu pilih “Jadikan pendamping”.
companion-named = { $name } · Mulai bersama aplikasi
companion-figure = Figur pendamping
companion-figure-about = Ditampilkan untuk karakter yang tidak punya figur 3D sendiri
companion-figure-woman = Perempuan
companion-figure-man = Laki-laki
companion-figure-robot = Robot
companion-size = Ukuran pendamping
companion-size-about = Tinggi figur, sebagai bagian dari tinggi layar
companion-size-value = { $size }%

## Other programs, MCP (settings/mcp.ts)

mcp-ask-title = Izinkan aplikasi AI di komputer ini memakai Cardwave
mcp-ask = Program di komputer ini, seperti Claude Desktop, bisa membaca karakter dan obrolanmu, menulis di obrolanmu, dan memakai alat yang dinyalakan di Pengaturan › Alat. Apa yang akan Cardwave tanyakan dulu kepadamu tidak bisa mereka lakukan.
mcp-switch-on = Nyalakan
mcp-about = Seperti Claude Desktop, lewat MCP: memakai karakter, obrolan, dan alat Anda
mcp-copy-address = Salin alamat MCP
mcp-copy = Salin
mcp-as-account = Sebagai akun
mcp-as-account-about = Apa yang dapat mereka lihat dan lakukan
mcp-remove-named = Hapus { $program }
mcp-removed = “{ $program }” dihapus.
mcp-remove = Hapus
mcp-connected = Terhubung
mcp-other-programs = Program lain
mcp-only-here = Hanya program di komputer ini yang dapat terhubung. Program yang dihapus tetap di luar sampai kamu mematikan lalu menyalakan ini lagi.

## Your own CSS (settings/own-css.ts)

css-none = Tidak ada
css-lines = { $count ->
   *[other] { $count } baris
  }
css-about = { $lines } · mengubah tampilan aplikasi
css-hint = Diterapkan setelah stylesheet Cardwave sendiri, sambil kamu mengetik. Simpan mempertahankannya; Batal menariknya kembali.
css-edit-own = Sunting CSS-mu sendiri
css-edit = Sunting

## The password (settings/password.ts)

password-forgotten = Kata sandi yang terlupa tidak bisa dipulihkan, dan obrolan serta karakter Anda hilang bersamanya. Simpan di tempat aman.
password-on-title = Atur kata sandi
password-on-says = Cardwave akan memintanya saat dibuka. Tanpanya tak ada yang bisa membuka Cardwave atau membaca obrolan Anda di komputer ini.
password-on = Atur kata sandi
password-on-done = Kata sandi diatur.
password-change-title = Ubah kata sandi
password-change-says = Cardwave akan meminta yang baru saat dibuka.
password-change = Ubah
password-change-done = Kata sandi diubah.
password-off-title = Matikan kata sandi
password-off-says = Cardwave akan terbuka tanpa memintanya. Chat dan karaktermu tetap terenkripsi.
password-off = Matikan
password-off-done = Kata sandi dimatikan.
password-differ = Kedua kata sandi berbeda.
password-other-says = Sejak itu kamu masuk dengan yang baru.
password-other-forgotten = Kalau kamu lupa, akun komputer ini dapat mengaturnya ulang, di Berbagi.
password-current = Kata sandi saat ini
password-password = Kata sandi
password-new = Kata sandi baru
password-repeat = Ulangi kata sandi
password-asked-sign-in = Diminta saat kamu masuk
password-is-on = Nyala · diminta saat aplikasi dibuka
password-is-off = Mati · siapa pun di komputer ini dapat membuka Cardwave
password-start-forgotten = Kata sandi yang terlupa tidak dapat dipulihkan.
password-open = Buka
password-locked-elsewhere = Cardwave terkunci di komputernya. Cardwave terbuka di sini begitu dibuka di sana.
password-back = Kembali

## Words many pages use

common-use = Pakai
common-in-use = { " " }· dipakai
common-more = Lainnya
common-edit = Sunting
common-duplicate = Gandakan
# The word a copy's name ends in, as in "Rig (copy)".
common-copy-word = salinan
common-delete = Hapus
common-save = Simpan
common-cancel = Batal
common-name = Nama

## Model presets and prompt presets (settings/presets.ts, settings/prompt-presets.ts)

preset-what = Preset menyimpan model chat beserta nilai sampling-nya. Pakai beralih ke preset itu.
preset-temperature = temperatur { $value }
preset-new = Preset baru
preset-model-presets = Preset model
preset-using = Memakai “{ $name }”.
preset-added = Preset “{ $name }” ditambahkan.
preset-deleted = Preset “{ $name }” dihapus.
preset-saved = Preset “{ $name }” disimpan.
preset-delete-ask = Hapus preset ini?
preset-replace = Gunakan model dan pengaturan saat ini
preset-replace-hint = Model obrolan, penyedianya, dan sampling di halaman ini. Mati: preset menyimpan miliknya sendiri.
preset-keeps-hint = Preset ini menyimpan model chat di Pengaturan › Model, penyedianya, dan sampling di halaman ini.
preset-name = Nama
preset-edit = Sunting preset
prompt-presets = Preset prompt
prompt-system = Prompt sistem
prompt-note = { $depth ->
   *[other] Catatan, { $depth } pesan ke belakang
}
prompt-system-note = { $depth ->
   *[other] Prompt sistem · catatan, { $depth } pesan ke belakang
}
prompt-as-card = Sesuai karakter
prompt-default = Bawaan
prompt-default-name = “{ $name }” adalah prompt milik karakter itu sendiri.

## Tools (settings/tools.ts, chat/tool-ask.ts)

tools-written-ask = { $count ->
    [0] Belum ada
   *[other] { $count } alat
  } · tanya dulu sebelum alat baru berjalan
tools-written-free = { $count ->
    [0] Belum ada
   *[other] { $count } alat
  } · alat baru berjalan tanpa bertanya
tools-folder-first = Pilih folder dulu
tools-web = Cari dan baca halaman web
tools-files = Hanya { $folder }
tools-ask-writes = Tanya sebelum menulis
tools-ask-writes-says = Setiap berkas ditunjukkan kepadamu sebelum ditulis
tools-commands = Berjalan di { $folder }, terpisah dari bagian lain komputer dan dari internet
tools-ask-commands = Tanya sebelum menjalankan
tools-ask-commands-says = Setiap perintah ditunjukkan kepadamu sebelum berjalan
tools-pictures = Memakai model gambar
tools-pictures-first = Siapkan model gambar dulu
tools-app = Pakai dan ubah karakter, chat, dan pengaturanmu; setiap perubahan ditanyakan dulu
tools-dice = Membiarkan AI melempar dadu; Cardwave yang melemparnya, jadi hasilnya adil.
tools-folder-example = C:\Users\kamu\Documents\Berbagi
tools-folder-says = Berkas dan perintah menjangkau folder ini beserta isinya, dan tidak lebih.
tools-change-folder = Ganti folder
tools-change = Ganti
tools-choose = Pilih
tools-none-chosen = Belum dipilih
tools-title = Alat
tools-ask-new = { $name } ingin memakai alat baru: { $what }
tools-ask-write = { $name } ingin menulis “{ $what }” di foldermu:
tools-ask-read = { $name } ingin membaca di foldermu:
tools-ask-install = { $name } ingin mengunduh dan memasang program yang dibutuhkannya:
tools-ask-web = { $name } ingin memakai web:
tools-ask-app = { $name } ingin mengubah Cardwave:
tools-ask-command = { $name } ingin menjalankan perintah di foldermu:
tools-allow = Izinkan
tools-deny = Tolak
tools-allow-writing = Izinkan menulis berkas untuk chat ini
tools-allow-commands = Izinkan perintah untuk chat ini

## Updates (settings/update.ts)

update-title = Periksa pembaruan
update-available = Cardwave { $version } tersedia
update-you-have = Kamu memakai { $version }.
update-up-to-date = Cardwave sudah versi terbaru ({ $version }).
update-connection-error = Tidak dapat memeriksa pembaruan. Periksa koneksimu.
update-check-failed = Tidak dapat memeriksa pembaruan: GitHub tidak menjawab dengan versi terbaru.
update-whats-new = Yang baru
update-close = Tutup
update-ok = OK
update-download = Unduh
update-install = Perbarui dan mulai ulang
update-installing = Mengunduh Cardwave { $version }…
update-auto = Periksa secara otomatis
update-auto-about = Cari versi baru saat mulai dan sekali sehari
update-check = Periksa
update-checking = Memeriksa…
update-about = Periksa apakah ada versi aplikasi yang lebih baru.

## The breadcrumbs of a page under Settings

crumbs = Posisi Anda

## Providers (views/providers.ts)

providers-key-end = { $where } · kunci ····{ $end }
providers-key-saved = { $where } · kunci tersimpan
providers-no-key = { $where } · tanpa kunci
providers-thinking-cannot = { $provider } tidak dapat mematikan berpikir untuk model ini
providers-thinking-off = Model membalas tanpa berpikir dulu
providers-thinking-on = Model berpikir sebelum membalas
providers-comfy-default = Bawaan ComfyUI
providers-workflow-note = Workflow ini memakai model dan ukurannya sendiri, bukan model Gambar.
providers-testing-model = Menguji model…
providers-thinking-of = { $label }: berpikir
providers-thinking = Berpikir
providers-testing-workflow = Menguji workflow…
providers-workflows-from = Dari workflow yang disimpan ComfyUI
providers-pictures-by = Gambar oleh “{ $name }”.
providers-pictures-default = Gambar oleh workflow bawaan ComfyUI.
providers-workflow = Workflow
providers-not-used = Belum dipakai untuk apa pun
providers-folder-saved = Folder disimpan.
providers-change-folder = Ganti folder model
providers-choose-folder = Pilih folder model
providers-change = Ganti
providers-not-set-up = Belum disiapkan
providers-folder-not-set-up = Menjalankan model dari folder di komputer ini · belum disiapkan
providers-menu = Menu penyedia: sunting, hapus
providers-remove = Hapus
providers-removed = Penyedia “{ $name }” dihapus.
providers-remove-with-models = Hapus penyedia ini? Model yang dipilih darinya tidak dipakai lagi.
providers-remove-ask = Hapus penyedia ini?
providers-remove-key = Hapus kunci
providers-key-removed = Kunci dihapus saat kamu menyimpan
providers-edit = Sunting penyedia
providers-keep-key = Biarkan kosong untuk mempertahankan kunci yang tersimpan.
providers-saved = Penyedia “{ $name }” disimpan.
providers-added = Penyedia “{ $name }” ditambahkan.
providers-add = Tambah penyedia
providers-about = Tempat AI berjalan: layanan di internet atau program di komputer ini. Di bawah masing-masing, untuk apa ia dipakai.

## Voices (views/voices.ts)

voices-stop = Hentikan { $name }
voices-try = Coba { $name }
voices-model-about = Membacakan pesan di komputer ini · { $size }
voices-default-of = Suara bawaan: { $name }
voices-menu = Menu suara: ganti nama, hapus
voices-rename = Ganti nama
voices-delete-ask = Hapus suara “{ $name }”? Karakter yang memakainya kembali membaca dengan suara bawaan.
voices-rename-title = Ganti nama suara
voices-name = Nama
voices-speed-value = { $speed }×
voices-speed = Kecepatan
voices-speed-about = Seberapa cepat balasan dibacakan, untuk semua suara
voices-make = Buat suara dari rekaman
voices-provider-failed = Tidak dapat memuat suara penyedia.
voices-provider-none = Penyedia tidak mencantumkan suara
voices-provider-own = Pesan dibacakan dengan suara milik penyedia.
voices-voices = Suara
voices-voices-about = Suara yang membacakan pesan. Karakter bisa punya suaranya sendiri di "Suara karakter".
voices-default = Suara bawaan
voices-voice-of = Suara { $name }
voices-back-default = Kembali ke suara bawaan
voices-name-title = { $name } · { $title }
voices-choose-character = Pilih karakter
voices-all-have = Setiap karakter sudah punya suara.
voices-set-for = Atur suara untuk karakter
voices-character = Karakter
voices-voice = Suara
voices-character-first = Pilih karakter dulu.
voices-characters = Suara karakter
voices-downloading = Mengunduh · { $size } · { $percent }%
voices-downloaded = Sudah diunduh · { $size }
voices-download-size = Unduhan { $size }
voices-action-of = { $action } { $name }
voices-language-downloaded = { $name } sudah diunduh
voices-built-in = Bawaan aplikasi
voices-languages = Bahasa yang dibacanya
voices-download = Unduh
voices-cancel = Batal
voices-delete = Hapus

## Advanced (views/advanced.ts)

advanced-context-size = Ukuran konteks (token)
advanced-context-hint = Kosongkan untuk 128.000
advanced-temperature = Temperatur
advanced-temperature-about = Lebih tinggi: balasan lebih mengejutkan. Dari 0 sampai 2
advanced-top-p = Top P
advanced-top-p-about = Lebih rendah: hanya kata yang paling mungkin. Dari 0 sampai 1
advanced-frequency = Penalti frekuensi
advanced-frequency-about = Lebih tinggi: lebih sedikit kata berulang. Dari −2 sampai 2
advanced-presence = Penalti kehadiran
advanced-presence-about = Lebih tinggi: lebih banyak topik baru. Dari −2 sampai 2
advanced-seed = Seed
advanced-seed-about = Angka yang sama memberi balasan yang sama lagi
advanced-from-to = Dari { $min } sampai { $max }
advanced-whole-from = Bilangan bulat mulai { $min }
advanced-whole = Bilangan bulat
advanced-number = Angka
advanced-sampling = Sampling
advanced-sampling-about = Untuk model chat. Biarkan nilai kosong untuk memakai bawaan penyedia. Disimpan sambil kamu mengetik.
advanced-describing = Mendeskripsikan… sisa { $count }
advanced-all-described = Semua karakter sudah dideskripsikan
advanced-not-described = { $count ->
   *[other] { $count } karakter
  } belum dideskripsikan
advanced-describe-cards = Deskripsikan karakter
advanced-describe-cost = Sekitar { $low } hingga { $high } token untuk { $count ->
   *[other] { $count } karakter
  }
advanced-failed = { $count ->
   *[other] { $count } gagal
  }: { $failure }. Tekan Deskripsikan karakter untuk mencoba lagi.
advanced-describe-again = Deskripsikan semua lagi
advanced-describe-again-stop = Hentikan
advanced-describe-again-about = Dengan model pembantu, menulis ulang deskripsi satu baris, ringkasan, dan tag setiap karakter, serta hal yang dipakai "Menurut kebutuhan" untuk menemukannya, sekitar 11.000 sampai 12.000 token per karakter. Yang Anda sunting sendiri tetap. Penyedia menagih per token.
advanced-no-characters = Tidak ada karakter untuk dideskripsikan
advanced-describe-again-far = { $done } dari { $all } sudah dideskripsikan lagi
advanced-describe-again-stopped = Dihentikan pada { $done } dari { $all } yang dideskripsikan lagi
advanced-describe-again-failed = { $count ->
   *[other] { $count } gagal dan tetap seperti semula
  }: { $failure }. Tekan Deskripsikan semua lagi untuk mencoba sekali lagi.
advanced-describe-about = Deskripsi satu baris, ringkasan, dan tag untuk masing-masing, ditulis oleh model pembantu
advanced-plain = Chat tanpa karakter
advanced-told-about = Sama di setiap obrolan tanpa karakter. Tulis { "{{date}}" } atau { "{{time}}" } dan AI mendapat tanggal hari ini atau jamnya
advanced-library = Pustaka
advanced-interview-about = Cara AI mengajukan pertanyaannya kepadamu
advanced-interview-tree = Pohon
advanced-interview-cloud = Awan
advanced-interview-hybrid = Campuran
advanced-data = Data
advanced-format-about = Format yang dipakai Ekspor untuk setiap kartu; sebagian besar aplikasi membuka SillyTavern V3
advanced-history-about = Versi sebelumnya dari setiap teks; hanya dalam format kartu milik Cardwave
advanced-helper = Model pembantu
advanced-the-helper = model pembantu

## Cardwave's CSS (views/css-reference.ts)

cssref-rail = Rel kiri
cssref-main = Layar di samping rel
cssref-crumbs = Jalur di bagian atas halaman
cssref-group = Kotak berisi baris, seperti di pengaturan
cssref-item = Baris dalam kotak
cssref-row = Baris dalam daftar
cssref-tile = Kartu di kisi pustaka
cssref-msg = Pesan dalam chat
cssref-bubble = Gelembung pesan
cssref-composer = Kolom pesan di bawah chat
cssref-dialog = Dialog
cssref-btn-primary = Tombol biru
cssref-switch = Sakelar
cssref-pill = Pil
cssref-notice = Pemberitahuan di kaki jendela
cssref-snippet-green = Aksen hijau
cssref-snippet-square = Gelembung persegi
cssref-snippet-larger = Teks lebih besar
cssref-snippet-wider = Dialog lebih lebar
cssref-snippet-tighter = Jarak lebih rapat
cssref-snippet-black = Tema gelap hitam
cssref-in-dark = { $light } · dalam gelap { $dark }
cssref-none = Tidak ada variabel dengan nama itu.
cssref-copy-of = Salin “{ $title }”
cssref-copied = Disalin.
cssref-copy = Salin
cssref-about-1 = Variabel dan nama kelas yang dapat dipakai CSS-mu sendiri. Setiap warna dan ukuran aplikasi adalah variabel di{ " " }
cssref-about-2 = , dengan nilai terang dan gelap.
cssref-variables = Variabel
cssref-search = Cari
cssref-find = Cari variabel
cssref-all = Seluruhnya { $count } variabel.
cssref-classes = Nama kelas
cssref-snippets = Cuplikan

## Tools the AI wrote (views/written-tools.ts)

written-about = { $what } · dibuat { $made }
written-about-in = { $what } · dibuat { $made } di { $chat }
written-used = { $count ->
    [0] belum dipakai
    [1] dipakai sekali
   *[other] dipakai { $count } kali
  }
written-none = Belum ada alat. Nyalakan “Biarkan AI menulis alat” di obrolan, dan yang ditulisnya tercantum di sini.
written-ask = Tanya sebelum alat baru berjalan
written-ask-about = Sekali per alat: Anda mengizinkannya saat pertama kali berjalan
written-in = { " " }di{ " " }
written-made = Dibuat { $made }
written-dot-used = { " " }· { $used }
written-switch-off = Matikan
written-switch-on = Nyalakan
written-intro = Alat kecil yang ditulis AI untuk dirinya di obrolan yang “Biarkan AI menulis alat”-nya menyala. Alat ini menyentuh file Anda hanya jika Anda izinkan, dan disimpan untuk obrolan berikutnya.
written-deleted = Alat “{ $name }” dihapus.
written-on = { $name } nyala
written-view-code = Lihat kode

## The coding team, shared by the chat and its pages (chat/coding.ts)

coding-quick = Cepat
coding-balanced = Seimbang
coding-thorough = Teliti
coding-custom = Khusus
coding-running = Berjalan
coding-done = Selesai
coding-failed = Gagal
coding-stopped = Dihentikan
coding-team-says-alone = { $name }: satu perencana, { $workers ->
    [1] satu pekerja
    [2] dua pekerja
   *[other] tiga pekerja
  }, tanpa auditor.
coding-team-says-tests = { $name }: satu perencana, { $workers ->
    [1] satu pekerja
    [2] dua pekerja
   *[other] tiga pekerja
  }, dan auditor yang menjalankan tes.
coding-team-says-steps = { $name }: satu perencana, { $workers ->
    [1] satu pekerja
    [2] dua pekerja
   *[other] tiga pekerja
  }, dan auditor yang memeriksa setiap langkah dan menjalankan tes.
coding-team-label = { $name } · { $workers ->
   *[other] { $workers } pekerja
  }
coding-team-label-auditor = { $name } · { $workers ->
   *[other] { $workers } pekerja
  }, auditor
coding-team-label-steps = { $name } · { $workers ->
   *[other] { $workers } pekerja
  }, auditor per langkah
coding-tests-pass = { $passed } dari { $total } tes lulus
coding-passed = Lulus
coding-problems = Ditemukan masalah

## Coding team (views/coding-team.ts)

team-audit-end = Di akhir
team-audit-each = Setelah setiap langkah
team-audit-never = Tidak pernah
team-change = Ganti
team-workers-of = { $model } · { $workers } sekaligus
team-worker-model = Model pekerja
team-change-worker = Ganti model pekerja
team-how-many = Berapa pekerja
team-none = Tidak ada
team-auditor-tests = { $model } · menjalankan tes
team-auditor-steps = { $model } · memeriksa setiap langkah
team-auditor-model = Model auditor
team-change-auditor = Ganti model auditor
team-when = Kapan auditor memeriksa
team-team = Tim
team-roles = Peran
team-planner-model = Model perencana
team-change-planner = Ganti model perencana
team-recent = Tugas terbaru
team-intro = AI yang bersama-sama menulis program untuk Anda di komputer ini, dimulai dari obrolan.
team-no-tasks = Belum ada tugas. Tugas dimulai di obrolan, dengan “+” di samping kolom pesan › Mulai tugas pemrograman.

## Trash (views/trash.ts)

trash-expressions = Ekspresi · tidak dimiliki karakter mana pun
trash-figure = Figur 3D · tidak dimiliki karakter mana pun
trash-chat-with = Chat dengan { $names }
trash-chat = Chat
trash-persona = Persona
trash-persona-used = Persona · dipakai di { $count ->
   *[other] { $count } chat
  }
trash-lorebook = Lorebook
trash-lorebook-used = Lorebook · dipakai di { $count ->
   *[other] { $count } chat
  }
trash-character = Karakter
trash-character-chats = Karakter · dengan { $count ->
   *[other] { $count } chat
  }
trash-empty = Sampah kosong.
trash-about = Yang dipindahkan ke sini disimpan selama { $days } hari, lalu dihapus selamanya.
trash-emptied = Sampah dikosongkan.
trash-empty-trash = Kosongkan Sampah
trash-delete-all-ask = Hapus { $count ->
    [1] 1 item ini
   *[other] semua { $count } item
  } selamanya?
trash-restored = “{ $title }” dipulihkan.
trash-deleted = “{ $title }” dihapus selamanya.
trash-deleted-at = Dipindahkan ke sini { $when }
trash-days-left = { $count ->
   *[other] sisa { $count } hari
  }
trash-restore = Pulihkan
trash-restore-chats = Mengembalikan karakter dan { $count ->
   *[other] { $count } chat-nya
  }
trash-delete-forever = Hapus selamanya
trash-delete-forever-ask = Hapus “{ $title }” selamanya? Ini tidak dapat dikembalikan.
trash-delete-forever-ask-chats = Hapus “{ $title }” dan { $count ->
   *[other] { $count } chat-nya
  } selamanya? Semuanya tidak dapat dikembalikan.

## About Cardwave (views/about.ts)

about-no-package = Tidak ada paket dengan nama itu.
about-no-notes = Versi ini tidak disertai catatan.
about-by = oleh { $by }
about-licence-of = Lisensi { $name }
about-licence = Lisensi
about-folder-failed = Folder tidak terbuka: { $reason }. Letaknya di { $where }.
about-open-folder = Buka folder
about-logs-where = di folder “logs” dalam folder data Cardwave, di komputer tempat Cardwave berjalan
about-logs = Log
about-logs-about = Apa yang dilakukan Cardwave dan crash yang terjadi, satu file per hari, disimpan 7 hari: untuk bantuan saat ada yang salah · { $where }
about-version = Versi { $version }
about-whats-new = Yang baru
about-packages = { $count } paket
about-open-source = Perangkat lunak sumber terbuka
about-search = Cari
about-find = Cari paket
about-version-built = Versi { $version } · { $built }
about-models = Model
about-figures = Figur dan animasi
about-voices = Suara
about-voice-donations = Suara sumbangan
about-voice-acted-by = Disuarakan oleh { $name }
about-voice-vctk = Penutur { $speaker } dari CSTR VCTK Corpus oleh Junichi Yamagishi, Christophe Veaux dan Kirsten MacDonald, University of Edinburgh; dibersihkan oleh Kyutai
about-voice-cml-tts = Penutur { $speaker } dari CML-TTS oleh Frederico S. Oliveira, Edresson Casanova, Arnaldo Candido Junior, Anderson S. Soares dan Arlindo R. Galvão Filho, dibacakan untuk LibriVox
about-voice-cml-tts-cleaned = Penutur { $speaker } dari CML-TTS oleh Frederico S. Oliveira, Edresson Casanova, Arnaldo Candido Junior, Anderson S. Soares dan Arlindo R. Galvão Filho, dibacakan untuk LibriVox; dibersihkan oleh Kyutai
about-lists = Daftar penyedia dan model

about-or = atau
about-and = dan
about-with = dengan

## Prompt preset (views/prompt-preset.ts)

prompt-new = Preset prompt baru
promptpage-system = Prompt sistem
prompt-system-about = Menggantikan prompt sistem kartu. Biarkan kosong untuk mempertahankan milik kartu.
promptpage-note = Catatan
prompt-note-about = AI membacanya sebelum setiap balasan; Anda tidak melihatnya di obrolan. Letaknya sejauh pesan yang diatur di bawah.
prompt-depth = Pesan ke belakang
prompt-intro = Petunjuk untuk AI. Pilih preset di panel samping obrolan untuk memakainya di sana.
prompt-depth-about = 1 menaruhnya tepat sebelum pesan terbaru, 4 empat pesan sebelumnya.
prompt-saved = Preset “{ $name }” disimpan.
prompt-gone = Preset prompt ini sudah dihapus. Kembali dan pilih yang lain.

## Profile (views/profile.ts)

profile-change-picture = Ganti gambar
profile-change = Ganti
profile-remove-picture = Hapus gambar
profile-remove = Hapus
profile-picture-changed = Gambar diganti.
profile-picture-removed = Gambar dihapus.
profile-your-picture = Gambarmu
profile-no-picture = Tanpa gambar: inisial Anda { $letter } yang ditampilkan
profile-change-name = Ganti nama
profile-this-computer = Akun komputer ini
profile-on-server = Akun di komputer ini
profile-account = Akun

## Server (views/server.ts)

server-copy = Salin
server-no-network = Komputer ini tidak terhubung ke jaringan. Hubungkan ke Wi-Fi atau kabel agar perangkat lain bisa masuk.
server-switch-on-about = Ponsel dan komputer lain di jaringan ini lalu dapat membuka Cardwave. Setiap akun masuk dengan kata sandinya.
server-switch-on = Nyalakan
server-network-about = Ponsel dan komputer lain membuka Cardwave di browser
server-other-devices = Perangkat lain
server-inside = Hanya perangkat di jaringan ini yang bisa menjangkaunya, kecuali Anda mengatur router agar yang lain bisa masuk.
server-add-account = Tambah akun
server-owner = Komputer ini · dapat menambah dan menghapus akun
server-more-of = Lainnya: { $name }
server-reset-password = Atur ulang kata sandi
server-delete-account = Hapus akun
server-deleted = Akun “{ $name }” dihapus.
server-delete-ask = Hapus akun ini beserta karakter, obrolan, dan pengaturannya? Ini tidak bisa dibatalkan.
server-reset-title = Atur ulang kata sandi { $name }
server-reset-about = Akun itu masuk dengan yang baru, dan dikeluarkan di mana pun akun itu sedang masuk.
server-new-password = Kata sandi baru
server-reset-done = Kata sandi { $name } diatur ulang.
server-reset = Atur ulang
server-accounts = Akun

## Character generator (views/generator.ts)

gen-gender-woman = Perempuan
gen-gender-man = Laki-laki
gen-gender-non-binary = Nonbiner
gen-being-human = Manusia
gen-being-not-human = Bukan manusia
gen-age-20s = 20-an
gen-age-30s = 30-an
gen-age-40s = 40-an
gen-age-50s-and-older = 50-an ke atas
gen-build-slim = Ramping
gen-build-average = Sedang
gen-build-athletic = Atletis
gen-build-strong = Kekar
gen-hair-short = Pendek
gen-hair-medium = Sedang
gen-hair-long = Panjang
gen-colour-black = Hitam
gen-colour-brown = Cokelat
gen-colour-blonde = Pirang
gen-colour-red = Merah
gen-colour-grey = Abu-abu
gen-colour-white = Putih
gen-relation-stranger = Orang asing
gen-relation-friend = Teman
gen-relation-partner = Pasangan
gen-relation-rival = Rival
gen-relation-colleague = Rekan kerja
gen-relation-mentor = Mentor
gen-shy = Pemalu
gen-outgoing = Supel
gen-gentle = Lembut
gen-harsh = Keras
gen-serious = Serius
gen-playful = Jenaka
gen-cautious = Hati-hati
gen-bold = Berani
gen-random = Acak
gen-slider = { $low } sampai { $high }
gen-looks = Penampilan
gen-gender = Gender
gen-being = Manusia atau bukan
gen-any = Apa saja
gen-age = Usia
gen-build = Postur
gen-hair = Rambut
gen-hair-colour = Warna rambut
gen-personality = Kepribadian
gen-relates = Siapa karakter ini bagimu
gen-make = Buat karakternya
gen-what = Pilih beberapa sifat; AI menulis pesan pertama karakter dan cara bicaranya.
interview-goes-to = Jawabanmu dikirim ke { $provider } untuk menulis karakternya.
interview-stays = Jawabanmu tetap di komputer ini.
interview-own-words = Atau tambahkan kata-katamu sendiri
interview-in-own-words = Dengan kata-katamu sendiri
interview-your-answer = Jawabanmu
interview-pick-one = Pilih satu
interview-pick-two = Pilih satu atau dua
interview-pick-three = Pilih sampai tiga
interview-pick-many = Pilih sebanyak yang cocok
interview-few-words = Beberapa kata sudah cukup
interview-wanted-hint = Apa yang kurang bersama orang lain, atau dengan karakter yang pernah kamu coba?
interview-needs-hint = Untuk waktumu bersama karakter ini, bukan untuk sisa hidupmu
interview-next = Berikutnya
interview-skip = Lewati
interview-dont-know = Aku tidak tahu
interview-back = Kembali
interview-just-make-it = Buat saja
interview-more = Jenis lainnya
interview-writing-next = Menulis pertanyaan berikutnya
interview-try-again = Coba lagi
interview-failed-where = Jika terus gagal, periksa penyedia dan model di Pengaturan › Penyedia.
gen-stop = Hentikan
gen-writing = Menulis karakternya…
interview-understood = Inilah yang aku pahami.
interview-you-said = kamu bilang: “{ $words }”
interview-own-guess = tebakan AI sendiri
interview-keep = Simpan
interview-change = Ubah
interview-remove = Hapus
interview-not-it = Bukan itu
interview-not-it-off = Baris ini tidak bersandar pada satu pertanyaan yang bisa ditanyakan lagi
interview-own-sentence = Kalimatmu sendiri
interview-private-line = Ada yang kamu inginkan di dunia karaktermu, atau yang sama sekali tidak?
interview-private-sub = Romansa, kekerasan, umpatan, dan lainnya · opsional
interview-make = Buat karakternya
interview-make-after = Setelahnya kamu bisa mengubahnya di halamannya.
interview-skip-all = Lewati semua
interview-private-hint = Sebagian orang menginginkan hal-hal ini di dunia karakternya, sebagian tidak. Jawabanmu tetap bersama karakter ini di komputermu dan hanya dikirim ke AI yang menulis karakter itu.
interview-private-free = Hal lain yang kamu inginkan, atau tidak pernah inginkan
interview-yes = Ya
interview-no = Tidak
interview-maybe = Mungkin
interview-fantasy-only = Hanya fantasi
interview-never = Tidak pernah
interview-try-another = Coba model lain
interview-without-topic = Tulis tanpa topik itu
interview-model-provider = { $model } · { $provider }
interview-reading = Membaca jawabanmu
interview-persona-title = Tambahkan yang kamu katakan tentang dirimu ke personamu?
interview-persona-field = Persona
interview-persona-in-use = { $persona } · dipakai
interview-persona-new = Persona baru
interview-persona-add = Tambah
interview-persona-not-now = Jangan sekarang
interview-persona-added = Ditambahkan ke “{ $persona }”.
interview-persona-you = Kamu
