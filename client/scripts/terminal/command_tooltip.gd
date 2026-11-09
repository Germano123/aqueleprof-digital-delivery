extends PanelContainer

## DIGITAL DELIVERY - Command Tooltip
## Painel flutuante no canto superior direito que exibe o nome e descrição
## de cada comando digitado no terminal. Aparece com fade e some após 2.5s.

@onready var title_label: Label = $VBox/TitleLabel
@onready var desc_label: Label = $VBox/DescLabel

var _hide_tween: Tween = null
var _show_tween: Tween = null

func _ready() -> void:
	modulate.a = 0.0
	visible = true

func show_tooltip(title: String, description: String) -> void:
	title_label.text = title
	desc_label.text = description

	# Cancela tweens anteriores
	if _hide_tween and _hide_tween.is_valid():
		_hide_tween.kill()
	if _show_tween and _show_tween.is_valid():
		_show_tween.kill()

	# Fade in
	_show_tween = create_tween()
	_show_tween.tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_show_tween.finished.connect(_schedule_hide, CONNECT_ONE_SHOT)

func _schedule_hide() -> void:
	_hide_tween = create_tween()
	_hide_tween.tween_interval(2.1)
	_hide_tween.tween_property(self, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
