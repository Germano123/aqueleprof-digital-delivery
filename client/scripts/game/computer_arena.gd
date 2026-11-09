extends Node3D

## DIGITAL DELIVERY - Arena Central (O Interior do Computador)
## Ref: Seções 6 e 11 do GDD.md
## Modo Frenesi: Processos caindo do alto na proporção de 2/3 dos jogadores

@onready var cubes_container: Node3D = $CubesContainer
@onready var remote_players_container: Node3D = $RemotePlayersContainer
@onready var player: PlayerController = $Player
@onready var ram_area: Area3D = $Hazards/RamPlatform/RamArea
@onready var software_stations: Node3D = $SoftwareStations

var file_cube_scene: PackedScene = preload("res://scenes/game/file_cube.tscn")
var ram_players_count: int = 0
var drop_timer: float = 0.0
var base_drop_interval: float = 4.5 # Novos processos caem a cada 4.5s no modo frenesi

var firewall_check_timer: float = 3.0
const FIREWALL_INTERVAL: float = 6.5
var popup_hazard_timer: float = 60.0

func _ready() -> void:
	GameManager.is_crashed = false
	GameManager.is_in_game_terminal_open = false
	popup_hazard_timer = randf_range(50.0, 80.0)

	# Assegura que todas as estações de software tenham seus pontos de coleta apontados para o centro
	for station in software_stations.get_children():
		if station is SoftwareStation:
			station.orient_towards_center(Vector3.ZERO)

	if GameManager.is_online:
		GameManager.is_match_running = true
		if GameManager.current_room_config.has("durationSeconds"):
			GameManager.match_time_remaining = float(GameManager.current_room_config["durationSeconds"])
		NetworkManager.tick_snapshot_received.connect(_on_tick_snapshot)
		NetworkManager.send_packet({ "type": "C2S_START_GAME" })
		if NetworkManager.last_snapshot.size() > 0:
			_on_tick_snapshot(NetworkManager.last_snapshot)
	else:
		GameManager.start_offline_practice()
		spawn_initial_cubes()

	if ram_area:
		ram_area.body_entered.connect(_on_ram_body_entered)
		ram_area.body_exited.connect(_on_ram_body_exited)

func _input(event: InputEvent) -> void:
	# Tecla P para teste rápido do sistema de popups abusivos
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			if not GameManager.has_active_popup and not GameManager.is_in_game_terminal_open:
				GameManager.popup_triggered.emit("adware_debug", 1)

func _process(delta: float) -> void:
	if not GameManager.is_match_running or GameManager.is_crashed:
		return

	# Orquestra ciclo do Firewall (máximo 2 ativos, 4s wipe shader + 6s duração)
	_process_firewall_scheduler(delta)

	# Orquestra popups abusivos periódicos
	_process_popup_scheduler(delta)

	# No modo offline, o cliente local orquestra os processos frenéticos
	if not GameManager.is_online:
		drop_timer -= delta
		var active_count = get_active_process_count()
		var target_processes = get_target_active_processes()

		# Se estiver abaixo da cota de processos ou o timer zerar, derruba novo cubo
		if active_count < target_processes or drop_timer <= 0.0:
			drop_timer = base_drop_interval
			spawn_falling_process()

		_update_and_check_processes()

func _process_firewall_scheduler(delta: float) -> void:
	firewall_check_timer -= delta
	if firewall_check_timer <= 0.0:
		firewall_check_timer = FIREWALL_INTERVAL
		var active_count = get_active_firewalls_count()
		# Regra estrita: NUNCA deve ter 3 firewalls ativos (máximo 2!)
		if active_count < 2:
			trigger_random_firewall()

func get_active_firewalls_count() -> int:
	var count = 0
	if not software_stations:
		return 0
	for station in software_stations.get_children():
		if station is SoftwareStation and station.is_firewall_active():
			count += 1
	return count

func trigger_random_firewall() -> void:
	if not software_stations:
		return
	var candidates: Array[SoftwareStation] = []
	for station in software_stations.get_children():
		if station is SoftwareStation and not station.is_firewall_active():
			candidates.append(station)

	if candidates.size() > 0:
		var chosen = candidates.pick_random()
		chosen.activate_firewall()

