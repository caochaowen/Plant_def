# 卡片抽取规则与概率计算：逐行详解

> 本文只讲一件事：**波末升级卡片 / 商店商品是怎么"按品质概率随机抽 4 张"的**。
> 核心代码全在 `autoloads/global.gd` 的两个函数里，升级面板和商店面板共用同一套逻辑。
> 所有引用均为 `文件:行号`，可直接点击跳转。相关流程见 `upgrade_and_shop_flow.md`。

---

## 0. 一句话总览

抽卡 = 两步：

1. **算概率**：`calculate_tier_probability()` 根据「当前波数 + 玩家幸运值」算出四种品质（普通/稀有/史诗/传说）各自的出现概率。
2. **按概率抽**：`select_items_for_offer()` 掷随机数决定品质 → 从该品质的物品里随机取 1 个 → 重复直到凑满 4 个**不重复**物品。

升级用 `UPGRADE_PROBABILITY_CONFIG`，商店用 `SHOP_PROBABILITY_CONFIG`，其余完全一样。

---

## 1. 前置：品质枚举 `UpgradeTier`

`autoloads/global.gd:127`：

```gdscript
enum UpgradeTier{
	COMMON,      # 0
	RARE,        # 1
	EPIC,        # 2
	LEGENDARY    # 3
}
```

每个物品的 `item_tier`（`resources/items/item_base.gd:38`）就是这个枚举值。抽卡时**完全靠 `item_tier` 这个整数**来筛选物品，数值越大越稀有。

> 注意：`ItemBase` 里 `@export var item_tier: Global.UpgradeTier` **没有写默认值**，所以一个 `.tres` 如果不写 `item_tier`，它就默认是 `0`（COMMON）。

---

## 2. 概率配置常量

### 2.1 升级品质概率 `UPGRADE_PROBABILITY_CONFIG`

`autoloads/global.gd:86`：

```gdscript
const UPGRADE_PROBABILITY_CONFIG = {
	"rare":      { "start_wave": 2, "base_multi": 0.06 },
	"epic":      { "start_wave": 4, "base_multi": 0.02 },
	"legendary": { "start_wave": 7, "base_multi": 0.0023 },
}
```

含义：每个非普通品质有「**从第几波开始出现**」（`start_wave`）和「**每过一波概率增加多少**」（`base_multi`）。

### 2.2 商店品质概率 `SHOP_PROBABILITY_CONFIG`

`autoloads/global.gd:93`：

```gdscript
const SHOP_PROBABILITY_CONFIG = {
	"rare":      { "start_wave": 2, "base_multi": 0.10 },
	"epic":      { "start_wave": 4, "base_multi": 0.06 },
	"legendary": { "start_wave": 7, "base_multi": 0.01 },
}
```

结构与升级相同，只是 `base_multi` 更大（商店更容易出高品质）。

### 2.3 两个配置的对比

| 品质 | 升级 base_multi | 商店 base_multi | 起始波 start_wave |
| --- | --- | --- | --- |
| 稀有 RARE | 0.06 | 0.10 | 2 |
| 史诗 EPIC | 0.02 | 0.06 | 4 |
| 传说 LEGENDARY | 0.0023 | 0.01 | 7 |

---

## 3. `calculate_tier_probability()` 逐行详解

`autoloads/global.gd:226`。**输入**：当前波数 `current_wave`、概率配置 `config`（Dictionary）。**输出**：`[普通, 稀有, 史诗, 传说]` 四个 float。

### 3.1 初始化四个概率

```gdscript
var common_chance := 0.0
var rare_chance := 0.0
var epic_chance := 0.0
var legendary_chance := 0.0
```

四行把四种品质的概率都先置 0，后面按条件累加。

### 3.2 稀有概率（从第 2 波开始）

```gdscript
if current_wave >= config.rare.start_wave:
	rare_chance = min(1.0, (current_wave - 1) * config.rare.base_multi)
```

- `config` 是 Dictionary，`config.rare` 是 GDScript 的「点号访问字典键」写法，等价 `config["rare"]`，得到内层字典 `{"start_wave": 2, "base_multi": 0.06}`；再 `.start_wave` 取到 `2`。
- 条件 `current_wave >= 2`：**第 1 波稀有概率是 0**，第 2 波起才有。
- 概率公式 `(波数 - 1) * base_multi`：
  - 第 2 波 → `(2-1)*0.06 = 6%`
  - 第 3 波 → `12%`
  - 第 5 波 → `24%`
- `min(1.0, x)` 把结果**封顶 100%**（概率不能超过 1）。

### 3.3 史诗概率（从第 4 波开始）

```gdscript
if current_wave >= config.epic.start_wave:
	epic_chance = min(1.0, (current_wave - 3) * config.epic.base_multi)
```

- 起始波 `4`，所以 `current_wave >= 4` 才生效。
- 公式 `(波数 - 3) * 0.02`：第 4 波 → `2%`，第 5 波 → `4%`，第 8 波 → `10%`。

### 3.4 传说概率（从第 7 波开始）

```gdscript
if current_wave >= config.legendary.start_wave:
	legendary_chance = min(1.0, (current_wave - 6) * config.legendary.base_multi)
```

