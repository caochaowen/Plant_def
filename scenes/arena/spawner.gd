extends Node2D
class_name Spawner
## =============================================================================
## Spawner（刷怪器 / Node2D）
## -----------------------------------------------------------------------------
## 作用：管理波次刷怪的核心。负责：
##   - 根据当前波数查找对应波次数据；
##   - 用刷怪定时器按固定/随机间隔刷敌人；
##   - 用波计时器控制整波时长，波末触发结算；
##   - 敌人按波成长的属性更新、清理敌人、提供 UI 显示文本。
## =============================================================================


## 信号：一波结束（波计时器超时）时发出。
## 连接到 Arena._on_spawner_on_wave_completed。
signal on_wave_completed


## ---------------------------------------------------------------------------
## 导出字段
## ---------------------------------------------------------------------------

## 刷怪区域尺寸（从中心向四周 ±spawn_area_size 的矩形随机取点）。
@export var spawn_area_size := Vector2(1000, 500)

## 所有波次数据（WaveData 数组），按波数范围覆盖各波。
@export var waves_data: Array[WaveData]

## 敌人属性集合（UnitStats 数组），每波结束时统一增长其生命/伤害。
@export var enemy_collection: Array[UnitStats]


## ---------------------------------------------------------------------------
## 节点引用
## ---------------------------------------------------------------------------

## 刷怪间隔定时器（Timer），超时触发刷一只敌人。
@onready var spawn_timer: Timer = $SpawnTimer

## 波次总时长定时器（Timer），超时触发波末结算。
@onready var wave_timer: Timer = $WaveTimer


## ---------------------------------------------------------------------------
## 运行时变量
## ---------------------------------------------------------------------------

## 当前波数（初始为 1）。由 Arena.start_new_wave 递增。
var wave_index := 1

## 当前波对应的数据（WaveData）。
var current_wave_data: WaveData

## 当前已刷出的、仍在场的敌人列表（Enemy）。
var spawned_enemies: Array[Enemy] = []


## 函数说明：查找并返回覆盖当前波数的波次数据。
## 被谁调用：start_wave。
## 调用了：wave.is_valid_index()。
func find_wave_data() -> WaveData:
	# 遍历所有波次数据。
	for wave in waves_data:
		# `wave` 判空，且调用 wave.is_valid_index(wave_index) 判断当前波数是否落在
		# 该波数据声明的 [from, to] 区间内；是则返回这个波数据。
		if wave and wave.is_valid_index(wave_index):
			return wave
	# 没找到覆盖当前波数的数据，返回 null。
	return null


## 函数说明：启动当前波：设置波时长并启动刷怪定时器。
## 被谁调用：
##   - Arena._on_selection_panel_on_selection_completed（开始第一波）
##   - Arena.start_new_wave（后续每波）
## 调用了：find_wave_data()、set_spawn_timer()、printerr()。
func start_wave() -> void:
	# 查找当前波对应的数据。
	current_wave_data = find_wave_data()
	# 若没有有效波数据，打印错误、停止两个定时器并返回（本轮不刷怪）。
	if not current_wave_data:
		printerr("No valid wave.")
		spawn_timer.stop()
		wave_timer.stop()
		return

	# 把波计时器的等待时长设为波数据的 wave_time（本波总时长），并 start() 开始倒计时。
	wave_timer.wait_time = current_wave_data.wave_time
	wave_timer.start()

	# 配置并启动刷怪间隔定时器。
	set_spawn_timer()


## 函数说明：根据波次数据的刷怪模式配置刷怪定时器的间隔并启动。
## 被谁调用：start_wave、spawn_enemy（每次刷怪后重新设置下一次间隔）。
## 调用了：randf_range()。
func set_spawn_timer() -> void:
	# match 按刷怪模式分派：
	match current_wave_data.spawn_type:
		# FIXED 模式：间隔固定为 fixed_spawn_time。
		WaveData.SpawnType.FIXED:
			spawn_timer.wait_time = current_wave_data.fixed_spawn_time
		# RANDOM 模式：间隔在 min_spawn_time ~ max_spawn_time 之间随机取值。
		WaveData.SpawnType.RANDOM:
			var min_t := current_wave_data.min_spawn_time
			var max_t := current_wave_data.max_spawn_time
			spawn_timer.wait_time = randf_range(min_t, max_t)

	# 若刷怪定时器当前处于停止状态，则 start() 启动它（开始按设定间隔触发刷怪）。
	if spawn_timer.is_stopped():
		spawn_timer.start()


## 函数说明：在刷怪区域内随机返回一个生成位置。
## 被谁调用：spawn_enemy。
## 调用了：randf_range()。
func get_random_spawn_position() -> Vector2:
	# randf_range(-spawn_area_size.x, spawn_area_size.x) 在水平方向 ±宽度 内随机取 x。
	var random_x := randf_range(-spawn_area_size.x, spawn_area_size.x)
	# 同理在垂直方向 ±高度 内随机取 y。
	var random_y := randf_range(-spawn_area_size.y, spawn_area_size.y)
	# 组合成随机生成位置向量（相对于刷怪器中心）。
	return Vector2(random_x, random_y)


