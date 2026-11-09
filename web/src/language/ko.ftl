### UI 문구의 한국어판. 영어(en.ftl, 원본 파일)에서 키마다 옮긴 것. 구조 테스트(structure.test.ts)가 모든 키가
### 영어와 같은 형태로 여기 있는지 확인해요.
### 용어집. 하나의 대상에 하나의 이름, 모든 ko.*.ftl에서 공통:
###   호칭: 사용자를 가리키는 대명사는 쓰지 않아요(“당신” 없음). 영어가 사용자를 강조하는 곳(채팅의 “You”)만 “나”.
###   앱의 문장은 해요체(“저장했어요”, “선택하세요”): 요즘 한국 소비자 앱(카카오, 토스, 네이버)의 말투이고, 개인용 채팅 앱에
###   합니다체는 딱딱해요. 버튼과 라벨은 짧은 명사형(“저장”, “삭제”, “채팅 열기”). 사용자의 성별은 정하지 않아요(“그/그녀” 없음);
###   캐릭터와 계정 이름({ $name })도 마찬가지. 앱은 자신을 “저”라고 부르지 않아요: 주어는 “Cardwave” 또는 생략. 인터뷰의 AI만
###   영어가 “me”라고 하는 곳에서 “저”. 사용자 자신의 버튼(“Write for me”, “I don't know”)도 “저”(“모르겠어요”).
###   한국 사용자가 아는 외래어는 한글로. Cardwave, MCP, Claude Desktop, CSS, AI, API, Downtempo, Outrun, Retrowave,
###   Neon Wave는 라틴 문자 그대로. token = 토큰; tab = 탭; chat = 채팅; message = 메시지; character = 캐릭터;
###   card = 카드(캐릭터 파일); figure = 3D 피규어; persona = 페르소나; lorebook = 로어북; memory = 기억(페이지 “기억”);
###   document = 문서; library = 라이브러리; knowledge = 지식; account = 계정; provider = 제공자; model = 모델;
###   helper (model) = 보조 모델; tool = 도구; tag = 태그; preset = 프리셋(모델 프리셋, 프롬프트 프리셋); prompt = 프롬프트;
###   key = 키(API 키); Settings = 설정; Advanced = 고급; Trash = 휴지통(Cardwave의); Recycle Bin = Windows 휴지통(항상
###   “Windows”를 붙여 구별); backup = 백업; restore = 복원; Sharing = 공유; companion = 컴패니언; voice = 음성(페이지 “음성”);
###   read aloud = 읽어 주기; dictation = 음성 입력; picture = 이미지(Images = 이미지, image model = 이미지 모델);
###   download = 다운로드; Showcase = 쇼케이스; Search Cardwave = Cardwave 검색; coding team = 코딩 팀; planner = 플래너;
###   worker = 워커; auditor = 감사자; task = 작업; sign in/out = 로그인/로그아웃; lock = 잠금; import = 가져오기;
###   export = 내보내기; password = 비밀번호; interview = 인터뷰; generator = 캐릭터 생성기; theme = 테마; first run = 처음 설정;
###   save = 저장; delete = 삭제; edit = 편집; cancel = 취소; file = 파일; folder = 폴더; search = 검색; version = 버전;
###   format = 형식; Appearance = 모양; greeting = 인사말; entry = 항목; keyword = 키워드; Your own CSS = 사용자 CSS.
###   페르소나가 없는 사용자의 이름(card-user-stand-in, cw_prompt::stand_in_user): 게스트(이름으로 읽히고 성별이 없어요).
###   복수형(Intl.PluralRules “ko”): other만. 수에는 단위를 붙여요(“{ $count }개”, “{ $count }줄”, “{ $count }일”).
###   띄어쓰기는 표준 한국어 맞춤법대로. 이름({ $name }) 뒤에는 받침에 따라 바뀌는 조사를 바로 붙이지 않아요: “{ $name } 캐릭터가”,
###   ““{ $name }” 계정을”처럼 명사를 넣거나, “의”, “에”, “:”처럼 어떤 이름에도 맞는 형태로 바꿔요; 어쩔 수 없을 때만 “을(를)”,
###   “이(가)”, “(으)로”. 따옴표 “ ”, 쉼표로 이름 잇기 “, ”(format-comma), 구분 “ · ”, 메뉴 경로 “ › ”, 말줄임 “…”.
###   문장 속 라벨: midSentence.

## The app

app-name = Cardwave

## The pages, as tabs, the rail and Search Cardwave name them (shell/pages.ts)

page-chats = 채팅
page-characters = 캐릭터
page-lorebooks = 로어북
page-personas = 페르소나
page-memories = 기억
page-documents = 문서
page-generator = 캐릭터 생성기
page-interview = 함께 캐릭터 만들기
page-profile = 프로필
page-server = 공유
page-settings = 설정
page-providers = 제공자
page-voices = 음성
page-advanced = 고급
page-css = Cardwave의 CSS
page-written-tools = AI가 만든 도구
page-coding-team = 코딩 팀
page-trash = 휴지통
page-about = Cardwave 정보
page-coding-task = 코딩 작업
page-chat = 채팅
page-new-card = 새 캐릭터
page-lorebook = 로어북
page-card = 캐릭터
page-prompt-preset = 프롬프트 프리셋
page-first-run = Cardwave 설정하기

## The places pages are under

place-library = 라이브러리
place-knowledge = 지식
place-account = 계정
place-settings = 설정
place-advanced = 설정 › 고급

## The rail (shell/rail.ts)

rail-create = 만들기
rail-memories-tip = 기억: AI가 채팅에서 기억하는 것
rail-documents-tip = 문서: AI가 답할 때 읽는 파일
rail-show-more = { $count }개 더 보기
rail-open-menu = 사이드바 열기
rail-close-menu = 사이드바 닫기
rail-collapse = 사이드바 접기
rail-expand = 사이드바 펼치기
rail-account = 계정
rail-account-named = 계정: { $name }
rail-lock = 잠금

## Create's lines (shell/create.ts)

