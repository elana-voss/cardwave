### Chữ trên giao diện bằng tiếng Việt, dịch từ tiếng Anh (en.ftl, tệp gốc) từng khóa một; bài kiểm tra cấu trúc
### (structure.test.ts) xác nhận ở đây có mọi khóa với cùng dạng.
### Bảng từ, một tên cho một thứ, trong mọi tệp vi.*.ftl:
###   Xưng hô: người dùng là «bạn» (viết thường giữa câu), như các ứng dụng phổ thông (Zalo, Facebook, Windows); «bạn»
###   không nói tuổi hay giới tính. Không dùng «anh», «chị», «em», «quý khách». Ứng dụng không xưng «tôi» hay «chúng tôi»
###   (nó là chương trình trên máy, không phải công ty): câu vô chủ ngữ hoặc gọi tên «Cardwave»; chỉ AI phỏng vấn, khi
###   tiếng Anh nói «me», xưng «tôi». Nút người dùng nói bằng lời của mình («Write for me», «I don't know»): «tôi». Nhân vật: gọi bằng tên hoặc «nhân vật», không «anh ấy», «cô ấy».
###   Cardwave, MCP, Claude Desktop, CSS, AI, token, tab: giữ nguyên. prompt = lời nhắc; preset = cấu hình mẫu; chat = trò chuyện
###   (một cuộc trò chuyện); message = tin nhắn; character = nhân vật; card = thẻ (thẻ nhân vật, tệp); figure = hình 3D;
###   persona = persona; lorebook = sổ bối cảnh; memory = ký ức (trang «Ký ức»); document = tài liệu; library = thư viện;
###   knowledge = kiến thức; account = tài khoản; provider = nhà cung cấp; model = mô hình; helper (model) = mô hình phụ trợ;
###   tool = công cụ; tab = tab (không bao giờ «thẻ»); tag = nhãn; model preset = cấu hình mẫu; prompt preset = cấu hình lời nhắc. Settings = Cài đặt; Advanced = Nâng cao; Trash = Thùng rác (của Cardwave);
###   Recycle Bin = Thùng rác của Windows; backup = bản sao lưu; back up = sao lưu; restore = khôi phục; Sharing = Chia sẻ.
###   companion = bạn đồng hành; voice = giọng nói; read aloud = đọc to; dictation = đọc chính tả; picture = ảnh (Images = Hình ảnh); download = tải xuống; Showcase = Trưng bày; Search Cardwave = Tìm trong Cardwave.
###   coding team = nhóm lập trình; planner = người lập kế hoạch; worker = người thực hiện; auditor = người kiểm tra; task = nhiệm vụ.
###   sign in = đăng nhập; sign out = đăng xuất; lock = khóa; import = nhập; export = xuất; password = mật khẩu.
###   interview = phỏng vấn; generator = trình tạo nhân vật; theme = chủ đề; first run = thiết lập ban đầu.
###   Tên thay cho người dùng không có persona (card-user-stand-in, cw_prompt::stand_in_user): Khách (một cái tên, không giới tính).
###   Số nhiều (Intl.PluralRules «vi»): chỉ một dạng, other; mọi select số nhiều chỉ có *[other] với { $count }.
###   Ngoặc kép “ ”, gạch ngang —, dấu ba chấm «…». Nhãn giữa câu viết thường (midSentence).

## The app

app-name = Cardwave

## The pages, as tabs, the rail and Search Cardwave name them (shell/pages.ts)

page-chats = Trò chuyện
page-characters = Nhân vật
page-lorebooks = Sổ bối cảnh
page-personas = Persona
page-memories = Ký ức
page-documents = Tài liệu
page-generator = Trình tạo nhân vật
page-interview = Cùng nhau tạo nhân vật
page-profile = Hồ sơ
page-server = Chia sẻ
page-settings = Cài đặt
page-providers = Nhà cung cấp
page-voices = Giọng nói
page-advanced = Nâng cao
page-css = CSS của Cardwave
page-written-tools = Công cụ do AI viết
page-coding-team = Nhóm lập trình
page-trash = Thùng rác
page-about = Giới thiệu Cardwave
page-coding-task = Nhiệm vụ lập trình
page-chat = Trò chuyện
page-new-card = Nhân vật mới
page-lorebook = Sổ bối cảnh
page-card = Nhân vật
page-prompt-preset = Cấu hình lời nhắc
page-first-run = Thiết lập Cardwave

## The places pages are under

place-library = Thư viện
place-knowledge = Kiến thức
place-account = Tài khoản
place-settings = Cài đặt
place-advanced = Cài đặt › Nâng cao

## The rail (shell/rail.ts)

rail-create = Tạo
rail-memories-tip = Ký ức: những gì AI nhớ từ các cuộc trò chuyện của bạn
rail-documents-tip = Tài liệu: các tệp AI đọc khi trả lời
rail-show-more = Hiện thêm { $count }
rail-open-menu = Mở thanh bên
rail-close-menu = Đóng thanh bên
rail-collapse = Thu gọn thanh bên
rail-expand = Mở rộng thanh bên
rail-account = Tài khoản
rail-account-named = Tài khoản: { $name }
rail-lock = Khóa

## Create's lines (shell/create.ts)

create-new-chat = Cuộc trò chuyện mới
create-plain-chat = Trò chuyện không có nhân vật
create-new-card = Nhân vật mới
create-from-picks = Trình tạo nhân vật
create-together = Cùng nhau tạo nhân vật
create-new-persona = Persona mới
create-new-lorebook = Sổ bối cảnh mới
create-import-card = Nhập thẻ
create-import-lorebook = Nhập sổ bối cảnh
create-new = Mới
create-import = Nhập

## The title bar and its tabs (shell/titlebar.ts)

tabs = Tab
tab-new = Tab mới
tab-new-keys = Tab mới (Ctrl+T)
tabs-all = Tất cả tab
tab-close = Đóng tab
window-minimize = Thu nhỏ
window-maximize = Phóng to
window-close = Đóng

## The view menu (shell/view-menu.ts, theme.ts)

view = Hiển thị
view-compact = Gọn
theme-system = Theo hệ thống
theme-light = Sáng
theme-dark = Tối
theme-downtempo = Downtempo
theme-outrun = Outrun
theme-retrowave = Retrowave
theme-neonwave-dark = Neon Wave tối
theme-neonwave-light = Neon Wave sáng

