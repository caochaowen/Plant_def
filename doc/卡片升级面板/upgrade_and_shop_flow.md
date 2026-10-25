# 升级面板 & 商店购买面板：从初始化到点击属性应用的完整调用流程

> 本文按"代码实际执行顺序"逐行追踪两张面板的完整链路：**波末升级面板**（`UpgradePanel`）和**商店购买面板**（`ShopPanel`），从各自的初始化入口，到玩家点击卡片，再到最终把属性/武器应用到玩家身上。
> 所有引用均为 `文件:行号`，可直接点击跳转。

---

## 0. 总览：两张面板共享的骨架

两张面板本质是同一套"**随机抽卡 → 显示卡片 → 点击 → 应用到玩家**"的流水线，只是商品来源、卡片类型、应用方式不同：

| 环节 | 升级面板 | 商店面板 |
| --- | --- | --- |
| 数据池配置位置 | `upgrade_panel.tscn` 的 `upgrade_list`（48 项 `ItemUpgrade`） | `shop_panel.tscn` 的 `shop_items`（50 项 `ItemWeapon`/`ItemPassive`） |
| 打开入口 | 波末自动弹出（`Arena.show_upgrades`） | 商店老板交互（`Arena.open_shop`） |
| 随机抽取 | `Global.select_items_for_offer(upgrade_list, wave, UPGRADE_PROBABILITY_CONFIG)` | `Global.select_items_for_offer(shop_items, wave, SHOP_PROBABILITY_CONFIG)` |
| 卡片类型 | `UpgradeCard` | `ShopCard` |
| 点击回调 | `UpgradeCard._on_custom_buttom_pressed` | `ShopCard._on_buy_buttom_pressed` |
| 应用方式 | `ItemUpgrade.apply_upgrade()` 累加 `stats[stat_id]` | 武器 → `Player.add_weapon()`；被动 → `ItemPassive.apply_passive()` |

核心共性结论：
- **随机抽取**都走 `Global.select_items_for_offer()`（内部用 `calculate_tier_probability()` 按波数+幸运算品质概率）。
- **卡片点击**都靠 `custom_button.tscn` 那个通用 `Button` 的 `pressed` 信号（在卡片 `.tscn` 里用 `[connection]` 连到卡片的回调）。
- **属性应用**最终都是**修改 `Global.player.stats`**（一个 `UnitStats` 资源）：升级用 `stat_id` 字符串，被动用 `add_stats`/`remove_stats` 字符串。

---

## 1. 升级面板（UpgradePanel）：完整链路

### 1.1 触发入口：波末结算

```
Spawner.WaveTimer 超时
  └─ Spawner._on_wave_timer_timeout()          (scenes/arena/spawner.gd:220)
       1. Global.game_paused = true             # 冻结战斗
       2. Global.get_harvesting_coins()         # 收获金币结算
       3. on_wave_completed.emit()              # 发信号 → Arena
       4. spawn_timer.stop()
       5. clear_enemies()                        # 清敌人
       6. update_enemies_new_wave()             # 敌人按波成长

Spawner.on_wave_completed 信号
  └─ Arena._on_spawner_on_wave_completed()     (scenes/arena/arena.gd:238)
       1. clean_arena()                          # 金币飞向金币袋、清敌人
       2. await 1 秒                            # 等收集动画
       3. show_upgrades()                        # ★ 打开升级面板
       4. clean_arena()                          # 二次清理
```

### 1.2 初始化：`show_upgrades()` → `load_upgrades()`

```gdscript
# Arena.show_upgrades()  (scenes/arena/arena.gd:120)
func show_upgrades() -> void:
	upgrade_panel.load_upgrades(spawner.wave_index)   # 用当前波数抽卡
	upgrade_panel.show()                               # 显示面板
```

```gdscript
# UpgradePanel.load_upgrades(current_wave)  (scenes/ui/upgrade_panel/upgrade_panel.gd:26)
func load_upgrades(current_wave: int) -> void:
	for child in items_container.get_children(): child.queue_free()   # 清空旧卡
	var config := Global.UPGRADE_PROBABILITY_CONFIG
	var selected_upgrades := Global.select_items_for_offer(upgrade_list, current_wave, config)  # 抽 4 个
	for random_upg: ItemUpgrade in selected_upgrades:
		var card_instance := UPGRADE_CARD_SCENE.instantiate() as UpgradeCard   # 实例化卡片
		items_container.add_child(card_instance)
		card_instance.item_data = random_upg     # 赋值触发 setter 刷新显示
```