create-new-chat = 새 채팅
create-plain-chat = 캐릭터 없이 채팅
create-new-card = 새 캐릭터
create-from-picks = 캐릭터 생성기
create-together = 함께 캐릭터 만들기
create-new-persona = 새 페르소나
create-new-lorebook = 새 로어북
create-import-card = 카드 가져오기
create-import-lorebook = 로어북 가져오기
create-new = 새로 만들기
create-import = 가져오기

## The title bar and its tabs (shell/titlebar.ts)

tabs = 탭
tab-new = 새 탭
tab-new-keys = 새 탭 (Ctrl+T)
tabs-all = 모든 탭
tab-close = 탭 닫기
window-minimize = 최소화
window-maximize = 최대화
window-close = 닫기

## The view menu (shell/view-menu.ts, theme.ts)

view = 보기
view-compact = 컴팩트
theme-system = 시스템
theme-light = 라이트
theme-dark = 다크
theme-downtempo = Downtempo
theme-outrun = Outrun
theme-retrowave = Retrowave
theme-neonwave-dark = Neon Wave 다크
theme-neonwave-light = Neon Wave 라이트

## Search Cardwave's button (shell/search-panel.ts)

search = Cardwave 검색
search-keys = Cardwave 검색 (Ctrl+K)

## The labels of the settings, as their pages and Search Cardwave name them (setting-labels.ts)

label-settings-theme = 테마
label-settings-chat-layout = 채팅 레이아웃
label-settings-web-pictures = 다른 웹사이트의 이미지 표시
label-settings-app-language = 앱 언어
label-settings-language = AI가 쓰는 언어
label-settings-providers = 제공자
label-settings-chat = 채팅
label-settings-images = 이미지
label-settings-voice = 음성
label-settings-search = 검색
label-settings-dictation = 음성 입력
label-settings-web = 웹
label-settings-files = 파일
label-settings-commands = 명령
label-settings-image-generation = 이미지 생성
label-settings-app = Cardwave
label-settings-dice = 주사위
label-settings-folder = 폴더
label-settings-written = AI가 만든 도구
label-settings-coding = 코딩 팀
label-settings-trash = 휴지통
label-settings-backup = 백업
label-settings-restore = 복원
label-settings-cards-folder = 카드 폴더
label-settings-advanced = 고급
label-settings-setup = 처음 설정 다시 하기
label-settings-about = Cardwave 정보
label-providers-this-computer = 이 컴퓨터
label-voices-model = 음성 모델
label-voices-speed = 속도
label-voices-english = 영어
label-advanced-background = 보조 모델
label-advanced-told = AI에게 전하는 내용
label-advanced-describe = 가져온 캐릭터 설명하기
label-advanced-described = 설명된 캐릭터
label-advanced-interview = 함께 캐릭터 만들기
label-advanced-format = 내보내기 형식
label-advanced-history = 각 텍스트의 이전 버전 포함
label-advanced-css = 사용자 CSS
label-coding-planner = 플래너
label-coding-workers = 워커
label-coding-auditor = 감사자
label-profile-name = 이름
label-profile-picture = 이미지
label-profile-password = 비밀번호
label-server-network = 홈 네트워크에서 접속 가능
label-server-address = 주소
label-server-mcp = 이 컴퓨터의 AI 앱이 Cardwave를 쓰게 하기

layout-bubbles = 말풍선
layout-plain = 일반

## Settings (views/settings.ts)

settings-appearance = 모양
settings-theme-about = 직접 고르지 않으면 시스템을 따라요
settings-layout-about = 메시지를 말풍선으로, 또는 일반 텍스트로
settings-web-pictures-about = 채팅을 열면 그 웹사이트들이 알 수 있어요.
settings-language = 언어
settings-data = 데이터
settings-trash-about = { $count ->
   *[other] 항목 { $count }개
  } · { $days }일 후 비움
settings-open-trash = 휴지통 열기
settings-open = 열기
settings-version = 버전 { $version } · 라이선스
settings-licences = 라이선스
settings-advanced-about = 보조 모델, 라이브러리, 내보내기, 캐릭터 없는 채팅, 샘플링, 프리셋, 사용자 CSS
settings-setup-about = 제공자, 모델, 음성을 단계별로
settings-providers-about = 모델을 실행하는 서비스의 주소와 키
settings-this-computer = 이 컴퓨터
settings-providers-named = 설정됨: { $names }
settings-models = 모델
settings-the-chat-model = 채팅 모델
settings-the-image-model = 이미지 모델

## The account's tabs and accounts (shell/account-tabs.ts, settings/accounts.ts)

account-sections = 계정 섹션
account-switch = 계정 전환

account-password = 비밀번호
account-switch-to = { $name } 계정으로 전환
account-password-asked = { $name }의 비밀번호를 입력하세요.
account-switch-button = 전환
account-add = 계정 추가
account-add-about = 이 컴퓨터에 있는 다른 사람의 계정으로, 채팅과 캐릭터를 따로 가져요. 그 계정은 여기서나 다른 기기에서 자기 비밀번호로 로그인해요.
account-name = 이름
account-added = “{ $name }” 계정을 추가했어요.
account-add-button = 추가
account-sign-out = 로그아웃
account-none = 로그인할 계정이 없어요
account-none-about = 아직 여기서 로그인할 수 있는 계정이 없습니다. Cardwave가 실행되는 컴퓨터에서 계정 › 공유에 하나 추가하세요.
account-this-computer = 이 컴퓨터의 계정
account-choose = 계정을 선택하세요
account-try-again = 다시 시도
account-back = 뒤로
account-sign-in = 로그인

## Backup and Restore (settings/backup.ts)

