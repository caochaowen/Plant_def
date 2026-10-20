extends RayCast2D
@onready var line_2d: Line2D = $Line2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
var speed = 8000
var max_length = 8000
var travel_distance : float
var shooting = true
var shoot_direction : Vector2
var multi_laser_scene = preload("res://multi_laser.tscn")

func _physics_process(delta: float) -> void:
	if travel_distance > max_length:
		animation_player.play("fade")
	else:
		if shooting:
			if !is_colliding():
				target_position.x += speed * delta
				line_2d.points[1].x += speed * delta
				travel_distance += speed * delta
			elif is_colliding():
				shooting = false
				animation_player.play("fade")
#激光和敌人碰撞
				if get_collider().has_meta("is_enemy"):
					get_collider().hp -= 10
					travel_distance = max_length
#激光和墙体碰撞
				if !get_collider().has_meta("is_enemy"):
					var reflect_direction = \
					shoot_direction.bounce(get_collision_normal()).normalized()
					var reflect_point = get_collision_point() + reflect_direction
					var look_at_point = reflect_point + reflect_direction * 5
					reflect(reflect_point, look_at_point, travel_distance)
		else:
			target_position.x = global_position.distance_to(get_collision_point())
			line_2d.points[1].x = target_position.x

func reflect(reflect_point, look_at_point, traveled_distance):
	var reflect_laser = multi_laser_scene.instantiate()
	reflect_laser.global_position = reflect_point
	reflect_laser.shoot_direction = look_at_point - reflect_point
	reflect_laser.look_at(look_at_point)
	reflect_laser.travel_distance = traveled_distance
	get_parent().add_child(reflect_laser)
	
func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	if travel_distance >= max_length:
		get_tree().current_scene.player.is_shooting = false
	queue_free()
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
