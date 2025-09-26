extends CharacterBody2D

# =========================
# ПАРАМЕТРЫ ДВИЖЕНИЯ
# =========================
var speed: float = 0.0
var max_speed: float = 900.0
var acceleration: float = 300.0
var friction: float = 60.0
var brake_power: float = 200.0
var brake_in_turn_factor: float = 0.45
var rotation_speed: float = 3.5

# =========================
# КОРОБКА ПЕРЕДАЧ (Автомат)
# =========================
var current_gear: int = 1
var max_gear: int = 5
# gear_ratios влияют на ускорение и "макс в передаче" (декоративно/игрово)
var gear_ratios: Array = [0.0, 0.3, 0.5, 0.7, 0.85, 1.0]
# пороговые скорости для переключения передач (в px/s)
var gear_speeds: Array = [0, 140, 280, 420, 560, 700]
var gear_change_cooldown: float = 0.45
var last_gear_change: float = 0.0

# =========================
# СТОЛКНОВЕНИЯ (параметры)
# =========================
var collision_speed_loss: float = 0.7
var lateral_collision_speed_loss: float = 0.4
var min_collision_speed: float = 50.0
var collision_rotation_effect: float = 0.12
var was_colliding: bool = false
var collision_timer: float = 0.0

# =========================
# ДРИФТ И ПРОБУКСОВКА
# =========================
var natural_drift_threshold: float = 10.0
var drift_strength: float = 0.1
var drift_rotation: float = 0.03
var drift_speed_loss: float = 0.03
var rear_wheel_slip: float = 0.0
var drift_balance: float = 0.8
var drift_recovery: float = 0.08
var is_braking: bool = false
var brake_slip: float = 0.0
var brake_slip_threshold: float = 200.0
var brake_slip_strength: float = 0.04

# =========================
# СТАБИЛЬНОСТЬ БОКОВОЙ СКОРОСТИ
# =========================
var lateral_damping: float = 300.0
var max_lateral_speed: float = 180.0
var turn_input: float = 0.0
var steer_angle: float = 0.0
var current_turn: float = 0.0

# =========================
# ДЫМ (частицы)
# =========================
@export var drift_smoke_path: String = "res://drift_smoke.tscn"
var drift_smoke_effect: PackedScene = null
var smoke_particles: Array = []
var tire_smoke_timer: float = 0.0

# =========================
# ЗВУКИ
# =========================
var engine_accel_sound: AudioStreamPlayer2D = null
var engine_decel_sound: AudioStreamPlayer2D = null
var tire_sound: AudioStreamPlayer2D = null
var collision_sound: AudioStreamPlayer2D = null
var gear_shift_sound: AudioStreamPlayer2D = null

# флаги для управления циклом звука
var want_engine_accel_playing: bool = false
var want_engine_decel_playing: bool = false

# уровни громкости (dB)
const ENGINE_VOL_DB := -10.0
const TIRE_VOL_DB := -6.0   # гораздо громче двигателя
const COLLISION_VOL_DB := 0.0

# =========================
# ГОНКА / UI / ВРЕМЯ
# =========================
var current_lap: int = 1
var total_laps: int = 3
var lap_times: Array = []
var current_lap_start_time: float = 0.0
var race_start_time: float = 0.0
var finish_line: Node = null
var can_detect_finish: bool = true
var lap_time: float = 0.0
var total_time: float = 0.0
var best_lap_time: float = 99999.0

# UI
var speed_label: Label = null
var lap_label: Label = null
var gear_label: Label = null
var message_label: Label = null
var message_timer: Timer = null

# =========================
# READY
# =========================
func _ready() -> void:
	# загрузка эффекта дыма безопасно
	if drift_smoke_path != "":
		var loaded = load(drift_smoke_path)
		if loaded and loaded is PackedScene:
			drift_smoke_effect = loaded
		else:
			drift_smoke_effect = null

	# создаём звуки (или ищем в сцене)
	_create_or_find_sounds()

	# UI
	_create_ui()

	# время старта
	race_start_time = Time.get_ticks_msec() / 1000.0
	current_lap_start_time = race_start_time

	# FinishLine если есть
	if get_parent() != null and get_parent().has_node("FinishLine"):
		finish_line = get_parent().get_node("FinishLine")
		if finish_line and finish_line.has_signal("body_entered"):
			finish_line.body_entered.connect(Callable(self, "_on_finish_line_entered"))

	# подключаем "finished" сигнал у аудиоплееров для зацикливания при необходимости
	if engine_accel_sound:
		engine_accel_sound.finished.connect(Callable(self, "_on_engine_accel_finished"))
	if engine_decel_sound:
		engine_decel_sound.finished.connect(Callable(self, "_on_engine_decel_finished"))