## Search Cardwave's button (shell/search-panel.ts)

search = Tìm trong Cardwave
search-keys = Tìm trong Cardwave (Ctrl+K)

## The labels of the settings, as their pages and Search Cardwave name them (setting-labels.ts)

label-settings-theme = Chủ đề
label-settings-chat-layout = Bố cục trò chuyện
label-settings-web-pictures = Hiện hình ảnh từ trang web khác
label-settings-app-language = Ngôn ngữ của ứng dụng
label-settings-language = Ngôn ngữ AI dùng để viết
label-settings-providers = Nhà cung cấp
label-settings-chat = Trò chuyện
label-settings-images = Hình ảnh
label-settings-voice = Giọng nói
label-settings-search = Tìm kiếm
label-settings-dictation = Đọc chính tả
label-settings-web = Web
label-settings-files = Tệp
label-settings-commands = Lệnh
label-settings-image-generation = Tạo hình ảnh
label-settings-app = Cardwave
label-settings-dice = Xúc xắc
label-settings-folder = Thư mục
label-settings-written = Công cụ do AI viết
label-settings-coding = Nhóm lập trình
label-settings-trash = Thùng rác
label-settings-backup = Sao lưu
label-settings-restore = Khôi phục
label-settings-cards-folder = Thư mục thẻ
label-settings-advanced = Nâng cao
label-settings-setup = Chạy lại thiết lập
label-settings-about = Giới thiệu Cardwave
label-providers-this-computer = Máy tính này
label-voices-model = Mô hình giọng nói
label-voices-speed = Tốc độ
label-voices-english = Tiếng Anh
label-advanced-background = Mô hình phụ trợ
label-advanced-told = Những gì AI được dặn
label-advanced-describe = Mô tả nhân vật đã nhập
label-advanced-described = Nhân vật đã mô tả
label-advanced-interview = Cùng nhau tạo nhân vật
label-advanced-format = Định dạng xuất
label-advanced-history = Kèm các phiên bản trước của mỗi văn bản
label-advanced-css = CSS của riêng bạn
label-coding-planner = Người lập kế hoạch
label-coding-workers = Người thực hiện
label-coding-auditor = Người kiểm tra
label-profile-name = Tên
label-profile-picture = Ảnh
label-profile-password = Mật khẩu
label-server-network = Truy cập được trong mạng gia đình
label-server-address = Địa chỉ
label-server-mcp = Cho ứng dụng AI trên máy tính này dùng Cardwave

layout-bubbles = Bong bóng
layout-plain = Văn bản thường

## Settings (views/settings.ts)

settings-appearance = Giao diện
settings-theme-about = Theo hệ thống, trừ khi bạn chọn một chủ đề
settings-layout-about = Tin nhắn dạng bong bóng hoặc dạng văn bản thường
settings-web-pictures-about = Các trang web đó có thể biết khi bạn mở cuộc trò chuyện.
settings-language = Ngôn ngữ
settings-data = Dữ liệu
settings-trash-about = { $count ->
   *[other] { $count } mục
  } · được dọn sau { $days } ngày
settings-open-trash = Mở Thùng rác
settings-open = Mở
settings-version = Phiên bản { $version } · giấy phép
settings-licences = Giấy phép
settings-advanced-about = Mô hình phụ trợ, thư viện, xuất, trò chuyện không có nhân vật, lấy mẫu, cấu hình mẫu, CSS của riêng bạn
settings-setup-about = Nhà cung cấp, mô hình và giọng nói, từng bước một
settings-providers-about = Địa chỉ và khóa của các dịch vụ chạy mô hình
settings-this-computer = máy tính này
settings-providers-named = Đã thiết lập: { $names }
settings-models = Mô hình
settings-the-chat-model = mô hình trò chuyện
settings-the-image-model = mô hình hình ảnh

## The account's tabs and accounts (shell/account-tabs.ts, settings/accounts.ts)

account-sections = Các mục tài khoản
account-switch = Chuyển tài khoản

account-password = Mật khẩu
account-switch-to = Chuyển sang { $name }
account-password-asked = Nhập mật khẩu của { $name }.
account-switch-button = Chuyển
account-add = Thêm tài khoản
account-add-about = Tài khoản của người khác trên máy tính này, với các cuộc trò chuyện và nhân vật riêng. Đăng nhập bằng mật khẩu của tài khoản đó, tại đây hoặc trên thiết bị khác.
account-name = Tên
account-added = Đã thêm tài khoản “{ $name }”.
account-add-button = Thêm
account-sign-out = Đăng xuất
account-none = Không có tài khoản để đăng nhập
account-none-about = Chưa có tài khoản nào đăng nhập được từ đây. Trên máy tính chạy Cardwave, hãy thêm một tài khoản trong Tài khoản › Chia sẻ.
account-this-computer = Tài khoản của máy tính này
account-choose = Chọn tài khoản của bạn
account-try-again = Thử lại
account-back = Quay lại
account-sign-in = Đăng nhập

## Backup and Restore (settings/backup.ts)

backup-saving = Đang lưu bản sao lưu.
backup-saving-to = Đang lưu bản sao lưu vào { $folder }.
backup-password = Mật khẩu
backup-repeat = Nhập lại mật khẩu
backup-encrypted = Bản sao lưu được mã hóa bằng mật khẩu này; muốn khôi phục cần có mật khẩu, tại đây hoặc trên máy tính khác.
backup-forgotten = Mật khẩu đã quên thì không lấy lại được, và không có nó thì không khôi phục được bản sao lưu.
backup-with-password = Sao lưu có mật khẩu
backup-differ = Hai mật khẩu không khớp.
backup-back-up = Lưu bản sao lưu
backup-no-file = Chưa chọn tệp
backup-choose-file = Chọn tệp
backup-its-password = Mật khẩu của bản sao lưu
backup-restoring = Khôi phục sẽ thay thế mọi thứ trong Cardwave: các cuộc trò chuyện, nhân vật, persona, sổ bối cảnh, ký ức và cài đặt. Không thể hoàn tác. Mật khẩu đặt ở đây vẫn giữ nguyên. Các tài khoản khác cũng bị thay thế.
backup-restored = Đã khôi phục bản sao lưu: mọi thứ trong Cardwave như lúc tạo bản sao lưu. Các thiết bị khác đăng nhập lại.
backup-file = Tệp
backup-restore-title = Khôi phục bản sao lưu
backup-choose-first = Hãy chọn tệp sao lưu trước.
backup-restore = Khôi phục bản sao lưu
backup-from-file = Từ tệp sao lưu
backup-about-own = Các cuộc trò chuyện, nhân vật và cài đặt trong một tệp, mã hóa bằng mật khẩu của bạn
backup-about-chosen = Các cuộc trò chuyện, nhân vật và cài đặt trong một tệp, mã hóa bằng mật khẩu bạn chọn

