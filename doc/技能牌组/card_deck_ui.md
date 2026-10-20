# 技能牌组 UI（CardDeck / DeckCard）实现说明 · 可视化操作版

> 目标：说明如何在**游戏界面正下方**实现五张技能卡卡槽的 UI。当前阶段只用「空卡占位」，
> 具体卡牌效果留待后续；本文同时记录**未来技能牌组机制**（商店购买 → 放入卡槽 → 独特增幅）的扩展方向。
>
> 📌 本文所有**节点参数**都用 Godot 编辑器右侧的**检查器（Inspector）面板**来描述，
> 方便在编辑器里照着点选，**不需要手写 .tscn 代码**。

---

## 0. 一句话结论

| 阶段 | 做什么 | 涉及文件 | 要不要写卡牌逻辑 |
| --- | --- | --- | --- |
| **当前**（已规划） | 底部正中放 5 个空卡槽 | `card_deck.*` + `deck_card.*` + `arena.tscn` | ❌ 不用，纯占位 |
| **未来** | 商店买卡 → 放入卡槽（≤5）→ 每张独特增幅 | 新增卡牌数据 + 商店购买分支 + 卡槽填充逻辑 | ✅ 要（较重） |

---

## 1. 需求概述

### 1.1 当前需求（本次范围）

在游戏 HUD 的**正下方**放置一排固定 5 个卡槽，作为「技能牌组」的占位 UI。此时卡槽里显示的是「空」占位，不承载任何实际效果。

### 1.2 未来设想（扩展方向，不在本次范围）

- 五张卡构成**技能牌组**，是玩家的核心构筑之一；
- 玩家在**商店**里购买技能卡，购得后**放入牌组卡槽**；
- 牌组**最多 5 张**，满了需先出售/替换；
- 每张卡有**独特的增幅效果**（如 +伤害、+攻速、特殊触发等），放进槽位即生效。

> 本文第 4 节会给出这个未来机制如何落地的建议，方便后续接手。

---

## 2. UI 结构设计

设计为两层，职责分离：

```
CardDeck (HBoxContainer)          ← 底部容器，负责布局与槽位管理
├── DeckCard 1  (Panel)           ← 单个卡槽，负责显示一张卡 / 空占位
├── DeckCard 2
├── DeckCard 3
├── DeckCard 4
└── DeckCard 5
```

- **`CardDeck`**：只做「5 个槽位怎么排、怎么取」，不关心单张卡长什么样。
- **`DeckCard`**：只做「这一格显示什么」，不关心自己排在哪个位置。

这样未来替换卡牌、排序、增删槽位时，两层互不影响。

### 2.1 定位：底部正中（关键锚点）

`CardDeck` 用**锚点 + 偏移**实现「正下方居中」，在检查器里这样设：

| 检查器里的位置 | 要设成什么 | 效果 |
| --- | --- | --- |
| **布局预设（Layout / 锚点预设）** | 选「底部居中（Center Bottom）」 | 自动把锚点设成：水平居中、贴屏幕底部 |
| 锚点（Anchors）左 / 右 | `0.5` | 水平中心对齐 |
| 锚点（Anchors）上 / 下 | `1.0` | 贴屏幕底部 |
| 偏移（Offsets）左 / 右 | `-332` / `+332` | 容器总宽 664px，相对中心左右对称 |
| 偏移（Offsets）上 / 下 | `-176` / `-16` | 距底部 16px，高 160px |
| 主题覆盖 → 常量（separation） | `16` | 卡槽间距 |

这样无论窗口怎么缩放，牌组始终水平居中、贴底。

---

## 3. 可视化搭建步骤

下面按「新建脚本 → 搭 CardDeck 容器 → 搭 DeckCard 卡槽 → 挂到 Arena」的顺序，
全程在编辑器里操作，只需对照检查器面板填参数。

### 3.1 新建脚本 `card_deck.gd`

> 这一步只建一个脚本文件，逻辑很简单，作用是「自动收集 5 个子卡槽」，
> 方便未来按序号取卡槽。**不涉及面板参数**。

脚本内容（`scenes/ui/card_deck/card_deck.gd`）：

```gdscript
extends HBoxContainer
class_name CardDeck

## 牌组最大卡槽数量。
const MAX_CARDS := 5

## 5 个卡槽引用（按从左到右顺序）。就绪时自动收集子节点中的 DeckCard。
@onready var slots: Array[DeckCard] = []

func _ready() -> void:
    for child in get_children():
        if child is DeckCard:
            slots.append(child as DeckCard)

## 返回指定下标的卡槽（越界返回 null）。
func get_slot(index: int) -> DeckCard:
    if index < 0 or index >= slots.size():
        return null
    return slots[index]
```

人话版：
- `MAX_CARDS = 5` 是唯一约束，未来想扩/缩卡槽数，改这里 + 场景里的子节点数即可。
- `slots` 会在就绪时**自动收集**子节点里的 `DeckCard`，不用在场景里逐个手动拖引用。
- `get_slot(index)` 是未来「放入第 N 张卡」的入口。

### 3.2 搭 CardDeck 容器（`card_deck.tscn`）

