extends Node2D

# UI элементы
var lap_label
var time_label
var speed_label
var notification_label
var notification_timer = 0.0

func _ready():
	create_ui()

func create_ui():
	# Создаем UI элементы
	var ui_container = Control.new()
	ui_container.name = "UIContainer"
	add_child(ui_container)
	
	# Делаем UI поверх всего
	ui_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	
	# Фон
	var background = ColorRect.new()
	background.size = Vector2(300, 120)
	background.position = Vector2(10, 10)
	background.color = Color(0, 0, 0, 0.7)
	ui_container.add_child(background)
	
	# Метки
	lap_label = Label.new()
	lap_label.position = Vector2(20, 20)
	lap_label.add_theme_font_size_override("font_size", 28)
	lap_label.add_theme_color_override("font_color", Color.CYAN)
	ui_container.add_child(lap_label)
	
	time_label = Label.new()
	time_label.position = Vector2(20, 55)
	time_label.add_theme_font_size_override("font_size", 22)
	time_label.add_theme_color_override("font_color", Color.YELLOW)
	ui_container.add_child(time_label)
	
	speed_label = Label.new()
	speed_label.position = Vector2(20, 85)
	speed_label.add_theme_font_size_override("font_size", 20)
	speed_label.add_theme_color_override("font_color", Color.GREEN)
	ui_container.add_child(speed_label)
	
	# Уведомления
	notification_label = Label.new()
	notification_label.position = Vector2(400, 300)
	notification_label.size = Vector2(400, 100)
	notification_label.add_theme_font_size_override("font_size", 36)
	notification_label.add_theme_color_override("font_color", Color.GOLD)
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.visible = false
	ui_container.add_child(notification_label)

func update_ui(lap, total_laps, lap_time, best_time, speed):
	lap_label.text = "🏁 КРУГ: %d/%d" % [lap, total_laps]
	time_label.text = "⏱️ ТЕКУЩЕЕ: %.1fс" % lap_time
	speed_label.text = "🚀 СКОРОСТЬ: %d км/ч" % speed

func show_ui_notification(text, duration = 2.0):
	notification_label.text = text
	notification_label.visible = true
	notification_timer = duration

func _process(delta):
	if notification_timer > 0:
		notification_timer -= delta
		if notification_timer <= 0:
			notification_label.visible = false