## The folder of cards (settings/card-folder.ts)

folder-watch = Tự động nhập thẻ mới
folder-watch-about = Tệp thẻ đặt vào thư mục sẽ tự vào thư viện của bạn
folder-recycle = Chuyển tệp đã nhập vào Thùng rác của Windows
folder-recycle-about = Khi tệp đã được nhập, nó vào Thùng rác

## The companion's line (library/companion-app.ts)

companion = Bạn đồng hành
# The companion window's name, which the system shows in its lists of windows.
companion-window = Bạn đồng hành Cardwave
companion-made = { $name } là bạn đồng hành của bạn.
companion-make = Chọn làm bạn đồng hành
companion-none = Chưa có bạn đồng hành. Mở menu “…” của một nhân vật và chọn “Chọn làm bạn đồng hành”.
companion-named = { $name } · Khởi động cùng ứng dụng
companion-figure = Hình 3D của bạn đồng hành
companion-figure-about = Hiện cho các nhân vật không có hình 3D riêng
companion-figure-woman = Nữ
companion-figure-man = Nam
companion-figure-robot = Robot
companion-size = Kích thước bạn đồng hành
companion-size-about = Chiều cao của hình, tính theo phần trăm chiều cao màn hình
companion-size-value = { $size }%

## Other programs, MCP (settings/mcp.ts)

mcp-ask-title = Cho ứng dụng AI trên máy tính này dùng Cardwave
mcp-ask = Các chương trình trên máy tính này, như Claude Desktop, có thể đọc nhân vật và cuộc trò chuyện của bạn, viết trong cuộc trò chuyện và dùng các công cụ đã bật trong Cài đặt › Công cụ. Những gì Cardwave sẽ hỏi bạn trước, chúng không làm được.
mcp-switch-on = Bật
mcp-about = Như Claude Desktop, qua MCP: chúng dùng nhân vật, cuộc trò chuyện và công cụ của bạn
mcp-copy-address = Sao chép địa chỉ MCP
mcp-copy = Sao chép
mcp-as-account = Với tư cách tài khoản
mcp-as-account-about = Những gì chúng có thể xem và làm
mcp-remove-named = Gỡ { $program }
mcp-removed = Đã gỡ “{ $program }”.
mcp-remove = Gỡ
mcp-connected = Đã kết nối
mcp-other-programs = Chương trình khác
mcp-only-here = Chỉ chương trình trên máy tính này mới kết nối được. Chương trình đã gỡ sẽ bị chặn cho đến khi bạn tắt rồi bật lại mục này.

## Your own CSS (settings/own-css.ts)

css-none = Không có
css-lines = { $count ->
   *[other] { $count } dòng
  }
css-about = { $lines } · thay đổi giao diện ứng dụng
css-hint = Được áp dụng sau bảng định kiểu của Cardwave, ngay khi bạn gõ. Lưu để giữ lại; Hủy để bỏ.
css-edit-own = Sửa CSS của riêng bạn
css-edit = Sửa

## The password (settings/password.ts)

password-forgotten = Mật khẩu đã quên không thể khôi phục, và cuộc trò chuyện cùng nhân vật của bạn mất theo. Hãy cất nó ở nơi an toàn.
password-on-title = Đặt mật khẩu
password-on-says = Cardwave sẽ hỏi nó khi mở. Không có nó, không ai mở được Cardwave hay đọc cuộc trò chuyện của bạn trên máy tính này.
password-on = Đặt mật khẩu
password-on-done = Đã đặt mật khẩu.
password-change-title = Đổi mật khẩu
password-change-says = Cardwave sẽ hỏi mật khẩu mới khi mở.
password-change = Đổi
password-change-done = Đã đổi mật khẩu.
password-off-title = Tắt mật khẩu
password-off-says = Cardwave sẽ mở mà không hỏi mật khẩu. Các cuộc trò chuyện và nhân vật của bạn vẫn được mã hóa.
password-off = Tắt
password-off-done = Đã tắt mật khẩu.
password-differ = Hai mật khẩu không khớp.
password-other-says = Từ đó trở đi bạn đăng nhập bằng mật khẩu mới.
password-other-forgotten = Nếu bạn quên, tài khoản của máy tính này có thể đặt lại mật khẩu, trong Chia sẻ.
password-current = Mật khẩu hiện tại
password-password = Mật khẩu
password-new = Mật khẩu mới
password-repeat = Nhập lại mật khẩu
password-asked-sign-in = Được hỏi khi bạn đăng nhập
password-is-on = Bật · được hỏi khi ứng dụng mở
password-is-off = Tắt · ai dùng máy tính này cũng mở được Cardwave
password-start-forgotten = Mật khẩu đã quên thì không lấy lại được.
password-open = Mở
password-locked-elsewhere = Cardwave đang bị khóa trên máy tính của nó. Nó sẽ mở ở đây khi được mở khóa ở đó.
password-back = Quay lại

## Words many pages use

common-use = Dùng
common-in-use = { " " }· đang dùng
common-more = Thêm
common-edit = Sửa
common-duplicate = Nhân bản
# The word a copy's name ends in, as in "Rig (copy)".
common-copy-word = bản sao
common-delete = Xóa
common-save = Lưu
common-cancel = Hủy
common-name = Tên

## Model presets and prompt presets (settings/presets.ts, settings/prompt-presets.ts)

