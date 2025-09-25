extends CharacterBody2D

# ===== ПАРАМЕТРЫ ДВИЖЕНИЯ =====
var speed = 0.0
var max_speed = 900.0
var acceleration = 300.0
var friction = 60.0
var brake_power = 200.0
var brake_in_turn_factor = 0.45
var rotation_speed = 3.5

# ===== ФИЗИКА СТОЛКНОВЕНИЙ =====
var collision_speed_loss = 0.7  # Потеря скорости при лобовом столкновении (70%)
var lateral_collision_speed_loss = 0.4  # Потеря скорости при боковом столкновении (40%)
var min_collision_speed = 50.0  # Минимальная скорость для срабатывания столкновения
var collision_rotation_effect = 0.1  # Эффект на вращение при столкновении

# Переменные для обработки столкновений
var was_colliding = false
var last_collision_normal: Vector2
var collision_timer = 0.0

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

# ===== ИНТЕРФЕЙС И СТАТИСТИКА =====
var current_lap = 1
var total_laps = 3
var lap_times = []
var current_lap_start_time = 0.0
var race_start_time = 0.0

# Для финишной линии
var finish_line: Area2D
var can_detect_finish = true

# Элементы интерфейса
var speed_label: Label
var lap_label: Label
var message_label: Label
var message_timer: Timer

func _ready():
	create_ui()
	race_start_time = Time.get_ticks_msec() / 1000.0
	current_lap_start_time = race_start_time
	
	# Ищем финишную линию по имени
	finish_line = get_parent().get_node("FinishLine")
	if finish_line:
		print("Финишная линия найдена: ", finish_line.name)
		if finish_line.body_entered.connect(_on_finish_line_entered) != OK:
			print("Ошибка подключения сигнала")
	else:
		print("Финишная линия не найдена! Убедись что она называется 'FinishLine'")
	
	show_message("GO! GO! GO!", 2.0)

func _on_finish_line_entered(body):
	if body == self and can_detect_finish:
		print("Финишная линия пересечена! Круг: ", current_lap)
		complete_lap()
		can_detect_finish = false
		await get_tree().create_timer(3.0).timeout
		can_detect_finish = true

func _physics_process(delta):
	# Управление
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

	update_drift_smoke(delta)
	update_ui(delta)

	# Обрабатываем столкновения
	var collision_occurred = move_and_slide()
	handle_collisions(delta, collision_occurred)

# ===== ФИЗИКА СТОЛКНОВЕНИЙ =====
func handle_collisions(delta, collision_occurred):
	if collision_occurred:
		# Получаем информацию о столкновении
		var collision = get_last_slide_collision()
		if collision and abs(speed) > min_collision_speed:
			var collision_normal = collision.get_normal()
			var collision_angle = abs(collision_normal.angle_to(transform.x))
			
			# Определяем тип столкновения
			if collision_angle < PI/4:  # Лобовое столкновение (0-45 градусов)
				handle_front_collision(collision_normal)
			elif collision_angle > 3*PI/4:  # Заднее столкновение (135-180 градусов)  
				handle_rear_collision(collision_normal)
			else:  # Боковое столкновение (45-135 градусов)
				handle_side_collision(collision_normal, collision_angle)
			
			# Показываем эффект столкновения
			show_collision_effect()
		
		was_colliding = true
		collision_timer = 0.3  # Таймер для предотвращения многократных срабатываний
	else:
		if was_colliding:
			collision_timer -= delta
			if collision_timer <= 0:
				was_colliding = false

func handle_front_collision(normal):
	# Лобовое столкновение - максимальная потеря скорости
	var speed_before = speed
	speed *= (1.0 - collision_speed_loss)
	
	# Добавляем отскок
	var bounce_effect = normal * speed_before * 0.3
	velocity += bounce_effect
	
	# Эффект на вращение
	rotation += sign(normal.cross(transform.x)) * collision_rotation_effect * (speed_before / max_speed)
	
	print("Лобовое столкновение! Скорость: ", speed_before, " -> ", speed)

func handle_rear_collision(normal):
	# Заднее столкновение - меньшая потеря скорости
	var speed_before = speed
	speed *= (1.0 - collision_speed_loss * 0.5)
	
	print("Заднее столкновение! Скорость: ", speed_before, " -> ", speed)

