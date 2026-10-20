extends RayCast2D
@onready var line_2d: Line2D = $Line2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D

var speed = 2000
var max_length = 2000
var shooting = false
var fading = true

func _ready() -> void:
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	global_position = get_tree().current_scene.player.global_position
	look_at(get_global_mouse_position())
	if shooting:
		if !is_colliding():
			target_position.x += speed * delta
			line_2d.points[1].x = target_position.x
			gpu_particles_2d.restart()
			gpu_particles_2d.visible = false
		if is_colliding():
			target_position.x = \
			global_position.distance_to(get_collision_point()) + 10
			line_2d.points[1].x = target_position.x - 10
			gpu_particles_2d.global_position = get_collision_point()
			gpu_particles_2d.visible = true
			if get_collider().has_meta("is_enemy"):
				get_collider().hp -= 10 * delta
	if !shooting and !fading:
		fading = true
		animation_player.play("fade")
	if fading:
		if is_colliding():
			target_position.x = \
			global_position.distance_to(get_collision_point()) + 10
			line_2d.points[1].x = target_position.x - 10
			gpu_particles_2d.global_position = get_collision_point()
			gpu_particles_2d.visible = true
	if target_position.x > max_length:
		fading = true
		animation_player.play("fade")

func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	reparent(get_tree().current_scene.player)
	gpu_particles_2d.visible = false
	gpu_particles_2d.restart()
	target_position.x = 0
	line_2d.points[1].x = 0
	line_2d.width = 10
	get_parent().is_shooting = false
	get_parent().can_stop_hot_laser = false
	set_physics_process(false)
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
