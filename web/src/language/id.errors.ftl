### Kata-kata antarmuka dalam bahasa Indonesia: jawaban galat server, satu untuk tiap kode api/generated/Code.ts (errors.ts),
### `error-<kode>` dengan "-" untuk "_"; diterjemahkan dari en.errors.ftl, daftar katanya di kepala id.ftl.

## Permintaan, sebagaimana diterima server

error-request-failed = Itu tidak dapat dilakukan. Coba lagi.
error-internal = Terjadi kesalahan di Cardwave. Coba lagi.
error-bad-request = Cardwave tidak dapat membaca permintaan itu. Muat ulang halaman dan coba lagi.
error-forbidden = Itu tidak diizinkan.
error-no-such-path = Cardwave tidak punya halaman seperti itu. Muat ulang halaman dan coba lagi.
error-method-not-allowed = Cardwave tidak melakukan itu di sini. Muat ulang halaman dan coba lagi.
error-too-large = Itu terlalu besar. Coba file yang lebih kecil.
error-unsupported-type = Cardwave tidak menerima jenis berkas itu di sini.

## Kata sandi dan akun

error-locked = Cardwave terkunci sampai kata sandinya dimasukkan.
error-sign-in = Masuk dulu.
error-password-wrong = Kata sandi salah.
error-password-needed = Kata sandi diperlukan.
error-current-password-needed = Kata sandi saat ini diperlukan.
error-backup-password-needed = Cadangan ini memerlukan kata sandinya.
error-too-many-tries = Terlalu banyak kata sandi salah. Coba lagi dalam { $seconds } detik.
error-owner-only = Hanya akun komputer ini yang dapat { $action ->
    [use_its_files] memakai berkasnya
    [use_its_folders] memakai foldernya
    [choose_its_models] memilih modelnya
    [lock_Cardwave] mengunci Cardwave
   *[other] melakukan itu
}.
error-no-password-to-lock = Cardwave hanya dapat dikunci selama kata sandi aktif.
error-remote-sign-in-off = Akun ini tidak dapat masuk dari perangkat lain. Aktifkan di Akun › Berbagi.
error-no-password-on = Tidak ada kata sandi yang aktif.
error-no-password-set = Belum ada kata sandi untuk akun ini.
error-password-kept = Sebuah akun di komputer ini menyimpan kata sandi: akun itu masuk dengannya.
error-account-busy = Cardwave masih bekerja untuk akun ini: balasan, gambar, tugas pemrograman, karakter baru, membaca karakter, atau ingatan sebuah chat; coba lagi setelah selesai.
error-restore-busy = Cardwave masih bekerja: balasan, gambar, tugas pemrograman, karakter baru, membaca karakter, atau ingatan sebuah chat; coba lagi setelah selesai.
error-backup-needs-password = Cadangan memerlukan kata sandi.

## Yang diminta