backup-saving = 백업을 저장하는 중이에요.
backup-saving-to = { $folder }에 백업을 저장하는 중이에요.
backup-password = 비밀번호
backup-repeat = 비밀번호 확인
backup-encrypted = 백업은 이 비밀번호로 암호화돼요. 여기서든 다른 컴퓨터에서든 복원하려면 이 비밀번호가 필요해요.
backup-forgotten = 잊어버린 비밀번호는 되찾을 수 없고, 비밀번호 없이는 백업을 복원할 수 없어요.
backup-with-password = 비밀번호로 백업
backup-differ = 두 비밀번호가 달라요.
backup-back-up = 백업 저장
backup-no-file = 선택한 파일 없음
backup-choose-file = 파일 선택
backup-its-password = 백업의 비밀번호
backup-restoring = 복원하면 Cardwave의 모든 것이 바뀌어요: 채팅, 캐릭터, 페르소나, 로어북, 기억, 설정. 되돌릴 수 없어요. 여기서 정한 비밀번호는 그대로 유지돼요. 다른 계정도 바뀌어요.
backup-restored = 백업을 복원했어요: Cardwave의 모든 것이 백업했을 때로 돌아갔어요. 다른 기기는 다시 로그인해요.
backup-file = 파일
backup-restore-title = 백업 복원
backup-choose-first = 먼저 백업 파일을 선택하세요.
backup-restore = 백업 복원
backup-from-file = 백업 파일에서
backup-about-own = 채팅, 캐릭터, 설정을 하나의 파일로, 계정 비밀번호로 암호화
backup-about-chosen = 채팅, 캐릭터, 설정을 하나의 파일로, 직접 정한 비밀번호로 암호화

## The folder of cards (settings/card-folder.ts)

folder-watch = 새 카드 자동으로 가져오기
folder-watch-about = 폴더에 넣은 카드 파일이 저절로 라이브러리에 들어와요
folder-recycle = 가져온 파일을 Windows 휴지통으로 이동
folder-recycle-about = 파일을 가져오면 휴지통으로 옮겨집니다

## The companion's line (library/companion-app.ts)

companion = 컴패니언
# 컴패니언 창의 이름. 시스템이 창 목록에 표시해요.
companion-window = Cardwave 컴패니언
companion-made = 이제 { $name } 캐릭터가 컴패니언이에요.
companion-make = 컴패니언으로 만들기
companion-none = 아직 컴패니언이 없어요. 캐릭터의 “…” 메뉴를 열고 “컴패니언으로 만들기”를 고르세요.
companion-named = { $name } · 앱과 함께 시작
companion-figure = 컴패니언 피규어
companion-figure-about = 자체 3D 피규어가 없는 캐릭터에게 표시돼요
companion-figure-woman = 여성
companion-figure-man = 남성
companion-figure-robot = 로봇
companion-size = 컴패니언 크기
companion-size-about = 화면 높이에 대한 피규어 높이의 비율
companion-size-value = { $size }%

## Other programs, MCP (settings/mcp.ts)

mcp-ask-title = 이 컴퓨터의 AI 앱이 Cardwave를 쓰게 하기
mcp-ask = 이 컴퓨터의 프로그램(예: Claude Desktop)은 캐릭터와 채팅을 읽고, 채팅에 쓰고, 설정 › 도구에서 켠 도구를 쓸 수 있습니다. Cardwave가 먼저 물어볼 일은 그 프로그램들이 할 수 없습니다.
mcp-switch-on = 켜기
mcp-about = Claude Desktop 등, MCP를 통해: 캐릭터, 채팅, 도구를 사용합니다
mcp-copy-address = MCP 주소 복사
mcp-copy = 복사
mcp-as-account = 사용할 계정
mcp-as-account-about = 볼 수 있는 것과 할 수 있는 것
mcp-remove-named = { $program } 제거
mcp-removed = “{ $program }” 프로그램을 제거했어요.
mcp-remove = 제거
mcp-connected = 연결됨
mcp-other-programs = 다른 프로그램
mcp-only-here = 이 컴퓨터의 프로그램만 연결할 수 있어요. 제거한 프로그램은 이 설정을 껐다 켤 때까지 연결할 수 없어요.

## Your own CSS (settings/own-css.ts)

css-none = 없음
css-lines = { $count ->
   *[other] { $count }줄
  }
css-about = { $lines } · 앱의 모양을 바꿔요
css-hint = Cardwave 자체 스타일시트 다음에, 입력하는 대로 적용돼요. 저장하면 유지되고, 취소하면 되돌려져요.
css-edit-own = 사용자 CSS 편집
css-edit = 편집

## The password (settings/password.ts)

password-forgotten = 잊어버린 비밀번호는 복구할 수 없으며, 채팅과 캐릭터도 함께 잃게 됩니다. 안전한 곳에 보관하세요.
password-on-title = 비밀번호 설정
password-on-says = Cardwave가 열릴 때 이를 묻습니다. 이것 없이는 아무도 이 컴퓨터에서 Cardwave를 열거나 채팅을 읽을 수 없습니다.
password-on = 비밀번호 설정
password-on-done = 비밀번호를 설정했어요.
password-change-title = 비밀번호 변경
password-change-says = Cardwave를 열 때 새 비밀번호를 물어요.
password-change = 변경
password-change-done = 비밀번호를 바꿨어요.
password-off-title = 비밀번호 끄기
password-off-says = Cardwave가 비밀번호를 묻지 않고 열려요. 채팅과 캐릭터는 암호화된 채로 있어요.
password-off = 끄기
password-off-done = 비밀번호를 껐어요.
password-differ = 두 비밀번호가 달라요.
password-other-says = 그때부터 새 비밀번호로 로그인해요.
password-other-forgotten = 잊어버리면 공유에서 이 컴퓨터의 계정이 재설정할 수 있어요.
password-current = 현재 비밀번호
password-password = 비밀번호
password-new = 새 비밀번호
password-repeat = 비밀번호 확인
password-asked-sign-in = 로그인할 때 물어봐요
password-is-on = 켜짐 · 앱을 열 때 물어봐요
password-is-off = 꺼짐 · 이 컴퓨터에서는 누구나 Cardwave를 열 수 있음
password-start-forgotten = 잊어버린 비밀번호는 되찾을 수 없어요.
password-open = 열기
password-locked-elsewhere = Cardwave가 원래 컴퓨터에서 잠겨 있어요. 그곳에서 잠금이 풀리면 여기서도 열려요.
password-back = 뒤로

## Words many pages use

common-use = 사용
common-in-use = { " " }· 사용 중
common-more = 더 보기
common-edit = 편집
common-duplicate = 복제
# 사본 이름 끝에 붙는 말. 예: “Rig (사본)”.
common-copy-word = 사본
common-delete = 삭제
common-save = 저장
common-cancel = 취소
common-name = 이름

