extends CanvasLayer

## DIGITAL DELIVERY - HUD da Partida
## Ref: Seções 5, 8 e 10 do GDD.md
## Exibe cronômetro de 8 minutos, placar, streak, requisição ativa, barra de sobrecarga de processos e crash

@onready var label_timer: Label = $TopBar/TimerContainer/LabelTimer
@onready var label_score: Label = $TopBar/ScoreContainer/LabelScore
@onready var label_streak: Label = $TopBar/StreakContainer/LabelStreak

@onready var label_process_count: Label = $TopBar/ProcessContainer/VBoxProcess/HBoxHeader/LabelProcessCount
@onready var progress_bar_process: ProgressBar = $TopBar/ProcessContainer/VBoxProcess/ProgressBarProcess
@onready var label_process_status: Label = $TopBar/ProcessContainer/VBoxProcess/LabelProcessStatus

@onready var request_panel: PanelContainer = $RequestCard
@onready var label_request_prompt: Label = $RequestCard/VBox/LabelPrompt
@onready var label_request_file: Label = $RequestCard/VBox/LabelFile

@onready var feedback_panel: PanelContainer = $FeedbackToast
@onready var label_feedback: Label = $FeedbackToast/LabelFeedback

@onready var carried_info_panel: PanelContainer = $CarriedInfo
@onready var label_carried_text: Label = $CarriedInfo/LabelCarried

@onready var crash_overlay: ColorRect = $CrashOverlay
@onready var crt_shutdown_beam: ColorRect = $CrtShutdownBeam

@onready var in_game_terminal: PanelContainer = $InGameTerminal
@onready var terminal_output: RichTextLabel = $InGameTerminal/VBoxTerminal/TerminalOutput
@onready var terminal_input: LineEdit = $InGameTerminal/VBoxTerminal/TerminalInputRow/TerminalInput
@onready var popup_spam_container: Control = $PopupSpamContainer

const POPUP_WINDOW_SCENE = preload("res://scenes/ui/popup_spam_window.tscn")

var feedback_tween: Tween
var is_crashing: bool = false
var active_popups_count: int = 0

func _ready() -> void:
	feedback_panel.modulate.a = 0.0
	carried_info_panel.visible = false
	crash_overlay.visible = false
	crt_shutdown_beam.visible = false
	in_game_terminal.visible = false

	if GameManager.logged_in_username != "":
		var pin_text = GameManager.current_room_pin if GameManager.current_room_pin != "" else "LOCAL"
		$RequestCard/VBox/LabelTitle.text = "📌 REQUISIÇÃO // OP: %s [NÓ: %s]" % [GameManager.logged_in_username, pin_text]

	GameManager.time_updated.connect(_on_time_updated)
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.request_assigned.connect(_on_request_assigned)
	GameManager.delivery_feedback.connect(_on_delivery_feedback)
	GameManager.process_count_changed.connect(_on_process_count_changed)
	GameManager.system_crashed.connect(_on_system_crashed)
	GameManager.game_over_triggered.connect(_on_game_over_triggered)
	GameManager.popup_triggered.connect(_on_popup_triggered)

	# Inicializa cronômetro e contagem imediatamente no primeiro frame
	_on_time_updated(int(GameManager.match_time_remaining))
	_on_process_count_changed(GameManager.active_processes_count, GameManager.max_processes_capacity)

	if terminal_input:
		terminal_input.text_submitted.connect(_on_terminal_command_submitted)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_in_game_terminal()

func _process(_delta: float) -> void:
	if is_crashing:
		return

	if GameManager.carried_cube != null:
		carried_info_panel.visible = true
		var cube = GameManager.carried_cube as FileCube
		label_carried_text.text = "📦 Carregando: %s (%s)\n[E] Largar | [F] Arremessar" % [cube.file_name, cube.extension]
	else:
		carried_info_panel.visible = false

func _on_time_updated(seconds_remaining: int) -> void:
	if is_crashing:
		return
	var mins = seconds_remaining / 60
	var secs = seconds_remaining % 60
	label_timer.text = "%02d:%02d" % [mins, secs]
	if seconds_remaining <= 60:
		label_timer.modulate = Color.RED
	else:
		label_timer.modulate = Color.WHITE

func _on_score_changed(new_score: int, _delta: int, streak: int) -> void:
	label_score.text = "%d pts" % new_score
	if streak > 1:
		label_streak.visible = true
		label_streak.text = "🔥 Streak x%d!" % streak
	else:
		label_streak.visible = false