preset-what = Cấu hình mẫu lưu một mô hình trò chuyện cùng các giá trị lấy mẫu của nó. Dùng sẽ chuyển sang cấu hình đó.
preset-temperature = nhiệt độ { $value }
preset-new = Cấu hình mẫu mới
preset-model-presets = Cấu hình mẫu mô hình
preset-using = Đang dùng “{ $name }”.
preset-added = Đã thêm cấu hình mẫu “{ $name }”.
preset-deleted = Đã xóa cấu hình mẫu “{ $name }”.
preset-saved = Đã lưu cấu hình mẫu “{ $name }”.
preset-delete-ask = Xóa cấu hình mẫu này?
preset-replace = Dùng mô hình và cài đặt hiện tại
preset-replace-hint = Mô hình trò chuyện, nhà cung cấp của nó và lấy mẫu trên trang này. Tắt: thiết lập sẵn giữ của riêng nó.
preset-keeps-hint = Cấu hình mẫu giữ mô hình trò chuyện trong Cài đặt › Mô hình, nhà cung cấp của nó và giá trị lấy mẫu trên trang này.
preset-name = Tên
preset-edit = Sửa cấu hình mẫu
prompt-presets = Cấu hình lời nhắc
prompt-system = Lời nhắc hệ thống
prompt-note = { $depth ->
   *[other] Ghi chú, cách { $depth } tin nhắn
}
prompt-system-note = { $depth ->
   *[other] Lời nhắc hệ thống · ghi chú, cách { $depth } tin nhắn
}
prompt-as-card = Theo nhân vật
prompt-default = Mặc định
prompt-default-name = “{ $name }” là lời nhắc riêng của nhân vật.

## Tools (settings/tools.ts, chat/tool-ask.ts)

tools-written-ask = { $count ->
    [0] Chưa có
   *[other] { $count } công cụ
  } · hỏi trước khi chạy công cụ mới
tools-written-free = { $count ->
    [0] Chưa có
   *[other] { $count } công cụ
  } · công cụ mới chạy mà không hỏi
tools-folder-first = Hãy chọn thư mục trước
tools-web = Tìm kiếm và đọc trang web
tools-files = Chỉ { $folder }
tools-ask-writes = Hỏi trước khi ghi
tools-ask-writes-says = Mỗi tệp được cho bạn xem trước khi ghi
tools-commands = Chạy trong { $folder }, tách khỏi phần còn lại của máy tính và internet
tools-ask-commands = Hỏi trước khi chạy
tools-ask-commands-says = Mỗi lệnh được cho bạn xem trước khi chạy
tools-pictures = Dùng mô hình hình ảnh
tools-pictures-first = Hãy thiết lập mô hình hình ảnh trước
tools-app = Dùng và thay đổi nhân vật, cuộc trò chuyện và cài đặt của bạn; mỗi thay đổi đều được hỏi trước
tools-dice = Cho AI tung xúc xắc; Cardwave tung nên kết quả công bằng.
tools-folder-example = C:\Users\ban\Documents\Shared
tools-folder-says = Tệp và lệnh chỉ chạm tới thư mục này và những gì bên trong, ngoài ra không gì khác.
tools-change-folder = Đổi thư mục
tools-change = Đổi
tools-choose = Chọn
tools-none-chosen = Chưa chọn
tools-title = Công cụ
tools-ask-new = { $name } muốn dùng một công cụ mới: { $what }
tools-ask-write = { $name } muốn ghi “{ $what }” vào thư mục của bạn:
tools-ask-read = { $name } muốn đọc trong thư mục của bạn:
tools-ask-install = { $name } muốn tải xuống và cài đặt các chương trình nó cần:
tools-ask-web = { $name } muốn dùng web:
tools-ask-app = { $name } muốn thay đổi Cardwave:
tools-ask-command = { $name } muốn chạy một lệnh trong thư mục của bạn:
tools-allow = Cho phép
tools-deny = Từ chối
tools-allow-writing = Cho phép ghi tệp trong cuộc trò chuyện này
tools-allow-commands = Cho phép chạy lệnh trong cuộc trò chuyện này

## Updates (settings/update.ts)

update-title = Kiểm tra cập nhật
update-available = Đã có Cardwave { $version }
update-you-have = Bạn đang dùng { $version }.
update-up-to-date = Cardwave đã là bản mới nhất ({ $version }).
update-connection-error = Không kiểm tra được cập nhật. Hãy kiểm tra kết nối mạng.
update-check-failed = Không kiểm tra được cập nhật: GitHub không trả về phiên bản mới nhất.
update-whats-new = Có gì mới
update-close = Đóng
update-ok = OK
update-download = Tải xuống
update-install = Cập nhật và khởi động lại
update-installing = Đang tải Cardwave { $version }…
update-auto = Tự động kiểm tra
update-auto-about = Tìm phiên bản mới khi khởi động và mỗi ngày một lần
update-check = Kiểm tra
update-checking = Đang kiểm tra…
update-about = Kiểm tra xem đã có phiên bản mới hơn của ứng dụng chưa.

## The breadcrumbs of a page under Settings

crumbs = Bạn đang ở đâu

## Providers (views/providers.ts)

providers-key-end = { $where } · khóa ····{ $end }
providers-key-saved = { $where } · đã lưu khóa
providers-no-key = { $where } · không có khóa
providers-thinking-cannot = { $provider } không tắt được chế độ suy nghĩ cho mô hình này
providers-thinking-off = Mô hình trả lời mà không suy nghĩ trước
providers-thinking-on = Mô hình suy nghĩ trước khi trả lời
providers-comfy-default = Mặc định của ComfyUI
providers-workflow-note = Quy trình này dùng mô hình và kích thước riêng, không dùng mô hình Hình ảnh.
providers-testing-model = Đang thử mô hình…
providers-thinking-of = { $label }: suy nghĩ
providers-thinking = Suy nghĩ
providers-testing-workflow = Đang thử quy trình…
providers-workflows-from = Từ các quy trình có trong ComfyUI
providers-pictures-by = Ảnh do “{ $name }” tạo.
providers-pictures-default = Ảnh do quy trình mặc định của ComfyUI tạo.
providers-workflow = Quy trình
providers-not-used = Chưa dùng cho việc gì
providers-folder-saved = Đã lưu thư mục.
providers-change-folder = Đổi thư mục mô hình
providers-choose-folder = Chọn thư mục mô hình
providers-change = Đổi
providers-not-set-up = Chưa thiết lập
providers-folder-not-set-up = Chạy mô hình từ một thư mục trên máy tính này · chưa thiết lập
providers-menu = Menu nhà cung cấp: sửa, gỡ
providers-remove = Gỡ
providers-removed = Đã gỡ nhà cung cấp “{ $name }”.
providers-remove-with-models = Gỡ nhà cung cấp này? Các mô hình đã chọn từ đó sẽ không còn được dùng.
providers-remove-ask = Gỡ nhà cung cấp này?
providers-remove-key = Gỡ khóa
providers-key-removed = Khóa sẽ được gỡ khi bạn lưu
providers-edit = Sửa nhà cung cấp
providers-keep-key = Để trống để giữ khóa đã lưu.
providers-saved = Đã lưu nhà cung cấp “{ $name }”.
providers-added = Đã thêm nhà cung cấp “{ $name }”.
providers-add = Thêm nhà cung cấp
providers-about = Nơi AI chạy: một dịch vụ trên internet hoặc một chương trình trên máy tính này. Dưới mỗi mục là việc nó được dùng.