## Model presets and prompt presets (settings/presets.ts, settings/prompt-presets.ts)

preset-what = 프리셋은 채팅 모델과 그 샘플링 값을 저장해요. “사용”을 누르면 그 프리셋으로 바뀌어요.
preset-temperature = temperature { $value }
preset-new = 새 프리셋
preset-model-presets = 모델 프리셋
preset-using = “{ $name }” 프리셋 사용 중.
preset-added = “{ $name }” 프리셋을 추가했어요.
preset-deleted = “{ $name }” 프리셋을 삭제했어요.
preset-saved = “{ $name }” 프리셋을 저장했어요.
preset-delete-ask = 이 프리셋을 삭제할까요?
preset-replace = 현재 모델과 설정 사용
preset-replace-hint = 채팅 모델, 그 제공자, 이 페이지의 샘플링. 끄면: 프리셋이 자기 것을 유지합니다.
preset-keeps-hint = 설정 › 모델의 채팅 모델, 그 제공자, 이 페이지의 샘플링을 유지해요.
preset-name = 이름
preset-edit = 프리셋 편집
prompt-presets = 프롬프트 프리셋
prompt-system = 시스템 프롬프트
prompt-note = { $depth ->
   *[other] 메모, 메시지 { $depth }개 앞
}
prompt-system-note = { $depth ->
   *[other] 시스템 프롬프트 · 메모, 메시지 { $depth }개 앞
}
prompt-as-card = 캐릭터에 적힌 대로
prompt-default = 기본값
prompt-default-name = “{ $name }” 프롬프트는 캐릭터 자체 프롬프트예요.

## Tools (settings/tools.ts, chat/tool-ask.ts)

tools-written-ask = { $count ->
    [0] 아직 없음
   *[other] 도구 { $count }개
  } · 새 도구는 실행 전에 물어봐요
tools-written-free = { $count ->
    [0] 아직 없음
   *[other] 도구 { $count }개
  } · 새 도구는 묻지 않고 실행돼요
tools-folder-first = 먼저 폴더를 선택하세요
tools-web = 웹 페이지 검색하고 읽기
tools-files = { $folder }만
tools-ask-writes = 쓰기 전에 묻기
tools-ask-writes-says = 각 파일을 쓰기 전에 보여 줘요
tools-commands = { $folder }에서 실행, 컴퓨터의 나머지 부분과 인터넷에서는 차단
tools-ask-commands = 실행 전에 묻기
tools-ask-commands-says = 각 명령을 실행하기 전에 보여 줘요
tools-pictures = 이미지 모델 사용
tools-pictures-first = 먼저 이미지 모델을 설정하세요
tools-app = 캐릭터, 채팅, 설정을 사용하고 바꾸기. 바꿀 때마다 먼저 물어봐요
tools-dice = AI가 주사위를 굴리게 합니다. 굴리는 건 Cardwave라 결과가 공정합니다.
tools-folder-example = C:\Users\you\Documents\Shared
tools-folder-says = 파일과 명령은 이 폴더와 그 안의 것에만 닿고, 그 밖에는 닿지 않아요.
tools-change-folder = 폴더 변경
tools-change = 변경
tools-choose = 선택
tools-none-chosen = 선택 안 함
tools-title = 도구
tools-ask-new = { $name }이(가) 새 도구를 쓰려고 해요: { $what }
tools-ask-write = { $name }이(가) 폴더에 “{ $what }”을(를) 쓰려고 해요:
tools-ask-read = { $name }이(가) 폴더에서 읽으려고 해요:
tools-ask-install = { $name }이(가) 필요한 프로그램을 내려받아 설치하려고 해요:
tools-ask-web = { $name }이(가) 웹을 쓰려고 해요:
tools-ask-app = { $name }이(가) Cardwave를 바꾸려고 해요:
tools-ask-command = { $name }이(가) 폴더에서 명령을 실행하려고 해요:
tools-allow = 허용
tools-deny = 거부
tools-allow-writing = 이 채팅에서 파일 쓰기 허용
tools-allow-commands = 이 채팅에서 명령 허용

## Updates (settings/update.ts)

update-title = 업데이트 확인
update-available = Cardwave { $version } 버전을 사용할 수 있어요
update-you-have = 현재 버전: { $version }.
update-up-to-date = Cardwave가 최신 버전이에요 ({ $version }).
update-connection-error = 업데이트를 확인하지 못했어요. 인터넷 연결을 확인하세요.
update-check-failed = 업데이트를 확인하지 못했어요: GitHub가 최신 버전 정보를 보내지 않았어요.
update-whats-new = 새로운 기능
update-close = 닫기
update-ok = 확인
update-download = 다운로드
update-install = 업데이트 후 다시 시작
update-installing = Cardwave { $version } 다운로드 중…
update-auto = 자동으로 확인
update-auto-about = 시작할 때와 하루에 한 번 새 버전 찾기
update-check = 확인
update-checking = 확인 중…
update-about = 앱의 새 버전이 있는지 확인해요.

## The breadcrumbs of a page under Settings

crumbs = 현재 위치

## Providers (views/providers.ts)