func _create_or_find_sounds() -> void:
	# accel
	if has_node("EngineAccelSound"):
		engine_accel_sound = $EngineAccelSound
	else:
		engine_accel_sound = AudioStreamPlayer2D.new()
		engine_accel_sound.name = "EngineAccelSound"
		engine_accel_sound.stream = load("res://sounds/engine_accel.wav")
		engine_accel_sound.volume_db = ENGINE_VOL_DB
		engine_accel_sound.autoplay = false
		add_child(engine_accel_sound)

	# decel
	if has_node("EngineDecelSound"):
		engine_decel_sound = $EngineDecelSound
	else:
		engine_decel_sound = AudioStreamPlayer2D.new()
		engine_decel_sound.name = "EngineDecelSound"
		engine_decel_sound.stream = load("res://sounds/engine_decel.wav")
		engine_decel_sound.volume_db = ENGINE_VOL_DB
		engine_decel_sound.autoplay = false
		add_child(engine_decel_sound)

	# tire
	if has_node("TireSound"):
		tire_sound = $TireSound
	else:
		tire_sound = AudioStreamPlayer2D.new()
		tire_sound.name = "TireSound"
		tire_sound.stream = load("res://sounds/tire_squeal.wav")
		tire_sound.volume_db = TIRE_VOL_DB
		tire_sound.autoplay = false
		add_child(tire_sound)

	# collision
	if has_node("CollisionSound"):
		collision_sound = $CollisionSound
	else:
		collision_sound = AudioStreamPlayer2D.new()
		collision_sound.name = "CollisionSound"
		collision_sound.stream = load("res://sounds/crash.wav")
		collision_sound.volume_db = COLLISION_VOL_DB
		collision_sound.autoplay = false
		add_child(collision_sound)

	# gear shift
	if has_node("GearShiftSound"):
		gear_shift_sound = $GearShiftSound
	else:
		gear_shift_sound = AudioStreamPlayer2D.new()
		gear_shift_sound.name = "GearShiftSound"
		gear_shift_sound.stream = load("res://sounds/gear_shift.wav")
		gear_shift_sound.volume_db = -6.0
		gear_shift_sound.autoplay = false
		add_child(gear_shift_sound)

# =========================
# ФИЗИЧЕСКИЙ ЦИКЛ
# =========================
func _physics_process(delta: float) -> void:
	# ввод / руль
	_handle_input(delta)

	# коробка передач
	_handle_gearbox(delta)

	# движение: газ, тормоз, engine braking, дрифт
	_handle_movement(delta)

	# дым, UI, звук
	_update_drift_smoke(delta)
	_update_ui(delta)
	_update_sounds(delta)

	# передвигаем тело и обрабатываем коллизии
	move_and_slide()
	_handle_collisions(delta)

	# шапка времени гонки
	if total_time != null:
		if lap_time != null and race_start_time != 0:
			# учитываем время
			lap_time += delta
			total_time += delta

# =========================
# ВВОД И ПОВОРОТ
# =========================
func _handle_input(delta: float) -> void:
	turn_input = 0.0
	if Input.is_action_pressed("ui_right"):
		turn_input += 1.0
	if Input.is_action_pressed("ui_left"):
		turn_input -= 1.0

	# плавный руль
	steer_angle = lerp(steer_angle, turn_input, 6.0 * delta)
	current_turn = steer_angle * rotation_speed

# =========================
# КОРОБКА ПЕРЕДАЧ
# улучшенный автомат: использует gear_speeds и cooldown
# =========================
func _handle_gearbox(delta: float) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	var abs_speed = abs(speed)

	# если слишком часто - не переключаем
	if now - last_gear_change < gear_change_cooldown:
		return

	# апшИфт: если скорость выше порога следующей передачи
	if current_gear < max_gear:
		var up_target = gear_speeds[current_gear + 1]
		if abs_speed >= up_target * 0.95:
			current_gear += 1
			last_gear_change = now
			if gear_shift_sound:
				gear_shift_sound.play()
			return

	# дауншИфт: если скорость сильно упала ниже текущей передачи
	if current_gear > 1:
		var down_target = gear_speeds[current_gear]
		if abs_speed <= down_target * 0.6:
			current_gear -= 1
			last_gear_change = now
			if gear_shift_sound:
				gear_shift_sound.play()
			return

