# 射线激光子弹：把 `laser` 项目的镭射效果整合为角色的一种子弹模式

> 目标：把仓库根目录 `laser/` 独立项目里的 4 种镭射激光实现（冻结 / 多重 / 灼热 / 爆裂），整合成 `plant_def` 项目中**一种**射线激光子弹。这个子弹只有一个场景 + 一个脚本，通过面板上的 `mode` 枚举切换不同镭射效果；激光的**粗细 / 速度 / 长度**都做成 `@export`，可直接在 Inspector 面板调试。
>
> 前置阅读：本文假定你已了解项目的武器/子弹/伤害系统，参见同目录 [`projectile_trajectory_merge_plan.md`](./projectile_trajectory_merge_plan.md)。

---

## 目录

1. [现状分析：laser 项目 vs plant_def 项目](#1-现状分析laser-项目-vs-plant_def-项目)
2. [总体设计方案](#2-总体设计方案)
3. [改动总览](#3-改动总览)
4. [手把手步骤 1：新建激光光束场景 `projectile_laser_beam.tscn`](#4-手把手步骤-1新建激光光束场景-projectile_laser_beamtscn)
5. [手把手步骤 2：编写 `laser_beam.gd` 并挂到根节点](#5-手把手步骤-2编写-laser_beamgd-并挂到根节点)
6. [手把手步骤 3：新建 `laser_behavior.gd`](#6-手把手步骤-3新建-laser_behaviorgd)
7. [手把手步骤 4：把激光武器的行为脚本换成 `LaserBehavior`](#7-手把手步骤-4把激光武器的行为脚本换成-laserbehavior)
8. [手把手步骤 5：调整激光数值资源 `stats_laser_1.tres`](#8-手把手步骤-5调整激光数值资源-stats_laser_1tres)
9. [四种镭射模式详解与调参](#9-四种镭射模式详解与调参)
10. [碰撞层对照表](#10-碰撞层对照表)
11. [（可选）让激光被墙体阻挡 / 反射](#11-可选让激光被墙体阻挡--反射)
12. [验证清单](#12-验证清单)
13. [常见问题与扩展](#13-常见问题与扩展)

---

## 1. 现状分析：laser 项目 vs plant_def 项目

### 1.1 laser 项目的 4 种镭射

`laser/` 是一个独立 Demo，用 4 个场景各自实现一种激光。它们的共同结构是：**根节点是 `RayCast2D`（或 `ShapeCast2D`）做碰撞检测，子节点 `Line2D` 画光束，`AnimationPlayer` 播放 `fade` 渐隐动画**（把 `Line2D` 的 `width` 从初始值动画到 0）。

| 模式 | 文件 | 根节点 | 子节点 | 速度 `speed` | 最大长度 `max_length` | 线宽 | 颜色 | 行为 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 冻结 FREEZE | `freeze_laser.gd` | `RayCast2D` | `Line2D` + `AnimationPlayer` | 4000 | 1000 | 8 | 青 (0.878,1,1) | 射出一段，命中敌人扣血并渐隐 |
| 多重 MULTI | `multi_laser.gd` | `RayCast2D` | `Line2D` + `AnimationPlayer` | 8000 | 8000 | 8 | 黄 (1,0.92,0.23) | 命中墙体后反射，再生成一条新光束 |
| 灼热 HOT | `hot_laser.gd` | `RayCast2D` | `Line2D` + `AnimationPlayer` + `GPUParticles2D` | 2000 | 2000 | 10 | 粉 (1,0.176,0.33) | 持续照射，持续扣血，命中点有火花粒子 |
| 爆裂 BOOM | `boom_laser.gd` | `ShapeCast2D` | `XuliLine` + `BoomLine` + `AnimationPlayer` + `GPUParticles2D` | 蓄力 1000 / 爆发 4000 | 1000 | 40 / 50 | 白 / 紫 | 先蓄力（细线变长），再瞬间爆发一条粗光束 |

> laser 项目的核心技巧：**光束 = `Line2D` 的两个点 `[Vector2(0,0), Vector2(长度,0)]` 沿 +X 方向**，根节点 `look_at()` 朝向发射方向；每帧把 `RayCast2D.target_position.x` 和 `Line2D.points[1].x` 同步加 `speed * delta`，就得到"光束延伸"的效果；`AnimationPlayer` 把 `width` 动画到 0 实现"消失"。

### 1.2 plant_def 项目现有的激光武器与子弹

项目**已经有一把激光武器**，只是它现在发射的是普通"飞行子弹"（一张贴图沿直线飞），并没有激光射线视觉：

| 内容 | 文件 |
| --- | --- |
| 武器场景 | `scenes/weapons/range/weapon_laser.tscn` |
| 武器行为脚本 | `scenes/weapons/range/range_behavior.gd`（和手枪/步枪共用） |
| 子弹场景 | `scenes/projectiles/projectile_laser.tscn`（继承自手枪子弹，只是一张贴图） |
| 数值资源 | `resources/items/weapons/range/laser/stats_laser_1.tres`（4 级） |
| 物品资源 | `resources/items/weapons/range/laser/item_laser_1.tres`（4 级） |

所以本方案**不需要新建武器/物品**，只要：把激光武器的 `WeaponBehavior` 行为脚本换成新的 `LaserBehavior`，让它发射激光光束即可。商店里现有的 "Laser I~IV" 会自动变成激光射线。

### 1.3 plant_def 的伤害系统（关键差异）

laser 项目是直接 `get_collider().hp -= 10` 扣血。plant_def 项目用**组件式伤害管线**，必须适配：

```
子弹 HitboxComponent(Area2D, 第5层) ──重叠──▶ 敌人 HurtboxComponent(Area2D, 第4层)
                                                    │ 发出 on_damaged(hitbox) 信号
                                                    ▼
                              Unit._on_hurtbox_component_on_damaged(hitbox)
                              （格挡判定 → 受击闪白 → 扣血 → 伤害文字 → 击退）
```

激光用 `RayCast2D` 检测，没有 Area2D 攻击盒。适配办法：**让激光射线检测敌人的 HurtboxComponent（第4层，值 8），命中后手工构造一个轻量 `HitboxComponent`，再 `hurtbox.on_damaged.emit(hitbox)`**——这样就完全复用现有受击管线（格挡 / 闪白 / 伤害文字 / 击退），不会绕过任何机制。

---

## 2. 总体设计方案

遵循项目既有"**资源驱动 + 行为多态**"架构：

1. **一个场景** `projectile_laser_beam.tscn` + **一个脚本** `laser_beam.gd`（根节点 `Node2D`，`class_name LaserBeam`），用 `@export` 枚举 `mode` 切换 4 种镭射效果。
2. `laser_beam.gd` 内用 `match mode` 分发到 4 个 `_process_xxx(delta)` 函数，分别移植 laser 项目的 4 个 `.gd`。
3. 面板可调参数：`mode`（模式）、`beam_width`（粗细）、`beam_speed`（速度）、`beam_max_length`（长度）、`beam_color`（颜色）。
4. 新建 `laser_behavior.gd`（继承 `RangeBehavior`），只重写 `create_projectile()`，让武器发射 `LaserBeam` 而不是普通 `Projectile`。
5. 把 `weapon_laser.tscn` 的 `WeaponBehavior` 脚本从 `range_behavior.gd` 换成 `laser_behavior.gd`。

---

## 3. 改动总览

| # | 文件 | 改动性质 | 说明 |
| --- | --- | --- | --- |
| 1 | `scenes/projectiles/projectile_laser_beam.tscn` | **新建** | 激光光束场景（射线/线/粒子/蓄力线/爆发线） |
| 2 | `scenes/projectiles/laser_beam.gd` | **新建** | 光束脚本，`mode` 枚举 + 可调参数 + 4 种模式逻辑 |
| 3 | `scenes/weapons/range/laser_behavior.gd` | **新建** | 激光武器行为（发射光束而非子弹） |
| 4 | `scenes/weapons/range/weapon_laser.tscn` | 修改 | `WeaponBehavior` 脚本换成 `laser_behavior.gd` |
| 5 | `resources/items/weapons/range/laser/stats_laser_1.tres` | 修改（可选） | 调整冷却/射程/后坐力等 |

> 无需新建武器/物品资源；碰撞层无需改动（激光直接检测已有的第4层 HurtboxEnemy）。

---

## 4. 手把手步骤 1：新建激光光束场景 `projectile_laser_beam.tscn`

### 4.1 创建场景与根节点

1. 在编辑器左侧"文件系统"面板，右键 `scenes/projectiles/` → **新建场景（New Scene）**。
2. 根节点类型选 **Node2D**，名字改成 `ProjectileLaserBeam`。
3. 选中根节点，在右侧 Inspector 面板设置：
   | 属性 | 值 | 说明 |
   | --- | --- | --- |
   | `Z Index` | `10` | 让激光画在地图/敌人上方 |

### 4.2 添加子节点并按面板设置

按下面顺序给根节点添加子节点（选中根节点 → 点 `+` 添加，或右键 → Add Child Node）：

**① `Ray`（RayCast2D）** —— 射线检测，负责"命中敌人"
| 属性 | 值 | 说明 |
| --- | --- | --- |
| `Enabled` | ✅ 勾选 | 射线参与检测（HOT/FREEZE/MULTI 用） |
| `Target Position` | `(0, 0)` | 初始长度为 0，由脚本逐渐延伸 |
| `Collision Mask` | `8` | **只检测第4层 HurtboxEnemy（敌人受击盒）** |
| `Collide With Areas` | ✅ 勾选 | 敌人受击盒是 Area2D，必须开启 |

**② `Line2D`** —— 光束本体
| 属性 | 值 | 说明 |
| --- | --- | --- |
| `Points` | `[(0,0), (0,0)]` | 两个点，脚本会把第2个点沿 +X 拉长 |
| `Width` | `8` | 默认粗细（运行时会用 `beam_width` 覆盖） |
| `Default Color` | 青色 `(0.878, 1, 1)` | 默认颜色（运行时会用 `beam_color` 覆盖） |
| `Begin Cap Mode` | `Round`（2） | 圆头，更像激光 |
| `End Cap Mode` | `Round`（2） | 圆头 |

**③ `GPUParticles2D`** —— 命中点的火花粒子（HOT/BOOM 用）
| 属性 | 值 | 说明 |
| --- | --- | --- |
| `Visible` | ❌ 取消勾选 | 初始不显示，命中时才显示 |
| `Emitting` | ❌ 取消勾选 | 初始不发射 |
| `Amount` | `24` | 粒子数量 |
| `Lifetime` | `0.4` | 粒子存活时间（秒） |
| `Process Material` | 新建 `ParticleProcessMaterial` | 见下方 4.3 |

**④ `ShapeCast`（ShapeCast2D）** —— 形状扫掠检测，负责"爆裂"模式的范围命中
| 属性 | 值 | 说明 |
| --- | --- | --- |
| `Enabled` | ❌ 取消勾选 | 默认关闭，只有 BOOM 模式开启 |
| `Shape` | 新建 `RectangleShape2D`，`Size = (20, 20)` | 扫掠用的矩形形状 |
| `Target Position` | `(0, 0)` | 初始长度 0 |
| `Collision Mask` | `8` | 同样只检测敌人受击盒 |
| `Collide With Areas` | ✅ 勾选 | |

**⑤ `XuliLine`（Line2D）** —— 爆裂模式的"蓄力"细线
| 属性 | 值 | 说明 |
| --- | --- | --- |
| `Points` | `[(0,0), (0,0)]` | |
| `Width` | `32` | 蓄力线（脚本会设为 `beam_width * 4`） |
| `Default Color` | 白色半透明 `(1, 1, 1, 0.4)` | |

**⑥ `BoomLine`（Line2D）** —— 爆裂模式的"爆发"粗线
| 属性 | 值 | 说明 |
| --- | --- | --- |
| `Points` | `[(0,0), (0,0)]` | |
| `Width` | `40` | 爆发线（脚本会设为 `beam_width * 5`） |
| `Default Color` | 白色 `(1, 1, 1, 1)` | |

### 4.3 粒子材质（GPUParticles2D 的 Process Material）

选中 `GPUParticles2D`，在 Inspector 里点 `Process Material` 右侧 → **新建 ParticleProcessMaterial**，然后设置：

| 属性 | 值 | 说明 |
| --- | --- | --- |
| `Disable Z` | ✅ 勾选 | 2D 游戏必须勾选 |
| `Spread` | `45` | 粒子散开角度 |
| `Initial Velocity Min` | `60` | 最小初速度 |
| `Initial Velocity Max` | `160` | 最大初速度 |
| `Scale Min` / `Scale Max` | `6` / `6` | 粒子大小 |
| `Color Ramp` | 新建 `GradientTexture1D`，其 `Gradient` 用：白(不透明)→白(透明) | 让粒子淡出 |

> 这个粒子材质就是 laser 项目 `hot_laser.tscn` / `boom_laser.tscn` 里火花粒子的精简版，用来在命中点/爆发时制造火花。

### 4.4 完整 `.tscn` 参考

如果你不想在编辑器里逐项点，也可以**新建一个文本文件** `scenes/projectiles/projectile_laser_beam.tscn`，粘贴以下内容（前提是脚本文件路径 `res://scenes/projectiles/laser_beam.gd` 已存在，见步骤 2）：

```gdscript
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://scenes/projectiles/laser_beam.gd" id="1_beam"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_beam"]
size = Vector2(20, 20)

[sub_resource type="Gradient" id="Gradient_beam"]
offsets = PackedFloat32Array(0, 1)
colors = PackedColorArray(1, 1, 1, 1, 1, 1, 1, 0)

[sub_resource type="GradientTexture1D" id="GradientTexture1D_beam"]
gradient = SubResource("Gradient_beam")

[sub_resource type="ParticleProcessMaterial" id="ParticleProcessMaterial_beam"]
particle_flag_disable_z = true
spread = 45.0
initial_velocity_min = 60.0
initial_velocity_max = 160.0
scale_min = 6.0
scale_max = 6.0
color_ramp = SubResource("GradientTexture1D_beam")

[node name="ProjectileLaserBeam" type="Node2D"]
z_index = 10
script = ExtResource("1_beam")

[node name="Ray" type="RayCast2D" parent="."]
enabled = true
target_position = Vector2(0, 0)
collision_mask = 8

[node name="Line2D" type="Line2D" parent="."]
points = PackedVector2Array(0, 0, 0, 0)
width = 8.0
default_color = Color(0.8784314, 1, 1, 1)
begin_cap_mode = 2
end_cap_mode = 2

[node name="GPUParticles2D" type="GPUParticles2D" parent="."]
visible = false
emitting = false
amount = 24
lifetime = 0.4
process_material = SubResource("ParticleProcessMaterial_beam")

[node name="ShapeCast" type="ShapeCast2D" parent="."]
enabled = false
shape = SubResource("RectangleShape2D_beam")
target_position = Vector2(0, 0)
collision_mask = 8

[node name="XuliLine" type="Line2D" parent="."]
points = PackedVector2Array(0, 0, 0, 0)
width = 32.0
default_color = Color(1, 1, 1, 0.39215687)

[node name="BoomLine" type="Line2D" parent="."]
points = PackedVector2Array(0, 0, 0, 0)
width = 40.0
default_color = Color(1, 1, 1, 1)
```

---

## 5. 手把手步骤 2：编写 `laser_beam.gd` 并挂到根节点

新建脚本 `scenes/projectiles/laser_beam.gd`，粘贴以下完整代码，然后回到 `projectile_laser_beam.tscn`，选中根节点，在 Inspector 的 `Script` 属性里加载这个脚本。

```gdscript
extends Node2D
class_name LaserBeam

## =============================================================================
## LaserBeam —— 射线激光子弹（把 laser 项目的镭射效果整合为"一种子弹"）
## -----------------------------------------------------------------------------
## 一个场景 + 一个脚本表现 4 种镭射效果，通过面板 `mode` 枚举切换。
## 激光的粗细 / 速度 / 长度 都做成 @export，可在 Inspector 面板直接调试。
## =============================================================================

## —— 激光模式枚举（对应 laser 项目的 4 个 .gd）——
enum LaserMode {
    FREEZE,   # 冻结激光 freeze_laser：射出一段，命中敌人造成一次伤害并消失
    MULTI,    # 多重激光 multi_laser：命中墙体后反射（需墙体碰撞层，见第 11 节）
    HOT,      # 灼热激光 hot_laser：持续照射，持续掉血
    BOOM,     # 爆裂激光 boom_laser：先蓄力，再瞬间爆发粗光束
}

## ---------------------------------------------------------------------------
## 面板可调参数（Inspector）
## ---------------------------------------------------------------------------
@export var mode: LaserMode = LaserMode.FREEZE          # 选择哪种镭射效果
@export var beam_width: float = 8.0                     # 激光粗细（像素）
@export var beam_speed: float = 4000.0                  # 激光延伸速度（像素/秒）
@export var beam_max_length: float = 1000.0             # 激光最大长度（像素）
@export var beam_color: Color = Color(0.878, 1.0, 1.0)  # 激光颜色

## ---------------------------------------------------------------------------
## 运行时参数（由 LaserBehavior.fire() 注入）
## ---------------------------------------------------------------------------
var damage: float = 1.0
var critical: bool = false
var knockback: float = 0.0
var source: Node2D           # 攻击来源（玩家），用于击退方向
var target: Node2D           # 追踪目标（HOT 模式每帧指向它）

## ---------------------------------------------------------------------------
## 内部状态
## ---------------------------------------------------------------------------
var direction: Vector2 = Vector2.RIGHT   # 发射方向（FREEZE/MULTI/BOOM 用）
var travel_distance: float = 0.0         # 已飞行距离（MULTI 反射用）
var shooting := false
var fading := false
var _fade_tween: Tween
var _hot_accum := 0.0                    # HOT 模式 DPS 累加器
var _boom_hit: Array = []                # BOOM 模式已命中的敌人（防重复扣血）
var _boom_charging := true
var _boom_releasing := false

## ---------------------------------------------------------------------------
## 节点引用
## ---------------------------------------------------------------------------
@onready var ray: RayCast2D = $Ray
@onready var line: Line2D = $Line2D
@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var shape_cast: ShapeCast2D = $ShapeCast        # BOOM 用
@onready var xuli_line: Line2D = $XuliLine               # BOOM 蓄力线
@onready var boom_line: Line2D = $BoomLine               # BOOM 爆发线


## =============================================================================
## 发射入口
## =============================================================================

## 函数说明：由 LaserBehavior.create_projectile 调用，注入方向/伤害等参数并启动。
func fire(new_direction: Vector2, new_damage: float, is_critical: bool,
        new_knockback: float, new_source: Node2D, new_target: Node2D) -> void:
    direction = new_direction.normalized()
    damage = new_damage
    critical = is_critical
    knockback = new_knockback
    source = new_source
    target = new_target

    rotation = direction.angle()      # 让整条光束朝向发射方向（光束沿 +X 绘制）
    shooting = true
    _apply_visuals()

    # 按模式启用对应检测节点：射线模式用 RayCast2D，爆裂模式用 ShapeCast2D
    ray.enabled = mode != LaserMode.BOOM
    shape_cast.enabled = mode == LaserMode.BOOM
    particles.emitting = false
    _boom_hit.clear()
    _boom_charging = true
    _boom_releasing = false
    _hot_accum = 0.0
    travel_distance = 0.0


## 函数说明：根据面板参数设置线的颜色/粗细，并把所有线长度清零。
func _apply_visuals() -> void:
    line.default_color = beam_color
    line.width = beam_width
    xuli_line.default_color = beam_color
    xuli_line.width = beam_width * 4.0
    boom_line.default_color = beam_color
    boom_line.width = beam_width * 5.0

    line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
    xuli_line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
    boom_line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
    ray.target_position = Vector2.ZERO
    shape_cast.target_position = Vector2.ZERO


## =============================================================================
## 主循环：按模式分发
## =============================================================================
func _physics_process(delta: float) -> void:
    if not shooting:
        return
    match mode:
        LaserMode.FREEZE:
            _process_freeze(delta)
        LaserMode.MULTI:
            _process_multi(delta)
        LaserMode.HOT:
            _process_hot(delta)
        LaserMode.BOOM:
            _process_boom(delta)


## ---------------------------------------------------------------------------
## 模式 1：FREEZE（冻结激光）
## ---------------------------------------------------------------------------
func _process_freeze(delta: float) -> void:
    # 光束向前延伸（不超过最大长度）
    ray.target_position.x = minf(ray.target_position.x + beam_speed * delta, beam_max_length)
    line.points[1].x = ray.target_position.x

    # 命中敌人：造成一次伤害，然后消失
    if ray.is_colliding():
        _try_damage(ray.get_collider())
        _fade_out()
        return
    # 达到最大长度：消失
    if ray.target_position.x >= beam_max_length:
        _fade_out()


## ---------------------------------------------------------------------------
## 模式 2：MULTI（多重/反射激光）
## ---------------------------------------------------------------------------
func _process_multi(delta: float) -> void:
    if travel_distance > beam_max_length:
        _fade_out()
        return

    if ray.is_colliding():
        if _try_damage(ray.get_collider()):
            # 命中敌人：终止本光束
            travel_distance = beam_max_length
            _fade_out()
        else:
            # 命中墙体：反射（要求墙体在 Ray 的 collision_mask 内，见第 11 节）
            shooting = false
            _fade_out()
            _reflect(ray.get_collision_point(), ray.get_collision_normal())
    else:
        ray.target_position.x = minf(ray.target_position.x + beam_speed * delta, beam_max_length)
        line.points[1].x = ray.target_position.x
        travel_distance += beam_speed * delta


## 函数说明：在命中点按反弹方向生成一条新光束（反射）。
func _reflect(hit_point: Vector2, normal: Vector2) -> void:
    var reflected := direction.bounce(normal).normalized()
    var scene := load("res://scenes/projectiles/projectile_laser_beam.tscn") as PackedScene
    var new_beam := scene.instantiate() as LaserBeam
    get_tree().root.add_child(new_beam)
    new_beam.global_position = hit_point
    new_beam.fire(reflected, damage, critical, knockback, source, target)
    new_beam.travel_distance = travel_distance


## ---------------------------------------------------------------------------
## 模式 3：HOT（灼热激光，持续照射）
## ---------------------------------------------------------------------------
func _process_hot(delta: float) -> void:
    # 持续指向追踪目标（若目标仍有效）
    if is_instance_valid(target):
        rotation = global_position.direction_to(target.global_position).angle()

    if ray.is_colliding():
        # 命中：光束停在命中点，粒子出现在命中点
        ray.target_position.x = global_position.distance_to(ray.get_collision_point())
        line.points[1].x = ray.target_position.x
        particles.global_position = ray.get_collision_point()
        particles.emitting = true
        # 持续伤害：按 DPS 累积，攒够 1 点扣一次（避免每帧都触发受击流程）
        _hot_accum += damage * delta
        if _hot_accum >= 1.0:
            var ticks := int(_hot_accum)
            _hot_accum -= float(ticks)
            _try_damage(ray.get_collider(), float(ticks))
    else:
        ray.target_position.x = minf(ray.target_position.x + beam_speed * delta, beam_max_length)
        line.points[1].x = ray.target_position.x
        particles.emitting = false

    if ray.target_position.x >= beam_max_length:
        _fade_out()


## ---------------------------------------------------------------------------
## 模式 4：BOOM（爆裂激光：蓄力 → 爆发）
## ---------------------------------------------------------------------------
func _process_boom(delta: float) -> void:
    if _boom_charging:
        # 蓄力阶段：xuli_line 缓慢增长到最大长度
        if xuli_line.points[1].x < beam_max_length:
            xuli_line.points[1].x = minf(
                xuli_line.points[1].x + beam_speed * 0.25 * delta,
                beam_max_length)
        else:
            _boom_charging = false
            _boom_releasing = true
    elif _boom_releasing:
        # 爆发阶段：boom_line 快速扫过，用 ShapeCast 检测并伤害敌人
        if shape_cast.target_position.x < beam_max_length:
            shape_cast.target_position.x = minf(
                shape_cast.target_position.x + beam_speed * delta,
                beam_max_length)
            boom_line.points[1].x = shape_cast.target_position.x
            particles.emitting = true
            for i in shape_cast.get_collision_count():
                var collider := shape_cast.get_collider(i)
                if collider is HurtboxComponent and not _boom_hit.has(collider):
                    _boom_hit.append(collider)
                    _try_damage(collider)
        else:
            _fade_out()


## =============================================================================
## 伤害与消失
## =============================================================================

## 函数说明：对命中对象造成伤害；命中敌人返回 true，否则返回 false。
##          通过构造一个轻量 HitboxComponent 并 emit 受击盒的 on_damaged 信号，
##          复用项目统一的受击管线（格挡/受击闪白/伤害文字/击退）。
func _try_damage(collider: Object, amount: float = -1.0) -> bool:
    if amount < 0.0:
        amount = damage
    var hurtbox := collider as HurtboxComponent
    if hurtbox == null or not is_instance_valid(hurtbox):
        return false

    var src := source if is_instance_valid(source) else self
    var hitbox := HitboxComponent.new()
    hitbox.setup(amount, critical, knockback, src)
    hurtbox.on_damaged.emit(hitbox)   # 走统一受击管线
    hitbox.free()
    return true


## 函数说明：渐隐所有光束线后销毁自身。
func _fade_out() -> void:
    if fading:
        return
    fading = true
    shooting = false
    particles.emitting = false
    if _fade_tween:
        _fade_tween.kill()
    _fade_tween = create_tween()
    _fade_tween.tween_property(line, "width", 0.0, 0.3)
    _fade_tween.parallel().tween_property(xuli_line, "width", 0.0, 0.3)
    _fade_tween.parallel().tween_property(boom_line, "width", 0.0, 0.3)
    _fade_tween.tween_callback(queue_free)
```

### 5.1 代码要点说明

1. **为什么用 Tween 而不是 laser 项目的 AnimationPlayer？** 因为 `beam_width` 现在是面板可调的，渐隐动画的起始宽度应该是"当前宽度"而不是写死的 8。Tween 直接 `tween_property(line, "width", 0.0, 0.3)`，自动从当前宽度渐隐到 0，比写死关键帧的 AnimationPlayer 更合适。视觉效果和 laser 项目的 `fade` 动画一致。
2. **伤害适配**：`_try_damage()` 不直接 `hp -= 10`，而是构造 `HitboxComponent` 并 `hurtbox.on_damaged.emit(hitbox)`，这样格挡、受击闪白、伤害数字、击退都会照常生效。
3. **HOT 持续伤害**：用 `_hot_accum` 累加器，攒够 1 点才触发一次受击流程，避免每物理帧都弹伤害文字。`damage` 在此模式下语义是"每秒伤害（DPS）"。
4. **BOOM 两阶段**：laser 项目里爆裂需要第二次按键触发"爆发"，但武器是自动攻击，所以这里改成自动"蓄力→爆发→消失"，无需额外输入。

---

## 6. 手把手步骤 3：新建 `laser_behavior.gd`

新建脚本 `scenes/weapons/range/laser_behavior.gd`，粘贴以下代码：

```gdscript
extends RangeBehavior
class_name LaserBehavior

## =============================================================================
## LaserBehavior —— 激光武器行为（继承 RangeBehavior）
## -----------------------------------------------------------------------------
## 与普通远程武器唯一区别：create_projectile 不再生成会飞的 Projectile 子弹，
## 而是生成一条 LaserBeam 激光光束（沿武器朝向射出，命中敌人造成伤害）。
## 其余（后坐动画 / 开火音效 / 吸血 / 冷却）沿用 RangeBehavior.execute_attack。
## =============================================================================

## 激光光束场景。
const LASER_BEAM_SCENE = preload("res://scenes/projectiles/projectile_laser_beam.tscn")


## 函数说明：重写父类的 create_projectile，生成激光光束。
## 被谁调用：RangeBehavior.execute_attack（武器每次攻击时）。
func create_projectile() -> void:
    var beam := LASER_BEAM_SCENE.instantiate() as LaserBeam
    get_tree().root.add_child(beam)
    beam.global_position = muzzle.global_position

    # 发射方向 = 武器当前朝向（Vector2.RIGHT 旋转 weapon.rotation）。
    var dir := Vector2.RIGHT.rotated(weapon.rotation)
    beam.fire(
        dir,
        get_damage(),                  # 伤害（含暴击判定，来自 WeaponBehavior.get_damage）
        critical,                      # 本次是否暴击
        weapon.data.stats.knockback,   # 击退力度
        weapon.get_parent(),           # 来源 = 玩家
        weapon.closest_target          # 追踪目标 = 最近敌人
    )
```

> `muzzle`、`weapon`、`get_damage()`、`critical` 都是从 `RangeBehavior`/`WeaponBehavior` 继承来的，无需自己再定义。

---

## 7. 手把手步骤 4：把激光武器的行为脚本换成 `LaserBehavior`

打开 `scenes/weapons/range/weapon_laser.tscn`：

1. 在场景树里选中 `WeaponBehavior` 节点。
2. 在 Inspector 里找到 `Script` 属性，点右侧脚本图标 → **加载（Load）** → 选 `laser_behavior.gd`（替换原来的 `range_behavior.gd`）。
3. 确认 Inspector 里 `Weapon` 属性仍指向 `..`（即父节点武器本身）。武器场景的 `node_paths` 已配好，一般不用动。

改完后的 `weapon_laser.tscn` 关键部分长这样（对照参考）：

```gdscript
[ext_resource type="Script" path="res://scenes/weapons/range/laser_behavior.gd" id="3_50c4r"]

[node name="WeaponBehavior" parent="." index="3" node_paths=PackedStringArray("weapon")]
script = ExtResource("3_50c4r")
weapon = NodePath("..")
```

> 这一步完成后，商店里现有的 "Laser I~IV" 就会发射激光光束了。`RangeBehavior` 的 `muzzle`（枪口）与后坐动画仍照常工作。

---

## 8. 手把手步骤 5：调整激光数值资源 `stats_laser_1.tres`

打开 `resources/items/weapons/range/laser/stats_laser_1.tres`（在 Inspector 里就是 `WeaponStats` 面板），建议做如下调整：

| 属性 | 建议值 | 说明 |
| --- | --- | --- |
| `Cooldown` | `0.6` | 两次发射间隔（光束持续约 0.25s，0.6s 冷却合适） |
| `Max Range` | `450` | 武器自动索敌半径（决定多远开始打） |
| `Recoil` | `15` | 激光后坐力可以调小（激光没有实弹后坐） |
| `Damage` | `1.0` | 基础伤害（FREEZE/MULTI/BOOM 每击；HOT 为每秒伤害） |

> 注意：`Projectile Scene` 和 `Projectile Speed` 这两个字段**现在被 `LaserBehavior` 忽略**（它用自己预加载的 `projectile_laser_beam.tscn`），但保留它们不会报错。

### 8.1 激光的"粗细/速度/长度"在哪调？

在**光束场景**上调（这才是"面板调试"激光本身的地方）：打开 `scenes/projectiles/projectile_laser_beam.tscn`，选中根节点 `ProjectileLaserBeam`，Inspector 里就有：

| 属性 | 含义 | 默认 |
| --- | --- | --- |
| `Mode` | 切换 4 种镭射效果 | FREEZE |
| `Beam Width` | 激光粗细（像素） | 8 |
| `Beam Speed` | 延伸速度（像素/秒） | 4000 |
| `Beam Max Length` | 最大长度（像素） | 1000 |
| `Beam Color` | 激光颜色 | 青 |

因为激光武器每次攻击都用同一个 `projectile_laser_beam.tscn`，所以在这个场景上改参数 = 全局改这把激光的效果。

> 进阶：如果想"每把激光武器（I~IV）参数不同"，可以把 `beam_width/speed/length` 提升到 `WeaponStats` 作为字段，再由 `LaserBehavior` 传给 `beam.fire()`。思路和第 9 节"四种模式调参"一致，但需额外改 `weapon_stats.gd`。本文采用"光束场景导出"方案，最简单。

---

## 9. 四种镭射模式详解与调参

切换方式：`projectile_laser_beam.tscn` 根节点的 `Mode` 下拉框。推荐参数（对应 laser 项目手感）：

| Mode | 推荐 `Beam Width` | 推荐 `Beam Speed` | 推荐 `Beam Max Length` | 推荐 `Beam Color` | 手感 |
| --- | --- | --- | --- | --- | --- |
| FREEZE 冻结 | 8 | 4000 | 1000 | 青 (0.878,1,1) | 短促一刺，命中即消失 |
| MULTI 多重 | 8 | 8000 | 8000 | 黄 (1,0.92,0.23) | 极快极长，配合反射（需墙体） |
| HOT 灼热 | 10 | 2000 | 2000 | 粉 (1,0.176,0.33) | 持续约 1 秒的照射，持续掉血 |
| BOOM 爆裂 | 8 | 4000 | 1000 | 紫/白 | 蓄力（细线变长）→ 爆发粗光束 |

- **FREEZE**：`beam_speed` 决定"刺出"多快，`beam_max_length` 决定能打多远。
- **MULTI**：只有在墙体有碰撞层时才会反射（见第 11 节）；没有墙体时和 FREEZE 一样只打敌人。
- **HOT**：`damage` 是"每秒伤害"，持续时长 ≈ `beam_max_length / beam_speed`（默认 2000/2000 = 1 秒）。它会每帧转向 `target`（最近敌人），所以追踪目标跑动时激光会跟着转。
- **BOOM**：蓄力速度 = `beam_speed * 0.25`（慢），爆发速度 = `beam_speed`（快），忠实还原 laser 项目 `xuli_speed=1000` / `boom_speed=4000` 的对比。

---

## 10. 碰撞层对照表

项目在 `project.godot` 里定义了 6 个物理层（二进制值 = 第 N 层 = `2^(N-1)`）：

| 层名（第 N 层） | 二进制值 | 用途 |
| --- | --- | --- |
| Player（第1层） | 1 | 玩家本体（+ 玩家身上无碰撞的墙体视觉） |
| Enemy（第2层） | 2 | 敌人本体 Area2D |
| HitboxEnemy（第3层） | 4 | 敌人攻击盒 |
| **HurtboxEnemy（第4层）** | **8** | **敌人受击盒（激光要检测的层）** |
| HitboxPlayer（第5层） | 16 | 玩家攻击盒（子弹的 HitboxComponent） |
| HurtboxPlayer（第6层） | 32 | 玩家受击盒 |

激光的 `Ray` 和 `ShapeCast` 都设 `collision_mask = 8`，即**只检测敌人的受击盒（HurtboxComponent）**：

- `ray.get_collider()` 返回的是 `HurtboxComponent`；
- `_try_damage()` 通过 `hurtbox.on_damaged.emit(hitbox)` 触发 `Unit._on_hurtbox_component_on_damaged`，完整走格挡/闪白/伤害文字/击退。

> 为什么不用第2层 Enemy 本体？因为敌人本体 CollisionShape2D 半径只有约 4px（`enemy_chaser_slow.tscn` 里 `radius = 4.12`），而受击盒半径约 37px，用第4层更稳、命中手感更接近普通子弹。

---

## 11. （可选）让激光被墙体阻挡 / 反射

默认 `collision_mask = 8` 只检测敌人，激光会**穿透地图边缘**（当前地图的 TileMapLayer 没有物理碰撞层，敌人/玩家本来就能自由走动，边界由玩家位置 clamp 限制）。所以：

- **FREEZE / HOT / BOOM 穿透墙体**：无影响，本来就只有敌人在第4层。
- **MULTI 反射**：需要墙体有碰撞层才能 `ray.get_collision_point()/get_collision_normal()` 反射。

如果想做完整的"激光被墙挡 / 反射"，需要额外给墙体加一个独立碰撞层（**不要用第1层，因为第1层是玩家本体**，会让激光误伤自己）：

1. 打开 `scenes/arena/map_area.tscn` 的 `water`/`green` TileMapLayer，在 Inspector → `Tile Set` 里给其物理层设置一个专用碰撞层（例如**第7层**，二进制值 64）。或在 tileset 资源 `tilleset/map_normal.tres` 的 Physics Layer 0 里把 `Collision Layer` 设为第7层。
2. 把 `projectile_laser_beam.tscn` 里 `Ray` 和 `ShapeCast` 的 `Collision Mask` 改为 `8 + 64 = 72`（同时勾选第4层和第7层）。
3. 这样 `MULTI` 命中墙体会走 `_reflect()`，生成反射光束；FREEZE/HOT 命中墙体会停在墙点。

> 这一步涉及给 tileset 加物理层，工程较繁琐，属于可选进阶，不影响激光打敌人的核心功能。

---

## 12. 验证清单

1. 保存所有新脚本后，Godot 编辑器无解析错误（`LaserBeam` / `LaserBehavior` 的 `class_name` 正常注册；若报 `LaserBeam` 找不到，先重启一次编辑器让脚本类刷新）。
2. 进入游戏选激光武器，攻击最近敌人：应看到一条**发光的激光线**从枪口刺出，命中后渐隐消失。
3. 在 `projectile_laser_beam.tscn` 把 `Beam Width` 改成 `20`、`Beam Speed` 改成 `8000`、`Beam Max Length` 改成 `2000`，运行观察：线更粗、延伸更快、打得更远——证明三个面板参数都生效。
4. 依次切 `Mode` 为 FREEZE / MULTI / HOT / BOOM，观察：
   - FREEZE：短促一刺；
   - MULTI：极快极长的黄线；
   - HOT：持续约 1 秒的粉线，命中点有火花，且会跟着敌人转；
   - BOOM：先一条半透明细线蓄力变长，再瞬间爆发一条粗线并溅出火花。
5. 命中敌人时：敌人会受击闪白、头顶弹出伤害数字、受击音效，死亡掉金币（验证伤害走的是统一管线，没绕过格挡）。
6. 让敌人贴脸时攻击：激光不会打到自己（因为 mask 只有第4层，不包含玩家本体第1层 / 玩家受击盒第6层）。

---

## 13. 常见问题与扩展

### 13.1 激光没有"辉光（glow）"感

laser 项目的发光感来自 `WorldEnvironment` 的 `Glow` + 高亮颜色。plant_def 项目默认没开 glow。可选做法：给光束场景加一个更亮的 `beam_color`，或在 `Line2D` 上叠加一条更宽、半透明的"外发光"线（再复制一个 `Line2D`，`width` 设为 `beam_width * 3`，颜色 alpha 调低，放在主线下层）。

### 13.2 HOT 光束想跟随玩家移动

`_process_hot` 里光束起点固定在发射瞬间的枪口位置。若玩家边走边打想让它跟着走，可在 `_process_hot` 开头加：

```gdscript
    if is_instance_valid(source):
        global_position = source.global_position
```

### 13.3 想让"粗细/速度/长度"每把武器可调（数据驱动）

把 `beam_width/beam_speed/beam_max_length/mode` 提升为 `WeaponStats` 的导出字段，再在 `LaserBehavior.create_projectile()` 里读取并传给 `beam.fire()`。扩展方式与 `projectile_trajectory_merge_plan.md` 里"弹道类型"的做法完全一致。

### 13.4 冻结激光的"减速"效果

laser 项目的 freeze 命中会 `speed -= 50`（减速）。plant_def 敌人速度在 `enemy.stats.speed`。若想做减速，可在 `_try_damage` 命中后临时下调 `enemy.stats.speed` 并用一个 Timer 恢复（注意别把敌人永久减速）。

---

## 附：改动文件清单汇总

| 文件 | 状态 |
| --- | --- |
| `scenes/projectiles/projectile_laser_beam.tscn` | 新建（激光光束场景） |
| `scenes/projectiles/laser_beam.gd` | 新建（光束脚本，mode 枚举 + 4 模式 + 可调参数） |
| `scenes/weapons/range/laser_behavior.gd` | 新建（发射激光光束的武器行为） |
| `scenes/weapons/range/weapon_laser.tscn` | 修改（WeaponBehavior 脚本换成 laser_behavior.gd） |
| `resources/items/weapons/range/laser/stats_laser_1.tres` | 修改（可选，调冷却/射程/后坐力） |

*文档生成时间：2026-10-20*
