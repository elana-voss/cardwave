### As palavras da interface em português do Brasil, traduzidas do inglês (en.ftl, o arquivo de referência), chave
### por chave; o teste de estrutura (structure.test.ts) confere que tudo esteja aqui e tenha a mesma forma.
### Lista de palavras, um nome por coisa, em todos os pt-BR.*.ftl:
###   Tratamento: você; nunca um gênero para o usuário (nada de «pronto/a», «conectado»: reformula-se).
###   Cardwave (o Cardwave), MCP, Claude Desktop, CSS, Lorebook (o lorebook), Persona(s) (a persona), prompt, preset, chat: ficam assim.
###   character = personagem (o personagem, a figura dos chats); card = ficha (o arquivo, ficha de personagem); figure = figura (3D).
###   memory = memória; document = documento; library = biblioteca; knowledge = conhecimento; account = conta.
###   provider = provedor; model = modelo; helper (model) = modelo auxiliar; AI = IA; tool = ferramenta; tab = aba.
###   Settings = Configurações; Advanced = Avançado; Trash = Lixeira (a do Cardwave);
###   Recycle Bin = Lixeira do Windows; backup = backup; restore = restaurar; Sharing = Compartilhamento.
###   companion = companhia (a companhia; «acompanhante» soa como profissão); voice = voz; dictation = ditado;
###   Search Cardwave = Pesquisar no Cardwave.
###   coding team = equipe de programação; planner = planejador; worker = executor; auditor = auditor; task = tarefa.
###   sign in = entrar; sign out = sair; lock = bloquear; import = importar; export = exportar.
###   interview = entrevista; generator = gerador de personagens; theme = tema; first run = configuração inicial.
###   Papéis de outras pessoas: as duas formas (amigo/a, colega, seu ex), nunca só uma.
###   Rótulos dentro de uma frase em minúscula (midSentence, como no inglês).

## The app

app-name = Cardwave

## The pages, as tabs, the rail and Search Cardwave name them (shell/pages.ts)

page-chats = Chats
page-characters = Personagens
page-lorebooks = Lorebooks
page-personas = Personas
page-memories = Memórias
page-documents = Documentos
page-generator = Gerador de personagens
page-interview = Criar um personagem juntos
page-profile = Perfil
page-server = Compartilhamento
page-settings = Configurações
page-providers = Provedores
page-voices = Vozes
page-advanced = Avançado
page-css = CSS do Cardwave
page-written-tools = Ferramentas que a IA escreveu
page-coding-team = Equipe de programação
page-trash = Lixeira
page-about = Sobre o Cardwave
page-coding-task = Tarefa de programação
page-chat = Chat
page-new-card = Novo personagem
page-lorebook = Lorebook
page-card = Personagem
page-prompt-preset = Preset de prompt
page-first-run = Configurar o Cardwave

## The places pages are under

place-library = Biblioteca
place-knowledge = Conhecimento
place-account = Conta
place-settings = Configurações
place-advanced = Configurações › Avançado

## The rail (shell/rail.ts)

rail-create = Criar
rail-memories-tip = Memórias: o que a IA lembra das suas conversas
rail-documents-tip = Documentos: arquivos que a IA lê ao responder
rail-show-more = Mostrar mais { $count }
rail-open-menu = Abrir barra lateral
rail-close-menu = Fechar barra lateral
rail-collapse = Recolher barra lateral
rail-expand = Expandir barra lateral
rail-account = Conta
rail-account-named = Conta: { $name }
rail-lock = Bloquear

## Create's lines (shell/create.ts)

create-new-chat = Novo chat
create-plain-chat = Chat sem personagem
create-new-card = Novo personagem
create-from-picks = Gerador de personagens
create-together = Criar um personagem juntos
create-new-persona = Nova persona
create-new-lorebook = Novo lorebook
create-import-card = Importar ficha
create-import-lorebook = Importar lorebook
create-new = Novo
create-import = Importar

## The title bar and its tabs (shell/titlebar.ts)

tabs = Abas
tab-new = Nova aba
tab-new-keys = Nova aba (Ctrl+T)
tabs-all = Todas as abas
tab-close = Fechar aba
window-minimize = Minimizar
window-maximize = Maximizar
window-close = Fechar

## The view menu (shell/view-menu.ts, theme.ts)

view = Exibir
view-compact = Compacto
theme-system = Sistema
theme-light = Claro
theme-dark = Escuro
theme-downtempo = Downtempo
theme-outrun = Outrun
theme-retrowave = Retrowave
theme-neonwave-dark = Neon Wave escuro
theme-neonwave-light = Neon Wave claro

## Search Cardwave's button (shell/search-panel.ts)

search = Pesquisar no Cardwave
search-keys = Pesquisar no Cardwave (Ctrl+K)

## The labels of the settings, as their pages and Search Cardwave name them (setting-labels.ts)

label-settings-theme = Tema
label-settings-chat-layout = Layout do chat
label-settings-web-pictures = Mostrar imagens de outros sites
label-settings-app-language = Idioma do aplicativo
label-settings-language = Idioma em que a IA escreve
label-settings-providers = Provedores
label-settings-chat = Chat
label-settings-images = Imagens
label-settings-voice = Voz
label-settings-search = Pesquisa
label-settings-dictation = Ditado
label-settings-web = Web
label-settings-files = Arquivos
label-settings-commands = Comandos
label-settings-image-generation = Geração de imagens
label-settings-app = Cardwave
label-settings-dice = Dados
label-settings-folder = Pasta
label-settings-written = Ferramentas que a IA escreveu
label-settings-coding = Equipe de programação
label-settings-trash = Lixeira
label-settings-backup = Backup
label-settings-restore = Restaurar
label-settings-cards-folder = Pasta de fichas
label-settings-advanced = Avançado
label-settings-setup = Refazer a configuração
label-settings-about = Sobre o Cardwave
label-providers-this-computer = Este computador
label-voices-model = Modelo de voz
label-voices-speed = Velocidade
label-voices-english = Inglês
label-advanced-background = Modelo auxiliar
label-advanced-told = O que a IA recebe como instrução
label-advanced-describe = Descrever personagens importados
label-advanced-described = Personagens descritos
label-advanced-interview = Criar um personagem juntos
label-advanced-format = Formato de exportação
label-advanced-history = Incluir versões anteriores de cada texto
label-advanced-css = Seu próprio CSS
label-coding-planner = Planejador
label-coding-workers = Executores
label-coding-auditor = Auditor
label-profile-name = Nome
label-profile-picture = Imagem
label-profile-password = Senha
label-server-network = Acessível na rede doméstica
label-server-address = Endereço
label-server-mcp = Deixar apps de IA deste computador usar o Cardwave

