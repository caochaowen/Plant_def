extends Node2D
class_name Weapon
## =============================================================================
## Weapon（武器 / Node2D）
## -----------------------------------------------------------------------------
## 作用：武器节点的通用逻辑。管理武器数值、攻击冷却、目标选择（找最近敌人）、
##       朝向旋转、攻击触发、以及按品质给武器描边。具体"怎么攻击"由
##       weapon_behavior（MeleeBehavior/RangeBehavior）的 execute_attack 实现。
## =============================================================================


## ---------------------------------------------------------------------------
## 节点引用
## ---------------------------------------------------------------------------

## 武器精灵（Sprite2D）。
@onready var sprite: Sprite2D = $Sprite2D

## 攻击范围碰撞体（CollisionShape2D，半径 = 射程）。
@onready var collision: CollisionShape2D = %CollisionShape2D

## 冷却计时器（Timer，控制攻击间隔）。
@onready var cooldown_timer: Timer = $CooldownTimer

## 攻击行为组件（WeaponBehavior：Melee/Range）。
@onready var weapon_behavior: WeaponBehavior = $WeaponBehavior


## ---------------------------------------------------------------------------
## 运行时变量
## ---------------------------------------------------------------------------

## 武器数据（ItemWeapon）。
var data: ItemWeapon

## 是否正在攻击。
var is_attacking := false

## 攻击起始位置（精灵初始位置，攻击动画往返的基准）。
var atk_start_pos: Vector2

## 攻击范围内的目标列表（Enemy）。
var targets: Array[Enemy]

## 当前最近目标（Enemy）。
var closest_target: Enemy

## 武器散布角度（累计误差，用于精度）。
var weapon_spread: float


## 函数说明：就绪时记录精灵初始位置作为攻击起始位置。
## 被谁调用：由 Godot 引擎在节点进入场景树时调用。
## 调用了：无。
func _ready() -> void:
	# 记录精灵初始位置，攻击动画（后坐/前伸/回位）都以此为基准。
	atk_start_pos = sprite.position


## 函数说明：每帧更新目标、旋转、视觉，并在可用时触发攻击。
## 被谁调用：由 Godot 引擎每帧调用。
## 调用了：update_closest_target()、rotate_to_target()、update_visuals()、
##        can_use_weapon()、use_weapon()。
func _process(delta: float) -> void:
	# 游戏暂停时冻结武器。
	if Global.game_paused: return

	# 未在攻击时，才更新最近目标（攻击过程中锁定目标不跳）。
	if not is_attacking:
		if targets.size() > 0:
			# 有目标则重新计算最近目标。
			update_closest_target()
		else:
			# 无目标则清空最近目标。
			closest_target = null

	# 旋转武器朝向目标。
	rotate_to_target()
	# 更新视觉（根据角度上下翻转）。
	update_visuals()

	# 若满足攻击条件（冷却结束且有目标），触发一次攻击。
	if can_use_weapon():
		use_weapon()


## 函数说明：配置武器数据：保存 data、设置范围半径、应用品质描边。
## 被谁调用：Player.add_weapon。
## 调用了：apply_tier_outline()。
func setup_weapon(data: ItemWeapon) -> void:
	# 保存武器数据。
	self.data = data
	# 把范围碰撞体的形状半径设为武器最大射程（collision.shape 是 CircleShape2D）。
	collision.shape.radius = data.stats.max_range
	# 按品质应用描边（非普通品质会有彩色轮廓）。
	apply_tier_outline()


## 函数说明：执行一次攻击：计算散布、调用行为攻击、设置并启动冷却。
## 被谁调用：_process（can_use_weapon 判定通过时）。
## 调用了：calculate_spread()、weapon_behavior.execute_attack()、cooldown_timer.start()。
func use_weapon() -> void:
	# 计算本次攻击的随机散布角度（叠加到旋转上）。
	calculate_spread()
	# 调用武器行为组件的 execute_attack()（近战挥砍 / 远程射击，多态）。
	weapon_behavior.execute_attack()
	# 设置冷却时长并启动冷却计时器（攻击后进入冷却）。
	cooldown_timer.wait_time = data.stats.cooldown
	cooldown_timer.start()


## 函数说明：根据是否在攻击选择不同的旋转目标计算方式。
## 被谁调用：_process。
## 调用了：get_custom_rotation_to_target()、get_rotation_to_target()。
func rotate_to_target() -> void:
	# 攻击中：用带散布的角度（get_custom_rotation_to_target）；
	# 非攻击：用标准朝向目标的角度（get_rotation_to_target）。
	if is_attacking:
		rotation = get_custom_rotation_to_target()
	else:
		rotation = get_rotation_to_target()


## 函数说明：计算攻击中朝向目标的旋转（叠加武器散布角度）。
## 被谁调用：rotate_to_target。
## 调用了：direction_to()、angle()。
func get_custom_rotation_to_target() -> float:
	# 无最近目标或目标已失效，则保持当前旋转不变。
	if not closest_target or not is_instance_valid(closest_target):
		return rotation

	# direction_to().angle() 求指向最近目标的方向角（弧度），再叠加散布角 weapon_spread。
	var rot := global_position.direction_to(closest_target.global_position).angle()
	return rot + weapon_spread


