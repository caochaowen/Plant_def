extends WeaponBehavior
class_name MeleeBehavior
## =============================================================================
## MeleeBehavior（近战攻击行为 / WeaponBehavior 子类）
## -----------------------------------------------------------------------------
## 作用：实现近战武器的挥砍攻击：武器先后坐（recoil）、前伸（attack）、回位
##       （back）三段 Tween 动画，并在前伸阶段启用攻击盒进行判定。
## =============================================================================


## 近战攻击盒（HitboxComponent）。
@export var hitbox: HitboxComponent


## 函数说明：执行一次近战挥砍攻击。
## 被谁调用：Weapon.use_weapon（通过 weapon_behavior.execute_attack 调用）。
## 调用了：create_tween()、hitbox.enable()、hitbox.setup()、get_damage()、
##        apply_life_steal()、hitbox.disable()。
func execute_attack() -> void:
	# 标记武器进入攻击状态（攻击中锁定旋转、不再触发新攻击）。
	weapon.is_attacking = true

	# create_tween() 创建补间动画对象，用于编排挥砍的三段位置动画。
	var tween := create_tween()

	# 后坐位置：起始位置的 x 减去后坐力 recoil（武器先向后缩）。
	var recoil_pos := Vector2(weapon.atk_start_pos.x - weapon.data.stats.recoil, weapon.atk_start_pos.y)
	# 第一段：精灵位置在 recoil_duration 秒内移动到后坐位置。
	tween.tween_property(weapon.sprite, "position", recoil_pos, weapon.data.stats.recoil_duration)

	# 启用攻击盒，并在前伸阶段配置它：
	# get_damage() 计算伤害（含暴击判定）、critical 暴击标志、knockback 击退、
	# weapon.get_parent() 取玩家作为攻击来源。
	hitbox.enable()
	hitbox.setup(get_damage(), critical, weapon.data.stats.knockback, weapon.get_parent())

	# 前伸位置：起始位置的 x 加上最大射程（武器向前挥出）。
	var attack_pos := Vector2(weapon.atk_start_pos.x + weapon.data.stats.max_range, weapon.atk_start_pos.y)
	# 第二段：精灵位置在 attack_duration 秒内移动到前伸位置（此阶段攻击盒判定命中）。
	tween.tween_property(weapon.sprite, "position", attack_pos, weapon.data.stats.attack_duration)

	# 触发吸血判定（命中后按概率回血）。
	apply_life_steal()

	# 第三段：精灵位置在 back_duration 秒内回到起始位置（收招）。
	tween.tween_property(weapon.sprite, "position", weapon.atk_start_pos, weapon.data.stats.back_duration)

	# tween.finished 是动画全部完成的信号；connect 连接一个 lambda 匿名函数，
	# 在动画结束后执行清理：禁用攻击盒、结束攻击状态、重置暴击标志。
	tween.finished.connect(func():
		hitbox.disable()
		weapon.is_attacking = false
		critical = false
	)