layout-bubbles = Balões
layout-plain = Simples

## Settings (views/settings.ts)

settings-appearance = Aparência
settings-theme-about = Segue o sistema, a menos que você escolha um
settings-layout-about = Mensagens em balões ou como texto simples
settings-web-pictures-about = Esses sites podem ver quando você abre o chat.
settings-language = Idioma
settings-data = Dados
settings-trash-about = { $count ->
    [one] { $count } item
    [many] { $count } itens
   *[other] { $count } itens
  } · esvaziada após { $days } dias
settings-open-trash = Abrir a Lixeira
settings-open = Abrir
settings-version = Versão { $version } · licenças
settings-licences = Licenças
settings-advanced-about = Modelo auxiliar, biblioteca, exportação, chat sem personagem, amostragem, presets, seu próprio CSS
settings-setup-about = Provedores, modelos e voz, passo a passo
settings-providers-about = Endereços e chaves dos serviços que executam os modelos
settings-this-computer = este computador
settings-providers-named = Configurados: { $names }
settings-models = Modelos
settings-the-chat-model = o modelo de chat
settings-the-image-model = o modelo de imagem

## The account's tabs and accounts (shell/account-tabs.ts, settings/accounts.ts)

account-sections = Seções da conta
account-switch = Trocar de conta

account-password = Senha
account-switch-to = Trocar para { $name }
account-password-asked = Digite a senha de { $name }.
account-switch-button = Trocar
account-add = Adicionar conta
account-add-about = A conta de outra pessoa neste computador, com chats e personagens próprios. Ela entra com sua senha, aqui ou em outro dispositivo.
account-name = Nome
account-added = Conta “{ $name }” adicionada.
account-add-button = Adicionar
account-sign-out = Sair
account-none = Nenhuma conta em que entrar
account-none-about = Nenhuma conta pode entrar daqui ainda. No computador em que o Cardwave roda, adicione uma em Conta › Compartilhamento.
account-this-computer = A conta deste computador
account-choose = Escolha sua conta
account-try-again = Tentar de novo
account-back = Voltar
account-sign-in = Entrar

## Backup and Restore (settings/backup.ts)

backup-saving = Salvando o backup.
backup-saving-to = Salvando o backup em { $folder }.
backup-password = Senha
backup-repeat = Repetir a senha
backup-encrypted = O backup é criptografado com esta senha; para restaurá-lo, a senha é necessária, aqui ou em outro computador.
backup-forgotten = Uma senha esquecida não pode ser recuperada, e o backup não pode ser restaurado sem ela.
backup-with-password = Fazer backup com uma senha
backup-differ = As duas senhas são diferentes.
backup-back-up = Salvar backup
backup-no-file = Nenhum arquivo escolhido
backup-choose-file = Escolher arquivo
backup-its-password = A senha do backup
backup-restoring = Restaurar substitui tudo no Cardwave: chats, personagens, personas, lorebooks, memórias e configurações. Isso não pode ser desfeito.
backup-file = Arquivo
backup-restore-title = Restaurar um backup
backup-choose-first = Escolha primeiro o arquivo do backup.
backup-restore = Restaurar backup
backup-save = Salvar um backup
backup-from-file = De um arquivo de backup
backup-about-own = Chats, personagens e configurações em um só arquivo, criptografado com sua senha
backup-about-chosen = Chats, personagens e configurações em um só arquivo, criptografado com uma senha que você escolhe

## The folder of cards (settings/card-folder.ts)

folder-watch = Importar novas fichas automaticamente
folder-watch-about = Um arquivo de ficha colocado na pasta entra sozinho na sua biblioteca
folder-recycle = Mover os arquivos importados para a Lixeira do Windows
folder-recycle-about = Depois que um arquivo é importado, ele vai para a Lixeira

## The companion's line (library/companion-app.ts)

companion = Companhia
# The companion window's name, which the system shows in its lists of windows.
companion-window = Companhia do Cardwave
companion-made = { $name } é sua companhia.
companion-make = Tornar companhia
companion-none = Ainda sem companhia. Abra o menu “…” de um personagem e escolha “Tornar companhia”.
companion-named = { $name } · Abre com o aplicativo
companion-figure = Figura da companhia
companion-figure-about = Mostrada para personagens sem uma figura 3D própria
companion-figure-woman = Mulher
companion-figure-man = Homem
companion-figure-robot = Robô
companion-size = Tamanho da companhia
companion-size-about = A altura da figura, como parte da altura da tela
companion-size-value = { $size }%

## Other programs, MCP (settings/mcp.ts)

mcp-ask-title = Deixar apps de IA deste computador usar o Cardwave
mcp-ask = Programas deste computador, como o Claude Desktop, podem ler seus personagens e chats, escrever nos seus chats e usar as ferramentas ligadas em Configurações › Ferramentas. O que o Cardwave perguntaria a você antes, eles não podem fazer.
mcp-switch-on = Ativar
mcp-about = Como o Claude Desktop, via MCP: usam seus personagens, chats e ferramentas
mcp-copy-address = Copiar o endereço MCP
mcp-copy = Copiar
mcp-as-account = Como conta
mcp-as-account-about = O que eles podem ver e fazer
mcp-remove-named = Remover { $program }
mcp-removed = “{ $program }” removido.
mcp-remove = Remover
mcp-connected = Conectado
mcp-other-programs = Outros programas
mcp-only-here = Só programas neste computador podem se conectar. Um programa removido fica de fora até você desativar e ativar isto de novo.

