% =========================================================================
% Simulação Integrada: Cancelamento de Eco (AEC) + Controle de Ganho (AGC)
% =========================================================================
clear; clc; close all;

%% 1. PARÂMETROS GERAIS E GERAÇÃO DE SINAIS SINTÉTICOS
Fs = 16000;             % Frequência de amostragem (16 kHz é ótimo para testes)
duracao = 5;            % Duração da simulação em segundos
t = (0:1/Fs:duracao-1/Fs)';
N_amostras = length(t);

% Sinal 1: A "Música" (Sinal de Referência)
% Uma mistura de duas frequências para simular um áudio rolando
sinal_musica = 0.5 * sin(2*pi*440*t) + 0.3 * sin(2*pi*1000*t);

% Sinal 2: O Eco da Sala (Caminho Acústico Simulado)
% Atrasamos a música em 50 amostras e atenuamos para simular o alto-falante vazando no mic
caminho_sala = [zeros(50, 1); 0.6; 0.3; 0.1]; 
eco_sala = filter(caminho_sala, 1, sinal_musica);

% Sinal 3: O Ruído Ambiente (O que realmente queremos medir)
% Fica em silêncio no começo, tem um pico alto entre os segundos 2 e 3, e volta pro silêncio
ruido_ambiente = zeros(N_amostras, 1);
ruido_ambiente(2*Fs : 3*Fs) = 0.4 * randn(Fs+1, 1); % Ruído branco no meio

% Sinal do Microfone Final = Eco da Música + Ruído da Sala
sinal_mic = eco_sala + ruido_ambiente;

%% 2. INICIALIZAÇÃO DAS VARIÁVEIS (AEC E AGC)
% Parâmetros do AEC (Filtro Adaptativo NLMS)
numTaps = 128;                  % Tamanho do filtro (memória)
mu = 0.1;                       % Passo de adaptação
eps_nlms = 1e-6;                % Proteção contra divisão por zero
w = zeros(numTaps, 1);          % Pesos iniciais do filtro
x_buffer = zeros(numTaps, 1);   % Buffer circular da música

% Parâmetros do AGC
frameSize = 512;                % Tamanho da janela de processamento
baseGain = 1.0;                 % Ganho padrão
noiseThreshold = 0.05;          % Limiar para começar a atuar
alpha = 0.95;                   % Fator de suavização (Attack/Release)
gainMultiplier = 3.0;           % Fator de amplificação
currentGain = baseGain;         % Estado inicial do ganho

% Vetores para salvar os resultados e plotar depois
ruido_limpo_out = zeros(N_amostras, 1);
ganho_historico = zeros(floor(N_amostras/frameSize), 1);
audio_final_out = zeros(N_amostras, 1);

%% 3. LOOP DE PROCESSAMENTO PRINCIPAL (Simulando buffers de hardware)
disp('Iniciando processamento...');

numFrames = floor(N_amostras / frameSize);
idx_amostra_global = 1;

for i = 1:numFrames
    % Extrai o frame (buffer) atual
    idx_inicio = (i-1)*frameSize + 1;
    idx_fim = i*frameSize;
    
    frame_musica = sinal_musica(idx_inicio:idx_fim);
    frame_mic = sinal_mic(idx_inicio:idx_fim);
    
    frame_ruido_limpo = zeros(frameSize, 1);
    
    % --- BLOCO 1: CANCELAMENTO DE ECO (Amostra por Amostra) ---
    for n = 1:frameSize
        % Atualiza buffer da música (FIFO)
        x_buffer = [frame_musica(n); x_buffer(1:end-1)];
        
        % Estima o eco e calcula o erro (que é o ruído real)
        y_est = dot(w, x_buffer);
        e = frame_mic(n) - y_est;
        
        % Atualiza os pesos do filtro (Mágica do NLMS)
        energia_x = dot(x_buffer, x_buffer);
        w = w + (mu / (energia_x + eps_nlms)) * e * x_buffer;
        
        % Salva o erro (ruído isolado)
        frame_ruido_limpo(n) = e;
        
        % Registra na saída global para visualização
        ruido_limpo_out(idx_amostra_global) = e;
        idx_amostra_global = idx_amostra_global + 1;
    end
    
    % --- BLOCO 2: CÁLCULO DO GANHO AGC (Por Frame) ---
    % Mede a energia (RMS) do ruído que sobrou
    rms_ruido = sqrt(mean(frame_ruido_limpo.^2));
    
    % Mapeamento de Ganho
    if rms_ruido > noiseThreshold
        targetGain = baseGain + ((rms_ruido - noiseThreshold) * gainMultiplier);
    else
        targetGain = baseGain;
    end
    
    % Suavização (Filtro Passa-Baixa no ganho)
    currentGain = (alpha * currentGain) + ((1 - alpha) * targetGain);
    
    % Registra histórico para o gráfico
    ganho_historico(i) = currentGain;
    
    % --- BLOCO 3: APLICAÇÃO DO GANHO ---
    frame_saida = frame_musica .* currentGain;
    audio_final_out(idx_inicio:idx_fim) = frame_saida;
end

disp('Processamento concluído!');

%% 4. VISUALIZAÇÃO DOS RESULTADOS (O Osciloscópio do DSP)
figure('Name', 'Análise do Sistema AGC+AEC', 'Position', [100, 100, 1000, 800]);

% Gráfico 1: O que o microfone ouviu vs Ruído Real
subplot(4,1,1);
plot(t, sinal_mic, 'Color', [0.8 0.8 0.8]); hold on;
plot(t, ruido_ambiente, 'r');
title('Microfone (Cinza) vs Ruído Ambiente Real (Vermelho)');
ylabel('Amplitude'); legend('Sinal do Mic (Música vazando + Ruído)', 'Ruído que queremos extrair');

% Gráfico 2: O Ruído Isolado pelo AEC
subplot(4,1,2);
plot(t, ruido_limpo_out, 'k');
title('Saída do Filtro AEC (Ruído Isolado)');
ylabel('Amplitude');
% Nota: no início o filtro deixa vazar música porque está aprendendo a sala!

% Gráfico 3: A curva do Ganho atuando
subplot(4,1,3);
tempo_frames = linspace(0, duracao, numFrames);
plot(tempo_frames, ganho_historico, 'b', 'LineWidth', 2);
title('Ação do AGC (Multiplicador de Volume)');
ylabel('Ganho'); ylim([0.8 max(ganho_historico)*1.2]);

% Gráfico 4: O Áudio Final gerado
subplot(4,1,4);
plot(t, sinal_musica, 'Color', [0.8 0.8 0.8]); hold on;
plot(t, audio_final_out, 'g');
title('Resultado: Música Original (Cinza) vs Música Amplificada (Verde)');
xlabel('Tempo (segundos)'); ylabel('Amplitude');