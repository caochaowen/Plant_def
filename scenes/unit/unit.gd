extends Node2D
class_name Unit
## =============================================================================
## Unit（单位基类 / Node2D）
## -----------------------------------------------------------------------------
## 作用：玩家与敌人的共同父类。持有单位属性（stats）、视觉节点、动画播放器、
##       生命组件、受击闪烁计时器；在 _ready 初始化生命组件；提供受击处理
##       （格挡判定、闪白、扣血、伤害文字）与闪烁材质清理。
## =============================================================================


## ---------------------------------------------------------------------------
## 导出字段
## ---------------------------------------------------------------------------

## 单位属性（UnitStats）。由 _ready 传给 HealthComponent.setup 初始化生命。
@export var stats: UnitStats


## ---------------------------------------------------------------------------
## 节点引用
## ---------------------------------------------------------------------------

## 视觉容器节点（Node2D，包含 sprite，用于翻转朝向）。
@onready var visuals: Node2D = %Visuals

## 精灵图（Sprite2D，用于受击闪烁材质）。
@onready var sprite: Sprite2D = %Sprite

## 动画播放器（AnimationPlayer）。
@onready var anim_player: AnimationPlayer = $AnimationPlayer

## 生命组件（HealthComponent）。
@onready var health_component: HealthComponent = $HealthComponent

## 受击闪烁定时器（Timer）。
@onready var flash_timer: Timer = $FlashTimer


## 函数说明：就绪时用属性初始化生命组件。
## 被谁调用：由 Godot 引擎在节点进入场景树时调用（子类 Player._ready 会先调用 super）。
## 调用了：health_component.setup()。
func _ready() -> void:
	# 用单位属性初始化生命组件（设置最大/当前生命并广播初始血量）。
	health_component.setup(stats)


## 函数说明：给精灵应用受击闪烁材质并启动闪烁计时器。
## 被谁调用：_on_hurtbox_component_on_damaged（未格挡、受击时）。
## 调用了：flash_timer.start()。
func set_flash_material() -> void:
	# 把精灵材质设为全局预加载的闪白材质（Global.FLASH_MATERIAL），表现为受击闪一下。
	sprite.material = Global.FLASH_MATERIAL
	# 启动闪烁计时器，超时后（_on_flash_timer_timeout）恢复材质。
	flash_timer.start()


## 函数说明：受伤盒被攻击盒命中时的回调，处理格挡/受伤流程。
## 被谁调用：由 HurtboxComponent.on_damaged 信号触发（子类 Enemy 重写并调用 super）。
## 调用了：Global.get_chance_sucess()、set_flash_material()、
##        health_component.take_damage()、Global.on_create_block_text.emit()、
##        Global.on_create_damage_text.emit()。
func _on_hurtbox_component_on_damaged(hitbox: HitboxComponent) -> void:
	# 若已经死亡（生命 ≤0），不再处理后续受伤。
	if health_component.current_health <= 0:
		return

	# stats.block_chance 是 0~1 的格挡率，除以 100 转成小数概率；
	# Global.get_chance_sucess() 做概率判定，返回是否格挡成功。
	var blocked := Global.get_chance_sucess(stats.block_chance / 100)
	# 若格挡成功。
	if blocked:
		# 发出"格挡"文字信号（Arena 生成 Blocked! 文字），并直接 return，不扣血。
		Global.on_create_block_text.emit(self)
		return

	# 未格挡：触发受击闪白。
	set_flash_material()
	# 生命组件扣除攻击盒伤害。
	health_component.take_damage(hitbox.damage)
	# 发出伤害文字信号（Arena 生成伤害数字）。
	Global.on_create_damage_text.emit(self, hitbox)


## 函数说明：闪烁计时器超时回调，恢复精灵材质。
## 被谁调用：由 flash_timer 超时信号触发。
## 调用了：无。
func _on_flash_timer_timeout() -> void:
	# 把精灵材质置回 null，清除闪白效果，恢复正常外观。
	sprite.material = null