error-not-found = Tidak ada { $what ->
    [account] akun
    [asset] berkas di dalam kartu
    [attachment] lampiran
    [card] kartu
    [card_version] versi kartu
    [chat] chat
    [chat_character] karakter di dalam chat
    [checkpoint] checkpoint
    [deleted_message] pesan terhapus
    [document] dokumen
    [expression] ekspresi
    [expression_pack] set ekspresi
    [figure] figur
    [kind_of_model] jenis model
    [language] bahasa
    [lorebook] lorebook
    [lorebook_entry] entri lorebook
    [memory] memori
    [message] pesan
    [model] model
    [persona] persona
    [picture] gambar
    [preset] preset
    [prompt_preset] preset prompt
    [provider] penyedia
    [question] pertanyaan
    [task] tugas
    [tool] alat
    [user] akun
    [voice] suara
   *[other] yang
} seperti itu. Mungkin sudah dihapus.
error-chat-busy = Balasan sedang ditulis di chat ini; hentikan dulu.
error-no-provider = { $what ->
    [chat_model] Belum ada model chat yang dipilih. Pilih satu di Pengaturan › Model.
   *[other] Belum ada penyedia yang disiapkan. Tambahkan satu di Pengaturan › Penyedia.
}
error-provider-refused = { $refusal ->
    [key] Penyedia tidak menerima kuncinya: periksa di Pengaturan › Penyedia.
    [paid] Penyedia meminta pembayaran untuk ini: tambah kredit, atau pilih model yang termasuk dalam paketmu.
    [busy] Kredit penyedia habis atau sedang sibuk: coba lagi nanti.
    [down] Penyedia tidak menjawab: coba lagi nanti.
    [fault] Penyedia mengalami gangguan di pihaknya: { $reason } Coba lagi nanti.
    [no_model] Penyedia tidak lagi menawarkan model ini: pilih yang lain di Pengaturan › Model.
    [too_long] Model dikirimi lebih banyak daripada yang bisa dibacanya sekaligus: pilih model yang membaca lebih banyak di Pengaturan › Model.
   *[other] Penyedia menolak ini: { $reason }
}
error-model-declined = { $model } menolak menulis ini. Ubah pesannya, atau pilih model lain.
error-model-sees-no-pictures = { $model } tidak dapat melihat gambar, jadi tidak menerima gambar. Pilih model yang bisa melihat gambar untuk mengirimnya.
error-card-trashed = Karakter ada di Sampah; pulihkan dulu.
error-lorebook-trashed = Lorebook “{ $name }” ada di Sampah; pulihkan untuk memakainya.
error-own-lorebook-flags = Lorebook milik sebuah karakter ikut bersama karakternya: lorebook itu tidak bisa diberi bintang, diarsipkan, dipindahkan ke Sampah, atau dipakai di setiap chat secara terpisah.

## Folder dan berkas

error-no-such-folder = Tidak ada folder { $folder } di komputer ini.
error-folder-not-chosen = Pilih folder dulu.
error-drive-root-to-watch = Akar sebuah drive berisi terlalu banyak untuk dipantau; pilih folder di dalamnya.
error-drive-root-for-model = Akar sebuah drive berisi terlalu banyak untuk diberikan ke AI; pilih folder di dalamnya.
error-data-folder = Folder itu berisi data Cardwave sendiri, atau ada di dalamnya; pilih yang lain.
error-commands-windows-only = Perintah hanya dijalankan di Windows.
error-recycle-bin-windows-only = Berkas dipindahkan ke Keranjang Sampah hanya di Windows.
error-files-tool-off = Nyalakan Berkas di Pengaturan › Alat dulu: tim membaca dan menulis folder tugas dengannya.

## Gambar, balasan, dan suara

error-picture-words-missing = Katakan dulu apa yang ditunjukkan gambar.
error-picture-words-too-long = Yang ditunjukkan gambar lebih panjang dari { $most } karakter.
error-picture-needs-words = Katakan apa yang ditunjukkan gambar.
error-goal-missing = Katakan apa yang harus dikerjakan tim.
error-dictation-not-set-up = Dikte belum disiapkan: Pengaturan › Model › Dikte.
error-direction-without-go-on = Petunjuk hanya berlaku dengan Lanjutkan.
error-again-or-go-on = Balasan ditulis ulang atau dilanjutkan, tidak keduanya.
error-again-not-reply = Hanya balasan karakter yang dapat ditulis ulang.
error-no-reply-to-write-again = Chat ini tidak punya balasan untuk ditulis ulang.
error-no-text = AI tidak mengirim teks. Coba lagi.
error-worker-no-answer = Model pembantu tidak memberi jawaban.
error-unknown-voice = Tidak ada suara “{ $voice }”.
error-nothing-to-read = Tidak ada yang bisa dibacakan.
error-voice-not-downloaded = Suara itu belum diunduh.
error-voice-failed = Membacakan gagal. Coba lagi.
error-stopping = Cardwave sedang berhenti.
error-download-failed = Unduhan gagal. Periksa koneksi dan coba lagi.
error-search-model-failed = Model pencarian gagal. Cardwave mencobanya lagi sebentar lagi.
error-models-not-listed = Model penyedia tidak dapat didaftar. Periksa alamat dan kuncinya, lalu coba lagi.
error-file-not-imported = File tidak dapat dibaca: Cardwave tidak mengenal formatnya.
error-describing-failed = Model pembantu tidak bisa mendeskripsikan karakter itu.