## 函数说明：计算非攻击时朝向目标的旋转（无目标则用 idle 朝向）。
## 被谁调用：rotate_to_target。
## 调用了：get_idle_rotation()、direction_to()、angle()。
func get_rotation_to_target() -> float:
	# 无目标时返回空闲朝向。
	if targets.size() == 0:
		return get_idle_rotation()

	# 返回指向最近目标的角度。
	var rot := global_position.direction_to(closest_target.global_position).angle()
	return rot


## 函数说明：返回空闲时的朝向角度（面向玩家朝向，右=0，左=PI）。
## 被谁调用：get_rotation_to_target。
## 调用了：Global.player.is_facing_right()。
func get_idle_rotation() -> float:
	# 玩家面向右则武器指向右（角度 0），否则指向左（PI 即 180°）。
	if Global.player.is_facing_right():
		return 0
	else:
		return PI


## 函数说明：根据旋转角度翻转武器精灵的垂直方向（保证武器不"倒挂"）。
## 被谁调用：_process。
## 调用了：abs()。
func update_visuals() -> void:
	# abs(rotation) 取旋转角绝对值；超过 PI/2（90°）说明武器朝上/朝下，
	# 需要垂直翻转精灵（scale.y = -0.5），否则保持 0.5。
	if abs(rotation) > PI / 2:
		sprite.scale.y = -0.5
	else:
		sprite.scale.y = 0.5


## 函数说明：根据精度累计随机散布并叠加到旋转上。
## 被谁调用：use_weapon。
## 调用了：randf_range()。
func calculate_spread() -> void:
	# 精度 accuracy 越高（接近 1），随机区间越窄（散布越小）：
	# randf_range(-1+accuracy, 1-accuracy) 生成散布量，累加到 weapon_spread。
	weapon_spread += randf_range(-1 + data.stats.accuracy, 1 - data.stats.accuracy)
	# 把散布角叠加到当前旋转，使弹道/朝向带一点随机偏差。
	rotation += weapon_spread


## 函数说明：把最近目标更新为当前目标列表中的最近敌人。
## 被谁调用：_process。
## 调用了：get_closest_target()。
func update_closest_target() -> void:
	# 调用 get_closest_target() 计算结果并赋给 closest_target。
	closest_target = get_closest_target()


## 函数说明：在目标列表中找出距离最近的敌人并返回。
## 被谁调用：update_closest_target。
## 调用了：distance_to()。
func get_closest_target() -> Node2D:
	# 无目标则返回（隐式返回 null）。
	if targets.size() == 0:
		return

	# 先以第一个目标为基准，记录它与到它的距离。
	var closest_enemy := targets[0]
	var closest_distance := global_position.distance_to(closest_enemy.global_position)

	# 从第二个目标开始遍历（range(1, size)）。
	for i in range(1, targets.size()):
		var target: Enemy = targets[i]
		# 计算到当前目标距离。
		var distance := global_position.distance_to(target.global_position)

		# 若更近则更新"最近目标"与"最近距离"。
		if distance < closest_distance:
			closest_enemy = target
			closest_distance = distance

	# 返回最近目标。
	return closest_enemy


## 函数说明：判断当前能否攻击（冷却已结束且有目标）。
## 被谁调用：_process。
## 调用了：cooldown_timer.is_stopped()。
func can_use_weapon() -> bool:
	# 冷却计时器已停止（is_stopped 为真）且存在最近目标时，才可攻击。
	return cooldown_timer.is_stopped() and closest_target


## 函数说明：按武器品质给精灵应用描边（普通品质不描边）。
## 被谁调用：setup_weapon。
## 调用了：sprite.material.set_shader_parameter()。
func apply_tier_outline() -> void:
	# 普通品质（COMMON）无描边，清空材质并返回。
	if data.item_tier == Global.UpgradeTier.COMMON:
		sprite.material = null
		return

	# 其它品质：从 Global.TIER_COLORS 取对应描边颜色。
	var outline_color := Global.TIER_COLORS[data.item_tier]
	# set_shader_parameter("outline_color", color) 把颜色写入材质的着色器参数，
	# 使精灵显示对应品质的轮廓描边。
	sprite.material.set_shader_parameter("outline_color", outline_color)


## 函数说明：敌人进入武器攻击范围时，加入目标列表。
## 被谁调用：由武器范围 Area2D 的 area_entered 信号触发。
## 调用了：targets.push_back()。
func _on_range_area_area_entered(area: Area2D) -> void:
	# push_back 把进入范围的敌人加入目标列表（后续据此找最近目标）。
	targets.push_back(area)


## 函数说明：敌人离开武器攻击范围时，从目标列表移除（并处理空列表）。
## 被谁调用：由武器范围 Area2D 的 area_exited 信号触发。
## 调用了：targets.erase()。
func _on_range_area_area_exited(area: Area2D) -> void:
	# erase 把离开范围的敌人从目标列表移除。
	targets.erase(area)
	# 若目标列表已空，清空最近目标。
	if targets.size() == 0:
		closest_target = null
