@echo off
:: ==============================================================================
:: FERRAMENTA DE DIAGNÓSTICO E MANUTENÇÃO DE SISTEMA
:: Este script automatiza rotinas comuns de suporte técnico, como limpeza de 
:: temporários, reparo do Windows, reset de rede e coleta de logs.
:: ==============================================================================

:: Define o padrão de caracteres para UTF-8 (garante que acentos apareçam corretamente no prompt)
chcp 65001 >nul

:: Define a cor do prompt (0 = Fundo Preto, A = Texto Verde) e o título da janela
color 0A
title Ferramenta de Diagnostico e Manutencao de Sistema

:: ==============================================================================
:: VALIDAÇÃO DE PRIVILÉGIOS DE ADMINISTRADOR
:: Muitos comandos (SFC, DISM, IP Release/Renew) exigem permissão de Administrador.
:: O comando 'net session' testa isso silenciosamente. Se der erro, ele avisa e fecha.
:: ==============================================================================
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :setup_log
) else (
    echo =======================================================
    echo ERRO: ESTE SCRIPT PRECISA SER EXECUTADO COMO ADMINISTRADOR!
    echo =======================================================
    echo Por favor, clique com o botão direito no arquivo e escolha:
    echo "Executar como administrador"
    pause
    exit
)

:: ==============================================================================
:: CONFIGURAÇÃO DO ARQUIVO DE LOG
:: Cria uma pasta raiz chamada TI_Logs no Disco C: para não perder o histórico.
:: Tudo o que o script fizer será registrado em Relatorio_Manutencao.txt.
:: ==============================================================================
:setup_log
set LOGDIR=C:\TI_Logs
if not exist "%LOGDIR%" mkdir "%LOGDIR%"
set LOGFILE=%LOGDIR%\Relatorio_Manutencao.txt

:: Registra a data e hora em que o script foi aberto
echo. >> "%LOGFILE%"
echo ======================================================= >> "%LOGFILE%"
echo SESSAO DE MANUTENCAO INICIADA EM: %date% as %time% >> "%LOGFILE%"
echo ======================================================= >> "%LOGFILE%"

:: ==============================================================================
:: MENU PRINCIPAL INTERATIVO
:: ==============================================================================
:menu
cls
echo =======================================================
echo           PAINEL DE MANUTENCAO E DIAGNOSTICO
echo =======================================================
echo LOG ATIVO EM: %LOGFILE%
echo =======================================================
echo [1]  Limpeza de arquivos temporarios
echo [2]  Limpeza de cache DNS
echo [3]  Reset de rede completo
echo [4]  Verificacao de IP (Detalhada)
echo [5]  SFC (Corrigir arquivos do Windows)
echo [6]  CHKDSK (Verificar e corrigir disco C:)
echo [7]  DISM (Reparar imagem do sistema)
echo [8]  Teste de conectividade (Ping)
echo [9]  Reset do Windows Update
echo [10] Monitoramento de portas (Netstat)
echo [11] Listagem de processos ativos
echo [12] Usuarios conectados na sessao
echo [13] Diagnostico completo de rede
echo [14] Limpeza geral automatizada
echo [15] Sair
echo =======================================================
set /p opcao="Escolha uma opcao (1-15): "

:: Direciona o fluxo do script com base na opção digitada pelo usuário
if "%opcao%"=="1" goto :temp
if "%opcao%"=="2" goto :dns
if "%opcao%"=="3" goto :reset_rede
if "%opcao%"=="4" goto :ip
if "%opcao%"=="5" goto :sfc
if "%opcao%"=="6" goto :chkdsk
if "%opcao%"=="7" goto :dism
if "%opcao%"=="8" goto :ping
if "%opcao%"=="9" goto :wupdate
if "%opcao%"=="10" goto :portas
if "%opcao%"=="11" goto :processos
if "%opcao%"=="12" goto :usuarios
if "%opcao%"=="13" goto :diagnostico
if "%opcao%"=="14" goto :limpeza_geral
if "%opcao%"=="15" goto :sair
goto :menu