## Voices (views/voices.ts)

voices-stop = Dừng { $name }
voices-try = Nghe thử { $name }
voices-model-about = Đọc to tin nhắn trên máy tính này · { $size }
voices-default-of = Giọng mặc định: { $name }
voices-menu = Menu giọng nói: đổi tên, xóa
voices-rename = Đổi tên
voices-delete-ask = Xoá giọng “{ $name }”? Các nhân vật dùng giọng này sẽ đọc lại bằng giọng mặc định.
voices-rename-title = Đổi tên giọng nói
voices-name = Tên
voices-speed-value = { $speed }×
voices-speed = Tốc độ
voices-speed-about = Tốc độ đọc câu trả lời, cho mọi giọng nói
voices-make = Tạo giọng nói từ bản ghi âm
voices-provider-failed = Không tải được giọng nói của nhà cung cấp.
voices-provider-none = Nhà cung cấp không liệt kê giọng nói nào
voices-provider-own = Tin nhắn được đọc bằng giọng riêng của nhà cung cấp.
voices-voices = Giọng nói
voices-voices-about = Giọng đọc to tin nhắn. Mỗi nhân vật có thể có giọng riêng trong "Giọng nói của nhân vật".
voices-default = Giọng mặc định
voices-voice-of = Giọng của { $name }
voices-back-default = Quay về giọng mặc định
voices-name-title = { $name } · { $title }
voices-choose-character = Chọn một nhân vật
voices-all-have = Mọi nhân vật đều đã có giọng nói.
voices-set-for = Đặt giọng nói cho một nhân vật
voices-character = Nhân vật
voices-voice = Giọng nói
voices-character-first = Hãy chọn nhân vật trước.
voices-characters = Giọng nói của nhân vật
voices-downloading = Đang tải · { $size } · { $percent }%
voices-downloaded = Đã tải · { $size }
voices-download-size = Tải { $size }
voices-action-of = { $action } { $name }
voices-language-downloaded = Đã tải { $name }
voices-built-in = Có sẵn
voices-languages = Ngôn ngữ nó đọc
voices-download = Tải xuống
voices-cancel = Hủy
voices-delete = Xóa

## Advanced (views/advanced.ts)

advanced-context-size = Kích thước ngữ cảnh (token)
advanced-context-hint = Để trống cho 128.000
advanced-temperature = Nhiệt độ
advanced-temperature-about = Cao hơn: câu trả lời bất ngờ hơn. Từ 0 đến 2
advanced-top-p = Top P
advanced-top-p-about = Thấp hơn: chỉ những từ khả dĩ nhất. Từ 0 đến 1
advanced-frequency = Phạt tần suất
advanced-frequency-about = Cao hơn: ít từ lặp lại hơn. Từ −2 đến 2
advanced-presence = Phạt hiện diện
advanced-presence-about = Cao hơn: nhiều chủ đề mới hơn. Từ −2 đến 2
advanced-seed = Seed
advanced-seed-about = Cùng một số cho lại cùng câu trả lời
advanced-from-to = Từ { $min } đến { $max }
advanced-whole-from = Một số nguyên từ { $min }
advanced-whole = Một số nguyên
advanced-number = Một số
advanced-sampling = Lấy mẫu
advanced-sampling-about = Cho mô hình trò chuyện. Để trống một giá trị để dùng mặc định của nhà cung cấp. Được lưu ngay khi bạn gõ.
advanced-describing = Đang mô tả… còn { $count }
advanced-all-described = Mọi nhân vật đều đã được mô tả
advanced-not-described = { $count ->
   *[other] { $count } nhân vật
  } chưa được mô tả
advanced-describe-cards = Mô tả nhân vật
advanced-describe-cost = Khoảng { $low } đến { $high } token cho { $count ->
   *[other] { $count } nhân vật
  }
advanced-failed = { $count ->
   *[other] { $count } thẻ thất bại
  }: { $failure }. Nhấn Mô tả nhân vật để thử lại.
advanced-describe-again = Mô tả lại tất cả
advanced-describe-again-stop = Dừng
advanced-describe-again-about = Dùng mô hình trợ giúp viết lại mô tả một dòng, tóm tắt, thẻ của mọi nhân vật và những gì "Theo nhu cầu" dùng để tìm họ, khoảng 11.000 đến 12.000 token mỗi nhân vật. Những gì bạn tự sửa vẫn giữ nguyên. Nhà cung cấp tính phí theo token.
advanced-no-characters = Không có nhân vật nào để mô tả
advanced-describe-again-far = Đã mô tả lại { $done } trên { $all }
advanced-describe-again-stopped = Đã dừng khi mô tả lại { $done } trên { $all }
advanced-describe-again-failed = { $count ->
   *[other] { $count } nhân vật thất bại và được giữ như cũ
  }: { $failure }. Nhấn Mô tả lại tất cả để thử thêm lần nữa.
