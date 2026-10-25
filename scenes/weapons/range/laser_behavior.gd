extends RangeBehavior
class_name LaserBehavior

## =============================================================================
## LaserBehavior —— 激光武器行为（继承 RangeBehavior）
## -----------------------------------------------------------------------------
## 与普通远程武器唯一区别：create_projectile 不再生成会飞的 Projectile 子弹，
## 而是生成一条 LaserBeam 激光光束（沿武器朝向射出，命中敌人造成伤害）。
## 其余（后坐动画 / 开火音效 / 吸血 / 冷却）沿用 RangeBehavior.execute_attack。
## =============================================================================

## 激光光束场景。
const LASER_BEAM_SCENE = preload("res://scenes/projectiles/projectile_laser_beam.tscn")


## 函数说明：重写父类的 create_projectile，生成激光光束。
## 被谁调用：RangeBehavior.execute_attack（武器每次攻击时）。
func create_projectile() -> void:
	var beam := LASER_BEAM_SCENE.instantiate() as LaserBeam
	get_tree().root.add_child(beam)
	beam.global_position = muzzle.global_position

	# 发射方向 = 武器当前朝向（Vector2.RIGHT 旋转 weapon.rotation）。
	var dir := Vector2.RIGHT.rotated(weapon.rotation)
	beam.fire(
		dir,
		get_damage(),                  # 伤害（含暴击判定，来自 WeaponBehavior.get_damage）
		critical,                      # 本次是否暴击
		weapon.data.stats.knockback,   # 击退力度
		weapon.get_parent(),           # 来源 = 玩家
		weapon.closest_target          # 追踪目标 = 最近敌人
	)
