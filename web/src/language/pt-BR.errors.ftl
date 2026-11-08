### As palavras da interface em português do Brasil: as respostas de erro do servidor, uma para cada código de
### api/generated/Code.ts (errors.ts), `error-<code>` com "-" no lugar de "_"; traduzidas de en.errors.ftl.

## O pedido, como o servidor o recebeu

error-request-failed = Não foi possível fazer isso. Tente de novo.
error-internal = Algo deu errado no Cardwave. Tente de novo.
error-bad-request = O Cardwave não conseguiu ler esse pedido. Recarregue a página e tente de novo.
error-forbidden = Isso não é permitido.
error-no-such-path = O Cardwave não tem essa página. Recarregue a página e tente de novo.
error-method-not-allowed = O Cardwave não faz isso aqui. Recarregue a página e tente de novo.
error-too-large = Isso é grande demais. Tente um arquivo menor.
error-unsupported-type = O Cardwave não aceita esse tipo de arquivo aqui.

## Senhas e contas

error-locked = O Cardwave fica bloqueado até que a senha seja informada.
error-sign-in = Entre primeiro.
error-password-wrong = Senha errada.
error-password-needed = A senha é necessária.
error-current-password-needed = A senha atual é necessária.
error-backup-password-needed = Este backup precisa da senha dele.
error-too-many-tries = Senhas erradas demais. Tente de novo em { $seconds } segundos.
error-owner-only = Só a conta deste computador pode { $action ->
    [use_its_files] usar os arquivos dele
    [use_its_folders] usar as pastas dele
    [choose_its_models] escolher os modelos dele
    [lock_Cardwave] bloquear o Cardwave
   *[other] fazer isso
}.
error-no-password-to-lock = O Cardwave só bloqueia enquanto houver uma senha ativa.
error-remote-sign-in-off = Esta conta não pode entrar a partir de outro dispositivo. Ative isso em Conta › Compartilhamento.
error-no-password-on = Nenhuma senha está ativa.
error-no-password-set = Nenhuma senha foi definida para esta conta.
error-password-kept = Uma conta neste computador tem senha: ela entra com essa senha.
error-account-busy = O Cardwave ainda está escrevendo uma resposta ou lendo personagens; tente de novo quando terminar.
error-restore-busy = O Cardwave ainda está escrevendo uma resposta ou lendo personagens; tente de novo quando terminar.
error-backup-needs-password = Um backup precisa de uma senha.

## Do que se trata

error-not-found = Não existe { $what ->
    [account] essa conta
    [asset] esse arquivo na ficha
    [attachment] esse anexo
    [card] essa ficha
    [card_version] essa versão da ficha
    [chat] esse chat
    [chat_character] esse personagem no chat
    [checkpoint] esse ponto de restauração
    [deleted_message] essa mensagem excluída
    [document] esse documento
    [expression] essa expressão
    [expression_pack] conjunto de expressões
    [figure] essa figura
    [kind_of_model] esse tipo de modelo
    [language] esse idioma
    [lorebook] esse lorebook
    [lorebook_entry] essa entrada de lorebook
    [memory] essa memória
    [message] essa mensagem
    [model] esse modelo
    [persona] essa persona
    [picture] essa imagem
    [preset] esse preset
    [prompt_preset] esse preset de prompt
    [provider] esse provedor
    [question] essa pergunta
    [task] essa tarefa
    [tool] essa ferramenta
    [user] essa conta
    [voice] essa voz
   *[other] isso
}. Talvez isso tenha sido excluído.
error-chat-busy = Uma resposta está sendo escrita neste chat; interrompa-a primeiro.
error-no-provider = Nenhum provedor foi configurado ainda. Adicione um em Configurações › Provedores.
error-provider-refused = { $refusal ->
    [key] O provedor não aceitou a chave: confira em Configurações › Provedores.
    [busy] O provedor está sem crédito ou ocupado: tente de novo mais tarde.
    [down] O provedor não está respondendo: tente de novo mais tarde.
   *[other] O provedor recusou isto: { $reason }
}
error-model-declined = { $model } se recusou a escrever isso. Mude a mensagem ou escolha outro modelo.
error-model-sees-no-pictures = { $model } não consegue ver imagens, por isso não recebe nenhuma. Escolha um modelo que veja imagens para enviá-las.
error-card-trashed = O personagem está na Lixeira; restaure-o primeiro.
error-lorebook-trashed = O lorebook “{ $name }” está na Lixeira; restaure-o para usá-lo.
error-own-lorebook-flags = O lorebook próprio de um personagem vai junto com o personagem: ele não pode ser marcado com estrela, arquivado, movido para a Lixeira nem usado em todos os chats sozinho.

