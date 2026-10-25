# 升级卡片「多属性自由调整」改造方案

> 目标：把升级卡片从「一张卡只能改一个属性」改成「一张卡可同时调整多个属性」，
> 每个属性可正可负，点卡片时把所有非 0 项一次性应用到玩家。

---

## 1. 现状与局限

当前 `ItemUpgrade`（`resources/items/upgrades/item_upgrade.gd`）只有三个业务字段：

```gdscript
@export var value: float        # 单值
@export var description: String # 手写描述
@export var stat_id: String     # 单属性名
```

`apply_upgrade()`（`item_upgrade.gd:24`）只处理**一个** `stat_id`：

```gdscript
func apply_upgrade() -> void:
	var current_value := Global.player.stats.get(stat_id) as float
	var new_value := float(value) + float(current_value)
	Global.player.stats.set(stat_id, new_value)
```

局限：
1. 一张卡只能改一个属性（`stat_id` 是单字符串）。
2. 只能加、不能减（`value` 语义固定为正，虽然填负数其实也能减，但数据里全是正数）。
3. 描述 `description` 是**手写**的，改了数值很容易忘改描述，卡片显示与实际效果脱节。
4. 现有 48 个 `.tres` 基本是"每个属性 × 每档数值"各一张，卡片膨胀、难以组合设计。

---

## 2. 目标设计

把 `ItemUpgrade` 改成"**罗列所有可调属性**"的结构：

- 每个可调属性 = 一个 `@export var xxx := 0.0` 字段，在 Inspector 里直接显示并填写。
- **正数 = 增加，负数 = 减少，0 = 不涉及**。
- `apply_upgrade()` 遍历所有字段，把所有**非 0** 项一次性应用到 `Global.player.stats`。
- 描述文本**自动生成**（列出所有非 0 项），保证卡片显示 = 实际效果。

在 Inspector 里打开任意升级 `.tres`，会看到一排属性字段（`damage` / `speed` / `health` / …），每项填 `+` 或 `-` 数值或留 `0`，效果一目了然。

> **本改造只改 `ItemUpgrade` 的数据结构**，`upgrade_list` 的随机抽取、`UpgradeCard` 显示、点击信号链路**全部不变**（见 `upgrade_and_shop_flow.md`）。

---

## 3. 可调整属性清单

字段名**必须与 `UnitStats`（`resources/units/unit_stats.gd`）里的 `@export` 字段名完全一致**，因为 `apply_upgrade` 用 `stats.set(字段名, ...)` 按名写回。

| 字段名 | 含义 | 来源 |
| --- | --- | --- |
| `damage` | 伤害 | 已有 |
| `speed` | 移动速度 | 已有 |
| `health` | 生命上限 | 已有 |
| `hp_regen` | 生命回复 | 已有 |
| `life_steal` | 生命偷取（百分比点数） | 已有 |
| `luck` | 幸运 | 已有 |
| `block_chance` | 格挡率（百分比点数） | 已有 |
| `harvesting` | 收获 | 已有 |

> 想加新属性：在 `UnitStats` 加字段 → 在 `ItemUpgrade` 加一个同名字段 → 在 `STAT_NAMES` 里加一行，即可出现在面板上。

---

## 4. 详细修改步骤

### 步骤 1：改造 `ItemUpgrade`

重写 `resources/items/upgrades/item_upgrade.gd`（替换掉 `value` / `stat_id` 字段）：

```gdscript
extends ItemBase
class_name ItemUpgrade
## 作用：描述一个"升级奖励"。可同时调整多个玩家属性：每个可调属性都是一个
##       数字字段，正数=增加、负数=减少、0=不涉及；点击卡片时把所有非 0 项
##       一次性应用到 Global.player.stats。


## ---------------------------------------------------------------------------
## 可调整属性（字段名必须与 UnitStats 的 @export 字段名一致，apply_upgrade
## 靠名字写回玩家 stats）。正=增加，负=减少，0=不涉及。
## ---------------------------------------------------------------------------
@export var damage := 0.0          # 伤害
@export var speed := 0.0           # 移动速度
@export var health := 0.0          # 生命上限
@export var hp_regen := 0.0        # 生命回复
@export var life_steal := 0.0      # 生命偷取（百分比点数）
@export var luck := 0.0            # 幸运
@export var block_chance := 0.0    # 格挡率（百分比点数）
@export var harvesting := 0.0      # 收获

## 手动描述（留空则 get_description() 按非 0 项自动生成）。可选，一般留空即可。
@export var description := ""


## 所有可调整属性名清单（新增属性：上面加字段 + 这里加名字）。
const STAT_NAMES: Array[String] = [
	"damage", "speed", "health", "hp_regen",
	"life_steal", "luck", "block_chance", "harvesting",
]


## 应用升级：把所有非 0 字段一次性累加到玩家对应属性。
## 被谁调用：UpgradeCard._on_custom_buttom_pressed（点击卡片）。
func apply_upgrade() -> void:
	for stat_name in STAT_NAMES:
		var v: float = get(stat_name)          # 反射读本字段当前值（正/负/0）
		if v == 0.0:
			continue
		var current := Global.player.stats.get(stat_name) as float
		Global.player.stats.set(stat_name, current + v)   # 正加负减


## 生成描述文本：优先用手写的 description，否则列出所有非 0 项。
## 被谁调用：UpgradeCard._set_data（显示卡片描述）。
func get_description() -> String:
	if description != "":
		return description
	var lines: Array[String] = []
	for stat_name in STAT_NAMES:
		var v: float = get(stat_name)
		if v > 0.0:
			lines.append("+%s %s" % [_fmt(v), stat_name])
		elif v < 0.0:
			lines.append("%s %s" % [_fmt(v), stat_name])
	return "\n".join(lines)


## 整数则去掉小数点（5.0 → "5"），否则保留原样。
func _fmt(v: float) -> String:
	if v == int(v):
		return str(int(v))
	return str(v)
```

