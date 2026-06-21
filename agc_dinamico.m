clear;clc;

%% Configurações Iniciais
frequencia_amostragem = 44100;  % Frequência padrão para áudio
tamanho_frame = 512;            % Quantidade de amostras em um pacote
qnt_coeficientes_filtro = 512;  % Tamanho do Filtro LMS (N)
passo_adaptacao = 0.01;        % Velocidade de convergência (mu)

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
[audio_musica, frequencia_amostragem_musica] = audioread('Musicas\musica_teste.wav');             
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
limite_silencio_rms = 0.01; % valor em que o ruído é considerado silêncio
ganho_maximo = 5.0;

epsilon = 1e-6; % evita divisao por 0 no NLMS

duracao_maxima = 60;

max_amostras = duracao_maxima * frequencia_amostragem;

historico_entrada = zeros(max_amostras,1);
historico_saida_ajustada = zeros(max_amostras,1);
historico_ruido_isolado = zeros(max_amostras,1);
indice = 1;

fprintf("Sistema iniciado.");

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
            
            %% LMS:
            % Ajustar os pesos do filtro para o próximo ciclo
            % w = w + passo_adaptacao * erro_atual * buffer_entrada;
            
            %% NLMS:
            energia_buffer = buffer_entrada' * buffer_entrada;
            w = w + (passo_adaptacao / (energia_buffer + epsilon)) * erro_atual * buffer_entrada;

            
        end

        %% Calcular o novo ganho
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

        fim = indice + tamanho_frame - 1;

        if fim <= max_amostras
            historico_entrada(indice:fim) = sinal_entrada;
            historico_saida_ajustada(indice:fim) = sinal_saida_ajustado;
            historico_ruido_isolado(indice:fim) = frame_ruido_ambiente;
        
            indice = fim + 1;
        else
            indice = 1; % buffer circular
        end
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

figure('Name', 'Análise Final dos Sinais', 'NumberTitle', 'off', 'WindowState', 'maximized');

% Gráfico 1
subplot(3, 1, 1);
plot(historico_entrada, 'y'); % 'y' plota em amarelo
title('1. Entrada Inicial (Microfone: Alerta + Ruído do Ambiente)');
xlabel('Amostras'); ylabel('Amplitude');
grid on;

% Gráfico 2
subplot(3, 1, 2);
plot(historico_ruido_isolado, 'r'); % 'r' plota em vermelho
title('2. Ruído Isolado pelo NLMS (Ruído Estimado)');
xlabel('Amostras'); ylabel('Amplitude');
grid on;

% Gráfico 3
subplot(3, 1, 3);
plot(historico_saida_ajustada, 'b'); % 'b' plota em azul
title('3. Saída Final (Música com Ganho Automático Aplicado)');
xlabel('Amostras'); ylabel('Amplitude');
grid on;