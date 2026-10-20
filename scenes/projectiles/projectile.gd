extends Node2D
class_name Projectile
## =============================================================================
## Projectile（弹丸 / Node2D）
## -----------------------------------------------------------------------------
## 作用：远程武器发射的子弹。持有攻击盒（HitboxComponent），按给定速度直线
##       飞行；命中受伤盒或飞出屏幕时销毁自身。
## =============================================================================


## 弹丸携带的攻击盒（HitboxComponent，用于判定命中）。
@export var hitbox: HitboxComponent


# —— 弹道类型（由 WeaponStats 驱动） ——
var trajectory_type: WeaponStats.TrajectoryType = WeaponStats.TrajectoryType.STRAIGHT


## ---------------------------------------------------------------------------
## 运行时变量
## ---------------------------------------------------------------------------

# —— 弹道基础参数 ——
var velocity: Vector2                 # 保留：初始速度向量（向后兼容）
var speed := 1600.0                   # 速度大小（由 velocity 长度初始化）
var direction := Vector2.RIGHT        # 初始朝向（单位向量）
var target: Node2D = null             # 追踪目标（由武器在发射时传入）

# —— 追踪弹道内部状态 ——
var current_velocity := Vector2.ZERO  # 阻尼追踪的当前速度（带惯性）
var drag_factor := 0.15               # 阻尼追踪转向系数
var turn_rate := 0.07                 # 旋转追踪转向速率
var bezier_control_multiplier := 1.7  # 贝塞尔控制点倍率

# —— 贝塞尔曲线状态 ——
var next_point := Vector2.ZERO
var current_time := 0.0


## 函数说明：每帧沿速度方向移动弹丸。
## 被谁调用：由 Godot 引擎每帧调用。
## 调用了：无。
func _process(delta: float) -> void:
	match trajectory_type:
		WeaponStats.TrajectoryType.STRAIGHT:
			_move_straight(delta)
		WeaponStats.TrajectoryType.HOMING_DIRECT:
			_move_homing_direct(delta)
		WeaponStats.TrajectoryType.HOMING_DAMPED:
			_move_homing_damped(delta)
		WeaponStats.TrajectoryType.HOMING_ROTATION:
			_move_homing_rotation(delta)
		WeaponStats.TrajectoryType.BEZIER:
			_move_bezier(delta)


# —— 弹道 1：直线 ——
func _move_straight(delta: float) -> void:
	position += direction * speed * delta


# —— 弹道 2：直接追踪（对应 BezierBullet action2） ——
func _move_homing_direct(delta: float) -> void:
	if not _has_valid_target():
		_move_straight(delta)
		return
	global_position = global_position.move_toward(target.global_position, speed * delta)
	look_at(target.global_position)


# —— 弹道 3：阻尼追踪（对应 BezierBullet action3） ——
func _move_homing_damped(delta: float) -> void:
	if not _has_valid_target():
		_move_straight(delta)
		return
	var desired := global_position.direction_to(target.global_position) * speed
	current_velocity = current_velocity.lerp(desired, drag_factor)
	position += current_velocity * delta
	rotation = current_velocity.angle()


# —— 弹道 4：旋转转向追踪（对应 BezierBullet action4） ——
func _move_homing_rotation(delta: float) -> void:
	if not _has_valid_target():
		_move_straight(delta)
		return
	var target_rot := (target.global_position - global_position).angle()
	rotation = lerp_angle(rotation, target_rot, turn_rate)
	position += Vector2(speed, 0).rotated(rotation) * delta


# —— 弹道 5：贝塞尔曲线（对应 BezierBullet action5） ——
func _move_bezier(delta: float) -> void:
	if not _has_valid_target():
		_move_straight(delta)
		return
	current_time += delta
	var distance := global_position.distance_to(target.global_position)
	var t := minf(current_time / (distance / speed), 1.0)
	var control := direction * speed * bezier_control_multiplier
	next_point = global_position.bezier_interpolate(control, target.global_position, target.global_position, t)
	look_at(next_point)
	global_position = global_position.move_toward(next_point, speed * delta)


# —— 目标有效性检测 ——
func _has_valid_target() -> bool:
	return is_instance_valid(target)

## 函数说明：配置弹丸的速度、朝向与攻击盒参数。
## 被谁调用：
##   - RangeBehavior.create_projectile
##   - ShootingBehavior.shoot
## 调用了：velocity.angle()、hitbox.setup()。
func set_projectile(velocity: Vector2,
	damage: float,
	critical: bool,
	knockback: float,
	unit: Node2D,
	trajectory_type: WeaponStats.TrajectoryType = WeaponStats.TrajectoryType.STRAIGHT,
	target: Node2D = null) -> void:
	# 保存速度向量（供 _process 移动）。
	self.velocity = velocity
	self.speed = velocity.length()
	self.direction = velocity.normalized()
	self.trajectory_type = trajectory_type
	self.target = target
	self.current_velocity = velocity      # 阻尼追踪的初始速度
	# velocity.angle() 返回该向量的方向角（弧度），把弹丸自身旋转到飞行方向，
	# 让贴图朝向与运动方向一致。
	rotation = velocity.angle()
	next_point = global_position
	current_time = 0.0
	# 若存在攻击盒，用传入参数配置它（伤害/暴击/击退/来源单位）。
	if hitbox:
		hitbox.setup(damage, critical, knockback, unit)


## 函数说明：弹丸飞出屏幕时销毁自身。
## 被谁调用：由 VisibleOnScreenNotifier2D 的 screen_exited 信号触发。
## 调用了：queue_free()。
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	# 弹丸离开屏幕后不再需要，释放自身节点。
	queue_free()


## 函数说明：弹丸命中受伤盒时销毁自身。
## 被谁调用：由 hitbox 的 on_hit_hurtbox 信号触发。
## 调用了：queue_free()。
func _on_hitbox_component_on_hit_hurtbox(hurtbox: HurtboxComponent) -> void:
	# 命中目标后子弹立即消失，释放自身节点（伤害已通过 hurtbox 传递）。
	print("碰撞触发")
	queue_free()
