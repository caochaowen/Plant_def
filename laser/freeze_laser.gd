extends RayCast2D
@onready var line_2d: Line2D = $Line2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var speed = 4000
var max_length = 1000
var shooting = true

func _physics_process(delta: float) -> void:
	if shooting:
		target_position.x += speed * delta
		line_2d.points[1].x += speed * delta
		if get_collider() != null and get_collider().has_meta("is_enemy"):
			get_collider().hp -= 10
			if get_collider().speed >= 100:
				get_collider().speed -= 50
	if target_position.x > max_length:
		shooting = false
		animation_player.play("fade")
	if is_colliding():
		shooting = false
		animation_player.play("fade")
		target_position.x = global_position.distance_to(get_collision_point())
		if line_2d.points[1].x > target_position.x:
			line_2d.points[1].x = target_position.x
	
	
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	get_tree().current_scene.player.is_shooting = false
	queue_free()
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