> 此时 `upgrade_list` 来自 `upgrade_panel.tscn:77` 的导出数组（48 个 `ItemUpgrade` 资源）。

### 1.3 随机抽取：`Global.select_items_for_offer()`

```gdscript
# Global.select_items_for_offer(item_pool, current_wave, config)  (autoloads/global.gd:298)
func select_items_for_offer(item_pool, current_wave, config) -> Array:
	var tier_chances := calculate_tier_probability(current_wave, config)  # 四种品质概率
	# ... 用 randf() 掷点，映射到 传说/史诗/稀有/普通 四个区间 ...
	while offered_items.size() < 4:                 # 凑满 4 个不重复物品
		var roll := randf()                          # 掷点定品质
		# 按 roll 落入的累计区间确定 chosen_tier_index
		var potential_items = item_pool.filter(func(item): return item.item_tier == 当前品质)  # 按品质筛
		if potential_items 为空: 品质逐级降级回退
		selected_item = potential_items.pick_random()  # 随机取一个
		if not offered_items.has(selected_item): offered_items.append(selected_item)
	return offered_items
```

```gdscript
# Global.calculate_tier_probability(current_wave, config)  (autoloads/global.gd:226)
# 按波数线性增长各非普通品质概率，再乘玩家幸运(luck)，最后归一化，普通占剩余。
```

> 品质概率配置：升级用 `Global.UPGRADE_PROBABILITY_CONFIG`（`global.gd:86`），商店用 `Global.SHOP_PROBABILITY_CONFIG`（`global.gd:93`）。

### 1.4 卡片显示：`UpgradeCard._set_data()`

```gdscript
# UpgradeCard._set_data(value)  (scenes/ui/upgrade_card/upgrade_card.gd:33)  —— item_data 的 setter
func _set_data(value: ItemUpgrade) -> void:
	item_data = value
	item_icon.texture = item_data.item_icon
	item_name.text = item_data.item_name
	item_description.text = item_data.description
	var style := Global.get_tier_style(item_data.item_tier)   # 品质边框
	add_theme_stylebox_override("panel", style)
```

### 1.5 点击 → 属性应用：`_on_custom_buttom_pressed()`

卡片场景里有一行连接（`upgrade_card.tscn:73`）：

```text
[connection signal="pressed" from="MarginContainer/Control/CustomButtom" to="." method="_on_custom_buttom_pressed"]
```

点击那个通用 `Button`（`custom_buttom.tscn`，文本 "select"）→ `pressed` → 回调：

```gdscript
# UpgradeCard._on_custom_buttom_pressed()  (scenes/ui/upgrade_card/upgrade_card.gd:50)
func _on_custom_buttom_pressed() -> void:
	if item_data and is_instance_valid(Global.player):
		item_data.apply_upgrade()                       # ★ 应用升级属性
		SoundManager.play_sound(SoundManager.Sound.UI)
		Global.on_upgrade_selected.emit()               # 通知 Arena
```

```gdscript
# ItemUpgrade.apply_upgrade()  (resources/items/upgrades/item_upgrade.gd:24)
func apply_upgrade() -> void:
	var current_value := Global.player.stats.get(stat_id) as float   # 按属性名取当前值
	var new_value := float(value) + float(current_value)
	Global.player.stats.set(stat_id, new_value)                      # ★ 写回玩家属性
```

> **"属性应用"的本质**：`stat_id` 是字符串（如 `"damage"`、`"speed"`），`stats.get/set` 按名读写 `Global.player.stats` 这个 `UnitStats` 资源。加攻速之类新属性只需在 `UnitStats` 里加字段 + 建 `stat_id = "xxx"` 的升级资源即可（参见 `attack_speed.md`）。

### 1.6 应用之后的流程：`on_upgrade_selected` → 直接下一波

