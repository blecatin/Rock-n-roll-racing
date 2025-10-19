class_name DriftSystem
extends Node

# Настройки дрифта
@export_group("Drift Settings")
@export var natural_drift_threshold: float = 10.0
@export var drift_strength: float = 0.1
@export var drift_rotation: float = 0.03
@export var drift_speed_loss: float = 0.03
@export var drift_balance: float = 0.8
@export var drift_recovery: float = 0.08

@export_group("Brake Slip Settings")
@export var brake_slip_threshold: float = 200.0
@export var brake_slip_strength: float = 0.04

# Текущее состояние
var rear_wheel_slip: float = 0.0
var brake_slip: float = 0.0
var is_drifting: bool = false

# Сигналы
signal drift_started()
signal drift_ended()

# Ссылки
var movement_system: CarMovement

func initialize(movement_ref: CarMovement) -> void:
	movement_system = movement_ref

func update(delta: float, input: Dictionary) -> void:
	var was_drifting = is_drifting
	
	# Применяем пробуксовку при торможении
	_apply_brake_slip(delta, input.get("brake", false))
	
	# Применяем естественный дрифт
	_apply_natural_drift(delta, input.get("steer", 0.0))
	
	# Проверяем состояние дрифта
	is_drifting = rear_wheel_slip > 0.25 or brake_slip > 0.2
	
	# Отправляем сигналы при изменении состояния
	if is_drifting and not was_drifting:
		drift_started.emit()
	elif not is_drifting and was_drifting:
		drift_ended.emit()

func _apply_brake_slip(delta: float, is_braking: bool) -> void:
	var abs_speed = movement_system.get_abs_speed()
	var steer_angle = movement_system.get_steer_angle()
	
	if is_braking and abs_speed > brake_slip_threshold:
		var brake_intensity = (abs_speed - brake_slip_threshold) / 500.0
		brake_intensity = clamp(brake_intensity, 0.0, 0.5)
		brake_slip = lerp(brake_slip, brake_intensity, 0.15)
		
		if abs(steer_angle) > 0.05:
			var brake_slide = movement_system.get_lateral_vector() * steer_angle * brake_slip * brake_slip_strength * 6.0 * delta
			movement_system.add_lateral_velocity(brake_slide)
			
			# Добавляем вращение при заносе
			var rotation_effect = steer_angle * brake_slip * delta * 0.18
			movement_system.get_parent().rotation += rotation_effect
		
		rear_wheel_slip = clamp(rear_wheel_slip + brake_slip * 0.04, 0.0, 1.0)
	else:
		brake_slip = lerp(brake_slip, 0.0, 0.25)

func _apply_natural_drift(delta: float, steer_input: float) -> void:
	var abs_speed = movement_system.get_abs_speed()
	var min_speed_for_drift = natural_drift_threshold
	var min_turn_for_drift = 0.1
	
	if abs_speed > min_speed_for_drift and abs(steer_input) > min_turn_for_drift:
		var speed_factor = (abs_speed - min_speed_for_drift) / 100.0
		var turn_factor = abs(steer_input)
		var new_slip = speed_factor * turn_factor * 0.45
		
		if movement_system.get_is_braking():
			new_slip *= 1.15
		
		rear_wheel_slip = lerp(rear_wheel_slip, new_slip, 0.22)
		rear_wheel_slip = clamp(rear_wheel_slip, 0.0, 1.0)
		
		var rear_slip = rear_wheel_slip * drift_balance
		var front_slip = rear_wheel_slip * (1.0 - drift_balance)
		
		# Применяем боковые силы
		var lateral_force = movement_system.get_lateral_vector() * steer_input * rear_slip * drift_strength * 6.0 * delta
		lateral_force += movement_system.get_lateral_vector() * steer_input * front_slip * drift_strength * 2.5 * delta
		movement_system.add_lateral_velocity(lateral_force)
		
		# Применяем вращение
		var rotation_effect = (rear_slip - front_slip) * steer_input * drift_rotation * 28.0 * delta
		movement_system.get_parent().rotation += rotation_effect
		
		# Потеря скорости при дрифте
		movement_system.modify_speed(1.0 - rear_wheel_slip * drift_speed_loss * 0.3)
	else:
		rear_wheel_slip = lerp(rear_wheel_slip, 0.0, drift_recovery)

# Публичные геттеры - ДОБАВИЛ НУЖНЫЕ МЕТОДЫ
func get_drift_intensity() -> float:
	return max(rear_wheel_slip, brake_slip)

func get_is_drifting() -> bool:
	return is_drifting

func get_rear_wheel_slip() -> float:
	return rear_wheel_slip

func get_brake_slip() -> float:
	return brake_slip