:: ==============================================================================
:: [1] LIMPEZA DE ARQUIVOS TEMPORÁRIOS E LIXEIRA
:: Usa 'del' e 'rd' de forma agressiva (/q /f /s) ocultando erros de arquivos em uso.
:: ==============================================================================
:temp
cls
echo --- Limpando Arquivos Temporarios e Lixeira ---
echo [%date% %time%] - Iniciando limpeza de arquivos temporarios e lixeira >> "%LOGFILE%"

echo 1. Limpando Temp do Sistema (Windows\Temp)...
del /q /f /s C:\Windows\Temp\* >> "%LOGFILE%" 2>&1

echo 2. Limpando Temp de todos os usuarios da maquina...
:: O comando FOR /D entra em cada pasta dentro de C:\Users e limpa o Temp individual de cada perfil
for /d %%x in (C:\Users\*) do (
    if exist "%%x\AppData\Local\Temp" (
        del /q /f /s "%%x\AppData\Local\Temp\*" >> "%LOGFILE%" 2>&1
    )
)

echo 3. Esvaziando Lixeira em todos os discos principais...
:: Verifica a existência da lixeira oculta ($Recycle.bin) nos discos listados e a deleta
for %%D in (C D) do (
    if exist %%D:\$Recycle.bin (
        rd /s /q %%D:\$Recycle.bin >> "%LOGFILE%" 2>&1
    )
)

echo [%date% %time%] - Limpeza concluida >> "%LOGFILE%"
echo.
echo Limpeza concluida! 
echo Nota: Arquivos em uso pelo sistema foram ignorados por seguranca e registrados no log.
pause
goto :menu

:: ==============================================================================
:: [2] LIMPEZA DE CACHE DNS
:: Resolve problemas onde o computador não acessa sites atualizados ou apresenta erros de resolução de nome.
:: ==============================================================================
:dns
cls
echo --- Limpando Cache DNS ---
echo [%date% %time%] - Limpando Cache DNS >> "%LOGFILE%"
ipconfig /flushdns >> "%LOGFILE%"
echo Cache DNS limpo! Registrado no log.
pause
goto :menu

:: ==============================================================================
:: [3] RESET DE REDE COMPLETO
:: Descarta o IP atual, puxa um novo do DHCP e limpa o catálogo Winsock e pilha TCP/IP.
:: Excelente para quando o PC diz estar conectado mas não navega.
:: ==============================================================================
:reset_rede
cls
echo --- Resetando Configuracoes de Rede ---
echo Aguarde, reconfigurando a rede...
echo [%date% %time%] - Reset de rede executado >> "%LOGFILE%"
ipconfig /release >> "%LOGFILE%"
ipconfig /renew >> "%LOGFILE%"
netsh winsock reset >> "%LOGFILE%"
netsh int ip reset >> "%LOGFILE%"
echo Reset concluido e registrado no log. Recomenda-se reiniciar o computador depois.
pause
goto :menu

:: ==============================================================================
:: [4] INFORMAÇÕES DE IP
:: Coleta MAC Address, IP, Máscara e Gateway.
:: Usa um arquivo temporário para mostrar na tela E salvar no log ao mesmo tempo.
:: ==============================================================================
:ip
cls
echo --- Informacoes de IP ---
echo [%date% %time%] - Verificacao de IP (ipconfig /all) >> "%LOGFILE%"
ipconfig /all > "%temp%\resultado_ti.txt"
type "%temp%\resultado_ti.txt"
type "%temp%\resultado_ti.txt" >> "%LOGFILE%"
echo.
pause
goto :menu

:: ==============================================================================
:: [5] SYSTEM FILE CHECKER (SFC)
:: Varre os arquivos protegidos do Windows. Se achar corrupção (tela azul, lentidão extrema),
:: tenta restaurar usando uma cópia em cache.
:: ==============================================================================
:sfc
cls
echo --- Executando System File Checker (SFC) ---
echo Isso pode demorar alguns minutos. Os resultados estao sendo salvos no log...
echo [%date% %time%] - Execucao do comando SFC /scannow >> "%LOGFILE%"
sfc /scannow >> "%LOGFILE%"
echo Verificacao SFC concluida! Resultados salvos no log.
pause
goto :menu

