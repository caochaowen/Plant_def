extends Panel
class_name StatsContainer
## =============================================================================
## StatsContainer（属性面板 / Panel）
## -----------------------------------------------------------------------------
## 作用：显示玩家当前各项属性（生命、回血、吸血、伤害、幸运、速度、格挡、
##       收获）的 UI 面板。每帧从 Global.player.stats 读取并刷新到各标签。
## =============================================================================


## ---------------------------------------------------------------------------
## 节点引用（各属性标签）
## ---------------------------------------------------------------------------

## 生命值标签。
@onready var health_label: Label = %HealthLabel

## 生命回复标签。
@onready var hp_regen_label: Label = %HPRegenLabel

## 生命偷取标签。
@onready var life_steal_label: Label = %LifeStealLabel

## 伤害标签。
@onready var damage_label: Label = %DamageLabel

## 幸运标签。
@onready var luck_label: Label = %LuckLabel

## 速度标签。
@onready var speed_label: Label = %SpeedLabel

## 格挡标签。
@onready var block_label: Label = %BlockLabel

## 收获标签。
@onready var harvesting_label: Label = %HarvestingLabel


## 函数说明：每帧刷新玩家属性显示。
## 被谁调用：由 Godot 引擎每帧调用。
## 调用了：is_instance_valid()、str()。
func _process(delta: float) -> void:
	# 玩家尚未生成或已被释放时，跳过刷新，避免空引用。
	if not is_instance_valid(Global.player):
		return

	# 依次把玩家 stats 的各项属性转字符串赋给对应标签；
	# 吸血（life_steal）与格挡（block_chance）以百分比形式显示，故末尾拼 "%"。
	health_label.text = str(Global.player.stats.health)
	hp_regen_label.text = str(Global.player.stats.hp_regen)
	life_steal_label.text = str(Global.player.stats.life_steal) + "%"
	damage_label.text = str(Global.player.stats.damage)
	luck_label.text = str(Global.player.stats.luck)
	speed_label.text = str(Global.player.stats.speed)
	block_label.text = str(Global.player.stats.block_chance) + "%"
	harvesting_label.text = str(Global.player.stats.harvesting)