## Your own CSS (settings/own-css.ts)

css-none = Nenhum
css-lines = { $count ->
    [one] { $count } linha
    [many] { $count } linhas
   *[other] { $count } linhas
  }
css-about = { $lines } · muda a aparência do aplicativo
css-hint = Aplicado depois da folha de estilo do próprio Cardwave, enquanto você digita. Salvar o mantém; Cancelar o desfaz.
css-edit-own = Editar seu próprio CSS
css-edit = Editar

## The password (settings/password.ts)

password-forgotten = Uma senha esquecida não pode ser recuperada, e seus chats e personagens se perdem com ela. Guarde-a em lugar seguro.
password-on-title = Definir uma senha
password-on-says = O Cardwave vai pedi-la ao abrir. Sem ela ninguém abre o Cardwave nem lê seus chats neste computador.
password-on = Definir senha
password-on-done = Senha definida.
password-change-title = Alterar a senha
password-change-says = O Cardwave vai pedir a nova ao abrir.
password-change = Alterar
password-change-done = Senha alterada.
password-off-title = Desativar a senha
password-off-says = O Cardwave vai abrir sem pedir senha. Seus chats e personagens continuam criptografados.
password-off = Desativar
password-off-done = Senha desativada.
password-differ = As duas senhas são diferentes.
password-other-says = A partir daí, a entrada é com a nova.
password-other-forgotten = Se ela for esquecida, a conta deste computador pode redefini-la, em Compartilhamento.
password-current = Senha atual
password-password = Senha
password-new = Nova senha
password-repeat = Repetir a senha
password-asked-sign-in = Pedida ao entrar
password-is-on = Ativada · pedida quando o aplicativo abre
password-is-off = Desativada · qualquer pessoa neste computador pode abrir o Cardwave
password-start-forgotten = Uma senha esquecida não pode ser recuperada. Restaure um backup para começar de novo.
password-open = Abrir
password-back = Voltar

## Words many pages use

common-use = Usar
common-in-use = { " " }· em uso
common-more = Mais
common-edit = Editar
common-duplicate = Duplicar
# The word a copy's name ends in, as in "Rig (copy)".
common-copy-word = cópia
common-delete = Excluir
common-save = Salvar
common-cancel = Cancelar
common-name = Nome

## Model presets and prompt presets (settings/presets.ts, settings/prompt-presets.ts)

preset-what = Um preset salva um modelo de chat com seus valores de amostragem. Usar troca para ele.
preset-temperature = temperatura { $value }
preset-new = Novo preset
preset-model-presets = Presets de modelo
preset-using = Usando “{ $name }”.
preset-added = Preset “{ $name }” adicionado.
preset-deleted = Preset “{ $name }” excluído.
preset-saved = Preset “{ $name }” salvo.
preset-delete-ask = Excluir este preset?
preset-replace = Usar o modelo e as configurações atuais
preset-replace-hint = O modelo de chat, seu provedor e a amostragem desta página. Desligado: a predefinição mantém os seus.
preset-keeps-hint = Ele mantém o modelo de chat em Configurações › Modelos, seu provedor e a amostragem desta página.
preset-name = Nome
preset-edit = Editar preset
prompt-presets = Presets de prompt
prompt-system = Prompt de sistema
prompt-note = { $depth ->
    [one] Nota, { $depth } mensagem atrás
    [many] Nota, { $depth } mensagens atrás
   *[other] Nota, { $depth } mensagens atrás
}
prompt-system-note = { $depth ->
    [one] Prompt de sistema · nota, { $depth } mensagem atrás
    [many] Prompt de sistema · nota, { $depth } mensagens atrás
   *[other] Prompt de sistema · nota, { $depth } mensagens atrás
}
prompt-as-card = Como diz o personagem
prompt-default = Padrão
prompt-default-name = “{ $name }” é o prompt do próprio personagem.

## Tools (settings/tools.ts, chat/tool-ask.ts)

tools-written-ask = { $count ->
    [0] Nenhuma ainda
    [one] { $count } ferramenta
    [many] { $count } ferramentas
   *[other] { $count } ferramentas
  } · perguntar antes que uma nova seja executada
tools-written-free = { $count ->
    [0] Nenhuma ainda
    [one] { $count } ferramenta
    [many] { $count } ferramentas
   *[other] { $count } ferramentas
  } · uma nova é executada sem perguntar
tools-folder-first = Escolha uma pasta primeiro
tools-web = Pesquisar e ler páginas da web
tools-files = Só { $folder }
tools-ask-writes = Perguntar antes de gravar
tools-ask-writes-says = Cada arquivo é mostrado a você antes de ser gravado
tools-commands = Executar em { $folder }, isolado do resto do computador e da internet
tools-ask-commands = Perguntar antes de executar
tools-ask-commands-says = Cada comando é mostrado a você antes de ser executado
tools-pictures = Usa o modelo de imagem
tools-pictures-first = Configure primeiro o modelo de imagem
tools-app = Usar e alterar seus personagens, chats e configurações; cada alteração perguntada antes
tools-dice = Deixa a IA rolar dados; o Cardwave os rola, então o resultado é justo.
tools-folder-example = C:\Users\você\Documents\Compartilhado
tools-folder-says = Arquivos e comandos alcançam esta pasta e o que ela contém, e nada mais.
tools-change-folder = Trocar a pasta
tools-change = Trocar
tools-choose = Escolher
tools-none-chosen = Nenhuma escolhida
tools-title = Ferramentas
tools-ask-new = { $name } quer usar uma nova ferramenta: { $what }
tools-ask-write = { $name } quer gravar “{ $what }” na sua pasta:
tools-ask-read = { $name } quer ler na sua pasta:
tools-ask-install = { $name } quer baixar e instalar programas de que precisa:
tools-ask-web = { $name } quer usar a web:
tools-ask-app = { $name } quer alterar o Cardwave:
tools-ask-command = { $name } quer executar um comando na sua pasta:
tools-allow = Permitir
tools-deny = Negar
tools-allow-writing = Permitir gravar arquivos neste chat
tools-allow-commands = Permitir comandos neste chat

