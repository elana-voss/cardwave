# 0.3.3

O Cardwave agora sabe quanto cada IA lê de uma vez, e não chuta mais.

- Cada resposta cabe no que o modelo dela consegue ler. O Cardwave pega o tamanho da sua lista de modelos embutida, ou pergunta à própria IA quando ela está no seu computador ou na sua rede local. Antes, todo modelo recebia 128.000 tokens.
- Um chat longo com um modelo que lê mais agora guarda mais do seu histórico.
- Quando o tamanho de uma IA não é conhecido, a resposta avisa, e você o define uma vez como tamanho do contexto em Configurações › Avançado. Até lá, nada é enviado.
- O tamanho do contexto em Configurações › Avançado agora limita o que é enviado a qualquer modelo.

# 0.3.2

O rosto do companheiro ganha vida, e ele responde ao seu toque.

- Uma figura 3D com formas de rosto pisca, olha para você e mostra no rosto os sentimentos e a voz, em VRM, GLB e FBX.
- Mesmo sem voz, os lábios do companheiro se mexem enquanto uma resposta chega.
- Clique na cabeça do companheiro, numa mão ou em outra parte do corpo: ele se assusta, e o personagem responde no balão de fala. Um clique duplo continua abrindo o chat.
- Em qualquer tamanho, o companheiro fica de pé, deita e anda com os pés na borda de baixo da janela, e não escorrega mais ao andar.
- Uma figura VRM que você adiciona mostra o nome de quem a criou.
- O painel lateral do chat lista cada ferramenta que uma resposta usou, em "Usado nesta resposta".
- Novo em Configurações › Avançado › Ferramentas para a IA: "Nomes para novos personagens" faz a IA tirar o nome de cada novo personagem de uma grande lista que combina com a cultura, a época e o gênero.

# 0.3.1

Uma pequena correção para Linux.

- Quando a leitura em voz alta não consegue começar no Linux, o Cardwave agora pede que você o reinstale, em vez de pedir um componente da Microsoft que o Linux não tem.

# 0.3.0

Cardwave no Linux.

- O Cardwave roda no Linux: a página da versão tem um AppImage, que roda na maioria dos computadores com Linux, e um .deb, que se instala no Ubuntu e no Debian.
- No Linux também, os rostos são encontrados na sua placa de vídeo, o microfone funciona na janela do Cardwave e as ferramentas de programação da IA executam comandos.
- Pequenas correções: os botões do topo de uma página cabem em uma janela estreita, e o menu da conta fica aberto enquanto suas contas carregam.

# 0.2.0

Cardwave no seu celular, e muitas correções.

- Abra o Cardwave de qualquer lugar: com o Tailscale, Conta › Compartilhamento mostra o endereço para abri-lo no seu celular ou em outro computador, e todas as telas cabem em um celular.
- As memórias pertencem a um personagem e à sua persona: trocar a persona de um chat começa memórias novas, e voltar encontra as antigas.
- O companheiro se move mais: muitos movimentos novos, escolhidos pelo humor dele, e mais quatro sentimentos: assustado, brincalhão, tímido e cansado.
- As figuras 3D são desenhadas com WebGPU onde o seu computador tem suporte.
- Um backup pode ser restaurado já na primeira inicialização, e um backup restaurado mantém a senha.
- Configurações mais organizadas: as ferramentas da IA foram para Avançado, e as abas podem ser desligadas em Configurações › Aparência.
- Os textos de um personagem mostram "Clique para editar" quando você aponta para eles, e o ícone da barra de tarefas preenche seu quadrado.
- Muitas correções encontradas numa busca pelo app inteiro.

# 0.1.3

Pequenas correções.

- Abrir o Cardwave quando ele já está aberto traz a janela para a frente, e quando ele não consegue iniciar porque outros programas usam as portas dele, ele avisa.
- Mais fácil de ler: as palavras dos botões azuis e as dicas de campos vazios no tema escuro, suas iniciais no tema claro.
- Chats: dados, escolhas aleatórias e variáveis de uma mensagem enviada continuam iguais em todas as respostas seguintes.
- Datas e horas na biblioteca e na página de um personagem seguem o seu idioma.
- O ditado ouve até uma única palavra curta, e frases longas sem pontuação são lidas em voz alta por inteiro.

# 0.1.2

Mais correções, de uma terceira rodada de testes.

- Memórias: o que você alterou ou apagou continua assim quando uma mensagem anterior é editada, e renomear um personagem ou uma persona mantém o que eles lembram.
- Chats: as palavras digitadas enquanto uma mensagem é enviada ficam no campo, o ditado mantém suas últimas palavras quando você troca de aba, e as datas nas saudações seguem o seu idioma.
- Mensagens mais claras quando um modelo deste computador falha no teste, quando o servidor de um download falha e quando a verificação de atualizações não consegue terminar.
- As abas cabem em uma janela estreita, seja como for que ela ficou estreita.

# 0.1.1

Correções de uma segunda rodada de testes.

- Backups: uma restauração espera o trabalho que ainda está em andamento, e o arquivo de backup leva a sua própria data.
- Primeira execução: um provedor adicionado em Configurações segue para a escolha dos modelos, uma chave recusada é informada como recusada, e configurar de novo com uma chave corrigida mantém um só provedor.
- Chats: um personagem longo demais para o modelo é avisado, não deixado de fora; imagens anexadas são reduzidas uma vez e continuam anexadas quando você sai do chat.
- A tela de senha e o login de outros dispositivos no seu idioma, e configurações que cabem na largura de um celular.
- Muitas correções menores em textos, abas, imagens e importações.

# 0.1.0

O Cardwave, refeito do zero: converse com os personagens da sua biblioteca, com modelos neste computador ou em um provedor.

- Sua biblioteca: importe fichas do SillyTavern e CCV4 ou crie as suas, e encontre-as pelas palavras ou pelo significado.
- Conversas com um personagem ou vários, que falam em turnos ou respondem sozinhos, com versões, outros caminhos, personas e lorebooks.
- Qualquer provedor: cole uma chave de API e o Cardwave sabe de quem ela é, ou escolha um modelo GGUF neste computador.
- Memórias: os personagens lembram o que aconteceu nas suas conversas.
- Vozes: respostas lidas em voz alta neste computador, na voz de cada personagem, e ditado.
- Ferramentas, conforme você as liga: busca na web, os arquivos de uma pasta, imagens.
- Doze idiomas, um tema claro e um escuro, uma senha e backups.
