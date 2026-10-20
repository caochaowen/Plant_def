# 卡片与面板实现流程总览

> 本文档系统解释本项目中**所有卡片（Card）与面板（Panel）的实现**，以及
> **"选择/点击某张卡片后，接下来调用哪些代码"** 的完整调用链。
>
> 与 `adding_upgrade_and_shop_cards.md`（「如何新增卡片」的指南）不同，本文档侧重
> **运行时数据流与信号调用链**：谁创建卡片 → 谁点它 → 触发什么信号 → 谁接收 → 又调用谁。

---

## 0. 一句话结论

- **4 种卡片**：`SelectionCard`（选角色/武器）、`ShopCard`（商店商品）、`UpgradeCard`（升级奖励）、`ItemCard`（背包物品）。
- **4 个面板**：`SelectionPanel`（开局选择）、`UpgradePanel`（波末升级）、`ShopPanel`（商店）、`StatsContainer`（属性展示）。
- 所有面板都由 `Arena`（`scenes/arena/arena.gd`）统一调度：**面板只发信号，Arena 负责切换**。
- 所有跨节点通信靠两类信号：**面板/卡片自身信号**（`on_selection_completed`、`on_item_purchased`、`on_shop_next_wave`、`on_item_card_selected`）和 **Global 事件总线**（`Global.on_upgrade_selected` 等）。
- 卡片显示数据来自 **Resource**（`ItemBase` 的三种子类），不存逻辑，只存数值。

---

## 1. 全局场景树（面板挂在哪）

面板不是独立场景，而是 `Arena` 场景 `GameUI`（CanvasLayer）下的子节点。来源：`scenes/arena/arena.tscn`。

```
Arena (Node2D)  script=arena.gd
├── BlackBG / GrassBG / Camera2D
├── Spawner (Node2D)                        script=spawner.gd
│   ├── SpawnTimer (Timer)
│   └── WaveTimer (Timer)
├── GameUI (CanvasLayer)
│   ├── CoinsBag                            唯一名 %CoinsBag
│   ├── CharacterStatus                     头像/血条/体力/技能栏
│   ├── WaveIndexLabel / WaveTimeLabel      唯一名 %WaveIndexLabel / %WaveTimeLabel
│   ├── UpgradePanel                        唯一名 %UpgradePanel，visible=false
│   ├── ShopPanel                           唯一名 %ShopPanel，visible=false
│   └── SelectionPanel                      开局默认可见
└── MusicPlayer
```

关键：`UpgradePanel` 与 `ShopPanel` 初始 `visible = false`，靠 `Arena` 调 `show()/hide()` 切换；`SelectionPanel` 初始可见，玩家点「continue」后自 `hide()`。

### 场景里的信号连线（tscn 内 `[connection]`）

| 信号 | 来自 | 连到 | 方法 |
| --- | --- | --- | --- |
| `on_wave_completed` | Spawner | Arena | `_on_spawner_on_wave_completed` |
| `on_shop_next_wave` | ShopPanel | Arena | `_on_shop_panel_on_shop_next_wave` |
| `on_selection_completed` | SelectionPanel | Arena | `_on_selection_panel_on_selection_completed` |
| `pressed`（continue 按钮） | SelectionPanel.tscn | SelectionPanel | `_on_continue_buttom_pressed` |
| `pressed`（buy 按钮） | ShopCard.tscn | ShopCard | `_on_buy_buttom_pressed` |
| `pressed`（CustomButtom） | UpgradeCard.tscn | UpgradeCard | `_on_custom_buttom_pressed` |
| `pressed`（NewWave/Combine/Sell） | ShopPanel.tscn | ShopPanel | `_on_new_wave_button_pressed` 等 |

> 卡片内部点击（SelectionCard/ItemCard）走的是 `Button` 自带的 `pressed` 信号，但它们的「选中」逻辑通过**回调绑定**（`.bind(data)`）或**自定义信号**（`on_item_card_selected`）上抛给面板。

---

## 2. 卡片四兄弟（Card）

### 2.1 SelectionCard —— 选择卡片（`extends Button`）
文件：`scenes/ui/selection_panel/selection_card.gd`

