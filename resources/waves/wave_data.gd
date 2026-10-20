extends Resource
class_name WaveData
## =============================================================================
## WaveData（波次数据 / Resource）
## -----------------------------------------------------------------------------
## 作用：描述一个（或一段）波次的配置：生效的波数范围、波时长、可刷出的单位
##       列表及权重、以及刷怪模式（固定间隔/随机间隔）。
## 由 Spawner 根据当前 wave_index 查找并驱动刷怪。
## =============================================================================


## ---------------------------------------------------------------------------
## 刷怪模式枚举
## ---------------------------------------------------------------------------
## 刷怪模式：FIXED（固定间隔刷怪）/ RANDOM（随机间隔刷怪）。
enum SpawnType {
	FIXED,
	RANDOM
}


## ---------------------------------------------------------------------------
## 导出字段
## ---------------------------------------------------------------------------

## 本波数据生效的起始波数（含）。
@export var from: int

## 本波数据生效的结束波数（含）。
@export var to: int

## 本波持续时长（秒）。由 Spawner.start_wave 设为 wave_timer.wait_time。
@export var wave_time := 20.0

## 可刷出的单位列表（WaveUnitData：场景 + 权重）。
@export var units: Array[WaveUnitData]

## 刷怪模式（FIXED / RANDOM）。
@export var spawn_type := SpawnType.RANDOM

## FIXED 模式下的固定刷怪间隔（秒）。
@export var fixed_spawn_time := 1.0

## RANDOM 模式下的最短刷怪间隔（秒）。
@export var min_spawn_time := 1.0

## RANDOM 模式下的最长刷怪间隔（秒）。
@export var max_spawn_time := 1.0


## 函数说明：按权重随机返回一个单位场景（PackedScene）。
## 被谁调用：Spawner.spawn_enemy（刷怪时取随机敌人）。
## 调用了：RandomNumberGenerator.new()、rand_weighted()、printerr()。
func get_random_unit_scene() -> PackedScene:
	# 若本波没有配置任何单位，打印错误日志并返回 null，调用方会据此跳过刷怪。
	if units.is_empty():
		printerr("No Units.")
		return null

	# enemies 收集所有敌人的场景（PackedScene），weights 收集对应的权重值。
	var enemies: Array[PackedScene]
	var weights: Array[float]

	# 遍历 units（每个 unit 是 WaveUnitData），把场景与权重分别压入两个数组。
	for unit in units:
		enemies.append(unit.unit_scene)
		weights.append(unit.weight)

	# RandomNumberGenerator 是 Godot 的随机数生成器类，new() 创建一个实例。
	var rng := RandomNumberGenerator.new()
	# rand_weighted(weights) 根据权重数组返回一个随机索引（权重越大越易被选中），
	# 用该索引从 enemies 取出对应的敌人场景。
	var random_unit = enemies[rng.rand_weighted(weights)]
	# 返回随机选中的敌人场景。
	return random_unit


## 函数说明：判断给定波数 index 是否落在本波数据生效范围内 [from, to]。
## 被谁调用：Spawner.find_wave_data（查找当前波对应的数据）。
## 调用了：无（仅比较 index 与 from/to）。
func is_valid_index(index: int) -> bool:
	# 返回 index 是否在闭区间 [from, to] 内：>= from 且 <= to。
	return index >= from and index <= to
