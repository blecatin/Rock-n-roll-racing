extends CharacterBody2D

# ===== ДВИЖЕНИЕ =====
var speed = 0
var max_speed = 900
var acceleration = 300
var friction = 100
var brake_power = 500
var rotation_speed = 3.5

# ===== ФИЗИКА СТОЛКНОВЕНИЙ =====
var collision_timer = 0.0
var is_colliding = false

# ===== ГОНКА =====
var current_lap = 1
var total_laps = 3
var lap_time = 0.0
var total_time = 0.0
var best_lap_time = 999.9
var can_trigger_finish = true
var race_started = true
var race_finished = false

func _ready():
	print("=== УПРОЩЕННАЯ ФИЗИКА ===")

func _physics_process(delta):
	# ===== УПРАВЛЕНИЕ =====
	if not race_finished and collision_timer <= 0:
		if Input.is_action_pressed("ui_up"):
			speed = move_toward(speed, max_speed, acceleration * delta)
		elif Input.is_action_pressed("ui_down"):
			speed = move_toward(speed, -max_speed * 0.5, brake_power * delta)
		else:
			speed = move_toward(speed, 0, friction * delta)
		
		var turn = 0
		if Input.is_action_pressed("ui_right"):
			turn += rotation_speed
		if Input.is_action_pressed("ui_left"):
			turn -= rotation_speed
		
		if abs(speed) > 20:
			var turn_power = turn * (abs(speed) / max_speed) * delta
			rotation += turn_power
	
	# ===== ОБРАБОТКА СТОЛКНОВЕНИЙ =====
	if collision_timer > 0:
		collision_timer -= delta
		# При столкновении теряем скорость быстрее
		speed = move_toward(speed, 0, friction * delta * 5.0)
		
		# Легкий случайный занос
		rotation += randf_range(-0.1, 0.1) * delta
	
	# Применяем движение
	velocity = transform.x * speed
	var collision = move_and_slide()
	
	# ===== ПРОСТАЯ ПРОВЕРКА СТОЛКНОВЕНИЙ =====
	if get_slide_collision_count() > 0 and collision_timer <= 0:
		handle_collision()
	
	# ===== ВРЕМЯ =====
	if race_started and not race_finished:
		lap_time += delta
		total_time += delta
		
		if get_parent().has_method("update_ui"):
			var speed_kmh = abs(speed) * 0.3
			get_parent().update_ui(current_lap, total_laps, lap_time, best_lap_time, speed_kmh)

# ===== ПРОСТАЯ ОБРАБОТКА СТОЛКНОВЕНИЙ =====
func handle_collision():
	# Простое столкновение - без сложной физики
	print("💥 СТОЛКНОВЕНИЕ!")
	
	# Резкая потеря скорости
	speed *= 0.3
	
	# Короткая блокировка управления
	collision_timer = 0.5
	
	# Легкий отскок - просто меняем направление немного
	rotation += randf_range(-0.5, 0.5)
	
	if get_parent().has_method("show_ui_notification"):
		get_parent().show_ui_notification("💥 СТОЛКНОВЕНИЕ!", 1.0)

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
	speed = 0

# Тест
func _input(event):
	if event.is_action_pressed("ui_accept"):
		# Принудительное столкновение для теста
		handle_collision()
