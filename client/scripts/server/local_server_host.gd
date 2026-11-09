extends Node
class_name LocalServerHost

const LocalRoomClass = preload("res://scripts/server/local_room.gd")

## DIGITAL DELIVERY - Servidor Host Local (Listen Server WebSocket)
## Gerencia o socket TCP/WebSocket na porta 3001 (ou porta alternativa)
## Permite que o jogo seja executado em modo multiplayer sem Node.js / Docker.

signal server_started(port: int)
signal server_stopped()

var tcp_server: TCPServer = TCPServer.new()
var is_active: bool = false
var listen_port: int = 3001

# Conexões pendentes e ativas: peer_id -> Dictionary
var next_peer_id: int = 1
var peers: Dictionary = {} # peer_id -> { "ws": WebSocketPeer, "tcp": StreamPeerTCP, "state": String, "room_id": String }

# Salas ativas
var rooms_by_id: Dictionary = {}
var rooms_by_pin: Dictionary = {}

func _ready() -> void:
	ensure_standard_rooms()

func start_server(port: int = 3001) -> bool:
	if is_active:
		return true

	listen_port = port
	var err = tcp_server.listen(port, "0.0.0.0")
	if err != OK:
		# Se a porta estiver em uso, tenta 3002
		listen_port = port + 1
		err = tcp_server.listen(listen_port, "0.0.0.0")
		if err != OK:
			push_error("LocalServerHost: Falha ao abrir porta %d ou %d (Erro: %d)" % [port, listen_port, err])
			return false

	is_active = true
	ensure_standard_rooms()
	server_started.emit(listen_port)
	print("[LocalServerHost] Servidor local iniciado na porta %d!" % listen_port)
	return true

func stop_server() -> void:
	if not is_active:
		return
	is_active = false
	for p_id in peers.keys():
		var p_info = peers[p_id]
		var ws: WebSocketPeer = p_info["ws"]
		if ws != null:
			ws.close(1000, "Servidor Host encerrado.")
	peers.clear()
	tcp_server.stop()
	server_stopped.emit()
	print("[LocalServerHost] Servidor local encerrado.")

func _process(delta: float) -> void:
	if not is_active:
		return

	# Aceita novas conexões TCP
	while tcp_server.is_connection_available():
		var tcp_conn = tcp_server.take_connection()
		if tcp_conn != null:
			_accept_new_connection(tcp_conn)

	# Atualiza peers e processa mensagens WebSocket
	var to_remove = []
	for p_id in peers.keys():
		var p_info = peers[p_id]
		var ws: WebSocketPeer = p_info["ws"]
		if ws == null:
			continue

		ws.poll()
		var state = ws.get_ready_state()

		if state == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var raw = ws.get_packet().get_string_from_utf8()
				var json = JSON.parse_string(raw)
				if json is Dictionary:
					_handle_client_packet(p_id, json)

		elif state == WebSocketPeer.STATE_CLOSED:
			to_remove.append(p_id)

	for p_id in to_remove:
		_disconnect_peer(p_id)

	# Atualiza o ciclo de todas as salas ativas
	for room in rooms_by_id.values():
		if room != null:
			room.update(delta)

func _accept_new_connection(tcp_conn: StreamPeerTCP) -> void:
	var ws = WebSocketPeer.new()
	var err = ws.accept_stream(tcp_conn)
	if err != OK:
		return

	var p_id = next_peer_id
	next_peer_id += 1

	peers[p_id] = {
		"ws": ws,
		"tcp": tcp_conn,
		"room_id": ""
	}

func _disconnect_peer(peer_id: int) -> void:
	if not peers.has(peer_id):
		return
	var p_info = peers[peer_id]
	var r_id = p_info["room_id"]
	if r_id != "" and rooms_by_id.has(r_id):
		rooms_by_id[r_id].remove_player(peer_id)
	peers.erase(peer_id)

func _handle_client_packet(peer_id: int, packet: Dictionary) -> void:
	var p_type = str(packet.get("type", ""))
	var p_info = peers[peer_id]
	var ws: WebSocketPeer = p_info["ws"]

	if p_type == "C2S_JOIN_ROOM":
		var pin_or_name = str(packet.get("pin", "")).strip_edges().to_lower()
		var username = str(packet.get("username", "Operador"))
		var room = find_room_by_pin_or_name(pin_or_name)

		if room == null:
			# Se não encontrou, cria a sala sob demanda se for um PIN de 6 dígitos ou nome
			room = create_room(pin_or_name, 1)

		p_info["room_id"] = room.id
		var res = room.add_player(ws, peer_id, username)
		if not res.get("success", false):
			_send_error(ws, res.get("message", "Falha ao ingressar na sala."))
		return

	# Demais pacotes vão para a sala onde o jogador está
	var current_room_id = p_info["room_id"]
	if current_room_id != "" and rooms_by_id.has(current_room_id):
		rooms_by_id[current_room_id].handle_packet(peer_id, packet)
	else:
		_send_error(ws, "Você não está em nenhuma sala ativa.")

func _send_error(ws: WebSocketPeer, message: String) -> void:
	if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify({ "type": "S2C_ERROR", "message": message }))

func ensure_standard_rooms() -> void:
	var std = [
		{ "name": "casual", "pin": "CASUAL", "tier": 1 },
		{ "name": "border", "pin": "BORDER", "tier": 3 },
		{ "name": "challenge", "pin": "CHALLG", "tier": 5 }
	]
	for def in std:
		var has_room = false
		for r in rooms_by_id.values():
			if r.name.to_lower() == def["name"]:
				has_room = true
				break
		if not has_room:
			var r_id = "room_%s" % def["name"]
			var r = LocalRoomClass.new(r_id, def["pin"], def["name"], def["tier"])
			rooms_by_id[r_id] = r
			rooms_by_pin[def["pin"].to_upper()] = r
			rooms_by_pin[def["name"].to_upper()] = r

func create_room(room_name: String, tier: int = 1) -> RefCounted:
	var pin = _generate_unique_pin()
	var r_id = "room_%d_%s" % [Time.get_ticks_msec(), pin]
	var display_name = room_name
	if display_name == "":
		display_name = "Sala_%s" % pin

	var r = LocalRoomClass.new(r_id, pin, display_name, tier)
	rooms_by_id[r_id] = r
	rooms_by_pin[pin.to_upper()] = r
	rooms_by_pin[display_name.to_upper()] = r
	return r

func find_room_by_pin_or_name(target: String) -> RefCounted:
	var clean = target.strip_edges().to_upper()
	if rooms_by_pin.has(clean):
		return rooms_by_pin[clean]
	for r in rooms_by_id.values():
		if r.name.to_upper() == clean or r.pin.to_upper() == clean:
			return r
	return null

func get_rooms_summary() -> Array:
	var list = []
	for r in rooms_by_id.values():
		list.append({
			"name": r.name,
			"slug": r.name,
			"pin": r.pin,
			"state": r.state,
			"difficultyTier": r.difficulty_tier,
			"playerCount": r.players.size(),
			"maxPlayers": r.max_players,
			"isTeamMode": false,
			"isPortOpen": r.is_port_open,
			"isHashSet": r.is_hash_set
		})
	return list

func _generate_unique_pin() -> String:
	var chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var pin = ""
	for i in range(6):
		pin += chars[randi() % chars.length()]
	return pin
