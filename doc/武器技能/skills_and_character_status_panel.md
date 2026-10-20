# 角色特色技能 + 角色状态面板 实现方案

> 目标：
> 1. 每个角色有**可调整的初始血量、初始体力**两个变量（不同角色不同数值）。
> 2. 每个角色拥有 **2 个不同的特色技能**，绑定按键 **Q** 和 **E**，释放后进入冷却。
> 3. **每个角色的技能使用一个单独的脚本实现**（一个角色一个技能脚本，脚本内包含该角色的两个技能）。
> 4. 战斗场景左上角新增一个**角色状态面板**：显示头像、血量、体力，以及两个带冷却倒计时的方形技能图标。

---

## 1. 需求概述

| 需求 | 实现方式 |
| --- | --- |
| 初始血量可调（不同角色不同） | `UnitStats.health`（`@export`，已存在，直接在每个角色的 `.tres` 里填不同值） |
| 初始体力可调（不同角色不同） | `UnitStats.stamina`（`@export`，**新增**） |
| 每个角色 2 个不同技能 | 每个角色一个 `CharacterSkills` 子类脚本，内含 `_execute_skill_1()` / `_execute_skill_2()` |
| 每个角色技能用单独脚本实现 | 5 个脚本：`brawler_skills.gd`、`bunny_skills.gd`、`crazy_skills.gd`、`knight_skills.gd`、`well_rounded_skills.gd` |
| Q / E 释放 + 冷却 | `project.godot` 加 `skill_1`(Q) / `skill_2`(E)，基类里用两个 `Timer` 管理冷却 |
| 状态面板（头像 + 血/体力 + 技能图标 + 冷却） | 新增 `CharacterStatus` HUD，挂到 `arena.tscn` |

---

## 2. 现有架构分析（关键文件）

| 关注点 | 文件 | 说明 |
| --- | --- | --- |
| 单位数值 | `resources/units/unit_stats.gd` | `UnitStats`，含 `health`(已可调)、damage/speed/luck/block_chance 等，**无体力、无技能字段** |
| 玩家逻辑 | `scenes/unit/players/player.gd` | `extends Unit`，处理移动/冲刺/朝向/回血/武器装配 |
| 玩家基场景 | `scenes/unit/players/player_well_rounded.tscn` | 玩家基场景；**同时它本身也是 "Well Rounded" 这个可选角色**，其余 4 个角色 instance 它并覆盖 stats/Sprite |
| 5 个角色场景 | `scenes/unit/players/player_brawler.tscn` 等 | instance `player_well_rounded.tscn`，覆盖 `stats` 与 `Sprite.texture` |
| 角色数据 | `resources/units/players/stats_player_*.tres`（5 个） | 每个角色的 `UnitStats` |
| 全局单例 | `autoloads/global.gd` | `available_players`、`player`、`main_player_selected` |
| 战斗 UI 根 | `scenes/arena/arena.tscn` | `GameUI`(CanvasLayer) 下挂 CoinsBag / WaveLabel / Shop / Upgrade / Selection |
| 现有 HUD 范例 | `scenes/ui/health_bar/*`、`scenes/ui/stats_container/*` | 血条用信号刷新；StatsContainer 每帧轮询 `Global.player` |
| 伤害判定 | `scenes/components/hitbox_component.gd` / `hurtbox_component.gd` | Hitbox(Area2D) 重叠 Hurtbox → 触发受伤 |
| 输入映射 | `project.godot` `[input]` | 现有 move(WASD)、dash(Space) |

关键结论：
- **血量已是可调变量**：`health` 就是 `UnitStats` 的 `@export` 字段，各角色 `.tres` 已填不同值（Brawler=25、Knight=30 等），无需改动；只需照此新增 `stamina`。
- 项目是「脚本 + 场景」分层，**用独立脚本实现每个角色技能**完全契合现有风格（如 `enemy_charger` 有独立的 `charge_behavior.gd`）。
- 敌人未用 `group`，检测/命中敌人靠 **Area2D 碰撞层**（敌人 Hurtbox = layer 4 / 值 8）。

---

## 3. 总体设计

### 3.1 架构

```
Player (player.gd)
  ├─ 管理体力：current_stamina + 每帧回复
  ├─ 读输入：skill_1(Q) / skill_2(E) → 转交 Skills 节点
  └─ Skills (Node，挂载「该角色的技能脚本」)
       ├─ CharacterSkills（基类）：冷却计时、体力消耗判定、HUD 查询接口
       └─ 每个角色一个子类脚本：brawler_skills / bunny_skills / crazy_skills / knight_skills / well_rounded_skills
            各自重写 _execute_skill_1() 与 _execute_skill_2()
```

- **初始血量 / 初始体力**：都在 `UnitStats` 上作为 `@export` 变量，每个角色 `.tres` 填不同值，Inspector 里即可调整。
- **技能**：不做成数据资源（不用 `SkillData`），而是**每个角色一个脚本**。脚本里用 `@export` 声明该角色两个技能的图标、冷却、体力消耗，并重写两个执行函数实现效果。
- **冷却**：由基类 `CharacterSkills` 在代码里创建两个 `Timer` 统一管理，子类只需写"放技能做什么"。

### 3.2 新增 / 修改文件一览

**新增：**
```
scenes/unit/players/skills/character_skills.gd       # 技能基类 CharacterSkills
scenes/unit/players/skills/brawler_skills.gd         # Brawler 技能脚本
scenes/unit/players/skills/bunny_skills.gd           # Bunny 技能脚本
scenes/unit/players/skills/crazy_skills.gd           # Crazy 技能脚本
scenes/unit/players/skills/knight_skills.gd          # Knight 技能脚本
scenes/unit/players/skills/well_rounded_skills.gd    # Well Rounded 技能脚本
scenes/ui/character_status/character_status.gd       # 状态面板脚本
scenes/ui/character_status/character_status.tscn     # 状态面板场景
```

**修改：**
```
resources/units/unit_stats.gd                        # 新增 stamina / stamina_regen
resources/units/players/stats_player_*.tres          # 5 个角色填入初始体力
scenes/unit/players/player.gd                        # 体力管理 + 输入转交 + HUD 查询委托
scenes/unit/players/player_well_rounded.tscn         # 加 Skills 节点(挂 well_rounded_skills)
scenes/unit/players/player_brawler.tscn 等 4 个      # 覆盖 Skills 节点脚本为各自技能脚本
scenes/arena/arena.tscn                              # GameUI 下挂 CharacterStatus
project.godot                                        # [input] 新增 skill_1(Q) / skill_2(E)
```

---

## 4. 详细实现步骤

### 步骤 1：`UnitStats` 新增可调的体力变量

修改 `resources/units/unit_stats.gd`，在 `harvesting` 之后追加：

```gdscript
## 初始体力值上限（每个角色在 .tres 里填不同值）。
@export var stamina := 100.0

## 体力每秒回复量。
@export var stamina_regen := 10.0
```

> 血量：`health` 已经是 `@export` 可调变量（每个角色 `.tres` 已填不同初始值），**无需改动**。
> 敌人 `.tres` 也会带上这两个字段，用默认值即可（敌人不使用）。

---

### 步骤 2：5 个角色 `.tres` 填入初始体力

为每个角色在 `resources/units/players/stats_player_*.tres` 里追加 `stamina` / `stamina_regen`，例如：