```gdscript
# Arena._ready 里连接： Global.on_upgrade_selected.connect(_on_upgrade_selected)  (arena.gd:82)

# Arena._on_upgrade_selected()  (scenes/arena/arena.gd:220)
func _on_upgrade_selected() -> void:
	upgrade_panel.hide()
	# ★ 注意：原"打开商店"逻辑已注释掉，改为直接开始下一波。
	start_new_wave()

# Arena.start_new_wave()  (arena.gd:130)
func start_new_wave() -> void:
	Global.game_paused = false
	Global.player.update_player_new_wave()      # 玩家生命按波成长
	spawner.wave_index += 1                     # 波数 +1
	spawner.start_wave()                        # 开始刷怪
	spawn_shopkeeper()                          # 刷商店老板
```

> **关键现状**（代码已改）：升级选完后**不再自动打开商店**，而是直接进下一波；商店改为在波中**与商店老板交互**打开（见 2.1）。

---

## 2. 商店购买面板（ShopPanel）：完整链路

### 2.1 打开入口：商店老板交互（以及初始武器装配）

```gdscript
# Arena.spawn_shopkeeper() 里连接：shopkeeper.on_interact.connect(_on_shopkeeper_interact)  (arena.gd:312)

# Arena._on_shopkeeper_interact()  (arena.gd:347)
func _on_shopkeeper_interact() -> void:
	open_shop()

# Arena.open_shop()  (arena.gd:335)
func open_shop() -> void:
	Global.game_paused = true                  # 逛商店时暂停战斗
	shop_panel.load_shop(spawner.wave_index)   # 抽商品
	shop_panel.show()                          # 显示商店
```

> 另有一条**初始武器**装配路径（角色选择完成后）：
> `Arena._on_selection_panel_on_selection_completed`（`arena.gd:276`）→ `player.add_weapon(...)` + `shop_panel.create_item_weapon(...)` + `Global.equipped_weapons.append(...)`，把初始武器同时装到玩家和商店武器栏。

### 2.2 初始化：`load_shop()`

```gdscript
# ShopPanel.load_shop(current_wave)  (scenes/ui/shop_panel/shop_panel.gd:67)
func load_shop(current_wave: int) -> void:
	for child in items_container.get_children(): child.queue_free()
	var config := Global.SHOP_PROBABILITY_CONFIG
	var selected_items := Global.select_items_for_offer(shop_items, current_wave, config)  # 抽 4 个
	for shop_item : ItemBase in selected_items:
		var card_instance := SHOP_CARD_SCENE.instantiate() as ShopCard
		card_instance.on_item_purchased.connect(_on_item_purchased)   # ★ 连接购买信号
		items_container.add_child(card_instance)
		card_instance.shop_item = shop_item      # setter 刷新显示
```

> 与升级面板同款流程，只是商品池是 `shop_items`（武器 + 被动，`shop_panel.tscn:121`），并多了 `on_item_purchased` 信号连接。

### 2.3 卡片显示：`ShopCard._set_shop_item()`

```gdscript
# ShopCard._set_shop_item(value)  (scenes/ui/shop_card/shop_card.gd:44)  —— shop_item 的 setter
func _set_shop_item(value: ItemBase) -> void:
	shop_item = value
	item_icon.texture = value.item_icon
	item_name.text = value.item_name
	item_type.text = ItemBase.ItemType.keys()[value.item_type]   # WEAPON/UPGRADE/PASSIVE
	item_description.text = value.get_description()              # BBCode 描述
	coins_label.text = str(value.item_cost)
	var style := Global.get_tier_style(value.item_tier)
	add_theme_stylebox_override("panel", style)
```

> `get_description()` 是多态：`ItemWeapon`（`item_weapon.gd:43`）显示伤害/冷却/射程/暴击；`ItemPassive`（`item_passive.gd:29`）显示 "+x stat / -x stat"。

### 2.4 点击购买 → 属性应用：`_on_buy_buttom_pressed()`

连接在 `shop_card.tscn:138`：

```text
[connection signal="pressed" from="MarginContainer/Control/BuyButtom" to="." method="_on_buy_buttom_pressed"]
```