## Updates (settings/update.ts)

update-title = Verificar atualizações
update-available = O Cardwave { $version } está disponível
update-you-have = Você tem a { $version }.
update-up-to-date = O Cardwave está atualizado ({ $version }).
update-connection-error = Não foi possível verificar atualizações. Verifique sua conexão.
update-whats-new = Novidades
update-close = Fechar
update-ok = OK
update-download = Baixar
update-install = Atualizar e reiniciar
update-installing = Baixando o Cardwave { $version }…
update-auto = Verificar automaticamente
update-auto-about = Procurar uma nova versão ao iniciar e uma vez por dia
update-check = Verificar
update-about = Verifica se há uma versão mais nova do aplicativo.

## First run (views/setup.ts, setup/*.ts)

setup-manually = Digitar o endereço do provedor em Configurações
setup-manually-models = Configurar manualmente
setup-use-this = Usar este
setup-choose-folder = Escolher pasta
setup-this-computer = Este computador
setup-this-computer-about = Arquivos de modelos de IA (.gguf) que você baixou, executados pelo Cardwave
setup-models-example = C:\Users\você\Modelos
setup-models-says = Cada arquivo de modelo nela (.gguf) é um modelo de chat, que o Cardwave executa neste computador. Ainda sem arquivos de modelo? Escolha uma pasta vazia: Ajustes › Provedores › Este computador então oferece os modelos que cabem neste computador e os baixa nela.
setup-not-this = Não é este?
setup-recognised = Reconhecido:{ " " }
setup-provider = Provedor
setup-none-of-these = Nenhum destes?
setup-several = Esta chave serve para mais de um provedor. Qual é?
setup-unknown = O Cardwave não consegue saber de qual provedor é esta chave. Encontre o provedor pelo nome ou digite o endereço dele.
setup-find = Encontrar
setup-find-field = Nome ou site do provedor
setup-find-example = Nome ou site, como example.com
setup-find-hint = O Cardwave procura o endereço do provedor. Sua chave não é enviada.
setup-name = Nome
setup-name-hint = O nome na lista de provedores do Cardwave. Pode deixar em branco.
setup-address = Endereço
setup-address-hint = Copie do site do seu provedor, como https://api.example.com/v1
setup-continue = Continuar
setup-local = Usar um programa neste computador (como LM Studio ou Ollama)
setup-no-key = Sem chave?{ " " }
setup-api-key = Chave de API
setup-key-placeholder = Cole sua chave aqui
setup-found = Encontrado
setup-no-api = O Cardwave não encontrou nenhum endereço para a IA em { $website }. Procure o endereço na documentação do provedor (muitas vezes chamado de “base URL”) e digite-o.
setup-find-by-name = Encontrar pelo nome
setup-enter-address = Digitar o endereço
setup-how = Como configurar
setup-not-listed = Nenhum provedor chamado “{ $name }” está na lista. Digite o site dele ou o endereço.
setup-looking = Procurando…
setup-looking-servers = Procurando programas neste computador…
setup-no-server = Nenhum programa de IA responde neste computador (o Cardwave procurou { $names }). Abra um e procure de novo.
setup-no-other-server = Nenhum outro programa de IA responde neste computador (o Cardwave procurou { $names }). Abra um e procure de novo.
setup-tested = { " " }· testado
setup-picking = Escolhendo entre os modelos do seu provedor…
setup-the-helper-model = o modelo auxiliar
setup-want-voice = Baixar a voz
setup-want-search = Baixar o modelo de pesquisa
setup-confirm = Confirmar
setup-back = Voltar
setup-key-line = { $provider } · ····{ $end }
setup-key-line-none = { $provider } · sem chave
setup-unlisted = Ainda não escolhido. O provedor não lista modelos: digite o ID do modelo.
setup-not-chosen = Ainda não escolhido
setup-the-voice = Voz
setup-the-search-model = Busca
setup-nothing-now = Nada é baixado agora. Pesquisa e Voz podem ser configuradas depois em Configurações.
setup-downloaded = A baixar: { $what }.
setup-and = { $first } e { $second }
setup-download-size = Baixar ({ $size })
setup-where = Configuração · passo { $step } de { $steps }
setup-title-1 = Provedor
setup-title-2 = Modelos
setup-title-3 = Fichas
setup-title-4 = Downloads
setup-about-1 = Cole a chave de API do site do seu provedor de IA. O Cardwave encontra o provedor.
setup-about-2 = O Cardwave escolheu estes entre os modelos do seu provedor. Mude qualquer um agora ou depois nos Ajustes.
setup-about-3 = Se você tem arquivos de fichas de personagem (PNG ou JSON de outros apps), o Cardwave pode trazê-los de uma pasta.
setup-about-4 = Você já pode abrir o Cardwave: os downloads continuam, e um aviso diz quando terminarem.
setup-no-list = Nenhuma lista de modelos: { $why } Toque em Escolher para digitar o ID de um modelo, ou Voltar para conferir a chave.
setup-change = Trocar
setup-choose = Escolher
setup-worker-does = { " " }· escreve resumos, tags e memórias
setup-same-as-chat = Igual ao modelo de chat
setup-no-picks = Nenhum modelo escolhido: { $why }
setup-helper-model = Modelo auxiliar
setup-set-up = O Cardwave está pronto.
setup-folder-not-kept = Não foi possível usar a pasta de fichas: { $why }. Você pode escolhê-la de novo em Configurações › Dados.

