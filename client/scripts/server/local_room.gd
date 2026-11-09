extends RefCounted
class_name LocalRoom

const KnowledgeBaseClass = preload("res://scripts/autoload/knowledge_base.gd")

## DIGITAL DELIVERY - Sala Autoritativa Local (Host / Listen Server)
## Executa a lógica de física e regras didáticas da partida dentro do Godot:
## - Geração periódica de processos (cubos) caindo na CPU central
## - Avaliação de entregas nas estações de software com pontuação e bônus
## - Replicação de estados via snapshots JSON (20 TPS) para todos os jogadores conectados

signal packet_to_send(peer: WebSocketPeer, packet: Dictionary)
signal room_game_over(room: LocalRoom)

var id: String = ""
var pin: String = ""
var name: String = ""
var difficulty_tier: int = 1
var duration_seconds: int = 480
var max_players: int = 20
var state: String = "LOBBY" # LOBBY, STARTING, IN_GAME, GAME_OVER

# Segurança e Puzzle de Conexão da Sala
var is_port_open: bool = false
var session_hash: String = ""
var is_hash_set: bool = false

# Jogadores: peer_id (int) -> Dictionary
var players: Dictionary = {}
var player_colors: Array[String] = [
	"#E74C3C", "#3498DB", "#2ECC71", "#F1C40F",
	"#9B59B6", "#E67E22", "#1ABC9C", "#E84393"
]

# Cubos/Processos: cube_id (String) -> Dictionary
var cubes: Dictionary = {}
var cube_spawn_timer: float = 0.0
var cube_spawn_interval: float = 4.5
var next_cube_seq: int = 100

# Temporizadores do jogo
var match_time_remaining: float = 480.0
var tick_timer: float = 0.0
const TICK_INTERVAL: float = 0.05 # 20 TPS (50ms)

# Hazard timers
var popup_timer: float = 70.0
var firewall_timer: float = 6.0

func _init(room_id: String, room_pin: String, room_name: String, tier: int = 1, duration: int = 480) -> void:
	id = room_id
	pin = room_pin
	name = room_name
	difficulty_tier = tier
	duration_seconds = duration
	match_time_remaining = float(duration)
	popup_timer = randf_range(50.0, 80.0)

func add_player(peer: WebSocketPeer, peer_id: int, username: String) -> Dictionary:
	if players.size() >= max_players:
		return { "success": false, "message": "Sala lotada (máximo 20 jogadores)." }
	if state == "GAME_OVER":
		return { "success": false, "message": "Esta partida já foi encerrada." }

	var player_id = "p_%d_%d" % [Time.get_ticks_msec(), peer_id]
	var is_first = (players.size() == 0)
	var assigned_color = player_colors[players.size() % player_colors.size()]
	var final_username = username.strip_edges()
	if final_username == "":
		final_username = "Operador_%d" % (players.size() + 1)

	var p_data = {
		"peer": peer,
		"peer_id": peer_id,
		"id": player_id,
		"username": final_username,
		"color": assigned_color,
		"score": 0,
		"streak": 0,
		"correct": 0,
		"failed": 0,
		"is_adm": is_first,
		"is_ready": is_first, # O Host inicia pronto; convidados devem descompactar o hash
		"carried_cube_id": null,
		"position": { "x": 0.0, "y": 0.5, "z": 0.0 },
		"velocity": { "x": 0.0, "y": 0.0, "z": 0.0 },
		"yaw": 0.0
	}
	players[peer_id] = p_data

	# Notifica o novo jogador com S2C_ROOM_JOINED
	var all_players_list = []
	for p in players.values():
		all_players_list.append(_get_player_public_dict(p))

	var join_packet = {
		"type": "S2C_ROOM_JOINED",
		"player": _get_player_public_dict(p_data),
		"players": all_players_list,
		"roomName": name,
		"security": {
			"isPortOpen": is_port_open,
			"isHashSet": is_hash_set,
			"sessionHash": session_hash
		},
		"config": {
			"pin": pin,
			"name": name,
			"difficultyTier": difficulty_tier,
			"durationSeconds": duration_seconds,
			"maxPlayers": max_players
		}
	}
	_send_to_peer(peer, join_packet)

	# Notifica os outros jogadores com S2C_PLAYER_JOINED
	broadcast({
		"type": "S2C_PLAYER_JOINED",
		"player": _get_player_public_dict(p_data)
	}, peer_id)

	return { "success": true, "player": p_data }

