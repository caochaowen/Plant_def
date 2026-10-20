# 商店老板交互改造方案（完整实现步骤）

> 目标：把「商店面板」的打开方式从 **"波末选完升级后自动弹出"** 改成
> **"每波开始时在地图随机位置刷新一个商店老板 NPC，玩家靠近按空格交互后打开"**。
>
> 本文档**只给出实现方案与完整代码**，不修改任何源文件。改代码前请先读第 0、1 节确认几个关键决策。

---

## 0. 改造前后流程对比

### 现状（改造前）

```
波结束(暂停) → UpgradePanel(升级面板)
   └ 玩家点升级 → Global.on_upgrade_selected → Arena._on_upgrade_selected
       └ upgrade_panel.hide() + shop_panel.load_shop() + shop_panel.show()   ← 商店自动弹
   └ 玩家点「next wave」 → on_shop_next_wave → Arena 隐藏商店 + start_new_wave()
```

### 目标（改造后）

```
波结束(暂停) → UpgradePanel(升级面板)
   └ 玩家点升级 → Global.on_upgrade_selected → Arena._on_upgrade_selected
       └ upgrade_panel.hide() + start_new_wave()      ← 不再弹商店，直接开下一波
   └ start_new_wave() 内部 → spawn_shopkeeper()        ← 每波开始刷商店老板(随机位置)

波进行中(未暂停)
   └ 玩家靠近商店老板 → 显示"按空格"提示
   └ 玩家按空格 → Shopkeeper.on_interact → Arena.open_shop()
       └ Global.game_paused = true + load_shop + show    ← 交互后才打开商店
   └ 玩家点「关闭商店」(原 next wave) → hide + 恢复未暂停
```

核心变化只有一句话：**`_on_upgrade_selected` 里不再 `load_shop/show`，改为 `start_new_wave()`；商店改由"商店老板 NPC + 空格交互"触发。**

---

## 1. 动手前必须确认的三个决策（重要）

### 决策 A：空格键冲突 ⚠️
当前 `project.godot` 里 **`dash`（冲刺）已经绑定了空格（physical_keycode=32）**。你要用空格做"交互"，必须先给冲刺改键。方案二选一：

- **方案 1（推荐）**：`dash` 改绑到 **Left Shift**；新增 `interact` 绑定 **Space**。
- 方案 2：`interact` 换一个没被占用的键（如 `F`），`dash` 保持 Space 不动。但这不符合你"按空格"的要求。

本文按**方案 1**给出步骤（见第 2 节）。

### 决策 B：商店打开时是否暂停游戏
- 现状里商店出现时游戏处于 `Global.game_paused == true`（波末结算留下的暂停）。
- 改造后商店在**波进行中**被打开，建议：打开商店时**主动暂停**（`game_paused = true`），关闭时恢复（`false`）。否则玩家逛商店时会被敌人打死。本文按"打开即暂停"实现。

### 决策 C：原「next wave」按钮怎么办
改造后商店在波中间打开，「下一波」按钮的语义已不成立。建议把它改成 **「离开商店 / 返回战斗」**：只是 `hide()` + 恢复未暂停，**不再推进波数**（波数推进改由 `_on_upgrade_selected → start_new_wave` 完成）。

如果你希望商店老板**每波只能交互一次**，在首次交互后 `queue_free()` 掉商店老板即可（见 4.3 末尾备注）。

---

## 2. 步骤一：输入映射（新增 `interact`，重绑 `dash`）

打开 **Project Settings → Input Map**（比手改 `project.godot` 安全）：

1. 新增动作 `interact`，绑定 **Space**（`Key Space`）。
2. 把 `dash` 原来绑定的 Space 删掉，改绑 **Shift**（`Key Shift`）。

若你坚持直接改 `project.godot`，在 `[input]` 段：

- 新增（复制自现有 dash 条目，`physical_keycode=32` 即空格）：

