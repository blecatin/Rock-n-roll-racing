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

# ===== СТОЛКНОВЕНИЯ / ГОНКА =====
var is_colliding_with_wall = false
var current_lap = 1
var total_laps = 3
var lap_time = 0.0
var total_time = 0.0
var best_lap_time = 999.9
var can_trigger_finish = true
var race_started = true
var race_finished = false

# ===== ПОВОРОТ РУЛЯ =====
var turn_input = 0.0          # моментальное положение кнопки
var steer_angle = 0.0         # плавное положение руля
var current_turn = 0.0        # финальная угловая скорость

func _ready():
	print("=== CAR: inertia + smooth steering ===")

func _physics_process(delta):
	if race_finished:
		return

	# 1) читаем ввод поворота (-1..1)
	turn_input = 0.0
	if Input.is_action_pressed("ui_right"):
		turn_input += 1.0
	if Input.is_action_pressed("ui_left"):
		turn_input -= 1.0

	# 2) плавно интерполируем руль к turn_input
	steer_angle = lerp(steer_angle, turn_input, 5.0 * delta)
	current_turn = steer_angle * rotation_speed

	# 3) газ / тормоз
	is_braking = false
	if Input.is_action_pressed("ui_up"):
		speed = move_toward(speed, max_speed, acceleration * delta)
	elif Input.is_action_pressed("ui_down"):
		is_braking = true
		var turn_factor = clamp(abs(steer_angle), 0.0, 1.0)
		var brake_factor = lerp(1.0, brake_in_turn_factor, turn_factor)
		var target_speed = -max_speed * 0.5
		speed = move_toward(speed, target_speed, brake_power * brake_factor * delta)
	# без самотормоза

	# 3.1) лёгкая потеря скорости при рулении
	var turn_loss = abs(steer_angle) * 0.015 # 1.5% max
	if turn_loss > 0.0 and abs(speed) > 50.0:
		speed *= (1.0 - turn_loss * delta)

	# 4) разложение скорости
	var forward_vec = transform.x.normalized() * speed
	var lateral_vec = velocity - velocity.project(transform.x)

	# 5) дрифт
	lateral_vec = apply_advanced_drift(delta, lateral_vec)
	lateral_vec = apply_brake_slip(delta, lateral_vec)

	if lateral_vec.length() > max_lateral_speed:
		lateral_vec = lateral_vec.normalized() * max_lateral_speed
	lateral_vec = lateral_vec.move_toward(Vector2.ZERO, lateral_damping * delta)

	velocity = forward_vec + lateral_vec

	# 6) плавный поворот
	if abs(speed) > 30.0:
		var turn_power = current_turn * (abs(speed) / max_speed) * delta
		var max_turn_delta = 0.12
		rotation += clamp(turn_power, -max_turn_delta, max_turn_delta)

	move_and_slide()
	check_wall_collisions()

	if race_started and not race_finished:
		lap_time += delta
		total_time += delta
		if get_parent().has_method("update_ui"):
			var speed_kmh = abs(speed) * 0.3
			get_parent().update_ui(current_lap, total_laps, lap_time, best_lap_time, speed_kmh)

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

func check_wall_collisions():
	is_colliding_with_wall = get_slide_collision_count() > 0
	if is_colliding_with_wall:
		rear_wheel_slip = 0.0
		brake_slip = 0.0

func _process(delta):
	check_finish_line()

func check_finish_line():
	var finish = get_parent().get_node_or_null("FinishLine")
	if finish and can_trigger_finish:
		var distance = global_position.distance_to(finish.global_position)
		if distance < 150.0:
			complete_lap()
			can_trigger_finish = false
	elif can_trigger_finish == false:
		var finish_node = get_parent().get_node_or_null("FinishLine")
		if finish_node:
			var distance = global_position.distance_to(finish_node.global_position)
			if distance > 250.0:
				can_trigger_finish = true

func complete_lap():
	if lap_time < best_lap_time:
		best_lap_time = lap_time
	current_lap += 1
	lap_time = 0.0
	if get_parent().has_method("show_ui_notification"):
		if current_lap > total_laps:
			get_parent().show_ui_notification("🎉 ПОБЕДА! Время: %.1fс" % total_time, 5.0)
		else:
			get_parent().show_ui_notification("КРУГ %d/%d" % [current_lap, total_laps])
	if current_lap > total_laps:
		finish_race()

func finish_race():
	race_finished = true
	speed = 0.0
	rear_wheel_slip = 0.0
	brake_slip = 0.0

func _input(event):
	if event.is_action_pressed("ui_accept"):
		print("=== DEBUG STATUS ===")
		print("speed:", speed, "vel.len:", velocity.length())
		print("turn_input:", turn_input, "steer_angle:", steer_angle, "rear_wheel_slip:", rear_wheel_slip)
