🌲 Projeto Trilha IoT - Monitoramento Inteligente e Segurança
Este repositório contém o código-fonte, binários e ferramentas de backend para o sistema Trilha IoT. O sistema é uma solução completa para monitoramento de segurança em trilhas ecológicas, utilizando tags NFC, geolocalização (GPS) e comunicação híbrida (WiFi/LoRa via MQTT).

📂 1. Organização do Repositório
A estrutura de pastas deste projeto foi organizada para facilitar a manutenção e o versionamento entre diferentes estágios de desenvolvimento:

📁 /aplicativo_trilha Contém a versão mais recente do código-fonte Flutter (lib, pubspec.yaml, etc.). Aqui estão as funcionalidades de Geofencing, Login Offline e Escrita de GPS na Tag. Use esta pasta para desenvolvimento.

📁 /DadosMySQL: Contém as informações do banco de dados

📁 /senhaEmailLaboratorio: Contém o e-mail e senha criados para o app.

📁 /API: Contém os scripts Python do Backend HTTP.

api_server.py: Servidor Flask que gerencia usuários, autenticação e banco de dados MySQL.

📁 /MOCK: Contém as ferramentas de simulação e pontes MQTT.

mock_pelms.py: O Bridge Listener. Escuta os tópicos MQTT (incluindo os fragmentados do LoRa) e grava no banco de dados.

📁 /app_realise: Contém o arquivo instalável para dispositivos Android, pronto para uso em campo.

📘 2. Manual do Usuário
Este aplicativo foi projetado para três perfis distintos, cada um com funcionalidades específicas para garantir a operação e segurança do parque.

🔐 Acesso e Segurança (Comum a Todos)
Cadastro:

Ao abrir o app, clique em "Cadastre-se".

Preencha: Nome, E-mail, Senha e CPF (Obrigatório para recuperação offline).

Escolha o perfil: Trilheiro, Guia ou Operador.

Login Híbrido:

O app salva suas credenciais de forma criptografada no dispositivo.

Se estiver sem internet, você consegue logar usando a senha local.

Esqueci Minha Senha (Offline):

Na tela de login, clique em "Esqueci minha senha (Local)".

Digite seu CPF. Se conferir com o salvo no aparelho, você poderá redefinir a senha de acesso ao app imediatamente, sem precisar de e-mail.

🎒 Perfil: O TRILHEIRO (Usuário Final)
O foco deste perfil é a segurança e o registro de progresso na trilha.

Fluxo de Uso:

Iniciar Trilha:

Na tela inicial, clique em "Iniciar Nova Trilha".

Preencha o formulário (Dificuldade, se precisa de guia, notas médicas).

Ao confirmar, o monitoramento de GPS e Bússola é ativado.

Navegação e Mapa:

Você verá sua posição em tempo real no mapa.

O mapa indica onde estão os Pontos de Checagem (Tags NFC).

Realizar Check-in (Leitura NFC):

Ao chegar perto de uma placa física, clique no botão flutuante NFC (ícone laranja).

Validação de Geofencing: O app verifica se você está num raio de 10 metros da coordenada original da tag.

Se estiver longe: O app emite um alerta, mas registra o evento para auditoria.

Se estiver perto: O check-in é confirmado com sucesso.

Envio de Dados: O app envia sua localização e horário via Internet (API) e via Rádio (Simulação MQTT) simultaneamente.

Botão de Pânico:

Em caso de emergência, use o botão de SOS (se disponível na interface) para enviar sua última localização conhecida.

🛠️ Perfil: O OPERADOR (Manutenção)
O Operador é responsável por instalar e manter a infraestrutura física (Tags NFC).

Fluxo de Uso:

Dashboard:

Visualiza status do sistema (Quantas tags ativas, leituras recentes).

Gerenciador de Tags (Menu Lateral):

Acesse a tela de gerenciamento para configurar as placas da trilha.

Vincular Tag com GPS (Instalação):

Ao instalar uma placa nova na mata:

Clique em "Vincular Tag (Com GPS Atual)".

Digite o ID da placa (ex: 15).

O app captura a latitude/longitude exata do seu celular.

Aproxime o celular da tag virgem.

O app grava: ID | LATITUDE | LONGITUDE na memória da tag.

Diagnóstico e Limpeza:

Use o botão "Analisar" para ler uma tag e ver se ela está funcionando ou corrompida.

Use "Limpar" ou "Reformatar" para reutilizar tags antigas.

🗺️ Perfil: O GUIA (Gestão)
O Guia monitora os grupos e a agenda.