| 角色 | 初始血量 `health`（已有） | 初始体力 `stamina`（新增，示例值） |
| --- | --- | --- |
| Brawler | 25 | 120 |
| Bunny | 20 | 100 |
| Crazy | 15 | 80 |
| Knight | 30 | 100 |
| Well Rounded | 15 | 100 |

示例（`stats_player_brawler.tres` 末尾追加）：

```text
stamina = 120.0
stamina_regen = 12.0
```

> 数值均为占位示例，可在 Inspector / `.tres` 中自由调整。

---

### 步骤 3：技能基类 `CharacterSkills`

新建 `scenes/unit/players/skills/character_skills.gd`：

```gdscript
extends Node
class_name CharacterSkills
## CharacterSkills（角色技能基类 / Node）
## 作用：定义两个技能（Q/E）的公共框架：冷却计时、体力消耗判定、输入触发，
##       以及对 HUD 的查询接口。具体技能效果由子类重写 _execute_skill_1/2。


## 技能 1 名称（显示用，可选）。
@export var skill_1_name := "Skill 1"
## 技能 2 名称。
@export var skill_2_name := "Skill 2"

## 技能 1 图标。
@export var skill_1_icon: Texture2D
## 技能 2 图标。
@export var skill_2_icon: Texture2D

## 技能 1 冷却时间（秒）。
@export var skill_1_cooldown := 3.0
## 技能 2 冷却时间（秒）。
@export var skill_2_cooldown := 3.0

## 技能 1 体力消耗。
@export var skill_1_stamina_cost := 20.0
## 技能 2 体力消耗。
@export var skill_2_stamina_cost := 20.0


var player: Player
var _skill_1_timer: Timer
var _skill_2_timer: Timer


func _ready() -> void:
	# Skills 作为玩家的子节点，get_parent() 即 Player。
	player = get_parent() as Player
	_skill_1_timer = _make_timer()
	_skill_2_timer = _make_timer()


func _make_timer() -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	add_child(timer)
	return timer


## 尝试施放技能 1（Q）。
func try_cast_skill_1() -> void:
	_try_cast(_skill_1_timer, skill_1_cooldown, skill_1_stamina_cost, _execute_skill_1)


## 尝试施放技能 2（E）。
func try_cast_skill_2() -> void:
	_try_cast(_skill_2_timer, skill_2_cooldown, skill_2_stamina_cost, _execute_skill_2)


func _try_cast(timer: Timer, cooldown: float, cost: float, exec: Callable) -> void:
	# 冷却未结束 / 体力不足则不能施放。
	if not timer.is_stopped():
		return
	if player.current_stamina < cost:
		return
	# 扣体力 → 执行技能 → 进入冷却。
	player.current_stamina -= cost
	exec.call()
	timer.wait_time = cooldown
	timer.start()


## 技能 1 具体效果（子类重写）。
func _execute_skill_1() -> void:
	pass


## 技能 2 具体效果（子类重写）。
func _execute_skill_2() -> void:
	pass


## HUD 查询：某个技能槽的剩余冷却时间（slot：0=技能1，1=技能2）。
func get_cooldown_time_left(slot: int) -> float:
	return (_skill_1_timer if slot == 0 else _skill_2_timer).time_left


## HUD 查询：某个技能槽的总冷却时间。
func get_cooldown_total(slot: int) -> float:
	return (_skill_1_timer if slot == 0 else _skill_2_timer).wait_time


## HUD 查询：某个技能槽的图标。
func get_icon(slot: int) -> Texture2D:
	return skill_1_icon if slot == 0 else skill_2_icon
```

---

### 步骤 4：每个角色一个技能脚本（子类）

每个脚本继承 `CharacterSkills`，只重写 `_execute_skill_1()` 和 `_execute_skill_2()`，并在各自角色的场景里填好图标 / 冷却 / 体力消耗。

**完整示例 —— `brawler_skills.gd`：**

```gdscript
extends CharacterSkills
class_name BrawlerSkills
## Brawler 技能：Q 狂暴（临时增伤），E 战吼（范围伤害 + 击退）。


## 攻击盒场景（用场景实例化而不是 HitboxComponent.new()：场景里带了
## area_entered → _on_area_entered 的信号连接，受击音效在那边播放）。
const HITBOX_SCENE := preload("res://scenes/components/hitbox_component.tscn")


## Q 狂暴：临时提升伤害，5 秒后还原。
func _execute_skill_1() -> void:
	var bonus := 5.0
	player.stats.damage += bonus
	# 5 秒后撤销增益。
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(player):
		player.stats.damage -= bonus


## E 战吼：对周围敌人造成范围伤害并击退。
func _execute_skill_2() -> void:
	# 实例化临时攻击盒，命中敌人 Hurtbox（layer 4 = 值 8）。
	var hitbox := HITBOX_SCENE.instantiate() as HitboxComponent
	# 必须同时设置 collision_layer：本项目的命中判定是"由受击方检测攻击盒"
	# （敌人 HurtboxComponent 是 layer=8 / mask=16），攻击盒只有位于
	# HitboxPlayer(layer_5 = 16) 层才会被它检测到。只设 collision_mask
	# 不设 collision_layer（默认 layer_1 = 1）时，敌人受击盒完全看不到这个
	# 盒子，技能会「静默失效、一点伤害都没有」。
	# 与近战武器 weapon_*.tscn 里的 HitboxComponent 设置保持一致。
	hitbox.collision_layer = 16      # HitboxPlayer 层
	hitbox.collision_mask = 8        # 命中敌人 Hurtbox（layer_4 = 8）
	hitbox.monitoring = true
	hitbox.damage = player.stats.damage + 10.0
	hitbox.critical = false
	hitbox.knockback_power = 200.0
	hitbox.source = player

	# 给攻击盒加一个圆形碰撞体，半径 = 技能范围。
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 120.0
	shape.shape = circle
	hitbox.add_child(shape)

	player.add_child(hitbox)
	hitbox.global_position = player.global_position

	# 等一个物理帧完成重叠判定后回收（避免重复命中）。
	await get_tree().physics_frame
	hitbox.queue_free()
```

> 说明：范围伤害复用了现有 `HitboxComponent` → 敌人 `HurtboxComponent.on_damaged` → `Unit._on_hurtbox_component_on_damaged` 的既有链路，无需改敌人代码。

> **三点已实测确认的细节（Godot 4.7.2 无头运行验证）：**
> - **碰撞层必须设**：攻击盒放在 `HitboxPlayer`(layer_5 = 16) 层、敌人 `HurtboxComponent`（layer_4 = 8 / mask = 16）才检测得到它。实测：只设 `collision_mask = 8`、`collision_layer` 保持默认（layer_1）时，受击盒**永远收不到 `area_entered`，命中数恒为 0**；加上 `collision_layer = 16` 后立刻命中。这也是 `weapon_sword.tscn` 等近战武器里 `HitboxComponent` 的写法（`collision_layer = 16` / `collision_mask = 8`）。
> - **回收时机够用**：`await get_tree().physics_frame` 一帧就够（实测该帧内受击盒已完成 `area_entered` 判定），不需要等两帧；`queue_free()` 也在此之后执行，不会再命中第二波。
> - **受击音效**：`SoundManager.play_sound(ENEMY_HIT)` 是写在 `HitboxComponent._on_area_entered` 里的，而 `area_entered` 的信号连接在 **`hitbox_component.tscn` 场景文件**里（脚本里没有 `_ready` 连接）。所以 `HitboxComponent.new()` 动态创建的盒子不会播放受击音效，用上面的 `HITBOX_SCENE.instantiate()` 才与近战武器表现一致。（`monitoring` 其实不是必须的——判定由敌人受击盒驱动——保留无害。）

