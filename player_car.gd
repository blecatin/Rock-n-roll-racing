extends CharacterBody2D

# ===== ПАРАМЕТРЫ ДВИЖЕНИЯ =====
var speed = 0.0
var max_speed = 900.0
var acceleration = 300.0
var friction = 60.0
var brake_power = 200.0
var brake_in_turn_factor = 0.45
var rotation_speed = 3.5

# ===== ДРИФТ =====
var natural_drift_threshold = 10.0
var drift_strength = 0.1
var drift_rotation = 0.03
var drift_speed_loss = 0.03

# ===== ПРОБУКСОВКА =====
var rear_wheel_slip = 0.0
var drift_balance = 0.8
var drift_recovery = 0.08

var is_braking = false
var brake_slip = 0.0
var brake_slip_threshold = 200.0
var brake_slip_strength = 0.04

# ===== СТАБИЛЬНОСТЬ БОКОВОЙ СКОРОСТИ =====
var lateral_damping = 300.0
var max_lateral_speed = 180.0

# ===== ПОВОРОТ РУЛЯ =====
var turn_input = 0.0
var steer_angle = 0.0
var current_turn = 0.0

# ===== ЭФФЕКТЫ ДРИФТА =====
var drift_smoke_effect: PackedScene = load("res://drift_smoke.tscn")


var smoke_particles: Array = []
var tire_smoke_timer = 0.0

func _physics_process(delta):
	# стандартное управление (как в твоём коде)
	turn_input = 0.0
	if Input.is_action_pressed("ui_right"):
		turn_input += 1.0
	if Input.is_action_pressed("ui_left"):
		turn_input -= 1.0

	steer_angle = lerp(steer_angle, turn_input, 5.0 * delta)
	current_turn = steer_angle * rotation_speed

	is_braking = false
	if Input.is_action_pressed("ui_up"):
		speed = move_toward(speed, max_speed, acceleration * delta)
	elif Input.is_action_pressed("ui_down"):
		is_braking = true
		var turn_factor = clamp(abs(steer_angle), 0.0, 1.0)
		var brake_factor = lerp(1.0, brake_in_turn_factor, turn_factor)
		var target_speed = -max_speed * 0.5
		speed = move_toward(speed, target_speed, brake_power * brake_factor * delta)

	var turn_loss = abs(steer_angle) * 0.015
	if turn_loss > 0.0 and abs(speed) > 50.0:
		speed *= (1.0 - turn_loss * delta)

	var forward_vec = transform.x.normalized() * speed
	var lateral_vec = velocity - velocity.project(transform.x)
	lateral_vec = apply_advanced_drift(delta, lateral_vec)
	lateral_vec = apply_brake_slip(delta, lateral_vec)

	if lateral_vec.length() > max_lateral_speed:
		lateral_vec = lateral_vec.normalized() * max_lateral_speed
	lateral_vec = lateral_vec.move_toward(Vector2.ZERO, lateral_damping * delta)
	velocity = forward_vec + lateral_vec

	if abs(speed) > 30.0:
		var turn_power = current_turn * (abs(speed) / max_speed) * delta
		var max_turn_delta = 0.12
		rotation += clamp(turn_power, -max_turn_delta, max_turn_delta)

	# спавним дым
	update_drift_smoke(delta)

	move_and_slide()

func apply_brake_slip(delta, lateral_vec):
	if is_braking and abs(speed) > brake_slip_threshold:
		var brake_intensity = (abs(speed) - brake_slip_threshold) / 500.0
		brake_intensity = clamp(brake_intensity, 0.0, 0.5)
		brake_slip = lerp(brake_slip, brake_intensity, 0.15)
		if abs(steer_angle) > 0.05:
			var brake_slide = transform.y * steer_angle * brake_slip * brake_slip_strength * 6.0 * delta
			lateral_vec += brake_slide
			rotation += steer_angle * brake_slip * delta * 0.18
		rear_wheel_slip = clamp(rear_wheel_slip + brake_slip * 0.04, 0.0, 1.0)
	else:
		brake_slip = lerp(brake_slip, 0.0, 0.25)
	return lateral_vec

func apply_advanced_drift(delta, lateral_vec):
	var min_speed_for_drift = natural_drift_threshold
	var min_turn_for_drift = 0.1
	if abs(speed) > min_speed_for_drift and abs(steer_angle) > min_turn_for_drift:
		var speed_factor = (abs(speed) - min_speed_for_drift) / 100.0
		var turn_factor = abs(steer_angle)
		var new_slip = speed_factor * turn_factor * 0.45
		if is_braking:
			new_slip *= 1.15
		rear_wheel_slip = lerp(rear_wheel_slip, new_slip, 0.22)
		rear_wheel_slip = clamp(rear_wheel_slip, 0.0, 1.0)
		var rear_slip = rear_wheel_slip * drift_balance
		var front_slip = rear_wheel_slip * (1.0 - drift_balance)
		lateral_vec += transform.y * steer_angle * rear_slip * drift_strength * 6.0 * delta
		lateral_vec += transform.y * steer_angle * front_slip * drift_strength * 2.5 * delta
		rotation += (rear_slip - front_slip) * steer_angle * drift_rotation * 28.0 * delta
		speed *= (1.0 - rear_wheel_slip * drift_speed_loss * 0.3)
	else:
		rear_wheel_slip = lerp(rear_wheel_slip, 0.0, drift_recovery)
	return lateral_vec

# ===== ДЫМ ПРИ ДРИФТЕ =====
func update_drift_smoke(delta):
	if (rear_wheel_slip > 0.3 or brake_slip > 0.2) and abs(speed) > 50.0:
		tire_smoke_timer += delta
		if tire_smoke_timer > 0.15:
			spawn_smoke_particle()
			tire_smoke_timer = 0.0

	# удаляем старые
	for i in range(smoke_particles.size() - 1, -1, -1):
		if not is_instance_valid(smoke_particles[i]):
			smoke_particles.remove_at(i)

func spawn_smoke_particle():
	if drift_smoke_effect and drift_smoke_effect is PackedScene:
		var distance_behind = 125
		
		# Всегда правильные стороны независимо от поворота машины
		var left_offset = transform.y * 35    # Левый бок
		var right_offset = transform.y * -35  # Правый бок
		var rear_offset = -transform.x * distance_behind
		
		# Левый дым
		var smoke_left = drift_smoke_effect.instantiate()
		get_parent().add_child(smoke_left)
		smoke_left.global_position = global_position + rear_offset + left_offset
		smoke_left.rotation = rotation
		if smoke_left is CPUParticles2D:
			smoke_left.emitting = true
		smoke_particles.append(smoke_left)
		
		# Правый дым
		var smoke_right = drift_smoke_effect.instantiate()
		get_parent().add_child(smoke_right)
		smoke_right.global_position = global_position + rear_offset + right_offset
		smoke_right.rotation = rotation
		if smoke_right is CPUParticles2D:
			smoke_right.emitting = true
		smoke_particles.append(smoke_right)
