extends CharacterBody2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var hp_bar: ProgressBar = $HpBar
var hp = 200
var speed = 400
@export var move_direction : String


func _physics_process(delta: float) -> void:
	hp_bar.value = hp
	if hp <= 0:
		queue_free()
	if move_direction == "left_right":
		velocity.x = speed
	if move_direction == "up_down":
		velocity.y = speed
	move_and_slide()


func hurt_by_boom_laser():
	hp -= 20
	collision_shape_2d.disabled = true


func _on_timer_timeout() -> void:
	speed = -speed
