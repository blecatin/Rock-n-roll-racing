class_name GearboxSystem
extends Node

# Настройки коробки передач
@export_group("Gearbox Settings")
@export var max_gear: int = 5
@export var gear_change_cooldown: float = 0.8  # Увеличили для меньшего раздражения
@export var enable_shift_sound: bool = false   # Можно включить если нужно

# Отношения передач (влияют на ускорение)
@export var gear_ratios: Array = [0.0, 0.3, 0.5, 0.7, 0.85, 1.0]
# Пороговые скорости для переключения (px/s)
@export var gear_speeds: Array = [0, 140, 280, 420, 560, 700]

# Текущее состояние
var current_gear: int = 1
var last_gear_change: float = 0.0

# Ссылки
var movement_system: CarMovement
var gear_shift_sound: AudioStreamPlayer2D

func initialize(movement_ref: CarMovement) -> void:
	movement_system = movement_ref
	_setup_sound()

func _setup_sound() -> void:
	if enable_shift_sound:
		gear_shift_sound = AudioStreamPlayer2D.new()
		gear_shift_sound.name = "GearShiftSound"
		gear_shift_sound.stream = load("res://sounds/gear_shift.wav")
		gear_shift_sound.volume_db = -12.0  # Тише чем было
		gear_shift_sound.autoplay = false
		get_parent().add_child(gear_shift_sound)

func update(delta: float) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	var abs_speed = movement_system.get_abs_speed()

	# Проверяем кулдаун
	if now - last_gear_change < gear_change_cooldown:
		return

	# Апшифт - только при достаточной скорости
	if current_gear < max_gear:
		var up_target = gear_speeds[current_gear + 1]
		if abs_speed >= up_target * 0.92:  # Более строгий порог
			_shift_gear(1, now)
			return

	# Дауншифт - с гистерезисом
	if current_gear > 1:
		var down_target = gear_speeds[current_gear] * 0.55  # Нижний порог
		if abs_speed <= down_target:
			_shift_gear(-1, now)
			return

func _shift_gear(direction: int, current_time: float) -> void:
	var new_gear = current_gear + direction
	
	# Проверяем валидность передачи
	if new_gear < 1 or new_gear > max_gear:
		return
	
	current_gear = new_gear
	last_gear_change = current_time
	
	# Воспроизводим звук только если включен и скорость достаточная
	if enable_shift_sound and gear_shift_sound and movement_system.get_abs_speed() > 50.0:
		gear_shift_sound.play()

# Получить текущий множитель передачи
func get_gear_ratio() -> float:
	if current_gear >= 0 and current_gear < gear_ratios.size():
		return gear_ratios[current_gear]
	return 1.0

# Получить текущую максимальную скорость для передачи
func get_gear_max_speed() -> float:
	if current_gear < gear_speeds.size():
		return gear_speeds[current_gear]
	return movement_system.max_speed

# Публичные геттеры
func get_current_gear() -> int:
	return current_gear

func get_gear_progress() -> float:
	var abs_speed = movement_system.get_abs_speed()
	var current_max = get_gear_max_speed()
	if current_max <= 0:
		return 0.0
	return clamp(abs_speed / current_max, 0.0, 1.2)
