### Chữ trên giao diện bằng tiếng Việt: câu trả lời lỗi của máy chủ, dịch từ en.errors.ftl (tệp gốc) từng khóa một;
### bảng từ ở đầu vi.ftl.

## Yêu cầu, như máy chủ nhận được

error-request-failed = Không làm được việc đó. Hãy thử lại.
error-internal = Cardwave gặp sự cố. Hãy thử lại.
error-bad-request = Cardwave không đọc được yêu cầu đó. Hãy tải lại trang rồi thử lại.
error-forbidden = Việc đó không được phép.
error-no-such-path = Cardwave không có trang này. Hãy tải lại trang rồi thử lại.
error-method-not-allowed = Cardwave không làm việc đó ở đây. Hãy tải lại trang rồi thử lại.
error-too-large = Quá lớn. Hãy thử một tệp nhỏ hơn.
error-unsupported-type = Cardwave không nhận loại tệp này ở đây.

## Mật khẩu và tài khoản

error-locked = Cardwave bị khóa cho đến khi nhập mật khẩu.
error-sign-in = Hãy đăng nhập trước.
error-password-wrong = Sai mật khẩu.
error-password-needed = Cần nhập mật khẩu.
error-current-password-needed = Cần nhập mật khẩu hiện tại.
error-backup-password-needed = Bản sao lưu này cần mật khẩu của nó.
error-too-many-tries = Sai mật khẩu quá nhiều lần. Hãy thử lại sau { $seconds } giây.
error-owner-only = Chỉ tài khoản của máy tính này mới có thể { $action ->
    [use_its_files] dùng các tệp của máy
    [use_its_folders] dùng các thư mục của máy
    [choose_its_models] chọn mô hình của máy
    [lock_Cardwave] khóa Cardwave
   *[other] làm việc đó
}.
error-no-password-to-lock = Cardwave chỉ khóa được khi đã bật mật khẩu.
error-remote-sign-in-off = Tài khoản này không thể đăng nhập từ thiết bị khác. Hãy bật trong Tài khoản › Chia sẻ.
error-no-password-on = Chưa bật mật khẩu.
error-no-password-set = Tài khoản này chưa đặt mật khẩu.
error-password-kept = Một tài khoản trên máy tính này giữ mật khẩu: tài khoản đó đăng nhập bằng mật khẩu ấy.
error-account-busy = Cardwave vẫn đang làm việc cho tài khoản này: một câu trả lời, một bức ảnh, một tác vụ lập trình, một nhân vật mới, việc đọc các nhân vật hoặc trí nhớ của một cuộc trò chuyện; hãy thử lại khi xong.
error-restore-busy = Cardwave vẫn đang làm việc: một câu trả lời, một bức ảnh, một tác vụ lập trình, một nhân vật mới, việc đọc các nhân vật hoặc trí nhớ của một cuộc trò chuyện; hãy thử lại khi xong.
error-backup-needs-password = Bản sao lưu cần có mật khẩu.

## Thứ được yêu cầu