func handle_side_collision(normal, angle):
	# Боковое столкновение - рассчитываем потери в зависимости от угла
	var speed_before = speed
	
	# Чем более боковое столкновение, тем меньше потери скорости
	var angle_factor = 1.0 - (abs(angle - PI/2) / (PI/2))  # 1.0 для прямого бокового, 0.0 для диагонального
	var speed_loss = lateral_collision_speed_loss * angle_factor
	
	speed *= (1.0 - speed_loss)
	
	# Боковое скольжение
	var slide_effect = normal * speed_before * 0.2 * angle_factor
	velocity += slide_effect
	
	# Сильный эффект на вращение при боковых столкновениях
	rotation += sign(normal.cross(transform.x)) * collision_rotation_effect * 2.0 * (speed_before / max_speed) * angle_factor
	
	print("Боковое столкновение! Угол: ", rad_to_deg(angle), "° Скорость: ", speed_before, " -> ", speed)

func show_collision_effect():
	# Можно добавить частицы, звук или анимацию столкновения
	show_message("CRASH!", 1.0)
	
	# Мигание скорости красным
	speed_label.add_theme_color_override("font_color", Color.RED)
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(speed_label):
		speed_label.add_theme_color_override("font_color", Color.WHITE)

# ===== ИНТЕРФЕЙС =====
func create_ui():
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "CanvasLayer"
	add_child(canvas_layer)
	
	speed_label = Label.new()
	speed_label.position = Vector2(20, 20)
	speed_label.add_theme_font_size_override("font_size", 24)
	speed_label.add_theme_color_override("font_color", Color.WHITE)
	speed_label.text = "SPEED: 0"
	canvas_layer.add_child(speed_label)
	
	lap_label = Label.new()
	lap_label.position = Vector2(20, 60)
	lap_label.add_theme_font_size_override("font_size", 24)
	lap_label.add_theme_color_override("font_color", Color.WHITE)
	lap_label.text = "LAP: 1/" + str(total_laps)
	canvas_layer.add_child(lap_label)
	
	message_label = Label.new()
	message_label.position = Vector2(400, 300)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 32)
	message_label.add_theme_color_override("font_color", Color.YELLOW)
	message_label.text = ""
	message_label.visible = false
	canvas_layer.add_child(message_label)
	
	message_timer = Timer.new()
	message_timer.one_shot = true
	message_label.add_child(message_timer)
	message_timer.timeout.connect(_on_message_timer_timeout)

func update_ui(delta):
	var speed_kmh = int(abs(speed) * 0.36)
	speed_label.text = "SPEED: " + str(speed_kmh) + " km/h"
	lap_label.text = "LAP: " + str(current_lap) + "/" + str(total_laps)

func show_message(text, duration = 3.0):
	message_label.text = text
	message_label.visible = true
	message_timer.start(duration)

func _on_message_timer_timeout():
	message_label.visible = false

func complete_lap():
	var lap_time = (Time.get_ticks_msec() / 1000.0) - current_lap_start_time
	lap_times.append(lap_time)
	
	var lap_time_str = "%.2f" % lap_time
	show_message("LAP " + str(current_lap) + " - " + lap_time_str + "s", 3.0)
	
	current_lap += 1
	current_lap_start_time = Time.get_ticks_msec() / 1000.0
	
	if current_lap > total_laps:
		finish_race()

func finish_race():
	speed = 0
	var total_time = (Time.get_ticks_msec() / 1000.0) - race_start_time
	var best_lap = lap_times.min() if lap_times.size() > 0 else 0
	var finish_text = "RACE FINISHED!\nTotal: %.2fs\nBest: %.2fs" % [total_time, best_lap]
	show_message(finish_text, 10.0)

# ===== ОСТАЛЬНЫЕ ФУНКЦИИ (без изменений) =====
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

func update_drift_smoke(delta):
	if (rear_wheel_slip > 0.3 or brake_slip > 0.2) and abs(speed) > 50.0:
		tire_smoke_timer += delta
		if tire_smoke_timer > 0.15:
			spawn_smoke_particle()
			tire_smoke_timer = 0.0

	for i in range(smoke_particles.size() - 1, -1, -1):
		if not is_instance_valid(smoke_particles[i]):
			smoke_particles.remove_at(i)

func spawn_smoke_particle():
	if drift_smoke_effect and drift_smoke_effect is PackedScene:
		var distance_behind = 125
		var left_offset = transform.y * 35
		var right_offset = transform.y * -35
		var rear_offset = -transform.x * distance_behind
		
		var smoke_left = drift_smoke_effect.instantiate()
		get_parent().add_child(smoke_left)
		smoke_left.global_position = global_position + rear_offset + left_offset
		smoke_left.rotation = rotation
		if smoke_left is CPUParticles2D:
			smoke_left.emitting = true
		smoke_particles.append(smoke_left)
		
		var smoke_right = drift_smoke_effect.instantiate()
		get_parent().add_child(smoke_right)
		smoke_right.global_position = global_position + rear_offset + right_offset
		smoke_right.rotation = rotation
		if smoke_right is CPUParticles2D:
			smoke_right.emitting = true
		smoke_particles.append(smoke_right)