# =========================
# ДВИЖЕНИЕ (газ/тормоз/engine braking + дрифт)
# =========================
func _handle_movement(delta: float) -> void:
	is_braking = false

	# вручную ускоряем / тормозим
	if Input.is_action_pressed("ui_up"):
		# acceleration scaled by gear ratio, max capped to max_speed * gear_ratio
		var gear_mult = 1.0
		if current_gear >= 0 and current_gear < gear_ratios.size():
			gear_mult = gear_ratios[current_gear]
		var effective_acc = acceleration * (0.5 + gear_mult)  # небольшая базовая тяга + отношение передачи
		var target_max = max_speed * gear_mult
		# если gear_mult очень маленький (первая точка 0.0), даём минимальный предел
		if target_max < 150.0:
			target_max = 150.0
		speed = move_toward(speed, target_max, effective_acc * delta)
		# хотим играть accel звук
		want_engine_accel_playing = true
		want_engine_decel_playing = false

	elif Input.is_action_pressed("ui_down"):
		# ручной тормоз/реверс
		is_braking = true
		var turn_factor = clamp(abs(steer_angle), 0.0, 1.0)
		var brake_factor = lerp(1.0, brake_in_turn_factor, turn_factor)
		var target_speed = -max_speed * 0.4
		speed = move_toward(speed, target_speed, brake_power * brake_factor * delta)
		# играем decel если нужно
		want_engine_accel_playing = false
		want_engine_decel_playing = true

	else:
		# отпуск газ — engine braking (плавное замедление), а не резкий стоп
		# engine brake сила зависит от текущей скорости и передачи
		var engine_brake_base = 80.0
		var gear_brake_factor = 0.3 + (float(current_gear) / float(max_gear)) * 0.7
		var engine_brake = engine_brake_base * gear_brake_factor
		# уменьшаем скорость с силой engine_brake
		if abs(speed) > 1.0:
			if speed > 0:
				speed = speed - engine_brake * delta
				if speed < 0:
					speed = 0
			else:
				speed = speed + engine_brake * delta
				if speed > 0:
					speed = 0
		else:
			# небольшое пассивное сопротивление
			speed = move_toward(speed, 0.0, friction * delta)

		# переключаем на decel звук
		want_engine_accel_playing = false
		want_engine_decel_playing = true

	# лёгкая потеря скорости при рулении (немного)
	var turn_loss = abs(steer_angle) * 0.012
	if turn_loss > 0.0 and abs(speed) > 50.0:
		speed *= (1.0 - turn_loss * delta)

	# Применяем дрифт / lateral forces
	var forward_vec = transform.x.normalized() * speed
	var lateral_vec = velocity - velocity.project(transform.x)
	lateral_vec = apply_advanced_drift(delta, lateral_vec)
	lateral_vec = apply_brake_slip(delta, lateral_vec)

	# ограничение боковой скорости и гашение
	if lateral_vec.length() > max_lateral_speed:
		lateral_vec = lateral_vec.normalized() * max_lateral_speed
	lateral_vec = lateral_vec.move_toward(Vector2.ZERO, lateral_damping * delta)

	velocity = forward_vec + lateral_vec

	# плавный поворот машины (ограничение на изменение в кадр)
	if abs(speed) > 30.0:
		var turn_power = current_turn * (abs(speed) / max_speed) * delta
		var max_turn_delta = 0.12
		rotation += clamp(turn_power, -max_turn_delta, max_turn_delta)