```ini
interact={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":32,"location":0,"echo":false,"script":null)
]
}
```

- 把 `dash` 条目里的 `physical_keycode":32` 改为 Shift（Godot 4 中 `KEY_SHIFT = 4194325`）：
  `"physical_keycode":4194325`（`keycode` 与 `unicode` 也同步清成 0）。

> 强烈建议用编辑器 Input Map 操作，避免手写序列化字段出错。

---

## 3. 步骤二：新建商店老板（Shopkeeper）

### 3.1 数据：`resources/units/npcs/stats_shopkeeper.tres`

商店老板继承 `Unit`，而 `Unit._ready()` 会 `health_component.setup(stats)`，所以需要一份 `UnitStats`。新建 Resource → `UnitStats`：

```ini
[gd_resource type="Resource" script_class="UnitStats" load_steps=2 format=3 uid="uid://xxxxxx"]

[ext_resource type="Script" path="res://resources/units/unit_stats.gd" id="1_shop"]

[resource]
script = ExtResource("1_shop")
name = "Shopkeeper"
type = 1                    # UnitType 目前未参与战斗逻辑，填 0/1 均可
icon = null
health = 999999             # 不会被打，但给个大值防意外
health_increase_per_wave = 0.0
damage = 0.0
damage_increase_per_wave = 0.0
speed = 0.0                 # 原地不动
luck = 0.0
block_chance = 0.0
gold_drop = 0
hp_regen = 0.0
life_steal = 0.0
harvesting = 0.0
stamina = 100.0
stamina_regen = 10.0
```

> `uid` 由编辑器自动生成；建议在编辑器里 `新建资源 → UnitStats` 填值，别手写。

### 3.2 场景：`scenes/unit/shopkeeper/shopkeeper.tscn`

与 `player_*` / `enemy_*` 完全同套路：**实例化 `unit.tscn` 作为根**，挂 `shopkeeper.gd`，替换 Sprite 贴图，加一个提示 Label。

建议在编辑器里：新建场景 → 根节点选「实例化子场景」`res://scenes/unit/unit.tscn` → 挂脚本 `shopkeeper.gd` → 给 `Visuals/Sprite` 设商店老板贴图 → 加一个 `InteractLabel`（Label）子节点放提示文字。最终结构：

```
Shopkeeper (Area2D, 实例自 unit.tscn)   script=shopkeeper.gd, stats=stats_shopkeeper.tres
├── Visuals
│   ├── Shadow
│   └── Sprite            → 商店老板贴图（如 assets/sprites/Players/... 或新素材）
├── CollisionShape2D       → 无需形状（不参与物理）
├── AnimationPlayer
├── HurtboxComponent       → 建议 collision_layer=0, collision_mask=0（免疫一切攻击）
├── HealthComponent
├── HealthBar              → 在 _ready 里 visible=false 隐藏
├── FlashTimer
└── InteractLabel (Label)  → 文本 "按空格打开商店"，初始 visible=false，位置 (0, -120)
```

关键点（对照现有 enemy 场景）：
- 根节点 `collision_layer`/`collision_mask` 可保持默认，**交互不用物理碰撞**（用距离判定，见 3.3）。
- `HurtboxComponent` 把 `collision_layer=0`、`collision_mask=0`，确保它不会被任何 hitbox 命中。
- 场景顶部的 `[connection]`（`on_damaged`、`on_health_changed`、`timeout`）是 `unit.tscn` 自带的，保留即可。

### 3.3 脚本：`scenes/unit/shopkeeper/shopkeeper.gd`

