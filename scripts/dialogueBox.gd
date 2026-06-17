extends CanvasLayer
## ============================================================
##  DialogueBox  (AUTOLOAD)
##  Простая система диалогов в стиле RPG:
##    [портрет] | Имя
##              | текст с эффектом печатной машинки
##  Фон — фигура (StyleBoxFlat). При желании можно положить
##  картинку: задайте background_texture.
##
##  Подключить как Autoload с именем "DialogueBox".
##
##  ИСПОЛЬЗОВАНИЕ из любого скрипта:
##      DialogueBox.say([
##          {"name": "Незнайомець", "portrait": preload("res://...png"),
##           "text": "Excuse me, how can I get to the Reservoir?"},
##          {"name": "Гравець", "text": "Прямо й наліво."},
##      ])
##      await DialogueBox.finished
##
##  Продвижение: клик мышью / тап / ui_accept.
##  Если текст ещё печатается — первый клик показывает его целиком.
## ============================================================

signal line_shown(index: int)
signal finished

@export var chars_per_second: float = 45.0
## Останавливать игровое время на время диалога (удобно для RPG).
@export var pause_while_active: bool = true
## Необязательная картинка-фон вместо фигуры (NinePatch).
@export var background_texture: Texture2D

const _BOX_HEIGHT := 150
const _PORTRAIT := 110
const _PAD := 18

var _root: Control
var _bg_shape: Panel
var _bg_image: NinePatchRect
var _portrait_rect: TextureRect
var _name_label: Label
var _text_label: RichTextLabel
var _next_hint: Label

var _lines: Array = []
var _index: int = -1
var _typing: bool = false
var _shown_chars: float = 0.0
var _active: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS  # работает даже на паузе
	_build_ui()
	_hide()


# ============================================================
#  ПУБЛИЧНОЕ API
# ============================================================
func say(lines: Array) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_index = -1
	_active = true
	_root.visible = true
	if pause_while_active:
		get_tree().paused = true
	set_process(true)
	set_process_unhandled_input(true)
	_advance()


func is_active() -> bool:
	return _active


# ============================================================
#  ВНУТРЕННЕЕ
# ============================================================
func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Фон-фигура
	_bg_shape = Panel.new()
	_anchor_box(_bg_shape)
	_bg_shape.add_theme_stylebox_override("panel", _make_box_style())
	_root.add_child(_bg_shape)

	# Фон-картинка (если задана)
	if background_texture:
		_bg_image = NinePatchRect.new()
		_anchor_box(_bg_image)
		_bg_image.texture = background_texture
		_root.add_child(_bg_image)
		_bg_shape.visible = false

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = _PAD
	hbox.offset_top = _PAD
	hbox.offset_right = -_PAD
	hbox.offset_bottom = -_PAD
	hbox.add_theme_constant_override("separation", _PAD)
	_bg_shape.add_child(hbox)

	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(_PORTRAIT, _PORTRAIT)
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # для пиксель-арта
	hbox.add_child(_portrait_rect)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vbox.add_child(_name_label)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.scroll_active = false
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("normal_font_size", 20)
	vbox.add_child(_text_label)

	# Мигающая стрелка "далее"
	_next_hint = Label.new()
	_next_hint.text = "▼"
	_next_hint.add_theme_font_size_override("font_size", 20)
	_next_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_next_hint.offset_left = -34
	_next_hint.offset_top = -34
	_bg_shape.add_child(_next_hint)
	_blink_hint()


func _anchor_box(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	c.offset_left = _PAD
	c.offset_right = -_PAD
	c.offset_top = -_BOX_HEIGHT - _PAD
	c.offset_bottom = -_PAD


func _make_box_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.92)
	sb.border_color = Color(0.9, 0.9, 1.0, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(_PAD)
	return sb


func _blink_hint() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(_next_hint, "modulate:a", 0.1, 0.5)
	tw.tween_property(_next_hint, "modulate:a", 1.0, 0.5)


func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		_finish()
		return
	_show_line(_lines[_index] as Dictionary)


func _show_line(line: Dictionary) -> void:
	_name_label.text = String(line.get("name", ""))

	var portrait: Variant = line.get("portrait", null)
	if portrait is String:
		portrait = load(portrait)
	_portrait_rect.texture = portrait as Texture2D
	_portrait_rect.visible = _portrait_rect.texture != null

	_text_label.text = String(line.get("text", ""))
	_text_label.visible_characters = 0
	_shown_chars = 0.0
	_typing = true
	_next_hint.visible = false
	line_shown.emit(_index)


func _process(delta: float) -> void:
	if not _typing:
		return
	_shown_chars += chars_per_second * delta
	var total := _text_label.get_total_character_count()
	if _shown_chars >= total:
		_reveal_all()
	else:
		_text_label.visible_characters = int(_shown_chars)


func _reveal_all() -> void:
	_text_label.visible_characters = -1
	_typing = false
	_next_hint.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	var pressed := false
	if event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event.is_action_pressed("ui_accept"):
		pressed = true

	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_reveal_all()
	else:
		_advance()


func _finish() -> void:
	_active = false
	_hide()
	if pause_while_active:
		get_tree().paused = false
	finished.emit()


func _hide() -> void:
	_root.visible = false
	set_process(false)
	set_process_unhandled_input(false)
