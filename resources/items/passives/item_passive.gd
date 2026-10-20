extends ItemBase
class_name ItemPassive
## =============================================================================
## ItemPassive（被动道具 / Resource）
## -----------------------------------------------------------------------------
## 作用：继承 ItemBase，描述一个"被动道具"：它通过 add_stats / remove_stats
##       指定要增减的玩家属性名，通过 add_value / remove_value 指定增减量。
##       例如某被动道具 "+10 damage, -2 speed"。它可以直接修改
##       Global.player.stats 字典中的属性值。
## =============================================================================


## 被动道具增加的属性数值（加到 add_stats 指定的属性上）。
@export var add_value: float

## 被动道具增加的属性名（对应 UnitStats 的字段名，如 "damage"）。
@export var add_stats: String

## 被动道具减少的属性数值（从 remove_stats 指定的属性上扣除）。
@export var remove_value: float

## 被动道具减少的属性名（对应 UnitStats 的字段名，如 "speed"）。
@export var remove_stats: String


## 函数说明：生成被动道具的描述文本（BBCode），列出增减属性。
## 被谁调用：ShopCard._set_shop_item（重写自 ItemBase.get_description）。
## 调用了：无。
func get_description() -> String:
	# 以 "[code]" 作为开头标签，description 用 += 逐步拼接最终的富文本。
	var description := "[code]"

	# 若 add_value 不为 0，说明该道具会加属性，追加一行绿色文本。
	if add_value != 0:
		# %s 占位符依次被 [add_value, add_stats] 填充，"[color=green]...[/color]"
		# 是 BBCode 颜色标签（绿色），"\n" 表示换行。
		description += "[color=green]+%s %s[/color]\n" % [add_value, add_stats]

	# 若 remove_value 不为 0，说明该道具会减属性，追加一行红色文本。
	if remove_value != 0:
		description += "[color=red]-%s %s[/color]" % [remove_value, remove_stats]

	# 以 "[/code]" 闭合标签。
	description += "[/code]"
	# 返回拼接好的描述字符串。
	return description


## 函数说明：把被动道具的效果真正应用到玩家属性上（加减对应 stats 字段）。
## 被谁调用：ShopPanel._on_item_purchased（购买被动道具时）。
## 调用了：直接读写 Global.player.stats 字典。
func apply_passive() -> void:
	# 若 add_value 不为 0：用字段名 add_stats 作为键访问玩家 stats 字典，
	# 把该属性值 += add_value（例如 stats["damage"] += 10）。
	if add_value != 0:
		Global.player.stats[add_stats] += add_value

	# 若 remove_value 不为 0：把 stats[remove_stats] -= remove_value（扣减对应属性）。
	if remove_value != 0:
		Global.player.stats[remove_stats] -= remove_value
