extends Node

## DIGITAL DELIVERY - Game Manager (Godot 4 Autoload)
## Gerencia o estado da partida, pontuação local, requisição ativa e modo offline/online

signal score_changed(new_score: int, delta: int, streak: int)
signal time_updated(seconds_remaining: int)
signal request_assigned(request_data: Dictionary)
signal delivery_feedback(is_success: bool, message: String, points: int)
signal virus_alert(sequence: String)
signal popup_triggered(popup_id: String, count: int)
signal process_count_changed(current_count: int, max_capacity: int)
signal system_crashed(reason: String)
signal game_over_triggered(rankings: Array, didactic_summary: Dictionary, reason: String)

var is_online: bool = false
var player_score: int = 0
var player_streak: int = 0
var correct_deliveries: int = 0
var failed_deliveries: int = 0
var match_time_remaining: float = 480.0 # 8 minutos (GDD Seção 5 e 15)
var is_match_running: bool = true
var is_crashed: bool = false
var crash_reason: String = ""

# Controle de Processos e Sobrecarga de CPU
var active_processes_count: int = 0
var max_processes_capacity: int = 12

# Resultados e Rankings para a tela de Game Over
var final_rankings: Array = []
var final_didactic_summary: Dictionary = {}

var active_request: Dictionary = {}
var carried_cube: Node3D = null
var logged_in_username: String = ""
var current_room_pin: String = ""
var current_room_name: String = ""
var is_room_adm: bool = false
var current_room_config: Dictionary = {}
var is_in_game_terminal_open: bool = false
var has_active_popup: bool = false

func _ready() -> void:
	is_match_running = false
	match_time_remaining = 480.0
	is_crashed = false
	is_in_game_terminal_open = false
	has_active_popup = false
	is_room_adm = false
	current_room_name = ""

func _process(delta: float) -> void:
	if is_match_running and not is_crashed:
		if not is_online:
			match_time_remaining -= delta
			if match_time_remaining <= 0.0:
				match_time_remaining = 0.0
				end_game_normal("TEMPO_ESGOTADO")
			time_updated.emit(int(match_time_remaining))
		else:
			match_time_remaining = max(0.0, match_time_remaining - delta)
			time_updated.emit(int(match_time_remaining))

func start_offline_practice() -> void:
	is_online = false
	is_in_game_terminal_open = false
	player_score = 0
	player_streak = 0
	correct_deliveries = 0
	failed_deliveries = 0
	match_time_remaining = 480.0
	is_match_running = true
	is_crashed = false
	crash_reason = ""
	active_processes_count = 0
	max_processes_capacity = 12
	has_active_popup = false
	is_room_adm = false
	current_room_name = ""
	final_rankings.clear()
	final_didactic_summary.clear()
	generate_new_offline_request()

func update_process_count(current: int, max_cap: int = -1) -> void:
	active_processes_count = current
	if max_cap > 0:
		max_processes_capacity = max_cap
	process_count_changed.emit(active_processes_count, max_processes_capacity)

	if active_processes_count >= max_processes_capacity and not is_crashed and is_match_running:
		trigger_system_crash("SOBRECARGA DE PROCESSOS: BUFFER OVERFLOW")

func trigger_system_crash(reason: String = "SOBRECARGA DE PROCESSOS") -> void:
	if is_crashed:
		return
	is_crashed = true
	is_match_running = false
	crash_reason = reason
	system_crashed.emit(reason)

	if not is_online:
		final_rankings = generate_offline_rankings()
		final_didactic_summary = {
			"totalDeliveries": correct_deliveries + failed_deliveries,
			"accuracyPercentage": int((float(correct_deliveries) / max(1, correct_deliveries + failed_deliveries)) * 100.0),
			"bestCategory": "Documentos",
			"needsReviewCategory": "Planilhas"
		}

	game_over_triggered.emit(final_rankings, final_didactic_summary, reason)

func end_game_normal(reason: String = "TEMPO_ESGOTADO") -> void:
	if not is_match_running:
		return
	is_match_running = false
	crash_reason = reason

	if not is_online:
		final_rankings = generate_offline_rankings()
		final_didactic_summary = {
			"totalDeliveries": correct_deliveries + failed_deliveries,
			"accuracyPercentage": int((float(correct_deliveries) / max(1, correct_deliveries + failed_deliveries)) * 100.0),
			"bestCategory": "Geral",
			"needsReviewCategory": "Nenhum"
		}

	game_over_triggered.emit(final_rankings, final_didactic_summary, reason)

func generate_offline_rankings() -> Array:
	var my_name = logged_in_username if logged_in_username != "" else "Operador"
	var list = [
		{ "username": my_name, "score": player_score, "correctDeliveries": correct_deliveries, "failedDeliveries": failed_deliveries, "is_local_player": true },
		{ "username": "RootDaemon", "score": 350, "correctDeliveries": 3, "failedDeliveries": 0, "is_local_player": false },
		{ "username": "ByteRunner", "score": 250, "correctDeliveries": 2, "failedDeliveries": 1, "is_local_player": false },
		{ "username": "CyberNova", "score": 180, "correctDeliveries": 1, "failedDeliveries": 0, "is_local_player": false },
		{ "username": "BufferKnight", "score": 100, "correctDeliveries": 1, "failedDeliveries": 2, "is_local_player": false },
		{ "username": "NullPointer", "score": 40, "correctDeliveries": 0, "failedDeliveries": 3, "is_local_player": false }
	]

	# Ordena por pontuação decrescente
	list.sort_custom(func(a, b): return a["score"] > b["score"])

	for i in range(list.size()):
		list[i]["rank"] = i + 1

	return list

func generate_new_offline_request() -> void:
	var sample = KnowledgeBase.SAMPLE_FILES.pick_random()
	active_request = {
		"id": "req_local_" + str(Time.get_ticks_msec()),
		"prompt": "O cliente precisa processar o arquivo '%s' no software correto." % sample["name"],
		"file_name": sample["name"],
		"extension": sample["ext"],
		"category": sample["category"],
		"target_software": sample["software"]
	}
	request_assigned.emit(active_request)

func register_delivery_attempt(extension: String, software_id: String) -> bool:
	var validation = KnowledgeBase.validate_delivery(extension, software_id)
	
	if validation["is_valid"]:
		player_streak += 1
		var streak_bonus = (player_streak - 1) * 15
		var points = 100 + streak_bonus
		player_score += points
		correct_deliveries += 1
		
		var msg = "Entrega Perfeita em %s! (+%d pts)" % [validation["station_name"], points]
		if player_streak > 1:
			msg += " [Streak x%d!]" % player_streak
			
		delivery_feedback.emit(true, msg, points)
		score_changed.emit(player_score, points, player_streak)
		
		# Em modo offline, gera um novo pedido
		if not is_online:
			generate_new_offline_request()
		return true
	else:
		player_streak = 0
		var penalty = 40
		player_score = max(0, player_score - penalty)
		failed_deliveries += 1
		
		var msg = "ERRO: %s (-%d pts)" % [validation["reason"], penalty]
		delivery_feedback.emit(false, msg, -penalty)
		score_changed.emit(player_score, -penalty, 0)
		return false
