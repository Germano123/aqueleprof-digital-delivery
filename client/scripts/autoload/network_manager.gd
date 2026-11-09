extends Node

## DIGITAL DELIVERY - Network Manager (Godot 4 Autoload)
## Suporte híbrido:
## 1. Listen Server / Host Local nativo (sem depender de Node.js/Docker)
## 2. Cliente LAN WebSocket para conectar no IP de outro jogador Host

signal connected_to_server()
signal connection_closed()
signal packet_received(packet: Dictionary)
signal tick_snapshot_received(snapshot: Dictionary)

# Sinais de resposta para o Terminal
signal auth_result(success: bool, message: String, username: String)
signal rooms_result(success: bool, rooms: Array, message: String)
signal room_created(success: bool, pin: String, message: String)
signal room_join_result(success: bool, message: String)
signal room_security_updated(is_port_open: bool, is_hash_set: bool, session_hash: String, message: String)
signal player_ready_status_received(player_id: String, username: String, is_ready: bool)

var server_host: String = "127.0.0.1:3001"
var server_http_url: String = "http://127.0.0.1:3001"
var server_ws_url: String = "ws://127.0.0.1:3001"

var ws: WebSocketPeer = WebSocketPeer.new()
var is_connected_to_server: bool = false
var is_room_adm: bool = false
var is_hosting: bool = false
var current_room_name: String = ""
var current_pin: String = ""
var player_id: String = ""
var is_player_ready: bool = false
var is_room_port_open: bool = false
var is_room_hash_set: bool = false
var room_session_hash: String = ""
var pending_join_username: String = ""
var pending_join_pin: String = ""
var join_timeout_timer: float = 0.0
var connected_players_count: int = 1
var last_snapshot: Dictionary = {}

const LocalServerHostClass = preload("res://scripts/server/local_server_host.gd")

# Servidor Host Local Integrado no Godot
var local_host: Node = null

func _ready() -> void:
	# Inicializa o motor de servidor host local sob demanda
	local_host = LocalServerHostClass.new()
	local_host.name = "LocalServerHostInstance"
	add_child(local_host)
	set_server_host("127.0.0.1:3001")

func set_server_host(host_string: String) -> void:
	var clean = host_string.strip_edges()
	clean = clean.replace("http://", "").replace("https://", "").replace("ws://", "").replace("wss://", "")
	if not clean.contains(":"):
		clean += ":3001"

	server_host = clean
	server_http_url = "http://" + clean
	server_ws_url = "ws://" + clean

func start_local_host(port: int = 3001) -> bool:
	if local_host == null:
		local_host = LocalServerHostClass.new()
		add_child(local_host)

	var success = local_host.start_server(port)
	if success:
		is_hosting = true
		set_server_host("127.0.0.1:%d" % local_host.listen_port)
	return success

func stop_local_host() -> void:
	if local_host != null and local_host.is_active:
		local_host.stop_server()
	is_hosting = false

func _process(delta: float) -> void:
	if pending_join_pin != "":
		join_timeout_timer -= delta
		if join_timeout_timer <= 0.0:
			var pin_err = pending_join_pin
			pending_join_pin = ""
			# Se tentou conectar em localhost e falhou, inicia o host local automaticamente!
			if server_host.begins_with("127.0.0.1") or server_host.begins_with("localhost"):
				if not is_hosting:
					print("[NetworkManager] Falha ao conectar em localhost. Iniciando Host Local automático...")
					start_local_host(3001)
					connect_and_join(pin_err, pending_join_username)
					return
			room_join_result.emit(false, "Tempo limite esgotado ao tentar conectar à sala. Verifique o servidor/IP.")

	ws.poll()
	var state = ws.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected_to_server:
			is_connected_to_server = true
			connected_to_server.emit()

			# Se havia uma solicitação pendente de entrada na sala
			if pending_join_pin != "":
				var pin_to_send = pending_join_pin
				var user_to_send = pending_join_username
				pending_join_pin = ""
				send_packet({
					"type": "C2S_JOIN_ROOM",
					"pin": pin_to_send,
					"username": user_to_send
				})

		while ws.get_available_packet_count() > 0:
			var raw = ws.get_packet().get_string_from_utf8()
			var json = JSON.parse_string(raw)
			if json is Dictionary:
				_handle_server_packet(json)

	elif state == WebSocketPeer.STATE_CLOSED:
		if is_connected_to_server:
			is_connected_to_server = false
			connection_closed.emit()

# --- Requisições REST HTTP e Fallbacks Locais ---