```gdscript
extends Unit
class_name Shopkeeper
## =============================================================================
## Shopkeeper（商店老板 NPC / Unit 子类）
## -----------------------------------------------------------------------------
## 作用：每波开始时被 Arena 刷到地图随机位置、原地不动的交互 NPC。
##       玩家进入交互距离后显示提示，按「interact」键发出 on_interact 信号，
##       由 Arena 收到后打开商店面板。本身不参与任何战斗逻辑。
## =============================================================================


## 信号：玩家在范围内按交互键。由 Arena.spawn_shopkeeper 连接到 open_shop。
signal on_interact


## 交互触发距离（像素）。
@export var interact_distance := 120.0


## 交互提示标签（"按空格打开商店"）。
@onready var interact_label: Label = $InteractLabel


## 玩家是否在交互范围内。
var player_in_range := false


## 函数说明：就绪时初始化父类、隐藏提示标签、隐藏血条。
## 被谁调用：由 Godot 引擎在节点进入场景树时调用。
## 调用了：super._ready()。
func _ready() -> void:
	# 父类 Unit._ready 会 health_component.setup(stats)，因此本节点需要有效的 stats。
	super._ready()
	# 隐藏提示标签。
	interact_label.visible = false
	# 隐藏血条（商店老板不需要显示生命条）。
	$HealthBar.visible = false


## 函数说明：每帧检测玩家距离，控制提示显隐并响应交互键。
## 被谁调用：由 Godot 引擎每帧调用。
## 调用了：Input.is_action_just_pressed()、on_interact.emit()。
func _process(_delta: float) -> void:
	# 游戏暂停（商店/升级/结算中）时不响应。
	if Global.game_paused:
		return

	# 玩家尚未生成或已被释放则跳过。
	if not is_instance_valid(Global.player):
		return

	# 计算与玩家的距离。
	var dist := global_position.distance_to(Global.player.global_position)
	var in_range := dist <= interact_distance

	# 状态变化时才刷新提示显隐（避免每帧重复赋值）。
	if in_range != player_in_range:
		player_in_range = in_range
		interact_label.visible = in_range

	# 在范围内且刚按下交互键，发出交互信号。
	if player_in_range and Input.is_action_just_pressed("interact"):
		on_interact.emit()
```

> 采用**距离判定**而非 `Area2D` 的 `body_entered`，原因是本项目的玩家根节点是 `Area2D`（不是 PhysicsBody2D），`body_entered` 检测不到；用距离判定最简单可靠。若想用 Area2D，需用 `area_entered` 且把交互区的 `collision_mask` 设为 1（Player 层）。

---

## 4. 步骤三：改造 Arena（总调度器）

文件：`scenes/arena/arena.gd`

### 4.1 顶部新增：预加载 + 运行时变量

在脚本顶部（`@export`/节点引用区附近）加：

```gdscript
## 商店老板场景（Shopkeeper）预加载。由 spawn_shopkeeper 实例化。
const SHOPKEEPER_SCENE = preload("res://scenes/unit/shopkeeper/shopkeeper.tscn")

## 当前场上的商店老板实例。
var shopkeeper: Shopkeeper

## 上一波商店老板的位置（用于保证每波位置不同）。
var last_shopkeeper_pos := Vector2.ZERO
```

### 4.2 新增方法：`spawn_shopkeeper` / `get_random_shopkeeper_position` / `open_shop`