providers-key-end = { $where } · 키 ····{ $end }
providers-key-saved = { $where } · 키 저장됨
providers-no-key = { $where } · 키 없음
providers-thinking-cannot = { $provider }에서는 이 모델의 생각하기를 끌 수 없어요
providers-thinking-off = 모델이 먼저 생각하지 않고 답해요
providers-thinking-on = 모델이 답하기 전에 생각해요
providers-comfy-default = ComfyUI 기본값
providers-workflow-note = 이 워크플로는 이미지 모델이 아닌 자체 모델과 크기를 사용해요.
providers-testing-model = 모델 테스트 중…
providers-thinking-of = { $label }: 생각하기
providers-thinking = 생각하기
providers-testing-workflow = 워크플로 테스트 중…
providers-workflows-from = ComfyUI에 있는 워크플로에서
providers-pictures-by = “{ $name }” 워크플로로 만드는 이미지.
providers-pictures-default = ComfyUI 기본 워크플로로 만드는 이미지.
providers-workflow = 워크플로
providers-not-used = 아직 아무 데도 쓰이지 않음
providers-folder-saved = 폴더를 저장했어요.
providers-change-folder = 모델 폴더 변경
providers-choose-folder = 모델 폴더 선택
providers-change = 변경
providers-not-set-up = 설정 안 됨
providers-folder-not-set-up = 이 컴퓨터의 폴더에 있는 모델을 실행해요 · 설정 안 됨
providers-menu = 제공자 메뉴: 편집, 제거
providers-remove = 제거
providers-removed = “{ $name }” 제공자를 제거했어요.
providers-remove-with-models = 이 제공자를 제거할까요? 여기서 고른 모델은 더 이상 쓰이지 않습니다.
providers-remove-ask = 이 제공자를 제거할까요?
providers-remove-key = 키 제거
providers-key-removed = 저장하면 키가 제거돼요
providers-edit = 제공자 편집
providers-keep-key = 저장된 키를 유지하려면 비워 두세요.
providers-saved = “{ $name }” 제공자를 저장했어요.
providers-added = “{ $name }” 제공자를 추가했어요.
providers-add = 제공자 추가
providers-about = AI가 실행되는 곳: 인터넷 서비스나 이 컴퓨터의 프로그램이에요. 각각 아래에 어디에 쓰이는지 나와요.

## Voices (views/voices.ts)

voices-stop = { $name } 정지
voices-try = { $name } 들어 보기
voices-model-about = 이 컴퓨터에서 메시지를 소리 내어 읽어요 · { $size }
voices-default-of = 기본 음성: { $name }
voices-menu = 음성 메뉴: 이름 바꾸기, 삭제
voices-rename = 이름 바꾸기
voices-delete-ask = 목소리 “{ $name }”을(를) 삭제할까요? 이 목소리를 쓰는 캐릭터는 기본 목소리로 돌아갑니다.
voices-rename-title = 음성 이름 바꾸기
voices-name = 이름
voices-speed-value = { $speed }×
voices-speed = 속도
voices-speed-about = 답을 읽어 주는 속도, 모든 음성에 적용
voices-make = 녹음으로 음성 만들기
voices-provider-failed = 제공자의 음성을 불러오지 못했어요.
voices-provider-none = 제공자가 음성 목록을 주지 않아요
voices-provider-own = 메시지는 제공자의 자체 목소리로 읽힙니다.
voices-voices = 음성
voices-voices-about = 메시지를 소리 내어 읽는 음성이에요. 캐릭터마다 '캐릭터 음성'에서 따로 정할 수 있어요.
voices-default = 기본 음성
voices-voice-of = { $name }의 음성
voices-back-default = 기본 음성으로 되돌리기
voices-name-title = { $name } · { $title }
voices-choose-character = 캐릭터 선택
voices-all-have = 모든 캐릭터에 음성이 있어요.
voices-set-for = 캐릭터 음성 정하기
voices-character = 캐릭터
voices-voice = 음성
voices-character-first = 먼저 캐릭터를 선택하세요.
voices-characters = 캐릭터 음성
voices-downloading = 다운로드 중 · { $size } · { $percent }%
voices-downloaded = 다운로드됨 · { $size }
voices-download-size = { $size } 다운로드
voices-action-of = { $name } { $action }
voices-language-downloaded = { $name } 다운로드됨
voices-built-in = 기본 제공
voices-languages = 읽어 주는 언어
voices-download = 다운로드
voices-cancel = 취소
voices-delete = 삭제

## Advanced (views/advanced.ts)

advanced-context-size = 컨텍스트 크기 (토큰)
advanced-context-hint = 비워 두면 128,000
advanced-temperature = Temperature
advanced-temperature-about = 높을수록 더 뜻밖의 답장. 0부터 2까지
advanced-top-p = Top P
advanced-top-p-about = 낮을수록 가장 그럴듯한 단어만. 0부터 1까지
advanced-frequency = Frequency penalty
advanced-frequency-about = 높을수록 반복되는 단어가 줄어듭니다. −2부터 2까지
advanced-presence = Presence penalty
advanced-presence-about = 높을수록 새로운 화제가 늘어납니다. −2부터 2까지
advanced-seed = 시드
advanced-seed-about = 같은 숫자면 같은 답장이 다시 나옵니다
advanced-from-to = { $min }~{ $max }
advanced-whole-from = { $min } 이상의 정수
advanced-whole = 정수
advanced-number = 숫자
advanced-sampling = 샘플링
advanced-sampling-about = 채팅 모델용. 제공자 기본값을 쓰려면 값을 비워 두세요. 입력하는 대로 저장돼요.
advanced-describing = 설명하는 중… { $count }개 남음
advanced-all-described = 모든 캐릭터가 설명되었어요
advanced-not-described = { $count ->
   *[other] 캐릭터 { $count }명
  } 아직 설명 안 됨
advanced-describe-cards = 캐릭터 설명하기
advanced-describe-cost = { $count ->
   *[other] 캐릭터 { $count }명
  }에 약 { $low }~{ $high } 토큰
advanced-failed = { $count ->
   *[other] { $count }개 실패
  }: { $failure }. 다시 시도하려면 캐릭터 설명하기를 누르세요.
advanced-describe-again = 모두 다시 설명하기
advanced-describe-again-stop = 중지
advanced-describe-again-about = 도우미 모델로 모든 캐릭터의 한 줄 설명, 요약, 태그, '필요별'이 찾는 기준을 다시 씁니다. 캐릭터당 약 11,000~12,000 토큰. 직접 편집한 내용은 그대로 남습니다. 토큰은 제공자가 요금을 매기는 단위입니다.
advanced-no-characters = 설명할 캐릭터가 없어요
advanced-describe-again-far = { $all }개 중 { $done }개 다시 설명함
advanced-describe-again-stopped = { $all }개 중 { $done }개 다시 설명하고 멈춤
advanced-describe-again-failed = { $count ->
   *[other] { $count }개는 실패해서 그대로 남음
  }: { $failure }. 한 번 더 시도하려면 모두 다시 설명하기를 누르세요.