**其余 4 个角色的技能脚本**（占位，均按上面同款结构实现）：

| 角色 | Q（`_execute_skill_1`） | E（`_execute_skill_2`） |
| --- | --- | --- |
| Bunny | 疾跑：`player.stats.speed` 临时提升后还原 | 跳跃：位移 + 短暂无敌（`collision.set_deferred("disabled", true)` 后还原） |
| Crazy | 疯狂：临时大幅增伤 | 爆裂：小半径高伤害 AoE（同战吼，半径更小伤害更高） |
| Knight | 圣盾：`health_component.heal(...)` 回血 | 圣光斩：范围 AoE（同战吼模板） |
| Well Rounded | 治疗术：`health_component.heal(...)` + `Global.on_create_heal_text.emit(...)` | 全面强化：临时提升多项属性后还原 |

每个脚本的图标 / 冷却 / 体力消耗在该角色的场景里通过 Inspector 设置（见步骤 6）。

---

### 步骤 5：`Player` 增加体力管理与技能触发

修改 `scenes/unit/players/player.gd`：

> **先说清 `Skills` 到底是什么节点**：它是**步骤 6 在玩家场景里新增的一个普通 `Node` 子节点**——不是新场景、不是 Player 脚本的一部分、也不是某种特殊节点类型。`player.gd` 只做"读 Q/E 输入 → 转交"，真正干什么由那个节点上挂的脚本决定。
>
> **为什么 `player.gd`（5 个角色共用）引用它不会"写死某一个角色"：**
> - `Skills` 节点的**脚本**是每个角色在自己的 `.tscn` 里覆盖的：Brawler 场景挂 `brawler_skills.gd`、Bunny 场景挂 `bunny_skills.gd`……
> - `player.gd` 只按**基类** `CharacterSkills` 取用、只调**基类方法** `try_cast_skill_1()`；`_execute_skill_1()` / `_execute_skill_2()` 是虚函数，运行时会分派到该节点实际脚本（子类）的实现。所以共用脚本不会锁死技能。
> - 玩家的生成路径本身就是"按角色场景实例化"：`Global.available_players`（角色名 → `PackedScene`）→ `Global.get_selected_player()` 实例化的就是**该角色自己的场景**，场景里带的 `Skills` 节点自然就是该角色的技能脚本。**技能随角色实例一起生成，不需要在生成代码里做任何判断。**
> - 真正会"写死角色"的写法只有两种：把类型标注写成具体子类（如 `BrawlerSkills`），或在 `player.gd` 里按角色名 `if`/`match` 分支。本方案都没有、也不要这样做。

**5.1 节点引用**

```gdscript
## 技能节点（普通 Node 子节点，挂载该角色的 CharacterSkills 子类脚本）。
## 类型标注必须是基类 CharacterSkills——写成具体子类才真的会写死角色。
@onready var skills: CharacterSkills = $Skills
```

**5.2 运行时变量**

```gdscript
## 当前体力值。
var current_stamina := 0.0
```

**5.3 `_ready` 初始化体力**

```gdscript
func _ready() -> void:
	super._ready()
	dash_timer.wait_time = dash_duration
	dash_cooldown_timer.wait_time = dash_cooldown
	# 初始体力 = 体力上限（来自该角色的 stats.stamina）。
	current_stamina = stats.stamina
```

**5.4 `_process` 末尾追加体力回复与技能输入**

在 `_process` 现有逻辑（`update_rotation()` 之后）追加：

```gdscript
	# 体力自然回复（不超过上限）。
	regen_stamina(delta)
	# 技能输入：Q/E → 转交给 Skills 节点。
	if Input.is_action_just_pressed("skill_1"):
		skills.try_cast_skill_1()
	if Input.is_action_just_pressed("skill_2"):
		skills.try_cast_skill_2()
```

**5.5 新增方法**

```gdscript
## 函数说明：每秒回复体力，不超过上限。
func regen_stamina(delta: float) -> void:
	current_stamina = min(current_stamina + stats.stamina_regen * delta, stats.stamina)
```

> HUD 需要读冷却 / 图标，可直接 `Global.player.skills.get_cooldown_time_left(0)` 等，无需再在 Player 写委托。

---

### 步骤 6：玩家场景挂载技能节点（每个角色独立脚本）

**6.1 基场景加 `Skills` 节点**

在 `scenes/unit/players/player_well_rounded.tscn` 末尾（`HPRegenTimer` 之后）新增一个 `Skills` 节点，挂 Well Rounded 自己的脚本：

```text
[node name="Skills" type="Node" parent="." index="12"]
script = ExtResource("<well_rounded_skills 的 uid>")
```

同时在这个节点上设置 Well Rounded 的图标 / 冷却 / 体力消耗（用 `skill_1_icon = ExtResource(...)` 等）。

**6.2 其余 4 个角色覆盖脚本**

由于其余角色都 instance `player_well_rounded.tscn`，它们会继承这个 `Skills` 节点；只需在各自的 `.tscn` 里**覆盖该节点的 `script` 属性**为其技能脚本即可。例如 `player_brawler.tscn`：

```text
[node name="Skills" parent="." index="12"]
script = ExtResource("<brawler_skills 的 uid>")
skill_1_icon = ExtResource("<brawler_q_icon_uid>")
skill_2_icon = ExtResource("<brawler_e_icon_uid>")
skill_1_cooldown = 6.0
skill_2_cooldown = 8.0
skill_1_stamina_cost = 30.0
skill_2_stamina_cost = 40.0
```

依次处理 `player_bunny.tscn`、`player_crazy.tscn`、`player_knight.tscn`。

> 若在 Godot 编辑器里操作：打开角色场景 → 选中继承来的 `Skills` 节点 → 把「脚本」换成该角色技能脚本 → 在 Inspector 填图标/冷却/体力消耗即可。

> **该机制已实测可用**（Godot 4.7.2 无头运行）：基场景子节点挂 `skills_base.gd`，继承场景里用
> `[node name="Skills" parent="." index="0"]` + `script = ExtResource("<子类脚本>")` 覆盖后，
> 实例化出的节点脚本确实是子类（`who()` 返回子类结果），且子类 `extends` 基类。
> 也就是说"每个角色场景自带自己的技能脚本"这条路是通的，不需要改生成代码。
> 小提醒：若编辑器 Inspector 不让改继承节点的「脚本」属性，就按上面的文本方式直接改 `.tscn`（同样有效）；
> 另外这种"覆盖"关系只存在于场景文件里，**新增第 6 个角色时必须记得覆盖 `Skills` 节点的脚本**，
> 否则它会静默沿用基场景（Well Rounded）的技能——这是本方案唯一的维护成本。

---

### 步骤 7：输入映射新增 `skill_1` / `skill_2`

在 `project.godot` 的 `[input]` 段新增（Q = physical_keycode 81，E = 69，参考现有 A/D/W/S/Space 写法）：

```text
skill_1={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":81,"key_label":0,"unicode":113,"location":0,"echo":false,"script":null)
]
}
skill_2={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":69,"key_label":0,"unicode":101,"location":0,"echo":false,"script":null)
]
}
```