setup-skip = Pular
setup-import-folder = Importar desta pasta
setup-cards-about = Só os arquivos de fichas são lidos; nada na pasta é movido ou alterado. As fichas dela entram quando a configuração termina, e as colocadas nela depois entram sozinhas. Você também pode escolhê-la depois em Configurações › Dados.
setup-done = Concluído
setup-done-mark = { " " }Concluído
setup-percent = { $percent }%
setup-waiting = Aguardando
setup-try-again = Tentar de novo
setup-try-voice-again = Tentar a voz de novo
setup-try-search-again = Tentar a busca de novo
setup-voice-failed = Não foi possível baixar a voz: { $why }
setup-search-failed = Não foi possível baixar o modelo de busca: { $why }
setup-downloads-done = Os downloads terminaram: o Cardwave está todo configurado.
setup-cards-later = Suas fichas entram da pasta assim que o Cardwave abrir.
setup-voice = Voz
setup-search = Pesquisa
setup-open = Abrir o Cardwave
setup-voice-named = { $name } · { $language }
setup-voice-model = Modelo de voz

## The breadcrumbs of a page under Settings

crumbs = Onde você está

## Providers (views/providers.ts)

providers-key-end = { $where } · chave ····{ $end }
providers-key-saved = { $where } · chave salva
providers-no-key = { $where } · sem chave
providers-thinking-cannot = { $provider } não consegue desligar o raciocínio deste modelo
providers-thinking-off = O modelo responde sem raciocinar antes
providers-thinking-on = O modelo raciocina antes de responder
providers-comfy-default = O padrão do ComfyUI
providers-workflow-note = Este workflow usa seus próprios modelos e tamanho, não o modelo de Imagens.
providers-testing-model = Testando o modelo…
providers-thinking-of = { $label }: raciocínio
providers-thinking = Raciocínio
providers-testing-workflow = Testando o workflow…
providers-workflows-from = Dos workflows que o ComfyUI guarda
providers-pictures-by = Imagens pelo “{ $name }”.
providers-pictures-default = Imagens pelo workflow padrão do ComfyUI.
providers-workflow = Workflow
providers-not-used = Ainda não é usado para nada
providers-folder-saved = Pasta salva.
providers-change-folder = Trocar a pasta de modelos
providers-choose-folder = Escolher uma pasta de modelos
providers-change = Trocar
providers-not-set-up = Não configurado
providers-folder-not-set-up = Executa modelos de uma pasta neste computador · não configurado
providers-menu = Menu do provedor: editar, remover
providers-remove = Remover
providers-removed = Provedor “{ $name }” removido.
providers-remove-with-models = Remover este provedor? Os modelos escolhidos dele deixam de ser usados.
providers-remove-ask = Remover este provedor?
providers-remove-key = Remover a chave
providers-key-removed = A chave é removida quando você salvar
providers-edit = Editar provedor
providers-keep-key = Deixe vazio para manter a chave salva.
providers-saved = Provedor “{ $name }” salvo.
providers-added = Provedor “{ $name }” adicionado.
providers-add = Adicionar provedor
providers-about = Onde a IA roda: um serviço na internet ou um programa neste computador. Abaixo de cada um, para que ele é usado.

## Voices (views/voices.ts)

voices-stop = Parar { $name }
voices-try = Ouvir { $name }
voices-model-about = Lê as mensagens em voz alta neste computador · { $size }
voices-default-of = Voz padrão: { $name }
voices-menu = Menu da voz: renomear, excluir
voices-rename = Renomear
voices-delete-ask = Excluir a voz “{ $name }”? Os personagens que a usam voltam à voz padrão.
voices-rename-title = Renomear voz
voices-name = Nome
voices-speed-value = { $speed }×
voices-speed = Velocidade
voices-speed-about = A velocidade com que as respostas são lidas, para todas as vozes
voices-make = Criar uma voz a partir de uma gravação
voices-provider-failed = Não foi possível carregar as vozes do provedor.
voices-provider-none = O provedor não lista vozes
voices-provider-own = As mensagens são lidas com a voz própria do provedor.
voices-voices = Vozes
voices-voices-about = A voz que lê as mensagens em voz alta. Um personagem pode ter a sua em "Vozes dos personagens".
voices-default = Voz padrão
voices-voice-of = Voz de { $name }
voices-back-default = Voltar à voz padrão
voices-name-title = { $name } · { $title }
voices-choose-character = Escolha um personagem
voices-all-have = Todos os personagens têm uma voz.
voices-set-for = Definir uma voz para um personagem
voices-character = Personagem
voices-voice = Voz
voices-character-first = Escolha um personagem primeiro.
voices-characters = Vozes dos personagens
voices-downloading = Baixando · { $size } · { $percent }%
voices-downloaded = Baixado · { $size }
voices-download-size = Download de { $size }
voices-action-of = { $action } { $name }
voices-language-downloaded = { $name } baixado
voices-built-in = Incluída
voices-languages = Idiomas que ela lê
voices-download = Baixar
voices-cancel = Cancelar
voices-delete = Excluir

## Advanced (views/advanced.ts)

advanced-context-size = Tamanho do contexto (tokens)
advanced-context-hint = Deixe vazio para 128.000
advanced-temperature = Temperatura
advanced-temperature-about = Mais alto: respostas mais surpreendentes. De 0 a 2
advanced-top-p = Top P
advanced-top-p-about = Mais baixo: só as palavras mais prováveis. De 0 a 1
advanced-frequency = Penalidade de frequência
advanced-frequency-about = Mais alto: menos palavras repetidas. De −2 a 2
advanced-presence = Penalidade de presença
advanced-presence-about = Mais alto: mais assuntos novos. De −2 a 2
advanced-seed = Semente
advanced-seed-about = O mesmo número dá a mesma resposta de novo
advanced-from-to = De { $min } a { $max }
advanced-whole-from = Um número inteiro a partir de { $min }
advanced-whole = Um número inteiro
advanced-number = Um número
advanced-sampling = Amostragem
advanced-sampling-about = Para o modelo de chat. Deixe um valor vazio para usar o padrão do provedor. Salvo enquanto você digita.
advanced-describing = Descrevendo… faltam { $count }
advanced-all-described = Todos os personagens estão descritos
advanced-not-described = { $count ->
    [one] { $count } personagem ainda não descrito
    [many] { $count } personagens ainda não descritos
   *[other] { $count } personagens ainda não descritos
  }