advanced-describe-about = 캐릭터마다 한 줄 소개, 요약, 태그를 보조 모델이 써요
advanced-plain = 캐릭터 없이 채팅
advanced-told-about = 캐릭터 없는 모든 채팅에서 같습니다. { "{{date}}" } 또는 { "{{time}}" }를 쓰면 AI가 오늘 날짜나 시각을 받습니다
advanced-library = 라이브러리
advanced-interview-about = AI가 당신에게 질문하는 방식
advanced-interview-tree = 트리
advanced-interview-cloud = 클라우드
advanced-interview-hybrid = 하이브리드
advanced-data = 데이터
advanced-format-about = 내보내기가 모든 카드를 쓰는 형식. 대부분의 앱은 SillyTavern V3를 엽니다
advanced-history-about = 각 텍스트의 이전 버전. Cardwave 자체 카드 형식에서만
advanced-helper = 보조 모델
advanced-the-helper = 보조 모델

## Cardwave's CSS (views/css-reference.ts)

cssref-rail = 왼쪽 레일
cssref-main = 레일 옆의 화면
cssref-crumbs = 페이지 맨 위의 경로
cssref-group = 설정처럼 줄을 묶은 상자
cssref-item = 상자의 한 줄
cssref-row = 목록의 한 줄
cssref-tile = 라이브러리 격자의 카드
cssref-msg = 채팅의 메시지
cssref-bubble = 메시지의 말풍선
cssref-composer = 채팅 아래의 메시지 입력란
cssref-dialog = 대화상자
cssref-btn-primary = 파란 버튼
cssref-switch = 스위치
cssref-pill = 알약 모양 라벨
cssref-notice = 창 아래쪽의 알림
cssref-snippet-green = 초록색 강조
cssref-snippet-square = 네모난 말풍선
cssref-snippet-larger = 더 큰 글자
cssref-snippet-wider = 더 넓은 대화상자
cssref-snippet-tighter = 더 좁은 간격
cssref-snippet-black = 검은 다크 테마
cssref-in-dark = { $light } · 다크에서는 { $dark }
cssref-none = 그런 이름의 변수가 없어요.
cssref-copy-of = “{ $title }” 복사
cssref-copied = 복사했어요.
cssref-copy = 복사
cssref-about-1 = 사용자 CSS에서 쓸 수 있는 변수와 클래스 이름이에요. 앱의 모든 색과 크기는{ " " }
cssref-about-2 = 의 변수이고, 라이트 값과 다크 값이 있어요.
cssref-variables = 변수
cssref-search = 검색
cssref-find = 변수 찾기
cssref-all = 변수 모두 { $count }개.
cssref-classes = 클래스 이름
cssref-snippets = 스니펫

## Tools the AI wrote (views/written-tools.ts)

written-about = { $what } · { $made } 만듦
written-about-in = { $what } · { $made } { $chat }에서 만듦
written-used = { $count ->
    [0] 아직 사용 안 함
   *[other] { $count }번 사용
  }
written-none = 아직 도구가 없습니다. 채팅에서 “AI가 도구를 쓰게 하기”를 켜면 AI가 쓴 것이 여기에 표시됩니다.
written-ask = 새 도구를 실행하기 전에 묻기
written-ask-about = 도구마다 한 번: 처음 실행될 때 허용합니다
written-in = { " " }· 채팅:{ " " }
written-made = { $made } 만듦
written-dot-used = { " " }· { $used }
written-switch-off = 끄기
written-switch-on = 켜기
written-intro = “AI가 도구를 쓰게 하기”가 켜진 채팅에서 AI가 스스로 쓴 작은 도구입니다. 허용할 때만 파일에 손대며, 이후 채팅을 위해 보관됩니다.
written-deleted = “{ $name }” 도구를 삭제했어요.
written-on = { $name } 켜기
written-view-code = 코드 보기

## The coding team, shared by the chat and its pages (chat/coding.ts)

coding-quick = 빠르게
coding-balanced = 균형
coding-thorough = 꼼꼼하게
coding-custom = 사용자 지정
coding-running = 실행 중
coding-done = 완료
coding-failed = 실패
coding-stopped = 중지됨
coding-team-says-alone = { $name }: 플래너 1명, { $workers ->
    [1] 워커 1명
    [2] 워커 2명
   *[other] 워커 3명
  }, 감사자 없음.
coding-team-says-tests = { $name }: 플래너 1명, { $workers ->
    [1] 워커 1명
    [2] 워커 2명
   *[other] 워커 3명
  }, 테스트를 실행하는 감사자 1명.
coding-team-says-steps = { $name }: 플래너 1명, { $workers ->
    [1] 워커 1명
    [2] 워커 2명
   *[other] 워커 3명
  }, 모든 단계를 확인하고 테스트를 실행하는 감사자 1명.
coding-team-label = { $name } · { $workers ->
   *[other] 워커 { $workers }명
  }
coding-team-label-auditor = { $name } · { $workers ->
   *[other] 워커 { $workers }명
  }, 감사자
coding-team-label-steps = { $name } · { $workers ->
   *[other] 워커 { $workers }명
  }, 단계마다 감사자
coding-tests-pass = 테스트 { $total }개 중 { $passed }개 통과
coding-passed = 통과
coding-problems = 문제 발견

## Coding team (views/coding-team.ts)

team-audit-end = 마지막에
team-audit-each = 단계마다
team-audit-never = 안 함
team-change = 변경
team-workers-of = { $model } · 동시에 { $workers }
team-worker-model = 워커 모델
team-change-worker = 워커 모델 변경
team-how-many = 워커 수
team-none = 없음
team-auditor-tests = { $model } · 테스트 실행
team-auditor-steps = { $model } · 모든 단계 확인
team-auditor-model = 감사자 모델
team-change-auditor = 감사자 모델 변경
team-when = 감사자가 확인하는 때
team-team = 팀
team-roles = 역할
team-planner-model = 플래너 모델
team-change-planner = 플래너 모델 변경
team-recent = 최근 작업
team-intro = 이 컴퓨터에서 함께 프로그램을 써 주는 AI들로, 채팅에서 시작합니다.
team-no-tasks = 아직 작업이 없습니다. 작업은 채팅에서 메시지 입력란 옆의 “+” › 코딩 작업 시작으로 시작합니다.