error-not-found = Không có { $what ->
    [account] tài khoản
    [asset] tệp trong thẻ
    [attachment] tệp đính kèm
    [card] thẻ
    [card_version] phiên bản thẻ
    [chat] cuộc trò chuyện
    [chat_character] nhân vật trong cuộc trò chuyện
    [checkpoint] điểm lưu
    [deleted_message] tin nhắn đã xóa
    [document] tài liệu
    [expression] biểu cảm
    [expression_pack] bộ biểu cảm
    [figure] hình 3D
    [kind_of_model] loại mô hình
    [language] ngôn ngữ
    [lorebook] sổ bối cảnh
    [lorebook_entry] mục sổ bối cảnh
    [memory] ký ức
    [message] tin nhắn
    [model] mô hình
    [persona] persona
    [picture] hình ảnh
    [preset] cấu hình mẫu
    [prompt_preset] cấu hình lời nhắc
    [provider] nhà cung cấp
    [question] câu hỏi
    [task] nhiệm vụ
    [tool] công cụ
    [user] tài khoản
    [voice] giọng nói
   *[other] thứ
} nào như vậy. Có thể nó đã bị xóa.
error-chat-busy = Một câu trả lời đang được viết trong cuộc trò chuyện này; hãy dừng nó trước.
error-no-provider = { $what ->
    [chat_model] Chưa chọn mô hình trò chuyện nào. Hãy chọn một mô hình trong Cài đặt › Mô hình.
   *[other] Chưa thiết lập nhà cung cấp nào. Hãy thêm một nhà cung cấp trong Cài đặt › Nhà cung cấp.
}
error-provider-refused = { $refusal ->
    [key] Nhà cung cấp không nhận khóa: hãy kiểm tra trong Cài đặt › Nhà cung cấp.
    [paid] Nhà cung cấp yêu cầu thanh toán cho việc này: hãy nạp thêm tín dụng, hoặc chọn một mô hình có trong gói của bạn.
    [busy] Nhà cung cấp đã hết tín dụng hoặc đang bận: hãy thử lại sau.
    [down] Nhà cung cấp không trả lời: hãy thử lại sau.
    [fault] Nhà cung cấp gặp lỗi ở phía họ: { $reason } Hãy thử lại sau.
    [no_model] Nhà cung cấp không còn cung cấp mô hình này: hãy chọn mô hình khác trong Cài đặt › Mô hình.
    [too_long] Mô hình được gửi nhiều hơn mức nó đọc được một lần: hãy chọn trong Cài đặt › Mô hình một mô hình đọc được nhiều hơn.
   *[other] Nhà cung cấp đã từ chối: { $reason }
}
error-model-declined = { $model } từ chối viết nội dung này. Hãy đổi tin nhắn, hoặc chọn mô hình khác.
error-model-sees-no-pictures = { $model } không xem được hình ảnh, nên không nhận hình nào. Hãy chọn mô hình nhìn được hình ảnh để gửi chúng.
error-card-trashed = Nhân vật đang ở trong Thùng rác; hãy khôi phục trước.
error-lorebook-trashed = Sổ bối cảnh “{ $name }” đang ở trong Thùng rác; hãy khôi phục để dùng.
error-own-lorebook-flags = Sổ bối cảnh riêng của một nhân vật đi cùng nhân vật đó: không thể gắn sao, lưu trữ, chuyển vào Thùng rác hay dùng trong mọi cuộc trò chuyện một cách riêng lẻ.

## Thư mục và tệp

error-no-such-folder = Máy tính này không có thư mục { $folder }.
error-folder-not-chosen = Hãy chọn thư mục trước.
error-drive-root-to-watch = Thư mục gốc của ổ đĩa chứa quá nhiều để theo dõi; hãy chọn một thư mục bên trong.
error-drive-root-for-model = Thư mục gốc của ổ đĩa chứa quá nhiều để đưa cho AI; hãy chọn một thư mục bên trong.
error-data-folder = Thư mục đó chứa dữ liệu của chính Cardwave, hoặc nằm trong đó; hãy chọn thư mục khác.
error-commands-windows-only = Lệnh chỉ chạy được trên Windows.
error-recycle-bin-windows-only = Tệp chỉ được chuyển vào Thùng rác của Windows khi chạy trên Windows.
error-files-tool-off = Hãy bật Tệp trong Cài đặt › Công cụ trước: nhóm dùng nó để đọc và ghi thư mục của nhiệm vụ.

## Hình ảnh, câu trả lời và giọng nói

error-picture-words-missing = Hãy nói hình ảnh thể hiện gì trước.
error-picture-words-too-long = Phần mô tả hình ảnh dài hơn { $most } ký tự.
error-picture-needs-words = Hãy nói hình ảnh thể hiện gì.
error-goal-missing = Hãy nói nhóm cần làm gì.
error-dictation-not-set-up = Chưa thiết lập đọc chính tả: Cài đặt › Mô hình › Đọc chính tả.
error-direction-without-go-on = Gợi ý chỉ dùng được với Viết tiếp.
error-again-or-go-on = Một câu trả lời hoặc được viết lại, hoặc được viết tiếp, không phải cả hai.
error-again-not-reply = Chỉ câu trả lời của nhân vật mới có thể viết lại.
error-no-reply-to-write-again = Cuộc trò chuyện không có câu trả lời nào để viết lại.
error-no-text = AI không gửi văn bản nào. Hãy thử lại.
error-worker-no-answer = Mô hình phụ trợ không trả lời.
error-unknown-voice = Không có giọng nói “{ $voice }”.
error-nothing-to-read = Không có gì để đọc.
error-voice-not-downloaded = Giọng nói chưa được tải xuống.
error-voice-failed = Đọc to thất bại. Hãy thử lại.
error-stopping = Cardwave đang dừng.
error-download-failed = Tải về thất bại. Hãy kiểm tra kết nối và thử lại.
error-search-model-failed = Mô hình tìm kiếm gặp lỗi. Cardwave sẽ thử lại sau một lúc.
error-models-not-listed = Không liệt kê được các mô hình của nhà cung cấp. Hãy kiểm tra địa chỉ và khóa, rồi thử lại.
error-file-not-imported = Không đọc được tệp: Cardwave không biết định dạng của nó.
error-describing-failed = Mô hình phụ trợ không mô tả được nhân vật.

