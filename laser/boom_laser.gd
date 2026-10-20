extends ShapeCast2D
@onready var xuli_line: Line2D = $XuliLine
@onready var boom_line: Line2D = $BoomLine
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D

var xuli_speed = 1000
var boom_speed = 4000
var max_length = 1000
var xuli = false
var boom = false
var enemy_array = []

func _ready() -> void:
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	global_position = get_tree().current_scene.player.global_position
	if xuli:
		look_at(get_global_mouse_position())
		if xuli_line.points[1].x <= max_length:
			xuli_line.points[1].x += xuli_speed * delta
	if boom:
		if target_position.x <= xuli_line.points[1].x:
			target_position.x += boom_speed * delta
			boom_line.points[1].x = target_position.x
			gpu_particles_2d.process_material.emission_shape_offset.x\
			= boom_line.points[1].x
			gpu_particles_2d.emitting = true
			if get_collider(0) != null and get_collider(0).has_meta("is_enemy"):
				enemy_array.append(get_collider(0))
				get_collider(0).hurt_by_boom_laser()
		else:
			animation_player.play("fade")
			gpu_particles_2d.emitting = false
			boom = false

func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	reparent(get_tree().current_scene.player)
	get_parent().is_shooting = false
	gpu_particles_2d.restart()
	gpu_particles_2d.emitting = false
	gpu_particles_2d.process_material.emission_shape_offset.x = 0
	target_position.x = 0
	xuli_line.points[1].x = 0
	xuli_line.width = 40
	boom_line.points[1].x = 0
	boom_line.width = 50
	
	for i in enemy_array.size():
		if enemy_array[i] != null:
			enemy_array[i].collision_shape_2d.disabled = false
	set_physics_process(false)
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