## 函数说明：刷一只敌人（带出生特效）。
## 被谁调用：_on_spawn_timer_timeout。
## 调用了：current_wave_data.get_random_unit_scene()、get_random_spawn_position()、
##        Global.SPAWN_EFFECT_SCENE.instantiate()、set_spawn_timer()。
func spawn_enemy() -> void:
	# 从当前波数据按权重随机取一个敌人场景（PackedScene）。
	var enemy_scene := current_wave_data.get_random_unit_scene() as PackedScene
	# 若有可用敌人场景才继续刷。
	if enemy_scene:
		# 取一个随机生成位置。
		var spawn_pos := get_random_spawn_position()

		# 实例化出生特效场景并加到父节点（Arena），定位到生成点。
		var spawn_anim := Global.SPAWN_EFFECT_SCENE.instantiate()
		get_parent().add_child(spawn_anim)
		spawn_anim.global_position = spawn_pos
		# await 特效的动画播放器 animation_finished 信号，即等待出生动画播完。
		await spawn_anim.anim_player.animation_finished
		# 特效播完后释放特效节点。
		spawn_anim.queue_free()

		# 实例化敌人场景（Enemy），定位到生成点，加入父节点。
		var enemy_instance := enemy_scene.instantiate() as Enemy
		enemy_instance.global_position = spawn_pos
		get_parent().add_child(enemy_instance)
		# 把敌人加入在场敌人列表，便于波末清理。
		spawned_enemies.append(enemy_instance)

	# 刷完一只后重新设置下一次刷怪间隔。
	set_spawn_timer()


## 函数说明：让所有敌人属性按波增长（生命、伤害各加增长量）。
## 被谁调用：_on_wave_timer_timeout（波末结算时）。
## 调用了：无（直接修改 stat 字段）。
func update_enemies_new_wave() -> void:
	# 遍历敌人属性集合。
	for stat: UnitStats in enemy_collection:
		# 每个敌人的生命上限增加其每波增长量，伤害同理增加。
		stat.health += stat.health_increase_per_wave
		stat.damage += stat.damage_increase_per_wave


## 函数说明：清除所有当前在场敌人。
## 被谁调用：_on_wave_timer_timeout、Arena.clean_arena。
## 调用了：enemy.destroy_enemy()。
func clear_enemies() -> void:
	# 若还有在场敌人。
	if spawned_enemies.size() > 0:
		# 遍历每个敌人。
		for enemy: Enemy in spawned_enemies:
			# is_instance_valid 判断节点仍有效（未被释放），有效则播放死亡动画后销毁。
			if is_instance_valid(enemy):
				enemy.destroy_enemy()

	# 清空在场敌人列表。
	spawned_enemies.clear()


## 函数说明：返回波数显示文本（"Wave N"）。
## 被谁调用：Arena._process（刷新 UI）。
## 调用了：无。
func get_wave_text() -> String:
	# 用 %s 把 wave_index 拼进字符串，返回如 "Wave 3"。
	return "Wave %s" % wave_index


## 函数说明：返回波次剩余时间文本（取整秒，下限 0）。
## 被谁调用：Arena._process（刷新 UI）。
## 调用了：int()、max()。
func get_wave_timer_text() -> String:
	# int(wave_timer.time_left) 把剩余秒数（浮点）截断为整数；
	# max(0, x) 保证不为负数；str() 转为字符串返回。
	return str(max(0, int(wave_timer.time_left)))


## 函数说明：刷怪定时器超时回调，刷一只敌人。
## 被谁调用：由 spawn_timer 超时信号触发。
## 调用了：spawn_enemy()。
func _on_spawn_timer_timeout() -> void:
	# 若没有当前波数据、或波计时器已停止（本波已结束），停止刷怪定时器并返回。
	if not current_wave_data or wave_timer.is_stopped():
		spawn_timer.stop()
		return

	# 否则刷一只敌人。
	spawn_enemy()


## 函数说明：波计时器超时回调，进入波末结算。
## 被谁调用：由 wave_timer 超时信号触发。
## 调用了：Global.get_harvesting_coins()、on_wave_completed.emit()、
##        clear_enemies()、update_enemies_new_wave()。
func _on_wave_timer_timeout() -> void:
	# 暂停游戏（冻结敌人/玩家/武器等每帧逻辑）。
	Global.game_paused = true
	# 结算本波收获的金币。
	Global.get_harvesting_coins()
	# 发出 on_wave_completed 信号，Arena 收到后会走"清理→显示升级"流程。
	on_wave_completed.emit()
	# 停止刷怪定时器（本波不再刷怪）。
	spawn_timer.stop()
	# 清除在场敌人。
	clear_enemies()
	# 让敌人属性按波成长（为下一波做准备）。
	update_enemies_new_wave()
