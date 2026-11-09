extends Control

## DIGITAL DELIVERY - Tela de Game Over e Tabela de Vitoriosos
## Ref: Seções 5, 8 e 15 do GDD.md
## Exibe motivo do crash/fim, pódio dos 3 primeiros, tabela completa e retorno ao terminal

@onready var label_header_title: Label = $MarginContainer/VBoxMain/HeaderBox/LabelHeaderTitle
@onready var label_header_sub: Label = $MarginContainer/VBoxMain/HeaderBox/LabelHeaderSub

# Pódio (Top 3)
@onready var card_gold: PanelContainer = $MarginContainer/VBoxMain/PodiumContainer/CardGold
@onready var label_gold_name: Label = $MarginContainer/VBoxMain/PodiumContainer/CardGold/VBox/LabelName
@onready var label_gold_score: Label = $MarginContainer/VBoxMain/PodiumContainer/CardGold/VBox/LabelScore
@onready var label_gold_stats: Label = $MarginContainer/VBoxMain/PodiumContainer/CardGold/VBox/LabelStats

@onready var card_silver: PanelContainer = $MarginContainer/VBoxMain/PodiumContainer/CardSilver
@onready var label_silver_name: Label = $MarginContainer/VBoxMain/PodiumContainer/CardSilver/VBox/LabelName
@onready var label_silver_score: Label = $MarginContainer/VBoxMain/PodiumContainer/CardSilver/VBox/LabelScore
@onready var label_silver_stats: Label = $MarginContainer/VBoxMain/PodiumContainer/CardSilver/VBox/LabelStats

@onready var card_bronze: PanelContainer = $MarginContainer/VBoxMain/PodiumContainer/CardBronze
@onready var label_bronze_name: Label = $MarginContainer/VBoxMain/PodiumContainer/CardBronze/VBox/LabelName
@onready var label_bronze_score: Label = $MarginContainer/VBoxMain/PodiumContainer/CardBronze/VBox/LabelScore
@onready var label_bronze_stats: Label = $MarginContainer/VBoxMain/PodiumContainer/CardBronze/VBox/LabelStats

# Tabela dos demais colocados (4º em diante)
@onready var remaining_table_container: VBoxContainer = $MarginContainer/VBoxMain/TableCard/ScrollContainer/VBoxRows
@onready var label_empty_table: Label = $MarginContainer/VBoxMain/TableCard/ScrollContainer/VBoxRows/LabelEmptyTable

# Resumo Pedagógico e Botão
@onready var label_didactic: Label = $MarginContainer/VBoxMain/FooterBox/LabelDidactic
@onready var btn_return_terminal: Button = $MarginContainer/VBoxMain/FooterBox/CenterBtn/BtnReturnTerminal

func _ready() -> void:
	btn_return_terminal.pressed.connect(_on_return_terminal_pressed)
	btn_return_terminal.grab_focus()

	_populate_game_over_data()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_return_terminal_pressed()

