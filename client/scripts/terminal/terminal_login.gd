extends Control

## DIGITAL DELIVERY - Terminal CLI de Login e Conexão em Rede Local
## Simula inicialização de terminal com transição de monitor ligando (CRT)
## e transcrição rápida caractere a caractere (typewriter).
## Garante foco ininterrupto para o jogador estar sempre digitando no terminal.

@onready var console_output: RichTextLabel = $TerminalContainer/ConsoleOutput
@onready var input_bar: HBoxContainer = $TerminalContainer/InputBar
@onready var prompt_label: Label = $TerminalContainer/InputBar/PromptLabel
@onready var command_input: LineEdit = $TerminalContainer/InputBar/CommandInput
@onready var crt_overlay: ColorRect = $CRTOverlay
@onready var crt_beam: ColorRect = $CRTOverlay/CRTBeam
@onready var command_tooltip: PanelContainer = $CommandTooltip

var command_history: Array[String] = []
var history_index: int = -1
var is_connecting_room: bool = false
var is_simulating_ftp: bool = false
var is_in_room_lobby: bool = false
var is_transitioning: bool = false
var is_booting: bool = true
var is_skipping_boot: bool = false

## Documentação de comandos para o tooltip (título, descrição)
const COMMAND_DOCS: Dictionary = {
	"help":         ["HELP", "Lista todos os comandos disponíveis no terminal"],
	"?":            ["HELP", "Lista todos os comandos disponíveis no terminal"],
	"clear":        ["CLEAR", "Limpa as linhas do console do terminal"],
	"cls":          ["CLEAR", "Limpa as linhas do console do terminal"],
	"whoami":       ["WHOAMI", "Exibe o nome do operador autenticado na sessão"],
	"server":       ["SERVER", "Exibe ou altera o IP do servidor para conexão LAN"],
	"register":     ["REGISTER", "Cadastra um novo operador no banco de dados do sistema"],
	"login":        ["LOGIN", "Autentica o operador com nome de usuário e senha"],
	"scan":         ["SCAN", "Escaneia os nós de sala ativos na rede e lista os resultados"],
	"rooms":        ["SCAN", "Escaneia os nós de sala ativos na rede e lista os resultados"],
	"netstat":      ["SCAN", "Escaneia os nós de sala ativos na rede e lista os resultados"],
	"host":         ["HOST", "Inicia nó de hospedagem e cria uma sala no servidor"],
	"create":       ["HOST", "Inicia nó de hospedagem e cria uma sala no servidor"],
	"connect":      ["CONNECT", "Inicia protocolo FTP de autenticação e entrada em uma sala"],
	"hack":         ["CONNECT", "Inicia protocolo FTP de autenticação e entrada em uma sala"],
	"join":         ["CONNECT", "Inicia protocolo FTP de autenticação e entrada em uma sala"],
	"start tunnel": ["START TUNNEL", "[ADM] Abre o túnel quântico e inicia a partida de processos"],
	"status":       ["STATUS", "Exibe detalhes, segurança e prontidão dos operadores da sala"],
	"leave":        ["LEAVE", "Encerra a conexão com a sala e retorna ao terminal principal"],
	"disconnect":   ["LEAVE", "Encerra a conexão com a sala e retorna ao terminal principal"],
	"ping":         ["PING", "Testa a conectividade com o servidor configurado"],
	"exit":         ["EXIT", "Sai da sala atual ou fecha o aplicativo"],
	"quit":         ["EXIT", "Sai da sala atual ou fecha o aplicativo"],
	"port":         ["PORT", "Gerencia e libera portas de comunicação de rede no firewall"],
	"open":         ["OPEN", "Abre portas de rede ou serviços (Ex: open port 3001)"],
	"ufw":          ["UFW", "Configura regras de firewall (Ex: ufw allow 3001)"],
	"hash":         ["HASH", "Gera ou define a assinatura criptográfica de integridade da sala"],
	"ls":           ["LS", "Lista arquivos e pastas do diretório atual da sala"],
	"dir":          ["DIR", "Lista arquivos e diretórios da pasta atual"],
	"cd":           ["CD", "Navega entre os diretórios de pastas da sala (Ex: cd security)"],
	"pwd":          ["PWD", "Imprime o caminho da pasta atual de trabalho"],
	"cat":          ["CAT", "Lê e exibe o conteúdo de um arquivo de texto no terminal"],
	"unzip":        ["UNZIP", "Descompacta e extrai arquivos comprimidos (.zip) da sessão"],
	"extract":      ["EXTRACT", "Extrai e valida arquivos compactados (.zip) da sessão"],
	"ready":        ["READY", "Exibe o status de prontidão e validação de hash dos operadores"]
}

# Sistema de Pastas Virtual (Lobby Puzzle)
var current_vdir: String = "/"
var virtual_fs: Dictionary = {}
var room_players_status: Dictionary = {} # player_id -> { "username": String, "is_ready": bool, "is_adm": bool }

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	input_bar.visible = false
	console_output.clear()

	command_input.text_submitted.connect(_on_command_submitted)

	# Garante que o input nunca perca o foco por cliques externos
	command_input.focus_exited.connect(func():
		if not is_connecting_room and not is_transitioning and not is_simulating_ftp:
			command_input.call_deferred("grab_focus")
	)

	# Conecta sinais do NetworkManager
	NetworkManager.auth_result.connect(_on_auth_result)
	NetworkManager.rooms_result.connect(_on_rooms_result)
	NetworkManager.room_created.connect(_on_room_created)
	NetworkManager.room_join_result.connect(_on_room_join_result)
	NetworkManager.packet_received.connect(_on_network_packet_received)
	NetworkManager.connection_closed.connect(_on_network_connection_closed)
	NetworkManager.room_security_updated.connect(_on_room_security_updated)
	NetworkManager.player_ready_status_received.connect(_on_player_ready_status_received)

	# Inicia animação do monitor ligando
	play_monitor_power_on()

func _process(_delta: float) -> void:
	# Mantém foco contínuo no campo de digitação para o jogador nunca ser interrompido
	if not is_booting and not is_connecting_room and not is_transitioning and not is_simulating_ftp:
		if is_instance_valid(command_input) and not command_input.has_focus():
			command_input.grab_focus()

