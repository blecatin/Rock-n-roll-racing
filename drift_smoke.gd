extends Node2D

@export var life_time: float = 1.0

func _ready():
	# запускаем эмиссию у вложенного CPUParticles2D
	var particles = $CPUParticles2D
	if particles:
		particles.emitting = true

	# плавное исчезновение ноды целиком
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, life_time)

	await get_tree().create_timer(life_time).timeout
	queue_free()
