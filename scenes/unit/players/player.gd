extends Unit
class_name Player
## =============================================================================
## Player（玩家 / Unit 子类）
## -----------------------------------------------------------------------------
## 作用：玩家角色。处理移动（含冲刺）、朝向与动画、冲刺/回血/生命恢复逻辑、
##       以及武器装配与位置更新。
## =============================================================================


## 技能节点（普通 Node 子节点，挂载该角色的 CharacterSkills 子类脚本）。
## 类型标注必须是基类 CharacterSkills——写成具体子类才真的会写死角色。
@onready var skills: CharacterSkills = $Skills


## 当前体力值。
var current_stamina := 0.0

## ---------------------------------------------------------------------------
## 导出字段（冲刺相关）
## ---------------------------------------------------------------------------

## 冲刺持续时间（秒）。
@export var dash_duration := 0.5

## 冲刺速度倍率。
@export var dash_speed_multi := 2.5

## 冲刺冷却时间（秒）。
@export var dash_cooldown := 0.5


## ---------------------------------------------------------------------------
## 节点引用
## ---------------------------------------------------------------------------

## 冲刺计时器（Timer，控制冲刺持续）。
@onready var dash_timer: Timer = $DashTimer

## 冲刺冷却计时器（Timer，控制冲刺冷却）。
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer

## 碰撞体（CollisionShape2D，冲刺时暂时禁用）。
@onready var collision: CollisionShape2D = $CollisionShape2D

## 拖尾特效（Trail）。
@onready var trail: Trail = %Trail

## 武器容器（WeaponContainer，管理武器挂点）。
@onready var weapon_container: WeaponContainer = $WeaponContainer


## ---------------------------------------------------------------------------
## 运行时变量
## ---------------------------------------------------------------------------

## 当前已装备的武器节点列表（Weapon）。
var current_weapons: Array[Weapon] = []

## 当前移动方向向量（由输入决定）。
var move_dir: Vector2

## 是否正在冲刺。
var is_dashing := false

## 冲刺是否可用（配合冷却计时器）。
var dash_available := true


## 函数说明：就绪时调用父类初始化并设置冲刺计时器时长。
## 被谁调用：由 Godot 引擎在节点进入场景树时调用。
## 调用了：super._ready()。
func _ready() -> void:
	# super._ready() 调用父类 Unit 的 _ready，完成生命组件初始化。
	super._ready()
	# 设置冲刺计时器与冲刺冷却计时器的等待时长（分别用导出参数）。
	dash_timer.wait_time = dash_duration
	dash_cooldown_timer.wait_time = dash_cooldown
	# 初始体力 = 体力上限（来自该角色的 stats.stamina）。
	current_stamina = stats.stamina

## 函数说明：每帧处理玩家移动、冲刺、动画与朝向。
## 被谁调用：由 Godot 引擎每帧调用。
## 调用了：Input.get_vector()、can_dash()、start_dash()、update_animations()、update_rotation()。
func _process(delta: float) -> void:
	# 游戏暂停时冻结玩家操作。
	if Global.game_paused: return

	# Input.get_vector(左, 右, 上, 下) 读取四个方向动作，合成一个方向向量（长度 ≤1），
	# 存储到 move_dir 表示当前输入方向。
	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# 基础速度 = 方向 × 移动速度。
	var current_velocity := move_dir * stats.speed
	# 冲刺时速度乘冲刺倍率（更快）。
	if is_dashing:
		current_velocity *= dash_speed_multi

	# 位置 += 速度 × 帧时间，实现移动。
	position += current_velocity * delta
	# clamp(值, min, max) 把位置限制在竞技场范围内，防止玩家走出边界。
	position.x = clamp(position.x, -1000, 1000)
	position.y = clamp(position.y, -500, 500)

	# 若满足冲刺条件（can_dash 判定），触发冲刺。
	if can_dash():
		start_dash()

	# 更新动画与朝向。
	update_animations()
	update_rotation()
	
	# 体力自然回复（不超过上限）。
	regen_stamina(delta)
	# 技能输入：Q/E → 转交给 Skills 节点。
	if Input.is_action_just_pressed("skill_1"):
		skills.try_cast_skill_1()
	if Input.is_action_just_pressed("skill_2"):
		skills.try_cast_skill_2()


## 函数说明：装配一把武器：实例化武器节点并配置，加入 current_weapons 并更新位置。
## 被谁调用：
##   - Arena._on_selection_panel_on_selection_completed（初始武器）
##   - ShopPanel._on_item_purchased（购买武器）
##   - ShopPanel._on_combine_button_pressed（合成武器）
## 调用了：data.scene.instantiate()、weapon.setup_weapon()、weapon_container.update_weapons_position()。
func add_weapon(data: ItemWeapon) -> void:
	# 用武器数据里的场景实例化出武器节点（Weapon）。
	var weapon := data.scene.instantiate() as Weapon
	# 把武器加入玩家子节点（跟随玩家移动）。
	add_child(weapon)

	# 用武器数据配置武器（数值、射程半径、品质描边）。
	weapon.setup_weapon(data)
	# 把武器加入当前武器列表。
	current_weapons.append(weapon)
	# 更新武器容器中所有武器的挂点位置（按数量排列）。
	weapon_container.update_weapons_position(current_weapons)