## Trash (views/trash.ts)

trash-expressions = 표정 · 어떤 캐릭터에도 없음
trash-figure = 3D 피규어 · 어떤 캐릭터에도 없음
trash-chat-with = 채팅: { $names }
trash-chat = 채팅
trash-persona = 페르소나
trash-persona-used = 페르소나 · { $count ->
   *[other] 채팅 { $count }개에서 사용
  }
trash-lorebook = 로어북
trash-lorebook-used = 로어북 · { $count ->
   *[other] 채팅 { $count }개에서 사용
  }
trash-character = 캐릭터
trash-character-chats = 캐릭터 · 채팅 { $count ->
   *[other] { $count }개
  }
trash-empty = 휴지통이 비어 있어요.
trash-about = 여기로 옮긴 것은 { $days }일 동안 보관된 뒤 영구 삭제돼요.
trash-emptied = 휴지통을 비웠어요.
trash-empty-trash = 휴지통 비우기
trash-delete-all-ask = { $count ->
   *[other] 항목 { $count }개를 모두
  } 영구 삭제할까요?
trash-restored = “{ $title }” 항목을 복원했어요.
trash-deleted = “{ $title }” 항목을 영구 삭제했어요.
trash-deleted-at = 여기로 옮김: { $when }
trash-days-left = { $count ->
   *[other] { $count }일 남음
  }
trash-restore = 복원
trash-restore-chats = 캐릭터와 { $count ->
   *[other] 채팅 { $count }개
  }를 되돌려요
trash-delete-forever = 영구 삭제
trash-delete-forever-ask = “{ $title }”을(를) 영구 삭제할까요? 되돌릴 수 없어요.
trash-delete-forever-ask-chats = “{ $title }”과(와) { $count ->
   *[other] 채팅 { $count }개
  }를 영구 삭제할까요? 되돌릴 수 없어요.

## About Cardwave (views/about.ts)

about-no-package = 그런 이름의 패키지가 없어요.
about-no-notes = 이 버전에는 릴리스 노트가 없어요.
about-by = 만든 이: { $by }
about-licence-of = { $name } 라이선스
about-licence = 라이선스
about-folder-failed = 폴더를 열지 못했습니다: { $reason }. 위치는 { $where }입니다.
about-open-folder = 폴더 열기
about-logs-where = Cardwave가 실행되는 컴퓨터의 Cardwave 데이터 폴더 안 “logs” 폴더
about-logs = 로그
about-logs-about = Cardwave가 한 일과 충돌 기록, 하루에 한 파일, 7일간 보관: 문제가 생겼을 때 도움을 받기 위해 · { $where }
about-version = 버전 { $version }
about-whats-new = 새로운 기능
about-community = Discord에서 Cardwave 커뮤니티에 참여하기
about-packages = 패키지 { $count }개
about-open-source = 오픈 소스 소프트웨어
about-search = 검색
about-find = 패키지 찾기
about-version-built = 버전 { $version } · { $built }
about-models = 모델
about-figures = 피규어와 애니메이션
about-voices = 음성
about-voice-donations = 기부된 목소리
about-voice-acted-by = 목소리 연기: { $name }
about-voice-vctk = CSTR VCTK Corpus(Junichi Yamagishi, Christophe Veaux, Kirsten MacDonald, University of Edinburgh)의 화자 { $speaker }, Kyutai가 정리
about-voice-cml-tts = CML-TTS(Frederico S. Oliveira, Edresson Casanova, Arnaldo Candido Junior, Anderson S. Soares, Arlindo R. Galvão Filho)의 화자 { $speaker }, LibriVox를 위해 낭독
about-voice-cml-tts-cleaned = CML-TTS(Frederico S. Oliveira, Edresson Casanova, Arnaldo Candido Junior, Anderson S. Soares, Arlindo R. Galvão Filho)의 화자 { $speaker }, LibriVox를 위해 낭독, Kyutai가 정리
about-lists = 제공자 및 모델 목록

about-or = 또는
about-and = 및
about-with = +

## Prompt preset (views/prompt-preset.ts)

prompt-new = 새 프롬프트 프리셋
promptpage-system = 시스템 프롬프트
prompt-system-about = 카드의 시스템 프롬프트를 대신해요. 카드의 것을 유지하려면 비워 두세요.
promptpage-note = 메모
prompt-note-about = AI가 매번 답하기 전에 읽으며, 채팅에는 보이지 않습니다. 아래에서 정한 만큼 이전 메시지 위치에 들어갑니다.
prompt-depth = 메시지 앞
prompt-intro = AI를 위한 지시입니다. 채팅의 사이드 패널에서 이 프리셋을 고르면 그 채팅에 쓰입니다.
prompt-depth-about = 1이면 가장 새 메시지 바로 앞, 4면 네 메시지 앞입니다.
prompt-saved = “{ $name }” 프리셋을 저장했어요.
prompt-gone = 이 프롬프트 프리셋은 삭제되었습니다. 돌아가서 다른 것을 고르세요.

## Profile (views/profile.ts)

profile-change-picture = 이미지 변경
profile-change = 변경
profile-remove-picture = 이미지 제거
profile-remove = 제거
profile-picture-changed = 이미지를 바꿨어요.
profile-picture-removed = 이미지를 제거했어요.
profile-your-picture = 프로필 이미지
profile-no-picture = 사진 없음: 머리글자 { $letter }가 표시됩니다
profile-change-name = 이름 변경
profile-this-computer = 이 컴퓨터의 계정
profile-on-server = 이 컴퓨터의 계정
profile-account = 계정

## Server (views/server.ts)

