

## card-block (card/card-block.ts)

card-block-text = { $madeBy } · { $under }

## coding (chat/coding.ts)

coding-the-team = A equipe de IA
coding-open-task = Abrir tarefa de programação
coding-undo-all = Desfazer tudo
coding-put-the-folder-back = Deixar a pasta como estava antes da tarefa?
coding-add-an-export-of = Adicionar uma exportação de chats em Markdown, com um teste.
coding-c-users-you-projects = C:\Users\você\Projetos\app
coding-start-a-coding-task = Iniciar uma tarefa de programação
coding-start = Iniciar
coding-goal = Objetivo
coding-a-checkpoint-is-kept = O Cardwave guarda uma cópia da pasta antes de cada passo, então cada passo pode ser desfeito.

## composer (chat/composer.ts)

composer-whoever-is-named-replies = Responde quem for citado
composer-the-character-named-in = Responde o personagem citado nas mensagens mais recentes e, quando nenhum é citado, um dos outros ao acaso.
composer-each-replies-in-turn = Cada um responde na sua vez
composer-the-characters-reply-one = Os personagens respondem um depois do outro, na ordem em que o painel lateral os lista.
composer-a-random-one-replies = Responde um ao acaso
composer-one-of-the-characters = Um dos personagens responde ao acaso, e não o que falou por último.
composer-keep-replying-by-themselves = Os personagens continuam conversando sozinhos
composer-write-for-me = Escrever por mim
composer-uses-what-you-typed = A IA escreve sua mensagem; o que você digitou a orienta e não é enviado.
composer-improve = Melhorar minha mensagem
composer-rewrites-what-you-typed = Reescreve o que você digitou
composer-attach-picture-or-document = Anexar imagem ou documento
composer-ai-draws-a-picture = A IA desenha uma imagem para a conversa; o que você digitou a orienta
composer-joins-this-chat = Outro personagem entra nesta conversa
composer-add-or-write = Anexar, ou deixar a IA escrever
composer-message = Mensagem
composer-send = Enviar
composer-writing-your-message = Escrevendo sua mensagem…
composer-who-replies = Quem responde: { $says }
composer-writes-every-reply = { $name } escreve todas as respostas.
composer-who-replies-group = Quem responde
composer-joined-the-chat = { $name } entrou no chat.
composer-message-improved = Mensagem melhorada.
composer-message-written-for-you = Mensagem escrita para você.
composer-message-2 = Mensagem para { $whom }
composer-replies = { $name } responde

## dictate (chat/dictate.ts)

dictate-dictate = Ditar
mic-none = Nenhum microfone foi encontrado: conecte um e tente de novo.
mic-not-allowed-desktop = O Cardwave não tem permissão para usar o microfone: permita nas configurações de privacidade do Windows, em Microfone.
mic-not-allowed-browser = Esta página não tem permissão para usar o microfone: permita nas configurações do navegador para este site.
mic-not-started = Não foi possível iniciar o microfone: feche outros programas que o estejam usando e tente de novo.
mic-not-offered = O navegador não oferece microfone neste endereço: use um no computador em que o Cardwave roda.
dictate-dictation-failed = O ditado falhou: { $reason }. Tente de novo.
dictate-writing-what-was-said = Escrevendo o que foi dito…
dictate-nothing-was-heard = Nada foi ouvido.
dictate-stop-dictating = Parar o ditado

## header (chat/header.ts)

header-chat-title = Título do chat
header-the-title-was-not = O título não foi salvo: { $reason }. Tente de novo.
header-automatic = Automático
header-automatic-sub = Escolhe um dos modos abaixo pelo que você escreve
header-new-chat-with-these = Novo chat com estes personagens
header-new-chat-with = Novo chat com { $name }
header-add-to-favourites = Adicionar aos Favoritos
header-remove-from-favourites = Remover dos Favoritos
header-chat-options = Opções do chat
header-with = com { $join }

## messages (chat/messages.ts)

