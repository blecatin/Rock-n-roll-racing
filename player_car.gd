extends CharacterBody2D
class_name PlayerCar

# Системы
@onready var movement_system: CarMovement = $Systems/CarMovement
@onready var gearbox_system: GearboxSystem = $Systems/GearboxSystem
@onready var drift_system: DriftSystem = $Systems/DriftSystem
@onready var collision_system: CollisionSystem = $Systems/CollisionSystem
@onready var sound_system: SoundSystem = $Systems/SoundSystem
@onready var race_system: RaceSystem = $Systems/RaceSystem
@onready var effects_system: EffectsSystem = $Systems/EffectsSystem
@onready var ui_system: RaceUI = $UI/RaceUI

# Ссылки на компоненты - УБИРАЕМ @onready, делаем безопасными
var car_body: Node2D
var collision_shape: CollisionShape2D

func _ready() -> void:
	# НАХОДИМ КОМПОНЕНТЫ БЕЗОПАСНО
	_find_components()
	
	# Подключаем сигналы между системами
	_setup_connections()
	
	# Инициализируем системы
	movement_system.initialize(self)
	gearbox_system.initialize(movement_system)
	drift_system.initialize(movement_system)
	collision_system.initialize(self, movement_system)
	sound_system.initialize(movement_system, gearbox_system)
	effects_system.initialize(movement_system, drift_system)
	race_system.initialize()
	ui_system.initialize(movement_system, gearbox_system, race_system)

func _find_components() -> void:
	# БЕЗОПАСНЫЙ ПОИСК КОМПОНЕНТОВ
	car_body = get_node("CarBody") if has_node("CarBody") else null
	collision_shape = get_node("CarBody/CollisionShape2D") if has_node("CarBody/CollisionShape2D") else null
	
	if not car_body:
		print("⚠️ CarBody not found - creating fallback")
		car_body = Node2D.new()
		car_body.name = "CarBody"
		add_child(car_body)
	
	if not collision_shape:
		print("⚠️ CollisionShape2D not found - creating fallback")
		collision_shape = CollisionShape2D.new()
		collision_shape.shape = RectangleShape2D.new()
		car_body.add_child(collision_shape)

func _setup_connections() -> void:
	# Сигналы столкновений
	collision_system.collision_occurred.connect(sound_system._on_collision)
	collision_system.collision_occurred.connect(effects_system._on_collision)
	
	# Сигналы дрифта
	drift_system.drift_started.connect(effects_system._on_drift_started)
	drift_system.drift_ended.connect(effects_system._on_drift_ended)
	
	# Сигналы гонки
	race_system.lap_completed.connect(ui_system._on_lap_completed)
	race_system.race_finished.connect(ui_system._on_race_finished)

func _physics_process(delta: float) -> void:
	# Обновляем системы в правильном порядке
	var input = _get_input()
	
	movement_system.update(delta, input)
	gearbox_system.update(delta)
	drift_system.update(delta, input)
	
	# Применяем вычисленную скорость и поворот
	velocity = movement_system.get_final_velocity()
	rotation = movement_system.get_final_rotation(delta)
	
	# Двигаем и обрабатываем столкновения
	move_and_slide()
	collision_system.handle_collisions()
	
	# Обновляем визуальные системы
	sound_system.update(delta)
	effects_system.update(delta)
	race_system.update(delta)
	ui_system.update(delta)
	
	# ОБНОВЛЯЕМ ДЫМ
	_update_drift_smoke(delta)

func _get_input() -> Dictionary:
	return {
		"throttle": Input.is_action_pressed("ui_up"),
		"brake": Input.is_action_pressed("ui_down"), 
		"steer": Input.get_axis("ui_left", "ui_right")
	}

# Публичные геттеры для систем
func get_car_body() -> Node2D:
	return car_body

func get_collision_shape() -> CollisionShape2D:
	return collision_shape

func get_drift_intensity() -> float:
	if drift_system:
		return drift_system.get_drift_intensity()
	return 0.0

# =========================
# СИСТЕМА ДЫМА
# =========================
var drift_smoke_effect: PackedScene
var smoke_particles: Array = []
var tire_smoke_timer: float = 0.0

func _update_drift_smoke(delta: float) -> void:
	# ДЫМ ПРИ ДРИФТЕ ИЛИ ТОРМОЖЕНИИ
	var drift_intensity = get_drift_intensity()
	if (drift_intensity > 0.3 or Input.is_action_pressed("ui_down")) and abs(movement_system.speed) > 50.0:
		tire_smoke_timer += delta
		if tire_smoke_timer > 0.12:
			_spawn_smoke_particle()
			tire_smoke_timer = 0.0

	# ОЧИСТКА УДАЛЕННЫХ ЧАСТИЦ
	for i in range(smoke_particles.size() - 1, -1, -1):
		if not is_instance_valid(smoke_particles[i]):
			smoke_particles.remove_at(i)

func _spawn_smoke_particle() -> void:
	if drift_smoke_effect == null:
		# Пытаемся загрузить сцену дыма
		drift_smoke_effect = load("res://effects/drift_smoke.tscn")
		if drift_smoke_effect == null:
			return
	
	var smoke_left = drift_smoke_effect.instantiate()
	var smoke_right = drift_smoke_effect.instantiate()
	
	# Добавляем в мир
	get_parent().add_child(smoke_left)
	get_parent().add_child(smoke_right)
	
	# Позиция за машиной
	var distance_behind = 80
	var wheel_offset = 25
	
	smoke_left.global_position = global_position - transform.x * distance_behind + transform.y * wheel_offset
	smoke_right.global_position = global_position - transform.x * distance_behind - transform.y * wheel_offset
	
	smoke_left.rotation = rotation
	smoke_right.rotation = rotation
	
	smoke_particles.append(smoke_left)
	smoke_particles.append(smoke_right)