advanced-describe-cards = Descrever personagens
advanced-failed = { $count ->
    [one] { $count } falhou
    [many] { $count } falharam
   *[other] { $count } falharam
  }: { $failure }. Toque em Descrever personagens para tentar de novo.
advanced-describe-again = Descrever todas de novo
advanced-describe-again-stop = Parar
advanced-describe-again-about = Com o modelo auxiliar, reescreve a descrição de uma linha, o resumo e as tags de cada personagem e aquilo pelo que "Por necessidade" o encontra, cerca de 11.000 a 12.000 tokens cada. O que você editou continua. Os provedores cobram por tokens.
advanced-no-characters = Nenhum personagem para descrever
advanced-describe-again-far = { $done } de { $all } descritos de novo
advanced-describe-again-failed = { $count ->
    [one] { $count } falhou e fica como estava
    [many] { $count } falharam e ficam como estavam
   *[other] { $count } falharam e ficam como estavam
  }: { $failure }. Toque em Descrever todas de novo para tentar mais uma vez.
advanced-describe-about = Para cada um, uma descrição de uma linha, um resumo e tags, escritos pelo modelo auxiliar
advanced-plain = Chat sem personagem
advanced-told-about = As mesmas em todo chat sem personagem. Escreva { "{{date}}" } ou { "{{time}}" } e a IA recebe a data de hoje ou a hora
advanced-library = Biblioteca
advanced-interview-about = Como a IA faz as perguntas a você
advanced-interview-tree = Árvore
advanced-interview-cloud = Nuvem
advanced-interview-hybrid = Híbrido
advanced-data = Dados
advanced-format-about = O formato em que Exportar grava cada cartão; a maioria dos apps abre SillyTavern V3
advanced-history-about = As versões anteriores de cada texto; só no formato de cartão próprio do Cardwave
advanced-helper = Modelo auxiliar
advanced-the-helper = o modelo auxiliar

## Cardwave's CSS (views/css-reference.ts)

cssref-rail = A barra lateral esquerda
cssref-main = Uma tela ao lado da barra lateral
cssref-crumbs = O caminho no topo de uma página
cssref-group = Uma caixa de linhas, como nas configurações
cssref-item = Uma linha de uma caixa
cssref-row = Uma linha de uma lista
cssref-tile = Um cartão na grade da biblioteca
cssref-msg = Uma mensagem em um chat
cssref-bubble = O balão de uma mensagem
cssref-composer = O campo de mensagem sob um chat
cssref-dialog = Uma caixa de diálogo
cssref-btn-primary = O botão azul
cssref-switch = Um interruptor
cssref-pill = Uma pílula
cssref-notice = O aviso no rodapé da janela
cssref-snippet-green = Um destaque verde
cssref-snippet-square = Balões quadrados
cssref-snippet-larger = Texto maior
cssref-snippet-wider = Caixas de diálogo mais largas
cssref-snippet-tighter = Espaçamento mais justo
cssref-snippet-black = Um tema escuro preto
cssref-in-dark = { $light } · no escuro { $dark }
cssref-none = Nenhuma variável com esse nome.
cssref-copy-of = Copiar “{ $title }”
cssref-copied = Copiado.
cssref-copy = Copiar
cssref-about-1 = As variáveis e os nomes de classe que seu próprio CSS pode usar. Cada cor e tamanho do aplicativo é uma variável em{ " " }
cssref-about-2 = , com um valor claro e um escuro.
cssref-variables = Variáveis
cssref-search = Pesquisar
cssref-find = Encontrar uma variável
cssref-all = { $count } variáveis ao todo.
cssref-classes = Nomes de classe
cssref-snippets = Trechos

## Tools the AI wrote (views/written-tools.ts)

written-about = { $what } · criada { $made }
written-about-in = { $what } · criada { $made } em { $chat }
written-used = { $count ->
    [0] ainda não usada
    [one] usada uma vez
    [many] usada { $count } vezes
   *[other] usada { $count } vezes
  }
written-none = Ainda não há ferramentas. Ative “Deixar a IA escrever ferramentas” em um chat, e o que ela escrever aparece aqui.
written-ask = Perguntar antes que uma nova ferramenta seja executada
written-ask-about = Uma vez por ferramenta: você a permite na primeira vez que ela roda
written-in = { " " }em{ " " }
written-made = Criada { $made }
written-dot-used = { " " }· { $used }
written-switch-off = Desativar
written-switch-on = Ativar
written-intro = Pequenas ferramentas que a IA escreveu para si em chats com “Deixar a IA escrever ferramentas” ativado. Só mexem nos seus arquivos se você permitir e ficam guardadas para chats futuros.
written-deleted = Ferramenta “{ $name }” excluída.
written-on = { $name } ativada
written-view-code = Ver o código

## The coding team, shared by the chat and its pages (chat/coding.ts)

coding-quick = Rápida
coding-balanced = Equilibrada
coding-thorough = Minuciosa
coding-custom = Personalizada
coding-running = Em andamento
coding-done = Concluída
coding-failed = Falhou
coding-stopped = Parada
coding-team-says-alone = { $name }: um planejador, { $workers ->
    [1] um executor
    [2] dois executores
   *[other] três executores
  }, sem auditor.
coding-team-says-tests = { $name }: um planejador, { $workers ->
    [1] um executor
    [2] dois executores
   *[other] três executores
  } e um auditor que roda os testes.
coding-team-says-steps = { $name }: um planejador, { $workers ->
    [1] um executor
    [2] dois executores
   *[other] três executores
  } e um auditor que confere cada passo e roda os testes.