messages-ai = IA
messages-you = { " " }(você)
messages-you-2 = Você
messages-writing = Escrevendo…
messages-message-and-the-after = A mensagem e as { $after } depois dela foram apagadas.
messages-message-deleted = Mensagem excluída.
messages-branch-from-here = Tentar outro caminho daqui
messages-edit-message = Editar a mensagem
messages-stop-reading = Parar a leitura
messages-read-aloud = Ler em voz alta
messages-message-options = Opções da mensagem
messages-previous-version = Versão anterior
messages-next-version = Próxima versão
messages-write-again = Escrever de novo
messages-continue-reply = Continuar esta resposta
messages-version-of = Versão { $at } de { $count }
messages-delete-versions = Excluir, com todas as versões ({ $count })
messages-delete-version = Excluir esta versão
messages-continue-uses-what-you = Continuar esta resposta · as palavras do campo a orientam
messages-generate-reply = Gerar resposta

## narration (narration.ts)

narration-show-pictures-from-the = Mostrar imagens da web
narration-a-picture-from-another = Uma imagem de outro site está oculta: carregá-la informa a esse site que o chat foi aberto.
narration-you-can-change-this = Você pode mudar isso a qualquer momento em Configurações › Aparência.

## panel (chat/panel.ts)

panel-in-trash = { " " }(na Lixeira)
panel-remove-from-this-chat = Remover deste chat
panel-chat-details = Detalhes do chat
panel-in-trash-locked = Na Lixeira: restaure o chat para alterá-lo.
panel-as-an-assistant = Personalidade como assistente
panel-kept-with-the-character = Fica com o personagem, para todo chat com este personagem.
panel-memory = Memória
panel-move-up = Mover para cima
panel-move-down = Mover para baixo
panel-in-speaking-order = Na ordem em que falam
panel-options-for = Opções de { $name }
panel-user = { card-user-stand-in }
panel-new-persona = Nova persona…
panel-from-settings = { $inUse } (das Configurações)
panel-default-the-characters-own = Padrão (o do personagem)
panel-not-used-this-model = Não usado: este modelo decide o tamanho da própria resposta
panel-not-used-while-a = Não usado enquanto a IA usa ferramentas
panel-tokens-per-reply = Tokens por resposta
panel-very-short = Muito curta
panel-short = Curta
panel-medium = Média
panel-long = Longa
panel-very-long = Muito longa
panel-pause-between-replies = Pausa entre as respostas
panel-seconds-when-they-reply = Em segundos; só enquanto os personagens conversam sozinhos
panel-replies-in-a-row = Respostas seguidas
panel-by-themselves-then-they = Sozinhos, depois param
panel-reply-length = Tamanho da resposta
panel-small-tools-then-kept = A IA pode escrever pequenos programas para pesquisar ou calcular coisas; eles continuam disponíveis em todas as conversas
panel-the-characters-bring-none = Os personagens não trazem nenhum lorebook.
panel-restore = Restaurar
panel-put-back-2 = Recolocar { $name }
panel-left-out = Não usado nesta conversa
panel-in-trash-2 = Na Lixeira
panel-used-in-last-reply = Usado na última resposta
panel-used-in-this-reply = Usado nesta resposta
panel-read-on-the-web = Lido na web
panel-read-from-your-files = Lido dos seus arquivos
panel-saved-to-memory = Salvo na memória
panel-this-character-has-no = Este personagem não tem imagem.
panel-show-portrait = Mostrar a imagem do personagem
panel-add-lorebook-to-chat = Adicionar um lorebook a esta conversa
panel-entry-of = Entrada de { $lorebook }
panel-portrait-beside = Ao lado da conversa
panel-remove-from-this-chat-2 = Remover { $name } deste chat
panel-remove-lorebook-from-this = Remover o lorebook { $name } deste chat

## pictures (chat/pictures.ts)

pictures-open-the-picture = Abrir a imagem
pictures-change-prompt = Editar descrição
pictures-save-picture = Salvar a imagem
pictures-picture-options = Opções da imagem
pictures-prompt = Descrição
pictures-make-again = Gerar de novo

## split (chat/split.ts)

split-open-card-page = Abrir página do personagem
split-hide-card-editor = Ocultar página do personagem
split-card-editor = Página do personagem
split-changes-are-used-from = As alterações valem a partir da próxima resposta
split-this-card-is-in = Este personagem está na Lixeira.

## stats (chat/stats.ts)

stats-chat-history = Mensagens anteriores
stats-reply-statistics = Sobre esta resposta
stats-context-used = Quanto do que a IA consegue ler está em uso
stats-sent-to-the-ai = Enviado à IA · { $count } tokens
stats-in-all = { $seconds } ao todo
stats-to-the-first-word = { $seconds } até a primeira palavra · { $all }

## talk (chat/talk.ts)