1. **新建场景**：文件系统面板 → 右键 `scenes/ui/card_deck/` → 新建场景，根节点类型选 **HBoxContainer**，命名为 `CardDeck`。
2. 选中 `CardDeck`，在右侧**检查器**里依次设置：

| 检查器分组 | 属性 | 值 |
| --- | --- | --- |
| 布局（Layout） | 锚点预设（Anchors Preset） | 选「底部居中（Center Bottom）」 |
| 布局 | 偏移 Offset Left / Top / Right / Bottom | `-332` / `-176` / `332` / `-16` |
| 主题覆盖（Theme Overrides）→ 常量（Constants） | Separation | `16` |

3. 把第 3.1 步的 `card_deck.gd` 脚本挂到 `CardDeck` 上：
   检查器顶部 → 脚本（Script）字段 → 点下拉 → **快速加载**选 `card_deck.gd`。

4. **放入 5 个子卡槽**：把第 3.3 步做好的 `deck_card.tscn` 从文件系统面板**拖 5 次**到 `CardDeck` 节点下，
   依次命名为 `DeckCard1` ~ `DeckCard5`。

> `HBoxContainer` 会自动把 5 个子卡槽**水平等距排开**，所以只需要设置容器整体位置，
> **不需要逐个给卡槽定位**。

### 3.3 搭 DeckCard 卡槽（`deck_card.tscn`）

1. **新建脚本** `scenes/ui/deck_card/deck_card.gd`，内容如下（作用：控制「空占位」的显示/隐藏，未来填真实卡牌时复用）：

```gdscript
extends Panel
class_name DeckCard

## 空卡占位标签（当前占位用；未来填入真实卡牌内容后隐藏）。
@onready var empty_label: Label = %EmptyLabel

## 把本卡槽重置为空卡占位状态。
func set_empty() -> void:
    empty_label.show()

## 在本卡槽上显示一张具体技能卡牌（占位实现，未来扩展）。
func set_card_data(_card_data) -> void:
    empty_label.hide()
```

2. **新建场景**：根节点类型选 **Panel**，命名为 `DeckCard`，挂上上面的脚本。

3. 选中 `DeckCard`，在**检查器**里设置尺寸与外观：

| 检查器分组 | 属性 | 值 | 说明 |
| --- | --- | --- | --- |
| 布局 | 自定义最小尺寸（Custom Minimum Size） | `X=120`、`Y=160` | 卡槽尺寸 |
| 主题覆盖 → 样式（Styles）→ Panel | （新建 StyleBoxFlat） | 见下表 | 卡片底色 + 圆角边框 |

4. **新建 StyleBoxFlat**：在「主题覆盖 → 样式 → Panel」点 `<空>` → 新建 **StyleBoxFlat**，再展开设置：

| StyleBoxFlat 属性 | 值 | 说明 |
| --- | --- | --- |
| 背景色（Background Color） | 深灰 `R26 G26 B26`，透明度 `55%` | 半透明深色底 |
| 边框宽度（Border Width）上/下/左/右 | 各 `2` | 细灰边框 |
| 边框颜色（Border Color） | 中灰 `R140 G140 B140`，透明度 `55%` | 边框颜色 |
| 圆角半径（Corner Radius）四角 | 各 `12` | 圆角 |

5. **加占位文字标签**：右键 `DeckCard` → 添加子节点 → **Label**，命名为 `EmptyLabel`。
   选中 `EmptyLabel`，在检查器里设置：

| 检查器分组 | 属性 | 值 |
| --- | --- | --- |
| 布局 | 锚点预设（Anchors Preset） | 选「全矩形（Full Rect）」铺满整张卡 |
| 文本（Text） | Text | `空` |
| 对齐 | 水平对齐（Horizontal Alignment） | 居中（Center） |
| 对齐 | 垂直对齐（Vertical Alignment） | 居中（Center） |
| 主题覆盖 → 标签设置（Label Settings） | （新建 LabelSettings） | 见下 |

6. **新建 LabelSettings**：在「主题覆盖 → 标签设置」点 `<空>` → 新建 **LabelSettings**，设置：

| LabelSettings 属性 | 值 | 说明 |
| --- | --- | --- |
| 字号（Font Size） | `36` | 大字占位 |
| 字体颜色（Font Color） | 浅灰 `R166 G166 B166`，透明度 `65%` | 半透明白灰 |

7. **把 `EmptyLabel` 设为唯一名称**：右键场景树里的 `EmptyLabel` → 勾选「**作为唯一名称访问（Access as Unique Name）**」。
   这样脚本里的 `%EmptyLabel` 才能找到它，且以后挪动节点路径也不会断。

> 成品效果：一张 `120×160`、圆角 `12`、半透明深色底 + 灰边框的「空白卡」，中间一个半透明的大「空」字。
> 未来放真实卡牌时，把 `EmptyLabel` 隐藏，再往 Panel 里加图标/名称/描述节点即可。

### 3.4 挂载到 Arena（`scenes/arena/arena.tscn`）

1. 打开 `scenes/arena/arena.tscn`，在左侧场景树里找到 **`GameUI`** 节点。
2. 从文件系统面板把 `card_deck.tscn` **拖到 `GameUI` 节点下**（编辑器会自动分配资源 id、处理引用）。