func async_register(username: String, password: String) -> void:
	# No modo autônomo (Host local), o cadastro de operador é aceito imediatamente em memória
	if is_hosting or server_host.begins_with("127.0.0.1") or server_host.begins_with("localhost"):
		auth_result.emit(true, "Operador registrado com sucesso no host local!", username)
		return

	var url = server_http_url + "/api/auth/register"
	var body = JSON.stringify({ "username": username, "password": password })
	var headers = ["Content-Type: application/json"]

	_exec_http(url, HTTPClient.METHOD_POST, headers, body, func(result_code: int, response_code: int, json_data: Variant):
		if result_code != HTTPRequest.RESULT_SUCCESS or response_code != 201:
			# Fallback para aceitação local se o servidor HTTP externo não estiver ativo
			auth_result.emit(true, "Operador registrado com sucesso (Sessão Local)!", username)
		else:
			var msg = json_data.get("message", "Operador registrado com sucesso!")
			auth_result.emit(true, msg, username)
	)

func async_login(username: String, password: String) -> void:
	if is_hosting or server_host.begins_with("127.0.0.1") or server_host.begins_with("localhost"):
		GameManager.logged_in_username = username
		auth_result.emit(true, "Acesso concedido (Sessão Local).", username)
		return

	var url = server_http_url + "/api/auth/login"
	var body = JSON.stringify({ "username": username, "password": password })
	var headers = ["Content-Type: application/json"]

	_exec_http(url, HTTPClient.METHOD_POST, headers, body, func(result_code: int, response_code: int, json_data: Variant):
		if result_code != HTTPRequest.RESULT_SUCCESS or response_code != 200:
			# Fallback para aceitação local
			GameManager.logged_in_username = username
			auth_result.emit(true, "Acesso concedido (Sessão Local).", username)
		else:
			var user = json_data.get("username", username)
			GameManager.logged_in_username = user
			var msg = json_data.get("message", "Acesso concedido.")
			auth_result.emit(true, msg, user)
	)

func async_fetch_rooms() -> void:
	# Se o host local estiver ativo, obtém as salas instantaneamente
	if local_host != null and local_host.is_active:
		var rooms = local_host.get_rooms_summary()
		rooms_result.emit(true, rooms, "Varredura local de salas concluída.")
		return

	# Se for conexão remota (IP de outro host), tenta HTTP
	if not (server_host.begins_with("127.0.0.1") or server_host.begins_with("localhost")):
		var url = server_http_url + "/api/rooms"
		var headers = ["Content-Type: application/json"]
		_exec_http(url, HTTPClient.METHOD_GET, headers, "", func(result_code: int, response_code: int, json_data: Variant):
			if result_code != HTTPRequest.RESULT_SUCCESS or response_code != 200:
				rooms_result.emit(false, [], "Não foi possível escanear as salas no host remoto (%s)." % server_http_url)
			else:
				var rooms = []
				if json_data is Dictionary and json_data.has("rooms"):
					rooms = json_data["rooms"]
				rooms_result.emit(true, rooms, "Varredura de salas concluída.")
		)
		return

	# Caso contrário (localhost sem host ativo ainda), inicializa o host local sob demanda
	start_local_host(3001)
	var local_rooms = local_host.get_rooms_summary()
	rooms_result.emit(true, local_rooms, "Host local iniciado. Salas padrão disponíveis:")

func async_create_room(difficulty_tier: int = 1) -> void:
	if not is_hosting:
		start_local_host(3001)

	var room = local_host.create_room("Sala_Custom", difficulty_tier)
	room_created.emit(true, room.pin, "Sala criada no host local com sucesso!")

func _exec_http(url: String, method: HTTPClient.Method, headers: PackedStringArray, body: String, callback: Callable) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.timeout = 3.0

	http.request_completed.connect(func(result: int, response_code: int, _resp_headers: PackedStringArray, resp_body: PackedByteArray):
		var json_data: Variant = null
		if resp_body.size() > 0:
			json_data = JSON.parse_string(resp_body.get_string_from_utf8())
		callback.call(result, response_code, json_data)
		http.queue_free()
	)

	var err = http.request(url, headers, method, body)
	if err != OK:
		callback.call(HTTPRequest.RESULT_CANT_CONNECT, 0, null)
		http.queue_free()

# --- Conexão de Sala WebSocket ---

func connect_and_join(pin_or_name: String, username: String) -> void:
	current_pin = pin_or_name.strip_edges()
	pending_join_username = username
	pending_join_pin = current_pin
	join_timeout_timer = 5.0

	# Se estamos conectando em localhost e o servidor local ainda não foi ligado, liga-o agora!
	if (server_host.begins_with("127.0.0.1") or server_host.begins_with("localhost")) and not is_hosting:
		start_local_host(3001)

	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		send_packet({
			"type": "C2S_JOIN_ROOM",
			"pin": pending_join_pin,
			"username": pending_join_username
		})
		pending_join_pin = ""
	else:
		ws.close()
		ws.connect_to_url(server_ws_url)

