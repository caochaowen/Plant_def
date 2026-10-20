extends Area2D
class_name HitboxComponent
## =============================================================================
## HitboxComponent（攻击碰撞盒 / Area2D）
## -----------------------------------------------------------------------------
## 作用：代表一次攻击的判定区域。由武器/弹丸在攻击时 setup 配置伤害、
##       暴击、击退、来源，并在与 HurtboxComponent 重叠时发出 on_hit_hurtbox
##       通知受伤方。支持 enable/disable 开关监测（近战挥砍时短暂启用）。
## =============================================================================


## 信号：命中了一个受伤盒。参数 hurtbox：被命中的 HurtboxComponent。
## 连接到 Projectile._on_hitbox_component_on_hit_hurtbox 等。
signal on_hit_hurtbox(hurtbox: HurtboxComponent)


## ---------------------------------------------------------------------------
## 运行时变量
## ---------------------------------------------------------------------------

## 本次攻击的伤害值。由 setup 设置。
var damage := 1.0

## 本次攻击是否暴击。由 setup 设置。
var critical := false

## 本次攻击的击退力度。由 setup 设置。
var knockback_power := 0.0

## 攻击来源单位（Node2D，用于计算击退方向等）。由 setup 设置。
var source: Node2D


## 函数说明：开启碰撞监测（使本攻击盒可检测重叠）。
## 被谁调用：MeleeBehavior.execute_attack（挥砍开始时）。
## 调用了：set_deferred()。
func enable() -> void:
	# set_deferred(property, value) 把属性设置推迟到空闲帧执行，避免在物理回调中
	# 直接改监测状态引发警告。monitoring 控制是否检测重叠，monitorable 控制是否可被检测。
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)


## 函数说明：关闭碰撞监测。
## 被谁调用：MeleeBehavior.execute_attack（挥砍结束的 tween 回调）。
## 调用了：set_deferred()。
func disable() -> void:
	# 关闭监测与可被监测，停止本攻击盒的碰撞判定（近战挥砍结束后失效）。
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)


## 函数说明：配置本次攻击盒的参数。
## 被谁调用：
##   - MeleeBehavior.execute_attack
##   - Projectile.set_projectile
## 调用了：无（仅赋值成员）。
func setup(damage: float, critical: bool, knockback: float, source: Node2D) -> void:
	# self.damage 显式用 self 区分成员变量与同名参数，保存伤害值。
	self.damage = damage
	# 保存是否暴击。
	self.critical = critical
	# 保存击退力度。
	knockback_power = knockback
	# 保存攻击来源单位（用于击退方向计算等）。
	self.source = source


## 函数说明：攻击盒重叠到受伤盒时触发，播放音效并发出命中信号。
## 被谁调用：由 Area2D 的 area_entered 信号触发。
## 调用了：SoundManager.play_sound()、on_hit_hurtbox.emit()。
func _on_area_entered(area: Area2D) -> void:
	# `area is HurtboxComponent` 判断重叠对象是否为受伤盒（类型检查），只有命中
	# 受伤盒才处理。
	if area is HurtboxComponent:
		# 播放敌人受击音效。
		SoundManager.play_sound(SoundManager.Sound.ENEMY_HIT)
		# 发出命中信号，把受伤盒传给监听者（如弹丸据此销毁自身）。
		on_hit_hurtbox.emit(area)