func _on_process_count_changed(current: int, max_cap: int) -> void:
	if not progress_bar_process:
		return

	progress_bar_process.max_value = max_cap
	progress_bar_process.value = current

	var pct = float(current) / max(1.0, float(max_cap))
	label_process_count.text = "%d / %d PROCESSOS (%d%%)" % [current, max_cap, int(pct * 100.0)]

	if pct < 0.5:
		label_process_status.text = "● ESTÁVEL - FLUXO SEGURO"
		label_process_status.modulate = Color("#2ECC71")
		progress_bar_process.modulate = Color("#2ECC71")
	elif pct < 0.75:
		label_process_status.text = "⚠️ ALERTA: SOBRECARGA MODERADA"
		label_process_status.modulate = Color("#F1C40F")
		progress_bar_process.modulate = Color("#F1C40F")
	else:
		label_process_status.text = "💥 PERIGO: RISCO IMINENTE DE CRASH DO PC!"
		label_process_status.modulate = Color("#E74C3C")
		progress_bar_process.modulate = Color("#E74C3C")

func _on_system_crashed(reason: String) -> void:
	if is_crashing:
		return
	is_crashing = true
	play_crash_and_shutdown_sequence(reason)

func play_crash_and_shutdown_sequence(reason: String) -> void:
	crash_overlay.visible = true
	crash_overlay.modulate.a = 0.0

	var label_code = $CrashOverlay/CenterContainer/VBoxCrash/LabelStopCode
	if label_code:
		label_code.text = "CÓDIGO DE PARADA: %s\nDESLIGANDO SISTEMA INESPERADAMENTE..." % reason.to_upper()

	# Fade-in rápido de tela azul BSOD
	var tween = create_tween()
	tween.tween_property(crash_overlay, "modulate:a", 1.0, 0.15)

	# Aguarda 2 segundos para o impacto visual da tela azul
	await get_tree().create_timer(2.0).timeout

	# Efeito CRT monitor desligando
	crt_shutdown_beam.visible = true
	crt_shutdown_beam.color = Color.WHITE
	crt_shutdown_beam.scale = Vector2(1.0, 1.0)
	crt_shutdown_beam.pivot_offset = Vector2(640, 360)

	var crt_tween = create_tween()
	crt_tween.tween_property(crt_shutdown_beam, "scale:y", 0.004, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	crt_tween.tween_property(crt_shutdown_beam, "scale:x", 0.004, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	crt_tween.tween_callback(func():
		crt_shutdown_beam.color = Color.BLACK
		crt_shutdown_beam.scale = Vector2(1.0, 1.0)
	)

	# Pausa de 0.6s e transição para Game Over
	await get_tree().create_timer(0.7).timeout
	get_tree().change_scene_to_file("res://scenes/game/game_over.tscn")

func _on_game_over_triggered(_rankings: Array, _didactic_summary: Dictionary, reason: String) -> void:
	if reason == "TEMPO_ESGOTADO" and not is_crashing:
		is_crashing = true
		get_tree().change_scene_to_file("res://scenes/game/game_over.tscn")

func _on_request_assigned(request: Dictionary) -> void:
	label_request_prompt.text = request.get("prompt", "")
	label_request_file.text = "Arquivo: %s | Categoria: %s" % [
		request.get("file_name", ""),
		request.get("category", "")
	]

func _on_delivery_feedback(is_success: bool, message: String, _points: int) -> void:
	label_feedback.text = message
	var target_color = Color("#2ECC71") if is_success else Color("#E74C3C")
	feedback_panel.self_modulate = target_color

	if feedback_tween:
		feedback_tween.kill()

	feedback_tween = create_tween()
	feedback_tween.tween_property(feedback_panel, "modulate:a", 1.0, 0.2)
	feedback_tween.tween_interval(2.5)
	feedback_tween.tween_property(feedback_panel, "modulate:a", 0.0, 0.4)

# --- Gerenciamento de Pop-ups Abusivos (Adware Spam) ---

func _on_popup_triggered(_popup_id: String, count: int) -> void:
	show_popups(count)

func show_popups(count: int = 1) -> void:
	if not popup_spam_container:
		return

	var num = clamp(count, 1, 4)
	for i in range(num):
		var popup = POPUP_WINDOW_SCENE.instantiate() as PopupSpamWindow
		popup.set_variant(randi() % 4)
		# Leve dispersão aleatória para simular janelas de vírus se acumulando na tela
		var offset_pos = Vector2(randf_range(-140.0, 140.0), randf_range(-90.0, 90.0))
		popup.position += offset_pos
		popup.closed.connect(_on_single_popup_closed)
		popup_spam_container.add_child(popup)
		active_popups_count += 1

	GameManager.has_active_popup = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_single_popup_closed() -> void:
	active_popups_count = max(0, active_popups_count - 1)
	if active_popups_count == 0:
		GameManager.has_active_popup = false
		if not GameManager.is_in_game_terminal_open:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

		if NetworkManager.is_connected_to_server:
			NetworkManager.send_packet({
				"type": "C2S_RESOLVE_POPUP",
				"popupId": "all"
			})

# --- Terminal Overlay In-Game (Ativado via ESC) ---

func toggle_in_game_terminal() -> void:
	if is_crashing or not in_game_terminal:
		return

	var will_open = not in_game_terminal.visible
	in_game_terminal.visible = will_open
	GameManager.is_in_game_terminal_open = will_open

	if will_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		terminal_input.clear()
		terminal_input.grab_focus()
		if terminal_output.get_total_character_count() == 0:
			terminal_output.append_text("[color=#00E5FF]============================================================[/color]\n")
			terminal_output.append_text("[color=#00FF66][SISTEMA] TERMINAL DE COMANDO EM JOGO (ESC)[/color]\n")
			terminal_output.append_text("Digite [color=#FFFF00]'exit'[/color] ou [color=#FFFF00]'quit'[/color] para desconectar e sair da sala.\n")
			terminal_output.append_text("Digite [color=#FFFF00]'resume'[/color] ou aperte [color=#FFFF00]ESC[/color] para voltar à partida.\n")
			terminal_output.append_text("Digite [color=#FFFF00]'status'[/color] para conferir telemetria e rede.\n")
			terminal_output.append_text("[color=#00E5FF]============================================================[/color]\n")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_terminal_command_submitted(raw_cmd: String) -> void:
	var cmd = raw_cmd.strip_edges()
	terminal_input.clear()
	terminal_input.call_deferred("grab_focus")

	if cmd == "":
		return

	terminal_output.append_text("[color=#888888]> " + cmd + "[/color]\n")
	var lower = cmd.to_lower()

	match lower:
		"exit", "quit", "leave":
			terminal_output.append_text("[color=#FF5555][DESCONEXÃO] Encerrando sessão e retornando ao terminal principal...[/color]\n")
			in_game_terminal.visible = false
			GameManager.is_in_game_terminal_open = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			NetworkManager.disconnect_from_server()
			GameManager.start_offline_practice()
			get_tree().change_scene_to_file("res://scenes/terminal/terminal_login.tscn")

		"resume", "close":
			toggle_in_game_terminal()

		"help", "?":
			terminal_output.append_text("[color=#00E5FF]COMANDOS DISPONÍVEIS:[/color]\n")
			terminal_output.append_text("  [color=#FFFF00]exit / quit[/color]  - Desconecta da sala e volta ao terminal de login\n")
			terminal_output.append_text("  [color=#FFFF00]resume[/color]       - Fecha o terminal overlay e retoma o jogo\n")
			terminal_output.append_text("  [color=#FFFF00]status[/color]       - Exibe informações da partida e conexão\n")
			terminal_output.append_text("  [color=#FFFF00]clear[/color]        - Limpa o histórico deste terminal\n")

		"status":
			var pin = GameManager.current_room_pin if GameManager.current_room_pin != "" else "OFFLINE"
			var mins = int(GameManager.match_time_remaining) / 60
			var secs = int(GameManager.match_time_remaining) % 60
			var user = GameManager.logged_in_username if GameManager.logged_in_username != "" else "guest"
			terminal_output.append_text("[color=#00FF66]Nó da Sala: %s | Operador: %s[/color]\n" % [pin, user])
			terminal_output.append_text("[color=#00E5FF]Tempo Restante: %02d:%02d | Placar: %d pts | Processos: %d/%d[/color]\n" % [
				mins, secs, GameManager.player_score, GameManager.active_processes_count, GameManager.max_processes_capacity
			])

		"clear", "cls":
			terminal_output.clear()

		_:
			terminal_output.append_text("[color=#FF5555][ERRO] Comando desconhecido: '%s'. Digite 'help' para ajuda.[/color]\n" % cmd)

