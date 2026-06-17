extends Node
## ============================================================
##  Settings  (AUTOLOAD)  —  "Dark Passage"
##  Графіка, гучність (Music/SFX/Master), складність, скидання.
##  Зберігається в user://settings.cfg, застосовується при старті.
##  Підключити як Autoload з ім'ям "Settings".
## ============================================================

const SAVE_PATH := "user://settings.cfg"

# Якість графіки
enum Quality { LOW, MEDIUM, HIGH }

# Значення за замовчуванням
const DEF_VOLUMES := {"Master": 1.0, "Music": 1.0, "SFX": 1.0}
const DEF_DIFFICULTY := 1
const DEF_QUALITY := Quality.HIGH

signal volume_changed(bus: String, linear: float)
signal difficulty_changed(value: int)
signal graphics_changed(quality: int)
signal settings_reset

var _volumes: Dictionary = DEF_VOLUMES.duplicate()
var difficulty: int = DEF_DIFFICULTY
var graphics_quality: int = DEF_QUALITY


func _ready() -> void:
	load_settings()
	_apply_all()


func _apply_all() -> void:
	_apply_all_volumes()
	_apply_graphics()


# ── ГРОМКІСТЬ ─────────────────────────────────────────────────
func set_volume(bus: String, linear: float) -> void:
	apply_volume(bus, linear)
	save_settings()

func apply_volume(bus: String, linear: float) -> void:   # без запису у файл
	linear = clampf(linear, 0.0, 1.0)
	_volumes[bus] = linear
	_set_bus_volume(bus, linear)
	volume_changed.emit(bus, linear)

func get_volume(bus: String) -> float:
	return _volumes.get(bus, 1.0)

func _set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		push_warning("Settings: аудіо-шина '%s' не знайдена." % bus)
		return
	AudioServer.set_bus_mute(idx, linear <= 0.0001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))

func _apply_all_volumes() -> void:
	for bus in _volumes:
		_set_bus_volume(bus, _volumes[bus])


# ── СКЛАДНІСТЬ ────────────────────────────────────────────────
func set_difficulty(value: int) -> void:
	difficulty = clampi(value, 1, 3)
	difficulty_changed.emit(difficulty)
	save_settings()


# ── ГРАФІКА ───────────────────────────────────────────────────
func set_graphics_quality(quality: int) -> void:
	graphics_quality = clampi(quality, 0, 2)
	_apply_graphics()
	save_settings()

func _apply_graphics() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	match graphics_quality:
		Quality.LOW:
			vp.msaa_2d = Viewport.MSAA_DISABLED
		Quality.MEDIUM:
			vp.msaa_2d = Viewport.MSAA_2X
		Quality.HIGH:
			vp.msaa_2d = Viewport.MSAA_4X
	# Підключіть свою логіку (тіні, частинки тощо) через цей сигнал:
	graphics_changed.emit(graphics_quality)


# ── СКИДАННЯ ──────────────────────────────────────────────────
func reset_to_defaults() -> void:
	_volumes = DEF_VOLUMES.duplicate()
	difficulty = DEF_DIFFICULTY
	graphics_quality = DEF_QUALITY
	_apply_all()
	save_settings()
	settings_reset.emit()


# ── ЗБЕРЕЖЕННЯ / ЗАВАНТАЖЕННЯ ─────────────────────────────────
func save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus in _volumes:
		cfg.set_value("audio", bus, _volumes[bus])
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("video", "quality", graphics_quality)
	cfg.save(SAVE_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for bus in _volumes.keys():
		_volumes[bus] = float(cfg.get_value("audio", bus, _volumes[bus]))
	difficulty = clampi(int(cfg.get_value("game", "difficulty", difficulty)), 1, 3)
	graphics_quality = clampi(int(cfg.get_value("video", "quality", graphics_quality)), 0, 2)
