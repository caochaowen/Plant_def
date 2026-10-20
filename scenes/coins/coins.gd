extends Area2D
class_name Coins
## =============================================================================
## Coins（金币 / Area2D）
## -----------------------------------------------------------------------------
## 作用：地上的一枚金币。支持两种拾取方式：
##   1. 玩家走近触发 area_entered → 设置 collected，金币开始追踪玩家飞过去；
##   2. 波末由 Arena 设置屏幕收集目标，金币飞向金币袋 UI 位置。
## 到达目标/玩家附近后调用 add_coins 累加金币并销毁自身。
## =============================================================================


## ---------------------------------------------------------------------------
## 导出字段
## ---------------------------------------------------------------------------

## 金币移动速度（追踪目标时的飞行速度，像素/秒）。
@export var move_speed := 1000.0

## 收集判定距离（离目标/玩家多近时算"捡到"）。
@export var collect_distance := 15.0


## ---------------------------------------------------------------------------
## 运行时变量
## ---------------------------------------------------------------------------

## 金币面值（掉落多少金币）。由 Arena.spawn_coins 设置。
var value := 1

## 屏幕坐标收集目标（Vector2.INF 表示未设置，来自波末 UI 收集）。
var target_screen_pos := Vector2.INF

## 世界坐标目标位置（追踪玩家或换算后的收集目标）。
var target_pos: Vector2

## 是否已被玩家触碰（进入收集状态）。
var collected := false


## 函数说明：每帧更新金币移动与收集判定。
## 被谁调用：由 Godot 引擎每帧调用。
## 调用了：is_instance_valid()、get_canvas_transform().affine_inverse()、
##        move_toward()、distance_to()、add_coins()。
func _process(delta: float) -> void:
	# 情况一：已被玩家触碰（collected）且还没有设置屏幕收集目标（波末收集）时，
	# 说明它是被玩家吸引过去，目标应是玩家当前位置。
	if collected and target_screen_pos == Vector2.INF:
		# 玩家有效时，把追踪目标设为玩家世界坐标。
		if is_instance_valid(Global.player):
			target_pos = Global.player.global_position

	# 情况二：已设置屏幕收集目标（波末飞向金币袋 UI）。
	if target_screen_pos != Vector2.INF:
		# get_canvas_transform() 返回当前画布（Canvas）的变换矩阵；
		# affine_inverse() 取其逆矩阵，用它左乘屏幕坐标，把屏幕坐标换算成世界坐标，
		# 得到金币在世界空间里要飞往的位置。
		target_pos = get_canvas_transform().affine_inverse() * target_screen_pos

	# 若已有一个非零的目标位置，向它移动。
	if target_pos != Vector2.ZERO:
		# move_toward(to, delta) 让 global_position 朝 target_pos 移动，但单步最多移动
		# move_speed * delta 距离（按帧时间换算的步长），返回移动后的新位置。
		global_position = global_position.move_toward(target_pos, move_speed * delta)

	# distance_to(target_pos) 计算当前位置到目标的距离；若小于收集判定距离，视为捡到。
	if global_position.distance_to(target_pos) < collect_distance:
		add_coins()


## 函数说明：把金币面值累加到全局金币并销毁自身。
## 被谁调用：_process（到达收集点）。
## 调用了：queue_free()。
func add_coins() -> void:
	# 把本枚金币面值 value 累加到全局金币总数。
	Global.coins += value
	# queue_free() 把本节点标记为待删除（本帧末尾安全释放）。
	queue_free()


## 函数说明：设置屏幕坐标收集目标（波末飞向金币袋 UI）。
## 被谁调用：Arena.clean_arena。
## 调用了：无。
func set_collection_target(screen_pos: Vector2) -> void:
	# 把传入的屏幕坐标保存到 target_screen_pos，供 _process 换算成世界坐标追踪。
	target_screen_pos = screen_pos


## 函数说明：玩家（或其他拾取区域）进入金币区域时，标记为已收集。
## 被谁调用：由 Area2D 的 area_entered 信号触发。
## 调用了：无。
func _on_area_entered(area: Area2D) -> void:
	# 置 collected = true，表示金币已被触发收集，下帧 _process 会开始追踪玩家。
	collected = true