```gdscript
## 函数说明：在随机位置刷出本波的商店老板。
## 被谁调用：start_new_wave、_on_selection_panel_on_selection_completed。
## 调用了：SHOPKEEPER_SCENE.instantiate()、get_random_shopkeeper_position()。
func spawn_shopkeeper() -> void:
	# 若上一波老板还在（理论不会，因为 start_new_wave 前已清理），先释放。
	if is_instance_valid(shopkeeper):
		shopkeeper.queue_free()

	# 实例化商店老板，加入竞技场。
	shopkeeper = SHOPKEEPER_SCENE.instantiate() as Shopkeeper
	add_child(shopkeeper)
	# 设置随机位置。
	shopkeeper.global_position = get_random_shopkeeper_position()
	# 连接交互信号 → 打开商店。
	shopkeeper.on_interact.connect(_on_shopkeeper_interact)


## 函数说明：返回一个与上一波位置不同、且离出生点(0,0)有一定距离的随机位置。
## 被谁调用：spawn_shopkeeper。
## 调用了：randf_range()、distance_to()。
func get_random_shopkeeper_position() -> Vector2:
	var pos := Vector2.ZERO
	# 最多尝试 20 次，尽量满足"与上波不同 + 不贴玩家出生点"。
	for i in 20:
		# 竞技场范围与玩家 clamp 一致：x ∈ [-1000,1000]，y ∈ [-500,500]；稍微内缩更安全。
		pos = Vector2(randf_range(-900, 900), randf_range(-450, 450))
		# 距上波位置 > 300，且距中心出生点 > 200 才接受。
		if pos.distance_to(last_shopkeeper_pos) > 300.0 and pos.distance_to(Vector2.ZERO) > 200.0:
			break
	# 记录本波位置，供下一波对比。
	last_shopkeeper_pos = pos
	return pos


## 函数说明：打开商店面板（暂停游戏 + 加载商品 + 显示）。
## 被谁调用：_on_shopkeeper_interact。
## 调用了：shop_panel.load_shop()、shop_panel.show()。
func open_shop() -> void:
	# 暂停战斗，玩家在波中逛商店时不被打。
	Global.game_paused = true
	# 用当前波数加载商店商品。
	shop_panel.load_shop(spawner.wave_index)
	# 显示商店面板。
	shop_panel.show()


## 函数说明：商店老板交互信号回调，打开商店。
## 被谁调用：由 Shopkeeper.on_interact 信号触发。
## 调用了：open_shop()。
func _on_shopkeeper_interact() -> void:
	open_shop()
```

### 4.3 修改 `_on_upgrade_selected`：不再自动开商店

原代码：

```gdscript
func _on_upgrade_selected() -> void:
	upgrade_panel.hide()
	shop_panel.load_shop(spawner.wave_index)
	shop_panel.show()
```

改为：

```gdscript
func _on_upgrade_selected() -> void:
	# 隐藏升级面板。
	upgrade_panel.hide()
	# ★ 不再自动打开商店，改为直接开始下一波（波开始时会刷商店老板）。
	start_new_wave()
```

### 4.4 修改 `start_new_wave`：波开始刷老板

```gdscript
func start_new_wave() -> void:
	Global.game_paused = false
	Global.player.update_player_new_wave()
	spawner.wave_index += 1
	spawner.start_wave()
	# ★ 每波开始刷新商店老板（随机位置）。
	spawn_shopkeeper()
```

### 4.5 修改 `_on_selection_panel_on_selection_completed`：第一波也刷老板

在末尾（`Global.game_paused = false` 之后）加一行：

```gdscript
func _on_selection_panel_on_selection_completed() -> void:
	var player := Global.get_selected_player()
	add_child(player)
	player.add_weapon(Global.main_weapon_selected)
	shop_panel.create_item_weapon(Global.main_weapon_selected)
	Global.equipped_weapons.append(Global.main_weapon_selected)

	spawner.start_wave()
	Global.game_paused = false
	# ★ 第一波也刷一个商店老板。
	spawn_shopkeeper()
```

### 4.6 修改 `_on_shop_panel_on_shop_next_wave`：改成「关闭商店」

原代码：

```gdscript
func _on_shop_panel_on_shop_next_wave() -> void:
	shop_panel.hide()
	start_new_wave()
```

改为（不再推进波数，只是关闭商店回到战斗）：

```gdscript
func _on_shop_panel_on_shop_next_wave() -> void:
	# 隐藏商店面板。
	shop_panel.hide()
	# ★ 只恢复战斗，不再 start_new_wave（波数推进已移到 _on_upgrade_selected）。
	Global.game_paused = false
```

