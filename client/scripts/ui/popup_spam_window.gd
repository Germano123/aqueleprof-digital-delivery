extends Control
class_name PopupSpamWindow

## DIGITAL DELIVERY - Janela de Popup / Adware Abusivo
## Exibe a arte oficial do popups.glb (dividida em 4 quadrantes 2x2).
## O jogador deve clicar no botão [X] para fechar a guia e liberar o movimento.

signal closed()

const TEXTURE_POPUPS = preload("res://models/popups/popups_popups-texture.png")

# Quadrantes 2x2 do atlas de 1254x1254 (pop-up.a, b, c, d)
const QUADRANT_RECTS = [
	Rect2(0, 0, 627, 627),       # pop-up.a (Superior Esquerdo)
	Rect2(627, 0, 627, 627),     # pop-up.b (Superior Direito)
	Rect2(0, 627, 627, 627),     # pop-up.c (Inferior Esquerdo)
	Rect2(627, 627, 627, 627)    # pop-up.d (Inferior Direito)
]

@onready var texture_display: TextureRect = $CardPanel/VBox/ImageFrame/TextureDisplay
@onready var btn_close: Button = $CardPanel/VBox/HeaderBar/HBox/BtnClose
@onready var card_panel: PanelContainer = $CardPanel
@onready var label_title: Label = $CardPanel/VBox/HeaderBar/HBox/LabelTitle

var popup_index: int = 0
var is_closing: bool = false

func _ready() -> void:
	if btn_close:
		btn_close.pressed.connect(_on_close_pressed)

	_setup_popup_texture()
	_play_spawn_animation()

func set_variant(variant_idx: int) -> void:
	popup_index = clamp(variant_idx, 0, QUADRANT_RECTS.size() - 1)
	if is_inside_tree():
		_setup_popup_texture()

func _setup_popup_texture() -> void:
	if not texture_display or not TEXTURE_POPUPS:
		return

	var atlas = AtlasTexture.new()
	atlas.atlas = TEXTURE_POPUPS
	atlas.region = QUADRANT_RECTS[popup_index]
	texture_display.texture = atlas

	var titles = [
		"🚨 ALERTA: 37 PROCESSOS SUSPEITOS!",
		"⚡ ATENÇÃO: ACELERE SUA MEMÓRIA RAM!",
		"⚠️ CRÍTICO: FALHA DE BUFFER DETECTADA!",
		"🎁 PARABÉNS: VOCÊ É O VISITANTE 1.000.000!"
	]
	if label_title:
		label_title.text = titles[popup_index % titles.size()]

func _play_spawn_animation() -> void:
	# Efeito de janela pop-up surgindo na tela com escala de 0 para 1
	pivot_offset = size / 2.0
	scale = Vector2(0.3, 0.3)
	modulate.a = 0.0

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)

func _on_close_pressed() -> void:
	if is_closing:
		return
	is_closing = true

	# Animação rápida de fechamento
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.finished.connect(func():
		closed.emit()
		queue_free()
	)
