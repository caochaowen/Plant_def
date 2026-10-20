# 新增「属性升级卡片」与「商店卡片」指南

> 目标：说明在本项目中如何新增
> 1. **属性升级卡片**（波末三选一，`ItemUpgrade`）；
> 2. **商店卡片**（`ItemPassive` 被动道具 / `ItemWeapon` 武器）；
>
> 并指出**哪些情况只需加数据（`.tres`）**、**哪些情况必须改代码**，以及现有代码中限制新内容的几个坑。

---

## 0. 一句话结论

| 想做的事 | 需要动的东西 | 要不要改代码 |
| --- | --- | --- |
| 新增一个**已有属性**的升级卡（如 +7 伤害） | 1 个 `.tres` + 在 `upgrade_panel.tscn` 注册 | ❌ 不用 |
| 新增一个**全新属性**的升级卡（如 +暴击率） | 新增 `UnitStats` 字段 + 接入战斗逻辑 + `.tres` + 注册 | ✅ 要 |
| 新增被动道具卡（+A / -B，各一个属性） | 1 个 `.tres` + 在 `shop_panel.tscn` 注册 | ❌ 不用 |
| 新增**多属性 / 条件触发**的复杂道具 | 扩展 `ItemPassive` 子类 + 分发逻辑 | ✅ 要 |
| 新增武器卡 | ItemWeapon `.tres` + WeaponStats `.tres` + 武器场景 + 注册 | ✅ 要（较重） |
| 把**升级卡放进商店**卖 | `ShopPanel._on_item_purchased` 增加分支 | ✅ 要（当前不支持） |

---

## 1. 现有架构（关键文件速查）

| 关注点 | 文件 | 说明 |
| --- | --- | --- |
| 物品基类 | `resources/items/item_base.gd` | `ItemBase`：`item_name / item_icon / item_tier / item_type / item_cost`；枚举 `ItemType{WEAPON=0, UPGRADE=1, PASSIVE=2}` |
| 升级数据 | `resources/items/upgrades/item_upgrade.gd` | `ItemUpgrade`：`stat_id`（属性名）+ `value`（加值）+ `description`（**手工文案**） |
| 被动数据 | `resources/items/passives/item_passive.gd` | `ItemPassive`：`add_stats/add_value`、`remove_stats/remove_value`；`get_description()` 自动生成 BBCode |
| 武器数据 | `resources/items/weapons/item_weapon.gd` | `ItemWeapon`：`type/scene/stats/upgrade_to` |
| 玩家属性 | `resources/units/unit_stats.gd` | `UnitStats`：`stat_id` 必须是这里的字段名（damage/luck/speed/block_chance…） |
| 升级面板 | `scenes/ui/upgrade_panel/upgrade_panel.gd` + `.tscn` | `@export var upgrade_list: Array[ItemUpgrade]`（**在场景里配置**） |
| 商店面板 | `scenes/ui/shop_panel/shop_panel.gd` + `.tscn` | `@export var shop_items: Array[ItemBase]`（**在场景里配置**） |
| 升级卡片 | `scenes/ui/upgrade_card/upgrade_card.gd` | 点击 → `item_data.apply_upgrade()` → 发 `Global.on_upgrade_selected` |
| 商店卡片 | `scenes/ui/shop_card/shop_card.gd` | 点击 → 扣钱 → `on_item_purchased.emit()` |
| 概率与抽取 | `autoloads/global.gd` | `UPGRADE_PROBABILITY_CONFIG` / `SHOP_PROBABILITY_CONFIG`、`calculate_tier_probability()`、`select_items_for_offer()` |
| 图标素材 | `assets/sprites/Upgrades/*.png`（1~13） | 升级/被动共用的图标目录 |

**核心关系**：所有卡片的稀有度（品质）由 `item_tier`（0=普通/1=稀有/2=史诗/3=传说）决定，掉落概率完全由 `Global` 里的配置 + `calculate_tier_probability()` 计算，**不需要为单张卡片写概率代码**。

---

## 2. 新增「属性升级卡片」（ItemUpgrade）

升级卡的生效方式极简：`stat_id` 指向 `UnitStats` 的字段，`value` 是加值，点选时 `apply_upgrade()` 执行 `stats[stat_id] += value`。

### 2.1 前提：`stat_id` 必须存在于 `UnitStats`

打开 `resources/units/unit_stats.gd`，确认你要加的属性有对应字段：

```gdscript
@export var damage := 1.0        # stat_id = "damage"
@export var luck := 1.0          # stat_id = "luck"
@export var hp_regen := 0.0      # stat_id = "hp_regen"
```