# =========================
# ЗВУКОВАЯ ЛОГИКА
#  - поддерживаем цикл звука вручную через сигнал finished
#  - управляем громкостью и питчем в зависимости от engine_rpm / speed
# =========================
func _update_sounds(delta: float) -> void:
	# вычисляем engine_rpm примерно (0..1.2)
	var redline_speed = gear_speeds[current_gear] if current_gear < gear_speeds.size() else max_speed
	if redline_speed <= 0:
		redline_speed = max_speed
	var engine_rpm = clamp(abs(speed) / redline_speed, 0.05, 1.2)

	# регулировка питча/громкости двигателя
	if engine_accel_sound and engine_accel_sound.stream:
		var target_pitch = lerp(0.9, 1.6, clamp(engine_rpm, 0.0, 1.0))
		engine_accel_sound.pitch_scale = lerp(engine_accel_sound.pitch_scale, target_pitch, 0.1)
		# корректируем громкость чуть в зависимости от rpm
		engine_accel_sound.volume_db = ENGINE_VOL_DB + (engine_rpm * 3.0)

	if engine_decel_sound and engine_decel_sound.stream:
		var decel_pitch = lerp(0.8, 1.2, clamp(engine_rpm, 0.0, 1.0))
		engine_decel_sound.pitch_scale = lerp(engine_decel_sound.pitch_scale, decel_pitch, 0.1)
		engine_decel_sound.volume_db = ENGINE_VOL_DB + (engine_rpm * 1.5)

	# визг шин: включаем, когда интенсивность дрифта высокая
	var drift_intensity = max(rear_wheel_slip, brake_slip)
	if drift_intensity > 0.18 and abs(speed) > 40.0:
		if tire_sound and not tire_sound.playing:
			tire_sound.volume_db = TIRE_VOL_DB
			tire_sound.play()
	else:
		if tire_sound and tire_sound.playing:
			tire_sound.stop()

	# Управление воспроизведением engine accel/decel
	# кмк: хотим чтобы accel звучал при давлении газа, decel — при отпускании
	if want_engine_accel_playing:
		if engine_decel_sound and engine_decel_sound.playing:
			engine_decel_sound.stop()
		if engine_accel_sound and not engine_accel_sound.playing:
			engine_accel_sound.play()
		# ensure we won't leave decel playing
		want_engine_decel_playing = false
	elif want_engine_decel_playing:
		if engine_accel_sound and engine_accel_sound.playing:
			engine_accel_sound.stop()
		if engine_decel_sound and not engine_decel_sound.playing:
			engine_decel_sound.play()

# вызывается, когда stream закончил воспроизведение
func _on_engine_accel_finished() -> void:
	# если хотим, чтобы accel продолжался — рестартуем
	if want_engine_accel_playing and engine_accel_sound and engine_accel_sound.stream:
		engine_accel_sound.play()

func _on_engine_decel_finished() -> void:
	if want_engine_decel_playing and engine_decel_sound and engine_decel_sound.stream:
		engine_decel_sound.play()

# =========================
# ДРИФТ / ПРОБУКСОВКА
# =========================
func apply_brake_slip(delta: float, lateral_vec: Vector2) -> Vector2:
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

func apply_advanced_drift(delta: float, lateral_vec: Vector2) -> Vector2:
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

# =========================
# ДЫМ
# =========================
func _update_drift_smoke(delta: float) -> void:
	# spawn if strong drift
	if (rear_wheel_slip > 0.3 or brake_slip > 0.2) and abs(speed) > 50.0:
		tire_smoke_timer += delta
		if tire_smoke_timer > 0.15:
			_spawn_smoke_particle()
			tire_smoke_timer = 0.0

	# clean up
	for i in range(smoke_particles.size() - 1, -1, -1):
		if not is_instance_valid(smoke_particles[i]):
			smoke_particles.remove_at(i)

func _spawn_smoke_particle() -> void:
	if drift_smoke_effect == null:
		return
	# два источника слева/справа за машиной
	var distance_behind = 25
	var side = 14
	var smoke_left = drift_smoke_effect.instantiate()
	var smoke_right = drift_smoke_effect.instantiate()
	var parent_node = get_parent() if get_parent() != null else get_tree().get_root()
	parent_node.add_child(smoke_left)
	parent_node.add_child(smoke_right)
	smoke_left.global_position = global_position - transform.x * distance_behind + transform.y * side
	smoke_right.global_position = global_position - transform.x * distance_behind - transform.y * side
	smoke_left.rotation = rotation
	smoke_right.rotation = rotation
	# включаем эмиттинг если это частицы
	if smoke_left is CPUParticles2D:
		smoke_left.emitting = true
	if smoke_right is CPUParticles2D:
		smoke_right.emitting = true
	smoke_particles.append(smoke_left)
	smoke_particles.append(smoke_right)

# =========================
# КОЛЛИЗИИ
# =========================
func _handle_collisions(delta: float) -> void:
	var count = get_slide_collision_count()
	if count <= 0:
		# уменьшаем таймер столкновения
		if was_colliding:
			collision_timer -= delta
			if collision_timer <= 0:
				was_colliding = false
		return

	for i in range(count):
		var col = get_slide_collision(i)
		if col == null:
			continue
		var rel_vel = Vector2.ZERO
		# стараемся получить относительную скорость если доступно
		if col.has_method("get_relative_velocity"):
			var rel = col.get_relative_velocity()
			if rel is Vector2:
				rel_vel = rel
		if rel_vel == Vector2.ZERO:
			rel_vel = velocity
		var collision_speed = rel_vel.length()
		if collision_speed < min_collision_speed:
			continue

		var normal = col.get_normal()
		var angle = abs(normal.angle_to(transform.x))
		# classify
		if angle < PI/4:
			_handle_front_collision(normal, collision_speed)
		elif angle > 3.0 * PI / 4.0:
			_handle_rear_collision(normal, collision_speed)
		else:
			_handle_side_collision(normal, collision_speed, angle)

		# звук и эффект
		if collision_sound:
			collision_sound.volume_db = COLLISION_VOL_DB
			collision_sound.play()
		show_message("CRASH!", 1.0)
		was_colliding = true
		collision_timer = 0.4