> 也可在 Godot 编辑器「项目设置 → 输入映射」添加 `skill_1`、`skill_2` 动作并绑定 Q/E。

> **这与现有 `move_left/right/up/down`、`dash` 的做法完全一致**：都是先在「项目设置 → 输入映射」里建动作，脚本里只用 `Input.is_action_just_pressed("skill_1")` 这样的**动作名**，不出现任何键码常量（不写 `KEY_Q`、不写 `physical_keycode`）。所以按键以后可以随意改绑，脚本一行都不用动。
> 推荐用编辑器添加动作；上面手写的 `[input]` 文本只是"等价的文件内容"，`Object(InputEventKey,...)` 那一长串容易写错。
> 另外注意：目前技能按键的**读取放在 `Player._process`**（和移动/冲刺同一处），这是有意的——玩家节点只在战斗场景里存在，不需要额外的输入路由层。

---

### 步骤 8：新增角色状态面板 HUD 并接入战斗场景

#### 8.1 面板场景 `scenes/ui/character_status/character_status.tscn`

结构（`Control` 根，锚点左上角）：

```
CharacterStatus (Panel，左上角，330×208)
└─ MarginContainer
    └─ VBoxContainer
        ├─ Top (HBoxContainer)                    ← 视觉上"一行"：头像 + 血/体力
        │   ├─ Face (TextureRect 96×96)           ← 角色头像（stats.icon）
        │   └─ Bars (VBoxContainer)               ← 头像右边的两条
        │       ├─ HPRow (HBoxContainer)          ← 血条这一行本身
        │       │   ├─ HPBar   (ProgressBar)      ← 左边：条，宽度自动撑满
        │       │   └─ HPValue (Label)            ← 右边：数字，固定 56 宽、右对齐
        │       └─ StaminaRow (HBoxContainer)     ← 体力那一行（结构同上）
        │           ├─ StaminaBar   (ProgressBar)
        │           └─ StaminaValue (Label)
        └─ Skills (HBoxContainer, alignment=center) ← 正下方：两个方形技能格
            ├─ Skill1 (Panel 80×80)
            │   ├─ Skill1Icon     (TextureRect)
            │   ├─ Skill1Overlay  (ColorRect)     ← 冷却遮罩（叠在图标上面）
            │   ├─ Skill1Cooldown (Label)         ← 剩余秒数（叠在最上面）
            │   └─ KeyHint1       (Label "Q")
            └─ Skill2 (Panel 80×80)
                └─ …（同 Skill1，按键提示 "E"）
```

> **层级注意**：`HPBar` 和 `HPValue` 是**兄弟**，都挂在 `HPRow` 这个 `HBoxContainer` 下，是**并排**关系（条在左、数字在右），**不是**父子/叠加关系。节点路径分别是
> `MarginContainer/VBoxContainer/Top/Bars/HPRow/HPBar` 与 `.../HPRow/HPValue`。
> （和玩家头顶那个 `health_bar.tscn` 不一样：那个是数字 `Label` 叠在条上的父子关系；这里刻意做成并排，免得数字压在条上。）

- 血条 / 体力条：复用 `health_bar.tscn` 的做法（`ProgressBar` + 数字 `Label`），体力条用不同颜色（如蓝色）。
- 技能冷却遮罩：用一个**铺满图标**的半透明黑 `ColorRect`，把 `pivot_offset` 设到**底边中点**，代码里只改 `scale.y = 剩余/总冷却`，遮罩就会从下往上消退，冷却结束隐藏。

#### 8.1.1 先定位置：不能和 `CoinsBag` 打架

`CoinsBag` 已经占了左上角：`offset_left = 10` / `offset_top = 10`，`custom_minimum_size = Vector2(128, 96)`（金币图标 64×64 + 字号 64 的标签），实际占据 `(10, 10) ~ (138, 106)`。
所以 `CharacterStatus` **不能也放 (16, 16)**（会把金币压住）。建议放在金币**正下方**：

```text
offset_left = 10.0     offset_top = 112.0     offset_right = 340.0     offset_bottom = 320.0
```

即左上角、金币下沿再留 6px，面板本体 **330 × 208**。
顶部居中的 `WaveIndexLabel`（`offset_top = 20`）和 `WaveTimeLabel`（`offset_top = 100`）在 x 方向居中，不会冲突。
另外角色选择界面 `SelectionPanel` 是铺满全屏的 `Panel`（`anchors_preset = 15`）且在 `GameUI` 里排在最后，选人时会盖住这个面板，所以**不需要**为它单独做显示/隐藏。

#### 8.1.2 逐节点参数表（中英对照 · 1920×1080 画布坐标）

中文名是按 Godot 官方 `zh_Hans` 编辑器翻译文件核对的；**先在 Inspector 里认清下面这几节**，参数就在里面：

> 找不到某一项时：点 Inspector 顶部的**筛选框**（放大镜）输入关键字过滤，比在长列表里翻快得多（`pivot`、`expand`、`unique`、`theme` 这些英文也能过滤）。

| Inspector 段落（中文 / 英文） | 这里放什么 |
| --- | --- |
| 布局 / Layout → 变换 / Transform | 位置(Position)、大小(Size)、旋转、缩放；**轴心偏移(Pivot Offset) 也在这里** |
| 布局 / Layout → 锚点 / Anchor Points | 锚点预设(Anchors Preset) 的 3×3 网格 |
| 布局 / Layout → 锚点偏移 / Anchor Offsets | 左 / 上 / 右 / 下（Left / Top / Right / Bottom）四个偏移值 |
| 布局 / Layout → 容器大小 / Container Sizing | 自定义最小尺寸(Custom Minimum Size)；水平/垂直(Horizontal / Vertical) 的「尺寸标志」按钮 |
| 主题覆盖 / Theme Overrides → 样式 / Styles · 常量 / Constants · 字体大小 / Font Sizes | 面板(Panel)、背景(Background)、填充(Fill) 等样式盒；边距、间距 |
| （属性列表里直接可见，不用展开） | 扩展模式(Expand Mode)、拉伸模式(Stretch Mode)、对齐(Alignment)、水平对齐、垂直对齐、最大值、显示百分比、颜色(Color)、可见(Visible)、文本(Text) |

> **布局模式 / Layout Mode**（`layout_mode`）：Inspector 里会看到这一项（位置 / 锚点 / 容器），它是编辑器根据"父节点是不是容器"**自动决定**的，不用手动设，忽略即可。
> **偏移 vs 位置/大小**：`offset_*` 和「位置 + 大小」是同一件事的两种显示，改哪边都一样。如果你的布局面板显示的是**位置/大小**，那就把表中"锚点偏移"一列理解成：**位置 = 左, 上；大小 = 右-左, 下-上**（例如根面板 = 位置 `(10, 112)`、大小 `(330, 208)`）。
> **新建样式盒**：样式类属性默认是空的，点它右边的「▼」→「**新建 StyleBoxFlat**」；填完后「圆角半径 / 圆角细节」右侧的小按钮可以一次统一四个角，也可以逐个填。
> **尺寸标志按钮**：`容器大小 → 水平 / 垂直` 各是一排小按钮，可同时点亮多个，代码里的数值就是它们相加：`0` 始端收缩(Shrink Begin) / `1` 填充(Fill) / `2` 扩展(Expand) / `3` 填充+扩展 / `4` 居中收缩(Shrink Center) / `8` 末端收缩(Shrink End)。
> **标签设置**：`标签设置 / Label Settings` 里只填「字号 / Font Size」即可（也可改用 主题覆盖 → 字体大小，效果一样，但本项目统一用 LabelSettings）。