coding-team-label = { $name } · { $workers ->
    [one] { $workers } executor
    [many] { $workers } executores
   *[other] { $workers } executores
  }
coding-team-label-auditor = { $name } · { $workers ->
    [one] { $workers } executor
    [many] { $workers } executores
   *[other] { $workers } executores
  }, auditor
coding-team-label-steps = { $name } · { $workers ->
    [one] { $workers } executor
    [many] { $workers } executores
   *[other] { $workers } executores
  }, auditor a cada passo
coding-tests-pass = { $passed } de { $total } testes passam
coding-passed = Aprovado
coding-problems = Problemas encontrados

## Coding team (views/coding-team.ts)

team-audit-end = No final
team-audit-each = Depois de cada passo
team-audit-never = Nunca
team-change = Trocar
team-workers-of = { $model } · { $workers } ao mesmo tempo
team-worker-model = Modelo dos executores
team-change-worker = Trocar o modelo dos executores
team-how-many = Quantos executores
team-none = Nenhum
team-auditor-tests = { $model } · roda os testes
team-auditor-steps = { $model } · confere cada passo
team-auditor-model = Modelo do auditor
team-change-auditor = Trocar o modelo do auditor
team-when = Quando o auditor confere
team-team = Equipe
team-roles = Papéis
team-planner-model = Modelo do planejador
team-change-planner = Trocar o modelo do planejador
team-recent = Tarefas recentes
team-intro = IAs que escrevem juntas um programa para você neste computador, iniciadas a partir de um chat.
team-no-tasks = Ainda não há tarefas. Uma tarefa é iniciada em um chat, com o “+” ao lado do campo de mensagem › Iniciar uma tarefa de programação.

## Trash (views/trash.ts)

trash-expressions = Expressões · nenhum personagem as tem
trash-figure = Figura 3D · nenhum personagem a tem
trash-chat-with = Chat com { $names }
trash-chat = Chat
trash-persona = Persona
trash-persona-used = Persona · usada em { $count ->
    [one] { $count } chat
    [many] { $count } chats
   *[other] { $count } chats
  }
trash-lorebook = Lorebook
trash-lorebook-used = Lorebook · usado em { $count ->
    [one] { $count } chat
    [many] { $count } chats
   *[other] { $count } chats
  }
trash-character = Personagem
trash-character-chats = Personagem · com { $count ->
    [one] { $count } chat
    [many] { $count } chats
   *[other] { $count } chats
  }
trash-empty = A Lixeira está vazia.
trash-about = O que é movido para cá fica guardado por { $days } dias e depois é excluído para sempre.
trash-emptied = Lixeira esvaziada.
trash-empty-trash = Esvaziar a Lixeira
trash-delete-all-ask = Excluir { $count ->
    [one] o { $count } item
    [many] todos os { $count } itens
   *[other] todos os { $count } itens
  } para sempre?
trash-restored = “{ $title }” restaurado.
trash-deleted = “{ $title }” excluído para sempre.
trash-deleted-at = Movido para cá { $when }
trash-days-left = { $count ->
    [one] falta { $count } dia
    [many] faltam { $count } dias
   *[other] faltam { $count } dias
  }
trash-restore = Restaurar
trash-restore-chats = Traz de volta o personagem e { $count ->
    [one] o chat dele
    [many] os { $count } chats dele
   *[other] os { $count } chats dele
  }
trash-delete-forever = Excluir para sempre
trash-delete-forever-ask = Excluir “{ $title }” para sempre? Não será possível recuperar.
trash-delete-forever-ask-chats = Excluir “{ $title }” e { $count ->
    [one] o chat dele
    [many] os { $count } chats dele
   *[other] os { $count } chats dele
  } para sempre? Não será possível recuperar.

## About Cardwave (views/about.ts)

about-no-package = Nenhum pacote com esse nome.
about-no-notes = Esta versão não traz notas.
about-by = por { $by }
about-licence-of = Licença de { $name }
about-licence = Licença
about-folder-failed = A pasta não abriu: { $reason }. Ela está em { $where }.
about-open-folder = Abrir pasta
about-logs-where = na pasta “logs” da pasta de dados do Cardwave, no computador em que o Cardwave roda
about-logs = Logs
about-logs-about = O que o Cardwave fez e eventuais falhas, um arquivo por dia, guardados por 7 dias: para ajudar quando algo der errado · { $where }
about-version = Versão { $version }
about-whats-new = Novidades
about-packages = { $count } pacotes
about-open-source = Software de código aberto
about-search = Pesquisar
about-find = Encontrar um pacote
about-version-built = Versão { $version } · { $built }
about-models = Modelos
about-figures = Figuras e animações
about-voices = Vozes
about-lists = Lista de provedores e modelos

about-or = ou
about-and = e
about-with = com

## Prompt preset (views/prompt-preset.ts)

prompt-new = Novo preset de prompt
promptpage-system = Prompt de sistema
prompt-system-about = Substitui o prompt de sistema da ficha. Deixe vazio para manter o da ficha.
promptpage-note = Nota
prompt-note-about = A IA a lê antes de cada resposta; você não a vê no chat. Ela vai tantas mensagens atrás quanto definido abaixo.
prompt-depth = Mensagens atrás
prompt-intro = Instruções para a IA. Escolha o preset no painel lateral de um chat para usá-lo ali.
prompt-depth-about = 1 a coloca logo antes da mensagem mais nova; 4, quatro mensagens atrás.
prompt-saved = Preset “{ $name }” salvo.
prompt-gone = Esta predefinição de prompt foi excluída. Volte e escolha outra.

## Profile (views/profile.ts)

profile-change-picture = Trocar a imagem
profile-change = Trocar
profile-remove-picture = Remover a imagem
profile-remove = Remover
profile-picture-changed = Imagem trocada.
profile-picture-removed = Imagem removida.
profile-your-picture = Sua imagem
profile-no-picture = Sem imagem: sua inicial { $letter } é mostrada
profile-change-name = Trocar o nome
profile-this-computer = A conta deste computador
profile-on-server = Conta neste computador
profile-account = Conta

