extends Line2D
class_name Trail
## =============================================================================
## Trail（拖尾特效 / Line2D）
## -----------------------------------------------------------------------------
## 作用：冲刺时在玩家身后绘制一条拖尾线。冲刺期间每帧把玩家位置追加到
##       点列表（限制长度），形成随时间变短的残影；冲刺结束后清除。
## =============================================================================


## 产生拖尾的玩家（Player）。
@export var player: Player

## 拖尾最多保留的点数量。
@export var trail_length := 25

## 拖尾持续时间（秒，冲刺结束后自动清除的延迟）。
@export var trail_duration := 1.0


## ---------------------------------------------------------------------------
## 节点引用
## ---------------------------------------------------------------------------

## 拖尾计时器（Timer）。
@onready var trail_timer: Timer = %TrailTimer


## ---------------------------------------------------------------------------
## 运行时变量
## ---------------------------------------------------------------------------

## 拖尾的点位置数组（Vector2）。
var points_array: Array[Vector2] = []

## 拖尾是否激活（冲刺中）。
var is_active := false


## 函数说明：每帧更新拖尾线条的点。
## 被谁调用：由 Godot 引擎每帧调用。
## 调用了：points_array.append()、pop_front()。
func _process(delta: float) -> void:
	# 未激活则不做任何事。
	if not is_active:
		return

	# 把玩家当前位置追加到点数组末尾。
	points_array.append(player.global_position)
	# 若点数超过最大长度，pop_front() 移除最旧的点，保持拖尾长度恒定。
	if points_array.size() > trail_length:
		points_array.pop_front()

	# 把点数组赋给 Line2D 的 points 属性，更新线条显示。
	points = points_array


## 函数说明：开始拖尾：清空旧点、激活并启动计时器。
## 被谁调用：Player.start_dash。
## 调用了：clear_points()、trail_timer.start()。
func start_trail() -> void:
	# 激活拖尾。
	is_active = true
	# clear_points() 清空 Line2D 当前绘制的点，points_array.clear() 清空数组。
	clear_points()
	points_array.clear()
	# 启动拖尾计时器（trail_duration 秒后自动停止拖尾）。
	trail_timer.start(trail_duration)


## 函数说明：拖尾计时器超时回调，停止拖尾并清除线条。
## 被谁调用：由 trail_timer 超时信号触发。
## 调用了：clear_points()。
func _on_trail_timer_timeout() -> void:
	# 停止拖尾，并清空线条与点数组。
	is_active = false
	clear_points()
	points_array.clear()