func send_packet(packet: Dictionary) -> void:
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var json_str = JSON.stringify(packet)
		ws.send_text(json_str)

func disconnect_from_server() -> void:
	pending_join_pin = ""
	pending_join_username = ""
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.close(1000, "User disconnected")
	is_connected_to_server = false
	current_pin = ""
	player_id = ""
	is_room_adm = false
	is_player_ready = false
	is_room_port_open = false
	is_room_hash_set = false
	room_session_hash = ""
	current_room_name = ""
	GameManager.is_room_adm = false
	GameManager.current_room_name = ""
	connected_players_count = 1
	last_snapshot.clear()
	GameManager.is_online = false
	connection_closed.emit()

func _handle_server_packet(packet: Dictionary) -> void:
	packet_received.emit(packet)

	match packet.get("type"):
		"S2C_ROOM_JOINED":
			GameManager.is_online = true
			var p_data = packet.get("player", {})
			player_id = p_data.get("id", "")
			is_room_adm = p_data.get("isAdm", p_data.get("isHost", false))
			is_player_ready = p_data.get("isReady", is_room_adm)
			current_room_name = packet.get("roomName", packet.get("config", {}).get("name", "casual"))
			GameManager.is_room_adm = is_room_adm
			GameManager.current_room_name = current_room_name
			current_pin = packet.get("config", {}).get("pin", current_pin)
			GameManager.current_room_pin = current_pin
			GameManager.current_room_config = packet.get("config", {})

			var sec = packet.get("security", {})
			is_room_port_open = sec.get("isPortOpen", false)
			is_room_hash_set = sec.get("isHashSet", false)
			room_session_hash = sec.get("sessionHash", "")

			room_join_result.emit(true, "Operador conectado com sucesso à sala '%s' (PIN: %s)!" % [current_room_name, current_pin])

		"S2C_ROOM_SECURITY_UPDATE":
			is_room_port_open = packet.get("isPortOpen", is_room_port_open)
			is_room_hash_set = packet.get("isHashSet", is_room_hash_set)
			room_session_hash = packet.get("sessionHash", room_session_hash)
			var msg = packet.get("message", "Segurança da sala atualizada.")
			room_security_updated.emit(is_room_port_open, is_room_hash_set, room_session_hash, msg)

		"S2C_PLAYER_READY_STATUS":
			var p_id = packet.get("playerId", "")
			var user = packet.get("username", "Operador")
			var ready = packet.get("isReady", false)
			if p_id == player_id:
				is_player_ready = ready
			player_ready_status_received.emit(p_id, user, ready)

		"S2C_ERROR":
			var msg = packet.get("message", "Erro retornado pelo servidor.")
			room_join_result.emit(false, msg)

		"S2C_DELIVERY_EVALUATED":
			var res = packet.get("result", {})
			var is_success = res.get("penalty", 0) == 0
			var msg = res.get("summaryMessage", "Entrega avaliada.")
			var delta = res.get("scoreDelta", 0)
			GameManager.delivery_feedback.emit(is_success, msg, delta)

		"S2C_VIRUS_TRIGGERED":
			var seq = packet.get("sequenceToType", "ABCD")
			GameManager.virus_alert.emit(seq)

		"S2C_POPUP_TRIGGERED":
			var p_id = packet.get("popupId", "adware")
			var p_count = packet.get("popupCount", 1)
			GameManager.has_active_popup = true
			GameManager.popup_triggered.emit(p_id, p_count)

		"S2C_TICK_SNAPSHOT":
			last_snapshot = packet
			var time_rem_ms = packet.get("timeRemainingMs", 480000)
			GameManager.match_time_remaining = float(time_rem_ms) / 1000.0
			GameManager.time_updated.emit(int(GameManager.match_time_remaining))
			var players = packet.get("players", [])
			connected_players_count = max(1, players.size())
			if packet.has("processCount"):
				var p_count = packet.get("processCount", 0)
				var p_max = packet.get("maxProcesses", 8)
				GameManager.update_process_count(p_count, p_max)
			tick_snapshot_received.emit(packet)

		"S2C_GAME_OVER":
			var rankings = packet.get("rankings", [])
			var didactic = packet.get("didacticSummary", {})
			var reason = packet.get("reason", "TIME_EXPIRED")
			GameManager.final_rankings = rankings
			GameManager.final_didactic_summary = didactic
			if reason == "SYSTEM_CRASH":
				GameManager.trigger_system_crash("SOBRECARGA DE PROCESSOS: BUFFER OVERFLOW")
			else:
				GameManager.end_game_normal("TEMPO_ESGOTADO")