- 本质是一个图标 `Button`。
- `set_icon(texture)`：给按钮设图标。
- `_on_pressed()` / `_on_mouse_entered()`：播放 UI 音效。
- **它本身不携带业务逻辑**，选中的角色/武器数据由面板在 `connect` 时 `.bind()` 注入：

```gdscript
card.pressed.connect(_on_player_selected.bind(player))   # 角色
card.pressed.connect(_on_weapon_selected.bind(weapon))   # 武器
```

### 2.2 ShopCard —— 商店商品卡片（`extends Panel`）
文件：`scenes/ui/shop_card/shop_card.gd`

- 显示：图标 / 名称 / 类型 / 描述 / 价格；按品质着色边框。
- 数据通过 `@export var shop_item: ItemBase: set = _set_shop_item`，**赋值即刷新 UI**。
- 点击购买 `_on_buy_buttom_pressed()`：
  1. 校验武器槽（`Global.equipped_weapons.size() >= 6` 则拦截，⚠️ 见 6.1 坑）；
  2. 校验金币够不够；
  3. 扣钱 → `on_item_purchased.emit(shop_item)` → `queue_free()` 销毁自己。

### 2.3 UpgradeCard —— 升级奖励卡片（`extends Panel`）
文件：`scenes/ui/upgrade_card/upgrade_card.gd`

- 显示：图标 / 名称 / 描述（**纯文本 Label，不解析 BBCode**）；按品质着色。
- `@export var item_data: ItemUpgrade: set = _set_data` 赋值刷新。
- 点击 `_on_custom_buttom_pressed()`：
  1. `item_data.apply_upgrade()` 把属性加到玩家；
  2. 播放音效；
  3. `Global.on_upgrade_selected.emit()` —— **通过全局事件总线通知 Arena 进商店**。

### 2.4 ItemCard —— 背包物品卡片（`extends Button`）
文件：`scenes/ui/item_card/item_card.gd`

- 显示：物品图标 + 品质边框。
- `@export var item: ItemBase: set = _set_item` 赋值刷新。
- 点击 `_on_pressed()`：播音效；**仅当是武器**才 `on_item_card_selected.emit(self)`，
  用于商店里「选中某武器」以便合成/出售。

> 四种卡片的共同套路：**卡片 = 纯展示 + 一个点击回调 + 向上发信号**；真正的业务由面板/Arena 处理。

---

## 3. 面板四兄弟（Panel）

### 3.1 SelectionPanel —— 开局选择面板
文件：`scenes/ui/selection_panel/selection_panel.gd`

| 成员 | 作用 |
| --- | --- |
| `@export players: Array[UnitStats]` | 可选角色（在 tscn 配 5 个） |
| `@export start_weapons: Array[ItemWeapon]` | 可选初始武器（tscn 配 11 把） |
| `signal on_selection_completed` | 选完继续 → 通知 Arena |

流程：
- `_ready()`：清空两个容器 → `show_player_info(false)` → `load_players()` + `load_weapons()`。
- `load_players()`：遍历 `players`，实例化 `SelectionCard`，`pressed.connect(_on_player_selected.bind(player))`。
- `load_weapons()`：同理，`pressed.connect(_on_weapon_selected.bind(weapon))`。
- `_on_player_selected(player)`：写 `Global.main_player_selected`，右侧详情区显示角色属性。
- `_on_weapon_selected(weapon)`：写 `Global.main_weapon_selected`。
- `_on_continue_buttom_pressed()`：校验两者都已选 → `on_selection_completed.emit()` → `hide()`。

### 3.2 UpgradePanel —— 波末升级面板
文件：`scenes/ui/upgrade_panel/upgrade_panel.gd`

- `@export upgrade_list: Array[ItemUpgrade]`（tscn 配 48 个）。
- `load_upgrades(current_wave)`：清空容器 → `Global.select_items_for_offer(upgrade_list, wave, config)` 随机抽 4 个 → 实例化 `UpgradeCard` 并 `card_instance.item_data = random_upg`（触发 setter 刷新）。

### 3.3 ShopPanel —— 商店面板（最复杂）
文件：`scenes/ui/shop_panel/shop_panel.gd`

| 成员 | 作用 |
| --- | --- |
| `@export shop_items: Array[ItemBase]` | 商店物品池（tscn 配 50 项） |
| `signal on_shop_next_wave` | 「下一波」→ 通知 Arena |
| `var context_card: ItemCard` | 当前选中的武器卡片（合成/出售目标） |