## Pastas e arquivos

error-no-such-folder = Não existe a pasta { $folder } neste computador.
error-folder-not-chosen = Escolha uma pasta primeiro.
error-drive-root-to-watch = A raiz de uma unidade contém coisas demais para acompanhar; escolha uma pasta dentro dela.
error-drive-root-for-model = A raiz de uma unidade tem coisas demais para dar à IA; escolha uma pasta dentro dela.
error-data-folder = Essa pasta contém os dados do próprio Cardwave, ou está dentro deles; escolha outra.
error-commands-windows-only = Comandos só são executados no Windows.
error-recycle-bin-windows-only = Mover arquivos para a Lixeira do Windows só é possível no Windows.
error-files-tool-off = Ative Arquivos em Configurações › Ferramentas primeiro: a equipe lê e escreve a pasta da tarefa com ela.

## Imagens, respostas e vozes

error-picture-words-missing = Diga primeiro o que a imagem mostra.
error-picture-words-too-long = O que a imagem mostra passa de { $most } caracteres.
error-picture-needs-words = Diga o que a imagem mostra.
error-goal-missing = Diga o que a equipe deve fazer.
error-dictation-not-set-up = O ditado não está configurado: Configurações › Modelos › Ditado.
error-direction-without-go-on = Uma dica só funciona com Continuar.
error-again-or-go-on = Uma resposta é escrita de novo ou continuada, não as duas coisas.
error-again-not-reply = Só a resposta de um personagem pode ser escrita de novo.
error-no-reply-to-write-again = O chat não tem resposta para escrever de novo.
error-no-text = A IA não enviou texto. Tente de novo.
error-worker-no-answer = O modelo auxiliar não deu resposta.
error-unknown-voice = Não existe a voz “{ $voice }”.
error-nothing-to-read = Não há nada para ler.
error-voice-not-downloaded = A voz não foi baixada.
error-voice-failed = A leitura em voz alta falhou. Tente de novo.
error-stopping = O Cardwave está encerrando.
error-download-failed = O download falhou. Verifique a conexão e tente de novo.
error-search-model-failed = O modelo de pesquisa falhou. O Cardwave tenta de novo daqui a pouco.
error-models-not-listed = Não foi possível listar os modelos do provedor. Confira o endereço e a chave e tente de novo.
error-file-not-imported = Não foi possível ler o arquivo: o Cardwave não conhece o formato dele.
error-describing-failed = O modelo auxiliar não conseguiu descrever o personagem.

## Os tipos pelos quais as falhas de uma área se agrupam: cada um escolhe as palavras por `what` (ou `whose`)

