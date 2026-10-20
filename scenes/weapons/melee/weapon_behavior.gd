extends Node2D
class_name WeaponBehavior
## =============================================================================
## WeaponBehavior（武器行为基类 / Node2D）
## -----------------------------------------------------------------------------
## 作用：定义武器攻击行为的公共接口与公共逻辑：
##   - execute_attack()：子类重写，实现具体攻击（近战挥砍/远程射击）；
##   - get_damage()：计算本次攻击伤害（含暴击判定）；
##   - apply_life_steal()：按概率吸血回血。
## =============================================================================


## 所属武器（Weapon）。
@export var weapon: Weapon


## 本次攻击是否暴击（get_damage 里判定）。
var critical := false


## 函数说明：执行攻击（抽象方法，由 MeleeBehavior / RangeBehavior 重写实现）。
## 被谁调用：Weapon.use_weapon。
## 调用了：无（基类为空实现）。
func execute_attack() -> void:
	# 基类无实现（pass 占位），具体攻击逻辑由 MeleeBehavior / RangeBehavior 子类重写。
	pass


## 函数说明：计算本次攻击的伤害，并做暴击判定。
## 被谁调用：
##   - MeleeBehavior.execute_attack
##   - RangeBehavior.create_projectile
## 调用了：Global.get_chance_sucess()、ceil()。
func get_damage() -> float:
	# 基础伤害 = 武器自身伤害 + 玩家 stats.damage（玩家伤害加成）。
	var damage := weapon.data.stats.damage + Global.player.stats.damage
	# 取武器暴击率。
	var crit_chance := weapon.data.stats.crit_chance
	# Global.get_chance_sucess(crit_chance) 做暴击概率判定。
	if Global.get_chance_sucess(crit_chance):
		# 暴击：置 critical = true，伤害向上取整（ceil）为 伤害 × 暴击倍率。
		critical = true
		damage = ceil(damage * weapon.data.stats.crit_damage)
	# 返回最终伤害。
	return damage


## 函数说明：按（玩家吸血 + 武器吸血）概率给玩家回血。
## 被谁调用：MeleeBehavior.execute_attack、RangeBehavior.execute_attack。
## 调用了：Global.get_chance_sucess()、Global.player.health_component.heal()、
##        Global.on_create_heal_text.emit()。
func apply_life_steal() -> void:
	# 吸血概率 = 玩家生命偷取（life_steal/100 转为小数）+ 武器自带吸血率。
	var steal_chance := (Global.player.stats.life_steal / 100.0) + weapon.data.stats.life_steal
	# 做吸血概率判定。
	var can_steal := Global.get_chance_sucess(steal_chance)
	# 判定成功且玩家有效时，给玩家回 1 点血。
	if can_steal and is_instance_valid(Global.player):
		Global.player.health_component.heal(1.0)
		# 发出治疗文字信号（显示 +1 治疗）。
		Global.on_create_heal_text.emit(Global.player, 1.0)