- 起始波 `7`，`current_wave >= 7` 才生效。
- 公式 `(波数 - 6) * 0.0023`：第 7 波 → `0.23%`，第 8 波 → `0.46%`。

> 小结：每种高品质都是「**到达起始波后，每过一波线性 + base_multi**」。起始波之前该品质概率恒为 0。

### 3.5 幸运值放大

```gdscript
var luck_factor := 1.0 + (Global.player.stats.luck / 100.0)
rare_chance *= luck_factor
epic_chance *= luck_factor
legendary_chance *= luck_factor
```

- `Global.player.stats.luck` 是玩家当前幸运属性。
- `luck / 100`：**10 点幸运 → 1.1 倍**，50 点幸运 → 1.5 倍。
- 只放大稀有/史诗/传说三种**非普通**品质，普通不参与（它最后拿剩余部分）。

### 3.6 归一化（防止总和超过 100%）

```gdscript
var total_non_common_chances := rare_chance + epic_chance + legendary_chance
if total_non_common_chances > 1.0:
	var scale_down := 1.0 / total_non_common_chances
	rare_chance *= scale_down
	epic_chance *= scale_down
	legendary_chance *= scale_down
	total_non_common_chances = 1.0
```

- 把三种非普通概率相加。若幸运放大后**总和超过 1.0**（比如高幸运把概率顶破 100%），就等比缩小到总和恰好 1.0。
- `scale_down = 1 / 总和` 是缩放系数，三个概率同乘它，保持相对比例不变、只整体压回 1.0。

### 3.7 普通概率 = 剩余部分

```gdscript
common_chance = 1.0 - total_non_common_chances
```

普通品质拿「剩下的」概率，保证四个概率之和永远等于 1（100%）。

### 3.8 打印与返回

```gdscript
print("Wave: %d, Luck: %.1f => Chances: C:%.2f R:%.2f E:%.2f L:%.2f" %
[current_wave, Global.player.stats.luck, common_chance, rare_chance, epic_chance, legendary_chance])

return [
	max(0.0, common_chance),
	max(0.0, rare_chance),
	max(0.0, epic_chance),
	max(0.0, legendary_chance),
]
```

- `print` 是调试输出，控制台能看到每波的概率分布。
- `return` 返回 `[普通, 稀有, 史诗, 传说]`，顺序对应 `UpgradeTier` 的 0/1/2/3。
- `max(0.0, x)` 是最后一道保险，防止任何概率是负数。

### 3.9 第一波的实际结果（例子）

第 1 波：稀有/史诗/传说都未达起始波 → 全 0；普通 = 1.0。返回 `[1.0, 0, 0, 0]` —— **第一波只会出普通品质**。

---

## 4. `select_items_for_offer()` 逐行详解

`autoloads/global.gd:298`。**输入**：物品池 `item_pool`、当前波数、配置。**输出**：最多 4 个不重复物品的 `Array`。

### 4.1 先算品质概率

```gdscript
var tier_chances := calculate_tier_probability(current_wave, config)
```

调用第 3 节的函数，得到 `[普通, 稀有, 史诗, 传说]` 四个概率。

### 4.2 把概率切成四段累计区间

```gdscript
var legendary_limit = tier_chances[3]
var epic_limit = legendary_limit + tier_chances[2]
var rare_limit = epic_limit + tier_chances[1]
```

这是「累计分布函数」的写法，把 `[0, 1)` 这条数轴按概率切成 4 段：

```
0 ──传说── legendary_limit ──史诗── epic_limit ──稀有── rare_limit ──普通── 1.0
```

- `legendary_limit` = 传说概率本身（第 0 段，长度 = 传说概率）。
- `epic_limit` = 传说 + 史诗（前两段累计）。
- `rare_limit` = 传说 + 史诗 + 稀有（前三段累计）。
- 剩下的 `[rare_limit, 1.0)` 就是普通。

> 举例：若 `[普通, 稀有, 史诗, 传说] = [0.7, 0.2, 0.08, 0.02]`，则：
> `legendary_limit = 0.02`，`epic_limit = 0.10`，`rare_limit = 0.30`。
> 掷到 `0.01` → 传说；`0.05` → 史诗；`0.15` → 稀有；`0.5` → 普通。

### 4.3 主循环：凑满 4 个不重复物品

```gdscript
var offered_items: Array = []
while offered_items.size() < 4:
	var roll := randf()
	var chosen_tier_index := 0
	if roll < legendary_limit:
		chosen_tier_index = 3
	elif roll < epic_limit:
		chosen_tier_index = 2
	elif roll < rare_limit:
		chosen_tier_index = 1
```

- `offered_items` 存最终结果，初始空。
- `while ... < 4`：循环直到拿到 4 个不重复物品。
- `roll := randf()`：掷一个 `[0, 1)` 的随机数，决定本次目标品质。
- `chosen_tier_index` 默认 `0`（普通）。
- 三个 `if/elif` 按 `roll` 落入哪个累计区间，把 `chosen_tier_index` 设为 3（传说）/ 2（史诗）/ 1（稀有）；都不满足就保持 0（普通）。