func _input(event: InputEvent) -> void:
	# Se ainda estiver ligando/transcrevendo o boot e o usuário digitar ou clicar:
	if is_booting:
		if event is InputEventKey and event.pressed:
			var initial_char = ""
			# Se for um caractere imprimível (letras, números, símbolos)
			if event.unicode >= 32:
				initial_char = char(event.unicode)
			skip_boot_and_focus(initial_char)
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventMouseButton and event.pressed:
			skip_boot_and_focus()
			get_viewport().set_input_as_handled()
			return

	# Clique do mouse em qualquer área da tela recupera o foco no input imediatamente
	if event is InputEventMouseButton and event.pressed:
		command_input.call_deferred("grab_focus")

	# Tecla ESC não remove o foco do terminal
	if event.is_action_pressed("ui_cancel"):
		command_input.grab_focus()
		get_viewport().set_input_as_handled()
		return

	# Navegação no histórico com setas Cima / Baixo
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_UP:
			if command_history.size() > 0:
				history_index = clamp(history_index + 1, 0, command_history.size() - 1)
				command_input.text = command_history[command_history.size() - 1 - history_index]
				command_input.caret_column = command_input.text.length()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			if history_index > 0:
				history_index -= 1
				command_input.text = command_history[command_history.size() - 1 - history_index]
				command_input.caret_column = command_input.text.length()
				get_viewport().set_input_as_handled()
			elif history_index == 0:
				history_index = -1
				command_input.text = ""
				get_viewport().set_input_as_handled()

func skip_boot_and_focus(initial_char: String = "") -> void:
	if not is_booting:
		command_input.grab_focus()
		return

	is_skipping_boot = true
	is_booting = false
	crt_overlay.visible = false
	console_output.visible_characters = -1
	input_bar.visible = true
	update_prompt()
	command_input.grab_focus()

	if initial_char != "":
		command_input.text += initial_char
		command_input.caret_column = command_input.text.length()

# --- Transição de Monitor Ligando (CRT Power-on) ---

