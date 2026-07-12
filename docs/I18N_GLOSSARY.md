# Cardwave i18n Glossary

Canonical translations for recurring domain terms. Created in Step 4 (see
`docs/I18N_PLAN.md` §4.2). **Every occurrence of a term below must use the
translation in this table** — do not paraphrase per string. When a term appears
inside a longer phrase, inflect it naturally for the target language but keep the
root choice consistent.

Cardwave is a consumer roleplay / creative writing tool. Register is **friendly
and direct, not corporate** (plan §4.3).

## Terms that stay untranslated in every locale
Kept verbatim (Latin) everywhere: **Cardwave**, **LLM**, **NSFW**, **NPC**,
**ZDR**, **KV**, **VRAM**, **GGUF**, **TTS**, **API** and provider/product names
(**OpenAI, Anthropic, Google, Grok, OpenRouter, NanoGPT, KoboldCpp, Ollama,
LM Studio, llama.cpp**), file formats (**PNG, JSON, GGUF**), and card-spec
markers (**CCv3, V2, V3, first_mes**).

- **API key** — keep "API" Latin; the word "key" follows the locale ("API-ключ"
  is avoided — use "API key" in Latin-script locales, "APIキー" ja, "API 密钥"
  zh-Hans / "API 金鑰" zh-Hant, "API 키" ko, "API कुंजी" hi, "ключ API" ru,
  "khóa API" vi).
- **token** — kept Latin in pt-BR/es-419/zh/vi; transliterated where Latin reads
  wrong: **トークン** ja, **토큰** ko, **токен** ru, **टोकन** hi.

## Domain terms

| en | ru | pt-BR | es-419 | ja | zh-Hans | zh-Hant | ko | hi | vi |
|---|---|---|---|---|---|---|---|---|---|
| character card | карточка персонажа | cartão de personagem | tarjeta de personaje | キャラクターカード | 角色卡 | 角色卡 | 캐릭터 카드 | कैरेक्टर कार्ड | thẻ nhân vật |
| character | персонаж | personagem | personaje | キャラクター | 角色 | 角色 | 캐릭터 | कैरेक्टर | nhân vật |
| persona | персона | persona | persona | ペルソナ | 人设 | 人設 | 페르소나 | पर्सोना | persona |
| chat (a conversation) | чат | conversa | chat | チャット | 对话 | 對話 | 채팅 | चैट | cuộc trò chuyện |
| group chat | групповой чат | conversa em grupo | chat grupal | グループチャット | 群聊 | 群組對話 | 그룹 채팅 | ग्रुप चैट | trò chuyện nhóm |
| group | группа | grupo | grupo | グループ | 群组 | 群組 | 그룹 | ग्रुप | nhóm |
| workspace | рабочая область | espaço de trabalho | espacio de trabajo | ワークスペース | 工作区 | 工作區 | 작업 공간 | वर्कस्पेस | không gian làm việc |
| prompt | промпт | prompt | prompt | プロンプト | 提示词 | 提示詞 | 프롬프트 | प्रॉम्प्ट | prompt |
| system prompt | системный промпт | prompt do sistema | prompt del sistema | システムプロンプト | 系统提示词 | 系統提示詞 | 시스템 프롬프트 | सिस्टम प्रॉम्प्ट | prompt hệ thống |
| provider | провайдер | provedor | proveedor | プロバイダー | 服务商 | 服務商 | 제공자 | प्रोवाइडर | nhà cung cấp |
| preset | пресет | predefinição | preajuste | プリセット | 预设 | 預設 | 프리셋 | प्रीसेट | preset |
| model | модель | modelo | modelo | モデル | 模型 | 模型 | 모델 | मॉडल | mô hình |
| memory (story memory) | память | memória | memoria | メモリ | 记忆 | 記憶 | 기억 | मेमोरी | ký ức |
| tag | тег | tag | etiqueta | タグ | 标签 | 標籤 | 태그 | टैग | tag |
| import | импортировать / импорт | importar / importação | importar / importación | インポート | 导入 | 匯入 | 가져오기 | इम्पोर्ट | nhập |
| export | экспортировать / экспорт | exportar / exportação | exportar / exportación | エクスポート | 导出 | 匯出 | 내보내기 | एक्सपोर्ट | xuất |
| library | библиотека | biblioteca | biblioteca | ライブラリ | 库 | 庫 | 라이브러리 | लाइब्रेरी | thư viện |
| lorebook | лорбук | lorebook | lorebook | ロアブック | 世界书 | 世界書 | 로어북 | लोरबुक | lorebook |
| greeting | приветствие | saudação | saludo | 挨拶 | 开场白 | 開場白 | 인사말 | अभिवादन | lời chào |
| scenario | сценарий | cenário | escenario | シナリオ | 场景 | 場景 | 시나리오 | परिदृश्य | kịch bản |
| node / nodes | узел / узлы | nó / nós | nodo / nodos | ノード | 节点 | 節點 | 노드 | नोड | node |
| reasoning | рассуждения | raciocínio | razonamiento | 推論 | 推理 | 推理 | 추론 | रीज़निंग | suy luận |
| selfie | селфи | selfie | selfie | 自撮り | 自拍 | 自拍 | 셀카 | सेल्फी | ảnh selfie |
| web fetch | веб-запрос | busca na web | búsqueda web | ウェブ取得 | 网页读取 | 網頁讀取 | 웹 가져오기 | वेब फ़ेच | truy xuất web |
| auto-chat | авточат | conversa automática | chat automático | 自動チャット | 自动聊天 | 自動對話 | 자동 채팅 | ऑटो-चैट | trò chuyện tự động |
| provider (media/voice) role, e.g. "image model" | модель | modelo | modelo | モデル | 模型 | 模型 | 모델 | मॉडल | mô hình |