要点：
- `get(stat_name)` 是 `Object` 的反射读取，`get("damage")` 等价于读 `self.damage`，让 `STAT_NAMES` 成为"唯一需要维护的属性清单"。
- `Global.player.stats.get(stat_name) as float` 与旧写法一致（字段不存在时安全返回 0）。
- 正加负减靠 `current + v` 天然实现（`v` 为负即减）。

### 步骤 2：`UpgradeCard` 改用 `get_description()`

修改 `scenes/ui/upgrade_card/upgrade_card.gd` 的 `_set_data()`，把读手写 `description` 改成调用 `get_description()`：

```gdscript
func _set_data(value: ItemUpgrade) -> void:
	item_data = value
	item_icon.texture = item_data.item_icon
	item_name.text = item_data.item_name
	item_description.text = item_data.get_description()   # 原：item_data.description
	var style := Global.get_tier_style(item_data.item_tier)
	add_theme_stylebox_override("panel", style)
```

> 注意：`UpgradeCard` 的 `Description` 节点是普通 `Label`（`upgrade_card.tscn:54`），**不渲染 BBCode**，所以上面 `get_description()` 返回的是**纯文本**（`+10 damage\n-2 speed`），不带颜色标签。若想给正/负项上色，把该 `Label` 换成 `RichTextLabel` 并勾选 `bbcode_enabled`，再在 `get_description()` 里包 `[color=green]/[color=red]` 即可（与 `ShopCard` 的 `ItemDescription` 一致）。

### 步骤 3：迁移 / 新建 `.tres` 数据

旧字段 `stat_id` + `value` 的**迁移规则**（`stat_id` 字符串本身就是字段名，所以是逐字对应）：

> 每个旧 `.tres`：删掉 `value` 和 `stat_id` 两行，把 `stat_id` 的名字当字段名、`value` 当值填进去，其余字段默认 0。

**1:1 迁移对照（8 个旧分类 → 字段名）**：

| 旧目录 / `stat_id` | 新字段 | 示例旧文件 | 迁移后 |
| --- | --- | --- | --- |
| `damage` | `damage` | `upgrade_damage_1.tres`（value=1） | `damage = 1.0` |
| `speed` | `speed` | `upgrade_speed_5.tres`（value=5） | `speed = 5.0` |
| `health` | `health` | `upgrade_health_1.tres`（value=1） | `health = 1.0` |
| `hp_regen` | `hp_regen` | `upgrade_hp_regen_2.tres` | `hp_regen = 2.0` |
| `life_steal` | `life_steal` | `upgrade_life_steal_1.tres` | `life_steal = 1.0` |
| `luck` | `luck` | `upgrade_luck_3.tres` | `luck = 3.0` |
| `block` | `block_chance` | `upgrade_block_1.tres` | `block_chance = 1.0` |
| `harvesting` | `harvesting` | `upgrade_harvesting_1.tres` | `harvesting = 1.0` |

迁移后单个 `.tres` 示例（`upgrade_damage_1.tres` 原本 `value=1 / stat_id="damage"`）：

```text
[resource]
script = ExtResource("...")
damage = 1.0
description = ""
item_name = "Damage"
item_icon = ExtResource("...")
item_tier = 0
item_type = 1
item_cost = 0
```

> 但**更推荐**：不要 1:1 迁移 48 张旧卡，而是借这次改造**重新设计卡组**——因为一张卡现在可以同时改多属性，你可以合并成更少、更有趣的卡。例如一张「狂怒」卡 `damage = 10.0` + `speed = -20.0`（对应被动 `passive_rage.tres` 的同款组合），一张卡顶过去两张。

### 步骤 4（可选）：`health` 变化的即时生效

