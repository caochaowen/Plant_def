extends Node2D
class_name ChargeBehavior
## =============================================================================
## ChargeBehavior（冲锋行为 / Node2D）
## -----------------------------------------------------------------------------
## 作用：给敌人添加"蓄力后朝玩家冲锋"的行为。流程：冷却结束 → 记录玩家位置
##       → 播放蓄力动画（禁移动）→ 高速冲向记录点 → 到达后结束冲锋并进入冷却。
## =============================================================================


## 所属敌人（Enemy）。
@export var enemy: Enemy

## 蓄力/冲锋动画播放器（AnimationPlayer）。
@export var anim_effects: AnimationPlayer

## 蓄力（准备）时间（秒）。
@export var prep_time := 1.0

## 冲锋冷却时间（秒）。
@export var cooldown := 3.0


## ---------------------------------------------------------------------------
## 运行时变量
## ---------------------------------------------------------------------------

## 当前剩余冷却时间（秒）。
var current_cooldown := 0.0

## 冲锋目标位置（玩家位置，冲锋开始时记录）。
var charge_attack_position := Vector2.ZERO

## 是否正在冲锋。
var is_charging := false


## 函数说明：就绪时把冷却设为满值。
## 被谁调用：由 Godot 引擎在节点进入场景树时调用。
## 调用了：无。
func _ready() -> void:
	# 初始冷却设为满值，避免一出生立即冲锋。
	current_cooldown = cooldown


## 函数说明：每帧处理冲锋状态机。
## 被谁调用：由 Godot 引擎每帧调用。
## 调用了：move_toward()、distance_to()、end_charge()、start_charge()。
func _process(delta: float) -> void:
	# 敌人为空则返回（未配置）。
	if enemy == null:
		return

	# 状态一：正在冲锋。
	if is_charging:
		# move_toward(目标, 步长) 让敌人朝冲锋目标点移动，步长 = 5 倍敌人速度 × 帧时间
		# （冲锋比正常移动快 5 倍）。
		enemy.global_position = enemy.global_position.move_toward(charge_attack_position, (enemy.stats.speed * 5) * delta)

		# 若离目标点不足 50 像素，视为到达，结束冲锋。
		if enemy.global_position.distance_to(charge_attack_position) < 50:
			end_charge()
	# 状态二：未在冲锋，处于冷却或待命。
	else:
		# 冷却倒计时中，逐帧减少剩余冷却。
		if current_cooldown > 0:
			current_cooldown -= delta
		# 冷却结束且玩家有效时，发起冲锋。
		else:
			if is_instance_valid(Global.player):
				# 记录玩家当前位置作为冲锋目标点（冲锋是朝记录点直线冲）。
				charge_attack_position = Global.player.global_position
				# 开始冲锋。
				start_charge()


## 函数说明：开始冲锋：禁移动、播放蓄力动画，动画结束后进入冲锋状态。
## 被谁调用：_process（冷却结束且玩家有效时）。
## 调用了：anim_effects.play()、await。
func start_charge() -> void:
	# 冲锋/蓄力期间禁止敌人普通移动。
	enemy.can_move = false
	# 播放 "charge" 蓄力动画。
	anim_effects.play("charge")
	# await 等待蓄力动画播放完毕（animation_finished 信号）。
	await anim_effects.animation_finished
	# 蓄力结束，进入真正冲锋状态。
	is_charging = true


## 函数说明：结束冲锋：退出冲锋状态、重置冷却、恢复移动。
## 被谁调用：_process（到达目标点）。
## 调用了：无。
func end_charge() -> void:
	# 退出冲锋状态。
	is_charging = false
	# 冷却重置为满值（开始下一轮冷却）。
	current_cooldown = cooldown
	# 恢复敌人移动能力。
	enemy.can_move = true
