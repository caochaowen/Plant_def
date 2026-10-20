extends Resource
class_name UnitStats
## =============================================================================
## UnitStats（单位数值 / Resource）
## -----------------------------------------------------------------------------
## 作用：纯数据资源，定义玩家/敌人的基础属性（生命、伤害、速度、幸运、
##       格挡、金币掉落、回血、吸血、收获等）以及按波数成长的增长量。
## 它作为 Unit.stats 的载体被战斗系统、掉落系统、商店/升级系统读取和修改。
## =============================================================================


## ---------------------------------------------------------------------------
## 单位类型枚举
## ---------------------------------------------------------------------------
## 单位类型：PLAYER（玩家）/ ENEMY（敌人）。
enum UnitType {
	PLAYER,
	ENEMY
}


## ---------------------------------------------------------------------------
## 导出字段
## ---------------------------------------------------------------------------

## 单位名称（角色名 / 敌人名，也作为 available_players 的键）。
@export var name: String

## 单位类型（PLAYER / ENEMY）。
@export var type: UnitType

## 单位图标（角色选择界面显示）。
@export var icon: Texture2D

## 生命值上限（当前生命在 HealthComponent.setup 时初始化为该值）。
@export var health := 1

## 每波生命增长量：每过一波 health 增加该值（由 Spawner.update_enemies_new_wave /
## Player.update_player_new_wave 使用）。
@export var health_increase_per_wave := 1.0

## 伤害值（玩家的普攻/敌人的攻击基础伤害）。
@export var damage := 1.0

## 每波伤害增长量（仅敌人使用）。
@export var damage_increase_per_wave := 1.0

## 移动速度（像素/秒）。
@export var speed := 300

## 幸运值：影响高稀有度掉落/商店概率（Global.calculate_tier_probability）。
@export var luck := 1.0

## 闪避概率（0.0~1.0）：受击时完全抵挡伤害的概率。
@export var block_chance := 0.0

## 金币掉落量：敌人死亡时掉落的金币数（Arena.spawn_coins）。
@export var gold_drop := 1

## 生命回复：每触发一次回复所恢复的血量（Player._on_hp_regen_timer_timeout）。
@export var hp_regen := 0.0

## 生命偷取：玩家普攻命中回血的概率（WeaponBehavior.apply_life_steal）。
@export var life_steal := 0.0

## 收获：每波结束结算时获得的金币数（Global.get_harvesting_coins）。
@export var harvesting := 0.0

## 初始体力值上限（每个角色在 .tres 里填不同值）。
@export var stamina := 100.0

## 体力每秒回复量。
@export var stamina_regen := 10.0

#抗性
@export var Resistance := 0.0