talk-the-characters-stopped-after = Os personagens pararam depois de { $asked } respostas.
talk-go-on = Continuar

## title (chat-title.ts)

title-new-chat = Novo chat

## chat (companion/chat.ts)

chat-open-in-cardwave = Abrir no Cardwave
chat-compact-chat = Converse com sua companhia
chat-read-replies-aloud = Ler as respostas em voz alta
chat-no-voice = Nenhuma voz configurada: escolha uma em Configurações › Vozes
chat-the-card-has-no = Este cartão não tem personagem para conversar. Escolha outro em Trocar de personagem.
chat-message = Mensagem para { $name }

## main (companion/main.ts)

main-open-chat = Abrir o chat
main-figure-hint = Clique duas vezes para conversar, clique com o botão direito para mais
main-walk-around = Andar por aí
main-sit-still = Ficar no lugar
main-change-character = Trocar de personagem
main-hide-until-tomorrow = Ocultar até amanhã
main-quit-companion = Fechar companhia

## dialogs (dialogs.ts)

dialogs-folder-on-this-computer = Pasta neste computador

## dom (dom.ts)

dom-text = { $name }: { $reason }
dom-keep-all = Manter todas as alterações
dom-chosen-by-you = Escolhido por você
dom-address-copied = Endereço copiado.
dom-the-browser-did-not = copiar não foi permitido aqui; selecione o texto e pressione Ctrl+C

## edit-form (edit-form.ts)

edit-form-from-to = De { $least } a { $most }
edit-form-a-whole-number-from = Um número inteiro a partir de { $least }

## load (figures/load.ts)

load-this-figure-has-no = O Cardwave não consegue mover esta figura. Figuras feitas para Mixamo, VRChat, Unity ou Ready Player Me conseguem.

## format (format.ts)

format-today = Hoje
format-comma = { ", " }
format-day-at = { $day }, { $time }
format-yesterday = Ontem
format-kb = { $kb } KB
format-seconds = { $seconds } s

## downloaded (models/downloaded.ts)

downloaded-set-up = Configurar
downloaded-text = { $action } { $toLowerCase }
downloaded-local = Neste computador

## fit-models (models/fit-models.ts)

fit-models-cancel = Cancelar { $name }
fit-models-download = Baixar { $name }
fit-models-model-menu-delete = Menu do modelo: excluir { $name }
fit-models-delete-this-model = Excluir este modelo deste computador? Isso libera { $size }.
fit-models-gb-of-memory = { $round } GB de RAM · { $folder }
fit-models-downloading = { $fits } · baixando { $percent }%
fit-models-downloaded = { $fits } · baixado
fit-models-model-deleted = Modelo “{ $name }” excluído.

## images-setup (models/images-setup.ts)

images-setup-image-model = Modelo de imagem
images-not-set-up = Imagens dos seus personagens · não configurado

## kinds (models/kinds.ts)

kinds-chat-model = Modelo de chat
kinds-models-from-all-your = Modelos de todos os seus provedores que escrevem texto. O que você escolher escreve os chats, seja de qual provedor for.
kinds-models-from-all-your-2 = Modelos de todos os seus provedores que escrevem texto. O que você escolher é o modelo auxiliar, seja de qual provedor for.
kinds-images-model = Modelo de imagens
kinds-models-from-all-your-3 = Modelos de todos os seus provedores que criam imagens. O que você escolher cria as imagens, seja de qual provedor for.
kinds-search-model = Modelo de pesquisa
kinds-models-on-this-computer = Modelos deste computador e de todos os seus provedores que encontram textos pelo significado. O que você escolher faz as buscas, venha de onde vier.
kinds-models-on-this-computer-2 = Modelos deste computador e de todos os seus provedores que leem as mensagens em voz alta. O que você escolher lê as mensagens, venha de onde vier.
kinds-loading-models = Carregando modelos…
kinds-couldnt-load-the-models = Não foi possível carregar os modelos.
kinds-search-the-models = Pesquisar os modelos
kinds-use-this-model = Usar este modelo
kinds-model = Modelo
kinds-type-unknown = { " " }· não se sabe se consegue fazer isso
kinds-address = { " " }· { $address }
kinds-this-computer = Um programa neste computador
kinds-asking-the-provider = Consultando o provedor…
kinds-own-on-this-computer = { $own } · neste computador
kinds-none-of-the-kind = Nenhum dos seus provedores tem um modelo que faça isso.