func remove_player(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	var p_data = players[peer_id]
	var p_id = p_data["id"]

	# Solta cubo que o jogador estava carregando
	if p_data["carried_cube_id"] != null:
		var c_id = p_data["carried_cube_id"]
		if cubes.has(c_id):
			cubes[c_id]["carrierPlayerId"] = null
			cubes[c_id]["state"] = "DROPPED_BOUNCING"

	players.erase(peer_id)

	# Se era o ADM e sobrou gente, promove o próximo
	if p_data.get("is_adm", false) and players.size() > 0:
		var next_peer_id = players.keys()[0]
		players[next_peer_id]["is_adm"] = true

	broadcast({
		"type": "S2C_PLAYER_LEFT",
		"playerId": p_id
	})

func handle_packet(peer_id: int, packet: Dictionary) -> void:
	if not players.has(peer_id):
		return
	var p = players[peer_id]
	var p_type = str(packet.get("type", ""))

	match p_type:
		"C2S_HOST_OPEN_PORT":
			if p.get("is_adm", false):
				is_port_open = true
				broadcast({
					"type": "S2C_ROOM_SECURITY_UPDATE",
					"isPortOpen": is_port_open,
					"isHashSet": is_hash_set,
					"sessionHash": session_hash,
					"message": "PORTA 3001/TCP LIBERADA PELO HOST NO FIREWALL!"
				})

		"C2S_HOST_SET_HASH":
			if p.get("is_adm", false):
				session_hash = str(packet.get("hash", "")).strip_edges()
				is_hash_set = true
				broadcast({
					"type": "S2C_ROOM_SECURITY_UPDATE",
					"isPortOpen": is_port_open,
					"isHashSet": is_hash_set,
					"sessionHash": session_hash,
					"message": "SENHA HASH DA SESSÃO DEFINIDA COM SUCESSO!"
				})

		"C2S_PLAYER_READY":
			p["is_ready"] = true
			broadcast({
				"type": "S2C_PLAYER_READY_STATUS",
				"playerId": p["id"],
				"username": p["username"],
				"isReady": true
			})

		"C2S_START_GAME", "C2S_START_TUNNEL":
			if p.get("is_adm", false):
				# Valida se a porta foi aberta
				if not is_port_open:
					_send_to_peer(p["peer"], {
						"type": "S2C_ERROR",
						"message": "A porta de conexão ainda não foi liberada! Execute: 'port open 3001' ou 'ufw allow 3001'."
					})
					return

				# Valida se o hash foi configurado
				if not is_hash_set:
					_send_to_peer(p["peer"], {
						"type": "S2C_ERROR",
						"message": "A senha hash da sala não foi configurada! Execute: 'hash gen <chave>' ou 'hash set <chave>'."
					})
					return

				# Valida se todos os jogadores estão prontos
				var pending_players: Array[String] = []
				for other_p in players.values():
					if not other_p.get("is_ready", false):
						pending_players.append(other_p.get("username", "Operador"))

				if pending_players.size() > 0:
					_send_to_peer(p["peer"], {
						"type": "S2C_ERROR",
						"message": "Operadores ainda não autenticaram o hash (%s)! Aguarde ficarem [PRONTOS]." % ", ".join(pending_players)
					})
					return

				start_match()

		"C2S_PLAYER_INPUT":
			var pos = packet.get("position", {})
			var vel = packet.get("velocity", {})
			p["position"] = {
				"x": float(pos.get("x", p["position"]["x"])),
				"y": float(pos.get("y", p["position"]["y"])),
				"z": float(pos.get("z", p["position"]["z"]))
			}
			p["velocity"] = {
				"x": float(vel.get("x", 0.0)),
				"y": float(vel.get("y", 0.0)),
				"z": float(vel.get("z", 0.0))
			}
			p["yaw"] = float(packet.get("yaw", p["yaw"]))

			# Se carrega um cubo, atualiza a posição do cubo junto com o jogador
			var c_id = p["carried_cube_id"]
			if c_id != null and cubes.has(c_id):
				cubes[c_id]["position"] = {
					"x": p["position"]["x"],
					"y": p["position"]["y"] + 0.45,
					"z": p["position"]["z"] - 0.6
				}

		"C2S_GRAB_CUBE":
			var c_id = str(packet.get("cubeId", ""))
			if cubes.has(c_id) and cubes[c_id]["carrierPlayerId"] == null:
				cubes[c_id]["carrierPlayerId"] = p["id"]
				cubes[c_id]["state"] = "CARRIED"
				p["carried_cube_id"] = c_id

		"C2S_DROP_CUBE":
			var c_id = str(packet.get("cubeId", ""))
			if cubes.has(c_id) and cubes[c_id]["carrierPlayerId"] == p["id"]:
				cubes[c_id]["carrierPlayerId"] = null
				cubes[c_id]["state"] = "DROPPED_BOUNCING"
				p["carried_cube_id"] = null

		"C2S_SUBMIT_DELIVERY":
			var station_id = str(packet.get("softwareStationId", ""))
			var c_id = str(packet.get("cubeId", ""))
			_evaluate_delivery(peer_id, station_id, c_id)

func start_match() -> void:
	if state == "IN_GAME":
		return
	state = "IN_GAME"
	match_time_remaining = float(duration_seconds)
	_spawn_initial_cubes()

	broadcast({
		"type": "S2C_ROOM_STATE_CHANGE",
		"state": "IN_GAME",
		"matchTimeRemainingMs": int(match_time_remaining * 1000.0)
	})

func update(delta: float) -> void:
	if state != "IN_GAME":
		return

	match_time_remaining -= delta
	if match_time_remaining <= 0.0:
		match_time_remaining = 0.0
		end_game("TEMPO_ESGOTADO")
		return

	# Geração periódica de novos processos caindo
	cube_spawn_timer -= delta
	var target_cubes = max(3, int(ceil(float(players.size()) * 2.0)))
	if cubes.size() < target_cubes or cube_spawn_timer <= 0.0:
		cube_spawn_timer = cube_spawn_interval
		_spawn_cube()

	# Tick Snapshot a 20 TPS
	tick_timer -= delta
	if tick_timer <= 0.0:
		tick_timer = TICK_INTERVAL
		_broadcast_tick_snapshot()

func _spawn_initial_cubes() -> void:
	var target_cubes = max(4, players.size() * 2)
	for i in range(target_cubes):
		_spawn_cube()

func _spawn_cube() -> void:
	next_cube_seq += 1
	var c_id = "cube_%d" % next_cube_seq
	var sample = KnowledgeBaseClass.SAMPLE_FILES.pick_random()

	var drop_x = randf_range(-5.0, 5.0)
	var drop_z = randf_range(-7.0, -2.0)

	cubes[c_id] = {
		"id": c_id,
		"fileName": sample.get("name", "arquivo.dat"),
		"extension": sample.get("ext", ".dat"),
		"category": sample.get("category", "DOCUMENT"),
		"colorHex": KnowledgeBaseClass.get_category_color(sample.get("category", "DOCUMENT")).to_html(false),
		"carrierPlayerId": null,
		"position": { "x": drop_x, "y": 12.0, "z": drop_z },
		"state": "SPAWNED"
	}

func _evaluate_delivery(peer_id: int, station_id: String, cube_id: String) -> void:
	if not players.has(peer_id):
		return
	var p = players[peer_id]
	if not cubes.has(cube_id):
		return

	var cube_data = cubes[cube_id]
	var ext = str(cube_data.get("extension", ""))
	var validation = KnowledgeBaseClass.validate_delivery(ext, station_id)
	var is_correct = bool(validation.get("is_valid", false))

	var delta = 0
	var msg = ""
	if is_correct:
		p["correct"] += 1
		p["streak"] += 1
		var streak_bonus = min(p["streak"], 4) * 15
		delta = 100 + streak_bonus
		p["score"] += delta
		msg = "Entrega Correta! +%d pontos (Sequência x%d)" % [delta, p["streak"]]
	else:
		p["failed"] += 1
		p["streak"] = 0
		delta = -40
		p["score"] = max(0, p["score"] + delta)
		msg = str(validation.get("reason", "Software Incorreto! -40 pontos"))

	# Desvincula o cubo entregue e remove-o da arena
	if p["carried_cube_id"] == cube_id:
		p["carried_cube_id"] = null
	cubes.erase(cube_id)

	# Envia resultado para o jogador
	var eval_packet = {
		"type": "S2C_DELIVERY_EVALUATED",
		"playerId": p["id"],
		"requestId": "",
		"result": {
			"scoreDelta": delta,
			"penalty": 0 if is_correct else 40,
			"summaryMessage": msg,
			"newStreak": p["streak"]
		}
	}
	_send_to_peer(p["peer"], eval_packet)

func _broadcast_tick_snapshot() -> void:
	var players_snap = []
	for p in players.values():
		players_snap.append({
			"id": p["id"],
			"username": p["username"],
			"color": p["color"],
			"score": p["score"],
			"streak": p["streak"],
			"carriedCubeId": p["carried_cube_id"],
			"position": p["position"],
			"velocity": p["velocity"],
			"yaw": p["yaw"]
		})

	var cubes_snap = []
	for c in cubes.values():
		cubes_snap.append(c)

	var snapshot = {
		"type": "S2C_TICK_SNAPSHOT",
		"serverTime": Time.get_ticks_msec(),
		"timeRemainingMs": int(match_time_remaining * 1000.0),
		"players": players_snap,
		"cubes": cubes_snap,
		"processCount": cubes.size(),
		"maxProcesses": max(12, players.size() * 6),
		"hazards": {
			"ram": { "activePlayersCount": 0, "isOverloaded": false, "speedMultiplier": 1.0 },
			"viruses": [],
			"firewalls": [],
			"isUsbBlocked": false
		}
	}
	broadcast(snapshot)

func end_game(reason: String = "TEMPO_ESGOTADO") -> void:
	state = "GAME_OVER"

	# Constrói o ranking final ordenado por pontuação
	var sorted_players = players.values().duplicate()
	sorted_players.sort_custom(func(a, b): return a["score"] > b["score"])

	var rankings = []
	var rank = 1
	var total_correct = 0
	var total_failed = 0

	for sp in sorted_players:
		total_correct += sp["correct"]
		total_failed += sp["failed"]
		rankings.append({
			"rank": rank,
			"playerId": sp["id"],
			"username": sp["username"],
			"score": sp["score"],
			"correctDeliveries": sp["correct"],
			"failedDeliveries": sp["failed"]
		})
		rank += 1

	var total = max(1, total_correct + total_failed)
	var didactic = {
		"totalDeliveries": total_correct + total_failed,
		"accuracyPercentage": int((float(total_correct) / float(total)) * 100.0),
		"bestCategory": "Documentos",
		"needsReviewCategory": "Planilhas"
	}

	broadcast({
		"type": "S2C_GAME_OVER",
		"rankings": rankings,
		"didacticSummary": didactic,
		"reason": reason
	})
	room_game_over.emit(self)

func broadcast(packet: Dictionary, exclude_peer_id: int = -1) -> void:
	for peer_id in players.keys():
		if peer_id != exclude_peer_id:
			var p = players[peer_id]
			_send_to_peer(p["peer"], packet)

func _send_to_peer(peer: WebSocketPeer, packet: Dictionary) -> void:
	packet_to_send.emit(peer, packet)
	if peer != null and peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var json = JSON.stringify(packet)
		peer.send_text(json)

func _get_player_public_dict(p: Dictionary) -> Dictionary:
	return {
		"id": p["id"],
		"username": p["username"],
		"color": p["color"],
		"score": p["score"],
		"streak": p["streak"],
		"isAdm": p.get("is_adm", false),
		"isReady": p.get("is_ready", false)
	}