## Các loại lỗi theo từng khu vực: mỗi loại chọn lời theo `what` (hoặc `whose`), thứ mà lỗi nói đến

error-needed = { $what ->
    [persona_name] Persona cần có tên.
    [account_name] Tài khoản cần có tên.
    [card_title] Nhân vật cần có tiêu đề.
    [character_name] Nhân vật cần có tên.
    [chat_character] Cuộc trò chuyện cần có nhân vật.
    [chat_title] Tiêu đề cuộc trò chuyện không được để trống.
    [entry_name] Mục cần có tên.
    [expression_files] Hãy chọn một tệp zip (thư mục đã nén) hoặc các hình của một bộ.
    [language] Thiếu ngôn ngữ.
    [lorebook_name] Sổ bối cảnh cần có tên.
    [memory_text] Ký ức cần có nội dung.
    [message_to_improve] Không có tin nhắn nào để cải thiện.
    [model_name] Phải đặt tên cho mô hình.
    [models_folder] Hãy chọn thư mục mô hình trước.
    [password] Mật khẩu không được để trống.
    [preset_name] Cấu hình mẫu cần có tên.
    [rewrite_given] Thiếu một thứ cần thiết. Hãy thử lại.
    [summary] Bản tóm tắt không được để trống.
    [text_to_change] Không có văn bản nào để thay đổi.
    [text_to_read] Không có gì để đọc.
    [voice_name] Giọng nói cần có tên.
   *[other] Thiếu một thứ cần thiết. Hãy thử lại.
}
error-too-long = { $what ->
    [account_name] Tên tài khoản dài tối đa { $name_limit } ký tự.
    [chat_title] Tiêu đề cuộc trò chuyện dài tối đa { $title_limit } ký tự.
    [document] { $name } quá dài: một tài liệu có tối đa 2.000.000 ký tự.
    [entry_name] Tên mục dài tối đa { $max_name } ký tự.
    [field_name] Tên trường dài từ 1 đến { $max_field } ký tự.
    [lorebook_name] Tên sổ bối cảnh dài tối đa { $max_name } ký tự.
    [memory_text] Ký ức dài tối đa { $text_limit } ký tự.
    [persona_name] Tên persona dài tối đa { $max_name } chữ.
    [provider_name] Tên dài tối đa { $name_limit } ký tự.
    [unsaved_text] Văn bản chưa lưu giữ tối đa { $max_text } ký tự.
    [voice_name] Tên giọng nói dài tối đa { $name_most } ký tự.
   *[other] Dài hơn { $most } ký tự.
}
error-out-of-range = { $what ->
    [authors_note_depth] Ghi chú được đặt lùi lại một tin nhắn trở lên.
    [companion_size] Kích thước của bạn đồng hành từ { $start } đến { $end } phần trăm chiều cao màn hình.
    [context_size] Kích thước ngữ cảnh phải ít nhất 512 token.
    [entry_chance] Xác suất của mục tối đa 100 phần trăm.
    [provider_setting] { $name } phải từ { $min } đến { $max }.
    [reply_length] Độ dài câu trả lời phải từ 1 đến { $most_reply_length } token.
    [slider] Thanh trượt đi từ 0 đến 100.
    [talk_pause] Khoảng dừng phải từ 0 đến { $most_talk_pause } giây.
    [talk_replies] Số câu trả lời liên tiếp phải từ 1 đến { $most_talk_replies }.
    [talkativeness] Mức nói nhiều từ 0 đến 100.
    [voice_speed] Tốc độ từ { $start }% đến { $end }%.
   *[other] Giá trị phải từ { $least } đến { $most }.
}
error-taken = { $what ->
    [card_in_library] Đã có trong thư viện của bạn.
    [account_name] Đã có tài khoản khác tên “{ $name }”.
    [card_language] Thẻ đã có bằng { $name }.
    [chat_character] { $name } đã có trong cuộc trò chuyện này.
    [chat_character_twice] { $name } có hai lần trong cuộc trò chuyện này.
    [lorebook_same_name] Thẻ hiện đã có sổ bối cảnh hoặc mục cùng tên.
    [model_file] { $name } đã có trong thư mục.
    [preset_name] Đã có cấu hình mẫu khác tên “{ $name }”.
    [tool_name] Đã có công cụ tên { $name }; hãy chọn tên khác.
   *[other] Đã có rồi.
}
error-in-trash = { $what ->
    [card] Nhân vật đang ở trong Thùng rác; hãy khôi phục trước.
    [card_to_chat] Nhân vật đang ở trong Thùng rác; hãy khôi phục nhân vật để trò chuyện lại.
    [chat] Cuộc trò chuyện đang ở trong Thùng rác; hãy khôi phục trước.
    [chat_card] Nhân vật “{ $title }” của nó đang ở trong Thùng rác; hãy khôi phục nhân vật trước.
    [lorebook] Sổ bối cảnh “{ $name }” đang ở trong Thùng rác; hãy khôi phục trước.
    [lorebook_to_use] Sổ bối cảnh “{ $name }” đang ở trong Thùng rác; hãy khôi phục để dùng.
    [persona_default] Persona trong Thùng rác không thể là mặc định; hãy khôi phục trước.
    [persona_to_use] Persona “{ $name }” đang ở trong Thùng rác; hãy khôi phục để dùng.
   *[other] Thứ đó đang ở trong Thùng rác; hãy khôi phục trước.
}
error-not-readable = { $what ->
    [damaged_key] Khóa của nó bị hỏng.
    [json] Tệp không phải JSON hợp lệ.
    [lorebook] Tệp không chứa sổ bối cảnh.
    [lorebook_not_card] Tệp là thẻ nhân vật, không phải sổ bối cảnh.
    [account_picture] Ảnh không phải tệp PNG hoặc JPEG đọc được, tối đa 4.096 điểm ảnh mỗi cạnh.
    [attachment_picture] Ảnh phải là tệp PNG, JPEG hoặc WebP.
    [backup] Tệp này không phải bản sao lưu của Cardwave.
    [backup_damaged] Bản sao lưu này bị hỏng.
    [backup_newer] Bản sao lưu này được tạo bởi Cardwave mới hơn. Hãy cập nhật Cardwave để khôi phục nó.
    [backup_key] Bản sao lưu này bị hỏng: không đọc được khóa của nó.
    [base64] Đó không phải base64.
    [base64_file] { $name } không phải base64.
    [card_defined_twice] Tệp này không phải thẻ nhân vật mà Cardwave đọc được. Hãy xuất lại từ ứng dụng mà nó đến từ đó.
    [card_file_name] Một tên tệp trong thẻ không dùng được.
    [card_reference] Không trỏ đến phần nào của thẻ.
    [ccv4_version] Thẻ này được tạo bởi Cardwave mới hơn. Hãy cập nhật Cardwave để mở nó.
    [comfyui_address] Không đọc được địa chỉ của ComfyUI.
    [comfyui_answer] Không đọc được câu trả lời của ComfyUI.
    [dictation_recording] Không đọc được bản ghi âm. Hãy ghi lại.
    [document_text] { $name } không có văn bản đọc được.
    [document_type] Tài liệu phải là tệp .txt, .md, .pdf hoặc .docx.
    [downloaded_model] Tệp đã tải xuống không phải mô hình.
    [expression_pack] Không hình nào được đặt tên theo cảm xúc bằng tiếng Anh, như joy.png hay anger.png (PNG, JPEG, WebP hoặc GIF).
    [figure_file] { $file_name } không phải tệp loại đó.
    [figure_still] Ảnh tĩnh của hình 3D không phải PNG tối đa 4 MB.
    [figure_type] Hình 3D phải là tệp VRM, GLB hoặc FBX.
    [folder_read] Không đọc được thư mục.
    [format_version] Tệp này không phải thẻ nhân vật mà Cardwave đọc được. Hãy xuất lại từ ứng dụng mà nó đến từ đó.
    [image_model_answer] Không đọc được câu trả lời của mô hình hình ảnh.
    [image_model_picture] Không đọc được hình của mô hình hình ảnh.
    [key_characters] Khóa có ký tự mà khóa không thể có. Hãy sao chép lại từ trang của nhà cung cấp.
    [lorebook_empty] Sổ bối cảnh trống.
    [lorebook_entries] Sổ bối cảnh không có mục nào.
    [lorebook_file] Không đọc được sổ bối cảnh.
    [lorebook_named] Không đọc được sổ bối cảnh “{ $name }”.
    [lorebook_named_empty] Sổ bối cảnh “{ $name }” trống.
    [models_dev_list] Không đọc được danh sách mô hình.
    [models_list_answer] Địa chỉ có trả lời, nhưng không phải danh sách mô hình.
    [models_list_missing] Danh sách mô hình không được gửi đến.
    [name_characters] Tên chứa ký tự mà tên không được có.
    [no_lorebook] Đây không phải sổ bối cảnh.
    [pdf] Không đọc được tệp PDF.
    [picture] Ảnh không phải PNG, JPEG hay WebP.
    [picture_server_answer] Không đọc được câu trả lời của máy chủ hình ảnh.
    [picture_unreadable] Không đọc được hình ảnh.
    [png] Không phải tệp PNG.
    [no_card] Tệp này không chứa thẻ nhân vật nào.
    [png_damaged] Tệp PNG bị hỏng.
    [charx] Cardwave chưa thể nhập tệp thẻ CHARX. Hãy xuất thẻ dưới dạng PNG hoặc JSON.
    [provider_address] Địa chỉ phải là địa chỉ web đơn giản, như https://api.openai.com/v1.
    [provider_website] Hãy nhập trang web của nhà cung cấp dưới dạng tên, như example.com.
    [recording_format] Không đọc được định dạng của bản ghi âm.
    [recording_pcm] Không đọc được bản ghi âm. Hãy ghi lại.
    [recording_rate] Không đọc được tần số lấy mẫu của bản ghi âm.
    [recording_short] Bản ghi âm quá ngắn: cần ít nhất { $shortest } giây.
    [recording_silent] Bản ghi âm không có tiếng.
    [recording_wav] Bản ghi âm không phải tệp WAV.
    [sillytavern_base64] Tệp này không phải thẻ nhân vật mà Cardwave đọc được. Hãy xuất lại từ ứng dụng mà nó đến từ đó.
    [sillytavern_empty] Thẻ trống.
    [sillytavern_file] Không đọc được thẻ SillyTavern trong tệp này.
    [sillytavern_json] Tệp này không phải thẻ nhân vật mà Cardwave đọc được. Hãy xuất lại từ ứng dụng mà nó đến từ đó.
    [sillytavern_object] Tệp này không phải thẻ nhân vật mà Cardwave đọc được. Hãy xuất lại từ ứng dụng mà nó đến từ đó.
    [sillytavern_png] Không đọc được thẻ SillyTavern trong tệp PNG này.
    [spec_version] Tệp này không phải thẻ nhân vật mà Cardwave đọc được. Hãy xuất lại từ ứng dụng mà nó đến từ đó.
    [spec_version_form] Tệp này không phải thẻ nhân vật mà Cardwave đọc được. Hãy xuất lại từ ứng dụng mà nó đến từ đó.
    [toml] Tệp này không phải thẻ nhân vật mà Cardwave đọc được. Hãy xuất lại từ ứng dụng mà nó đến từ đó.
    [word_file] Không đọc được tệp Word.
    [word_text] Tệp Word không có văn bản.
    [workflow] Không đọc được quy trình “{ $name }”.
    [workflow_api_form] Quy trình được lưu ở dạng dành cho API: hãy lưu nó trong ComfyUI dưới dạng quy trình (workflow).
    [workflow_broken] Không đọc được quy trình.
    [workflow_fields] Nút “{ $kind }” của quy trình có những trường Cardwave không đọc được.
    [workflow_no_node] Quy trình không có nút nào mà ComfyUI này chạy được.
    [workflow_node] Nút “{ $class }” của quy trình không có trong ComfyUI này.
    [zip] Không đọc được { $name } dưới dạng tệp zip.
   *[other] Không đọc được.
}
error-too-big = { $what ->
    [card_for_worker] Nhân vật quá dài với mô hình phụ trợ; hãy chọn mô hình phụ trợ đọc được nhiều hơn.
    [card_for_chat] Nhân vật quá dài với mô hình trò chuyện nên sẽ không còn là chính mình; hãy chọn mô hình trò chuyện đọc được nhiều hơn, hoặc rút gọn nhân vật.
    [card_file] Tệp lớn hơn { $most } MB.
    [checkpoint_folder] Thư mục quá lớn để giữ bản sao trước mỗi bước.
    [expression_pack_size] Các hình ảnh của { $name } quá lớn.
    [expression_zip_files] { $name } chứa hơn { $max_entries } tệp.
    [figure] Hình 3D quá lớn.
    [model_for_computer] { $name } quá lớn so với máy tính này.
    [models_dev_list] Danh sách mô hình quá dài.
    [picture_pixels] Ảnh quá lớn ({ $wide } x { $high } điểm ảnh).
    [reply] Câu trả lời bị cắt: nó đã quá dài.
   *[other] Quá lớn.
}
error-not-now = { $what ->
    [character_has_written] { $name } đã viết trong cuộc trò chuyện này nên vẫn ở lại.
    [coding_folder_busy] Một nhiệm vụ lập trình khác đang chạy trong thư mục đó; hãy chờ nó xong hoặc dừng nó.
    [database_busy] Cardwave đang bận; hãy thử lại.
    [download_cancelling] Lượt tải xuống đang được hủy; hãy thử lại sau giây lát.
    [held_by_card] Một nhân vật đang dùng mục này; hãy gỡ nó khỏi nhân vật trước.
    [lorebook_used_elsewhere] Sổ bối cảnh hiện được dùng ở nơi khác, nên vẫn ở lại trong thư viện.
    [model_downloading] Mô hình đang được tải xuống.
    [model_replying] Mô hình đang trả lời; hãy xóa nó khi câu trả lời kết thúc.
    [search_model_not_downloaded] Mô hình tìm kiếm chưa được tải xuống.
    [task_running] Nhiệm vụ vẫn đang chạy; hãy dừng nó trước.
   *[other] Không làm được việc đó lúc này. Hãy thử lại sau giây lát.
}
error-changed = { $what ->
    [lorebook_entry] Sổ bối cảnh hiện đã có một mục khác.
    [card_version] Thẻ đã bị thay đổi trong lúc đó; thẻ được đọc lại.
    [tool_name] Giờ đã có công cụ khác tên { $name }.
    [two_ways] { $reference } bị thay đổi hai lần cùng lúc; hãy thử lại.
    [workflow] Quy trình “{ $name }” đã bị thay đổi trong ComfyUI: hãy chọn lại trong Cài đặt › Nhà cung cấp.
   *[other] Thứ đó đã bị thay đổi trong lúc đó; hãy thử lại.
}
error-not-possible = { $what ->
    [back_to_computer] Chỉ tìm kiếm và giọng nói mới có thể quay về máy tính này.
    [card_about_itself] Không thể thay đổi những gì thẻ nói về chính nó.
    [card_change] Không thể thay đổi điều đó trong thẻ này.
    [card_character] Thẻ không có nhân vật này.
    [card_character_change] Không thể thay đổi nhân vật của thẻ.
    [card_language_beside] Thẻ không thể chứa { $name } bên cạnh ngôn ngữ đầu tiên của nó.
    [card_lorebook] Thẻ không mang theo sổ bối cảnh này.
    [card_lorebook_attached] Thẻ không có sổ bối cảnh này được gắn vào.
    [card_mode] Thẻ không có chế độ này.
    [card_no_character] Thẻ không có nhân vật.
    [card_not_changed] Thẻ không bị thay đổi.
    [card_part] Đó không phải phần nào của thẻ có thể thay đổi.
    [card_takes_no] Thẻ này không nhận thêm thứ mới loại đó.
    [card_takes_no_lorebook] Thẻ không nhận sổ bối cảnh.
    [character_change] Không thể thay đổi nhân vật đó trong thẻ này.
    [chat_character] Cuộc trò chuyện không có nhân vật này.
    [chat_lore] Cuộc trò chuyện không có sổ bối cảnh hay mục sổ bối cảnh này.
    [chat_lorebook] Cuộc trò chuyện không có sổ bối cảnh này.
    [chat_mode] Cuộc trò chuyện không có chế độ này.
    [chat_no_character] Cuộc trò chuyện không có nhân vật.
    [chat_without_character] Cuộc trò chuyện không có nhân vật thì không có nhân vật nào.
    [chat_without_character_add] Cuộc trò chuyện không có nhân vật thì không nhận nhân vật nào.
    [checkpoint_put_back] Không thể đặt lại { $path }.
    [comfyui_no_picture] ComfyUI không tạo hình ảnh nào.
    [companion_not_answering] Bạn đồng hành không trả lời.
    [companion_not_shown] Bạn đồng hành đang không hiển thị.
    [comfyui_queue] ComfyUI không xếp hình ảnh vào hàng đợi.
    [comfyui_said] ComfyUI báo: { $said }
    [continue_no_text] Câu trả lời không có văn bản để viết tiếp.
    [continue_only_reply] Chỉ câu trả lời của nhân vật mới có thể viết tiếp.
    [depth_note] Không thể thêm ghi chú ở một độ sâu.
    [dictation_failed] Mô hình đọc chính tả gặp lỗi.
    [dictation_model_load] Không tải được mô hình đọc chính tả.
    [dictation_model_start] Không khởi động được mô hình đọc chính tả.
    [draft_made_by] Bản nháp không được tạo bởi “{ $made }”.
    [edit_breaks_card] Thẻ sẽ không đọc được sau thay đổi này.
    [entry_change] Không thể thay đổi mục theo yêu cầu trong sổ bối cảnh này.
    [entry_taken_out] Đây không phải mục sổ bối cảnh đã được tách ra.
    [export_no_character] Thẻ không có nhân vật để xuất.
    [greeting] Đó không phải một lời chào của nhân vật này.
    [improve_direction] Cải thiện dùng chữ trong ô; nó không nhận gợi ý.
    [key_refused] Khóa bị từ chối.
    [llama_server_start] Không khởi động được mô hình tìm kiếm. Hãy khởi động lại Cardwave và thử lại.
    [local_address] Mô hình trên máy tính này được tìm theo thư mục của chúng, trong Cài đặt › Nhà cung cấp.
    [lorebook_change] Không thể thay đổi sổ bối cảnh này.
    [lorebook_change_breaks] Sổ bối cảnh sẽ không đọc được sau thay đổi này.
    [lorebook_new_entry] Sổ bối cảnh này không nhận mục mới.
    [lorebook_put_in] Không thể đưa sổ bối cảnh vào thẻ này.
    [lorebook_take_out] Không thể tách sổ bối cảnh khỏi thẻ này.
    [message_not_in_chat] Tin nhắn không thuộc cuộc trò chuyện này.
    [message_not_in_view] Tin nhắn không nằm trong khung nhìn.
    [model_remove] Không thể gỡ { $path }.
    [no_folder] Máy tính này không có thư mục như vậy.
    [no_image_model] Chưa thiết lập mô hình hình ảnh: hãy thiết lập trong Cài đặt › Mô hình › Hình ảnh.
    [no_local_model] Không có mô hình “{ $id }” trong thư mục đó.
    [no_local_models] Chưa thiết lập mô hình trên máy.
    [no_recycle_bin] Không có Thùng rác của Windows cho { $path }.
    [no_summary] Thẻ chưa có bản tóm tắt.
    [no_voice] Không có giọng nói này.
    [no_vulkan] Card đồ họa của máy này không chạy được mô hình. Hãy dùng một nhà cung cấp thay thế.
    [no_vulkan_dictation] Card đồ họa của máy này không chạy được tính năng đọc chính tả.
    [prompt_change] Không thể thay đổi prompt của nhân vật đó trong thẻ này.
    [recycle_bin_move] { $path } không được chuyển vào Thùng rác của Windows.
    [speaker_not_in_chat] Người nói không thuộc cuộc trò chuyện này.
    [speaker_only_character] Chỉ tin nhắn của nhân vật mới có người nói.
    [unknown_language] Ứng dụng này không biết ngôn ngữ đó.
    [version_lacks_character] Có cuộc trò chuyện với một nhân vật mà phiên bản mới nhất không có.
    [voice_runtime] Đọc to cần một thành phần của Microsoft đang bị thiếu: hãy cài Visual C++ Redistributable từ microsoft.com, rồi khởi động lại Cardwave.
    [workflow_no_text] Quy trình “{ $name }” không có trường văn bản cho lời mô tả hình ảnh.
    [workflow_use] Không dùng được quy trình “{ $name }”.
    [written_tools_full] Bạn chỉ giữ được tối đa { $most_tools } công cụ; hãy xóa một cái trong Cài đặt › Công cụ do AI viết trước.
    [delete_not_in_trash] Chỉ thứ trong Thùng rác mới xóa vĩnh viễn được; hãy chuyển nó vào đó trước.
   *[other] Không làm được việc đó.
}
error-model-answer = { $what ->
    [no_greeting] AI không viết lời chào.
    [background_answer] Không dùng được câu trả lời của mô hình phụ. Hãy thử lại, hoặc chọn mô hình phụ khác.
    [background_text] Không dùng được câu trả lời của mô hình phụ. Hãy thử lại, hoặc chọn mô hình phụ khác.
    [card_texts] Câu trả lời của AI không phải các văn bản của nhân vật.
    [classification] Không dùng được câu trả lời của mô hình phụ. Hãy thử lại, hoặc chọn mô hình phụ khác.
    [example_messages] AI không viết tin nhắn mẫu nào.
    [no_example_message] AI viết một tin nhắn mẫu không có nội dung.
    [json] Câu trả lời của AI không theo dạng đã yêu cầu.
    [keywords] Không dùng được câu trả lời của mô hình phụ. Hãy thử lại, hoặc chọn mô hình phụ khác.
    [logline] Không dùng được câu trả lời của mô hình phụ. Hãy thử lại, hoặc chọn mô hình phụ khác.
    [no_chat_reply] Nhà cung cấp AI không gửi câu trả lời trò chuyện.
    [no_fitting_answer] AI không đưa ra câu trả lời dùng được sau ba lần thử.
    [no_picture] Mô hình hình ảnh trả lời mà không có hình.
    [no_plan] Người lập kế hoạch không lập kế hoạch nào.
    [no_text] AI không gửi văn bản nào.
    [picture_address] Ảnh của mô hình hình ảnh nằm ở một địa chỉ không được tải xuống.
    [picture_art] Không tạo được hình ảnh; hãy thử lại.
    [picture_field] Mô hình phụ trợ không tìm thấy trường cho lời mô tả hình ảnh.
    [picture_server_no_picture] Máy chủ hình ảnh trả lời mà không có hình.
    [picture_words] Mô hình phụ trợ không viết lời mô tả cho hình ảnh.
    [rating] Không dùng được câu trả lời của mô hình phụ. Hãy thử lại, hoặc chọn mô hình phụ khác.
    [reply_broke_off] Câu trả lời bị ngắt giữa chừng.
    [needs] Không dùng được câu trả lời của mô hình phụ. Hãy thử lại, hoặc chọn mô hình phụ khác.
    [rounds] Nhóm không hoàn thành công việc trong { $rounds } vòng.
    [search_left_out] Mô hình tìm kiếm bỏ sót một văn bản.
    [search_model] Không đọc được câu trả lời của mô hình tìm kiếm.
    [search_tokens] Không đọc được token của mô hình tìm kiếm.
    [title] Không dùng được câu trả lời của mô hình phụ. Hãy thử lại, hoặc chọn mô hình phụ khác.
    [too_many_tools] AI gọi quá nhiều công cụ.
    [worker_mode] Không dùng được câu trả lời của mô hình phụ. Hãy thử lại, hoặc chọn mô hình phụ khác.
    [worker_texts] Không dùng được câu trả lời của mô hình phụ. Hãy thử lại, hoặc chọn mô hình phụ khác.
    [server_reported] Nhà cung cấp AI báo: { $reason }
   *[other] Không dùng được câu trả lời của AI.
}
error-timed-out = { $whose ->
    [comfyui] ComfyUI không tạo xong hình ảnh kịp lúc.
    [llama_server] Mô hình tìm kiếm chưa sẵn sàng kịp. Hãy thử lại.
    [model] AI không trả lời kịp thời. Hãy thử lại.
    [model_server] Nhà cung cấp AI không trả lời kịp thời. Hãy thử lại.
    [search_model] Mô hình tìm kiếm không trả lời kịp lúc.
   *[other] Không có câu trả lời kịp lúc.
}
error-unreachable = { $whose ->
    [comfyui] Không kết nối được ComfyUI.
    [image_model] Không kết nối được mô hình hình ảnh.
    [model_download] Không tải được tệp của mô hình.
    [model_server] Nhà cung cấp AI không trả lời: hãy thử lại sau, hoặc kiểm tra kết nối.
    [picture_address] Không tải được hình ảnh.
    [picture_server] Không kết nối được máy chủ hình ảnh.
    [provider_voices] Không kết nối được các giọng nói của nhà cung cấp.
    [search_model] Mô hình tìm kiếm không trả lời.
    [provider_voice] Không kết nối được giọng nói của nhà cung cấp.
    [provider_search_model] Không kết nối được mô hình tìm kiếm của nhà cung cấp.
   *[other] Không kết nối được.
}
error-answered = { $whose ->
    [comfyui] ComfyUI trả lời { $status }.
    [model_server] Nhà cung cấp AI trả lời { $status }. Hãy thử lại sau.
    [picture_server] Máy chủ hình ảnh trả lời { $status }.
    [provider_voices] Giọng nói của nhà cung cấp trả lời { $status }.
    [search_model] Mô hình tìm kiếm trả lời { $status }.
   *[other] Phía bên kia trả lời { $status }.
}
error-answered-said = { $said ->
    [did_not_take_the_key] Nhà cung cấp không nhận khóa.
    [asks_for_a_key] Nhà cung cấp yêu cầu khóa.
   *[other] Nhà cung cấp không có danh sách mô hình ở địa chỉ này.
}