## language-line (models/language-line.ts, settings/app-language.ts)

language-line-taken-from-this-computer = O mesmo deste computador até você escolher outro
language-line-follows-the-app = Segue o idioma do aplicativo até você mudá-lo

## models-group (models/models-group.ts)

models-group-not-configured = Não configurado
models-group-no-longer-offered = Seu provedor não oferece mais este modelo: escolha outro.

## provider-form (models/provider-form.ts)

provider-form-a-key-is-saved = Há uma chave salva
provider-form-asking-the-provider-for = Pedindo ao provedor os modelos dele…
provider-form-the-provider-lists-no = O provedor não lista modelos. Digite o nome do modelo exatamente como o site do provedor o escreve.
provider-form-text = { $action } { $what }
provider-form-test-passed = { " " }· teste aprovado
provider-form-testing = { " " }· testando…
provider-form-is-saved = ····{ $key_end } está salva
provider-form-or-type-the-models = { $listedCount }{ $have }. Ou digite o nome do modelo exatamente como o site do provedor o escreve.
provider-form-test-failed = O teste falhou: { $failed }. Confira a chave e o endereço.

## search-setup (models/search-setup.ts)

search-setup-not-downloaded = Não baixado
search-setup-ready = Disponível
search-setup-on-this-computer-download = { $name } · neste computador · download de { $bytes }
search-setup-the-librarys-search-then = A pesquisa da biblioteca passa então a encontrar personagens pelo assunto deles, não só pelas palavras.
search-setup-reading-cards-left = { " " }· lendo personagens, faltam { $left }
search-setup-reading-cards-left-2 = Lendo personagens · faltam { $left }

## find (shell/find.ts)

find-pages = Páginas
find-page = Página

## search-panel (shell/search-panel.ts)

search-panel-nothing-found-for = Nada encontrado para “{ $asked }”.
search-panel-show-all = Mostrar todos os { $count }
search-panel-open-in-a-new = Abrir em uma nova aba
search-panel-what = Personagens, chats, lorebooks, memórias, documentos e páginas
search-panel-not-messages = As palavras das mensagens não são buscadas; tente o personagem do chat.

## advanced (views/advanced.ts)

advanced-sillytavern-v3 = SillyTavern V3
advanced-ccv4 = Character Card V4

## chat (views/chat.ts)

chat-your-next-message-starts = Sua próxima mensagem tenta outro caminho a partir da mensagem marcada.{ " " }
chat-this-chat-is-in = Este chat está na Lixeira. Restaure-o para continuar escrevendo.
chat-hide-side-panel = Ocultar o painel lateral
chat-show-side-panel = Mostrar o painel lateral
chat-show-card-editor = Mostrar a página do personagem
chat-set-up-a-model = Configurar um modelo
chat-the-characters-keep-replying = Os personagens continuam respondendo sozinhos: { $asked } de { $talk_replies } respostas.{ " " }

## chats (views/chats.ts)

chats-last-message = Última mensagem
chats-date-started = Data de início
chats-no-chats-yet = Nenhum chat ainda.
chats-search-chats = Pesquisar chats
chats-couldnt-load = Não foi possível carregar seus chats.
chats-chat-character-or-card = Encontrar um chat ou personagem
chats-with = com { $others }
chats-from = em Personagens como { $join }

## coding-task (views/coding-task.ts)

coding-task-checkpoints = Pontos para desfazer
coding-task-put-the-folder-back = Deixar a pasta como { $toLowerCase }?
coding-task-none-yet = Nenhum ainda
coding-task-changed-files = Arquivos alterados
coding-task-text = { " " }· { $stepSays }
coding-task-team-started = { $folder } · equipe { $team } · iniciada { $format } ·{ " " }
coding-task-steps = Passos
coding-task-undone = { $detail } · desfeito

## documents (views/documents.ts)

documents-no-documents-yet-a = Nenhum documento ainda. Adicione um aqui ou anexe um em um chat.
documents-what-they-are = A IA lê estes arquivos ao responder: os de um personagem em todo chat com esse personagem, os de um chat nesse chat.
documents-found-by-meaning-once = A IA encontra as partes certas pelo significado assim que a Pesquisa estiver configurada.
documents-set-up-search = Configurar a Pesquisa em Configurações
documents-no-document-found = Nenhum documento encontrado.
documents-search-documents = Pesquisar documentos
documents-name-chat-or-character = Nome, chat ou personagem
documents-document-deleted = Documento excluído.
documents-for-the-character = Para o personagem{ " " }
documents-for-the-chat = Para o chat{ " " }