server-copy = 복사
server-no-network = 이 컴퓨터는 네트워크에 연결되어 있지 않습니다. 다른 기기가 들어오려면 Wi-Fi나 케이블로 연결하세요.
server-switch-on-about = 그러면 이 네트워크의 휴대폰과 다른 컴퓨터에서 Cardwave를 열 수 있어요. 각 계정은 자기 비밀번호로 로그인해요.
server-switch-on = 켜기
server-network-about = 휴대폰과 다른 컴퓨터가 브라우저에서 Cardwave를 열어요
server-other-devices = 다른 기기
server-inside = 라우터에서 외부 접속을 허용하지 않는 한 이 네트워크의 기기만 접속할 수 있습니다.
server-add-account = 계정 추가
server-owner = 이 컴퓨터 · 계정을 추가하고 삭제할 수 있음
server-more-of = 더 보기: { $name }
server-reset-password = 비밀번호 재설정
server-delete-account = 계정 삭제
server-deleted = “{ $name }” 계정을 삭제했어요.
server-delete-ask = 이 계정을 캐릭터, 채팅, 설정과 함께 삭제할까요? 되돌릴 수 없습니다.
server-reset-title = { $name } 계정의 비밀번호 재설정
server-reset-about = 계정은 새 비밀번호로 로그인하고, 로그인되어 있던 모든 곳에서 로그아웃돼요.
server-new-password = 새 비밀번호
server-reset-done = { $name } 계정의 비밀번호를 재설정했어요.
server-reset = 재설정
server-accounts = 계정

## Character generator (views/generator.ts)

gen-gender-woman = 여성
gen-gender-man = 남성
gen-gender-non-binary = 논바이너리
gen-being-human = 인간
gen-being-not-human = 인간 아님
gen-age-20s = 20대
gen-age-30s = 30대
gen-age-40s = 40대
gen-age-50s-and-older = 50대 이상
gen-build-slim = 날씬함
gen-build-average = 보통
gen-build-athletic = 탄탄함
gen-build-strong = 건장함
gen-hair-short = 짧은 머리
gen-hair-medium = 중간 길이
gen-hair-long = 긴 머리
gen-colour-black = 검은색
gen-colour-brown = 갈색
gen-colour-blonde = 금색
gen-colour-red = 빨간색
gen-colour-grey = 회색
gen-colour-white = 흰색
gen-relation-stranger = 낯선 사람
gen-relation-friend = 친구
gen-relation-partner = 연인
gen-relation-rival = 라이벌
gen-relation-colleague = 동료
gen-relation-mentor = 멘토
gen-shy = 수줍음
gen-outgoing = 외향적
gen-gentle = 다정함
gen-harsh = 거침
gen-serious = 진지함
gen-playful = 장난스러움
gen-cautious = 신중함
gen-bold = 대담함
gen-random = 무작위
gen-slider = { $low }~{ $high }
gen-looks = 외모
gen-gender = 성별
gen-being = 인간 여부
gen-any = 상관없음
gen-age = 나이
gen-build = 체형
gen-hair = 머리
gen-hair-colour = 머리 색
gen-personality = 성격
gen-relates = 캐릭터가 당신에게 어떤 존재인지
gen-make = 캐릭터 만들기
gen-what = 특징 몇 가지를 고르면 AI가 캐릭터의 첫 메시지와 말투를 씁니다.
interview-goes-to = 캐릭터를 쓰기 위해 답변이 { $provider }에 전송돼요.
interview-stays = 답변은 이 컴퓨터에만 남아요.
interview-own-words = 또는 직접 말을 덧붙이기
interview-in-own-words = 직접 말로
interview-your-answer = 답변
interview-pick-one = 하나 고르기
interview-pick-two = 한두 개 고르기
interview-pick-three = 세 개까지 고르기
interview-pick-many = 맞는 것을 모두 고르기
interview-few-words = 몇 마디면 충분해요
interview-wanted-hint = 사람들, 또는 써 본 캐릭터에게서 무엇이 아쉬웠나요?
interview-needs-hint = 캐릭터와 보내는 시간에 대한 것이지, 삶 전체에 대한 것은 아니에요
interview-next = 다음
interview-skip = 건너뛰기
interview-dont-know = 모르겠어요
interview-back = 뒤로
interview-just-make-it = 그냥 만들어 주세요
interview-more = 다른 종류
interview-writing-next = 다음 질문을 쓰는 중
interview-try-again = 다시 시도
interview-failed-where = 계속 실패하면 설정 › 제공자에서 제공자와 모델을 확인하세요.
gen-stop = 중지
gen-writing = 캐릭터를 쓰는 중…
interview-understood = 이렇게 이해했어요.
interview-you-said = 입력한 말: “{ $words }”
interview-own-guess = AI의 추측
interview-keep = 유지
interview-change = 변경
interview-remove = 제거
interview-not-it = 그게 아니에요
interview-not-it-off = 이 줄은 다시 물을 수 있는 하나의 질문에 기대고 있지 않아요
interview-own-sentence = 직접 쓴 문장
interview-private-line = 당신의 캐릭터 세계에 꼭 있었으면 하는 것, 절대 없었으면 하는 것이 있나요?
interview-private-sub = 로맨스, 폭력, 욕설 등 · 선택 사항
interview-make = 캐릭터 만들기
interview-make-after = 나중에 캐릭터 페이지에서 바꿀 수 있어요.
interview-skip-all = 모두 건너뛰기
interview-private-hint = 캐릭터의 세계에 이런 것을 원하는 사람도, 원하지 않는 사람도 있어요. 답변은 이 컴퓨터의 이 캐릭터와 함께 남고, 캐릭터를 쓰는 AI에만 전달돼요.
interview-private-free = 그 밖에 원하는 것, 절대 원하지 않는 것
interview-yes = 예
interview-no = 아니요
interview-maybe = 아마도
interview-fantasy-only = 상상 속에서만
interview-never = 절대 안 돼요
interview-try-another = 다른 모델로 시도
interview-without-topic = 그 주제 없이 쓰기
interview-model-provider = { $model } · { $provider }
interview-reading = 답변을 읽는 중
interview-persona-title = 자신에 대해 말한 내용을 페르소나에 추가할까요?
interview-persona-field = 페르소나
interview-persona-in-use = { $persona } · 사용 중
interview-persona-new = 새 페르소나
interview-persona-add = 추가
interview-persona-not-now = 나중에
interview-persona-added = “{ $persona }”에 추가했어요.
interview-persona-you = 나
