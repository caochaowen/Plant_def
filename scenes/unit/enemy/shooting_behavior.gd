extends Node2D
class_name ShootingBehavior
## =============================================================================
## ShootingBehavior（射击行为 / Node2D）
## -----------------------------------------------------------------------------
## 作用：给敌人添加"周期性朝玩家扇形散射弹丸"的行为。冷却结束后朝玩家方向
##       发射一排弹丸（呈扇形展开），射击时短暂禁止移动。
## =============================================================================


## 所属敌人（Enemy）。
@export var enemy: Enemy

## 发射口位置（Marker2D）。
@export var fire_pos: Marker2D

## 射击冷却时间（秒）。
@export var cooldown := 3.0

## 每次散射的弹丸数量。
@export var projectile_count := 3

## 散射扇形总角度（度）。
@export var arc_angle := 45.0

## 弹丸场景（PackedScene）。
@export var projectile_scene: PackedScene

## 弹丸飞行速度（像素/秒）。
@export var projectile_speed := 1800.0


## ---------------------------------------------------------------------------
## 运行时变量
## ---------------------------------------------------------------------------

## 当前剩余冷却时间（秒）。
var current_cooldown := 0.0


## 函数说明：就绪时把冷却设为满值。
## 被谁调用：由 Godot 引擎在节点进入场景树时调用。
## 调用了：无。
func _ready() -> void:
	# 初始冷却满值，避免一出生立即射击。
	current_cooldown = cooldown


## 函数说明：每帧处理射击冷却。
## 被谁调用：由 Godot 引擎每帧调用。
## 调用了：shoot()。
func _process(delta: float) -> void:
	# 游戏暂停时冻结。
	if Global.game_paused: return

	# 敌人未配置则返回。
	if enemy == null:
		return

	# 冷却倒计时；结束则射击一次并把冷却重置为满值。
	if current_cooldown > 0:
		current_cooldown -= delta
	else:
		shoot()
		current_cooldown = cooldown


## 函数说明：朝玩家方向扇形散射发射一排弹丸，发射期间禁止移动。
## 被谁调用：_process。
## 调用了：direction_to()、deg_to_rad()、projectile_scene.instantiate()、
##        projectile.set_projectile()、get_tree().create_timer()。
func shoot() -> void:
	# 玩家无效则返回（无目标）。
	if not is_instance_valid(Global.player):
		return

	# 射击期间禁止敌人移动（站立射击）。
	enemy.can_move = false

	# 计算指向玩家的单位方向向量。
	var direction := enemy.global_position.direction_to(Global.player.global_position)
	# 扇形起始角 = 负的半个扇形角（让扇形关于玩家方向对称）。
	var start_angle := -arc_angle / 2.0
	# 角度步长 = 扇形总角 / (弹丸数-1)，均匀分布；弹丸数 ≤1 时退化为 0（避免除零）。
	var angle_step := arc_angle / float(projectile_count - 1 if projectile_count > 1 else 0.0)

	# 循环发射 projectile_count 枚弹丸。
	for i in range(projectile_count):
		# 实例化弹丸（Projectile）。
		var projectile := projectile_scene.instantiate() as Projectile
		# 把弹丸加到场景树根节点。
		get_tree().root.add_child(projectile)
		# 弹丸初始位置 = 发射口（fire_pos）的世界坐标。
		projectile.global_position = fire_pos.global_position

		# direction.rotated(角度) 把朝向玩家的方向旋转（扇形展开的第 i 个角度）；
		# deg_to_rad 把角度转弧度。得到该弹丸的方向向量。
		var rotated_direction := direction.rotated(deg_to_rad(start_angle + angle_step * i))
		# 速度 = 方向 × 弹速。
		var velocity := rotated_direction * projectile_speed
		# 配置弹丸：速度、伤害（用敌人 stats.damage）、非暴击、无击退、来源为敌人。
		projectile.set_projectile(velocity, enemy.stats.damage, false, 0, enemy)

	# get_tree().create_timer(1) 创建 1 秒定时器，await 等待 1 秒（射击硬直）。
	await get_tree().create_timer(1).timeout
	# 恢复敌人移动。
	enemy.can_move = true