func _handle_front_collision(normal: Vector2, collision_speed: float) -> void:
	var speed_before = speed
	speed *= (1.0 - collision_speed_loss)
	var bounce = normal * speed_before * 0.25
	velocity += bounce
	rotation += sign(normal.cross(transform.x)) * collision_rotation_effect * (speed_before / max_speed)

func _handle_rear_collision(normal: Vector2, collision_speed: float) -> void:
	speed *= (1.0 - collision_speed_loss * 0.5)

func _handle_side_collision(normal: Vector2, collision_speed: float, angle: float) -> void:
	var speed_before = speed
	var angle_factor = 1.0 - (abs(angle - PI/2.0) / (PI/2.0))
	var speed_loss = lateral_collision_speed_loss * angle_factor
	speed *= (1.0 - speed_loss)
	var slide = normal * speed_before * 0.2 * angle_factor
	velocity += slide
	rotation += sign(normal.cross(transform.x)) * collision_rotation_effect * 2.0 * (speed_before / max_speed) * angle_factor

# =========================
# UI / Lap logic
# =========================
func _create_ui() -> void:
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "HUD"
	add_child(canvas_layer)
	speed_label = Label.new()
	speed_label.position = Vector2(18, 14)
	canvas_layer.add_child(speed_label)
	lap_label = Label.new()
	lap_label.position = Vector2(18, 44)
	canvas_layer.add_child(lap_label)
	gear_label = Label.new()
	gear_label.position = Vector2(18, 74)
	canvas_layer.add_child(gear_label)
	message_label = Label.new()
	message_label.position = Vector2(400, 200)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.visible = false
	canvas_layer.add_child(message_label)
	message_timer = Timer.new()
	message_timer.one_shot = true
	canvas_layer.add_child(message_timer)
	message_timer.timeout.connect(Callable(self, "_on_message_timer_timeout"))

func _update_ui(delta: float) -> void:
	if speed_label:
		speed_label.text = "SPEED: " + str(int(abs(speed) * 0.36)) + " km/h"
	if lap_label:
		lap_label.text = "LAP: " + str(current_lap) + "/" + str(total_laps)
	if gear_label:
		gear_label.text = "GEAR: " + str(current_gear)

func show_message(text: String, duration: float = 3.0) -> void:
	if message_label:
		message_label.text = text
		message_label.visible = true
		if message_timer:
			message_timer.start(duration)

func _on_message_timer_timeout() -> void:
	if message_label:
		message_label.visible = false

# =========================
# Finish / Lap detection
# =========================
func _on_finish_line_entered(body: Node) -> void:
	if body == self and can_detect_finish:
		complete_lap()
		can_detect_finish = false
		await get_tree().create_timer(3.0).timeout
		can_detect_finish = true

func complete_lap():
	var now = Time.get_ticks_msec() / 1000.0
	var this_lap = now - current_lap_start_time
	lap_times.append(this_lap)
	if this_lap < best_lap_time:
		best_lap_time = this_lap
	current_lap += 1
	current_lap_start_time = now
	
	# округляем до двух знаков
	var lap_time_rounded = int(this_lap * 100) / 100.0
	show_message("LAP " + str(current_lap - 1) + " - " + str(lap_time_rounded) + "s", 3.0)
	
	if current_lap > total_laps:
		_finish_race()


func _finish_race() -> void:
	show_message("RACE FINISHED! Total: " + format_total_time(), 6.0)
	speed = 0.0

func format_total_time() -> String:
	var total = Time.get_ticks_msec() / 1000.0 - race_start_time
	var minutes = int(total) / 60
	var seconds = int(total) % 60
	var ms = int((total - int(total)) * 100)
	return "%02d:%02d.%02d" % [minutes, seconds, ms]

# =========================
# ДЕБАГ / ВСПОМОГАТЕЛЬНЫЕ
# =========================
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		print("DEBUG -- speed:", speed, "gear:", current_gear, "rear_slip:", rear_wheel_slip, "rpm_approx:", clamp(abs(speed) / max(1, gear_speeds[current_gear]) , 0.0, 1.2))