:: ==============================================================================
:: [6] CHKDSK (CHECK DISK)
:: Analisa falhas no sistema de arquivos do HD/SSD.
:: Como o disco C: está em uso, ele apenas agenda para o próximo boot.
:: ==============================================================================
:chkdsk
cls
echo --- Agendando CHKDSK para o Disco C: ---
echo [%date% %time%] - Solicitacao de CHKDSK agendada >> "%LOGFILE%"
echo O CHKDSK nao pode ser executado com o Windows em uso.
echo Pressione Y (Sim) na proxima tela para agendar para a proxima inicializacao.
chkdsk C: /f /r
pause
goto :menu

:: ==============================================================================
:: [7] DISM (DEPLOYMENT IMAGE SERVICING AND MANAGEMENT)
:: Complemento do SFC. Ele baixa os arquivos originais do Windows Update para 
:: reparar o sistema operacional quando o cache interno está quebrado.
:: ==============================================================================
:dism
cls
echo --- Executando DISM ---
echo Reparando a imagem do sistema. Isso pode demorar bastante...
echo Acompanhe pelo log.
echo [%date% %time%] - Execucao do DISM RestoreHealth >> "%LOGFILE%"
DISM /Online /Cleanup-Image /RestoreHealth >> "%LOGFILE%"
echo DISM concluido! Resultados salvos no log.
pause
goto :menu

:: ==============================================================================
:: [8] TESTE DE PING
:: Testa se a máquina consegue falar com a internet (Google) usando IP e Nome (DNS).
:: ==============================================================================
:ping
cls
echo --- Teste de Conectividade ---
echo Realizando testes de Ping. Aguarde...
echo [%date% %time%] - Teste de Ping executado >> "%LOGFILE%"
ping 8.8.8.8 > "%temp%\resultado_ti.txt"
echo. >> "%temp%\resultado_ti.txt"
ping google.com >> "%temp%\resultado_ti.txt"
type "%temp%\resultado_ti.txt"
type "%temp%\resultado_ti.txt" >> "%LOGFILE%"
echo.
pause
goto :menu

:: ==============================================================================
:: [9] RESET DO WINDOWS UPDATE
:: Para os serviços associados à atualização, renomeia as pastas que guardam 
:: downloads corrompidos (SoftwareDistribution e catroot2) e reinicia os serviços.
:: ==============================================================================
:wupdate
cls
echo --- Resetando o Windows Update ---
echo Parando servicos e limpando pastas corrompidas...
echo [%date% %time%] - Reset dos componentes do Windows Update >> "%LOGFILE%"
net stop wuauserv >nul 2>&1
net stop cryptSvc >nul 2>&1
net stop bits >nul 2>&1
net stop msiserver >nul 2>&1
ren C:\Windows\SoftwareDistribution SoftwareDistribution.old >nul 2>&1
ren C:\Windows\System32\catroot2 catroot2.old >nul 2>&1
net start wuauserv >nul 2>&1
net start cryptSvc >nul 2>&1
net start bits >nul 2>&1
net start msiserver >nul 2>&1
echo [%date% %time%] - Servicos reiniciados >> "%LOGFILE%"
echo Componentes do Windows Update resetados com sucesso! Registrado no log.
pause
goto :menu

:: ==============================================================================
:: [10] MONITORAMENTO DE PORTAS
:: Mostra todas as conexões TCP/UDP ativas e portas abertas na máquina local.
:: ==============================================================================
:portas
cls
echo --- Monitoramento de Portas ---
echo [%date% %time%] - Portas ativas (netstat -ano) >> "%LOGFILE%"
netstat -ano > "%temp%\resultado_ti.txt"
type "%temp%\resultado_ti.txt"
type "%temp%\resultado_ti.txt" >> "%LOGFILE%"
echo.
pause
goto :menu

