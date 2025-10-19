class_name SoundSystem
extends Node

# Настройки звуков
@export_group("Sound Settings")
@export var engine_volume_db: float = -10.0
@export var tire_volume_db: float = -6.0
@export var collision_volume_db: float = 0.0

# Звуковые потоки
@export var engine_loop_path: String = "res://sounds/engine_loop.wav"
@export var tire_squeal_path: String = "res://sounds/tire_squeal.wav"
@export var collision_path: String = "res://sounds/crash.wav"

# Аудиоплееры
var engine_loop_player: AudioStreamPlayer2D
var tire_player: AudioStreamPlayer2D
var collision_player: AudioStreamPlayer2D

# Ссылки
var movement_system: CarMovement
var gearbox_system: GearboxSystem

func initialize(movement_ref: CarMovement, gearbox_ref: GearboxSystem) -> void:
	movement_system = movement_ref
	gearbox_system = gearbox_ref
	_setup_audio_players()

func _setup_audio_players() -> void:
	# ДВИГАТЕЛЬ
	engine_loop_player = AudioStreamPlayer2D.new()
	engine_loop_player.stream = load(engine_loop_path)
	engine_loop_player.volume_db = engine_volume_db
	engine_loop_player.bus = "SFX"
	get_parent().add_child(engine_loop_player)
	
	# ВИЗГ ШИН
	tire_player = AudioStreamPlayer2D.new()
	tire_player.stream = load(tire_squeal_path)
	tire_player.volume_db = tire_volume_db
	tire_player.bus = "SFX"
	get_parent().add_child(tire_player)
	
	# СТОЛКНОВЕНИЯ
	collision_player = AudioStreamPlayer2D.new()
	collision_player.stream = load(collision_path)
	collision_player.volume_db = collision_volume_db
	collision_player.bus = "SFX"
	get_parent().add_child(collision_player)
	
	# ЗАПУСКАЕМ ДВИГАТЕЛЬ
	engine_loop_player.play()

func update(delta: float) -> void:
	_handle_engine_sound(delta)
	_handle_tire_sounds(delta)

func _handle_engine_sound(delta: float) -> void:
	if not movement_system:
		return
	
	var speed = movement_system.get_abs_speed()
	var max_speed = movement_system.max_speed
	var rpm = clamp(speed / max_speed, 0.1, 1.0)
	
	# ПРОСТО МЕНЯЕМ ПИТЧ БЕЗ ПЕРЕКЛЮЧЕНИЙ
	var target_pitch = lerp(0.8, 1.5, rpm)
	engine_loop_player.pitch_scale = lerp(engine_loop_player.pitch_scale, target_pitch, 5.0 * delta)
	
	# ЗАПУСКАЕМ ЗВУК ЕСЛИ ОСТАНОВИЛСЯ
	if not engine_loop_player.playing:
		engine_loop_player.play()
	
	# МЕНЯЕМ ГРОМКОСТЬ ПО СКОРОСТИ
	var target_volume = engine_volume_db + (rpm * 8.0)
	engine_loop_player.volume_db = lerp(engine_loop_player.volume_db, target_volume, 3.0 * delta)

func _handle_tire_sounds(delta: float) -> void:
	if not movement_system:
		return
	
	# Получаем интенсивность дрифта
	var drift_intensity = 0.0
	var car_node = get_parent().get_parent()
	if car_node and car_node.has_method("get_drift_intensity"):
		drift_intensity = car_node.get_drift_intensity()
	
	var abs_speed = movement_system.get_abs_speed()
	
	# Визг шин при дрифте или торможении
	var should_play_tire = (drift_intensity > 0.2 or Input.is_action_pressed("ui_down")) and abs_speed > 50.0
	
	if should_play_tire:
		if not tire_player.playing:
			tire_player.play()
		tire_player.volume_db = tire_volume_db + (drift_intensity * 8.0)
	else:
		if tire_player.playing:
			tire_player.stop()

func _on_collision(collision_speed: float, collision_type: String) -> void:
	if collision_player:
		collision_player.play()