func play_monitor_power_on() -> void:
	crt_overlay.visible = true
	crt_overlay.modulate.a = 1.0
	crt_beam.visible = true
	crt_beam.scale = Vector2(0.0, 0.4)

	# Ajusta o pivot do feixe para o centro da tela
	crt_beam.pivot_offset = Vector2(size.x / 2.0 if size.x > 0 else 640.0, 2.0)

	var tween = create_tween()
	# 1. Breve silêncio/pausa no escuro antes do fósforo acender
	tween.tween_interval(0.12)
	# 2. Feixe de luz horizontal se expande de um ponto central
	tween.tween_property(crt_beam, "scale:x", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 3. Feixe se abre verticalmente cobrindo o monitor
	tween.tween_property(crt_beam, "scale:y", 200.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# 4. Clarão se dissipa revelando o terminal com o fósforo estabilizado
	tween.tween_property(crt_overlay, "modulate:a", 0.0, 0.25)

	tween.finished.connect(_on_power_on_finished)

func _on_power_on_finished() -> void:
	if is_booting:
		crt_overlay.visible = false
		start_typewriter_boot()

# --- Transcrição Letra por Letra (Typewriter) ---

func start_typewriter_boot() -> void:
	console_output.clear()

	var boot_text = ""
	boot_text += "[color=#00FF66][BIOS] INITIALIZING DIGITAL DELIVERY CORE v1.0.0...[/color]\n"
	boot_text += "[color=#00FF66][CPU] ARCHITECTURE: 64-BIT // CORES: ONLINE[/color]\n"
	boot_text += "[color=#00FF66][MEM] 640K BASE MEMORY OK | 16384M EXTENDED MEMORY OK[/color]\n"
	boot_text += "[color=#00FF66][NET] TCP/IP STACK: ONLINE | HOST ATUAL: " + NetworkManager.server_http_url + "[/color]\n"
	
	var local_ips: Array[String] = []
	for ip_str in IP.get_local_addresses():
		if not ip_str.begins_with("127.") and not ip_str.begins_with("169.254.") and not ":" in ip_str:
			local_ips.append(ip_str)
	if local_ips.size() > 0:
		boot_text += "[color=#00E5FF][LAN] SEU IP NESTA MÁQUINA: " + ", ".join(local_ips) + "[/color]\n"
		boot_text += "[color=#888888]      (Outros computadores na LAN devem digitar: server " + local_ips[0] + ":3001)[/color]\n"

	boot_text += "[color=#FFFF00][AUTH] OPERATOR STATUS: UNIDENTIFIED / GUEST[/color]\n"
	boot_text += "[color=#555555]======================================================================[/color]\n"
	boot_text += "[color=#00E5FF]DIGITAL DELIVERY - TERMINAL DE ACESSO DO OPERADOR[/color]\n"
	boot_text += "Digite [color=#FFFF00]'help'[/color] para listar comandos de rede, cadastro e conexão.\n"
	boot_text += "[color=#555555]======================================================================[/color]\n"

	console_output.append_text(boot_text)

	var total_chars = console_output.get_total_character_count()
	console_output.visible_characters = 0
	var parsed_text = console_output.get_parsed_text()

	# Transcreve letra por letra de forma rápida
	for i in range(total_chars):
		if is_skipping_boot:
			console_output.visible_characters = -1
			break

		console_output.visible_characters = i + 1

		# Pausa de linha para simular processamento realista do terminal
		if i < parsed_text.length() and parsed_text[i] == "\n":
			await get_tree().create_timer(0.045).timeout
		else:
			await get_tree().create_timer(0.008).timeout

	console_output.visible_characters = -1
	is_booting = false
	input_bar.visible = true
	update_prompt()
	command_input.grab_focus()

func append_line(bbcode: String) -> void:
	console_output.append_text(bbcode + "\n")

func update_prompt() -> void:
	if is_in_room_lobby:
		var room_display = NetworkManager.current_room_name if NetworkManager.current_room_name != "" else NetworkManager.current_pin
		var vpath_disp = "~" if current_vdir == "/" else current_vdir
		if NetworkManager.is_room_adm:
			prompt_label.text = "%s@%s[ADM]:%s$ " % [GameManager.logged_in_username, room_display, vpath_disp]
			prompt_label.modulate = Color("#FFD700") # Dourado
		else:
			prompt_label.text = "%s@%s:%s$ " % [GameManager.logged_in_username, room_display, vpath_disp]
			prompt_label.modulate = Color("#00E5FF") # Ciano
	elif GameManager.logged_in_username != "":
		prompt_label.text = "%s@digital-delivery:~$ " % GameManager.logged_in_username
		prompt_label.modulate = Color("#00E5FF") # Ciano brilhante
	else:
		prompt_label.text = "guest@digital-delivery:~$ "
		prompt_label.modulate = Color("#00FF66") # Verde terminal

func _show_command_tooltip(cmd_key: String) -> void:
	if not COMMAND_DOCS.has(cmd_key):
		return
	var doc = COMMAND_DOCS[cmd_key]
	command_tooltip.show_tooltip(doc[0], doc[1])

func _on_command_submitted(raw_text: String) -> void:
	var text = raw_text.strip_edges()
	command_input.clear()
	history_index = -1
	command_input.call_deferred("grab_focus")

	if text == "":
		return

	command_history.append(text)
	append_line("[color=#888888]" + prompt_label.text + text + "[/color]")

	execute_terminal_command(text)

func execute_terminal_command(raw_text: String) -> void:
	var clean = raw_text.strip_edges()
	if clean == "":
		return

	# Suporte ao comando composto 'start tunnel'
	if clean.to_lower() == "start tunnel" or clean.to_lower().begins_with("start tunnel "):
		_show_command_tooltip("start tunnel")
		cmd_start_tunnel()
		command_input.call_deferred("grab_focus")
		return

	var parts = clean.split(" ", false)
	var cmd = parts[0].to_lower()
	var args = parts.slice(1)

	# Exibe o tooltip para o comando digitado
	_show_command_tooltip(cmd)

	match cmd:
		"help", "?":
			cmd_help()
		"clear", "cls":
			console_output.clear()
		"whoami":
			cmd_whoami()
		"server":
			cmd_server(args)
		"register":
			cmd_register(args)
		"login":
			cmd_login(args)
		"scan", "rooms", "netstat":
			cmd_scan()
		"host", "create":
			cmd_host(args)
		"connect", "hack", "join":
			cmd_connect(args)
		"port":
			cmd_port(args)
		"open":
			if args.size() > 0 and args[0].to_lower() == "port":
				_show_command_tooltip("port")
				cmd_port(args.slice(1))
			else:
				append_line("[color=#FFFF00][USO] Para abrir uma porta de rede, use: 'port open <porta>' ou 'open port <porta>'.[/color]")
		"ufw":
			cmd_ufw(args)
		"hash":
			cmd_hash(args)
		"ls":
			cmd_ls(args)
		"dir":
			cmd_dir(args)
		"cd":
			cmd_cd(args)
		"pwd":
			cmd_pwd()
		"cat":
			cmd_cat(args)
		"unzip", "extract":
			cmd_unzip(args)
		"ready":
			cmd_lobby_status()
		"start":
			if args.size() > 0 and args[0].to_lower() == "tunnel":
				_show_command_tooltip("start tunnel")
				cmd_start_tunnel()
			else:
				append_line("[color=#FFFF00][AVISO] Para iniciar a partida dos processos, digite: 'start tunnel'.[/color]")
		"status":
			cmd_lobby_status()
		"leave", "disconnect":
			cmd_leave_room()
		"ping":
			cmd_ping()
		"exit", "quit":
			if is_in_room_lobby:
				cmd_leave_room()
			else:
				get_tree().quit()
		_:
			append_line("[color=#FF5555][ERRO] Comando desconhecido: '%s'. Digite 'help' para o manual.[/color]" % cmd)

	command_input.call_deferred("grab_focus")

func cmd_help() -> void:
	append_line("[color=#00E5FF]MANUAL DE COMANDOS DO SISTEMA:[/color]")
	append_line("  [color=#FFFF00]server [ip:porta][/color]           Exibe ou altera o host do servidor em LAN (Ex: server 192.168.1.50:3001)")
	append_line("  [color=#FFFF00]register <user> <senha>[/color]     Cadastra uma nova conta de operador no banco do sistema")
	append_line("  [color=#FFFF00]login <user> <senha>[/color]        Autentica as credenciais do operador na sessão")
	append_line("  [color=#FFFF00]whoami[/color]                      Exibe o nome do operador autenticado atualmente")
	append_line("  [color=#FFFF00]scan / rooms[/color]                Escaneia nós e lista as salas disponíveis")
	append_line("  [color=#FFFF00]host [nivel][/color]                 Hospeda uma nova sala como Host/Administrador")
	append_line("  [color=#FFFF00]connect <sala ou PIN>[/color]      Conecta à sala (Ex: connect casual, connect border, connect challenge)")
	append_line("")
	append_line("[color=#00E5FF]PUZZLE DO HOST (CONFIGURAÇÃO DE REDE E SEGURANÇA):[/color]")
	append_line("  [color=#FFFF00]port open <porta>[/color]          Libera a porta de conexão TCP no firewall (Ex: port open 3001)")
	append_line("  [color=#FFFF00]ufw allow <porta>[/color]          Aplica regra de firewall para permitir tráfego na porta")
	append_line("  [color=#FFFF00]hash gen <chave>[/color]           Gera a chave criptográfica hash SHA-256 da sessão")
	append_line("  [color=#FFFF00]start tunnel[/color]                [ADM] Inicia o túnel quântico quando todos estiverem [PRONTOS]")
	append_line("")
	append_line("[color=#00E5FF]PUZZLE DO CONVIDADO (EXPLORAÇÃO E VALIDAÇÃO DE HASH):[/color]")
	append_line("  [color=#FFFF00]ls / dir[/color]                    Lista as pastas e arquivos do diretório atual da sala")
	append_line("  [color=#FFFF00]cd <pasta>[/color]                  Entra na pasta especificada (Ex: cd security, cd ..)")
	append_line("  [color=#FFFF00]pwd[/color]                         Exibe o caminho do diretório de pastas atual")
	append_line("  [color=#FFFF00]cat <arquivo>[/color]               Lê e imprime o conteúdo de um arquivo de texto")
	append_line("  [color=#FFFF00]unzip <arquivo>[/color]             Descompacta o hash da sessão e define status como [PRONTO]")
	append_line("")
	append_line("[color=#00E5FF]GERENCIAMENTO DA SALA:[/color]")
	append_line("  [color=#FFFF00]status[/color]                      Exibe status de segurança, porta, hash e operadores prontos")
	append_line("  [color=#FFFF00]leave[/color]                       Sai da sala atual e retorna ao terminal principal")
	append_line("  [color=#FFFF00]ping[/color]                        Testa conectividade com o servidor atual")
	append_line("  [color=#FFFF00]clear[/color]                       Limpa as linhas do console")
	append_line("  [color=#FFFF00]exit[/color]                        Sai da sala ou fecha o jogo")
	append_line("")

func cmd_whoami() -> void:
	if GameManager.logged_in_username != "":
		append_line("[color=#00FF66]Sessão ativa: Operador '%s' [AUTENTICADO][/color]" % GameManager.logged_in_username)
	else:
		append_line("[color=#FFFF00]Modo convidado. Nenhuma conta logada. Use 'login <user> <senha>'.[/color]")

func cmd_server(args: Array) -> void:
	if args.size() == 0:
		append_line("[color=#00E5FF][NET] Servidor configurado: %s (REST: %s)[/color]" % [NetworkManager.server_ws_url, NetworkManager.server_http_url])
		append_line("Para alterar o IP para outro PC da LAN: [color=#FFFF00]server <ip:porta>[/color]")
	else:
		var target = args[0]
		NetworkManager.set_server_host(target)
		append_line("[color=#00FF66][NET] Servidor atualizado para: %s[/color]" % NetworkManager.server_http_url)

func cmd_register(args: Array) -> void:
	if args.size() < 2:
		append_line("[color=#FF5555][USO] Sintaxe: register <usuario> <senha>[/color]")
		return

	var user = args[0]
	var password = args[1]
	append_line("[color=#888888][AUTH] Transmitindo credenciais de '%s' para o servidor...[/color]" % user)
	NetworkManager.async_register(user, password)

func cmd_login(args: Array) -> void:
	if args.size() < 2:
		append_line("[color=#FF5555][USO] Sintaxe: login <usuario> <senha>[/color]")
		return

	var user = args[0]
	var password = args[1]
	append_line("[color=#888888][AUTH] Validando chave de acesso para '%s'...[/color]" % user)
	NetworkManager.async_login(user, password)

func cmd_scan() -> void:
	append_line("[color=#888888][SCAN] Escaneando nós de salas ativas em %s...[/color]" % NetworkManager.server_http_url)
	NetworkManager.async_fetch_rooms()

func cmd_host(args: Array) -> void:
	if GameManager.logged_in_username == "":
		GameManager.logged_in_username = "Host_%d" % (randi() % 900 + 100)
		update_prompt()
		append_line("[color=#00FF66][AUTO-LOGIN] Sessão iniciada como '%s' para hospedagem.[/color]" % GameManager.logged_in_username)

	var tier = 1
	if args.size() > 0:
		tier = clamp(int(args[0]), 1, 5)

	append_line("[color=#00E5FF][HOST] Inicializando nó de servidor local e alocando sala (Nível %d)...[/color]" % tier)
	NetworkManager.async_create_room(tier)

func cmd_connect(args: Array) -> void:
	if args.size() < 1:
		append_line("[color=#FF5555][USO] Sintaxe: connect <sala_ou_pin> (Ex: connect casual, connect border, connect challenge)[/color]")
		return

	if GameManager.logged_in_username == "":
		GameManager.logged_in_username = "Operador_%d" % (randi() % 900 + 100)
		update_prompt()
		append_line("[color=#00FF66][AUTO-LOGIN] Conectando como convidado: '%s'[/color]" % GameManager.logged_in_username)

	if is_in_room_lobby:
		append_line("[color=#FFFF00][AVISO] Você já está conectado à sala '%s'. Digite 'leave' antes de se conectar a outra.[/color]" % NetworkManager.current_room_name)
		return

	var target = args[0].strip_edges()
	_simulate_ftp_and_connect(target)

func _simulate_ftp_and_connect(target: String) -> void:
	is_connecting_room = true
	is_simulating_ftp = true

	# --- Handshake FTP simulado ---
	await get_tree().create_timer(0.15).timeout
	append_line("[color=#888888]> Iniciando protocolo FTP com nó '%s'...[/color]" % target)

	await get_tree().create_timer(0.4).timeout
	append_line("[color=#00E5FF]ftp> Connected to %s.node.digitaldelivery[/color]" % target)

	await get_tree().create_timer(0.3).timeout
	append_line("[color=#00FF66]220 DIGITAL DELIVERY FTP Service Ready[/color]")

	await get_tree().create_timer(0.45).timeout
	append_line("[color=#888888]USER guest[/color]")

	await get_tree().create_timer(0.3).timeout
	append_line("[color=#00FF66]331 Password required for guest[/color]")

	await get_tree().create_timer(0.4).timeout
	append_line("[color=#888888]PASS ****[/color]")

	await get_tree().create_timer(0.35).timeout
	append_line("[color=#00FF66]230 User guest logged in.[/color]")

	await get_tree().create_timer(0.55).timeout
	append_line("[color=#888888]ftp> DIR[/color]")

	await get_tree().create_timer(0.3).timeout
	append_line("[color=#00FF66]200 PORT command successful[/color]")

	await get_tree().create_timer(0.2).timeout
	append_line("[color=#00FF66]150 Opening ASCII mode data connection.[/color]")

	await get_tree().create_timer(0.4).timeout
	append_line("[color=#555555]  drwxr-xr-x  session.log[/color]")
	await get_tree().create_timer(0.15).timeout
	append_line("[color=#555555]  drwxr-xr-x  room.config[/color]")
	await get_tree().create_timer(0.15).timeout
	append_line("[color=#FFFF00]  -rw-r--r--  connect.key[/color]")

	await get_tree().create_timer(0.35).timeout
	append_line("[color=#00FF66]226 Transfer complete. 3 objects listed.[/color]")

	await get_tree().create_timer(0.55).timeout
	append_line("[color=#888888]ftp> GET connect.key[/color]")

	await get_tree().create_timer(0.3).timeout
	append_line("[color=#00FF66]200 PORT command successful[/color]")

	await get_tree().create_timer(0.2).timeout
	append_line("[color=#00FF66]150 Opening BINARY mode data connection for connect.key[/color]")

	await get_tree().create_timer(0.5).timeout
	append_line("[color=#00FF66]226 Transfer complete.[/color]")

	await get_tree().create_timer(0.35).timeout
	append_line("[color=#FFD700][CHAVE OBTIDA] connect.key recebida. Autenticando entrada na sala...[/color]")

	await get_tree().create_timer(0.4).timeout

	# Fim da simulação — conecta de verdade
	is_simulating_ftp = false
	NetworkManager.connect_and_join(target, GameManager.logged_in_username)

func cmd_start_tunnel() -> void:
	if not is_in_room_lobby:
		append_line("[color=#FF5555][ERRO] Você precisa estar conectado a uma sala para iniciar o túnel.[/color]")
		append_line("Use: [color=#FFFF00]connect casual[/color], [color=#FFFF00]connect border[/color] ou [color=#FFFF00]connect challenge[/color].")
		return

	if not NetworkManager.is_room_adm:
		append_line("[color=#FF5555][ACESSO NEGADO] Apenas o Administrador (ADM) da sala pode iniciar o túnel com 'start tunnel'.[/color]")
		append_line("[color=#888888]Aguarde o ADM iniciar a partida.[/color]")
		return

	append_line("[color=#FFD700][TÚNEL] Solicitando abertura de túnel quântico ao servidor...[/color]")
	NetworkManager.send_packet({ "type": "C2S_START_TUNNEL" })

func cmd_port(args: Array) -> void:
	if not is_in_room_lobby:
		append_line("[color=#FF5555][ERRO] Você precisa estar hospedando ou conectado a uma sala para gerenciar portas.[/color]")
		return
	if not NetworkManager.is_room_adm:
		append_line("[color=#FF5555][ACESSO NEGADO] Apenas o Host / ADM da sala pode liberar portas de rede.[/color]")
		return

	if args.size() < 2 or args[0].to_lower() != "open":
		append_line("[color=#FFFF00][USO] Sintaxe: port open <numero_da_porta> (Ex: port open 3001)[/color]")
		return

	var port_num = int(args[1])
	if port_num <= 0:
		append_line("[color=#FF5555][ERRO] Número de porta inválido.[/color]")
		return

	append_line("[color=#00E5FF][FIREWALL] Aplicando regra de entrada: LIBERANDO PORTA %d/TCP...[/color]" % port_num)
	NetworkManager.send_packet({ "type": "C2S_HOST_OPEN_PORT", "port": port_num })

func cmd_ufw(args: Array) -> void:
	if not is_in_room_lobby:
		append_line("[color=#FF5555][ERRO] Você precisa estar em uma sala para configurar o firewall.[/color]")
		return
	if not NetworkManager.is_room_adm:
		append_line("[color=#FF5555][ACESSO NEGADO] Apenas o Host / ADM da sala pode configurar regras de firewall.[/color]")
		return

	if args.size() < 2 or args[0].to_lower() != "allow":
		append_line("[color=#FFFF00][USO] Sintaxe: ufw allow <porta> (Ex: ufw allow 3001)[/color]")
		return

	var port_num = int(args[1])
	append_line("[color=#00E5FF][UFW] Regra adicionada: ALLOW %d/TCP INBOUND.[/color]" % port_num)
	NetworkManager.send_packet({ "type": "C2S_HOST_OPEN_PORT", "port": port_num })

func cmd_hash(args: Array) -> void:
	if not is_in_room_lobby:
		append_line("[color=#FF5555][ERRO] Você precisa estar em uma sala para gerenciar a chave hash.[/color]")
		return
	if not NetworkManager.is_room_adm:
		append_line("[color=#FF5555][ACESSO NEGADO] Apenas o Host / ADM da sala pode configurar o hash da sessão.[/color]")
		return

	if args.size() < 2 or (args[0].to_lower() != "gen" and args[0].to_lower() != "set"):
		append_line("[color=#FFFF00][USO] Sintaxe: hash gen <palavra_chave> ou hash set <palavra_chave> (Ex: hash gen quantum)[/color]")
		return

	var key_phrase = args[1].strip_edges()
	var hash_calc = "SHA256:" + key_phrase.md5_text().to_lower().substr(0, 16) + key_phrase.sha256_text().substr(0, 16)

	append_line("[color=#00E5FF][CRIPTOGRAFIA] Calculando hash de sessão SHA-256 para '%s'...[/color]" % key_phrase)
	append_line("[color=#00FF66]  -> Hash gerado: %s[/color]" % hash_calc)
	append_line("[color=#FFD700]  -> Empacotando arquivo virtual 'security/session_hash.zip'... [OK][/color]")

	NetworkManager.send_packet({ "type": "C2S_HOST_SET_HASH", "hash": hash_calc })

func cmd_ls(_args: Array) -> void:
	if not is_in_room_lobby:
		append_line("[color=#FF5555][ERRO] Conecte-se a uma sala para explorar o diretório de arquivos.[/color]")
		return

	if not virtual_fs.has(current_vdir):
		_init_virtual_fs()

	var dir_info = virtual_fs.get(current_vdir, {})
	var children: Array = dir_info.get("children", [])

	append_line("[color=#888888]Conteúdo de %s (%d itens):[/color]" % [current_vdir, children.size()])
	append_line("[color=#555555]PERMISSÕES    TIPO   NOME[/color]")

	for item_name in children:
		var item_path = (current_vdir + "/" + item_name).replace("//", "/")
		var item_data = virtual_fs.get(item_path, {})
		var i_type = item_data.get("type", "file")

		if i_type == "dir":
			append_line("[color=#00E5FF]drwxr-xr-x    DIR    %s/[/color]" % item_name)
		elif i_type == "zip":
			var ext_status = "[DESCOMPACTADO]" if item_data.get("extracted", false) else "[COMPACTADO .ZIP]"
			append_line("[color=#FFFF00]-rw-r--r--    ZIP    %s  %s[/color]" % [item_name, ext_status])
		else:
			append_line("[color=#FFFFFF]-rw-r--r--    FILE   %s[/color]" % item_name)

func cmd_dir(args: Array) -> void:
	cmd_ls(args)

func cmd_cd(args: Array) -> void:
	if not is_in_room_lobby:
		append_line("[color=#FF5555][ERRO] Conecte-se a uma sala para navegar em pastas.[/color]")
		return

	if args.size() == 0 or args[0] == "/" or args[0] == "~":
		current_vdir = "/"
		update_prompt()
		return

	var target = args[0].strip_edges()

	if target == "..":
		if current_vdir != "/":
			var parts = current_vdir.split("/", false)
			if parts.size() > 1:
				parts.remove_at(parts.size() - 1)
				current_vdir = "/" + "/".join(parts)
			else:
				current_vdir = "/"
		update_prompt()
		return

	var candidate = ""
	if target.begins_with("/"):
		candidate = target
	else:
		candidate = (current_vdir + "/" + target).replace("//", "/")

	if virtual_fs.has(candidate) and virtual_fs[candidate].get("type") == "dir":
		current_vdir = candidate
		update_prompt()
	else:
		append_line("[color=#FF5555][ERRO] Diretório '%s' não encontrado.[/color]" % target)

func cmd_pwd() -> void:
	if not is_in_room_lobby:
		append_line("/ (offline)")
	else:
		append_line("[color=#00FF66]%s[/color]" % current_vdir)

func cmd_cat(args: Array) -> void:
	if not is_in_room_lobby:
		append_line("[color=#FF5555][ERRO] Conecte-se a uma sala para ler arquivos.[/color]")
		return
	if args.size() == 0:
		append_line("[color=#FFFF00][USO] Sintaxe: cat <nome_do_arquivo>[/color]")
		return

	var filename = args[0].strip_edges()
	var file_path = filename if filename.begins_with("/") else (current_vdir + "/" + filename).replace("//", "/")

	if virtual_fs.has(file_path):
		var item = virtual_fs[file_path]
		if item.get("type") == "dir":
			append_line("[color=#FF5555][ERRO] '%s' é um diretório, não um arquivo de texto.[/color]" % filename)
		elif item.get("type") == "zip":
			append_line("[color=#FFFF00][AVISO] '%s' é um arquivo compactado binário. Use: 'unzip %s'.[/color]" % [filename, filename])
		else:
			append_line("[color=#00E5FF]--- [ %s ] ---[/color]" % filename)
			append_line(item.get("content", ""))
			append_line("[color=#00E5FF]-----------------------------[/color]")
	else:
		append_line("[color=#FF5555][ERRO] Arquivo '%s' não encontrado no diretório atual.[/color]" % filename)

func cmd_unzip(args: Array) -> void:
	if not is_in_room_lobby:
		append_line("[color=#FF5555][ERRO] Conecte-se a uma sala para descompactar arquivos.[/color]")
		return

	var filename = "session_hash.zip"
	if args.size() > 0:
		filename = args[0].strip_edges()

	var file_path = filename if filename.begins_with("/") else (current_vdir + "/" + filename).replace("//", "/")

	# Se digitou só "unzip session_hash.zip" mas está na raiz, procura na pasta security também
	if not virtual_fs.has(file_path) and virtual_fs.has("/security/" + filename):
		file_path = "/security/" + filename

	if not virtual_fs.has(file_path) or virtual_fs[file_path].get("type") != "zip":
		append_line("[color=#FF5555][ERRO] Arquivo compactado '%s' não localizado. Use 'ls' ou 'cd security' para encontrá-lo.[/color]" % filename)
		return

	var item = virtual_fs[file_path]
	var hash_content = item.get("hash", NetworkManager.room_session_hash)
	if hash_content == "":
		hash_content = "SHA256:d41d8cd98f00b204e9800998ecf8427e"

	item["extracted"] = true

	# Animação de descompactação
	is_simulating_ftp = true
	append_line("[color=#FFFF00][DESCOMPACTANDO] Extraindo '%s'...[/color]" % filename)
	await get_tree().create_timer(0.3).timeout
	append_line("[color=#888888]  -> inflando: session.hash[/color]")
	await get_tree().create_timer(0.25).timeout
	append_line("[color=#888888]  -> verificando integridade de dados SHA-256...[/color]")
	await get_tree().create_timer(0.35).timeout
	append_line("[color=#00FF66]  -> [OK] Hash identificado: %s[/color]" % hash_content)
	await get_tree().create_timer(0.2).timeout
	append_line("[color=#00FF66][AUTENTICADO] Assinatura da sessão confirmada![/color]")
	append_line("[color=#FFD700]**********************************************************************[/color]")
	append_line("[color=#00FF66][STATUS: PRONTO] Seu operador agora está PRONTO para a partida![/color]")
	append_line("[color=#FFD700]**********************************************************************[/color]")
	is_simulating_ftp = false

	# Envia pacote de operador pronto ao servidor
	NetworkManager.is_player_ready = true
	NetworkManager.send_packet({ "type": "C2S_PLAYER_READY" })
	command_input.call_deferred("grab_focus")

func _init_virtual_fs(initial_hash: String = "") -> void:
	current_vdir = "/"
	var hash_val = initial_hash if initial_hash != "" else NetworkManager.room_session_hash
	if hash_val == "":
		hash_val = "SHA256:7f83b1657ff1fc53b92dc18148a1d65b"

	virtual_fs = {
		"/": {
			"type": "dir",
			"children": ["logs", "security", "system", "readme.txt"]
		},
		"/logs": {
			"type": "dir",
			"children": ["session.log", "traffic.pcap"]
		},
		"/logs/session.log": {
			"type": "file",
			"content": "[LOG] Sessao de rede ativa em %s. Porta=3001 Protocol=TCP" % NetworkManager.server_host
		},
		"/logs/traffic.pcap": {
			"type": "file",
			"content": "[PCAP TRACE] 64 packets captured. Interface: dd0. Status: ESTABLISHED."
		},
		"/security": {
			"type": "dir",
			"children": ["session_hash.zip", "public.pem"]
		},
		"/security/session_hash.zip": {
			"type": "zip",
			"hash": hash_val,
			"extracted": false
		},
		"/security/public.pem": {
			"type": "file",
			"content": "-----BEGIN PUBLIC KEY-----\nDIGITAL_DELIVERY_SESSION_KEY_VERIFIED\n-----END PUBLIC KEY-----"
		},
		"/system": {
			"type": "dir",
			"children": ["firewall.rules", "host.conf"]
		},
		"/system/firewall.rules": {
			"type": "file",
			"content": "ALLOW 3001/TCP INBOUND # REGRA DE TUNEL QUANTICO DE PROCESSOS"
		},
		"/system/host.conf": {
			"type": "file",
			"content": "HOSTNAME=digital-delivery\nPORT=3001\nMAX_PLAYERS=20\nPROTOCOL=WEBSOCKET"
		},
		"/readme.txt": {
			"type": "file",
			"content": "=== GUIA DE AUTENTICACAO DO OPERADOR ===\n1. Use 'ls' para listar pastas e arquivos.\n2. Use 'cd security' para entrar na pasta de chaves.\n3. Use 'unzip session_hash.zip' para extrair o hash e ficar [PRONTO]!"
		}
	}

func cmd_lobby_status() -> void:
	if not is_in_room_lobby:
		append_line("[color=#888888]Nenhuma sala conectada no momento. Digite 'scan' para listar salas ativas.[/color]")
		return

	var adm_str = "SIM (Você)" if NetworkManager.is_room_adm else "NÃO"
	var port_str = "[color=#00FF66]LIBERADA (3001/TCP)[/color]" if NetworkManager.is_room_port_open else "[color=#FF5555]BLOQUEADA NO FIREWALL[/color]"
	var hash_str = "[color=#00FF66]CONFIGURADO (%s)[/color]" % NetworkManager.room_session_hash.substr(0, 16) if NetworkManager.is_room_hash_set else "[color=#FF5555]NÃO CONFIGURADO[/color]"
	var my_ready = "[color=#00FF66][PRONTO][/color]" if NetworkManager.is_player_ready else "[color=#FFFF00][PENDENTE HASH][/color]"

	append_line("[color=#00E5FF]STATUS DA SALA ATUAL:[/color]")
	append_line("  Sala / Modo:       [color=#FFFF00]%s[/color]" % NetworkManager.current_room_name)
	append_line("  PIN da Sala:       [color=#FFFF00]%s[/color]" % NetworkManager.current_pin)
	append_line("  Administrador:     [color=#FFFF00]%s[/color]" % adm_str)
	append_line("  Porta de Conexão:  %s" % port_str)
	append_line("  Senha Hash:        %s" % hash_str)
	append_line("  Seu Status:        %s" % my_ready)
	append_line("  Total Conectados:  [color=#FFFF00]%d operador(es)[/color]" % NetworkManager.connected_players_count)

	if room_players_status.size() > 0:
		append_line("[color=#555555]----------------------------------------------------------------------[/color]")
		append_line("[color=#00E5FF]OPERADORES NO LOBBY:[/color]")
		for p_id in room_players_status.keys():
			var p_info = room_players_status[p_id]
			var uname = str(p_info.get("username", "Operador"))
			var is_adm = p_info.get("is_adm", false)
			var is_rdy = p_info.get("is_ready", false)
			var r_badge = "[color=#00FF66][PRONTO][/color]" if is_rdy else "[color=#FFFF00][PENDENTE][/color]"
			var a_badge = "[ADM] " if is_adm else ""
			append_line("  -> %s%s : %s" % [a_badge, uname, r_badge])
	append_line("[color=#555555]----------------------------------------------------------------------[/color]")

func cmd_leave_room() -> void:
	if not is_in_room_lobby:
		append_line("[color=#FFFF00]Você não está em nenhuma sala de partida.[/color]")
		return

	NetworkManager.disconnect_from_server()
	is_in_room_lobby = false
	update_prompt()
	append_line("[color=#FFFF00][DESCONECTADO] Você saiu da sala e retornou ao terminal principal.[/color]")

func cmd_ping() -> void:
	append_line("[color=#888888][PING] Enviando sinal de teste para %s...[/color]" % NetworkManager.server_http_url)
	NetworkManager.async_fetch_rooms()

# --- Callbacks de Eventos Assíncronos ---

func _on_auth_result(success: bool, message: String, user: String) -> void:
	if success:
		append_line("[color=#00FF66][AUTH OK] %s[/color]" % message)
		if user != "":
			update_prompt()
	else:
		append_line("[color=#FF5555][AUTH FALHOU] %s[/color]" % message)
	command_input.call_deferred("grab_focus")

func _on_rooms_result(success: bool, rooms: Array, message: String) -> void:
	if not success:
		append_line("[color=#FF5555][SCAN ERRO] %s[/color]" % message)
		command_input.call_deferred("grab_focus")
		return

	if rooms.size() == 0:
		append_line("[color=#FFFF00][SCAN] Nenhuma sala ativa encontrada no servidor.[/color]")
		command_input.call_deferred("grab_focus")
		return

	append_line("[color=#00FF66][SCAN RESULT] %d nó(s) de partida encontrado(s):[/color]" % rooms.size())
	append_line("[color=#555555]+----------------+--------+---------+--------+---------+------------+[/color]")
	append_line("[color=#00E5FF]| SALA           | PIN    | STATUS  | TIER   | PLAYERS | MODO       |[/color]")
	append_line("[color=#555555]+----------------+--------+---------+--------+---------+------------+[/color]")

	for r in rooms:
		var r_name = str(r.get("name", r.get("slug", "sala"))).rpad(14)
		var pin = str(r.get("pin", "------")).rpad(6)
		var state = str(r.get("state", "LOBBY")).rpad(7)
		var tier = ("Nível " + str(r.get("difficultyTier", 1))).rpad(6)
		var count = "%d/%d" % [r.get("playerCount", 0), r.get("maxPlayers", 20)]
		count = count.rpad(7)
		var mode = "Equipes" if r.get("isTeamMode", false) else "Solo"
		mode = mode.rpad(10)

		append_line("| [color=#00FF66]%s[/color] | [color=#FFFF00]%s[/color] | %s | %s | %s | %s |" % [r_name, pin, state, tier, count, mode])

	append_line("[color=#555555]+----------------+--------+---------+--------+---------+------------+[/color]")
	append_line("Para conectar: [color=#FFFF00]connect casual[/color], [color=#FFFF00]connect border[/color], [color=#FFFF00]connect challenge[/color] ou [color=#FFFF00]connect <PIN>[/color]")
	append_line("")
	command_input.call_deferred("grab_focus")

func _on_room_created(success: bool, pin: String, message: String) -> void:
	if success:
		append_line("[color=#00FF66][HOST OK] %s PIN gerado: [b]%s[/b][/color]" % [message, pin])
		append_line("[color=#00E5FF][AUTO-CONNECT] Conectando automaticamente ao nó '%s'...[/color]" % pin)
		cmd_connect([pin])
	else:
		append_line("[color=#FF5555][HOST ERRO] %s[/color]" % message)
	command_input.call_deferred("grab_focus")

func _on_room_join_result(success: bool, message: String) -> void:
	is_connecting_room = false
	if success:
		is_in_room_lobby = true
		current_vdir = "/"
		_init_virtual_fs(NetworkManager.room_session_hash)
		update_prompt()
		append_line("[color=#00FF66][LINK ESTABELECIDO] %s[/color]" % message)
		append_line("[color=#555555]----------------------------------------------------------------------[/color]")
		if NetworkManager.is_room_adm:
			append_line("[color=#FFD700][SALA %s - ADM] VOCÊ É O ADMINISTRADOR DESTA SALA.[/color]" % NetworkManager.current_room_name.to_upper())
			append_line("[color=#00E5FF]MISSÃO DO HOST (CONFIGURAÇÃO DE ACESSO):[/color]")
			append_line("  1. Libere a porta do firewall: [color=#FFFF00]port open 3001[/color] (ou [color=#FFFF00]ufw allow 3001[/color])")
			append_line("  2. Gere a chave hash da sessão: [color=#FFFF00]hash gen <chave>[/color] (ex: [color=#FFFF00]hash gen cyber[/color])")
			append_line("  3. Aguarde os operadores conectarem e extraírem a chave com 'unzip'.")
			append_line("  4. Quando todos estiverem [color=#00FF66][PRONTO][/color], execute: [color=#FFFF00]start tunnel[/color]")
			append_line("[color=#888888]Comandos úteis: status, port open 3001, hash gen <txt>, ls, cd, cat, start tunnel, leave[/color]")
		else:
			append_line("[color=#00E5FF][SALA %s] CONECTADO AO NÓ COMO CONVIDADO.[/color]" % NetworkManager.current_room_name.to_upper())
			append_line("[color=#FFFF00]MISSÃO DO OPERADOR (AUTENTICAÇÃO DE ENTRADA):[/color]")
			append_line("  Status inicial: [color=#FFFF00][PENDENTE HASH][/color]")
			append_line("  1. Explore o diretório de arquivos: [color=#FFFF00]ls[/color]")
			append_line("  2. Acesse a pasta de segurança: [color=#FFFF00]cd security[/color]")
			append_line("  3. Descompacte o pacote de autenticação: [color=#FFFF00]unzip session_hash.zip[/color]")
			append_line("  Ao concluir a extração, seu status mudará para [color=#00FF66][PRONTO][/color]!")
			append_line("[color=#888888]Comandos úteis: status, ls, dir, cd, pwd, cat, unzip, leave[/color]")
		append_line("[color=#555555]----------------------------------------------------------------------[/color]")
	else:
		append_line("[color=#FF5555][FALHA NA CONEXÃO] %s[/color]" % message)
	command_input.call_deferred("grab_focus")

func _on_room_security_updated(is_port_open: bool, is_hash_set: bool, session_hash: String, message: String) -> void:
	if is_hash_set and virtual_fs.has("/security/session_hash.zip"):
		virtual_fs["/security/session_hash.zip"]["hash"] = session_hash

	append_line("[color=#00E5FF][SEGURANÇA DA SALA] %s[/color]" % message)
	if is_port_open:
		append_line("  -> Porta 3001/TCP: [color=#00FF66]LIBERADA NO FIREWALL[/color]")
	if is_hash_set:
		append_line("  -> Senha Hash da Sessão: [color=#00FF66]CONFIGURADA (%s)[/color]" % session_hash.substr(0, 16))
		if not NetworkManager.is_room_adm and not NetworkManager.is_player_ready:
			append_line("  -> [color=#FFFF00]ATENÇÃO: A chave está pronta! Use 'cd security' e 'unzip session_hash.zip' para validar seu acesso![/color]")
	command_input.call_deferred("grab_focus")

func _on_player_ready_status_received(player_id: String, username: String, is_ready: bool) -> void:
	if room_players_status.has(player_id):
		room_players_status[player_id]["is_ready"] = is_ready
	else:
		room_players_status[player_id] = {
			"username": username,
			"is_ready": is_ready,
			"is_adm": false
		}

	if is_ready:
		append_line("[color=#00FF66][LOBBY] Operador '%s' descompactou a chave hash e está [PRONTO]![/color]" % username)
		if NetworkManager.is_room_adm:
			var all_ready = true
			for p in room_players_status.values():
				if not p.get("is_ready", false):
					all_ready = false
					break
			if all_ready and NetworkManager.is_room_port_open and NetworkManager.is_room_hash_set:
				append_line("[color=#FFD700]**********************************************************************[/color]")
				append_line("[color=#00FF66][PRONTIDÃO MÁXIMA] Todos os operadores estão prontos e as travas foram liberadas![/color]")
				append_line("[color=#00E5FF]Host: execute [b]'start tunnel'[/b] para abrir a arena 3D![/color]")
				append_line("[color=#FFD700]**********************************************************************[/color]")
	else:
		append_line("[color=#FFFF00][LOBBY] Operador '%s' está com status [PENDENTE HASH].[/color]" % username)
	command_input.call_deferred("grab_focus")

func _on_network_packet_received(packet: Dictionary) -> void:
	match packet.get("type"):
		"S2C_ROOM_JOINED":
			var p_list = packet.get("players", [])
			room_players_status.clear()
			for p in p_list:
				var p_id = str(p.get("id", ""))
				if p_id != "":
					room_players_status[p_id] = {
						"username": p.get("username", "Operador"),
						"is_adm": p.get("isAdm", false),
						"is_ready": p.get("isReady", false)
					}
			NetworkManager.connected_players_count = room_players_status.size()
		"S2C_PLAYER_JOINED":
			var p = packet.get("player", {})
			var p_id = str(p.get("id", ""))
			var name_joined = p.get("username", "Operador")
			var is_adm = p.get("isAdm", false)
			var is_ready = p.get("isReady", false)
			if p_id != "":
				room_players_status[p_id] = {
					"username": name_joined,
					"is_adm": is_adm,
					"is_ready": is_ready
				}
			append_line("[color=#00FF66][CONEXÃO] Operador '%s' ingressou na sala.[/color]" % name_joined)
			NetworkManager.connected_players_count = room_players_status.size()
		"S2C_PLAYER_LEFT":
			var p_id = str(packet.get("playerId", ""))
			var p_name = packet.get("username", "")
			if p_id != "" and room_players_status.has(p_id):
				if p_name == "":
					p_name = room_players_status[p_id].get("username", "Operador")
				room_players_status.erase(p_id)
			if p_name != "":
				append_line("[color=#FF5555][DESCONEXÃO] Operador '%s' deixou a sala.[/color]" % p_name)
			else:
				append_line("[color=#FF5555][DESCONEXÃO] Um operador deixou a sala.[/color]")
			NetworkManager.connected_players_count = max(1, room_players_status.size())
		"S2C_ROOM_STATE_CHANGE":
			var state = packet.get("state", "")
			if state == "IN_GAME" or state == "STARTING":
				if is_transitioning:
					return
				is_transitioning = true
				append_line("")
				append_line("[color=#FFD700]**********************************************************************[/color]")
				append_line("[color=#00FF66][TÚNEL ATIVADO] Protocolo 'start tunnel' confirmado pelo servidor![/color]")
				append_line("[color=#00E5FF][ARENA 3D] MATERIALIZANDO OPERADORES E ABRINDO ENTRADA DE PROCESSOS...[/color]")
				append_line("[color=#FFD700]**********************************************************************[/color]")
				append_line("")
				await get_tree().create_timer(1.2).timeout
				get_tree().change_scene_to_file("res://scenes/game/computer_arena.tscn")
		"S2C_ERROR":
			var msg = packet.get("message", "")
			if msg != "":
				append_line("[color=#FF5555][SERVIDOR] %s[/color]" % msg)

func _on_network_connection_closed() -> void:
	if is_in_room_lobby:
		is_in_room_lobby = false
		current_vdir = "/"
		virtual_fs.clear()
		room_players_status.clear()
		update_prompt()
		append_line("[color=#FF5555][AVISO] Conexão com a sala foi encerrada pelo servidor.[/color]")