> 建议同步把 `shop_panel.gd` 的信号 `on_shop_next_wave` 改名为 `on_shop_closed`、`shop_panel.tscn` 里 `NewWaveButton` 的 `text` 从 `"next wave"` 改成 `"离开商店"`（或 `"close"`），并更新 `arena.tscn` 里的 `[connection]`。仅改显示/命名，逻辑仍是"关闭并恢复战斗"。

### 4.7 （可选）波末清理商店老板

波末进入升级面板时，若上一波老板还在场上，会显得突兀。在 `clean_arena()` 末尾加：

```gdscript
	# 波末清掉商店老板（下一波会重新随机刷）。
	if is_instance_valid(shopkeeper):
		shopkeeper.queue_free()
		shopkeeper = null
```

> 由于 `spawn_shopkeeper()` 开头已经会 `queue_free` 旧的，这一步只是让"升级结算阶段"画面更干净，非必需。

---

## 5. 改动清单汇总

| 文件 | 操作 | 内容 |
| --- | --- | --- |
| `project.godot` | 修改 | 新增 `interact`=Space；`dash` 改绑 Shift |
| `resources/units/npcs/stats_shopkeeper.tres` | 新建 | 商店老板 UnitStats |
| `scenes/unit/shopkeeper/shopkeeper.gd` | 新建 | 距离判定 + 空格交互 + `on_interact` 信号 |
| `scenes/unit/shopkeeper/shopkeeper.tscn` | 新建 | 实例 unit.tscn + 提示 Label + 隐藏血条 |
| `scenes/arena/arena.gd` | 修改 | 加 `SHOPKEEPER_SCENE`、`shopkeeper`、`last_shopkeeper_pos`、`spawn_shopkeeper`、`get_random_shopkeeper_position`、`open_shop`、`_on_shopkeeper_interact`；改 `_on_upgrade_selected`/`start_new_wave`/`_on_selection_panel_on_selection_completed`/`_on_shop_panel_on_shop_next_wave` |
| `scenes/ui/shop_panel/shop_panel.gd` | 修改(可选) | `on_shop_next_wave` → `on_shop_closed` |
| `scenes/ui/shop_panel/shop_panel.tscn` | 修改(可选) | `NewWaveButton` 文本 → "离开商店" |
| `scenes/arena/arena.tscn` | 修改(可选) | 同步 `[connection]` 里的信号名 |

---

## 6. 测试清单

- [ ] 开局选完角色武器点 continue 后，第一波就有一个商店老板出现在随机位置。
- [ ] 商店老板站在地图内、原地不动，不会追玩家，也没有血条。
- [ ] 靠近商店老板时出现「按空格」提示，远离后提示消失。
- [ ] 按空格弹出商店面板，同时游戏暂停；能正常购买/合成/出售。
- [ ] 点「离开商店」后面板关闭，战斗恢复，波数**没有**推进。
- [ ] 波结束 → 升级面板 → 选升级后**不再弹商店**，而是直接进入下一波。
- [ ] 下一波商店老板出现在**新位置**（与上一波明显不同）。
- [ ] 冲刺仍可用（Shift），确认改键后没有空格误触。
- [ ] 波末升级结算阶段，上一波的商店老板已被清掉（若做了 4.7）。

---

## 7. 备选变体（如需）

- **每波只让老板交互一次**：在 `_on_shopkeeper_interact()` 里加 `shopkeeper.queue_free(); shopkeeper = null`（交互一次后老板消失，直到下一波再刷）。
- **用碰撞区而非距离判定**：给老板加 `InteractionArea(Area2D, collision_mask=1)`，监听 `area_entered/area_exited`（注意玩家是 Area2D，必须用 `area_*` 不是 `body_*`），并 `if area is Player`。
- **给老板加寻路提示箭头**：额外做一个指向老板的 UI 箭头（读 `shopkeeper.global_position` 与玩家位置算方向），方便玩家找到随机位置的老板。