## Jenis kegagalan sebuah area dikelompokkan: tiap jenis memilih katanya menurut `what` (atau `whose`), hal yang dibicarakan

error-needed = { $what ->
    [persona_name] Persona memerlukan nama.
    [account_name] Akun memerlukan nama.
    [card_title] Karakter perlu judul.
    [character_name] Karakter memerlukan nama.
    [chat_character] Chat memerlukan karakter.
    [chat_title] Judul chat memerlukan kata-kata.
    [entry_name] Entri memerlukan nama.
    [expression_files] Pilih berkas zip (folder yang dikemas) atau gambar-gambar sebuah set.
    [language] Bahasanya tidak ada.
    [lorebook_name] Lorebook memerlukan nama.
    [memory_text] Memori memerlukan teks.
    [message_to_improve] Tidak ada pesan untuk diperbaiki.
    [model_name] Model harus diberi nama.
    [models_folder] Pilih folder model dulu.
    [password] Kata sandi tidak boleh kosong.
    [preset_name] Preset memerlukan nama.
    [rewrite_given] Ada yang diperlukan tetapi tidak ada. Coba lagi.
    [summary] Ringkasan memerlukan kata-kata.
    [text_to_change] Tidak ada teks untuk diubah.
    [text_to_read] Tidak ada yang bisa dibacakan.
    [voice_name] Suara memerlukan nama.
   *[other] Ada yang diperlukan tetapi tidak ada. Coba lagi.
}
error-too-long = { $what ->
    [account_name] Nama akun paling banyak { $name_limit } karakter.
    [chat_title] Judul chat paling banyak { $title_limit } karakter.
    [document] { $name } terlalu panjang: dokumen paling banyak 2.000.000 karakter.
    [entry_name] Nama entri paling banyak { $max_name } karakter.
    [field_name] Nama kolom terdiri dari 1 sampai { $max_field } tanda.
    [lorebook_name] Nama lorebook paling banyak { $max_name } karakter.
    [memory_text] Memori paling banyak { $text_limit } karakter.
    [persona_name] Nama persona paling banyak { $max_name } huruf.
    [provider_name] Nama paling banyak { $name_limit } karakter.
    [unsaved_text] Teks yang belum disimpan paling banyak { $max_text } tanda.
    [voice_name] Nama suara paling banyak { $name_most } karakter.
   *[other] Itu lebih panjang dari { $most } karakter.
}
error-out-of-range = { $what ->
    [authors_note_depth] Catatan diletakkan satu pesan ke belakang atau lebih.
    [companion_size] Ukuran pendamping dari { $start } sampai { $end } persen tinggi layar.
    [context_size] Ukuran konteks harus minimal 512 token.
    [entry_chance] Peluang entri paling banyak 100 persen.
    [provider_setting] { $name } harus dari { $min } sampai { $max }.
    [reply_length] Panjang balasan harus dari 1 sampai { $most_reply_length } token.
    [slider] Penggeser bernilai dari 0 sampai 100.
    [talk_pause] Jeda harus dari 0 sampai { $most_talk_pause } detik.
    [talk_replies] Balasan berturut-turut harus dari 1 sampai { $most_talk_replies }.
    [talkativeness] Keaktifan bicara dari 0 sampai 100.
    [voice_speed] Kecepatan dari { $start }% sampai { $end }%.
   *[other] Itu harus dari { $least } sampai { $most }.
}
error-taken = { $what ->
    [card_in_library] Sudah ada di pustakamu.
    [account_name] Akun lain sudah bernama “{ $name }”.
    [card_language] Kartu sudah dalam bahasa { $name }.
    [chat_character] { $name } sudah ada di chat ini.
    [chat_character_twice] { $name } ada dua kali di chat ini.
    [lorebook_same_name] Kartu kini sudah punya lorebook atau entri dengan nama yang sama.
    [model_file] { $name } sudah ada di folder.
    [preset_name] Preset lain sudah bernama “{ $name }”.
    [tool_name] Alat bernama { $name } sudah ada; pilih nama lain.
   *[other] Itu sudah ada.
}
error-in-trash = { $what ->
    [card] Karakter ada di Sampah; pulihkan dulu.
    [card_to_chat] Karakter ada di Sampah; pulihkan karakter untuk chat lagi.
    [chat] Chat ada di Sampah; pulihkan dulu.
    [chat_card] Karakternya, “{ $title }”, ada di Sampah; pulihkan karakter dulu.
    [lorebook] Lorebook “{ $name }” ada di Sampah; pulihkan dulu.
    [lorebook_to_use] Lorebook “{ $name }” ada di Sampah; pulihkan untuk memakainya.
    [persona_default] Persona di Sampah tidak dapat menjadi bawaan; pulihkan dulu.
    [persona_to_use] Persona “{ $name }” ada di Sampah; pulihkan untuk memakainya.
   *[other] Itu ada di Sampah; pulihkan dulu.
}
error-not-readable = { $what ->
    [damaged_key] Kuncinya rusak.
    [json] Berkas ini bukan JSON yang sah.
    [lorebook] Berkas ini tidak berisi lorebook.
    [lorebook_not_card] Berkas ini kartu karakter, bukan lorebook.
    [account_picture] Gambar ini bukan PNG atau JPEG yang dapat dibaca dengan sisi paling banyak 4.096 piksel.
    [attachment_picture] Gambar berupa berkas PNG, JPEG, atau WebP.
    [backup] Berkas ini bukan cadangan Cardwave.
    [backup_damaged] Cadangan ini rusak.
    [backup_newer] Cadangan ini dibuat oleh Cardwave yang lebih baru. Perbarui Cardwave untuk memulihkannya.
    [backup_key] Cadangan ini rusak: kuncinya tidak dapat dibaca.
    [base64] Itu bukan base64.
    [base64_file] { $name } bukan base64.
    [card_defined_twice] File ini bukan kartu karakter yang dapat dibaca Cardwave. Ekspor lagi dari aplikasi asalnya.
    [card_file_name] Sebuah nama berkas di dalam kartu tidak dapat dipakai.
    [card_reference] Itu tidak menunjuk bagian mana pun dari kartu.
    [ccv4_version] Kartu ini dibuat oleh Cardwave yang lebih baru. Perbarui Cardwave untuk membukanya.
    [comfyui_address] Alamat ComfyUI tidak dapat dibaca.
    [comfyui_answer] Jawaban ComfyUI tidak dapat dibaca.
    [dictation_recording] Rekaman tidak dapat dibaca. Rekam lagi.
    [document_text] { $name } tidak berisi teks yang dapat dibaca.
    [document_type] Dokumen berupa berkas .txt, .md, .pdf, atau .docx.
    [downloaded_model] Berkas yang diunduh bukan model itu.
    [expression_pack] Tidak ada gambarnya yang dinamai menurut suasana hati dalam bahasa Inggris, seperti joy.png atau anger.png (PNG, JPEG, WebP, atau GIF).
    [figure_file] { $file_name } bukan berkas jenis itu.
    [figure_still] Gambar diam figur bukan PNG berukuran paling besar 4 MB.
    [figure_type] Figur 3D berupa berkas VRM, GLB, atau FBX.
    [folder_read] Folder tidak dapat dibaca.
    [format_version] File ini bukan kartu karakter yang dapat dibaca Cardwave. Ekspor lagi dari aplikasi asalnya.
    [image_model_answer] Jawaban model gambar tidak dapat dibaca.
    [image_model_picture] Gambar dari model gambar tidak dapat dibaca.
    [key_characters] Kunci berisi karakter yang tidak boleh ada di kunci. Salin lagi dari situs penyedia.
    [lorebook_empty] Lorebook kosong.
    [lorebook_entries] Lorebook tidak punya entri.
    [lorebook_file] Lorebook tidak dapat dibaca.
    [lorebook_named] Lorebook “{ $name }” tidak dapat dibaca.
    [lorebook_named_empty] Lorebook “{ $name }” kosong.
    [models_dev_list] Daftar model tidak dapat dibaca.
    [models_list_answer] Alamat itu menjawab, tetapi bukan dengan daftar model.
    [models_list_missing] Daftar model tidak datang.
    [name_characters] Nama berisi karakter yang tidak boleh ada di nama.
    [no_lorebook] Ini bukan lorebook.
    [pdf] PDF tidak dapat dibaca.
    [picture] Gambar ini bukan PNG, JPEG, atau WebP.
    [picture_server_answer] Jawaban server gambar tidak dapat dibaca.
    [picture_unreadable] Gambar tidak dapat dibaca.
    [png] Bukan berkas PNG.
    [no_card] File ini tidak berisi kartu karakter.
    [png_damaged] PNG ini rusak.
    [charx] Cardwave belum dapat mengimpor file kartu CHARX. Ekspor kartu sebagai PNG atau JSON.
    [provider_address] Alamat harus berupa alamat web biasa seperti https://api.openai.com/v1.
    [provider_website] Tuliskan situs web penyedia sebagai nama seperti example.com.
    [recording_format] Format rekaman tidak dapat dibaca.
    [recording_pcm] Rekaman tidak dapat dibaca. Rekam lagi.
    [recording_rate] Laju rekaman tidak dapat dibaca.
    [recording_short] Rekaman terlalu pendek: diperlukan minimal { $shortest } detik.
    [recording_silent] Rekaman tidak bersuara.
    [recording_wav] Rekaman ini bukan berkas WAV.
    [sillytavern_base64] File ini bukan kartu karakter yang dapat dibaca Cardwave. Ekspor lagi dari aplikasi asalnya.
    [sillytavern_empty] Kartu kosong.
    [sillytavern_file] Kartu SillyTavern di berkas ini tidak dapat dibaca.
    [sillytavern_json] File ini bukan kartu karakter yang dapat dibaca Cardwave. Ekspor lagi dari aplikasi asalnya.
    [sillytavern_object] File ini bukan kartu karakter yang dapat dibaca Cardwave. Ekspor lagi dari aplikasi asalnya.
    [sillytavern_png] Kartu SillyTavern di PNG ini tidak dapat dibaca.
    [spec_version] File ini bukan kartu karakter yang dapat dibaca Cardwave. Ekspor lagi dari aplikasi asalnya.
    [spec_version_form] File ini bukan kartu karakter yang dapat dibaca Cardwave. Ekspor lagi dari aplikasi asalnya.
    [toml] File ini bukan kartu karakter yang dapat dibaca Cardwave. Ekspor lagi dari aplikasi asalnya.
    [word_file] Berkas Word tidak dapat dibaca.
    [word_text] Berkas Word tidak berisi teks.
    [workflow] Workflow “{ $name }” tidak dapat dibaca.
    [workflow_api_form] Workflow disimpan dalam bentuk untuk API: simpan di ComfyUI sebagai workflow.
    [workflow_broken] Workflow tidak dapat dibaca.
    [workflow_fields] Node workflow “{ $kind }” punya kolom yang tidak dapat dibaca Cardwave.
    [workflow_no_node] Workflow tidak punya node yang dapat dijalankan ComfyUI ini.
    [workflow_node] Node workflow “{ $class }” tidak dimiliki ComfyUI ini.
    [zip] { $name } tidak dapat dibaca sebagai zip.
   *[other] Itu tidak dapat dibaca.
}
error-too-big = { $what ->
    [card_for_worker] Karakter terlalu panjang untuk model pembantu; pilih model pembantu yang membaca lebih banyak.
    [card_for_chat] Karakter terlalu panjang untuk model chat, sehingga ia tidak akan menjadi dirinya sendiri; pilih model chat yang membaca lebih banyak, atau persingkat karakternya.
    [card_file] Berkas lebih besar dari { $most } MB.
    [checkpoint_folder] Folder terlalu besar untuk disalin sebelum setiap langkah.
    [expression_pack_size] Gambar-gambar { $name } terlalu besar.
    [expression_zip_files] { $name } berisi lebih dari { $max_entries } berkas.
    [figure] Figur 3D terlalu besar.
    [model_for_computer] { $name } terlalu besar untuk komputer ini.
    [models_dev_list] Daftar model terlalu panjang.
    [picture_pixels] Gambar terlalu besar ({ $wide } kali { $high } piksel).
    [reply] Balasan terpotong: terlalu panjang.
   *[other] Itu terlalu besar.
}
error-not-now = { $what ->
    [character_has_written] { $name } sudah menulis di chat ini dan tetap di dalamnya.
    [coding_folder_busy] Tugas pemrograman lain sedang berjalan di folder itu; tunggu, atau hentikan.
    [database_busy] Cardwave sedang sibuk; coba lagi.
    [download_cancelling] Unduhannya sedang dibatalkan; coba lagi sebentar lagi.
    [held_by_card] Sebuah karakter memakainya; lepaskan dulu dari karakter itu.
    [lorebook_used_elsewhere] Lorebook kini dipakai di tempat lain, jadi tetap di pustaka.
    [model_downloading] Model sedang diunduh.
    [model_replying] Model sedang membalas; hapus setelah balasannya selesai.
    [search_model_not_downloaded] Model pencarian belum diunduh.
    [task_running] Tugas masih berjalan; hentikan dulu.
   *[other] Itu tidak dapat dilakukan sekarang. Coba lagi sebentar lagi.
}
error-changed = { $what ->
    [lorebook_entry] Lorebook kini punya entri lain.
    [card_version] Kartu diubah sementara itu; kartu dibaca ulang.
    [tool_name] Alat lain kini bernama { $name }.
    [two_ways] { $reference } diubah dua kali sekaligus; coba lagi.
    [workflow] Workflow “{ $name }” diubah di ComfyUI: pilih lagi di Pengaturan › Penyedia.
   *[other] Itu diubah sementara itu; coba lagi.
}
error-not-possible = { $what ->
    [back_to_computer] Hanya pencarian dan suara yang dapat kembali ke komputer ini.
    [card_about_itself] Yang dikatakan kartu tentang dirinya tidak dapat diubah.
    [card_change] Itu tidak dapat diubah di kartu ini.
    [card_character] Kartu tidak punya karakter seperti itu.
    [card_character_change] Karakter kartu tidak dapat diubah.
    [card_language_beside] Kartu tidak dapat memuat { $name } di samping bahasa pertamanya.
    [card_lorebook] Kartu tidak membawa lorebook seperti itu.
    [card_lorebook_attached] Kartu tidak punya lorebook seperti itu yang terpasang.
    [card_mode] Kartu tidak punya mode seperti itu.
    [card_no_character] Kartu tidak punya karakter.
    [card_not_changed] Kartu tidak diubah.
    [card_part] Itu bukan bagian kartu yang dapat diubah.
    [card_takes_no] Kartu ini tidak menerima hal baru jenis itu.
    [card_takes_no_lorebook] Kartu tidak menerima lorebook.
    [character_change] Karakter itu tidak dapat diubah di kartu ini.
    [chat_character] Chat tidak punya karakter seperti itu.
    [chat_lore] Chat tidak punya lorebook atau entri lorebook seperti itu.
    [chat_lorebook] Chat tidak punya lorebook seperti itu.
    [chat_mode] Chat tidak punya mode seperti itu.
    [chat_no_character] Chat tidak punya karakter.
    [chat_without_character] Chat tanpa karakter tidak punya karakter.
    [chat_without_character_add] Chat tanpa karakter tidak menerima karakter.
    [checkpoint_put_back] { $path } tidak dapat dikembalikan.
    [comfyui_no_picture] ComfyUI tidak membuat gambar.
    [companion_not_answering] Pendamping tidak menjawab.
    [companion_not_shown] Pendamping tidak sedang tampil.
    [comfyui_queue] ComfyUI tidak memasukkan gambar ke antrean.
    [comfyui_said] ComfyUI berkata: { $said }
    [continue_no_text] Balasan tidak punya teks untuk dilanjutkan.
    [continue_only_reply] Hanya balasan karakter yang dapat dilanjutkan.
    [depth_note] Catatan pada kedalaman tertentu tidak dapat ditambahkan.
    [dictation_failed] Model dikte gagal.
    [dictation_model_load] Model dikte tidak dapat dimuat.
    [dictation_model_start] Model dikte tidak dapat dijalankan.
    [draft_made_by] Draf tidak dibuat oleh “{ $made }”.
    [edit_breaks_card] Kartu tidak akan terbaca setelah perubahan ini.
    [entry_change] Entri tidak dapat diubah seperti yang diminta di lorebook ini.
    [entry_taken_out] Ini bukan entri lorebook yang dikeluarkan.
    [export_no_character] Kartu tidak punya karakter untuk diekspor.
    [greeting] Itu bukan salah satu sapaan karakter ini.
    [improve_direction] Perbaiki memakai kata-kata di kolom; tidak menerima petunjuk.
    [key_refused] Kunci ditolak.
    [llama_server_start] Model pencarian tidak dapat dijalankan. Mulai ulang Cardwave lalu coba lagi.
    [local_address] Model komputer ini ditemukan lewat foldernya, di Pengaturan › Penyedia.
    [lorebook_change] Lorebook ini tidak dapat diubah.
    [lorebook_change_breaks] Lorebook tidak akan terbaca setelah perubahan ini.
    [lorebook_new_entry] Lorebook ini tidak menerima entri baru.
    [lorebook_put_in] Lorebook tidak dapat dimasukkan ke kartu ini.
    [lorebook_take_out] Lorebook tidak dapat dikeluarkan dari kartu ini.
    [message_not_in_chat] Pesan itu bukan bagian dari chat ini.
    [message_not_in_view] Pesan itu tidak terlihat.
    [model_remove] { $path } tidak dapat dihapus.
    [no_folder] Tidak ada folder seperti itu di komputer ini.
    [no_image_model] Belum ada model gambar yang disiapkan: siapkan satu di Pengaturan › Model › Gambar.
    [no_local_model] Tidak ada model “{ $id }” di folder itu.
    [no_local_models] Model lokal belum disiapkan.
    [no_recycle_bin] Tidak ada Keranjang Sampah untuk { $path }.
    [no_summary] Kartu belum punya ringkasan.
    [no_voice] Tidak ada suara seperti itu.
    [no_vulkan] Kartu grafis komputer ini tidak dapat menjalankan model. Pakai penyedia sebagai gantinya.
    [no_vulkan_dictation] Kartu grafis komputer ini tidak dapat menjalankan dikte.
    [prompt_change] Prompt karakter itu tidak dapat diubah di kartu ini.
    [recycle_bin_move] { $path } tidak dipindahkan ke Keranjang Sampah.
    [speaker_not_in_chat] Pembicara itu bukan bagian dari chat ini.
    [speaker_only_character] Hanya pesan karakter yang punya pembicara.
    [unknown_language] Itu bukan bahasa yang dikenal aplikasi ini.
    [version_lacks_character] Sebuah chat bersama karakter yang tidak ada di versi terbaru.
    [voice_runtime] Membaca keras butuh komponen Microsoft yang tidak ada: pasang Visual C++ Redistributable dari microsoft.com, lalu mulai ulang Cardwave.
    [workflow_no_text] Workflow “{ $name }” tidak punya kolom teks untuk kata-kata gambar.
    [workflow_use] Workflow “{ $name }” tidak dapat dipakai.
    [written_tools_full] Kamu bisa menyimpan paling banyak { $most_tools } alat; hapus dulu satu di Pengaturan › Alat buatan AI.
    [delete_not_in_trash] Hanya yang ada di Sampah dapat dihapus selamanya; pindahkan ke sana dulu.
   *[other] Itu tidak dapat dilakukan.
}
error-model-answer = { $what ->
    [no_greeting] AI tidak menulis sapaan.
    [background_answer] Jawaban model pembantu tidak dapat dipakai. Coba lagi, atau pilih model pembantu lain.
    [background_text] Jawaban model pembantu tidak dapat dipakai. Coba lagi, atau pilih model pembantu lain.
    [card_texts] Jawaban AI bukan teks-teks karakter.
    [classification] Jawaban model pembantu tidak dapat dipakai. Coba lagi, atau pilih model pembantu lain.
    [example_messages] AI tidak menulis contoh pesan.
    [no_example_message] AI menulis contoh pesan tanpa teksnya.
    [json] Jawaban AI tidak dalam bentuk yang diminta.
    [keywords] Jawaban model pembantu tidak dapat dipakai. Coba lagi, atau pilih model pembantu lain.
    [logline] Jawaban model pembantu tidak dapat dipakai. Coba lagi, atau pilih model pembantu lain.
    [no_chat_reply] Penyedia AI tidak mengirim balasan chat.
    [no_fitting_answer] AI tidak memberi jawaban yang dapat dipakai dalam tiga percobaan.
    [no_picture] Model gambar menjawab tanpa gambar.
    [no_plan] Perencana tidak membuat rencana.
    [no_text] AI tidak mengirim teks.
    [picture_address] Gambar dari model gambar ada di alamat yang tidak diambil.
    [picture_art] Gambar tidak dapat dibuat; coba lagi.
    [picture_field] Model pembantu tidak menemukan kolom untuk kata-kata gambar.
    [picture_server_no_picture] Server gambar menjawab tanpa gambar.
    [picture_words] Model pembantu tidak menulis kata-kata untuk gambar.
    [rating] Jawaban model pembantu tidak dapat dipakai. Coba lagi, atau pilih model pembantu lain.
    [reply_broke_off] Balasan terputus.
    [needs] Jawaban model pembantu tidak dapat dipakai. Coba lagi, atau pilih model pembantu lain.
    [rounds] Tim tidak menyelesaikan pekerjaannya dalam { $rounds } putaran.
    [search_left_out] Model pencarian melewatkan sebuah teks.
    [search_model] Jawaban model pencarian tidak dapat dibaca.
    [search_tokens] Token model pencarian tidak dapat dibaca.
    [title] Jawaban model pembantu tidak dapat dipakai. Coba lagi, atau pilih model pembantu lain.
    [too_many_tools] AI memanggil terlalu banyak alat.
    [worker_mode] Jawaban model pembantu tidak dapat dipakai. Coba lagi, atau pilih model pembantu lain.
    [worker_texts] Jawaban model pembantu tidak dapat dipakai. Coba lagi, atau pilih model pembantu lain.
    [server_reported] Penyedia AI melaporkan: { $reason }
   *[other] Jawaban AI tidak dapat dipakai.
}
error-timed-out = { $whose ->
    [comfyui] ComfyUI tidak membuat gambar tepat waktu.
    [llama_server] Model pencarian tidak siap tepat waktu. Coba lagi.
    [model] AI tidak menjawab tepat waktu. Coba lagi.
    [model_server] Penyedia AI tidak menjawab tepat waktu. Coba lagi.
    [search_model] Model pencarian tidak menjawab tepat waktu.
   *[other] Tidak ada jawaban tepat waktu.
}
error-unreachable = { $whose ->
    [comfyui] ComfyUI tidak dapat dihubungi.
    [image_model] Model gambar tidak dapat dihubungi.
    [model_download] Berkas model tidak dapat diunduh.
    [model_server] Penyedia AI tidak menjawab: coba lagi nanti, atau periksa koneksinya.
    [picture_address] Gambar tidak dapat diambil.
    [picture_server] Server gambar tidak dapat dihubungi.
    [provider_voices] Suara-suara penyedia tidak dapat dihubungi.
    [search_model] Model pencarian tidak menjawab.
    [provider_voice] Suara penyedia tidak dapat dihubungi.
    [provider_search_model] Model pencarian penyedia tidak dapat dihubungi.
   *[other] Tidak dapat dihubungi.
}
error-answered = { $whose ->
    [comfyui] ComfyUI menjawab { $status }.
    [model_server] Penyedia AI menjawab { $status }. Coba lagi nanti.
    [picture_server] Server gambar menjawab { $status }.
    [provider_voices] Suara-suara penyedia menjawab { $status }.
    [search_model] Model pencarian menjawab { $status }.
   *[other] Jawabannya { $status }.
}
error-answered-said = { $said ->
    [did_not_take_the_key] Penyedia tidak menerima kuncinya.
    [asks_for_a_key] Penyedia meminta kunci.
   *[other] Penyedia tidak punya daftar model di alamat ini.
}