Fluxo de Uso:

Painel de Controle:

Visualiza lista de trilheiros ativos no momento.

Recebe alertas de check-ins atrasados.

Agendamentos:

Visualiza solicitações de trilhas que pediram acompanhamento.

Confirma ou recusa solicitações.

⚙️ 3. Guia Técnico (Instalação e Execução)
Para rodar o projeto localmente em ambiente de desenvolvimento.

Pré-requisitos
Flutter SDK (Versão 3.x ou superior)

Python 3.8+

MySQL Server

Mosquitto MQTT Broker (Opcional, se for usar o envio MQTT local)

Passo A: Configurar o Banco de Dados
Certifique-se de que o MySQL está rodando e crie o banco:

SQL
CREATE DATABASE aplicativotrilhamapl;
-- Configure o usuário 'mapl_user' conforme credenciais no api_server.py
Passo B: Rodar o Backend (API e MQTT Listener)
Abra dois terminais.

Terminal 1 (API):

Bash
cd API
pip install flask pymysql
python api_server.py
Terminal 2 (Bridge MQTT):

Bash
cd MOCK
pip install paho-mqtt pymysql
python mock_pelms.py
Passo C: Rodar o Aplicativo Mobile
Conecte seu celular Android via USB (Depuração USB ativa).

Navegue até a pasta do código:

Bash
cd codigo_atual
Instale as dependências e rode:

Bash
flutter pub get
flutter run
📡 Protocolos de Comunicação
O sistema utiliza uma arquitetura robusta para garantir a entrega de dados mesmo em áreas de sombra:

HTTP (REST): Usado para login, cadastro e sincronização quando há 4G/WiFi.

MQTT (Split Payload): Simula o envio via LoRa. O app fragmenta os dados em tópicos leves para garantir a entrega em redes de baixa largura de banda:

trilha/id_pessoa

trilha/id_tag

trilha/gps_lat

trilha/gps_lon

trilha/time_stamp

🚀 Notas de Atualização - Versão v1.6
🛠️ Correções de Bugs (Fixes)
1. Perfil do Usuário e Botão "Editar" (Crítico) 

Problema: O botão de edição falhava silenciosamente e informações como Sexo e Telefone não apareciam na tela.

Causa Raiz: O arquivo api_service.dart chamava a rota /api/usuario/{id}/completo, porém o endpoint no servidor (api_server.py) estava definido apenas como /api/usuario/{id}. Isso gerava um erro 404 Not Found, caindo em um bloco try-catch silencioso no Flutter.

Correção:

Ajustada a URL no ApiService para bater com a rota existente.

Adicionado o widget visual (_buildInfoCard) para exibir o telefone no profile_screen.dart.

Corrigida a lógica do Dropdown de sexo para aceitar valores por extenso ("Masculino"/"Feminino").

2. Tela do Operador - Link Quebrado
Problema: O texto "Revisar" na lista de agendamentos pendentes era estático.

Correção: Substituído o método _buildCleanMatrix por _buildMatrixRow com suporte a InkWell, permitindo clicar na linha para abrir a gestão.

✨ Novas Funcionalidades (Features)
1. Gestão de Agendamentos (Ciclo Completo)
Implementado fluxo ponta-a-ponta para solicitação e aprovação de guias:

Backend (API):

Novo Endpoint GET /api/agendamentos/pendentes: Lista trilhas sem guia atribuído.

Novo Endpoint PUT /api/agendamento/{id}/atribuir: Vincula um guia à trilha.

Novo Endpoint PUT /api/agendamento/{id}/status: Permite alterar status (confirmado/em_andamento).

Frontend (Operador):

Nova tela ScheduleManagementScreen: "Torre de controle" para visualizar pendências e atribuir guias via modal dinâmico.

Frontend (Guia):

Botão "Aceitar Trilha": Confirma a atribuição feita pelo operador.

Botão "Iniciar Agora": Muda status para em_andamento e move a trilha para o painel "Trilha Atual" com destaque.

2. Recuperação de Senha Real ("Esqueci minha Senha")
Substituída a lógica de "senha local fake" por uma redefinição real no servidor.

Novo Endpoint POST /api/recuperar-senha: Reseta o hash da senha no MySQL baseada no e-mail fornecido.

3. Implementação de CPF
Banco de Dados: Adicionada coluna cpf (Unique) na tabela usuarios.

API: Atualizados endpoints de Register (para salvar) e Login (para aceitar E-mail OU CPF na autenticação).

Desenvolvido por: Equipe MAPL. Versão 1.6 - Janeiro/2026