### 4.4 按品质筛物品 + 空档回退

```gdscript
	var potential_items: Array = []
	var current_search_tier_index := chosen_tier_index

	while potential_items.is_empty() and current_search_tier_index >= 0:
		potential_items = item_pool.filter(func(item: ItemBase): return item.item_tier == current_search_tier_index)
		if potential_items.is_empty():
			current_search_tier_index -= 1
		else:
			break
```

- `potential_items` 是「目标品质下的候选物品」。
- `filter()` 从 `item_pool` 里筛出 `item_tier == 当前品质索引` 的所有物品。
- 若目标品质**一个物品都没有**（比如 roll 到传说但池子里没传说），就 `current_search_tier_index -= 1` **逐级降级**：传说→史诗→稀有→普通，直到找到非空的一档。
- 内层 `while` 的退出条件 `current_search_tier_index >= 0`：最坏退到普通（0），保证「有物品可抽」。

### 4.5 随机取一个 + 去重

```gdscript
	if not potential_items.is_empty():
		var selected_item = potential_items.pick_random()
		if not offered_items.has(selected_item):
			offered_items.append(selected_item)
```

- 若候选非空，`pick_random()` 从候选里随机取 1 个。
- `offered_items.has(selected_item)` 判断是否已经抽过，**抽过就丢弃、不重复加入**（这就是"不重复"的来源）。

### 4.6 返回

```gdscript
return offered_items
```

返回最多 4 个物品。

---

## 5. 调用位置

抽卡逻辑有两个入口，都调用 `select_items_for_offer`，只是传入不同的池子和配置：

### 5.1 升级面板（波末）

`scenes/ui/upgrade_panel/upgrade_panel.gd:26`：

```gdscript
func load_upgrades(current_wave: int) -> void:
	for child in items_container.get_children(): child.queue_free()   # 清空旧卡
	var config := Global.UPGRADE_PROBABILITY_CONFIG
	var selected_upgrades := Global.select_items_for_offer(upgrade_list, current_wave, config)
	for random_upg: ItemUpgrade in selected_upgrades:
		var card_instance := UPGRADE_CARD_SCENE.instantiate() as UpgradeCard
		items_container.add_child(card_instance)
		card_instance.item_data = random_upg
```

- `upgrade_list` 来自 `upgrade_panel.tscn` 的导出数组（`Array[ItemUpgrade]`）。
- 波末由 `Arena.show_upgrades()`（`arena.gd:120`）调用。

### 5.2 商店面板

`scenes/ui/shop_panel/shop_panel.gd:67`：

```gdscript
func load_shop(current_wave: int) -> void:
	for child in items_container.get_children(): child.queue_free()
	var config := Global.SHOP_PROBABILITY_CONFIG
	var selected_items := Global.select_items_for_offer(shop_items, current_wave, config)
	for shop_item : ItemBase in selected_items:
		var card_instance := SHOP_CARD_SCENE.instantiate() as ShopCard
		card_instance.on_item_purchased.connect(_on_item_purchased)
		items_container.add_child(card_instance)
		card_instance.shop_item = shop_item
```

- `shop_items` 来自 `shop_panel.tscn` 的导出数组（武器 + 被动）。
- 由 `Arena.open_shop()`（`arena.gd:335`）在玩家与商店老板交互时调用。

---

## 6. 与「战斗概率」的区别（易混淆）

`global.gd:189` 还有个 `get_chance_sucess(chance)`：

```gdscript
func get_chance_sucess(chance: float) -> bool:
	var random := randf_range(0, 1.0)
	if random < chance:
		return true
	return false
```

它**不属于抽卡逻辑**，而是战斗里的通用单次判定（格挡、暴击、吸血），只是「`randf() < 概率` 即成功」。抽卡用的是 `select_items_for_offer`，别混在一起。

---

## 7. 已知的坑 / 边界条件

1. **死循环风险（当前项目已踩坑）**：`select_items_for_offer` 的 `while offered_items.size() < 4` **没有任何兜底**。如果某一品质（尤其普通）的物品数不足 4，且 `roll` 一直落在这个品质，就永远凑不满 4 个 → 死循环卡死。
   - 根因：`4.4` 的「降级回退」只在目标品质 **`filter` 结果为空**时才触发；若该品质**有物品但都已经被抽过了**（`4.5` 的 `has()` 一直为 true），回退不会触发，循环空转。
   - 例：`upgrade_list` 砍到 4 个、其中普通只有 2 个时，第 1 波（只出普通）必然死循环。

2. **物品池小于 4 个**：即使品质分布没问题，池子总共不足 4 个不同物品，也会因去重凑不满而空转。安全的写法应在循环里加「池子耗尽就 `break`」，或把上限改成 `min(4, 池子大小)`。

3. **`item_tier` 不写默认普通**：`.tres` 若漏写 `item_tier`，它默认 `0`（COMMON），可能让一张本意稀有的卡混进普通池，或反之。

4. **概率靠波数线性增长、无随机扰动**：同一波内所有玩家的概率是确定值（只有幸运和波数影响），不存在"连抽保底/伪随机"机制，抽卡纯随机。