`health` 是生命**上限**，直接 `stats.set("health", ...)` 只会改上限数字，不会立刻更新 `HealthComponent.max_health`（要到下一波 `update_player_new_wave` 才会 `health_component.setup(stats)`）。若希望加血立即生效，在 `apply_upgrade()` 末尾判断"本次是否改了 health"，改了则：

```gdscript
# 放在 apply_upgrade() 末尾，health 非 0 时重新初始化生命组件（满血进新上限）。
if health != 0.0:
	Global.player.health_component.setup(Global.player.stats)
```

> 这是**旧系统就存在**的问题（现在的 `upgrade_health_*.tres` 也一样延迟生效），并非本次改造引入；是否顺带修取决于你，不影响其它属性。

---

## 5. 备选方案：`Array[StatModifier]`（数据驱动版）

若希望"不写死属性、开发者自行增删任意属性"（更灵活、但要自己敲属性名），可改成一个小 Resource 列表：

```gdscript
# 新建 resources/items/upgrades/stat_modifier.gd
class_name StatModifier
extends Resource
@export var stat_id: String   # 属性名，如 "damage"
@export var value: float      # 正加负减，0 不涉及

# ItemUpgrade 里：
@export var modifiers: Array[StatModifier]

func apply_upgrade() -> void:
	for m in modifiers:
		if m and m.value != 0.0:
			var cur := Global.player.stats.get(m.stat_id) as float
			Global.player.stats.set(m.stat_id, cur + m.value)
```

取舍：

| | 方案 A：罗列字段（本文步骤 1） | 方案 B：`Array[StatModifier]` |
| --- | --- | --- |
| Inspector 体验 | 一排已命名字段，直接填数 | 点"添加元素"→ 敲属性名 → 填值 |
| 防错 | 字段名写死在脚本，不会拼错 | `stat_id` 自由字符串，拼错则静默失效 |
| 加新属性 | 改脚本（加字段+加清单） | 不改脚本，纯数据 |
| 与「罗列所有属性」的贴合度 | **完全贴合**（你要的效果） | 不贴合（属性名要自己填） |

用户需求是"**每个可调属性都罗列在面板上，开发者填 + / - / 0**"，方案 A 完全对应，故推荐 A。若未来属性很多且希望纯数据维护，再考虑 B。

---

## 6. 修改文件一览

**修改：**
```
resources/items/upgrades/item_upgrade.gd        # 步骤 1：多字段 + apply_upgrade + get_description
scenes/ui/upgrade_card/upgrade_card.gd          # 步骤 2：改用 get_description()
resources/items/upgrades/data/*/*.tres          # 步骤 3：迁移旧卡（或重设计卡组）
```

**不变（无需改动）：**
```
scenes/ui/upgrade_panel/upgrade_panel.gd/.tscn  # upgrade_list 抽取流程不变
autoloads/global.gd                             # select_items_for_offer 不变
scenes/ui/stats_container/*                     # 面板显示不变
```

---

## 7. 验证清单

- [ ] 在 Inspector 打开任意升级 `.tres`，能看到罗列的一排属性字段，填写 `+`/`-`/`0`。
- [ ] 一张卡填 `damage = 10`、`speed = -20`、其余 0，点选后：`Global.player.stats.damage` +10、`stats.speed` -20，其余属性不变。
- [ ] 卡片描述自动显示 `+10 damage` 和 `-20 speed`（无需手写）。
- [ ] 填 `description` 非空时，卡片显示手写文案（覆盖自动生成）。
- [ ] 所有字段为 0 的卡（或未选）点击后无副作用、不报错。
- [ ] 负属性把某项减到负值时，是否可接受（是否要给 `speed`/`health` 等加下限，见下方注意点 3）。
- [ ] 升级选完后仍按既有流程进下一波（`on_upgrade_selected` → `start_new_wave`），无回归。

---

## 8. 注意点 / 易错点

1. **字段名必须与 `UnitStats` 一字不差**：`apply_upgrade` 靠 `stats.set(字段名)` 写回，拼错（如 `block` vs `block_chance`、`resistance` vs `Resistance` 大小写）会静默失效，且控制台不报错。
2. **`get(stat_name)` 依赖字段存在**：`STAT_NAMES` 里写了、但脚本里没这个字段，`get()` 返回 null → `as float` = 0 → 被跳过（安全但等于没配）。
3. **负值下限**：目前纯 `+=`，负值可能把 `speed`/`health`/`hp_regen` 减成负数。是否给这些属性 `max(0, ...)` 下限，取决于你的数值设计。
4. **`health` 的即时生效**：见步骤 4，改上限不会立刻刷新当前血条，如需即时效果要重设 `health_component`。
5. **卡片描述是 `Label` 不是 `RichTextLabel`**：自动生成的描述用纯文本，别写 `[color]` 标签，否则会原样显示出来。
