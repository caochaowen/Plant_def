extends ItemBase
class_name ItemUpgrade
## =============================================================================
## ItemUpgrade（升级道具 / Resource）
## -----------------------------------------------------------------------------
## 作用：继承 ItemBase，描述一个"升级奖励"：指定要提升的玩家属性（stat_id）
##       及其增加值（value），在波次结算时作为可选项供玩家挑选。
## =============================================================================


## 升级提升的数值（加到 stat_id 指定的属性上）。
@export var value: float

## 升级的描述文本（直接作为展示文案，非 BBCode 计算）。
@export var description: String

## 要提升的属性 id（对应 UnitStats 字段名，如 "damage"）。
@export var stat_id: String


## 函数说明：把升级效果应用到玩家属性上（在现有值基础上累加 value）。
## 被谁调用：UpgradeCard._on_custom_buttom_pressed（玩家点选升级卡时）。
## 调用了：Global.player.stats.get() / set()。
func apply_upgrade() -> void:
	# stats.get(stat_id) 用属性名取玩家当前该属性的值（不存在则返回 null），
	# `as float` 把结果安全转型为 float（用于后续加法）。
	var current_value := Global.player.stats.get(stat_id) as float
	# 新值 = 升级提供值 value + 当前值 current_value；float() 确保 value 是浮点。
	var new_value := float(value) + float(current_value)
	# stats.set(stat_id, new_value) 把新值写回玩家属性字典（按属性名覆盖）。
	Global.player.stats.set(stat_id, new_value)
