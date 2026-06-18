clear; clc;

%% Configurações Iniciais
frequencia_amostragem = 44100;  
tamanho_frame = 512;            
qnt_coeficientes_filtro = 64;   
passo_adaptacao = 0.01;         

%% Configuração do Osciloscópio (TimeScope)
scope = timescope('SampleRate', frequencia_amostragem, ...
                  'TimeSpan', 1, ...                  
                  'NumInputPorts', 2, ...             
                  'LayoutDimensions', [2 1], ...      
                  'Title', 'Teste LMS - Senoide + WGN');

scope.ActiveDisplay = 1; 
scope.YLabel = 'Sinal Corrompido (Senoide + WGN)';
scope.YLimits = [-2.5 2.5]; 

scope.ActiveDisplay = 2; 
scope.YLabel = 'Saída LMS (Senoide Filtrada)';
scope.YLimits = [-2.5 2.5]; 
show(scope);

%% Geração dos Sinais 
tempo_total = 1; 
vetor_tempo = (0:1/frequencia_amostragem:tempo_total - 1/frequencia_amostragem)';
total_amostras = length(vetor_tempo);

% senoide 60Hz
senoide_desejada = 1 * sin(2 * pi * 60 * vetor_tempo);

% ruido branco (WGN)
ruido_branco = 0.5 * randn(total_amostras, 1);

% sinal "corrompido"
sinal_corrompido = senoide_desejada + ruido_branco;

ponteiro_leitura = 1;

%% Configurando o filtro LMS
w = zeros(qnt_coeficientes_filtro, 1);              
buffer_entrada = zeros(qnt_coeficientes_filtro, 1); 

fprintf("Simulação iniciada.\n");

%% Processamento por Frames
try
    while isVisible(scope)
        
        if (ponteiro_leitura + tamanho_frame - 1 > total_amostras)
            fprintf("fim do sinal\n");
            break; 
        end

        % frames atuais
        frame_corrompido = sinal_corrompido(ponteiro_leitura : ponteiro_leitura + tamanho_frame - 1);
        frame_ruido_ref = ruido_branco(ponteiro_leitura : ponteiro_leitura + tamanho_frame - 1);
        
        ponteiro_leitura = ponteiro_leitura + tamanho_frame;
        frame_sinal_limpo = zeros(tamanho_frame, 1);
        
        %%  LMS
        for n = 1:tamanho_frame
            buffer_entrada = [frame_ruido_ref(n); buffer_entrada(1:end-1)];
            
            
            estimativa_ruido = buffer_entrada' * w;
            erro_atual = frame_corrompido(n) - estimativa_ruido;
            frame_sinal_limpo(n) = erro_atual;
            
            w = w + passo_adaptacao * erro_atual * buffer_entrada;
        end
        
        %% Exibição no Gráfico
        scope(frame_corrompido, frame_sinal_limpo);
        pause(0.15);
        drawnow limitrate;
    end
catch exception
    release(scope);
    rethrow(exception);
end

release(scope);
fprintf("Simulação concluída.\n");