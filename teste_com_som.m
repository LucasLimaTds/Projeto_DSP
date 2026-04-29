% =========================================================================
% Tempo Real: AGC + AEC com Microfone e Alto-falante Físicos
% =========================================================================
clear; clc;

%% 1. CONFIGURAÇÃO DE HARDWARE E ARQUIVOS
frameSize = 512; % Tamanho do buffer (latência)

% Leitor da Música (Coloque um arquivo .wav na mesma pasta do script)
try
    leitor_musica = dsp.AudioFileReader('musica_teste.wav', ...
        'SamplesPerFrame', frameSize, ...
        'PlayCount', inf); % Fica em loop infinito
    Fs = leitor_musica.SampleRate;
catch
    error('Erro: Coloque um arquivo chamado "musica_teste.wav" na pasta!');
end

% Leitor do Microfone (Captura o ruído ambiente + vazamento do alto-falante)
leitor_mic = audioDeviceReader('SampleRate', Fs, 'SamplesPerFrame', frameSize);

% Saída para o Alto-falante (A música amplificada)
saida_altofalante = audioDeviceWriter('SampleRate', Fs);

%% 2. INICIALIZAÇÃO DAS VARIÁVEIS (AEC E AGC)
% AEC (Filtro Adaptativo)
numTaps = 256;                  % Aumentei a memória do filtro para a sala real
mu = 0.05;                      % Passo um pouco menor para maior estabilidade real
eps_nlms = 1e-6;
w = zeros(numTaps, 1);
x_buffer = zeros(numTaps, 1);

% AGC
baseGain = 1.0;
noiseThreshold = 0.02;          % Ajuste isso dependendo do seu microfone
alpha = 0.90;                   % Suavização
gainMultiplier = 4.0;           % O quanto o volume sobe
currentGain = baseGain;

%% 3. LOOP DE PROCESSAMENTO EM TEMPO REAL
disp('🔥 Rodando em Tempo Real! Fale no microfone para testar.');
disp('Pressione Ctrl+C na Command Window para parar.');

% Como o leitor_musica pode ser estéreo, vamos converter para mono para facilitar o DSP
try
    while true
        % --- A. Captura os Buffers (O relógio do sistema) ---
        frame_musica_stereo = leitor_musica();
        frame_musica = mean(frame_musica_stereo, 2); % Converte para Mono
        
        frame_mic = leitor_mic();
        frame_mic = frame_mic(:, 1); % Garante que o mic seja Mono
        
        frame_ruido_limpo = zeros(frameSize, 1);
        
        % --- B. Cancelamento de Eco (AEC) Amostra por Amostra ---
        for n = 1:frameSize
            x_buffer = [frame_musica(n); x_buffer(1:end-1)];
            
            y_est = dot(w, x_buffer);
            e = frame_mic(n) - y_est; % Erro = Ruído real da sala
            
            energia_x = dot(x_buffer, x_buffer);
            w = w + (mu / (energia_x + eps_nlms)) * e * x_buffer;
            
            frame_ruido_limpo(n) = e;
        end
        
        % --- C. Controle de Ganho (AGC) ---
        rms_ruido = sqrt(mean(frame_ruido_limpo.^2));
        
        if rms_ruido > noiseThreshold
            targetGain = baseGain + ((rms_ruido - noiseThreshold) * gainMultiplier);
        else
            targetGain = baseGain;
        end
        
        currentGain = (alpha * currentGain) + ((1 - alpha) * targetGain);
        
        % Opcional: Trava de segurança para não estourar a caixa de som
        if currentGain > 5.0
            currentGain = 5.0;
        end
        
        % --- D. Aplica o Ganho e Toca ---
        frame_saida = frame_musica_stereo .* currentGain; % Mantém o estéreo original
        saida_altofalante(frame_saida);
        
    end
catch ME
    % Captura o Ctrl+C ou erros graciosamente e libera a placa de som
    release(leitor_musica);
    release(leitor_mic);
    release(saida_altofalante);
    disp('Processamento encerrado e hardware liberado.');
end