## memories (views/memories.ts)

memories-nothing-remembered-yet = Nenhuma memória ainda.
memories-come-from-chats = As memórias vêm dos seus chats: a cada 20 mensagens, o Cardwave guarda o que cada personagem deve lembrar. Aqui você pode alterá-las ou excluí-las.
memories-no-memory-found = Nenhuma memória encontrada.
memories-search-memories = Pesquisar memórias
memories-text-chat-or-character = Texto, chat ou personagem
memories-known-by = Conhecida por
memories-known-by-hint = Quem no chat sabe disso e pode mencionar.
memories-you = você
memories-you-alone = Você
memories-edit-memory = Editar a memória
memories-memory-deleted = Memória excluída.
memories-from-the-chat = { " " }· Do chat{ " " }
memories-from-your-chat-with = { " " }· Do seu chat com{ " " }
memories-because = porque { $end }
memories-so = então { $end }

## dictation-setup (voice/dictation-setup.ts)

dictation-setup-on-this-computers-graphics = { $name } · na placa de vídeo deste computador · { $bytes }
dictation-setup-the-microphone-beside-the = O microfone ao lado do campo de mensagem passa a escrever o que você diz, em português, inglês e outros idiomas. O que você diz fica neste computador.

## make-voice (voice/make-voice.ts)

make-voice-my-voice = Minha voz
make-voice-make-voice = Criar a voz
make-voice-choose-a-file = Escolher um arquivo
make-voice-record = Gravar
make-voice-play-back = Ouvir
make-voice-record-again = Gravar de novo
make-voice-the-recording-is-too = A gravação é curta demais: no mínimo { $SHORTEST } segundos.
make-voice-cardwave-cant-read-choose = O Cardwave não consegue ler “{ $name }”. Escolha um arquivo WAV ou MP3.
make-voice-recording = Gravação
make-voice-a-short-recording-of = Uma gravação curta de uma pessoa falando com clareza: de 10 a { $LONGEST } segundos. WAV ou MP3.
make-voice-use-only-a-voice = Use só uma voz que você tem o direito de usar: a sua, ou uma cujo dono ou dona concordou.
make-voice-give-the-voice-a = Dê um nome à voz.

## voice-setup (voice/voice-setup.ts)

voice-setup-made-from-your-recording = Criada a partir da sua gravação
voice-setup-on-this-computer-download = Neste computador · download de { $bytes }
voice-setup-play-a-sample-of = Ouvir uma amostra de { $name }
voice-setup-stop-the-sample-of = Parar a amostra de { $name }
voice-setup-messages-are-read-aloud = As mensagens são lidas em voz alta em inglês, neste computador.
voice-setup-use-this-voice = Usar esta voz
voice-setup-hello-im-this-is = Olá, aqui é { $name }. É assim que suas mensagens soam quando são lidas em voz alta.

## voice (voice/voice.ts)

voice-the-voice-stopped-answering = A voz parou de responder. Tente de novo ou escolha outra voz em Configurações › Vozes.
voice-this-window-cannot-play = Esta janela não consegue tocar som: { $reason }. Verifique a saída de som no Windows.

## Written by hand: plurals, conditions and numbers

client-backup-failed = Não foi possível fazer o backup. Verifique se a pasta pode receber arquivos e tente de novo.
composer-tokens-of = { NUMBER($used, useGrouping: "auto") } de { NUMBER($size, useGrouping: "auto") } tokens
header-chat = Chat
header-chat-archived = Chat arquivado.
header-chat-unarchived = A conversa voltou do arquivo.
messages-tokens = { $count ->
    [one] { $count } token
    [many] { NUMBER($count, useGrouping: "auto") } tokens
   *[other] { NUMBER($count, useGrouping: "auto") } tokens
  }
dom-texts-changed-by-ai = { $count ->
    [one] { $count } texto alterado
    [many] { $count } textos alterados
   *[other] { $count } textos alterados
  } pela IA
format-days-ago = { $count ->
    [one] há { $count } dia
    [many] há { $count } dias
   *[other] há { $count } dias
  }
format-weeks-ago = { $count ->
    [one] há { $count } semana
    [many] há { $count } semanas
   *[other] há { $count } semanas
  }
