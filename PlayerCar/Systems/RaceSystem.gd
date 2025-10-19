class_name RaceSystem
extends Node

# Настройки гонки
@export_group("Race Settings")
@export var total_laps: int = 3
@export var enable_lap_timing: bool = true

# Состояние гонки
var current_lap: int = 1
var lap_times: Array = []
var current_lap_start_time: float = 0.0
var race_start_time: float = 0.0
var best_lap_time: float = 99999.0
var can_detect_finish: bool = true

# Сигналы
signal lap_completed(lap_number: int, lap_time: float, best_lap: bool)
signal race_finished(total_time: float, best_lap: float)

# Ссылки
var finish_line: Area2D

func initialize() -> void:
	race_start_time = Time.get_ticks_msec() / 1000.0
	current_lap_start_time = race_start_time
	
	# Ищем финишную линию
	_find_finish_line()

func _find_finish_line() -> void:
	var parent = get_parent().get_parent()
	if parent and parent.has_node("FinishLine"):
		finish_line = parent.get_node("FinishLine")
		if finish_line and finish_line.has_signal("body_entered"):
			finish_line.body_entered.connect(_on_finish_line_entered)

func update(delta: float) -> void:
	# Обновление времени гонки (если нужно)
	pass

func _on_finish_line_entered(body: Node) -> void:
	if body == get_parent().get_parent() and can_detect_finish:  # PlayerCar нод
		complete_lap()
		can_detect_finish = false
		
		# Задержка перед следующим обнаружением
		await get_tree().create_timer(3.0).timeout
		can_detect_finish = true

func complete_lap() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	var lap_time = now - current_lap_start_time
	
	lap_times.append(lap_time)
	
	var is_best_lap = false
	if lap_time < best_lap_time:
		best_lap_time = lap_time
		is_best_lap = true
	
	# Округляем для отображения
	var rounded_time = snapped(lap_time, 0.01)
	
	# Отправляем сигнал
	lap_completed.emit(current_lap, rounded_time, is_best_lap)
	
	current_lap += 1
	current_lap_start_time = now
	
	# Проверяем завершение гонки
	if current_lap > total_laps:
		_finish_race()

func _finish_race() -> void:
	var total_time = Time.get_ticks_msec() / 1000.0 - race_start_time
	race_finished.emit(total_time, best_lap_time)

func get_current_lap_time() -> float:
	return Time.get_ticks_msec() / 1000.0 - current_lap_start_time

func get_total_time() -> float:
	return Time.get_ticks_msec() / 1000.0 - race_start_time

func format_time(seconds: float) -> String:
	var minutes = int(seconds) / 60
	var secs = int(seconds) % 60
	var ms = int((seconds - int(seconds)) * 100)
	return "%02d:%02d.%02d" % [minutes, secs, ms]

# Публичные геттеры
func get_current_lap() -> int:
	return current_lap

func get_total_laps() -> int:
	return total_laps

func get_best_lap_time() -> float:
	return best_lap_time

func get_lap_times() -> Array:
	return lap_times.duplicate()
