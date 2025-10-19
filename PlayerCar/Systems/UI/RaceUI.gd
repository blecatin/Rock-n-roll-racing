class_name RaceUI
extends Control

# UI элементы
var speed_label: Label
var lap_label: Label
var gear_label: Label
var message_label: Label
var lap_time_label: Label
var best_time_label: Label

# Таймеры
var message_timer: Timer

# Ссылки
var movement_system: CarMovement
var gearbox_system: GearboxSystem
var race_system: RaceSystem

func initialize(movement_ref: CarMovement, gearbox_ref: GearboxSystem, race_ref: RaceSystem) -> void:
	movement_system = movement_ref
	gearbox_system = gearbox_ref
	race_system = race_ref
	
	_setup_ui()
	_setup_timers()

func _setup_ui() -> void:
	# Создаем все UI элементы если их нет
	_create_ui_elements()
	
	# Теперь безопасно получаем ссылки
	speed_label = $SpeedLabel
	lap_label = $LapLabel
	gear_label = $GearLabel
	message_label = $MessageLabel
	lap_time_label = $LapTimeLabel
	best_time_label = $BestTimeLabel

func _create_ui_elements() -> void:
	# Создаем базовые UI элементы если их нет в сцене
	
	# Speed Label
	if not has_node("SpeedLabel"):
		speed_label = Label.new()
		speed_label.name = "SpeedLabel"
		speed_label.position = Vector2(18, 14)
		speed_label.add_theme_font_size_override("font_size", 20)
		add_child(speed_label)

	# Lap Label
	if not has_node("LapLabel"):
		lap_label = Label.new()
		lap_label.name = "LapLabel"
		lap_label.position = Vector2(18, 44)
		lap_label.add_theme_font_size_override("font_size", 20)
		add_child(lap_label)

	# Gear Label
	if not has_node("GearLabel"):
		gear_label = Label.new()
		gear_label.name = "GearLabel"
		gear_label.position = Vector2(18, 74)
		gear_label.add_theme_font_size_override("font_size", 20)
		add_child(gear_label)

	# Message Label
	if not has_node("MessageLabel"):
		message_label = Label.new()
		message_label.name = "MessageLabel"
		message_label.position = Vector2(400, 200)
		message_label.size = Vector2(200, 50)
		message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		message_label.add_theme_font_size_override("font_size", 24)
		message_label.visible = false
		add_child(message_label)

	# Lap Time Label
	if not has_node("LapTimeLabel"):
		lap_time_label = Label.new()
		lap_time_label.name = "LapTimeLabel"
		lap_time_label.position = Vector2(18, 104)
		lap_time_label.add_theme_font_size_override("font_size", 16)
		add_child(lap_time_label)

	# Best Time Label
	if not has_node("BestTimeLabel"):
		best_time_label = Label.new()
		best_time_label.name = "BestTimeLabel"
		best_time_label.position = Vector2(18, 134)
		best_time_label.add_theme_font_size_override("font_size", 16)
		add_child(best_time_label)

func _setup_timers() -> void:
	message_timer = Timer.new()
	message_timer.name = "MessageTimer"
	message_timer.one_shot = true
	add_child(message_timer)
	message_timer.timeout.connect(_on_message_timer_timeout)

func update(delta: float) -> void:
	if not movement_system or not gearbox_system or not race_system:
		return
		
	_update_speed_display()
	_update_lap_display()
	_update_gear_display()
	_update_time_displays()

func _update_speed_display() -> void:
	if speed_label and movement_system:
		var kmh = int(movement_system.get_abs_speed() * 0.36)
		speed_label.text = "SPEED: %d km/h" % kmh

func _update_lap_display() -> void:
	if lap_label and race_system:
		lap_label.text = "LAP: %d/%d" % [race_system.get_current_lap(), race_system.get_total_laps()]

func _update_gear_display() -> void:
	if gear_label and gearbox_system:
		gear_label.text = "GEAR: %d" % gearbox_system.get_current_gear()

func _update_time_displays() -> void:
	if lap_time_label and race_system:
		var current_lap_time = race_system.get_current_lap_time()
		lap_time_label.text = "LAP: %s" % race_system.format_time(current_lap_time)
	
	if best_time_label and race_system:
		var best_time = race_system.get_best_lap_time()
		if best_time < 99999.0:
			best_time_label.text = "BEST: %s" % race_system.format_time(best_time)
		else:
			best_time_label.text = "BEST: --:--.--"

func show_message(text: String, duration: float = 3.0) -> void:
	if message_label:
		message_label.text = text
		message_label.visible = true
		if message_timer:
			message_timer.start(duration)

func _on_message_timer_timeout() -> void:
	if message_label:
		message_label.visible = false

func _on_lap_completed(lap_number: int, lap_time: float, is_best_lap: bool) -> void:
	var message = "LAP %d - %s" % [lap_number, race_system.format_time(lap_time)]
	if is_best_lap:
		message += " - BEST LAP!"
	show_message(message, 4.0)

func _on_race_finished(total_time: float, best_lap: float) -> void:
	var message = "RACE FINISHED!\nTotal: %s\nBest Lap: %s" % [
		race_system.format_time(total_time),
		race_system.format_time(best_lap)
	]
	show_message(message, 8.0)