## 函数说明：根据是否移动切换播放 move/idle 动画。
## 被谁调用：_process。
## 调用了：anim_player.play()。
func update_animations() -> void:
	# move_dir.length() 是方向向量长度；有输入（长度>0）则播放移动动画，否则待机动画。
	if move_dir.length() > 0:
		anim_player.play("move")
	else:
		anim_player.play("idle")


## 函数说明：根据移动方向水平翻转角色朝向。
## 被谁调用：_process。
## 调用了：无。
func update_rotation() -> void:
	# 未移动（方向为零向量）则保持当前朝向，直接返回。
	if move_dir == Vector2.ZERO:
		return

	# 向右移动（x ≥ 0.1）则翻转 scale 为 (-0.5, 0.5)，否则 (0.5, 0.5)。
	if move_dir.x >= 0.1:
		visuals.scale = Vector2(-0.5, 0.5)
	else:
		visuals.scale = Vector2(0.5, 0.5)


## 函数说明：开始冲刺：置冲刺状态、启动计时、开启拖尾、半透明、禁用碰撞。
## 被谁调用：_process（can_dash 判定通过时）。
## 调用了：dash_timer.start()、trail.start_trail()、collision.set_deferred()。
func start_dash() -> void:
	# 置冲刺状态为真。
	is_dashing = true
	# 启动冲刺计时器（超时后结束冲刺）。
	dash_timer.start()
	# 开启拖尾特效。
	trail.start_trail()
	# 把玩家调半透明（冲刺残影效果）。
	visuals.modulate.a = 0.5
	# set_deferred("disabled", true) 延迟禁用碰撞体，让冲刺期间无敌（穿透敌人）。
	collision.set_deferred("disabled", true)


## 函数说明：判断当前能否触发冲刺。
## 被谁调用：_process。
## 调用了：Input.is_action_just_pressed()。
func can_dash() -> bool:
	# 满足四个条件才可冲刺：
	# 1) 不在冲刺中（not is_dashing）；
	# 2) 冲刺冷却计时器已停止（is_stopped，冷却结束）；
	# 3) 刚按下冲刺键（is_action_just_pressed("dash") 只在按下当帧为真）；
	# 4) 有移动方向（move_dir 不为零）。
	return not is_dashing and\
	dash_cooldown_timer.is_stopped() and\
	Input.is_action_just_pressed("dash") and\
	move_dir != Vector2.ZERO


## 函数说明：判断角色是否面向右侧（供武器 idle 朝向使用）。
## 被谁调用：Weapon.get_idle_rotation。
## 调用了：无。
func is_facing_right() -> bool:
	# 面向右侧时 visuals.scale.x 为 -0.5（因资源朝向约定），据此返回 true/false。
	return visuals.scale.x == -0.5


## 函数说明：新一波开始时玩家成长：生命上限按波增长并重新初始化生命组件。
## 被谁调用：Arena.start_new_wave。
## 调用了：health_component.setup()。
func update_player_new_wave() -> void:
	# 生命上限增加每波增长量。
	stats.health += stats.health_increase_per_wave
	# 用新的 stats 重新 setup 生命组件（当前生命会被重置为新上限，满血进入新波）。
	health_component.setup(stats)


## 函数说明：冲刺计时器超时回调，结束冲刺并开始冷却。
## 被谁调用：由 dash_timer 超时信号触发。
## 调用了：dash_cooldown_timer.start()、collision.set_deferred()。
func _on_dash_timer_timeout() -> void:
	# 退出冲刺状态。
	is_dashing = false
	# 恢复不透明。
	visuals.modulate.a = 1.0
	# 清空移动方向（冲刺结束瞬间停下）。
	move_dir = Vector2.ZERO
	# 恢复碰撞体（结束无敌）。
	collision.set_deferred("disabled", false)
	# 启动冲刺冷却计时器。
	dash_cooldown_timer.start()


## 函数说明：生命回复计时器超时回调，回复生命并发治疗文字。
## 被谁调用：由 hp_regen 计时器（场景中 HPRegenTimer）超时信号触发。
## 调用了：health_component.heal()、Global.on_create_heal_text.emit()。
func _on_hp_regen_timer_timeout() -> void:
	# 已死亡则不再回血。
	if health_component.current_health <= 0:
		return

	# 只有当前生命低于上限时才回血。
	if health_component.current_health < stats.health:
		# 治疗量 = 玩家 stats.hp_regen（生命回复属性）。
		var heal := stats.hp_regen
		# 生命组件治疗。
		health_component.heal(heal)
		# 发出治疗文字信号（Arena 生成 +N 文字）。
		Global.on_create_heal_text.emit(self, heal)
		
## 函数说明：每秒回复体力，不超过上限。
func regen_stamina(delta: float) -> void:
	current_stamina = min(current_stamina + stats.stamina_regen * delta, stats.stamina)