## Cross-feature action verbs (mirror `common.actions.*`)
Reuse one translation across the app for these six:

| en | ru | pt-BR | es-419 | ja | zh-Hans | zh-Hant | ko | hi | vi |
|---|---|---|---|---|---|---|---|---|---|
| OK | ОК | OK | OK | OK | 确定 | 確定 | 확인 | ठीक है | OK |
| Cancel | Отмена | Cancelar | Cancelar | キャンセル | 取消 | 取消 | 취소 | रद्द करें | Hủy |
| Save | Сохранить | Salvar | Guardar | 保存 | 保存 | 儲存 | 저장 | सहेजें | Lưu |
| Delete | Удалить | Excluir | Eliminar | 削除 | 删除 | 刪除 | 삭제 | हटाएं | Xóa |
| Close | Закрыть | Fechar | Cerrar | 閉じる | 关闭 | 關閉 | 닫기 | बंद करें | Đóng |
| Try Again | Повторить | Tentar novamente | Reintentar | 再試行 | 重试 | 重試 | 다시 시도 | पुनः प्रयास करें | Thử lại |

Note: es-419 uses "Guardar" for Save per LatAm convention here (both "Guardar" and
"Salvar" occur regionally; "Guardar" is the safer neutral choice for a save action).

## Register cheatsheet (from plan §4.3)
- **ru** — «вы» (lowercase), buttons in the infinitive («Создать»).
- **pt-BR** — «você», warm; "salvar" not "guardar", "excluir/deletar" not "apagar".
- **es-419** — neutral LatAm, «tú»; "computadora" not "ordenador"; no vosotros.
- **ja** — です/ます; buttons as noun/verb-stem («作成»); no spaces around `$vars`.
- **zh-Hans vs zh-Hant** — terminology differs, not just script (设置/設定,
  导入/匯入, 视频/影片, 保存/儲存). Translate Hant independently, Taiwan usage.
- **ko** — 해요체 for messages, noun-form buttons («만들기», «가져오기»).
- **hi** — formal «आप»; Devanagari English loanwords are fine and often preferred
  (सेटिंग्स, इम्पोर्ट).
- **vi** — friendly «bạn»; established tech loanwords stay Latin (prompt, preset,
  token); plural: `other` only. No title case — capitalize first word only.
