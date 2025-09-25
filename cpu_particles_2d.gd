extends CPUParticles2D

@export var life_time := 1.0

func _ready():
	emitting = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, life_time)
	await get_tree().create_timer(life_time).timeout
	queue_free()
