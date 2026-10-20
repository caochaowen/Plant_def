extends WeaponBehavior
class_name RangeBehavior
## =============================================================================
## RangeBehavior（远程攻击行为 / WeaponBehavior 子类）
## -----------------------------------------------------------------------------
## 作用：实现远程武器的射击攻击：从枪口发射一枚弹丸、播放开火音效，
##       并用 Tween 做枪口后坐/回位动画。
## =============================================================================


## 枪口位置（Marker2D），弹丸出生点。
@onready var muzzle: Marker2D = %Muzzle


## 函数说明：执行一次远程射击。
## 被谁调用：Weapon.use_weapon（通过 weapon_behavior.execute_attack 调用）。
## 调用了：create_projectile()、SoundManager.play_sound()、create_tween()、
##        apply_life_steal()、await。
func execute_attack() -> void:
	# 标记武器进入攻击状态。
	weapon.is_attacking = true

	# 发射一枚弹丸。
	create_projectile()
	# 播放开火音效。
	SoundManager.play_sound(SoundManager.Sound.FIRE)

	# 创建补间动画：后坐与回位两段。
	var tween := create_tween()
	# 后坐位置：起始位置 x 减去后坐力 recoil（枪口后缩）。
	var attack_pos := Vector2(weapon.atk_start_pos.x - weapon.data.stats.recoil, weapon.atk_start_pos.y)
	# 第一段：精灵位置后坐（recoil_duration 秒）。
	tween.tween_property(weapon.sprite, "position", attack_pos, weapon.data.stats.recoil_duration)
	# 第二段：精灵位置回到起始位置（recoil_duration 秒）。
	tween.tween_property(weapon.sprite, "position", weapon.atk_start_pos, weapon.data.stats.recoil_duration)
	# 触发吸血判定。
	apply_life_steal()

	# await 等待动画全部完成（tween.finished）。
	await tween.finished
	# 结束攻击状态、重置暴击标志。
	weapon.is_attacking = false
	critical = false


## 函数说明：在枪口位置实例化一枚弹丸并配置速度与攻击参数。
## 被谁调用：execute_attack。
## 调用了：projectile_scene.instantiate()、set_projectile()、get_damage()。
func create_projectile() -> void:
	# 实例化弹丸（用武器数据里的 projectile_scene）。
	var instance := weapon.data.stats.projectile_scene.instantiate() as Projectile
	# 把弹丸加入场景树根节点。
	get_tree().root.add_child(instance)
	# 弹丸初始位置 = 枪口（muzzle）世界坐标。
	instance.global_position = muzzle.global_position

	# 速度方向 = Vector2.RIGHT（右方向）旋转武器当前角度；乘弹速得到速度向量。
	var velocity := Vector2.RIGHT.rotated(weapon.rotation) * weapon.data.stats.projectile_speed
	# 配置弹丸：速度、伤害（get_damage 含暴击）、暴击标志、击退、来源（weapon.get_parent()=玩家）。
	instance.set_projectile(velocity, get_damage(), critical, weapon.data.stats.knockback, weapon.get_parent(),weapon.data.stats.trajectory_type,weapon.closest_target)
	instance.drag_factor = weapon.data.stats.homing_drag_factor
	instance.turn_rate = weapon.data.stats.homing_turn_rate
	instance.bezier_control_multiplier = weapon.data.stats.bezier_control_multiplier
