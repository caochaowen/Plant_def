extends Resource
class_name WeaponStats
## =============================================================================
## WeaponStats（武器数值 / Resource）
## -----------------------------------------------------------------------------
## 作用：纯数据资源，集中定义一把武器的全部战斗数值（伤害、精度、冷却、
##       暴击、射程、击退、吸血、后坐力、攻击节奏、弹道速度等）。
## 它不包含任何逻辑方法，只作为 ItemWeapon.stats 的载体被战斗系统读取。
## =============================================================================


# —— 新增：子弹弹道类型 ——
enum TrajectoryType {
	STRAIGHT,        # 直线
	HOMING_DIRECT,   # 直接追踪（move_toward，瞬时转向）
	HOMING_DAMPED,   # 阻尼追踪（速度向量惯性转向）
	HOMING_ROTATION, # 旋转转向追踪（lerp_angle 限角速度）
	BEZIER,          # 贝塞尔曲线
}


## 单次攻击的基础伤害。
@export var damage := 1.0

## 命中精度（0.0~1.0）：越接近 1 子弹散布越小。由 Weapon.calculate_spread 使用。
## @export_range(min, max) 限定在编辑器里拖动数值的范围。
@export_range(0.0, 1.0) var accuracy := 0.9

## 攻击冷却时间（秒，0.5~3.0）：两次攻击间的最短间隔。
@export_range(0.5, 3.0) var cooldown := 1.0

## 暴击概率（0.0~1.0）。由 WeaponBehavior.get_damage 判定。
@export_range(0.0, 1.0) var crit_chance := 0.05

## 暴击伤害倍率（暴击时伤害 = 基础伤害 × 该值）。
@export var crit_damage := 1.5

## 最大射程（像素）：决定武器碰撞半径与近战攻击前伸距离。
@export var max_range := 150.0

## 击退力度：命中敌人时施加的击退强度。由 HitboxComponent.setup / Enemy.apply_knockback 使用。
@export var knockback := 0.0

## 武器自带吸血概率（0.0~1.0，与玩家生命偷取叠加）。
@export_range(0.0, 1.0) var life_steal := 0.0

## 后坐力（像素）：攻击时武器/枪口后退的距离。
@export var recoil := 25.0

## 后坐力持续时间（秒，0.1~3.0）。
@export_range(0.1, 3.0) var recoil_duration := 0.1

## 攻击（前伸）阶段持续时间（秒，0.1~3.0，近战挥砍用）。
@export_range(0.1, 3.0) var attack_duration := 0.2

## 收招（回位）阶段持续时间（秒，0.1~3.0，近战用）。
@export_range(0.1, 3.0) var back_duration := 0.15

## 远程武器发射的弹丸场景（PackedScene，Projectile）。
@export var projectile_scene: PackedScene

## 弹丸飞行速度（像素/秒）。由 RangeBehavior.create_projectile 使用。
@export var projectile_speed := 1600.0


@export var trajectory_type: TrajectoryType = TrajectoryType.STRAIGHT

@export var homing_drag_factor := 0.15        # 阻尼追踪转向系数
@export var homing_turn_rate := 0.07          # 旋转追踪转向速率
@export var bezier_control_multiplier := 1.7  # 贝塞尔控制点倍率
