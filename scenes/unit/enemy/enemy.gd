extends Unit
class_name Enemy
## =============================================================================
## Enemy（敌人 / Unit 子类）
## -----------------------------------------------------------------------------
## 作用：敌人单位。在 Unit 基础上增加：向玩家移动（含群体分离的 flock 效果）、
##       朝向翻转、击退处理、死亡动画与死亡信号广播。
## =============================================================================


## 群体分离（flock）推挤力度：用于让同类敌人相互散开，避免堆叠。
@export var flock_push := 20.0


## ---------------------------------------------------------------------------
## 节点引用
## ---------------------------------------------------------------------------

## 视野区域（Area2D），用于检测周围其他敌人以做群体分离。
@onready var vision_area: Area2D = $VisionArea

## 击退计时器（Timer），控制击退效果的持续时间。
@onready var knockback_timer: Timer = $KnockbackTimer


## ---------------------------------------------------------------------------
## 运行时变量
## ---------------------------------------------------------------------------

## 是否允许移动（蓄力/冲锋/死亡时置 false）。
var can_move := true

## 击退方向（单位向量）。
var knockback_dir: Vector2

## 击退力度（标量）。
var knockback_power: float


## 函数说明：每帧处理敌人移动逻辑。
## 被谁调用：由 Godot 引擎每帧调用。
## 调用了：can_move_towards_player()、get_move_direction()、update_rotation()。
func _process(delta: float) -> void:
	# 游戏暂停时冻结敌人行为。
	if Global.game_paused: return

	# 若被禁止移动（蓄力/冲锋/死亡中），跳过移动。
	if not can_move:
		return

	# 若不能朝玩家移动（离太近或玩家无效），跳过移动。
	if not can_move_towards_player():
		return

	# 合成速度向量 =（朝向玩家的方向 + 击退方向 × 击退力度），乘速度与帧时间后累加到位置；
	# 这样击退会和主动移动叠加。
	position += (get_move_direction() + knockback_dir * knockback_power) * stats.speed * delta
	# 更新朝向（翻转精灵）。
	update_rotation()


## 函数说明：计算朝向玩家的移动方向，并叠加群体分离向量。
## 被谁调用：_process。
## 调用了：is_instance_valid()、direction_to()、vision_area.get_overlapping_areas()。
func get_move_direction() -> Vector2:
	# 玩家无效时返回零向量（不移动）。
	if not is_instance_valid(Global.player):
		return Vector2.ZERO

	# direction_to() 返回从自身指向玩家的单位方向向量（长度 1）。
	var direction := global_position.direction_to(Global.player.global_position)
	# get_overlapping_areas() 返回与视野区域重叠的其它 Area2D（即附近敌人）。
	for area: Node2D in vision_area.get_overlapping_areas():
		# 排除自身、且该区域在场景树内（有效）。
		if area != self and area.is_inside_tree():
			# 计算"远离附近敌人"的向量（从敌人指向自己再取负方向）。
			var vector := global_position - area.global_position
			# normalized() 取单位方向；vector.length() 是距离；flock_push 是分离强度。
			# 距离越近，分离力越强（除以距离），推动敌人彼此散开。
			direction += flock_push * vector.normalized() / vector.length()

	# 返回叠加分离后的移动方向。
	return direction


## 函数说明：根据玩家相对位置翻转精灵朝向（水平翻转）。
## 被谁调用：_process。
## 调用了：is_instance_valid()。
func update_rotation() -> void:
	# 玩家无效则返回。
	if not is_instance_valid(Global.player):
		return

	# 取玩家世界坐标。
	var player_pos := Global.player.global_position
	# 判断玩家是否在自身右侧（moving_right）。
	var moving_right := global_position.x < player_pos.x
	# 三元表达式：向右则 scale 设为 (-0.5, 0.5)（水平翻转），否则 (0.5, 0.5)。
	visuals.scale = Vector2(-0.5, 0.5) if moving_right else Vector2(0.5, 0.5)


## 函数说明：判断敌人当前是否应朝玩家移动（玩家有效且距离 > 60）。
## 被谁调用：_process。
## 调用了：is_instance_valid()、distance_to()。
func can_move_towards_player() -> bool:
	# 返回玩家是否有效 且 到玩家的距离是否大于 60（太近则停下不贴脸）。
	return is_instance_valid(Global.player) and\
	global_position.distance_to(Global.player.global_position) > 60


## 函数说明：施加击退，设置击退方向/力度并重启击退计时器。
## 被谁调用：_on_hurtbox_component_on_damaged（受击且攻击带击退时）。
## 调用了：knockback_timer.stop()、reset_knockback()、knockback_timer.start()。
func apply_knockback(knock_dir: Vector2, knock_power: float) -> void:
	# 保存击退方向与力度。
	knockback_dir = knock_dir
	knockback_power = knock_power
	# 若击退计时器正在倒计时（上次击退还没结束），先 stop 再重置，重新施加。
	if knockback_timer.time_left > 0:
		knockback_timer.stop()
		reset_knockback()

	# 启动击退计时器（超时后清除击退）。
	knockback_timer.start()


## 函数说明：清零击退方向与力度。
## 被谁调用：apply_knockback、_on_knockback_timer_timeout。
## 调用了：无。
func reset_knockback() -> void:
	# 击退方向清零、力度清零，停止被击退。
	knockback_dir = Vector2.ZERO
	knockback_power = 0.0


## 函数说明：播放死亡动画后销毁敌人。
## 被谁调用：Spawner.clear_enemies（波末清场）。
## 调用了：anim_player.play()、queue_free()。
func destroy_enemy() -> void:
	# 禁止移动。
	can_move = false
	# 播放 "die" 死亡动画。
	anim_player.play("die")
	# await 等待死亡动画播放完毕（animation_finished 信号）。
	await anim_player.animation_finished
	# 动画结束后释放自身节点。
	queue_free()


## 函数说明：击退计时器超时回调，清除击退效果。
## 被谁调用：由 knockback_timer 超时信号触发。
## 调用了：reset_knockback()。
func _on_knockback_timer_timeout() -> void:
	# 击退持续时间结束，清除击退方向与力度。
	reset_knockback()


## 函数说明：受击回调（重写），先执行基类受击流程，再处理击退。
## 被谁调用：由 HurtboxComponent.on_damaged 信号触发。
## 调用了：super._on_hurtbox_component_on_damaged()、apply_knockback()。
func _on_hurtbox_component_on_damaged(hitbox: HitboxComponent) -> void:
	# super.xxx 调用父类 Unit 的同名方法，先处理格挡/闪白/扣血/伤害文字。
	super._on_hurtbox_component_on_damaged(hitbox)

	# 若本次攻击带击退力度（knockback_power > 0）。
	if hitbox.knockback_power > 0:
		# direction_to 计算从攻击来源指向自身的方向，作为击退方向（远离攻击者）。
		var dir := hitbox.source.global_position.direction_to(global_position)
		# 施加击退。
		apply_knockback(dir, hitbox.knockback_power)


## 函数说明：敌人死亡回调，广播全局敌人死亡信号（触发掉落金币）。
## 被谁调用：由 HealthComponent.on_unit_died 信号触发。
## 调用了：Global.on_enemy_died.emit()。
func _on_health_component_on_unit_died() -> void:
	# 发出全局敌人死亡信号（携带自身），Arena 收到后会在死亡位置掉金币。
	Global.on_enemy_died.emit(self)