现有可用 `stat_id`：`health`、`damage`、`speed`、`luck`、`block_chance`、`gold_drop`、`hp_regen`、`life_steal`、`harvesting`、`stamina`、`stamina_regen`。

### 2.2 步骤一：新建 `.tres` 数据文件

在 `resources/items/upgrades/data/<属性名>/` 下新建，命名约定沿用现有风格：`upgrade_<属性>_<数值>.tres`。

例如 `resources/items/upgrades/data/damage/upgrade_damage_7.tres`：

```ini
[gd_resource type="Resource" script_class="ItemUpgrade" load_steps=3 format=3 uid="uid://xxxxxx"]

[ext_resource type="Texture2D" path="res://assets/sprites/Upgrades/12.png" id="1_qw2me"]
[ext_resource type="Script" path="res://resources/items/upgrades/item_upgrade.gd" id="2_b4rq5"]

[resource]
script = ExtResource("2_b4rq5")
value = 7.0
description = "+7 伤害"
stat_id = "damage"
item_name = "Damage"
item_icon = ExtResource("1_qw2me")
item_tier = 1        # 0=普通 1=稀有 2=史诗 3=传说
item_type = 1        # 1 = UPGRADE
item_cost = 0        # 升级卡不走商店，固定 0
```

> **推荐做法**：不要手写 `.tres`，而是复制一个同类文件改数值，或在 Godot 编辑器里 `新建资源 → ItemUpgrade` 后逐项填。
> `metadata/_custom_type_script` 和 `uid` 由编辑器自动补全，手写容易漏。

字段要点：

| 字段 | 说明 |
| --- | --- |
| `stat_id` | **必须是 `UnitStats` 的字段名**，写错会在 `apply_upgrade()` 里得到 `null`，静默变 0 |
| `value` | 加值（float），写 `7` 或 `7.0` 均可 |
| `description` | **手工文案**，不会被自动生成。`UpgradeCard` 里用的是普通 `Label`，**不解析 BBCode**，请写纯文本如 `+7 伤害` |
| `item_tier` | 决定这张卡出现在哪个稀有度池 |
| `item_type` | 固定 `1`（`UPGRADE`） |

### 2.3 步骤二：注册到升级池（场景里配置）

升级池不是代码常量，而是 **`UpgradePanel` 节点上的导出数组**。两种等价做法：

**A. 编辑器（推荐）**
1. 打开 `scenes/ui/upgrade_panel/upgrade_panel.tscn`；
2. 选中根节点 `UpgradePanel`，在 Inspector 找到 `Upgrade List`；
3. `Add Element` → 拖入（或 Load）刚建的 `.tres`。

**B. 直接改 `.tscn`**
在 `upgrade_panel.tscn` 顶部加一条 `ext_resource`，并把新 UID 追加到 `upgrade_list` 数组里：

```ini
[ext_resource type="Resource" uid="uid://xxxxxx" path="res://resources/items/upgrades/data/damage/upgrade_damage_7.tres" id="49_abcd"]

[node name="UpgradePanel" type="Panel"]
upgrade_list = Array[ExtResource("2_aghkh")]([ ... , ExtResource("49_abcd")])
```

> ⚠️ 改 `.tscn` 时 `load_steps` 计数要 +1，且 UID 必须与 `.tres` 内部 `uid` 一致。**强烈建议用编辑器操作**，避免手改损坏场景。

**完成。** 无需任何脚本改动，卡片会自动按 `item_tier` 的概率被 `select_items_for_offer()` 抽到。

### 2.4 如果要加一个「全新属性」

例如"暴击率"：

1. 在 `resources/units/unit_stats.gd` 增加导出字段：
   ```gdscript
   @export var crit_chance := 0.0   # 暴击率（0~1）
   ```
2. **接入实际战斗逻辑**（这一步最容易漏，否则卡片加了属性但没效果）。例如 `scenes/weapons/melee/weapon_behavior.gd` 的 `get_damage()` 里用 `Global.get_chance_sucess(Global.player.stats.crit_chance)` 参与判定。
3. 可选：在 `scenes/ui/stats_container/stats_container.gd` 的 `_process()` 里加一行显示，并在 `stats_container.tscn` 加对应 `%CritLabel` 节点。
4. 最后按 2.2 / 2.3 建 `.tres` 并注册。

> 记住：`ItemUpgrade` 只会改 `UnitStats` 的**数值**；属性**怎么影响玩法**必须由战斗代码自己读取。