**① 根面板与布局容器**

| 节点 | 属性（中文 / 英文 / 代码名） | 在哪一节 | 设成 |
| --- | --- | --- | --- |
| `CharacterStatus` | 自定义最小尺寸 / Custom Minimum Size / `custom_minimum_size` | 布局 → 容器大小 | `Vector2(330, 208)` |
| `CharacterStatus` | 锚点预设 / Anchors Preset / `anchors_preset` | 布局 → 锚点 | **左上 / Top Left**（3×3 网格点左上角，代码值 `0`） |
| `CharacterStatus` | 锚点偏移 / Anchor Offsets / `offset_left` `offset_top` `offset_right` `offset_bottom` | 布局 → 锚点偏移 | **左 10 / 上 112 / 右 340 / 下 320** |
| `CharacterStatus` | 主题覆盖 → 样式 → 面板 / Theme Overrides → Styles → Panel / `theme_override_styles/panel` | 主题覆盖 | 新建 StyleBoxFlat：背景色(Background Color) `0.098, 0.098, 0.098`、Alpha `0.85`；圆角半径(Corner Radius) 全 `16`；圆角细节(Corner Detail) `5` |
| `MarginContainer` | 锚点预设 / Anchors Preset | 布局 → 锚点 | **整个矩形 / Full Rect**（代码值 `15`），让里面铺满面板 |
| `MarginContainer` | 主题覆盖 → 常量 → 边距左/上/右/下 / Constants → Margin Left/Top/Right/Bottom | 主题覆盖 | 4 个都填 `12` |
| `VBoxContainer` | 主题覆盖 → 常量 → 间距 / Constants → Separation | 主题覆盖 | `8` |
| `Top`（头像+血量行） | 主题覆盖 → 常量 → 间距 / Separation | 主题覆盖 | `10` |
| `Bars` | 水平 / Size Flags Horizontal / `size_flags_horizontal` | 布局 → 容器大小 | 点亮 **填充 + 扩展**（代码值 `3`），占满头像右边的剩余宽度 |
| `Bars` | 垂直 / Size Flags Vertical / `size_flags_vertical` | 布局 → 容器大小 | 点亮 **居中收缩**（代码值 `4`） |
| `HPRow` / `StaminaRow` | 主题覆盖 → 常量 → 间距 / Separation | 主题覆盖 | 各 `6` |
| `Skills`（技能行） | 对齐 / Alignment / `alignment` | 属性列表里 | **居中 / Center**（代码值 `1`） |
| `Skills` | 主题覆盖 → 常量 → 间距 / Separation | 主题覆盖 | `10` |

> 注意区分两个"对齐"：**容器的**叫「对齐 / Alignment」(`alignment`)，**Label 的**叫「水平对齐 / Horizontal Alignment」(`horizontal_alignment`)，别找错。

**② 头像 / 血条 / 体力条**

| 节点 | 属性（中文 / 英文 / 代码名） | 在哪一节 | 设成 |
| --- | --- | --- | --- |
| `Face` | 自定义最小尺寸 / Custom Minimum Size | 布局 → 容器大小 | `Vector2(96, 96)` |
| `Face` | 垂直 / Size Flags Vertical | 布局 → 容器大小 | **居中收缩**（`4`） |
| `Face` | 扩展模式 / Expand Mode / `expand_mode` | 属性列表里 | 下拉选**第 2 项**：Ignore Size（中文约「忽略大小」，代码值 `1`）——让图片按 96×96 铺满，不受原图尺寸影响 |
| `Face` | 拉伸模式 / Stretch Mode / `stretch_mode` | 属性列表里 | 下拉选**第 6 项**：Keep Aspect Centered（约「保持长宽比居中」，代码值 `5`）——不变形 |
| `Face` | 唯一名称 / Unique Name in Owner / `unique_name_in_owner` | 场景面板里节点名右侧的 `%` 按钮 | 点上（脚本用 `%Face` 找它） |
| `HPBar` / `StaminaBar` | 自定义最小尺寸 / Custom Minimum Size | 布局 → 容器大小 | `Vector2(0, 22)`（宽给 0，靠"填充+扩展"撑开） |
| `HPBar` / `StaminaBar` | 水平 / Size Flags Horizontal | 布局 → 容器大小 | **填充 + 扩展**（`3`） |
| `HPBar` / `StaminaBar` | 最大值 / Max Value / `max_value` | 属性列表里 | `1.0`（脚本赋的是 0~1 的比例值，别改） |
| `HPBar` / `StaminaBar` | 显示百分比 / Show Percentage / `show_percentage` | 属性列表里 | **取消勾选** |
| `HPBar` / `StaminaBar` | 主题覆盖 → 样式 → 背景 / Background / `theme_override_styles/background` | 主题覆盖 | 新建 StyleBoxFlat：内容边距(Content Margins) 四边 `2`；背景色 `0.137255, 0.0196078, 0.027451`；圆角半径 `8`；圆角细节 `6` |
| `HPBar` | 主题覆盖 → 样式 → 填充 / Fill / `theme_override_styles/fill` | 主题覆盖 | 新建 StyleBoxFlat：内容边距 `2`；背景色 `1, 0.290196, 0.454902`；边框宽度(Border Width) `3`；边框颜色(Border Color) `0.137255, 0.0196078, 0.027451`；圆角半径 `6`；圆角细节 `6` |
| `StaminaBar` | 主题覆盖 → 样式 → 填充 / Fill | 主题覆盖 | 同上，只把背景色换成**蓝** `0.294118, 0.639216, 0.960784` |
| `HPValue` / `StaminaValue` | 自定义最小尺寸 / Custom Minimum Size | 布局 → 容器大小 | `Vector2(56, 0)` |
| `HPValue` / `StaminaValue` | 水平对齐 / Horizontal Alignment / `horizontal_alignment` | 属性列表里 | **右 / Right**（代码值 `2`） |
| `HPValue` / `StaminaValue` | 标签设置 → 字号 / Label Settings → Font Size | 属性列表里 | 新建 LabelSettings：字号 `22` |
| `HPValue` / `StaminaValue` | 文本 / Text / `text` | 属性列表里 | 占位随便填（`10` / `100`），脚本每帧会覆盖 |
| `HPValue` / `StaminaValue` | 唯一名称 / Unique Name in Owner | 场景面板 `%` 按钮 | 点上 |

**③ 技能格（两个格子结构完全一样，`Skill2` 那套把名字里的 1 换成 2、按键提示文本换成 `E`）**