advanced-describe-about = Mỗi nhân vật có một dòng mô tả, một bản tóm tắt và nhãn, do mô hình phụ trợ viết
advanced-plain = Trò chuyện không có nhân vật
advanced-told-about = Giống nhau ở mọi cuộc trò chuyện không có nhân vật. Viết { "{{date}}" } hoặc { "{{time}}" } và AI nhận ngày hôm nay hoặc giờ
advanced-library = Thư viện
advanced-interview-about = Cách AI đặt câu hỏi cho bạn
advanced-interview-tree = Cây
advanced-interview-cloud = Đám mây
advanced-interview-hybrid = Kết hợp
advanced-data = Dữ liệu
advanced-format-about = Định dạng mà Xuất ghi mọi thẻ; hầu hết ứng dụng mở được SillyTavern V3
advanced-history-about = Các phiên bản trước của mỗi văn bản; chỉ ở định dạng thẻ riêng của Cardwave
advanced-helper = Mô hình phụ trợ
advanced-the-helper = mô hình phụ trợ

## Cardwave's CSS (views/css-reference.ts)

cssref-rail = Thanh bên trái
cssref-main = Một màn hình cạnh thanh bên
cssref-crumbs = Đường dẫn ở đầu trang
cssref-group = Một khung gồm nhiều dòng, như trong cài đặt
cssref-item = Một dòng của khung
cssref-row = Một dòng của danh sách
cssref-tile = Một thẻ trong lưới của thư viện
cssref-msg = Một tin nhắn trong cuộc trò chuyện
cssref-bubble = Bong bóng của tin nhắn
cssref-composer = Ô nhập tin nhắn dưới cuộc trò chuyện
cssref-dialog = Một hộp thoại
cssref-btn-primary = Nút màu xanh
cssref-switch = Một công tắc
cssref-pill = Một nhãn tròn
cssref-notice = Thông báo ở chân cửa sổ
cssref-snippet-green = Điểm nhấn màu xanh lá
cssref-snippet-square = Bong bóng vuông
cssref-snippet-larger = Chữ lớn hơn
cssref-snippet-wider = Hộp thoại rộng hơn
cssref-snippet-tighter = Khoảng cách hẹp hơn
cssref-snippet-black = Chủ đề tối màu đen
cssref-in-dark = { $light } · khi tối { $dark }
cssref-none = Không có biến nào tên như vậy.
cssref-copy-of = Sao chép “{ $title }”
cssref-copied = Đã sao chép.
cssref-copy = Sao chép
cssref-about-1 = Các biến và tên lớp mà CSS của riêng bạn có thể dùng. Mọi màu sắc và kích thước của ứng dụng là một biến trong{ " " }
cssref-about-2 = , với một giá trị sáng và một giá trị tối.
cssref-variables = Biến
cssref-search = Tìm kiếm
cssref-find = Tìm một biến
cssref-all = Tổng cộng { $count } biến.
cssref-classes = Tên lớp
cssref-snippets = Đoạn mã mẫu

## Tools the AI wrote (views/written-tools.ts)

written-about = { $what } · tạo { $made }
written-about-in = { $what } · tạo { $made } trong { $chat }
written-used = { $count ->
    [0] chưa dùng lần nào
   *[other] đã dùng { $count } lần
  }
written-none = Chưa có công cụ. Bật “Cho AI viết công cụ” trong một cuộc trò chuyện, và những gì nó viết sẽ được liệt kê ở đây.
written-ask = Hỏi trước khi chạy công cụ mới
written-ask-about = Một lần cho mỗi công cụ: bạn cho phép khi nó chạy lần đầu
written-in = { " " }trong{ " " }
written-made = Tạo { $made }
written-dot-used = { " " }· { $used }
written-switch-off = Tắt
written-switch-on = Bật
written-intro = Các công cụ nhỏ AI tự viết trong những cuộc trò chuyện bật “Cho AI viết công cụ”. Chúng chỉ chạm vào tệp của bạn nếu bạn cho phép, và được giữ cho các cuộc trò chuyện sau.
written-deleted = Đã xóa công cụ “{ $name }”.
written-on = Bật { $name }
written-view-code = Xem mã

## The coding team, shared by the chat and its pages (chat/coding.ts)

coding-quick = Nhanh
coding-balanced = Cân bằng
coding-thorough = Kỹ lưỡng
coding-custom = Tùy chỉnh
coding-running = Đang chạy
coding-done = Xong
coding-failed = Thất bại
coding-stopped = Đã dừng
coding-team-says-alone = { $name }: một người lập kế hoạch, { $workers ->
    [1] một người thực hiện
    [2] hai người thực hiện
   *[other] ba người thực hiện
  }, không có người kiểm tra.
coding-team-says-tests = { $name }: một người lập kế hoạch, { $workers ->
    [1] một người thực hiện
    [2] hai người thực hiện
   *[other] ba người thực hiện
  } và một người kiểm tra chạy các bài kiểm thử.
coding-team-says-steps = { $name }: một người lập kế hoạch, { $workers ->
    [1] một người thực hiện
    [2] hai người thực hiện
   *[other] ba người thực hiện
  } và một người kiểm tra xét từng bước và chạy các bài kiểm thử.
coding-team-label = { $name } · { $workers ->
   *[other] { $workers } người thực hiện
  }
coding-team-label-auditor = { $name } · { $workers ->
   *[other] { $workers } người thực hiện
  }, người kiểm tra
coding-team-label-steps = { $name } · { $workers ->
   *[other] { $workers } người thực hiện
  }, kiểm tra từng bước
coding-tests-pass = { $passed } trên { $total } bài kiểm thử đạt
coding-passed = Đạt
coding-problems = Có lỗi

## Coding team (views/coding-team.ts)

team-audit-end = Ở cuối
team-audit-each = Sau mỗi bước
team-audit-never = Không bao giờ
team-change = Đổi
team-workers-of = { $model } · { $workers } cùng lúc
team-worker-model = Mô hình người thực hiện
team-change-worker = Đổi mô hình người thực hiện
team-how-many = Bao nhiêu người thực hiện
team-none = Không có
team-auditor-tests = { $model } · chạy các bài kiểm thử
team-auditor-steps = { $model } · xét từng bước
team-auditor-model = Mô hình người kiểm tra
team-change-auditor = Đổi mô hình người kiểm tra
team-when = Khi nào người kiểm tra xét
team-team = Nhóm
team-roles = Vai trò
team-planner-model = Mô hình người lập kế hoạch
team-change-planner = Đổi mô hình người lập kế hoạch
team-recent = Nhiệm vụ gần đây
team-intro = Các AI cùng viết chương trình cho bạn trên máy tính này, bắt đầu từ một cuộc trò chuyện.
team-no-tasks = Chưa có tác vụ. Tác vụ được bắt đầu trong cuộc trò chuyện, bằng “+” cạnh ô tin nhắn › Bắt đầu tác vụ lập trình.