error-needed = { $what ->
    [persona_name] Uma persona precisa de um nome.
    [account_name] A conta precisa de um nome.
    [card_title] O personagem precisa de um título.
    [character_name] O personagem precisa de um nome.
    [chat_character] Um chat precisa de um personagem.
    [chat_title] O título de um chat precisa de palavras.
    [entry_name] Uma entrada precisa de um nome.
    [expression_files] Escolha um arquivo zip (uma pasta compactada) ou as imagens de um conjunto.
    [language] Falta o idioma.
    [lorebook_name] Um lorebook precisa de um nome.
    [memory_text] Uma memória precisa de um texto.
    [message_to_improve] Não há mensagem para melhorar.
    [model_name] O modelo precisa ser informado.
    [models_folder] Escolha primeiro uma pasta de modelos.
    [password] Uma senha não pode ficar vazia.
    [preset_name] O preset precisa de um nome.
    [rewrite_given] Falta algo necessário. Tente de novo.
    [summary] Um resumo precisa de palavras.
    [text_to_change] Não há texto para mudar.
    [text_to_read] Não há nada para ler.
    [voice_name] A voz precisa de um nome.
   *[other] Falta algo necessário. Tente de novo.
}
error-too-long = { $what ->
    [account_name] O nome de uma conta tem no máximo { $name_limit } caracteres.
    [chat_title] O título de um chat tem no máximo { $title_limit } caracteres.
    [document] { $name } é longo demais: um documento tem no máximo 2.000.000 caracteres.
    [entry_name] O nome de uma entrada tem no máximo { $max_name } caracteres.
    [field_name] O nome de um campo tem de 1 a { $max_field } sinais.
    [lorebook_name] O nome de um lorebook tem no máximo { $max_name } caracteres.
    [memory_text] Uma memória tem no máximo { $text_limit } caracteres.
    [persona_name] O nome de uma persona tem no máximo { $max_name } letras.
    [provider_name] O nome tem no máximo { $name_limit } caracteres.
    [unsaved_text] Um texto não salvo guarda no máximo { $max_text } sinais.
    [voice_name] O nome de uma voz tem no máximo { $name_most } caracteres.
   *[other] Isso passa de { $most } caracteres.
}
error-out-of-range = { $what ->
    [authors_note_depth] A nota é colocada uma mensagem atrás ou mais.
    [companion_size] O tamanho da companhia vai de { $start } a { $end } por cento da altura da tela.
    [context_size] O tamanho do contexto precisa ser de pelo menos 512 tokens.
    [entry_chance] A chance de uma entrada é de no máximo 100 por cento.
    [provider_setting] { $name } precisa ficar entre { $min } e { $max }.
    [reply_length] O tamanho da resposta precisa ficar entre 1 e { $most_reply_length } tokens.
    [slider] Um controle deslizante vai de 0 a 100.
    [talk_pause] A pausa precisa ficar entre 0 e { $most_talk_pause } segundos.
    [talk_replies] As respostas seguidas precisam ficar entre 1 e { $most_talk_replies }.
    [talkativeness] A loquacidade vai de 0 a 100.
    [voice_speed] A velocidade vai de { $start }% a { $end }%.
   *[other] Isso deve ficar entre { $least } e { $most }.
}
error-taken = { $what ->
    [card_in_library] Já está na sua biblioteca.
    [account_name] Outra conta já se chama “{ $name }”.
    [card_language] A ficha já está em { $name }.
    [chat_character] { $name } já está neste chat.
    [chat_character_twice] { $name } está duas vezes neste chat.
    [lorebook_same_name] A ficha já tem um lorebook ou uma entrada com o mesmo nome.
    [model_file] { $name } já está na pasta.
    [preset_name] Outro preset já se chama “{ $name }”.
    [tool_name] Já existe uma ferramenta chamada { $name }; escolha outro nome.
   *[other] Isso já existe.
}
error-in-trash = { $what ->
    [card] O personagem está na Lixeira; restaure-o primeiro.
    [card_to_chat] O personagem está na Lixeira; restaure o personagem para conversar de novo.
    [chat] O chat está na Lixeira; restaure-o primeiro.
    [chat_card] O personagem dele, “{ $title }”, está na Lixeira; restaure o personagem primeiro.
    [lorebook] O lorebook “{ $name }” está na Lixeira; restaure-o primeiro.
    [lorebook_to_use] O lorebook “{ $name }” está na Lixeira; restaure-o para usá-lo.
    [persona_default] Uma persona na Lixeira não pode ser a padrão; restaure-a primeiro.
    [persona_to_use] A persona “{ $name }” está na Lixeira; restaure-a para usá-la.
   *[other] Isso está na Lixeira; restaure primeiro.
}
error-not-readable = { $what ->
    [damaged_key] A chave está danificada.
    [json] O arquivo não é um JSON válido.
    [lorebook] O arquivo não contém nenhum lorebook.
    [lorebook_not_card] O arquivo é uma ficha de personagem, não um lorebook.
    [account_picture] A imagem não é um PNG ou JPEG legível de no máximo 4.096 pixels por lado.
    [attachment_picture] Uma imagem é um arquivo PNG, JPEG ou WebP.
    [backup] Este arquivo não é um backup do Cardwave.
    [backup_damaged] Este backup está danificado.
    [backup_key] Este backup está danificado: não é possível ler a chave dele.
    [base64] Isso não é base64.
    [base64_file] { $name } não é base64.
    [card_defined_twice] Este arquivo não é uma ficha de personagem que o Cardwave consiga ler. Exporte de novo pelo app de onde ele veio.
    [card_file_name] Um nome de arquivo na ficha não pode ser usado.
    [card_reference] Isso não indica nenhuma parte da ficha.
    [ccv4_version] Esta ficha foi feita por um Cardwave mais novo. Atualize o Cardwave para abri-la.
    [comfyui_address] Não é possível ler o endereço do ComfyUI.
    [comfyui_answer] Não é possível ler a resposta do ComfyUI.
    [dictation_recording] Não foi possível ler a gravação. Grave de novo.
    [document_text] { $name } não tem texto legível.
    [document_type] Um documento é um arquivo .txt, .md, .pdf ou .docx.
    [downloaded_model] O arquivo baixado não é o modelo.
    [expression_pack] Nenhuma de suas imagens tem o nome de um humor em inglês, como joy.png ou anger.png (PNG, JPEG, WebP ou GIF).
    [figure_file] { $file_name } não é um arquivo desse tipo.
    [figure_still] A imagem parada da figura não é um PNG de no máximo 4 MB.
    [figure_type] Uma figura 3D é um arquivo VRM, GLB ou FBX.
    [folder_read] Não é possível ler a pasta.
    [format_version] Este arquivo não é uma ficha de personagem que o Cardwave consiga ler. Exporte de novo pelo app de onde ele veio.
    [image_model_answer] Não é possível ler a resposta do modelo de imagem.
    [image_model_picture] Não é possível ler a imagem do modelo de imagem.
    [key_characters] A chave tem caracteres que uma chave não pode ter. Copie-a de novo do site do provedor.
    [lorebook_empty] O lorebook está vazio.
    [lorebook_entries] O lorebook não tem entradas.
    [lorebook_file] Não é possível ler o lorebook.
    [lorebook_named] Não é possível ler o lorebook “{ $name }”.
    [lorebook_named_empty] O lorebook “{ $name }” está vazio.
    [models_dev_list] Não é possível ler a lista de modelos.
    [models_list_answer] O endereço responde, mas não com uma lista de modelos.
    [models_list_missing] A lista de modelos não chegou.
    [name_characters] O nome contém caracteres que um nome não pode ter.
    [no_lorebook] Isso não é um lorebook.
    [pdf] Não é possível ler o PDF.
    [picture] A imagem não é PNG, JPEG nem WebP.
    [picture_server_answer] Não é possível ler a resposta do servidor de imagens.
    [picture_unreadable] Não é possível ler a imagem.
    [png] Não é um arquivo PNG.
    [png_damaged] O PNG está danificado.
    [provider_address] O endereço precisa ser um endereço web simples, como https://api.openai.com/v1.
    [provider_website] Informe o site do provedor como um nome, por exemplo example.com.
    [recording_format] Não é possível ler o formato da gravação.
    [recording_pcm] Não foi possível ler a gravação. Grave de novo.
    [recording_rate] Não é possível ler a taxa da gravação.
    [recording_short] A gravação é curta demais: são necessários pelo menos { $shortest } segundos.
    [recording_silent] A gravação não tem som.
    [recording_wav] A gravação não é um arquivo WAV.
    [sillytavern_base64] Este arquivo não é uma ficha de personagem que o Cardwave consiga ler. Exporte de novo pelo app de onde ele veio.
    [sillytavern_empty] A ficha está vazia.
    [sillytavern_file] Não é possível ler a ficha do SillyTavern neste arquivo.
    [sillytavern_json] Este arquivo não é uma ficha de personagem que o Cardwave consiga ler. Exporte de novo pelo app de onde ele veio.
    [sillytavern_object] Este arquivo não é uma ficha de personagem que o Cardwave consiga ler. Exporte de novo pelo app de onde ele veio.
    [sillytavern_png] Não é possível ler a ficha do SillyTavern neste PNG.
    [spec_version] Este arquivo não é uma ficha de personagem que o Cardwave consiga ler. Exporte de novo pelo app de onde ele veio.
    [spec_version_form] Este arquivo não é uma ficha de personagem que o Cardwave consiga ler. Exporte de novo pelo app de onde ele veio.
    [toml] Este arquivo não é uma ficha de personagem que o Cardwave consiga ler. Exporte de novo pelo app de onde ele veio.
    [word_file] Não é possível ler o arquivo do Word.
    [word_text] O arquivo do Word não tem texto.
    [workflow] Não é possível ler o workflow “{ $name }”.
    [workflow_api_form] O workflow foi salvo no formato para a API: salve-o no ComfyUI como workflow.
    [workflow_broken] Não é possível ler o workflow.
    [workflow_fields] O nó “{ $kind }” do workflow tem campos que o Cardwave não consegue ler.
    [workflow_no_node] O workflow não tem nenhum nó que este ComfyUI consiga executar.
    [workflow_node] O nó “{ $class }” do workflow não existe neste ComfyUI.
    [zip] Não é possível ler { $name } como zip.
   *[other] Não é possível ler isso.
}
error-too-big = { $what ->
    [card_for_worker] O personagem é longo demais para o modelo auxiliar; escolha um modelo auxiliar que leia mais.
    [card_file] O arquivo passa de { $most } MB.
    [checkpoint_folder] A pasta é grande demais para guardar cópias antes de cada passo.
    [expression_pack_size] As imagens de { $name } são grandes demais.
    [expression_zip_files] { $name } contém mais de { $max_entries } arquivos.
    [figure] A figura 3D é grande demais.
    [model_for_computer] { $name } é grande demais para este computador.
    [models_dev_list] A lista de modelos é longa demais.
    [picture_pixels] A imagem é grande demais ({ $wide } por { $high } pixels).
    [reply] A resposta foi cortada: ficou longa demais.
   *[other] Isso é grande demais.
}
error-not-now = { $what ->
    [character_has_written] { $name } já escreveu neste chat e fica nele.
    [coding_folder_busy] Outra tarefa de programação está rodando nessa pasta; espere por ela ou interrompa-a.
    [database_busy] O Cardwave estava ocupado; tente de novo.
    [download_cancelling] O download está sendo cancelado; tente de novo daqui a pouco.
    [held_by_card] Um personagem usa isto; remova-o do personagem primeiro.
    [lorebook_used_elsewhere] O lorebook agora é usado em outro lugar, por isso fica na biblioteca.
    [model_downloading] O modelo está sendo baixado.
    [model_replying] O modelo está respondendo; exclua-o quando a resposta terminar.
    [search_model_not_downloaded] O modelo de pesquisa não foi baixado.
    [task_running] A tarefa ainda está rodando; interrompa-a primeiro.
   *[other] Isso não pode ser feito agora. Tente de novo daqui a pouco.
}
error-changed = { $what ->
    [lorebook_entry] O lorebook agora tem outra entrada.
    [card_version] A ficha foi alterada nesse meio-tempo; ela é lida de novo.
    [tool_name] Outra ferramenta agora se chama { $name }.
    [two_ways] { $reference } foi alterado duas vezes ao mesmo tempo; tente de novo.
    [workflow] O workflow “{ $name }” foi alterado no ComfyUI: escolha-o de novo em Configurações › Provedores.
   *[other] Isso foi alterado nesse meio-tempo; tente de novo.
}
error-not-possible = { $what ->
    [back_to_computer] Só a pesquisa e a voz podem voltar para este computador.
    [card_about_itself] O que a ficha diz sobre si mesma não pode ser alterado.
    [card_change] Isso não pode ser alterado nesta ficha.
    [card_character] A ficha não tem esse personagem.
    [card_character_change] O personagem da ficha não pode ser alterado.
    [card_language_beside] A ficha não pode conter { $name } ao lado do primeiro idioma dela.
    [card_lorebook] A ficha não traz esse lorebook.
    [card_lorebook_attached] A ficha não tem esse lorebook anexado.
    [card_mode] A ficha não tem esse modo.
    [card_no_character] A ficha não tem personagem.
    [card_not_changed] A ficha não foi alterada.
    [card_part] Isso não é uma parte da ficha que se possa alterar.
    [card_takes_no] Esta ficha não aceita nada novo desse tipo.
    [card_takes_no_lorebook] A ficha não aceita lorebook.
    [character_change] Esse personagem não pode ser alterado nesta ficha.
    [chat_character] O chat não tem esse personagem.
    [chat_lore] O chat não tem esse lorebook nem essa entrada de lorebook.
    [chat_lorebook] O chat não tem esse lorebook.
    [chat_mode] O chat não tem esse modo.
    [chat_no_character] O chat não tem personagem.
    [chat_without_character] Um chat sem personagem não tem personagens.
    [chat_without_character_add] Um chat sem personagem não aceita nenhum.
    [checkpoint_put_back] Não é possível restaurar { $path }.
    [comfyui_no_picture] O ComfyUI não fez nenhuma imagem.
    [companion_not_answering] A companhia não respondeu.
    [companion_not_shown] A companhia não está à vista.
    [comfyui_queue] O ComfyUI não colocou a imagem na fila.
    [comfyui_said] O ComfyUI disse: { $said }
    [continue_no_text] A resposta não tem texto para continuar.
    [continue_only_reply] Só a resposta de um personagem pode ser continuada.
    [depth_note] Não é possível adicionar uma nota em uma profundidade.
    [dictation_failed] O modelo de ditado falhou.
    [dictation_model_load] Não é possível carregar o modelo de ditado.
    [dictation_model_start] Não é possível iniciar o modelo de ditado.
    [draft_made_by] Um rascunho não é feito por “{ $made }”.
    [edit_breaks_card] A ficha não poderia mais ser lida depois dessa mudança.
    [entry_change] A entrada não pode ser alterada desse jeito neste lorebook.
    [entry_taken_out] Isso não é uma entrada de lorebook que foi retirada.
    [export_no_character] A ficha não tem personagem para exportar.
    [greeting] Essa não é uma das saudações deste personagem.
    [improve_direction] Melhorar usa as palavras do campo; não aceita dica.
    [key_refused] A chave foi recusada.
    [llama_server_start] Não é possível iniciar o modelo de pesquisa. Reinicie o Cardwave e tente de novo.
    [local_address] Os modelos deste computador são encontrados pela pasta deles, em Configurações › Provedores.
    [lorebook_change] Este lorebook não pode ser alterado.
    [lorebook_change_breaks] O lorebook não poderia mais ser lido depois dessa mudança.
    [lorebook_new_entry] Este lorebook não aceita entrada nova.
    [lorebook_put_in] O lorebook não pode ser colocado nesta ficha.
    [lorebook_take_out] O lorebook não pode ser retirado desta ficha.
    [message_not_in_chat] A mensagem não faz parte deste chat.
    [message_not_in_view] A mensagem não está à vista.
    [model_remove] Não é possível remover { $path }.
    [no_folder] Essa pasta não existe neste computador.
    [no_image_model] Nenhum modelo de imagem foi configurado ainda: configure um em Configurações › Modelos › Imagens.
    [no_local_model] Não existe o modelo “{ $id }” nessa pasta.
    [no_local_models] Os modelos locais não estão configurados.
    [no_recycle_bin] Não há Lixeira do Windows para { $path }.
    [no_summary] A ficha ainda não tem resumo.
    [no_voice] Essa voz não existe.
    [no_vulkan] A placa de vídeo deste computador não consegue rodar modelos. Use um provedor no lugar.
    [no_vulkan_dictation] A placa de vídeo deste computador não consegue rodar o ditado.
    [prompt_change] O prompt desse personagem não pode ser alterado nesta ficha.
    [recycle_bin_move] { $path } não foi movido para a Lixeira do Windows.
    [speaker_not_in_chat] Quem fala não faz parte deste chat.
    [speaker_only_character] Só a mensagem de um personagem tem quem fala.
    [unknown_language] Esse não é um idioma que este aplicativo conhece.
    [version_lacks_character] Há um chat com um personagem que a versão mais nova não tem.
    [voice_runtime] Para ler em voz alta falta uma peça da Microsoft: instale o Visual C++ Redistributable pelo microsoft.com e reinicie o Cardwave.
    [workflow_no_text] O workflow “{ $name }” não tem campo de texto para as palavras da imagem.
    [workflow_use] O workflow “{ $name }” não pode ser usado.
    [written_tools_full] Você pode manter no máximo { $most_tools } ferramentas; exclua uma antes em Configurações › Ferramentas que a IA escreveu.
    [delete_not_in_trash] Só o que está na Lixeira pode ser excluído para sempre; mova para lá primeiro.
   *[other] Isso não pode ser feito.
}
error-model-answer = { $what ->
    [no_greeting] A IA não escreveu nenhuma saudação.
    [background_answer] Não foi possível usar a resposta do modelo auxiliar. Tente de novo ou escolha outro modelo auxiliar.
    [background_text] Não foi possível usar a resposta do modelo auxiliar. Tente de novo ou escolha outro modelo auxiliar.
    [card_texts] A resposta da IA não eram os textos do personagem.
    [classification] Não foi possível usar a resposta do modelo auxiliar. Tente de novo ou escolha outro modelo auxiliar.
    [example_messages] A IA não escreveu mensagens de exemplo.
    [no_example_message] A IA escreveu uma mensagem de exemplo sem o texto.
    [json] A resposta da IA não veio no formato pedido.
    [keywords] Não foi possível usar a resposta do modelo auxiliar. Tente de novo ou escolha outro modelo auxiliar.
    [logline] Não foi possível usar a resposta do modelo auxiliar. Tente de novo ou escolha outro modelo auxiliar.
    [no_chat_reply] O provedor da IA não enviou resposta de chat.
    [no_fitting_answer] A IA não deu nenhuma resposta utilizável em três tentativas.
    [no_picture] O modelo de imagem respondeu sem imagem.
    [no_plan] O planejador não fez nenhum plano.
    [no_text] A IA não enviou texto.
    [picture_address] A imagem do modelo de imagem está em um endereço que não é buscado.
    [picture_art] Não foi possível fazer a imagem; tente de novo.
    [picture_field] O modelo auxiliar não encontrou nenhum campo para as palavras da imagem.
    [picture_server_no_picture] O servidor de imagens respondeu sem imagem.
    [picture_words] O modelo auxiliar não escreveu palavras para a imagem.
    [rating] Não foi possível usar a resposta do modelo auxiliar. Tente de novo ou escolha outro modelo auxiliar.
    [reply_broke_off] A resposta foi interrompida.
    [needs] Não foi possível usar a resposta do modelo auxiliar. Tente de novo ou escolha outro modelo auxiliar.
    [rounds] A equipe não terminou o trabalho em { $rounds } rodadas.
    [search_left_out] O modelo de pesquisa deixou de fora um texto.
    [search_model] Não é possível ler a resposta do modelo de pesquisa.
    [search_tokens] Não é possível ler os tokens do modelo de pesquisa.
    [title] Não foi possível usar a resposta do modelo auxiliar. Tente de novo ou escolha outro modelo auxiliar.
    [too_many_tools] A IA chamou ferramentas demais.
    [worker_mode] Não foi possível usar a resposta do modelo auxiliar. Tente de novo ou escolha outro modelo auxiliar.
    [worker_texts] Não foi possível usar a resposta do modelo auxiliar. Tente de novo ou escolha outro modelo auxiliar.
    [server_reported] O provedor da IA informou: { $reason }
   *[other] A resposta da IA não pode ser usada.
}
error-timed-out = { $whose ->
    [comfyui] O ComfyUI não fez a imagem a tempo.
    [llama_server] O modelo de pesquisa não ficou pronto a tempo. Tente de novo.
    [model] A IA não respondeu a tempo. Tente de novo.
    [model_server] O provedor da IA não respondeu a tempo. Tente de novo.
    [search_model] O modelo de pesquisa não respondeu a tempo.
   *[other] Não houve resposta a tempo.
}
error-unreachable = { $whose ->
    [comfyui] Não é possível acessar o ComfyUI.
    [image_model] Não é possível acessar o modelo de imagem.
    [model_download] Não é possível baixar o arquivo do modelo.
    [model_server] O provedor da IA não está respondendo: tente de novo mais tarde ou confira a conexão.
    [picture_address] Não é possível buscar a imagem.
    [picture_server] Não é possível acessar o servidor de imagens.
    [provider_voices] Não é possível acessar as vozes do provedor.
    [search_model] O modelo de pesquisa não responde.
    [provider_voice] Não é possível acessar a voz do provedor.
    [provider_search_model] Não é possível acessar o modelo de pesquisa do provedor.
   *[other] Não é possível acessar.
}
error-answered = { $whose ->
    [comfyui] O ComfyUI respondeu { $status }.
    [model_server] O provedor da IA respondeu { $status }. Tente de novo mais tarde.
    [picture_server] O servidor de imagens respondeu { $status }.
    [provider_voices] As vozes do provedor responderam { $status }.
    [search_model] O modelo de pesquisa respondeu { $status }.
   *[other] A resposta foi { $status }.
}