func _process_popup_scheduler(delta: float) -> void:
	if GameManager.has_active_popup or GameManager.is_in_game_terminal_open:
		return
	popup_hazard_timer -= delta
	if popup_hazard_timer <= 0.0:
		# Intervalos longos e imprevisíveis (65s a 115s) para não saturar os jogadores
		popup_hazard_timer = randf_range(65.0, 115.0)
		# 75% de chance de 1 janela, 25% de chance de 2 janelas
		var count = 2 if randf() < 0.25 else 1
		GameManager.popup_triggered.emit("adware_alert", count)

@export var processes_per_player: float = 2.0
@export var min_active_processes: int = 3

func get_target_active_processes() -> int:
	var players_count = 1
	if NetworkManager.is_connected_to_server and NetworkManager.connected_players_count > 0:
		players_count = NetworkManager.connected_players_count
	return max(min_active_processes, int(ceil(float(players_count) * processes_per_player)))

func get_max_processes_capacity() -> int:
	var target = get_target_active_processes()
	return max(12, target * 3)

func get_active_process_count() -> int:
	var count = 0
	for child in cubes_container.get_children():
		if child is FileCube and is_instance_valid(child) and not child.is_queued_for_deletion():
			count += 1
	return count

func spawn_initial_cubes() -> void:
	var target = get_target_active_processes()
	for i in range(target):
		spawn_falling_process()

func spawn_falling_process() -> void:
	if not GameManager.is_match_running or GameManager.is_crashed:
		return

	var sample = KnowledgeBase.SAMPLE_FILES.pick_random()
	var cube_instance = file_cube_scene.instantiate() as FileCube

	# Processo cai fisicamente do alto (Y=12m) na área do processador/requisições
	var drop_x = randf_range(-5.0, 5.0)
	var drop_z = randf_range(-7.0, -2.0)
	cube_instance.position = Vector3(drop_x, 12.0, drop_z)

	cube_instance.set_file_data(sample["name"], sample["ext"], sample["category"])
	cubes_container.add_child(cube_instance)

	# Impulso de queda para quicar na placa-mãe
	cube_instance.linear_velocity = Vector3(randf_range(-0.5, 0.5), -3.0, randf_range(-0.5, 0.5))
	cube_instance.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))

	_update_and_check_processes()

func _update_and_check_processes() -> void:
	var active_count = get_active_process_count()
	var max_cap = get_max_processes_capacity()
	GameManager.update_process_count(active_count, max_cap)

func _on_ram_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		ram_players_count += 1
		_evaluate_ram_effects(body)

func _on_ram_body_exited(body: Node3D) -> void:
	if body is PlayerController:
		ram_players_count = max(0, ram_players_count - 1)
		body.speed_multiplier = 1.0

func _evaluate_ram_effects(player_body: PlayerController) -> void:
	# GDD Seção 11: Se < 5 jogadores, acelerador (+40%). Se >= 5, sobrecarga de RAM (-50%).
	if ram_players_count >= 5:
		player_body.speed_multiplier = 0.5
	else:
		player_body.speed_multiplier = 1.4