## Trash (views/trash.ts)

trash-expressions = Biểu cảm · không nhân vật nào dùng
trash-figure = Hình 3D · không nhân vật nào dùng
trash-chat-with = Trò chuyện với { $names }
trash-chat = Trò chuyện
trash-persona = Persona
trash-persona-used = Persona · dùng trong { $count ->
   *[other] { $count } cuộc trò chuyện
  }
trash-lorebook = Sổ bối cảnh
trash-lorebook-used = Sổ bối cảnh · dùng trong { $count ->
   *[other] { $count } cuộc trò chuyện
  }
trash-character = Nhân vật
trash-character-chats = Nhân vật · có { $count ->
   *[other] { $count } cuộc chat
  }
trash-empty = Thùng rác trống.
trash-about = Những gì chuyển vào đây được giữ { $days } ngày, sau đó bị xóa vĩnh viễn.
trash-emptied = Đã dọn sạch Thùng rác.
trash-empty-trash = Dọn sạch Thùng rác
trash-delete-all-ask = Xóa vĩnh viễn { $count ->
   *[other] { $count } mục
  } trong Thùng rác?
trash-restored = Đã khôi phục “{ $title }”.
trash-deleted = Đã xóa vĩnh viễn “{ $title }”.
trash-deleted-at = Đã chuyển vào đây { $when }
trash-days-left = { $count ->
   *[other] Còn { $count } ngày
  }
trash-restore = Khôi phục
trash-restore-chats = Khôi phục nhân vật và { $count ->
   *[other] { $count } cuộc chat của nhân vật
  }
trash-delete-forever = Xóa vĩnh viễn
trash-delete-forever-ask = Xóa vĩnh viễn “{ $title }”? Không thể khôi phục lại.
trash-delete-forever-ask-chats = Xóa vĩnh viễn “{ $title }” và { $count ->
   *[other] { $count } cuộc chat của nhân vật
  }? Không thể khôi phục lại.

## About Cardwave (views/about.ts)

about-no-package = Không có gói nào tên như vậy.
about-no-notes = Phiên bản này không kèm ghi chú.
about-by = của { $by }
about-licence-of = Giấy phép của { $name }
about-licence = Giấy phép
about-folder-failed = Không mở được thư mục: { $reason }. Thư mục nằm ở { $where }.
about-open-folder = Mở thư mục
about-logs-where = trong thư mục “logs” của thư mục dữ liệu Cardwave, trên máy tính chạy Cardwave
about-logs = Nhật ký
about-logs-about = Những gì Cardwave đã làm và các lần lỗi, mỗi ngày một tệp, giữ 7 ngày: để được giúp khi có sự cố · { $where }
about-version = Phiên bản { $version }
about-whats-new = Có gì mới
about-packages = { $count } gói
about-open-source = Phần mềm nguồn mở
about-search = Tìm kiếm
about-find = Tìm một gói
about-version-built = Phiên bản { $version } · { $built }
about-models = Mô hình
about-figures = Hình 3D và hoạt ảnh
about-voices = Giọng nói
about-voice-donations = Giọng nói được hiến tặng
about-voice-acted-by = Lồng tiếng: { $name }
about-voice-vctk = Người nói { $speaker } của CSTR VCTK Corpus do Junichi Yamagishi, Christophe Veaux và Kirsten MacDonald, University of Edinburgh; Kyutai làm sạch
about-voice-cml-tts = Người nói { $speaker } của CML-TTS do Frederico S. Oliveira, Edresson Casanova, Arnaldo Candido Junior, Anderson S. Soares và Arlindo R. Galvão Filho, đọc cho LibriVox
about-voice-cml-tts-cleaned = Người nói { $speaker } của CML-TTS do Frederico S. Oliveira, Edresson Casanova, Arnaldo Candido Junior, Anderson S. Soares và Arlindo R. Galvão Filho, đọc cho LibriVox; Kyutai làm sạch
about-lists = Danh sách nhà cung cấp và mô hình

about-or = hoặc
about-and = và
about-with = với

## Prompt preset (views/prompt-preset.ts)

prompt-new = Cấu hình lời nhắc mới
promptpage-system = Lời nhắc hệ thống
prompt-system-about = Thay cho lời nhắc hệ thống của thẻ. Để trống để giữ lời nhắc của thẻ.
promptpage-note = Ghi chú
prompt-note-about = AI đọc nó trước mỗi câu trả lời; bạn không thấy nó trong cuộc trò chuyện. Nó nằm lùi bấy nhiêu tin nhắn như đặt bên dưới.
prompt-depth = Cách bao nhiêu tin nhắn
prompt-intro = Chỉ dẫn cho AI. Chọn cấu hình này trong bảng bên của một cuộc trò chuyện để dùng ở đó.
prompt-depth-about = 1 đặt nó ngay trước tin nhắn mới nhất, 4 lùi bốn tin nhắn.
prompt-saved = Đã lưu cấu hình lời nhắc “{ $name }”.
prompt-gone = Mẫu prompt này đã bị xoá. Hãy quay lại và chọn mẫu khác.

## Profile (views/profile.ts)

profile-change-picture = Đổi ảnh
profile-change = Đổi
profile-remove-picture = Gỡ ảnh
profile-remove = Gỡ
profile-picture-changed = Đã đổi ảnh.
profile-picture-removed = Đã gỡ ảnh.
profile-your-picture = Ảnh của bạn
profile-no-picture = Không có ảnh: chữ cái đầu { $letter } được hiện
profile-change-name = Đổi tên
profile-this-computer = Tài khoản của máy tính này
profile-on-server = Tài khoản trên máy tính này
profile-account = Tài khoản

## Server (views/server.ts)