```gdscript
# ShopCard._on_buy_buttom_pressed()  (scenes/ui/shop_card/shop_card.gd:66)
func _on_buy_buttom_pressed() -> void:
	SoundManager.play_sound(SoundManager.Sound.UI)
	if Global.equipped_weapons.size() >= 6:      # 武器槽上限（见注意点 3）
		return
	if Global.coins >= shop_item.item_cost:
		Global.coins -= shop_item.item_cost       # 扣钱
		on_item_purchased.emit(shop_item)         # ★ 发购买信号给 ShopPanel
		queue_free()                              # 销毁商品卡
```

### 2.5 属性应用：`ShopPanel._on_item_purchased()`

```gdscript
# ShopPanel._on_item_purchased(item)  (scenes/ui/shop_panel/shop_panel.gd:122)
func _on_item_purchased(item: ItemBase) -> void:
	var item_card := create_item_card()          # 实例化 ItemCard 并连接选中信号

	if item.item_type == ItemBase.ItemType.WEAPON:        # ★ 武器分支
		weapons_container.add_child(item_card)
		var weapon := item as ItemWeapon
		Global.player.add_weapon(weapon)                  # 装配武器
		Global.equipped_weapons.append(weapon)            # 记入全局装备列表

	elif item.item_type == ItemBase.ItemType.PASSIVE:     # ★ 被动分支
		passives_container.add_child(item_card)
		var passive := item as ItemPassive
		passive.apply_passive()                           # 立即应用被动属性

	item_card.item = item                    # setter 显示图标
```

**武器分支** → `Player.add_weapon()`（`scenes/unit/players/player.gd:128`）：

```gdscript
func add_weapon(data: ItemWeapon) -> void:
	var weapon := data.scene.instantiate() as Weapon   # 实例化武器场景
	add_child(weapon)
	weapon.setup_weapon(data)                          # 设置数值/射程/品质描边
	current_weapons.append(weapon)
	weapon_container.update_weapons_position(current_weapons)  # 按数量重新排布挂点
```

**被动分支** → `ItemPassive.apply_passive()`（`resources/items/passives/item_passive.gd:52`）：

```gdscript
func apply_passive() -> void:
	if add_value != 0:
		Global.player.stats[add_stats] += add_value        # ★ 例：stats["damage"] += 10
	if remove_value != 0:
		Global.player.stats[remove_stats] -= remove_value  # 例：stats["speed"] -= 20
```

> 被动道具的字段来自 `.tres`：`add_value` / `add_stats`（加属性），`remove_value` / `remove_stats`（减属性）。例：`passive_rage.tres` = `+10 damage`、`-20 speed`。

### 2.6 购买后的相关流程（选中 / 合成 / 出售）

商店武器栏/被动栏里的卡片是 `ItemCard`（`Button`）。点击武器卡片：

```
ItemCard._on_pressed()  (scenes/ui/item_card/item_card.gd:43)
  └─ 若是武器 → on_item_card_selected.emit(self)

ShopPanel._on_item_card_selected(card)  (shop_panel.gd:151)
  └─ 记录 context_card；统计同名武器数 ≥2 → combine_button.disabled = false

ShopPanel._on_combine_button_pressed()  (shop_panel.gd:176)   # 合成两把同名武器
  └─ 筛出 2 把同名武器 + 2 张同名卡 → 删除 → load(upgrade_to.resource_path) → add_weapon + 新卡

ShopPanel._on_sell_button_pressed()  (shop_panel.gd:235)       # 以 75% 价格卖出
  └─ 移除 1 把同名武器 → 售价 = item_cost * 0.75 → Global.coins += coins
```

---

## 3. 关键公共组件

### 3.1 `custom_button.tscn`（通用按钮）

`scenes/ui/custom_button/custom_buttom.tscn` 是一个纯 `Button`，带 hover/normal 样式和 "select" 文本。`UpgradeCard` 和 `ShopCard` 都用它，靠卡片 `.tscn` 里的 `[connection signal="pressed" ...]` 把点击连到各自回调。它本身**不含任何业务逻辑**。

### 3.2 品质样式 `Global.get_tier_style(tier)`

`global.gd:206`：按 `item_tier`（COMMON/RARE/EPIC/LEGENDARY）返回 `COMMON_STYLE` 等 `StyleBoxFlat`，卡片用它做边框着色。抽卡时也按这个品质筛选（`select_items_for_offer` 里的 `item.item_tier`）。