func _on_tick_snapshot(snapshot: Dictionary) -> void:
	if not GameManager.is_online or not is_inside_tree():
		return

	var cubes = snapshot.get("cubes", [])
	var server_cube_ids: Dictionary = {}

	for c in cubes:
		var c_id = str(c.get("id", ""))
		if c_id == "":
			continue
		server_cube_ids[c_id] = true

		var pos_dict = c.get("position", {})
		var target_pos = Vector3(
			float(pos_dict.get("x", 0.0)),
			float(pos_dict.get("y", 0.5)),
			float(pos_dict.get("z", 0.0))
		)

		var cube_node = cubes_container.get_node_or_null(c_id) as FileCube
		if cube_node == null:
			cube_node = file_cube_scene.instantiate() as FileCube
			cube_node.name = c_id
			# O cubo cai fisicamente do alto (Y=12m) na frente do jogador
			var spawn_y = target_pos.y
			if spawn_y < 8.0:
				spawn_y = 12.0
			cube_node.position = Vector3(target_pos.x, spawn_y, target_pos.z)
			var file_name = str(c.get("fileName", "arquivo" + str(c.get("extension", ".dat"))))
			var ext = str(c.get("extension", ".dat"))
			var cat = str(c.get("category", "DOCUMENT"))
			cube_node.set_file_data(file_name, ext, cat)
			cubes_container.add_child(cube_node)

			# Impulso físico de queda para quicar na placa-mãe com giro
			cube_node.linear_velocity = Vector3(randf_range(-0.5, 0.5), -4.0, randf_range(-0.5, 0.5))
			cube_node.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
		else:
			# Se o jogador local NÃO estiver segurando este cubo, atualiza a posição
			if not (cube_node.is_carried and cube_node == GameManager.carried_cube):
				var carrier_id = c.get("carrierPlayerId", null)
				if carrier_id != null and str(carrier_id) != NetworkManager.player_id:
					cube_node.freeze = true
					cube_node.global_position = target_pos
				elif not cube_node.is_carried:
					# Só alinha com o servidor se o cubo já atingiu o chão após a queda
					if cube_node.global_position.y <= 1.5:
						if cube_node.global_position.distance_squared_to(target_pos) > 0.05:
							cube_node.global_position = cube_node.global_position.lerp(target_pos, 0.3)

	# Remove cubos que não existem mais no servidor
	for child in cubes_container.get_children():
		if child is FileCube and is_instance_valid(child) and not child.is_queued_for_deletion():
			if not server_cube_ids.has(child.name):
				if child == GameManager.carried_cube:
					GameManager.carried_cube = null
				child.queue_free()

	# Sincroniza avatares dos outros jogadores conectados
	_sync_remote_players(snapshot.get("players", []))

func _sync_remote_players(players_data: Array) -> void:
	if not remote_players_container:
		return

	var current_remote_ids: Dictionary = {}

	for p_data in players_data:
		var p_id = str(p_data.get("id", ""))
		if p_id == "" or p_id == NetworkManager.player_id:
			continue # Não renderiza o avatar do jogador local como proxy remoto

		current_remote_ids[p_id] = true
		var pos_dict = p_data.get("position", {})
		var target_pos = Vector3(
			float(pos_dict.get("x", 0.0)),
			float(pos_dict.get("y", 0.5)),
			float(pos_dict.get("z", 0.0))
		)

		var remote_node = remote_players_container.get_node_or_null(p_id) as Node3D
		if remote_node == null:
			remote_node = Node3D.new()
			remote_node.name = p_id
			remote_node.position = target_pos

			# Modelo visual simples: cápsula com a cor do jogador
			var mesh_inst = MeshInstance3D.new()
			var cap_mesh = CapsuleMesh.new()
			cap_mesh.radius = 0.4
			cap_mesh.height = 1.4
			mesh_inst.mesh = cap_mesh
			mesh_inst.position = Vector3(0, 0.7, 0)

			var mat = StandardMaterial3D.new()
			var color_str = str(p_data.get("color", "#00E5FF"))
			mat.albedo_color = Color(color_str)
			mat.roughness = 0.4
			mesh_inst.material_override = mat
			remote_node.add_child(mesh_inst)

			# Rótulo de nome flutuante 3D
			var label = Label3D.new()
			label.text = str(p_data.get("username", "Operador"))
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.double_sided = true
			label.no_depth_test = true
			label.font_size = 24
			label.outline_size = 6
			label.outline_modulate = Color(0, 0, 0, 1)
			label.position = Vector3(0, 1.8, 0)
			remote_node.add_child(label)

			remote_players_container.add_child(remote_node)
		else:
			remote_node.global_position = remote_node.global_position.lerp(target_pos, 0.4)

	# Remove jogadores remotos que se desconectaram
	for child in remote_players_container.get_children():
		if not current_remote_ids.has(child.name):
			child.queue_free()
