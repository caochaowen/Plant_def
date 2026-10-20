extends ItemBase
class_name ItemWeapon
## =============================================================================
## ItemWeapon（武器道具 / Resource）
## -----------------------------------------------------------------------------
## 作用：继承 ItemBase，描述一把可装备的武器。包含武器类型（近战/远程）、
##       对应的武器场景、武器数值（WeaponStats）、以及可升级合成的下一级武器。
## 它在角色选择、商店购买、背包合成等流程中被当作"武器数据"使用。
## =============================================================================


## ---------------------------------------------------------------------------
## 武器类型枚举
## ---------------------------------------------------------------------------
## 武器类型：MELEE（近战）/ RANGE（远程）。
enum WeaponType {
	MELEE,
	RANGE
}


## ---------------------------------------------------------------------------
## 导出字段
## ---------------------------------------------------------------------------

## 武器类型（MELEE / RANGE）。
@export var type: WeaponType

## 武器对应的场景（PackedScene），实例化后为 Weapon 节点。由 Player.add_weapon 使用。
@export var scene: PackedScene

## 武器数值（WeaponStats Resource：伤害/冷却/射程/暴击等）。
@export var stats: WeaponStats

## 升级目标武器（ItemWeapon）：两把同类武器合成后升级成的下一级武器。
## 由 ShopPanel._on_combine_button_pressed 读取 resource_path 加载。
@export var upgrade_to: ItemWeapon


## 函数说明：生成武器描述文本（BBCode），显示伤害/冷却/射程/暴击率。
## 被谁调用：ShopCard._set_shop_item（重写自 ItemBase.get_description）。
## 调用了：无（读取 stats 字段）。
func get_description() -> String:
	# 用格式串把武器的四项数值拼进 BBCode 描述文本：
	# stats.damage（伤害）、stats.cooldown（冷却）、stats.max_range（射程）
	# 显示为绿色；stats.crit_chance * 100 把 0~1 的暴击率换算成百分比，%% 表示字面百分号。
	return "[code]Damage: [color=green]%s[/color]\nCooldown: [color=green]%s[/color]\nRange: [color=green]%s[/color]\nCritical: [color=green]%s%%[/color][/code]" % [stats.damage, stats.cooldown, stats.max_range, stats.crit_chance * 100]