### 3.3 属性中枢 `Global.player.stats`

所有"应用属性"最终都落到 `Global.player.stats`（`UnitStats`）上，通过**字符串字段名**读写：
- 升级：`stats.set(stat_id, ...)`（`item_upgrade.gd:31`）
- 被动：`stats[add_stats] += ...`（`item_passive.gd:56`）
- 面板显示：`StatsContainer._process` 每帧读 `stats.xxx`（`stats_container.gd:43`）

---

## 4. 时序图（文本）

```
波末：WaveTimer 超时
  → Spawner._on_wave_timer_timeout
  → Arena._on_spawner_on_wave_completed
  → Arena.show_upgrades
  → UpgradePanel.load_upgrades
       → Global.select_items_for_offer → calculate_tier_probability
       → UpgradeCard(item_data = upg) → _set_data 渲染
玩家点击卡片
  → CustomButtom.pressed
  → UpgradeCard._on_custom_buttom_pressed
       → ItemUpgrade.apply_upgrade → stats.set(stat_id, ...)
       → Global.on_upgrade_selected.emit
  → Arena._on_upgrade_selected
       → start_new_wave

波中：与商店老板交互
  → Shopkeeper.on_interact
  → Arena._on_shopkeeper_interact → open_shop
  → ShopPanel.load_shop
       → Global.select_items_for_offer → calculate_tier_probability
       → ShopCard(shop_item = item) → _set_shop_item 渲染
玩家点击购买
  → BuyButtom.pressed
  → ShopCard._on_buy_buttom_pressed → 校验 + 扣钱 + on_item_purchased.emit
  → ShopPanel._on_item_purchased
       ├─ 武器 → Player.add_weapon + equipped_weapons.append
       └─ 被动 → ItemPassive.apply_passive → stats[add_stats] += ...
```

---

## 5. 注意点 / 易错点

1. **升级面板与商店已解耦**：`arena.gd` 里 `_on_upgrade_selected` 现在是 `start_new_wave()`（商店逻辑已注释）；商店只能在波中与商店老板交互打开（`open_shop`）。这与早期"升级后自动进商店"不同，后续改逻辑时注意别只改一处。

2. **属性应用是"累加"而非"覆盖"**：升级 `apply_upgrade` 用 `当前值 + value`；被动 `apply_passive` 用 `+=`。若想做成"乘法/百分比"（如攻速、暴击率），需单独写折算逻辑，不能直接套 `ItemUpgrade` 的加法规约（百分比属性在 `unit_stats.gd` 里是百分比点数，消费端再 `/100`）。

3. **商店购买卡片的武器槽上限判断有误伤**：`ShopCard._on_buy_buttom_pressed` 里 `if Global.equipped_weapons.size() >= 6: return` 是**无条件**提前返回，即使买的是被动道具也会被这个 6 武器上限挡住。应只在 `item_type == WEAPON` 时才判断该上限。

4. **两张卡片都依赖 `custom_button.tscn` 的 `pressed` 信号**：信号连接写在卡片 `.tscn` 的 `[connection]` 里（不在脚本 `_ready`）。若动态 `new()` 创建卡片而非 `.instantiate()` 场景，点击不会触发回调。

5. **随机抽取的"凑满 4 个"**：`select_items_for_offer` 里品质不够时会逐级降级回退（传说→普通），最坏退到普通；物品池太小可能抽不满 4 个。`upgrade_list`/`shop_items` 都在 `.tscn` 里逐个拖拽配置，新增物品需在对应 `.tscn` 的导出数组里注册（参见 `adding_upgrade_and_shop_cards.md`）。

6. **`Global.player` 有效性**：升级卡片点击前有 `is_instance_valid(Global.player)` 守卫；商店购买侧依赖 `Global.player` 的路径（`add_weapon`/`apply_passive`）由 `ShopPanel` 执行，靠 `on_item_purchased` 信号转发，未显式判空（正常流程下玩家始终存在）。

7. **波末两次 `clean_arena`**：`_on_spawner_on_wave_completed` 在 `show_upgrades` 前后各清一次，是为了覆盖 1 秒等待期间可能新出现的敌人/金币。
