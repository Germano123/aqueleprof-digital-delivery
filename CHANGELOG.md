# Changelog

Todas as mudanças notáveis deste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

---

## [1.0.0] - 2026-11-09

### Adicionado
- **Puzzle de Comandos no Terminal (CTF no Lobby)**:
  - Mecânica colaborativa em que o Host deve liberar a porta da sala (`port open 3001` / `ufw allow 3001`) e gerar a chave hash (`hash gen <chave>`).
  - Sistema de arquivos virtual (`virtual_fs`) com pastas `/logs`, `/security` e `/system`.
  - Novos comandos para navegação e descompactação: `ls`, `dir`, `pwd`, `cd`, `cat` e `unzip session_hash.zip`.
  - Validação SHA-256 e sincronização de prontidão (`isReady`) entre operadores antes de permitir o `start tunnel`.
- **Listen Server Integrado (P2P / Host Local)**:
  - Implementação completa de `LocalServerHost` e `LocalRoom` em GDScript nativo utilizando `TCPServer` e `WebSocketPeer`.
  - Elimina a dependência obrigatória de um servidor dedicado externo para partidas multiplayer, permitindo distribuição e execução autônoma do binário em rede local ou localmente.
- **Terminal CRT Imersivo e Interativo**:
  - Animação de transição de monitor ligando (*power-on CRT beam*).
  - Simulação de conexão e download de chaves via FTP.
  - Janela de pop-up educativa no canto superior direito (`CommandTooltip`) explicando o conceito pedagógico de cada comando digitado.
  - Sistema de foco contínuo no campo de digitação, evitando perda de foco ao teclar ou clicar fora.
- **Documentação do Projeto**:
  - `README.md` completo com instruções de execução, lista de comandos e arquitetura.
  - `CHANGELOG.md` estruturado.
  - Regras de exclusão no `.gitignore` para Godot 4 e Node.js.

### Modificado
- **Atmosfera e Cenografia da Arena 3D**:
  - Ajuste de ambientação para tom escuro e temático digital cibernético, valorizando as luzes de neon.
  - Inserção dos postes de luz de forma estática no mapa da arena em vez de posicionamento puramente dinâmico.
  - Redução de 50% na intensidade do bloom/emissão para equilíbrio visual e contraste.
- **Controlador do Jogador**:
  - Correção na declaração da classe `PlayerController` e vinculação de animações da personagem.

---

## [0.2.0] - 2026-09-22

### Adicionado
- **Arena 3D da Placa-Mãe (`computer_arena.tscn`)**:
  - Cenário 3D representando os componentes de hardware de um computador.
  - Sistema de geração de cubos de processos caindo da CPU central.
  - Estações de software com validação pedagógica de extensões de arquivos (.docx, .xlsx, .mp4, .png, etc.).
  - Mecânicas de pegar (`grab`) e soltar (`drop`) cubos com física.
- **Eventos de Perigo (*Hazards*)**:
  - Janelas pop-up invasivas de adware que exigem interação para fechar.
  - Barreiras dinâmicas de firewall ativadas periodicamente.
- **HUD e Telemetria**:
  - Indicador de tempo restante da partida, pontuação atual e multiplicador de sequência (*streak*).

---

## [0.1.0] - 2026-09-16

### Adicionado
- **Concepção Inicial e Backend**:
  - Criação do Game Design Document (`GDD.md`) definindo os objetivos pedagógicos para o curso de Operador de Computador.
  - Servidor dedicado multiplayer em Node.js e TypeScript com WebSockets, loop de física a 20 TPS e gerenciamento de salas por PIN.
  - Modelagem e exportação dos primeiros assets 3D (personagem, cubos e estações).