方法：
- `_ready()`：清空被动栏、武器栏。
- `load_shop(current_wave)`：`select_items_for_offer` 抽 4 件 → 实例化 `ShopCard` → `on_item_purchased.connect(_on_item_purchased)` → `shop_item = ...`。
- `create_item_card()`：实例化 `ItemCard` 并连接 `on_item_card_selected`，返回。
- `create_item_weapon(weapon)`：建 `ItemCard` → 加进武器栏 → 设 `item`。
- `_on_item_purchased(item)`：按 `item_type` 分发：
  - `WEAPON` → 入武器栏 + `Global.player.add_weapon()` + `Global.equipped_weapons.append()`；
  - `PASSIVE` → 入被动栏 + `passive.apply_passive()`。
- `_on_item_card_selected(card)`：记 `context_card`；统计同名武器数 ≥2 才 `combine_button.disabled = false`。
- `_on_combine_button_pressed()`：两把同名武器合成 `upgrade_to`（详见 5.3）。
- `_on_sell_button_pressed()`：以 75% 价格出售选中武器。
- `_on_new_wave_button_pressed()`：`on_shop_next_wave.emit()`。

### 3.4 StatsContainer —— 属性面板
文件：`scenes/ui/stats_container/stats_container.gd`

- 每帧 `_process` 从 `Global.player.stats` 读 8 项属性刷新到 Label（生命/回血/吸血/伤害/幸运/速度/格挡/收获）。
- 面板类里唯一「被升级/被动改动后能实时看到结果」的展示层。

---

## 4. 数据层：卡片背后背的是什么

`resources/items/` 下是 Resource 继承链：

```
ItemBase (item_base.gd)
 ├── 公共字段：item_name / item_icon / item_tier / item_type / item_cost
 ├── 枚举 ItemType { WEAPON=0, UPGRADE=1, PASSIVE=2 }
 ├── get_description() → ""（子类可重写）
 │
 ├─ ItemUpgrade (upgrades/item_upgrade.gd)
 │    value / description / stat_id
 │    apply_upgrade() → Global.player.stats.set(stat_id, 当前值 + value)
 │
 ├─ ItemPassive (passives/item_passive.gd)
 │    add_value/add_stats + remove_value/remove_stats
 │    get_description() → 自动生成绿色 +N / 红色 -N 的 BBCode
 │    apply_passive()  → stats[add_stats] += add_value; stats[remove_stats] -= remove_value
 │
 └─ ItemWeapon (weapons/item_weapon.gd)
      type(MELEE/RANGE) / scene(PackedScene) / stats(WeaponStats) / upgrade_to(ItemWeapon)
      get_description() → 伤害/冷却/射程/暴击
```

关键点：**卡片只读数据**，`item_tier`（品质枚举 `Global.UpgradeTier`，0普通/1稀有/2史诗/3传说）同时决定：
1. 掉落概率（`select_items_for_offer`）；
2. 边框颜色（`Global.get_tier_style`）。

---

## 5. 核心调用链（"选择面板后调用的代码"）

### 5.1 开局：选择面板 → 进入第一波

```
SelectionPanel._ready()
  └→ load_players() / load_weapons()   # 生成 SelectionCard 并 bind 数据
玩家点角色卡（SelectionCard pressed）
  └→ SelectionPanel._on_player_selected(player)
       ├→ Global.main_player_selected = player
       └→ show_player_info(true)  # 右侧详情
玩家点武器卡
  └→ SelectionPanel._on_weapon_selected(weapon)
       └→ Global.main_weapon_selected = weapon
玩家点「continue」
  └→ SelectionPanel._on_continue_buttom_pressed()
       ├→ 校验两者已选
       ├→ on_selection_completed.emit()
       └→ hide()
       │
       ▼ （arena.tscn 连线）
Arena._on_selection_panel_on_selection_completed()
  ├→ Global.get_selected_player()      # 用 main_player_selected.name 实例化玩家，写 Global.player
  ├→ add_child(player)
  ├→ player.add_weapon(Global.main_weapon_selected)          # 装配初始武器
  ├→ shop_panel.create_item_weapon(Global.main_weapon_selected)  # 商店武器栏生成 ItemCard
  ├→ Global.equipped_weapons.append(Global.main_weapon_selected)
  ├→ spawner.start_wave()              # 第一波开始
  └→ Global.game_paused = false
```