format-months-ago = { $count ->
    [one] há { $count } mês
    [many] há { $count } meses
   *[other] há { $count } meses
  }
format-years-ago = { $count ->
    [one] há { $count } ano
    [many] há { $count } anos
   *[other] há { $count } anos
  }
format-mb = { NUMBER($mb, minimumFractionDigits: 1, maximumFractionDigits: 1) } MB
format-gb = { NUMBER($gb, minimumFractionDigits: 1, maximumFractionDigits: 1) } GB
fit-models-fits = { $size } · Funciona neste computador
fit-models-too-large = { $size } · Grande demais para este computador
fit-models-used-for = { $fits } · usado para { $kinds }
provider-form-models = { $count ->
    [one] { $count } modelo
    [many] { NUMBER($count, useGrouping: "auto") } modelos
   *[other] { NUMBER($count, useGrouping: "auto") } modelos
  }
provider-form-listed = { $count ->
    [one] { $count } modelo listado
    [many] { NUMBER($count, useGrouping: "auto") } modelos listados
   *[other] { NUMBER($count, useGrouping: "auto") } modelos listados
  }
provider-form-listed-not-all = { $count ->
    [one] { $count } modelo listado
    [many] { NUMBER($count, useGrouping: "auto") } modelos listados
   *[other] { NUMBER($count, useGrouping: "auto") } modelos listados
  }; não foi possível carregar o resto
provider-form-have = ; { NUMBER($count, useGrouping: "auto") } contêm “{ $part }”
coding-task-verdict-passed = Veredito do auditor: aprovado
coding-task-verdict-not-passed = Veredito do auditor: reprovado
documents-words = { $count ->
    [one] { $count } palavra
    [many] { NUMBER($count, useGrouping: "auto") } palavras
   *[other] { NUMBER($count, useGrouping: "auto") } palavras
  }
memories-known-by-everyone = Conhecida por todos
memories-known-by-these = Conhecida por { $names }
memories-known-by-nobody = Conhecida por ninguém
lore-tools-entries-changed-by-ai = { $count ->
    [one] { $count } entrada alterada
    [many] { $count } entradas alteradas
   *[other] { $count } entradas alteradas
  } pela IA
coding-failed-with-error = Falhou: { $error }
coding-planner-doing = Planejador: { $what }
coding-step-doing = Passo { $begun } de { $planned } · { $who }: { $what }
coding-worker = Executor { $number }
coding-plans = Planeja os passos
coding-planned = { $steps ->
    [one] { $steps } passo planejado
    [many] { $steps } passos planejados
   *[other] { $steps } passos planejados
  }
coding-fixes = Corrige o que o auditor encontrou
coding-checks-step = Confere o passo { $step }
coding-checks-all = Verifica cada passo e roda os testes
coding-verdict-tests = { $said } · { $tests }
coding-show-plan = Mostrar o plano
coding-before-step = Antes do passo { $step }
coding-before-fix = Antes da correção
coding-looking-at-folder = Olhando a pasta
coding-looking-at = Olhando { $target }
coding-reading = Lendo { $target }
coding-writing = Escrevendo { $target }
coding-running-command = Executando: { $target }
coding-installing = Instalando: { $target }
coding-searching-web = Pesquisando na web: { $target }
coding-files = { $files ->
    [one] { $files } arquivo
    [many] { $files } arquivos
   *[other] { $files } arquivos
  }
coding-no-files-changed = Nenhum arquivo alterado
coding-lines-files = { $lines } · { $files }
messages-copy-refused = copiar não foi permitido aqui; selecione o texto e pressione Ctrl+C
panel-book-persona = persona
panel-book-every-chat = todos os chats
stats-model = Modelo
stats-response-time = Tempo de resposta
stats-context = Contexto
stats-context-says = { $used } de { $size } tokens usados · { $free } livres
documents-the-chat = o chat
models-download-recommended = Encontra personagens pelo que eles são · download de { $size } · recomendado
models-downloading = { $name } · baixando { $percent }%
models-on-this-computer = { $name } · Este computador{ $reading }
voice-setup-voice-download = Lê as respostas em voz alta · { $name } ({ $about }) · download de { $size }
voice-setup-downloading = Baixando { $percent }%
panel-persona-default = Usada em novos chats
panel-who-you-are-in-this-chat = Quem você é neste chat
panel-use-in-this-chat = Usar neste chat
panel-click-a-reply = Clique em uma resposta para ver o que ela usou.
