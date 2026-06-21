clear; clc;

%% Configurações Iniciais
frequencia_amostragem = 44100;  
tamanho_frame = 512;            
qnt_coeficientes_filtro = 64;   
passo_adaptacao = 0.0001;         

%% Configuração do Osciloscópio (TimeScope)
scope = timescope('SampleRate', frequencia_amostragem, ...
                  'TimeSpan', 1, ...                  
                  'NumInputPorts', 2, ...             
                  'LayoutDimensions', [2 1], ...      
                  'Title', 'Teste LMS - Musica + WGN');

scope.ActiveDisplay = 1; 
scope.YLabel = 'Sinal Corrompido (Musica + WGN)';
scope.YLimits = [-2.5 2.5]; 

scope.ActiveDisplay = 2; 
scope.YLabel = 'Saída LMS (Musica Filtrada)';
scope.YLimits = [-2.5 2.5]; 
show(scope);

%% Geração dos Sinais 
% musica
[audio, fs] = audioread("Musicas\down_under.mp3");
audio_mono = audio(:, 1);
audio_desejado = resample(audio_mono, frequencia_amostragem, fs);

% musica ruido
[audio_ruido, fs_ruido] = audioread("Musicas\guitar_town.mp3");
audio_ruido_mono = audio_ruido(:, 1);
audio_ruido = resample(audio_ruido_mono, frequencia_amostragem, fs_ruido);

% Correção dos tamanhos dos audios (para evitar o erro de tamanho na soma)
% calcula o tamanho do menor audio
total_amostras = min(length(audio_desejado), length(audio_ruido));

% corta as matrizes para ter o mesmo tamanho de audio
audio_desejado = audio_desejado(1:total_amostras);
audio_ruido = audio_ruido(1:total_amostras);

% sinal "corrompido"
sinal_corrompido = audio_desejado + audio_ruido;
ponteiro_leitura = 1;

%% Configurando o filtro LMS
w = zeros(qnt_coeficientes_filtro, 1);              
buffer_entrada = zeros(qnt_coeficientes_filtro, 1); 

fprintf("Simulação iniciada.\n");

saida_audio = audioDeviceWriter('SampleRate', frequencia_amostragem);

%% Processamento por Frames
try
    while isVisible(scope)
        
        if (ponteiro_leitura + tamanho_frame - 1 > total_amostras)
            fprintf("fim do sinal\n");
            break; 
        end

        % frames atuais
        frame_corrompido = sinal_corrompido(ponteiro_leitura : ponteiro_leitura + tamanho_frame - 1);
        frame_musica_pura = audio_desejado(ponteiro_leitura : ponteiro_leitura + tamanho_frame - 1);
        
        ponteiro_leitura = ponteiro_leitura + tamanho_frame;
        frame_ruido_isolado = zeros(tamanho_frame, 1);
        
        %%  LMS
        for n = 1:tamanho_frame
            buffer_entrada = [frame_musica_pura(n); buffer_entrada(1:end-1)];
            
            
            estimativa_ruido = buffer_entrada' * w;
            erro_atual = frame_corrompido(n) - estimativa_ruido;
            frame_ruido_isolado(n) = erro_atual;
            
            w = w + passo_adaptacao * erro_atual * buffer_entrada;
        end

        frame_estereo = [frame_corrompido, frame_ruido_isolado];
        saida_audio(frame_estereo);

        %% Exibição no Gráfico
        scope(frame_corrompido, frame_ruido_isolado);
        drawnow limitrate;
    end
catch exception
    release(scope);
    rethrow(exception);
end

release(scope);
fprintf("Simulação concluída.\n");