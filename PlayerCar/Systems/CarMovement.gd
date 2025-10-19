class_name CarMovement
extends Node

# Параметры движения
@export_group("Movement Settings")
@export var max_speed: float = 900.0
@export var acceleration: float = 300.0
@export var friction: float = 60.0
@export var brake_power: float = 200.0
@export var brake_in_turn_factor: float = 0.45
@export var rotation_speed: float = 3.5

@export_group("Stability Settings") 
@export var lateral_damping: float = 300.0
@export var max_lateral_speed: float = 180.0

# Текущее состояние
var speed: float = 0.0
var steer_angle: float = 0.0
var current_turn: float = 0.0
var lateral_velocity: Vector2 = Vector2.ZERO
var is_braking: bool = false

# Ссылки
var car_node: CharacterBody2D

func initialize(car: CharacterBody2D) -> void:
	car_node = car

func update(delta: float, input: Dictionary) -> void:
	_handle_steering(delta, input.get("steer", 0.0))
	_handle_throttle_brake(delta, input.get("throttle", false), input.get("brake", false))
	_apply_lateral_forces(delta)

func _handle_steering(delta: float, steer_input: float) -> void:
	# Плавный руль
	steer_angle = lerp(steer_angle, steer_input, 6.0 * delta)
	current_turn = steer_angle * rotation_speed

func _handle_throttle_brake(delta: float, throttle: bool, brake: bool) -> void:
	is_braking = false
	
	if throttle:
		# Ускорение
		speed = move_toward(speed, max_speed, acceleration * delta)
	elif brake:
		# Торможение
		is_braking = true
		var turn_factor = clamp(abs(steer_angle), 0.0, 1.0)
		var brake_factor = lerp(1.0, brake_in_turn_factor, turn_factor)
		var target_speed = -max_speed * 0.4
		speed = move_toward(speed, target_speed, brake_power * brake_factor * delta)
	else:
		# Engine braking
		var engine_brake = 80.0
		if abs(speed) > 1.0:
			if speed > 0:
				speed = max(0, speed - engine_brake * delta)
			else:
				speed = min(0, speed + engine_brake * delta)
		else:
			speed = move_toward(speed, 0.0, friction * delta)
	
	# Потеря скорости при рулении
	var turn_loss = abs(steer_angle) * 0.012
	if turn_loss > 0.0 and abs(speed) > 50.0:
		speed *= (1.0 - turn_loss * delta)

func _apply_lateral_forces(delta: float) -> void:
	# Ограничение и гашение боковой скорости
	if lateral_velocity.length() > max_lateral_speed:
		lateral_velocity = lateral_velocity.normalized() * max_lateral_speed
	lateral_velocity = lateral_velocity.move_toward(Vector2.ZERO, lateral_damping * delta)

func get_final_velocity() -> Vector2:
	var forward_vec = car_node.transform.x.normalized() * speed
	return forward_vec + lateral_velocity

func get_final_rotation(delta: float) -> float:  # ДОБАВИЛ delta КАК ПАРАМЕТР
	var new_rotation = car_node.rotation
	
	if abs(speed) > 30.0:
		var turn_power = current_turn * (abs(speed) / max_speed) * delta
		var max_turn_delta = 0.12
		new_rotation += clamp(turn_power, -max_turn_delta, max_turn_delta)
	
	return new_rotation

# Публичные геттеры
func get_speed() -> float:
	return speed

func get_abs_speed() -> float:
	return abs(speed)

func get_steer_angle() -> float:
	return steer_angle

func get_is_braking() -> bool:
	return is_braking

func get_forward_vector() -> Vector2:
	return car_node.transform.x.normalized()

func get_lateral_vector() -> Vector2:
	return car_node.transform.y.normalized()

func add_lateral_velocity(velocity: Vector2) -> void:
	lateral_velocity += velocity

func modify_speed(factor: float) -> void:
	speed *= factor