func _populate_game_over_data() -> void:
	# 1. Cabeçalho de Crash ou Fim de Tempo
	if GameManager.is_crashed:
		label_header_title.text = "💥 SISTEMA DESLIGADO INESPERADAMENTE (KERNEL PANIC)"
		label_header_title.modulate = Color("#E74C3C")
		label_header_sub.text = "O processador atingiu sobrecarga fatal por excesso de processos não entregues a tempo."
	else:
		label_header_title.text = "🏁 OPERAÇÃO CONCLUÍDA COM SUCESSO"
		label_header_title.modulate = Color("#2ECC71")
		label_header_sub.text = "O tempo da partida encerrou. Relatório de eficiência do computador compilado abaixo."

	# 2. Rankings
	var rankings = GameManager.final_rankings
	if rankings.is_empty():
		rankings = GameManager.generate_offline_rankings()

	# Pódio: 1º Lugar (Ouro)
	if rankings.size() > 0:
		var r1 = rankings[0]
		label_gold_name.text = str(r1.get("username", "Operador 1"))
		label_gold_score.text = "%d PTS" % r1.get("score", 0)
		label_gold_stats.text = "%d corretas | %d erros" % [r1.get("correctDeliveries", 0), r1.get("failedDeliveries", 0)]
		if r1.get("is_local_player", false):
			label_gold_name.text += " (VOCÊ)"
			card_gold.modulate = Color(1.2, 1.2, 1.0)
	else:
		card_gold.visible = false

	# Pódio: 2º Lugar (Prata)
	if rankings.size() > 1:
		var r2 = rankings[1]
		label_silver_name.text = str(r2.get("username", "Operador 2"))
		label_silver_score.text = "%d PTS" % r2.get("score", 0)
		label_silver_stats.text = "%d corretas" % r2.get("correctDeliveries", 0)
		if r2.get("is_local_player", false):
			label_silver_name.text += " (VOCÊ)"
			card_silver.modulate = Color(1.0, 1.2, 1.2)
	else:
		card_silver.visible = false

	# Pódio: 3º Lugar (Bronze)
	if rankings.size() > 2:
		var r3 = rankings[2]
		label_bronze_name.text = str(r3.get("username", "Operador 3"))
		label_bronze_score.text = "%d PTS" % r3.get("score", 0)
		label_bronze_stats.text = "%d corretas" % r3.get("correctDeliveries", 0)
		if r3.get("is_local_player", false):
			label_bronze_name.text += " (VOCÊ)"
			card_bronze.modulate = Color(1.2, 1.1, 1.0)
	else:
		card_bronze.visible = false

	# 3. Tabela de 4º Lugar em Diante
	var has_remaining = false
	if rankings.size() > 3:
		label_empty_table.visible = false
		for i in range(3, rankings.size()):
			has_remaining = true
			var r = rankings[i]
			var row = _create_ranking_row(i + 1, r)
			remaining_table_container.add_child(row)

	if not has_remaining:
		label_empty_table.visible = true
		label_empty_table.text = "Sem outros jogadores nesta sessão."

	# 4. Resumo Pedagógico
	var summary = GameManager.final_didactic_summary
	var acc = summary.get("accuracyPercentage", 100)
	var tot = summary.get("totalDeliveries", GameManager.correct_deliveries + GameManager.failed_deliveries)
	var best = summary.get("bestCategory", "Documentos")
	label_didactic.text = "📚 ESTATÍSTICAS DA SESSÃO // Entregas Avaliadas: %d | Precisão Geral: %d%% | Categoria de Maior Domínio: %s" % [tot, acc, best]

func _create_ranking_row(pos: int, data: Dictionary) -> Control:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 32)
	hbox.theme_override_constants.separation = 16

	var is_me = data.get("is_local_player", false) or data.get("username", "") == GameManager.logged_in_username

	var pos_lbl = Label.new()
	pos_lbl.text = "#%02d" % pos
	pos_lbl.custom_minimum_size = Vector2(50, 0)
	pos_lbl.theme_override_colors.font_color = Color("#7F8C8D")
	hbox.add_child(pos_lbl)

	var name_lbl = Label.new()
	name_lbl.text = str(data.get("username", "Operador"))
	if is_me:
		name_lbl.text += " (VOCÊ)"
		name_lbl.theme_override_colors.font_color = Color("#00FFFF")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)

	var deliveries_lbl = Label.new()
	deliveries_lbl.text = "%d entregas" % data.get("correctDeliveries", 0)
	deliveries_lbl.custom_minimum_size = Vector2(120, 0)
	deliveries_lbl.theme_override_colors.font_color = Color("#BDC3C7")
	hbox.add_child(deliveries_lbl)

	var score_lbl = Label.new()
	score_lbl.text = "%d pts" % data.get("score", 0)
	score_lbl.custom_minimum_size = Vector2(90, 0)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_lbl.theme_override_colors.font_color = Color("#F1C40F") if not is_me else Color("#00FFFF")
	hbox.add_child(score_lbl)

	return hbox

func _on_return_terminal_pressed() -> void:
	# Desconecta de qualquer sala online e reinicia para o terminal
	NetworkManager.disconnect_from_server()
	GameManager.start_offline_practice()
	get_tree().change_scene_to_file("res://scenes/terminal/terminal_login.tscn")