### 5.2 波末：波结束 → 升级面板 → 商店

```
Spawner.WaveTimer 超时
  └→ Spawner._on_wave_timer_timeout()
       ├→ Global.game_paused = true
       ├→ Global.get_harvesting_coins()   # 收获结算
       ├→ on_wave_completed.emit()
       ├→ spawn_timer.stop()
       ├→ clear_enemies()
       └→ update_enemies_new_wave()
       │
       ▼
Arena._on_spawner_on_wave_completed()
  ├→ clean_arena()                       # 金币飞向金币袋 + 清敌人
  ├→ await 1 秒（create_timer）
  ├→ show_upgrades()
  │    ├→ upgrade_panel.load_upgrades(spawner.wave_index)   # 抽 4 个升级
  │    └→ upgrade_panel.show()
  └→ clean_arena()（二次清理）
```

### 5.3 升级选择 → 商店 → 购买/合成/出售 → 下一波

```
玩家点升级卡（UpgradeCard）
  └→ UpgradeCard._on_custom_buttom_pressed()
       ├→ item_data.apply_upgrade()          # 属性累加
       ├→ SoundManager.play_sound(UI)
       └→ Global.on_upgrade_selected.emit()   # ★ 全局事件总线
       │
       ▼ （arena.gd _ready 里 connect）
Arena._on_upgrade_selected()
  ├→ upgrade_panel.hide()
  ├→ shop_panel.load_shop(spawner.wave_index)   # 抽 4 件商品
  └→ shop_panel.show()

玩家点商店卡购买（ShopCard）
  └→ ShopCard._on_buy_buttom_pressed()
       ├→ 武器槽满(≥6) → return（⚠️ 坑 6.1）
       ├→ 金币够 → Global.coins -= cost
       ├→ on_item_purchased.emit(shop_item)
       └→ queue_free()
       │
       ▼
ShopPanel._on_item_purchased(item)
  ├→ create_item_card()
  └→ 按 item_type：
       WEAPON  → weapons_container.add_child + player.add_weapon + equipped_weapons.append
       PASSIVE → passives_container.add_child + passive.apply_passive()

玩家点背包武器卡（ItemCard）
  └→ ItemCard._on_pressed()
       └→ (武器) on_item_card_selected.emit(self)
       │
       ▼
ShopPanel._on_item_card_selected(card)
  └→ context_card = card；同名武器 ≥2 → combine_button 可用

点「combine」
  └→ ShopPanel._on_combine_button_pressed()
       ├→ 筛出 2 把同名武器 + 2 张同名卡
       ├→ 删除武器实例（current_weapons / equipped_weapons / queue_free）
       ├→ 删除 2 张卡
       ├→ load(upgrade_to.resource_path) 得升级武器
       ├→ player.add_weapon(升级武器) + equipped_weapons.append
       └→ 新建 ItemCard 显示升级武器

点「sell」
  └→ ShopPanel._on_sell_button_pressed()
       ├→ 售价 = item_cost * 0.75
       ├→ 删除第一把同名武器实例
       ├→ context_card.queue_free()
       └→ Global.coins += 售价

点「next wave」
  └→ ShopPanel._on_new_wave_button_pressed()
       └→ on_shop_next_wave.emit()
       │
       ▼
Arena._on_shop_panel_on_shop_next_wave()
  ├→ shop_panel.hide()
  └→ start_new_wave()
       ├→ Global.game_paused = false
       ├→ Global.player.update_player_new_wave()
       ├→ spawner.wave_index += 1
       └→ spawner.start_wave()   # 回到 5.2 循环
```

---

## 6. 概率抽取（卡片怎么被"随机"选中）

`Global.select_items_for_offer(item_pool, current_wave, config)` 是升级与商店共用的抽取器：

1. `calculate_tier_probability()` 按配置算出四品质概率 `[普通, 稀有, 史诗, 传说]`；
   - 稀有第 2 波、史诗第 4 波、传说第 7 波起出现，概率随波数线性增长；
   - 玩家 `luck` 会放大非普通品质概率（`1 + luck/100`），最后归一化。