server-copy = Sao chép
server-no-network = Máy tính này chưa kết nối mạng. Hãy kết nối Wi-Fi hoặc cáp để các thiết bị khác vào được.
server-switch-on-about = Khi đó điện thoại và các máy tính khác trong mạng này có thể mở Cardwave. Mỗi tài khoản đăng nhập bằng mật khẩu riêng.
server-switch-on = Bật
server-network-about = Điện thoại và các máy tính khác mở Cardwave trong trình duyệt
server-other-devices = Thiết bị khác
server-inside = Chỉ thiết bị trong mạng này truy cập được, trừ khi bạn đặt bộ định tuyến cho người khác vào.
server-add-account = Thêm tài khoản
server-owner = Máy tính này · có thể thêm và xóa tài khoản
server-more-of = Thêm: { $name }
server-reset-password = Đặt lại mật khẩu
server-delete-account = Xóa tài khoản
server-deleted = Đã xóa tài khoản “{ $name }”.
server-delete-ask = Xoá tài khoản này cùng nhân vật, cuộc trò chuyện và cài đặt của nó? Không thể hoàn tác.
server-reset-title = Đặt lại mật khẩu của { $name }
server-reset-about = Tài khoản sẽ đăng nhập bằng mật khẩu mới, và bị đăng xuất ở mọi nơi đang đăng nhập.
server-new-password = Mật khẩu mới
server-reset-done = Đã đặt lại mật khẩu của { $name }.
server-reset = Đặt lại
server-accounts = Tài khoản

## Character generator (views/generator.ts)

gen-gender-woman = Nữ
gen-gender-man = Nam
gen-gender-non-binary = Phi nhị nguyên
gen-being-human = Người
gen-being-not-human = Không phải người
gen-age-20s = Ngoài 20
gen-age-30s = Ngoài 30
gen-age-40s = Ngoài 40
gen-age-50s-and-older = Từ 50 trở lên
gen-build-slim = Mảnh khảnh
gen-build-average = Trung bình
gen-build-athletic = Săn chắc
gen-build-strong = Vạm vỡ
gen-hair-short = Ngắn
gen-hair-medium = Vừa
gen-hair-long = Dài
gen-colour-black = Đen
gen-colour-brown = Nâu
gen-colour-blonde = Vàng
gen-colour-red = Đỏ
gen-colour-grey = Xám
gen-colour-white = Trắng
gen-relation-stranger = Người lạ
gen-relation-friend = Bạn bè
gen-relation-partner = Người yêu
gen-relation-rival = Đối thủ
gen-relation-colleague = Đồng nghiệp
gen-relation-mentor = Người dẫn dắt
gen-shy = Nhút nhát
gen-outgoing = Hướng ngoại
gen-gentle = Dịu dàng
gen-harsh = Gay gắt
gen-serious = Nghiêm túc
gen-playful = Tinh nghịch
gen-cautious = Thận trọng
gen-bold = Táo bạo
gen-random = Ngẫu nhiên
gen-slider = { $low } đến { $high }
gen-looks = Ngoại hình
gen-gender = Giới tính
gen-being = Có phải người không
gen-any = Bất kỳ
gen-age = Tuổi
gen-build = Vóc dáng
gen-hair = Tóc
gen-hair-colour = Màu tóc
gen-personality = Tính cách
gen-relates = Nhân vật là ai đối với bạn
gen-make = Tạo nhân vật
gen-what = Chọn vài nét tính cách; AI viết tin nhắn đầu tiên của nhân vật và cách nhân vật nói chuyện.
interview-goes-to = Câu trả lời của bạn được gửi đến { $provider } để viết nhân vật.
interview-stays = Câu trả lời của bạn ở lại trên máy tính này.
interview-own-words = Hoặc thêm lời của bạn
interview-in-own-words = Bằng lời của bạn
interview-your-answer = Câu trả lời của bạn
interview-pick-one = Chọn một
interview-pick-two = Chọn một hoặc hai
interview-pick-three = Chọn tối đa ba
interview-pick-many = Chọn tất cả những gì phù hợp
interview-few-words = Vài từ là đủ
interview-wanted-hint = Điều gì còn thiếu khi ở bên mọi người, hoặc với những nhân vật bạn đã thử?
interview-needs-hint = Cho thời gian của bạn với nhân vật, không phải cho phần còn lại của cuộc sống
interview-next = Tiếp
interview-skip = Bỏ qua
interview-dont-know = Tôi không biết
interview-back = Quay lại
interview-just-make-it = Cứ tạo đi
interview-more = Thêm loại
interview-writing-next = Đang viết câu hỏi tiếp theo
interview-try-again = Thử lại
interview-failed-where = Nếu vẫn lỗi, hãy xem nhà cung cấp và mô hình trong Cài đặt › Nhà cung cấp.
gen-stop = Dừng
gen-writing = Đang viết nhân vật…
interview-understood = Đây là những gì tôi hiểu.
interview-you-said = bạn đã nói: “{ $words }”
interview-own-guess = phỏng đoán riêng của AI
interview-keep = Giữ
interview-change = Đổi
interview-remove = Gỡ
interview-not-it = Không phải vậy
interview-not-it-off = Dòng này không dựa trên một câu hỏi nào có thể hỏi lại
interview-own-sentence = Câu của riêng bạn
interview-private-line = Điều gì bạn muốn có trong thế giới nhân vật của bạn, hoặc không bao giờ muốn?
interview-private-sub = Lãng mạn, bạo lực, chửi thề và hơn nữa · không bắt buộc
interview-make = Tạo nhân vật
interview-make-after = Sau đó bạn có thể đổi trên trang của nó.
interview-skip-all = Bỏ qua tất cả
interview-private-hint = Có người muốn những điều này trong thế giới nhân vật của mình, có người không. Câu trả lời của bạn ở lại cùng nhân vật này trên máy tính của bạn và chỉ được gửi đến AI viết nhân vật.
interview-private-free = Điều gì khác bạn muốn, hoặc không bao giờ muốn
interview-yes = Có
interview-no = Không
interview-maybe = Có thể
interview-fantasy-only = Chỉ trong tưởng tượng
interview-never = Không bao giờ
interview-try-another = Thử mô hình khác
interview-without-topic = Viết mà không có chủ đề đó
interview-model-provider = { $model } · { $provider }
interview-reading = Đang đọc câu trả lời của bạn
interview-persona-title = Thêm những gì bạn nói về mình vào persona của bạn?
interview-persona-field = Persona
interview-persona-in-use = { $persona } · đang dùng
interview-persona-new = Persona mới
interview-persona-add = Thêm
interview-persona-not-now = Để sau
interview-persona-added = Đã thêm vào “{ $persona }”.
interview-persona-you = Bạn