:: ==============================================================================
:: [11] LISTAGEM DE PROCESSOS
:: Traz todos os executáveis abertos no momento, similar ao Gerenciador de Tarefas.
:: ==============================================================================
:processos
cls
echo --- Processos em Execucao ---
echo [%date% %time%] - Lista de processos (tasklist) >> "%LOGFILE%"
tasklist > "%temp%\resultado_ti.txt"
type "%temp%\resultado_ti.txt"
type "%temp%\resultado_ti.txt" >> "%LOGFILE%"
echo.
pause
goto :menu

:: ==============================================================================
:: [12] USUÁRIOS CONECTADOS
:: Mostra quais perfis do Windows possuem sessões abertas no momento da execução.
:: ==============================================================================
:usuarios
cls
echo --- Usuarios Conectados ---
echo [%date% %time%] - Usuarios na sessao (query user) >> "%LOGFILE%"
query user > "%temp%\resultado_ti.txt"
type "%temp%\resultado_ti.txt"
type "%temp%\resultado_ti.txt" >> "%LOGFILE%"
echo.
pause
goto :menu

:: ==============================================================================
:: [13] DIAGNÓSTICO COMPLETO
:: Roda ping prolongado, traça a rota para ver onde a rede está caindo (tracert) 
:: e exibe se o cabo físico ou wifi estão conectados/desconectados.
:: ==============================================================================
:diagnostico
cls
echo --- Diagnostico Completo de Rede ---
echo Executando testes. Isso levara alguns minutos...
echo [%date% %time%] - INICIO DO DIAGNOSTICO COMPLETO DE REDE >> "%LOGFILE%"
echo -> Teste de Ping (8.8.8.8): >> "%LOGFILE%"
ping 8.8.8.8 -n 4 >> "%LOGFILE%"
echo -> Rota de Tracert (8.8.8.8): >> "%LOGFILE%"
tracert -d -h 10 8.8.8.8 >> "%LOGFILE%"
echo -> Status das Interfaces: >> "%LOGFILE%"
netsh interface show interface >> "%LOGFILE%"
echo Diagnostico concluido! Todos os dados estao no arquivo de log.
pause
goto :menu

:: ==============================================================================
:: [14] LIMPEZA GERAL
:: Executa os módulos de Temp, Lixeira e FlushDNS de uma única vez em segundo plano.
:: Ideal para manutenção rápida preventiva em estações de trabalho.
:: ==============================================================================
:limpeza_geral
cls
echo --- Iniciando Limpeza Geral Automatizada ---
echo [%date% %time%] - Limpeza Geral iniciada (Temp, Lixeira, DNS) >> "%LOGFILE%"

echo 1. Limpando Temp do Sistema (Windows\Temp)...
del /q /f /s C:\Windows\Temp\* >> "%LOGFILE%" 2>&1

echo 2. Limpando Temp de todos os usuarios...
for /d %%x in (C:\Users\*) do (
    if exist "%%x\AppData\Local\Temp" (
        del /q /f /s "%%x\AppData\Local\Temp\*" >> "%LOGFILE%" 2>&1
    )
)

echo 3. Esvaziando Lixeira em todos os discos principais...
for %%D in (C D) do (
    if exist %%D:\$Recycle.bin (
        rd /s /q %%D:\$Recycle.bin >> "%LOGFILE%" 2>&1
    )
)

echo 4. Limpando Cache DNS...
ipconfig /flushdns >> "%LOGFILE%" 2>&1

echo [%date% %time%] - Limpeza Geral concluida com sucesso >> "%LOGFILE%"
echo.
echo Limpeza Geral concluida com sucesso! Registrado no log.
pause
goto :menu

:: ==============================================================================
:: [15] SAÍDA DO SCRIPT
:: ==============================================================================
:sair
echo [%date% %time%] - Sessao finalizada pelo usuario. >> "%LOGFILE%"
exit