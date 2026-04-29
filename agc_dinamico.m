% Anotações e Ideias
% - Algoritmo NLMS (Normalized Least Mean Squares).

% Exemplo inicial com a música e geração de ruído
[x, fs] = audioread("musica.wav");

% Gerando um ruído com a mesma duração da música
ruido = 0.1 * randn(length(x), 1); 

% Calculando o RMS de cada sinal (sqrt(mean(sinal.^2)))
rmsMusica = rms(x);
rmsRuido = rms(ruido);

% Exibindo os valores no Console
fprintf('--- Resultados de RMS ---\n');
fprintf('RMS da Música: %.4f\n', rmsMusica);
fprintf('RMS do Ruído:  %.4f\n', rmsRuido);

% 5. Mostrando os sinais e seus níveis médios (RMS) no gráfico
t = (0:length(x)-1) / fs;

figure;

% Sinal da Música
subplot(2,1,1);
plot(t, x, 'b');
hold on;
yline(rmsMusica, 'r', 'LineWidth', 2); % Linha horizontal no nível RMS
yline(-rmsMusica, 'r', 'LineWidth', 2);
title(['Música Original (RMS: ', num2str(rmsMusica, 3), ')']);
ylabel('Amplitude');
legend('Sinal', 'Nível RMS');
grid on;

% Sinal do Ruído
subplot(2,1,2);
plot(t, ruido, 'k');
hold on;
yline(rmsRuido, 'r', 'LineWidth', 2);
yline(-rmsRuido, 'r', 'LineWidth', 2);
title(['Ruído Gerado (RMS: ', num2str(rmsRuido, 3), ')']);
xlabel('Tempo (segundos)');
ylabel('Amplitude');
legend('Sinal', 'Nível RMS');
grid on;

% Tocando a musica com o ruido sem o ganho aplicado
mix = x+ruido;
sound(mix, fs);
pause(length(mix)/fs + 0.5);

% Tocando a musica com o ruido e o ganho aplicado
ganho = (rmsRuido/rmsMusica) * 2;
x_alto = x*ganho;
mix = x_alto+ruido;
mix = mix/max(abs(mix));

sound(mix, fs);



