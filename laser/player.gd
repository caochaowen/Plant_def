extends CharacterBody2D
var speed = 300
var direction = 0
var state = 0
var is_shooting = false
var can_stop_hot_laser = false
var can_boom = false
var freeze_laser_scene = preload("res://freeze_laser.tscn")
var multi_laser_scene = preload("res://multi_laser.tscn")
@onready var hot_laser: RayCast2D = $HotLaser
@onready var hot_laser_timer: Timer = $HotLaserTimer
@onready var boom_laser: ShapeCast2D = $BoomLaser
@onready var boom_laser_timer: Timer = $BoomLaserTimer


func _physics_process(delta: float) -> void:
	direction = Input.get_axis("left","right")
	velocity.x = speed * direction
	if velocity.y < 1200:
		velocity.y += 1200 * delta
	move_and_slide()

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = -900
	if !is_shooting:
		if Input.is_action_just_pressed("state1"):
			state = 1
		if Input.is_action_just_pressed("state2"):
			state = 2
		if Input.is_action_just_pressed("state3"):
			state = 3
		if Input.is_action_just_pressed("state4"):
			state = 4
		if Input.is_action_just_pressed("shoot"):
			if state == 1:
				is_shooting = true
				var freeze_laser = freeze_laser_scene.instantiate()
				freeze_laser.global_position = global_position
				freeze_laser.look_at(get_global_mouse_position())
				get_parent().glow_layer.add_child(freeze_laser)
			if state == 2:
				is_shooting = true
				var multi_laser = multi_laser_scene.instantiate()
				multi_laser.global_position = global_position
				multi_laser.travel_distance = 0
				multi_laser.look_at(get_global_mouse_position())
				multi_laser.shoot_direction = \
				(get_global_mouse_position() - global_position).normalized()
				get_parent().glow_layer.add_child(multi_laser)
			if state == 3:
				is_shooting = true
				hot_laser.shooting = true
				hot_laser.fading = false
				hot_laser.set_physics_process(true)
				hot_laser.reparent(get_parent().glow_layer)
				hot_laser_timer.start()
			if state == 4:
				is_shooting = true
				boom_laser.xuli = true
				boom_laser.set_physics_process(true)
				boom_laser.reparent(get_parent().glow_layer)
				boom_laser_timer.start()
	if is_shooting:
		if Input.is_action_just_pressed("shoot"):
			if state == 3 and can_stop_hot_laser:
				hot_laser.shooting = false
				can_stop_hot_laser = false
			if state == 4 and can_boom:
				boom_laser.boom = true
				boom_laser.xuli = false
				can_boom = false
	
func _on_hot_laser_timer_timeout() -> void:
	can_stop_hot_laser = true
	
func _on_boom_laser_timer_timeout() -> void:
	can_boom = true
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
