class_name EffectsSystem
extends Node

# Настройки эффектов
@export_group("Smoke Effects")
@export var drift_smoke_scene: PackedScene
@export var smoke_spawn_interval: float = 0.15
@export var smoke_distance_behind: float = 25.0
@export var smoke_side_offset: float = 14.0

@export_group("Collision Effects")
@export var collision_particles_scene: PackedScene

# Состояние
var smoke_particles: Array = []
var tire_smoke_timer: float = 0.0
var is_emitting_smoke: bool = false

# Ссылки
var movement_system: CarMovement
var drift_system: DriftSystem

func initialize(movement_ref: CarMovement, drift_ref: DriftSystem) -> void:
	movement_system = movement_ref
	drift_system = drift_ref

func update(delta: float) -> void:
	_update_smoke_effects(delta)
	_cleanup_particles()

func _update_smoke_effects(delta: float) -> void:
	var drift_intensity = drift_system.get_drift_intensity()
	var abs_speed = movement_system.get_abs_speed()
	
	# Проверяем условия для дыма
	var should_emit_smoke = (drift_intensity > 0.3 or drift_system.get_brake_slip() > 0.2) and abs_speed > 50.0
	
	if should_emit_smoke:
		tire_smoke_timer += delta
		if tire_smoke_timer > smoke_spawn_interval:
			_spawn_smoke_particles()
			tire_smoke_timer = 0.0
		
		if not is_emitting_smoke:
			is_emitting_smoke = true
	else:
		if is_emitting_smoke:
			is_emitting_smoke = false

func _spawn_smoke_particles() -> void:
	if not drift_smoke_scene:
		return
	
	var car_position = movement_system.get_parent().global_position
	var car_rotation = movement_system.get_parent().rotation
	var car_transform = movement_system.get_parent().transform
	
	# Создаем дым с двух сторон
	var smoke_left = drift_smoke_scene.instantiate()
	var smoke_right = drift_smoke_scene.instantiate()
	
	var parent_node = get_tree().current_scene
	parent_node.add_child(smoke_left)
	parent_node.add_child(smoke_right)
	
	# Позиционируем за машиной
	smoke_left.global_position = car_position - car_transform.x * smoke_distance_behind + car_transform.y * smoke_side_offset
	smoke_right.global_position = car_position - car_transform.x * smoke_distance_behind - car_transform.y * smoke_side_offset
	
	smoke_left.rotation = car_rotation
	smoke_right.rotation = car_rotation
	
	# Запускаем эмиттеры
	if smoke_left is CPUParticles2D:
		smoke_left.emitting = true
	if smoke_right is CPUParticles2D:
		smoke_right.emitting = true
	
	smoke_particles.append(smoke_left)
	smoke_particles.append(smoke_right)

func _cleanup_particles() -> void:
	# Удаляем невалидные частицы
	for i in range(smoke_particles.size() - 1, -1, -1):
		if not is_instance_valid(smoke_particles[i]):
			smoke_particles.remove_at(i)

func _on_drift_started() -> void:
	# Можно добавить дополнительные эффекты при начале дрифта
	pass

func _on_drift_ended() -> void:
	# Можно добавить эффекты при завершении дрифта
	pass

func _on_collision(collision_speed: float, collision_type: String) -> void:
	# Эффекты столкновений
	if collision_particles_scene and collision_speed > 80.0:
		_spawn_collision_particles(collision_type)

func _spawn_collision_particles(collision_type: String) -> void:
	var collision_particles = collision_particles_scene.instantiate()
	var parent_node = get_tree().current_scene
	parent_node.add_child(collision_particles)
	collision_particles.global_position = movement_system.get_parent().global_position
	
	if collision_particles is CPUParticles2D:
		collision_particles.emitting = true