| 节点 | 属性（中文 / 英文 / 代码名） | 在哪一节 | 设成 |
| --- | --- | --- | --- |
| `Skill1` / `Skill2` | 自定义最小尺寸 / Custom Minimum Size | 布局 → 容器大小 | `Vector2(80, 80)` |
| `Skill1` / `Skill2` | 主题覆盖 → 样式 → 面板 / Styles → Panel | 主题覆盖 | 新建 StyleBoxFlat：背景色 `0.137255, 0.0196078, 0.027451`；边框宽度 `2`；边框颜色 `0.352941, 0.0784314, 0.113725`；圆角半径 `8`；圆角细节 `5` |
| `Skill1Icon` / `Skill2Icon` | 锚点预设 / Anchors Preset | 布局 → 锚点 | **整个矩形 / Full Rect**（`15`），偏移 4 个都是 `0` |
| `Skill1Icon` / `Skill2Icon` | 扩展模式 / 拉伸模式 | 属性列表里 | `1`（Ignore Size）/ `5`（Keep Aspect Centered），同头像 |
| `Skill1Icon` / `Skill2Icon` | 唯一名称 / Unique Name in Owner | 场景面板 `%` 按钮 | 点上 |
| `Skill1Overlay` / `Skill2Overlay` | 锚点预设 / Anchors Preset | 布局 → 锚点 | **整个矩形 / Full Rect**（`15`） |
| `Skill1Overlay` / `Skill2Overlay` | 轴心偏移 / Pivot Offset / `pivot_offset` | **布局 → 变换 / Transform**（找不到就用筛选框输 `pivot`） | `Vector2(40, 80)`（80×80 格子的**底边中点**，冷却遮罩靠它从下往上退） |
| `Skill1Overlay` / `Skill2Overlay` | 颜色 / Color / `color` | 属性列表里 | 取色器选**纯黑**，然后把 **Alpha 拖到 0.6**（等于代码 `Color(0, 0, 0, 0.6)`） |
| `Skill1Overlay` / `Skill2Overlay` | 可见 / Visible / `visible` | 属性列表最上面 | **取消勾选**（初始隐藏，免得开局面板上有块黑） |
| `Skill1Overlay` / `Skill2Overlay` | 唯一名称 / Unique Name in Owner | 场景面板 `%` 按钮 | 点上 |
| `Skill1Cooldown` / `Skill2Cooldown` | 锚点预设 / Anchors Preset | 布局 → 锚点 | **整个矩形 / Full Rect**（`15`） |
| `Skill1Cooldown` / `Skill2Cooldown` | 水平对齐 + 垂直对齐 / Horizontal + Vertical Alignment | 属性列表里 | 都选 **居中 / Center**（代码值 `1`） |
| `Skill1Cooldown` / `Skill2Cooldown` | 标签设置 → 字号 / Label Settings → Font Size | 属性列表里 | 新建 LabelSettings：字号 `28` |
| `Skill1Cooldown` / `Skill2Cooldown` | 可见 / Visible | 属性列表最上面 | **取消勾选**（避免首帧闪一个写死的 "3.0"） |
| `Skill1Cooldown` / `Skill2Cooldown` | 唯一名称 / Unique Name in Owner | 场景面板 `%` 按钮 | 点上 |
| `KeyHint1` / `KeyHint2`（Q/E 角标） | 锚点预设 / Anchors Preset | 布局 → 锚点 | **右下 / Bottom Right**（代码值 `3`） |
| `KeyHint1` / `KeyHint2` | 锚点偏移 / Anchor Offsets | 布局 → 锚点偏移 | **左 -22 / 上 -26 / 右 -6 / 下 -6** |
| `KeyHint1` / `KeyHint2` | 文本 / Text | 属性列表里 | `Q` / `E` |
| `KeyHint1` / `KeyHint2` | 水平对齐 / Horizontal Alignment | 属性列表里 | **右 / Right**（`2`） |
| `KeyHint1` / `KeyHint2` | 标签设置 → 字号 | 属性列表里 | 新建 LabelSettings：字号 `16` |
| `KeyHint1` / `KeyHint2` | 唯一名称 | — | **不用点**（脚本不引用它） |

> 两条硬约束：
> 1. **节点名必须和脚本里的 `%` 名一致**：`%Face` / `%HPBar` / `%HPValue` / `%StaminaBar` / `%StaminaValue` / `%Skill1Icon` / `%Skill2Icon` / `%Skill1Overlay` / `%Skill2Overlay` / `%Skill1Cooldown` / `%Skill2Cooldown`。上面 8.1 结构图里的 `Icon` / `CooldownOverlay` / `CooldownLabel` 只是示意叫法，实际按这张表取名（`%` 是按**节点名**查找，改名就要同步改脚本）。
> 2. 凡是要被 `%` 引用的节点，都要点上「唯一名称」（`unique_name_in_owner`）。
>
> 尺寸都可以按喜好调：面板高度是按内容算出来的（`12` 边距 + `96` 头像行 + `8` 间距 + `80` 技能行 + `12` 边距 = `208`），改了头像/技能格尺寸记得同步改 `offset_bottom`；若同时改了技能格尺寸，别忘了 `pivot_offset` 也要改成新格子的底边中点。

#### 8.1.3 可直接粘贴的场景文本

`scenes/ui/character_status/character_status.tscn`（`uid` 保存时由编辑器补，不用手写）：

