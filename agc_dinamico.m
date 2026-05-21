clear;clc;

%% Configurações Iniciais
frequencia_amostragem = 44100;  % Frequência padrão para áudio
tamanho_frame = 512;            % Quantidade de amostras em um pacote
qnt_coeficientes_filtro = 256;  % Tamanho do Filtro LMS (N)
passo_adaptacao = 0.005;        % Velocidade de convergência (mu)

% Entrada de áudio
entrada_audio_mic = audioDeviceReader('SampleRate', ...
                                    frequencia_amostragem, ...
                                    'SamplesPerFrame', ...
                                    tamanho_frame);
% Saída de áudio
saida_audio = audioDeviceWriter('SampleRate', frequencia_amostragem);

%% Configuração do Osciloscópio (TimeScope)
% Cria uma interface otimizada para ver os sinais em tempo real
scope = timescope('SampleRate', frequencia_amostragem, ...
                  'TimeSpan', 2, ...                  % Mostra 2 segundos de histórico
                  'YLimits', [-1.5 1.5], ...          % Limites do eixo Y (amplitude)
                  'NumInputPorts', 2, ...             % Duas entradas (Mic e Saída)
                  'LayoutDimensions', [2 1], ...      % Duas linhas, uma coluna
                  'Title', 'Controle Automático de Ganho em Tempo Real');

scope.ActiveDisplay = 1; scope.YLabel = 'Microfone (Ruído + Eco)';
scope.ActiveDisplay = 2; scope.YLabel = 'Alerta com Ganho Ajustado';

show(scope);

%% Preparando o sinal da música
[audio_musica, frequencia_amostragem_musica] = audioread('musica.wav');             
% Converter para áudio mono
referencia_musica = resample(audio_musica(:,1), frequencia_amostragem, frequencia_amostragem_musica);
% A função resample, altera a taxa de amostragem da música para se adequar
% com a frequencia de amosragem definida inicialmente.
% audio_musica(:,1) pega apenas o canal esquerdo, tornando o audio mono.

total_amostras_musica = length(referencia_musica);
ponteiro_leitura = 1;       % Ponto da amostra atual na qual a leitura deve começar

%% Configurando o filtro LMS
w = zeros(qnt_coeficientes_filtro, 1);              % Vetor de pesos do filtro. Inicialmente zero
buffer_entrada = zeros(qnt_coeficientes_filtro, 1); % Buffer de estado. Guarda as últimas N amostras do sinal 

ganho_atual = 1.0;
suavizacao_do_ganho = 0.05;
limite_silencio_rms = 0.02; % valor em que o ruído é considerado silêncio
ganho_maximo = 5.0;

fprintf("Sistema iniciado. Fale no microfone...");

%% Processamento

try
    while isVisible(scope)
        % Ler o sinal de entrada do microfone
        sinal_entrada = entrada_audio_mic();

        % Obter o próximo frame da música
        % Verificar se tem amostras suficientes para ler um frame completo
        if ponteiro_leitura + tamanho_frame - 1 <= total_amostras_musica
            % Obter o pedaço correspondente da posição atual até o tamanho
            % do frame
            frame_musica = referencia_musica(ponteiro_leitura : ponteiro_leitura + tamanho_frame - 1);
            % Atualiza o ponteiro para a próxima posição
            ponteiro_leitura = ponteiro_leitura + tamanho_frame;
        else
            % Verifica as amostras restantes e faz um zero padding no frame
            amostras_restantes = referencia_musica(ponteiro_leitura:end);
            qnt_zeros_preenchimento = tamanho_frame - length(amostras_restantes);
            frame_musica = [amostras_restantes; zeros(qnt_zeros_preenchimento, 1)];
            
            % Reinicia o ponteiro de posição
            ponteiro_leitura = 1;
        end

        % Aplicar o ganho calculado no ciclo anterior
        sinal_saida_ajustado = frame_musica * ganho_atual;
        frame_ruido_ambiente = zeros(tamanho_frame, 1);

        %% Aplicar o filtro LMS
        for n = 1:tamanho_frame
            % O buffer recebe o frame atual e descarta a anterior (fila)
            buffer_entrada = [sinal_saida_ajustado(n); buffer_entrada(1:end-1)];
            
            % Estimar o eco
            estimativa_eco = buffer_entrada' * w;
            
            % Calcular o erro
            erro_atual = sinal_entrada(n) - estimativa_eco;
            frame_ruido_ambiente(n) = erro_atual;
            
            % Ajustar os pesos do filtro para o próximo ciclo
            w = w + passo_adaptacao * erro_atual * buffer_entrada;
        end

        %% Calcular o ACG
        rms_ruido_ambiente = rms(frame_ruido_ambiente);
        novo_ganho = 1.0 + (rms_ruido_ambiente / limite_silencio_rms);
        
        % limitar o novo ganho
        if novo_ganho > ganho_maximo
            novo_ganho = ganho_maximo;
        end
        
        % Filtro passa-baixas (suavização)
        ganho_atual = ganho_atual + suavizacao_do_ganho * (novo_ganho - ganho_atual);

        %% Saída
        saida_audio(sinal_saida_ajustado);
        scope(sinal_entrada, sinal_saida_ajustado);
        
        drawnow limitrate; % Deixa o audio mais fluido
    end
catch exception
    release(entrada_audio_mic);
    release(saida_audio);
    release(scope);
    fprintf("Ocorreu um erro.");
    rethrow(exception);
end

%% Liberando as variáveis contínuas
release(entrada_audio_mic);
release(saida_audio);
release(scope);
fprintf("Encerrado.");