---

## 3. 新增「商店卡片」

商店卡片的处理入口是 `ShopPanel._on_item_purchased(item)`，它**按 `item_type` 分发**：

```gdscript
if item.item_type == ItemBase.ItemType.WEAPON:
    ...                            # 入武器栏 + Global.player.add_weapon()
elif item.item_type == ItemBase.ItemType.PASSIVE:
    ...passive.apply_passive()     # 立即生效
# 注意：没有 UPGRADE 分支
```

### 3.1 被动道具卡（ItemPassive）—— 最常用，通常不用改代码

被动道具支持 **"加一个属性 + 减一个属性"**（各一个），购买时立即生效。

**步骤一**：在 `resources/items/passives/data/` 新建 `.tres`，例如 `passive_rage.tres`：

```ini
[gd_resource type="Resource" script_class="ItemPassive" load_steps=3 format=3 uid="uid://yyyyyy"]

[ext_resource type="Script" path="res://resources/items/passives/item_passive.gd" id="1_ay6v8"]
[ext_resource type="Texture2D" path="res://assets/sprites/Upgrades/9.png" id="1_fe1fw"]

[resource]
script = ExtResource("1_ay6v8")
add_value = 10.0          # 增加量
add_stats = "damage"      # 增加的属性名（UnitStats 字段名）
remove_value = 20.0       # 减少量（不扣就填 0 + 空字符串）
remove_stats = "speed"
item_name = "Rage"
item_icon = ExtResource("1_fe1fw")
item_tier = 1             # 稀有
item_type = 2             # 2 = PASSIVE
item_cost = 45            # 商店售价（金币）
```

- `add_stats` / `remove_stats` 同样**必须是 `UnitStats` 的字段名**。
- 只加不减：`remove_value = 0.0`、`remove_stats = ""`（见 `passive_mighty_sword.tres`）。
- `item_cost` 是购买价；出售价 = `item_cost * 0.75`（`_on_sell_button_pressed`）。

**步骤二**：注册到商店池 —— 打开 `scenes/ui/shop_panel/shop_panel.tscn`，选中根节点 `ShopPanel`，在 Inspector 的 `Shop Items` 数组里 `Add Element` 加载该 `.tres`。

**完成。** 描述文本由 `ItemPassive.get_description()` 自动生成（绿色 `+N 属性` / 红色 `-N 属性`），无需手写。

### 3.2 武器卡（ItemWeapon）—— 较重

一把武器需要三份数据 + 一个场景：

| 文件 | 位置 | 作用 |
| --- | --- | --- |
| 武器数值 | `resources/items/weapons/melee/<名>/stats_<名>_N.tres` | `WeaponStats` |
| 武器物品 | `resources/items/weapons/melee/<名>/item_<名>_N.tres` | `ItemWeapon`，引用上面的 stats 与武器场景 |
| 武器场景 | `scenes/weapons/melee/weapon_<名>.tscn` | 实际攻击行为节点（脚本挂 `weapon_behavior.gd` / 子类） |
| 注册 | `shop_panel.tscn` 的 `shop_items` | 加入物品池 |

合成升级（两把同名合成）还需在低阶武器的 `upgrade_to` 里指向高阶 `ItemWeapon`（`_on_combine_button_pressed` 通过 `upgrade_to.resource_path` 加载）。

> 现成模板可参考斧头：`item_axe_1.tres` / `stats_axe_1.tres` / `weapon_axe.tscn`。

### 3.3 在商店里卖「升级卡」—— 当前不支持，需改代码

`_on_item_purchased` 没有 `UPGRADE` 分支，且 `ItemUpgrade` 未重写 `get_description()`（商店卡会显示空描述）。若要支持，改 `scenes/ui/shop_panel/shop_panel.gd`：

```gdscript
	elif item.item_type == ItemBase.ItemType.UPGRADE:
		passives_container.add_child(item_card)
		(item as ItemUpgrade).apply_upgrade()
```

并建议给 `ItemUpgrade` 补一个 `get_description()` 返回 `description`。

---

## 4. 必须注意的坑 / 建议修复

### 4.1 ⚠️ 购买被动道具会被"武器数量上限"误拦

`scenes/ui/shop_card/shop_card.gd:71`：

```gdscript
if Global.equipped_weapons.size() >= 6:
    return        # 无论买什么都会被拦
```

这个判断**没有区分物品类型**：一旦装备满 6 把武器，玩家将无法购买任何被动道具。建议改为：