```text
[gd_scene load_steps=10 format=3]

[ext_resource type="Script" path="res://scenes/ui/character_status/character_status.gd" id="1_status"]

[sub_resource type="StyleBoxFlat" id="SB_panel"]
bg_color = Color(0.0980392, 0.0980392, 0.0980392, 0.85)
corner_radius_top_left = 16
corner_radius_top_right = 16
corner_radius_bottom_right = 16
corner_radius_bottom_left = 16
corner_detail = 5

[sub_resource type="StyleBoxFlat" id="SB_slot"]
bg_color = Color(0.137255, 0.0196078, 0.027451, 1)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.352941, 0.0784314, 0.113725, 1)
corner_radius_top_left = 8
corner_radius_top_right = 8
corner_radius_bottom_right = 8
corner_radius_bottom_left = 8
corner_detail = 5

[sub_resource type="StyleBoxFlat" id="SB_bar_back"]
content_margin_left = 2.0
content_margin_top = 2.0
content_margin_right = 2.0
content_margin_bottom = 2.0
bg_color = Color(0.137255, 0.0196078, 0.027451, 1)
corner_radius_top_left = 8
corner_radius_top_right = 8
corner_radius_bottom_right = 8
corner_radius_bottom_left = 8
corner_detail = 6

[sub_resource type="StyleBoxFlat" id="SB_bar_hp"]
content_margin_left = 2.0
content_margin_top = 2.0
content_margin_right = 2.0
content_margin_bottom = 2.0
bg_color = Color(1, 0.290196, 0.454902, 1)
border_width_left = 3
border_width_top = 3
border_width_right = 3
border_width_bottom = 3
border_color = Color(0.137255, 0.0196078, 0.027451, 1)
corner_radius_top_left = 6
corner_radius_top_right = 6
corner_radius_bottom_right = 6
corner_radius_bottom_left = 6
corner_detail = 6

[sub_resource type="StyleBoxFlat" id="SB_bar_stamina"]
content_margin_left = 2.0
content_margin_top = 2.0
content_margin_right = 2.0
content_margin_bottom = 2.0
bg_color = Color(0.294118, 0.639216, 0.960784, 1)
border_width_left = 3
border_width_top = 3
border_width_right = 3
border_width_bottom = 3
border_color = Color(0.137255, 0.0196078, 0.027451, 1)
corner_radius_top_left = 6
corner_radius_top_right = 6
corner_radius_bottom_right = 6
corner_radius_bottom_left = 6
corner_detail = 6

[sub_resource type="LabelSettings" id="LS_value"]
font_size = 22

[sub_resource type="LabelSettings" id="LS_cd"]
font_size = 28

[sub_resource type="LabelSettings" id="LS_key"]
font_size = 16

[node name="CharacterStatus" type="Panel"]
custom_minimum_size = Vector2(330, 208)
offset_left = 10.0
offset_top = 112.0
offset_right = 340.0
offset_bottom = 320.0
theme_override_styles/panel = SubResource("SB_panel")
script = ExtResource("1_status")

[node name="MarginContainer" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/margin_left = 12
theme_override_constants/margin_top = 12
theme_override_constants/margin_right = 12
theme_override_constants/margin_bottom = 12

[node name="VBoxContainer" type="VBoxContainer" parent="MarginContainer"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="Top" type="HBoxContainer" parent="MarginContainer/VBoxContainer"]
layout_mode = 2
theme_override_constants/separation = 10

[node name="Face" type="TextureRect" parent="MarginContainer/VBoxContainer/Top"]
unique_name_in_owner = true
custom_minimum_size = Vector2(96, 96)
layout_mode = 2
size_flags_vertical = 4
expand_mode = 1
stretch_mode = 5

[node name="Bars" type="VBoxContainer" parent="MarginContainer/VBoxContainer/Top"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 4
theme_override_constants/separation = 6

[node name="HPRow" type="HBoxContainer" parent="MarginContainer/VBoxContainer/Top/Bars"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="HPBar" type="ProgressBar" parent="MarginContainer/VBoxContainer/Top/Bars/HPRow"]
unique_name_in_owner = true
custom_minimum_size = Vector2(0, 22)
layout_mode = 2
size_flags_horizontal = 3
theme_override_styles/background = SubResource("SB_bar_back")
theme_override_styles/fill = SubResource("SB_bar_hp")
max_value = 1.0
value = 1.0
show_percentage = false

[node name="HPValue" type="Label" parent="MarginContainer/VBoxContainer/Top/Bars/HPRow"]
unique_name_in_owner = true
custom_minimum_size = Vector2(56, 0)
layout_mode = 2
text = "10"
label_settings = SubResource("LS_value")
horizontal_alignment = 2

[node name="StaminaRow" type="HBoxContainer" parent="MarginContainer/VBoxContainer/Top/Bars"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="StaminaBar" type="ProgressBar" parent="MarginContainer/VBoxContainer/Top/Bars/StaminaRow"]
unique_name_in_owner = true
custom_minimum_size = Vector2(0, 22)
layout_mode = 2
size_flags_horizontal = 3
theme_override_styles/background = SubResource("SB_bar_back")
theme_override_styles/fill = SubResource("SB_bar_stamina")
max_value = 1.0
value = 1.0
show_percentage = false

[node name="StaminaValue" type="Label" parent="MarginContainer/VBoxContainer/Top/Bars/StaminaRow"]
unique_name_in_owner = true
custom_minimum_size = Vector2(56, 0)
layout_mode = 2
text = "100"
label_settings = SubResource("LS_value")
horizontal_alignment = 2

[node name="Skills" type="HBoxContainer" parent="MarginContainer/VBoxContainer"]
layout_mode = 2
alignment = 1
theme_override_constants/separation = 10

[node name="Skill1" type="Panel" parent="MarginContainer/VBoxContainer/Skills"]
custom_minimum_size = Vector2(80, 80)
layout_mode = 2
theme_override_styles/panel = SubResource("SB_slot")

[node name="Skill1Icon" type="TextureRect" parent="MarginContainer/VBoxContainer/Skills/Skill1"]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
expand_mode = 1
stretch_mode = 5

[node name="Skill1Overlay" type="ColorRect" parent="MarginContainer/VBoxContainer/Skills/Skill1"]
unique_name_in_owner = true
visible = false
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
pivot_offset = Vector2(40, 80)
color = Color(0, 0, 0, 0.6)

[node name="Skill1Cooldown" type="Label" parent="MarginContainer/VBoxContainer/Skills/Skill1"]
unique_name_in_owner = true
visible = false
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
text = "3.0"
label_settings = SubResource("LS_cd")
horizontal_alignment = 1
vertical_alignment = 1

[node name="KeyHint1" type="Label" parent="MarginContainer/VBoxContainer/Skills/Skill1"]
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -22.0
offset_top = -26.0
offset_right = -6.0
offset_bottom = -6.0
grow_horizontal = 0
grow_vertical = 0
text = "Q"
label_settings = SubResource("LS_key")
horizontal_alignment = 2

[node name="Skill2" type="Panel" parent="MarginContainer/VBoxContainer/Skills"]
custom_minimum_size = Vector2(80, 80)
layout_mode = 2
theme_override_styles/panel = SubResource("SB_slot")

[node name="Skill2Icon" type="TextureRect" parent="MarginContainer/VBoxContainer/Skills/Skill2"]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
expand_mode = 1
stretch_mode = 5

[node name="Skill2Overlay" type="ColorRect" parent="MarginContainer/VBoxContainer/Skills/Skill2"]
unique_name_in_owner = true
visible = false
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
pivot_offset = Vector2(40, 80)
color = Color(0, 0, 0, 0.6)

[node name="Skill2Cooldown" type="Label" parent="MarginContainer/VBoxContainer/Skills/Skill2"]
unique_name_in_owner = true
visible = false
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
text = "3.0"
label_settings = SubResource("LS_cd")
horizontal_alignment = 1
vertical_alignment = 1

[node name="KeyHint2" type="Label" parent="MarginContainer/VBoxContainer/Skills/Skill2"]
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -22.0
offset_top = -26.0
offset_right = -6.0
offset_bottom = -6.0
grow_horizontal = 0
grow_vertical = 0
text = "E"
label_settings = SubResource("LS_key")
horizontal_alignment = 2
```

> 图标资源：技能图标建议放 `assets/sprites/Skills/`（每角色两个，正方形），头像直接用 `stats.icon`。**注意图标不是在这个场景里设的**——`Skill1Icon` 的 `texture` 由脚本从 `CharacterSkills.get_icon()` 读，所以真正要填的是各角色 `Skills` 节点上的 `skill_1_icon` / `skill_2_icon`（步骤 6.2）；不填就是空白格子。

> **上面这套参数是实测过的**（Godot 4.7.2 无头加载本场景、等两帧后读取实际布局），实测结果：
> 面板 `position = (10, 112)`、`size = (330, 208)`；`%Face = 96×96`；`%HPBar = 138×22`（占满剩余宽）、`%HPValue = 56×31` 位于 x=144；`Skills` 行 `306×80`，`Skill1` 在 x=68、`Skill2` 在 x=158（间距 10、整行居中）；`%Skill1Overlay` 的 `pivot_offset = (40, 80)`，`scale.y = 0.4` 时遮罩覆盖 y `48 ~ 80`（即贴着底边、从下往上消退）；`%HPBar.max_value = 1.0`，脚本按比例赋值可直接生效；`KeyHint1/2` 文本为 `Q` / `E`。
> 也就是说照抄 8.1.2 的参数或整段 8.1.3 的 `.tscn`，出来的就是上面这个布局，不需要再手调。

#### 8.2 面板脚本 `scenes/ui/character_status/character_status.gd`