## Server (views/server.ts)

server-copy = Copiar
server-no-network = Este computador não está conectado a uma rede. Conecte-o ao Wi-Fi ou a um cabo para deixar outros dispositivos entrarem.
server-switch-on-about = Celulares e outros computadores nesta rede poderão então abrir o Cardwave. Cada conta entra com sua senha.
server-switch-on = Ativar
server-network-about = Celulares e outros computadores abrem o Cardwave em um navegador
server-other-devices = Outros dispositivos
server-inside = Só dispositivos desta rede o alcançam, a menos que você configure seu roteador para deixar outros entrarem.
server-add-account = Adicionar conta
server-owner = Este computador · pode adicionar e remover contas
server-more-of = Mais: { $name }
server-reset-password = Redefinir a senha
server-delete-account = Excluir a conta
server-deleted = Conta “{ $name }” excluída.
server-delete-ask = Excluir esta conta com seus personagens, chats e configurações? Isso não pode ser desfeito.
server-reset-title = Redefinir a senha de { $name }
server-reset-about = A conta entra com a nova senha e sai de todos os lugares em que estiver conectada.
server-new-password = Nova senha
server-reset-done = Senha de { $name } redefinida.
server-reset = Redefinir
server-accounts = Contas

## Character generator (views/generator.ts)

gen-gender-woman = Mulher
gen-gender-man = Homem
gen-gender-non-binary = Não binário
gen-being-human = Humano
gen-being-not-human = Não humano
gen-age-20s = Na casa dos 20
gen-age-30s = Na casa dos 30
gen-age-40s = Na casa dos 40
gen-age-50s-and-older = 50 ou mais
gen-build-slim = Esguia
gen-build-average = Média
gen-build-athletic = Atlética
gen-build-strong = Forte
gen-hair-short = Curto
gen-hair-medium = Médio
gen-hair-long = Longo
gen-colour-black = Preto
gen-colour-brown = Castanho
gen-colour-blonde = Loiro
gen-colour-red = Ruivo
gen-colour-grey = Grisalho
gen-colour-white = Branco
gen-relation-stranger = Desconhecido/a
gen-relation-friend = Amigo/a
gen-relation-partner = Parceiro/a
gen-relation-rival = Rival
gen-relation-colleague = Colega
gen-relation-mentor = Mentor/a
gen-shy = Timidez
gen-outgoing = Extroversão
gen-gentle = Gentileza
gen-harsh = Dureza
gen-serious = Seriedade
gen-playful = Descontração
gen-cautious = Cautela
gen-bold = Ousadia
gen-random = Aleatório
gen-slider = { $low } a { $high }
gen-looks = Aparência
gen-gender = Gênero
gen-being = Humano ou não
gen-any = Qualquer
gen-age = Idade
gen-build = Constituição
gen-hair = Cabelo
gen-hair-colour = Cor do cabelo
gen-personality = Personalidade
gen-relates = Quem o personagem é para você
gen-make = Criar o personagem
gen-what = Escolha alguns traços; a IA escreve o personagem, a história dele e a primeira mensagem.
interview-goes-to = Suas respostas vão para { $provider } para escrever o personagem.
interview-stays = Suas respostas ficam neste computador.
interview-own-words = Ou acrescente suas próprias palavras
interview-in-own-words = Com suas próprias palavras
interview-your-answer = Sua resposta
interview-pick-one = Escolha uma
interview-pick-two = Escolha uma ou duas
interview-pick-three = Escolha até três
interview-pick-many = Escolha quantas combinarem
interview-few-words = Poucas palavras bastam
interview-wanted-hint = O que faltava com as pessoas, ou com os personagens que você experimentou?
interview-needs-hint = Para o seu tempo com o personagem, não para o resto da sua vida
interview-next = Próxima
interview-skip = Pular
interview-dont-know = Não sei
interview-back = Voltar
interview-just-make-it = Pode criar assim
interview-more = Mais tipos
interview-writing-next = Escrevendo a próxima pergunta
interview-try-again = Tentar de novo
interview-failed-where = Se continuar falhando, veja o provedor e o modelo em Configurações › Provedores.
gen-stop = Parar
gen-writing = Escrevendo o personagem…
interview-understood = Foi isto que eu entendi.
interview-you-said = você disse: “{ $words }”
interview-own-guess = um palpite da própria IA
interview-keep = Manter
interview-change = Alterar
interview-remove = Remover
interview-not-it = Não é isso
interview-not-it-off = Esta linha não vem de uma pergunta que possa ser feita de novo
interview-own-sentence = Sua própria frase
interview-private-line = Algo que você quer no mundo do seu personagem, ou nunca?
interview-private-sub = Romance, violência, palavrões e mais · opcional
interview-make = Criar o personagem
interview-make-after = Depois você pode mudá-lo na página dele.
interview-skip-all = Pular tudo
interview-private-hint = Algumas pessoas querem estas coisas no mundo do seu personagem, outras não. Suas respostas ficam com este personagem no seu computador e vão só para a IA que escreve o personagem.
interview-private-free = Mais alguma coisa que você quer, ou nunca quer
interview-yes = Sim
interview-no = Não
interview-maybe = Talvez
interview-fantasy-only = Só na fantasia
interview-never = Nunca
interview-try-another = Tentar outro modelo
interview-without-topic = Escrever sem esse tema
interview-model-provider = { $model } · { $provider }
interview-reading = Lendo suas respostas
interview-persona-title = Adicionar à sua persona o que você disse sobre si?
interview-persona-field = Persona
interview-persona-in-use = { $persona } · em uso
interview-persona-new = Nova persona
interview-persona-add = Adicionar
interview-persona-not-now = Agora não
interview-persona-added = Adicionado a “{ $persona }”.
interview-persona-you = Você