```gdscript
if shop_item.item_type == ItemBase.ItemType.WEAPON and Global.equipped_weapons.size() >= 6:
    return
```

### 4.2 `ItemPassive` 表达力有限

只支持"加一个 + 减一个"数值属性。若要做**多属性叠加、按波数加成、命中触发**等效果，需要：

1. 新建子类 `extends ItemPassive`（或在 `ItemPassive` 上加新字段），重写 `apply_passive()`；
2. 让 `ShopPanel._on_item_purchased` 能分发到新类型。当前是按 `item_type` 枚举分发，**同 `item_type` 的多种行为无法区分**，建议改为按脚本类分发：
   ```gdscript
   if item is ItemWeapon:
       ...
   elif item is ItemPassive:
       (item as ItemPassive).apply_passive()
   ```
   （用 `is` 判断具体类型，比枚举更可扩展。）

### 4.3 概率抽取的隐含约束

`Global.select_items_for_offer()` 每次要凑 **4 张不重复**卡片，且当目标品质池为空时会**向低品质回退**。因此：

- 每个 `item_tier` 池最好有 **≥4 个不同物品**，否则会出现"翻来覆去同几张"或回退到普通的现象。
- 若某品质在 `*_PROBABILITY_CONFIG` 还没到 `start_wave`（稀有 2 波、史诗 4 波、传说 7 波），该品质的卡片**前期不会被抽到**，属正常现象。
- 想改某品质出现速度，调 `Global.UPGRADE_PROBABILITY_CONFIG` / `SHOP_PROBABILITY_CONFIG` 的 `base_multi`。

### 4.4 物品池放在场景里，维护成本高

`shop_items` 已有近 50 项、`upgrade_list` 有 48 项，都是**场景导出数组**，新增要逐个在 Inspector 拖拽，且多人协作时 `.tscn` 冲突频繁。

**可选的重构建议**：把物品池集中为一个注册表，便于批量管理。例如在 `global.gd` 里：

```gdscript
const UPGRADE_POOL: Array[ItemUpgrade] = [
    preload("res://resources/items/upgrades/data/damage/upgrade_damage_1.tres"),
    ...
]
```

再让 `UpgradePanel.load_upgrades()` 用 `Global.UPGRADE_POOL` 代替 `upgrade_list`（商店同理）。更进一步可扫描目录自动收集（`DirAccess.get_files_at()`）。属于优化项，非必需。

---

## 5. 新增卡片检查清单

**属性升级卡**
- [ ] `stat_id` 是 `UnitStats` 的字段名（新属性已加字段并接入战斗逻辑）
- [ ] `.tres` 放在 `resources/items/upgrades/data/<属性>/`，`item_type = 1`，`item_cost = 0`
- [ ] `description` 手写为纯文本（Label 不解析 BBCode）
- [ ] `item_tier` 已设置（0~3）
- [ ] 已注册进 `upgrade_panel.tscn` 的 `upgrade_list`
- [ ] 该品质池现在有 ≥4 个物品

**商店卡片（被动）**
- [ ] `add_stats` / `remove_stats` 是 `UnitStats` 字段名
- [ ] 不用的方向填 `0.0` + `""`
- [ ] `item_type = 2`，`item_cost > 0`
- [ ] 已注册进 `shop_panel.tscn` 的 `shop_items`
- [ ] （建议）已修复 `shop_card.gd` 的武器上限误拦问题

---

## 6. 相关文件索引

```                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
resources/items/
├── item_base.gd                      # ItemBase：公共字段 + ItemType 枚举
├── upgrades/item_upgrade.gd          # 升级卡脚本
├── upgrades/data/<属性>/*.tres        # 升级卡数据
├── passives/item_passive.gd          # 被动道具脚本
├── passives/data/*.tres              # 被动道具数据
└── weapons/item_weapon.gd            # 武器脚本（+ weapons/**/*.tres）

scenes/ui/
├── upgrade_panel/upgrade_panel.tscn  # upgrade_list 数组在此配置
├── upgrade_card/upgrade_card.gd      # 升级卡点击 → apply_upgrade()
├── shop_panel/shop_panel.tscn        # shop_items 数组在此配置
├── shop_panel/shop_panel.gd          # _on_item_purchased 按 item_type 分发
└── shop_card/shop_card.gd            # 购买校验（见坑 4.1）

resources/units/unit_stats.gd         # 所有 stat_id 的来源
autoloads/global.gd                   # 概率配置 + select_items_for_offer
assets/sprites/Upgrades/*.png         # 卡片图标素材
```