```gdscript
extends Panel
class_name CharacterStatus
## CharacterStatus（角色状态面板 / Panel）
## 作用：战斗时左上角显示角色头像、血量、体力与两个技能（Q/E）的冷却。

@onready var face: TextureRect = %Face
@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_value: Label = %HPValue
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var stamina_value: Label = %StaminaValue

@onready var skill_1_icon: TextureRect = %Skill1Icon
@onready var skill_2_icon: TextureRect = %Skill2Icon
@onready var skill_1_overlay: Control = %Skill1Overlay
@onready var skill_2_overlay: Control = %Skill2Overlay
@onready var skill_1_cd: Label = %Skill1Cooldown
@onready var skill_2_cd: Label = %Skill2Cooldown


var _initialized := false


func _process(delta: float) -> void:
	if not is_instance_valid(Global.player):
		return

	# 玩家生成后首次初始化头像与技能图标。
	if not _initialized:
		_initialized = true
		setup_from_player()

	var p: Player = Global.player

	# 血量。
	hp_bar.value = p.health_component.current_health / p.health_component.max_health
	hp_value.text = str(p.health_component.current_health)

	# 体力。
	stamina_bar.value = p.current_stamina / p.stats.stamina
	stamina_value.text = str(int(p.current_stamina))

	# 技能冷却。
	update_skill_cooldown(0, skill_1_overlay, skill_1_cd)
	update_skill_cooldown(1, skill_2_overlay, skill_2_cd)


func setup_from_player() -> void:
	var p: Player = Global.player
	face.texture = p.stats.icon
	skill_1_icon.texture = p.skills.get_icon(0)
	skill_2_icon.texture = p.skills.get_icon(1)


func update_skill_cooldown(slot: int, overlay: Control, cd_label: Label) -> void:
	var left := Global.player.skills.get_cooldown_time_left(slot)
	var total := Global.player.skills.get_cooldown_total(slot)
	if left <= 0.0 or total <= 0.0:
		overlay.visible = false
		cd_label.visible = false
		return
	overlay.visible = true
	cd_label.visible = true
	# 遮罩高度比例 = 剩余 / 总冷却。
	overlay.scale.y = left / total
	cd_label.text = "%.1f" % left
```

> **场景参数和这段脚本之间的三处约定**（不对上会出现"看着就不对"的现象）：
> 1. 两个 `ProgressBar` 都保持 `max_value = 1.0`，脚本赋的是**比例值**（`p.health_component.current_health / p.health_component.max_health`、`p.current_stamina / p.stats.stamina`），不要去改 `max_value`。
> 2. `Skill1Overlay` / `Skill2Overlay` 的 `pivot_offset = Vector2(40, 80)`（80×80 格子的**底边中点**）是 `overlay.scale.y = left / total` 能"贴底边往上消退"的前提——`scale` 是绕 `pivot_offset` 缩放的。若把技能格改成别的尺寸（例如 96×96），这里必须同步改成 `Vector2(48, 96)`，否则遮罩会从错误的位置缩。
>    也可以换成不依赖 `scale` 的等价写法：遮罩用 `anchor_top = 0` / `anchor_bottom = 0` 的顶部锚定，然后在 `update_skill_cooldown` 里写 `overlay.offset_bottom = 80.0 * (left / total)`。
> 3. `Skill1Cooldown` / `Skill2Cooldown` 的显隐由脚本的 `visible` 控制，所以场景里初始设成 `visible = false`，避免玩家生成的第一帧闪出一个写死的 "3.0"。

#### 8.3 接入 `arena.tscn`

在 `scenes/arena/arena.tscn` 的 `GameUI`（CanvasLayer）下新增：

```text
[node name="CharacterStatus" parent="GameUI" instance=ExtResource("<character_status_uid>")]
```

放在 `CoinsBag` 之后、`WaveIndexLabel` 之前（或按需调整顺序），并设置 `anchors_preset` 为左上角。

---

### （可选）步骤 9：选择界面展示技能

在 `scenes/ui/selection_panel/selection_panel.gd` 的 `_on_player_selected` 中，描述里追加两个技能名。但技能名现在在技能脚本上、而非 `UnitStats` 上；可给 `UnitStats` 再加两个可选显示字段，或在 `CharacterSkills` 基类上读 `skill_1_name`/`skill_2_name`（需先实例化才能读，较麻烦）。**建议**：在 `UnitStats` 上额外加两个纯展示字段：

```gdscript
## 技能 1 名称（仅选择界面展示用）。
@export var skill_1_display_name := ""
## 技能 2 名称（仅展示用）。
@export var skill_2_display_name := ""
```

然后在 `_on_player_selected` 里拼进描述即可。此步骤为可选，不影响战斗功能。

---

## 5. 验证清单

- [ ] 启动游戏，选不同角色时，状态面板头像正确，血量 / 体力显示为该角色在 `.tres` 里填的初始值。
- [ ] 血量随受伤 / 回复实时刷新；体力随技能消耗 / 自然回复实时刷新，且不超过上限。
- [ ] 两个方形技能图标显示在面板正下方，分别标注 Q / E，图标对应各角色自己的技能。
- [ ] 按 Q / E 触发**该角色自己的**技能脚本逻辑；图标进入冷却（变暗 + 倒计时），结束后恢复。
- [ ] 体力不足或冷却未结束时按 Q / E 不施放、不扣体力。
- [ ] 游戏暂停（商店 / 升级 / 结算）时，技能与体力回复冻结（依赖 `_process` 顶部 `Global.game_paused` 判断）。
- [ ] 5 个角色切换后，各自技能效果互不串味（每个角色跑的是自己的技能脚本）。
- [ ] 范围技能（战吼 / 爆裂 / 圣光斩）**确实造成了伤害**：攻击盒 `collision_layer = 16`（设错会静默零伤害，且控制台不报任何错，只能靠"敌人没掉血"发现）。

---

## 6. 待确认 / 备选方案

1. **体力是否作为技能消耗**：本方案采用「体力消耗 + 冷却」双重门槛。若只想要冷却，可删掉基类里的体力判定，体力仅作展示。
2. **技能脚本与场景的绑定方式**：本方案把技能脚本挂到玩家子节点 `Skills` 上（`get_parent()` 取 Player）。若想更解耦，可改为 `@export var player: Player` + `node_path` 显式绑定（与 `Trail.gd` 一致）。
3. **技能名称展示**：如需在选择界面显示技能名，用步骤 9 的 `skill_1_display_name`/`skill_2_display_name`（纯展示，与脚本无耦合）。
4. **"面部"理解**：需求中的"角色状态面部"按"状态面板 + 头像"理解实现；如需独立头像框 / 立绘可再调整布局。
5. **临时增益的还原方式**：示例里 `player.stats.damage += bonus` 改的是**共享的 `.tres` 资源**（`UnitStats` 是一个被 `preload` 的 Resource）；若玩家在增益期间被释放（换波重开 / 死亡），`await` 之后的还原会被 `is_instance_valid` 守卫跳过，资源上就**永久留下**了这次增益。项目既有写法（`update_player_new_wave` 里的 `stats.health += ...`）也是直接改资源，所以不算新问题；若要更严谨，可在技能脚本里记下基准值并在 `_exit_tree` 里还原。
6. **当前代码进度**（对照本方案）：步骤 1（`UnitStats.stamina` / `stamina_regen`）、步骤 3（`character_skills.gd`）、步骤 4（5 个技能脚本）**已存在**；但 5 个技能脚本目前是 **Brawler 实现的拷贝**（`bunny/crazy/knight/well_rounded_skills.gd` 内容与 `brawler_skills.gd` 完全一致，连文档注释都还是 Brawler 的），需要按步骤 4 的表格填各自效果。步骤 2（`.tres` 填体力）、步骤 5（`player.gd`）、步骤 6（场景挂 `Skills` 节点）、步骤 7（输入映射）、步骤 8（状态面板）**尚未实现**。
