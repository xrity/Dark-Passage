extends Control
## ============================================================
##  Settings  (контролер меню "Dark Passage")
##  Шукає вузли за ПРЯМИМИ шляхами вашої сцени Settings.tscn —
##  нічого позначати як Unique Name не треба.
## ============================================================

const CONTROLS_TEXT := \
"[b]Рух[/b] — WASD\n" + \
"W — вгору   S — вниз   A — ліворуч   D — праворуч\n" + \
"W+A — ліворуч-вгору   W+D — праворуч-вгору\n" + \
"S+A — ліворуч-вниз   S+D — праворуч-вниз\n" + \
"[b]Стрибок[/b] — Space\n" + \
"[b]Атака / Взаємодія[/b] — E / ЛКМ\n" + \
"[b]Пауза[/b] — Esc"

@onready var _music: HSlider          = get_node_or_null("Background/VBoxContainer/MusicSlider")
@onready var _sfx: HSlider            = get_node_or_null("Background/VBoxContainer/SFXSlider")
@onready var _difficulty: OptionButton = get_node_or_null("Background/VBoxContainer/DifficultyButton")
@onready var _graphics: OptionButton   = get_node_or_null("Background/VBoxContainer/GraphicsButton")
@onready var _controls: RichTextLabel  = get_node_or_null("Background/VBoxContainer/ControlsLabel")
@onready var _reset_btn: Button        = get_node_or_null("Background/VBoxContainer/ResetButton")
@onready var _back: Node               = get_node_or_null("BackButton")


func _ready() -> void:
	# Управління (статичний довідник)
	if _controls:
		_controls.bbcode_enabled = true
		_controls.text = CONTROLS_TEXT

	# Звук
	_setup_slider(_music, "Music")
	_setup_slider(_sfx, "SFX")

	# Випадаючі списки (із захистом від подвійного підключення)
	_connect_option(_graphics, _on_graphics_item_selected)
	_connect_option(_difficulty, _on_difficulty_button_item_selected)

	# Скидання
	if _reset_btn and not _reset_btn.pressed.is_connected(_on_reset):
		_reset_btn.pressed.connect(_on_reset)

	# Назад
	_connect_back()

	_sync_ui()


# ── Підключення ───────────────────────────────────────────────
func _setup_slider(slider: HSlider, bus: String) -> void:
	if not slider:
		return
	slider.min_value = 0.0
	slider.max_value = 1.0
	if not slider.value_changed.is_connected(_on_slider_changed):
		slider.value_changed.connect(_on_slider_changed.bind(bus))
	if not slider.drag_ended.is_connected(_on_slider_drag_ended):
		slider.drag_ended.connect(_on_slider_drag_ended)


func _connect_option(btn: OptionButton, callable: Callable) -> void:
	if btn and not btn.item_selected.is_connected(callable):
		btn.item_selected.connect(callable)


func _connect_back() -> void:
	if _back == null:
		return
	var btn := _find_button(_back)
	if btn and not btn.pressed.is_connected(_close):
		btn.pressed.connect(_close)


# ── Обробники ─────────────────────────────────────────────────
func _on_slider_changed(value: float, bus: String) -> void:
	Settings.apply_volume(bus, value)        # живий звук

func _on_slider_drag_ended(_changed: bool) -> void:
	Settings.save_settings()                 # запис при відпусканні

func _on_graphics_item_selected(index: int) -> void:
	Settings.set_graphics_quality(index)     # 0=low 1=medium 2=high

func _on_difficulty_button_item_selected(index: int) -> void:
	Settings.set_difficulty(index + 1)       # 0/1/2 → 1/2/3

func _on_reset() -> void:
	Settings.reset_to_defaults()
	_sync_ui()


# ── Синхронізація UI ──────────────────────────────────────────
func _sync_ui() -> void:
	if _music:
		_music.set_value_no_signal(Settings.get_volume("Music"))
	if _sfx:
		_sfx.set_value_no_signal(Settings.get_volume("SFX"))
	if _graphics:
		_graphics.select(Settings.graphics_quality)
	if _difficulty:
		_difficulty.select(Settings.difficulty - 1)


# ── Закриття ──────────────────────────────────────────────────
func _close() -> void:
	queue_free()

func _exit_tree() -> void:
	Settings.save_settings()


# ── Допоміжне ─────────────────────────────────────────────────
func _find_button(node: Node) -> BaseButton:
	if node is BaseButton:
		return node
	for child in node.get_children():
		var found := _find_button(child)
		if found:
			return found
	return null
