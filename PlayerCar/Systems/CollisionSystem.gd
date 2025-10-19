class_name CollisionSystem
extends Node

# Настройки столкновений
@export_group("Collision Settings")
@export var collision_speed_loss: float = 0.7
@export var lateral_collision_speed_loss: float = 0.4
@export var min_collision_speed: float = 50.0
@export var collision_rotation_effect: float = 0.12

# Текущее состояние
var was_colliding: bool = false
var collision_timer: float = 0.0

# Сигналы
signal collision_occurred(collision_speed: float, collision_type: String)

# Ссылки
var car_node: CharacterBody2D
var movement_system: CarMovement

func initialize(car: CharacterBody2D, movement_ref: CarMovement) -> void:
	car_node = car
	movement_system = movement_ref

func handle_collisions() -> void:
	var collision_count = car_node.get_slide_collision_count()
	
	if collision_count <= 0:
		# Сбрасываем состояние столкновения
		if was_colliding:
			collision_timer -= get_physics_process_delta_time()
			if collision_timer <= 0:
				was_colliding = false
		return

	for i in range(collision_count):
		var collision = car_node.get_slide_collision(i)
		if collision == null:
			continue
			
		var collision_speed = _get_collision_speed(collision)
		if collision_speed < min_collision_speed:
			continue

		# Классифицируем тип столкновения
		var collision_type = _classify_collision(collision)
		
		# Обрабатываем в зависимости от типа
		match collision_type:
			"front":
				_handle_front_collision(collision, collision_speed)
			"rear":
				_handle_rear_collision(collision, collision_speed)
			"side":
				_handle_side_collision(collision, collision_speed)
		
		# Отправляем сигнал
		collision_occurred.emit(collision_speed, collision_type)
		
		was_colliding = true
		collision_timer = 0.4

func _get_collision_speed(collision: KinematicCollision2D) -> float:
	# Пытаемся получить относительную скорость
	if collision.has_method("get_relative_velocity"):
		var rel_vel = collision.get_relative_velocity()
		if rel_vel is Vector2:
			return rel_vel.length()
	
	# Fallback на обычную скорость
	return movement_system.get_abs_speed()

func _classify_collision(collision: KinematicCollision2D) -> String:
	var normal = collision.get_normal()
	var forward = movement_system.get_forward_vector()
	var angle = abs(normal.angle_to(forward))
	
	if angle < PI/4:
		return "front"
	elif angle > 3.0 * PI / 4.0:
		return "rear"
	else:
		return "side"

func _handle_front_collision(collision: KinematicCollision2D, collision_speed: float) -> void:
	var speed_before = movement_system.get_speed()
	var normal = collision.get_normal()
	
	# Потеря скорости
	movement_system.modify_speed(1.0 - collision_speed_loss)
	
	# Отскок
	var bounce = normal * speed_before * 0.25
	car_node.velocity += bounce
	
	# Эффект вращения
	var rotation_effect = sign(normal.cross(movement_system.get_forward_vector())) * collision_rotation_effect * (speed_before / movement_system.max_speed)
	car_node.rotation += rotation_effect

func _handle_rear_collision(collision: KinematicCollision2D, collision_speed: float) -> void:
	# Меньшая потеря скорости при ударе сзади
	movement_system.modify_speed(1.0 - collision_speed_loss * 0.5)

func _handle_side_collision(collision: KinematicCollision2D, collision_speed: float) -> void:
	var speed_before = movement_system.get_speed()
	var normal = collision.get_normal()
	var forward = movement_system.get_forward_vector()
	var angle = abs(normal.angle_to(forward))
	
	var angle_factor = 1.0 - (abs(angle - PI/2.0) / (PI/2.0))
	var speed_loss = lateral_collision_speed_loss * angle_factor
	
	movement_system.modify_speed(1.0 - speed_loss)
	
	# Скольжение
	var slide = normal * speed_before * 0.2 * angle_factor
	car_node.velocity += slide
	
	# Вращение при боковом ударе
	var rotation_effect = sign(normal.cross(forward)) * collision_rotation_effect * 2.0 * (speed_before / movement_system.max_speed) * angle_factor
	car_node.rotation += rotation_effect