> 挂在 `GameUI` 下随 HUD 一起显示；`CardDeck` 自身的锚点是「底部居中」，所以在 `GameUI` 内会自动定位到屏幕正下方。
>
> ⚠️ 建议全程用**编辑器拖入**来加节点/挂脚本，不要手改 `.tscn` 文本文件，避免损坏场景。

---

## 4. 未来扩展：技能牌组机制（建议方向）

> 本节省略实现，只给落地路径，供后续单独开工时参考。

### 4.1 商店购买 → 放入卡槽

1. 新建卡牌数据资源（可复用现有 `ItemPassive` / `ItemUpgrade`，或新建 `SkillCard` 资源类），描述「卡牌名称 + 图标 + 增幅效果」。
2. 在 `ShopPanel._on_item_purchased(item)`（`scenes/ui/shop_panel/shop_panel.gd`）增加分支：
   ```gdscript
   elif item is SkillCard:
       card_deck.add_card(item)     # 放入第一个空槽
   ```
3. 在 `CardDeck` 上补 `add_card(card)` / `remove_card(index)`：遍历 `slots` 找第一个 `is_empty()` 的槽，调用 `slot.set_card_data(card)`；满 5 张时拦截（或提示先出售/替换）。
   - 需在 `DeckCard` 上加 `is_empty()` 状态标记，区分「空槽」与「已放卡」。

### 4.2 卡牌增幅效果

- 效果作用于玩家属性：放进槽位时调用一次 `apply()`（如 `stats.damage += x`），移出时 `revert()`。
- 触发型效果（如命中触发）需在战斗代码里读牌组状态，可让 `CardDeck` 暴露 `get_active_effects()` 给战斗系统轮询，或维护一个 `Array[SkillCard]` 由 `Global` 统一查询。
- 可参考 `resources/items/passives/item_passive.gd` 的 `apply_passive()` 思路，但注意**技能牌是「槽位常驻、可移除」，不是一次性购买生效**，因此必须有对应的 `revert()`。

### 4.3 与商店面板的交互时机

- 商店打开时游戏处于暂停（`Global.game_paused = true`，见 `doc/shopkeeper_interaction_refactor.md`），购买/出售卡牌应即时刷新 `CardDeck` 显示。
- 出售卡牌售价参考现有逻辑：`item_cost * 0.75`（见 `doc/卡片升级面板/adding_upgrade_and_shop_cards.md` 3.1）。

### 4.4 数据设计建议

- 若技能卡就是「一张卡一个属性加成」，可直接复用 `ItemPassive`；若要「一张卡带多个效果 / 条件触发」，建议新建 `SkillCard` 资源类并 `extends ItemBase`，避免污染现有 `item_type` 枚举（见该文档 4.2 的「按脚本类分发」建议）。

---

## 5. 检查清单

**当前（空卡 UI）**
- [ ] `card_deck.tscn` 根节点为 `HBoxContainer`，布局预设「底部居中」
- [ ] 5 个 `DeckCard` 子节点，主题覆盖 → 常量 separation = `16`
- [ ] `DeckCard` 自定义最小尺寸 `120×160`，StyleBoxFlat 圆角 `12`，显示「空」占位
- [ ] `CardDeck` 已作为 `GameUI` 子节点挂进 `arena.tscn`
- [ ] `card_deck.gd` 的 `slots` 能自动收集到 5 个 `DeckCard`

**未来（真实卡牌）**
- [ ] 卡牌数据资源已建（含名称/图标/效果）
- [ ] `CardDeck.add_card()` / `remove_card()` 已实现，满 5 张有拦截
- [ ] 卡牌效果有 `apply()` 与 `revert()` 成对实现
- [ ] 商店购买分支能正确把卡放入空槽
- [ ] 出售/替换会正确刷新 `CardDeck` 显示

---

## 6. 相关文件索引

```
scenes/ui/
├── card_deck/
│   ├── card_deck.gd                 # CardDeck：容器 + 槽位管理（get_slot/add_card 预留）
│   └── card_deck.tscn               # HBoxContainer 底部居中 + 5 个 DeckCard
└── deck_card/
    ├── deck_card.gd                 # DeckCard：单卡槽，set_empty/set_card_data 预留
    └── deck_card.tscn               # 120×160 圆角 Panel + 「空」占位标签

scenes/arena/arena.tscn              # GameUI 下挂 CardDeck 实例

# 未来接商店时涉及（现状见相关文档）：
scenes/ui/shop_panel/shop_panel.gd   # _on_item_purchased 购买分发
resources/items/passives/item_passive.gd   # 可参考的加成/生效思路
resources/items/item_base.gd         # 卡牌数据基类
```

### 关联文档
- `doc/卡片升级面板/adding_upgrade_and_shop_cards.md` —— 商店卡片 / 升级卡片的数据与注册方式
- `doc/卡片升级面板/cards_and_panels_flow.md` —— 卡片与面板的流程
- `doc/shopkeeper_interaction_refactor.md` —— 商店交互与暂停逻辑