2. 循环抽 4 个**不重复**物品：`randf()` 落进某个品质区间 → 用 `filter()` 在该品质池找候选 → 池空则向低品质回退 → `pick_random()`。

配置常量（`global.gd`）：

| 常量 | 用途 |
| --- | --- |
| `UPGRADE_PROBABILITY_CONFIG` | 升级奖励品质概率 |
| `SHOP_PROBABILITY_CONFIG` | 商店商品品质概率 |

品质 → 边框样式由 `Global.get_tier_style(tier)` 返回预加载的 4 个 StyleBoxFlat（`COMMON/RARE/EPIC/LEGENDARY_STYLE`）。

---

## 7. Global 事件总线（跨场景通信）

`autoloads/global.gd` 上的信号（卡片/面板流程涉及到的）：

| 信号 | 发出者 | 接收者 |
| --- | --- | --- |
| `on_upgrade_selected` | UpgradeCard | Arena（切商店） |
| `on_create_block_text` / `on_create_damage_text` / `on_create_heal_text` | Unit / WeaponBehavior | Arena（浮动文字） |
| `on_enemy_died` | Enemy | Arena（掉金币） |

其它被卡片流程用到的 Global 成员：

- 预加载场景：`ITEM_CARD_SCENE`、`SELECTION_CARD_SCENE`（面板据此 `instantiate()` 卡片）。
- 状态：`coins`、`player`、`game_paused`、`main_player_selected`、`main_weapon_selected`、`equipped_weapons`。
- 方法：`get_tier_style()`、`calculate_tier_probability()`、`select_items_for_offer()`、`get_selected_player()`、`get_chance_sucess()`、`get_harvesting_coins()`。

---

## 8. 坑与提醒（与卡片/面板直接相关）

1. **买被动被武器槽误拦**：`shop_card.gd:71` 的 `if Global.equipped_weapons.size() >= 6: return` 不分物品类型，满武器后无法买任何被动。应加 `shop_item.item_type == WEAPON` 前缀判断。
2. **升级卡描述是纯文本**：`UpgradeCard` 用普通 `Label`，`ItemUpgrade.description` 里的 BBCode 不会渲染。
3. **合成条件**：需同名武器 ≥2 且 `upgrade_to` 非空；否则 `combine_button` 置灰 / 点击无效。
4. **出售/合成对象来自 `context_card`**：必须先在武器卡上点一下（触发 `on_item_card_selected`），否则 `context_card == null` 直接 return。
5. **物品池在 tscn 里配置**：`upgrade_list`（48）与 `shop_items`（50）都是场景导出数组，新增需在 Inspector 逐个拖，协作时 `.tscn` 易冲突（重构建议见 `adding_upgrade_and_shop_cards.md` 4.4）。

---

## 9. 文件索引

```
场景 / UI
scenes/arena/arena.gd                 # 总调度：连信号、切面板、实例化玩家
scenes/arena/arena.tscn               # 面板挂载 + [connection] 连线
scenes/arena/spawner.gd               # 波次循环，on_wave_completed 触发结算
scenes/ui/selection_panel/            # 开局选择（SelectionPanel + SelectionCard）
scenes/ui/upgrade_panel/              # 波末升级（UpgradePanel）
scenes/ui/upgrade_card/               # 升级卡（UpgradeCard）
scenes/ui/shop_panel/                 # 商店（ShopPanel）
scenes/ui/shop_card/                  # 商品卡（ShopCard）
scenes/ui/item_card/                  # 背包物品卡（ItemCard）
scenes/ui/stats_container/            # 属性展示（StatsContainer）
scenes/ui/character_status/           # 血条/体力/技能栏（非卡片流程）
scenes/ui/coins_bag/                  # 金币显示

数据 Resource
resources/items/item_base.gd          # ItemBase + ItemType 枚举
resources/items/upgrades/item_upgrade.gd
resources/items/passives/item_passive.gd
resources/items/weapons/item_weapon.gd
resources/units/unit_stats.gd         # stat_id 字段来源

全局
autoloads/global.gd                   # 事件总线 + 概率抽取 + 预加载资源
autoloads/sound_manager.gd            # UI 音效

文档
doc/adding_upgrade_and_shop_cards.md  # 如何新增卡片（配套指南）
doc/cards_and_panels_flow.md          # 本文档：卡片/面板实现与调用链
```
