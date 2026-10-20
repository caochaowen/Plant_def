extends CharacterSkills
class_name KnightSkills
## Brawler 技能：Q 狂暴（临时增伤），E 战吼（范围伤害 + 击退）。


## Q 狂暴：临时提升伤害，5 秒后还原。
func _execute_skill_1() -> void:
	var bonus := 5.0
	player.stats.damage += bonus
	# 5 秒后撤销增益。
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(player):
		player.stats.damage -= bonus


## E 战吼：对周围敌人造成范围伤害并击退。
func _execute_skill_2() -> void:
	# 实例化临时攻击盒，命中敌人 Hurtbox（layer 4 = 值 8）。
	var hitbox := HitboxComponent.new()
	hitbox.collision_mask = 8        # 命中敌人 Hurtbox
	hitbox.monitoring = true
	hitbox.damage = player.stats.damage + 10.0
	hitbox.critical = false
	hitbox.knockback_power = 200.0
	hitbox.source = player

	# 给攻击盒加一个圆形碰撞体，半径 = 技能范围。
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 120.0
	shape.shape = circle
	hitbox.add_child(shape)

	player.add_child(hitbox)
	hitbox.global_position = player.global_position

	# 等一个物理帧完成重叠判定后回收（避免重复命中）。
	await get_tree().physics_frame
	hitbox.queue_free()
