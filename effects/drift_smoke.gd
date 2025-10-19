extends CPUParticles2D
func _ready() -> void:
	# Автоматическое удаление после завершения
	emitting = true
	one_shot = true
	await get_tree().create_timer(lifetime * 1.5).timeout
	queue_free()
