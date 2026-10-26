# 升级面板并入商店面板 + 商店老板安全区（找老板即跳过波次）改造方案 v2

> 本文是**实现方案（设计文档）**，不直接改代码。需求（v2 更正版）：
> 1. 升级面板并入商店面板：商店右上角加「煅体」按钮跳转升级面板，升级面板右下角加「商店」按钮返回商店。
> 2. **波末不清除、也不冻结敌人**：敌人自由移动，但**不能靠近商店老板周围**（安全区）。
> 3. 角色离开老板周围后敌人恢复正常攻击，并开启下一波。
> 4. **波中也能找老板**：找老板后（无论买没买），角色一离开老板周围就进入下一波——即**当前波次直接跳过**。
>
> 所有引用为 `文件:行号`。相关既有流程见 `upgrade_and_shop_flow.md`，抽卡概率见 `card_draw_probability.md`。

---

## 0. 与上一版的差异（关键更正）

| | v1（旧方案） | v2（本方案） |
| --- | --- | --- |
| 波末敌人 | 冻结（`shop_phase` 早退）或清除 | **不清除、不冻结**，靠安全区斥力挡在外 |
| 敌人状态 | 波间静止 | **全程自由移动**，只是进不了老板安全区 |
| 老板出现时机 | 波末才刷 | **波开始就刷**（波中可找） |
| 波末玩家 | 瞬移到老板旁 | 仍瞬移到老板旁（安全区内） |
| 下一波触发 | 离开安全区 | 离开安全区（同上） |
| 波中找老板 | 无 | **有**：找完离开 = 跳过当前波 |

核心机制一句话：**用一个「老板安全区」替代原来的「冻结/清除」，既保护玩家，又让敌人始终活跃。**

---

## 1. 核心机制：商店老板安全区

- 商店老板有一个以自身为圆心的**安全区**（半径 `safe_radius`）。
- 敌人在接近安全区时受到一个**向外推的斥力**，因此无法进入安全区，只能在外围游荡。
- 玩家可以自由进出安全区（敌人不会跟进来）。
- 玩家在安全区内是安全的：可找老板逛商店、煅体升级。
- **离开安全区 = 结束当前波、进入下一波。**

这样，敌人从头到尾都在动（不冻结、不清除），只是被安全区隔在老板之外。

---

## 2. 新增全局状态与引用

在 `autoloads/global.gd` 运行时变量区（`game_paused` 附近，约 `global.gd:142`）新增：

```gdscript
## 波间/商店阶段标记：true 时波计时/刷怪停止，商店/升级 UI 打开。
## 注意：此标记**不冻结敌人**（敌人照常移动，只是被安全区挡住）。
## 玩家走出老板安全区后，由 Arena 置 false 并开启下一波。
var shop_phase := false

## 当前商店老板的引用（由 Arena.spawn_shopkeeper 赋值）。
## 供敌人 get_move_direction() 读取安全区中心，做"远离老板"的斥力。
var shopkeeper: Shopkeeper
```

> `game_paused` 仍保留，用于「完全冻结」的场景（角色选择等）。商店阶段**不再使用** `game_paused`（否则会冻住敌人，违反需求）。

---

## 3. 商店老板：加安全区半径

`scenes/unit/Shopkeeper/shopkeeper.gd`（`interact_distance` 附近，约 `shopkeeper.gd:17`）新增：

```gdscript
## 交互触发距离（像素）。
@export var interact_distance := 120.0

## 安全区半径（像素）：敌人被斥力挡在此半径之外，玩家可自由进出。
@export var safe_radius := 300.0
```

> 关系：`interact_distance`（120）决定「能按交互键开店」的距离；`safe_radius`（300）决定「敌人进不来」的范围。玩家在 300 内都是安全的，但只有 120 内才能按交互键。

---

## 4. 敌人：安全区斥力（不冻结、不清除）

### 4.1 `_process` 不动

`scenes/unit/enemy/enemy.gd:43` 的 `_process` 保持现状，**只检查 `game_paused`，不加 `shop_phase` 判断**：

```gdscript
func _process(delta: float) -> void:
	if Global.game_paused: return   # 只有完全暂停才冻敌人；商店阶段不设 game_paused
	# ... 原有移动逻辑不变 ...
```

这样商店阶段敌人不会被冻住。

### 4.2 `get_move_direction()` 加斥力

`scenes/unit/enemy/enemy.gd:65` 的 `get_move_direction()` 在原有「朝玩家 + flock 分离」之后，叠加「远离老板」的力：

```gdscript
func get_move_direction() -> Vector2:
	if not is_instance_valid(Global.player):
		return Vector2.ZERO
	var direction := global_position.direction_to(Global.player.global_position)

	# ... 原有 flock 群体分离循环（保持不变）...

	# ★ 新增：远离商店老板安全区（敌人无法靠近老板）
	if is_instance_valid(Global.shopkeeper):
		var keeper := Global.shopkeeper
		var to_keeper := global_position - keeper.global_position   # 从老板指向自己的向量
		var dist := to_keeper.length()
		# 进入"安全区 + 缓冲带"时施加斥力，越靠近越强（1/dist）
		if dist < keeper.safe_radius + 120.0 and dist > 0.001:
			direction += to_keeper.normalized() * (600.0 / dist)

	return direction
```

要点：
- 斥力从「安全区半径 + 120 缓冲」开始生效，敌人还没碰到边界就被往外推。
- 系数 `600.0` 是调参值：越大敌人越难贴近安全区，按手感调。
- 斥力方向 `to_keeper.normalized()` 是「远离老板」的单位向量，叠加进移动方向后，敌人会绕开老板。
- 更平滑、有界的实现与完整调参方法见 §14。

> 因为敌人「碰撞伤害」是靠 Hitbox 碰到玩家 Hurtbox，而敌人根本进不了安全区，所以玩家在安全区内不会挨打——无需额外禁用攻击。

---

## 5. 玩家：商店阶段软锁移动（可选）

商店 UI 打开时，玩家理论上还能动（因为没设 `game_paused`）。为避免玩家在全屏 UI 下乱走，给玩家加一个软锁：

`scenes/unit/players/player.gd:85` 的 `_process` 顶部：

```gdscript
func _process(delta: float) -> void:
	if Global.game_paused: return
	if Global.shop_phase: return      # ★ 商店阶段软锁：不处理移动/冲刺/技能输入
	# ... 原有移动/冲刺/动画逻辑不变 ...
```

> 这样：敌人持续移动（不受 shop_phase 影响），玩家在商店 UI 打开时暂时不能动；点「离开」关店后恢复移动，再走出安全区触发下一波（见 §8）。若你希望商店打开时玩家也能走动，可去掉这一行（见 §12 决策点 2）。

---

## 6. 商店老板生命周期

现状老板在每波开始刷出（`arena.gd:139`、`arena.gd:293`），波中可交互。本方案**保持波开始刷出**（这样波中才能找老板），并在 `spawn_shopkeeper()` 里写入全局引用：

`scenes/arena/arena.gd:301` 的 `spawn_shopkeeper()`，末尾加一行：

```gdscript
func spawn_shopkeeper() -> void:
	if is_instance_valid(shopkeeper):
		shopkeeper.queue_free()
	shopkeeper = SHOPKEEPER_SCENE.instantiate() as Shopkeeper
	add_child(shopkeeper)
	shopkeeper.global_position = get_random_shopkeeper_position()
	shopkeeper.on_interact.connect(_on_shopkeeper_interact)
	Global.shopkeeper = shopkeeper   # ★ 写入全局引用，供敌人读取安全区中心
```

> `get_random_shopkeeper_position()`（`arena.gd:318`）已保证老板离出生点足够远、每波位置不同，不用改。

---

## 7. 打开商店（波中找老板 / 波末，统一走这里）

把 `open_shop()`（`arena.gd:335`）改成**非暂停**的商店阶段入口：

```gdscript
func open_shop() -> void:
	Global.shop_phase = true              # ★ 进入商店阶段（不设 game_paused，敌人继续动）
	spawner.spawn_timer.stop()            # 停止刷怪
	spawner.wave_timer.stop()             # 停止波计时（避免商店阶段波又自然结束）
	shop_panel.load_shop(spawner.wave_index)
	shop_panel.show()
```

`_on_shopkeeper_interact()`（`arena.gd:347`）保持不变，仍调用 `open_shop()`。这样：

- **波中找老板**：玩家走近老板按交互键 → `open_shop()` → `shop_phase=true` → 离开安全区即跳过当前波。
- **波末**：见 §8，也是调 `open_shop()`。

> 因为 `open_shop` 里 `spawner.wave_timer.stop()`，波中找老板后本波不会再自然结束；下一波完全由「离开安全区」驱动。

---

## 8. 波末流程：瞬移 + 开商店（不清敌人）

### 8.1 Spawner 侧：只停刷怪、发信号

`scenes/arena/spawner.gd:220` 的 `_on_wave_timer_timeout()` 改为：

```gdscript
func _on_wave_timer_timeout() -> void:
	# ★ 不再 game_paused、不再 clear_enemies、不再 update_enemies_new_wave
	#   （收获结算与敌人成长都移到 Arena.start_new_wave 统一做）
	spawn_timer.stop()
	on_wave_completed.emit()   # → Arena 瞬移玩家 + 开商店
```

### 8.2 Arena 侧：收金币 → 瞬移 → 开商店

`scenes/arena/arena.gd:238` 的 `_on_spawner_on_wave_completed()` 改为：

```gdscript
func _on_spawner_on_wave_completed() -> void:
	if not Global.player: return
	collect_gold()                                        # 收金币（不再清敌人）
	Global.player.global_position = shopkeeper.global_position + Vector2(0, -120)  # 瞬移到老板安全区
	open_shop()                                           # 开商店（shop_phase=true）
```

把原来的 `clean_arena()` 拆出「只收金币」的 `collect_gold()`（`arena.gd:145` 处改造）：

```gdscript
## 只把场上金币吸向金币袋，不再清敌人（敌人保留、自由移动）。
func collect_gold() -> void:
	if gold_list.size() > 0:
		var target_center_pos := coins_bag.global_position + coins_bag.size / 2.0
		for gold in gold_list:
			if is_instance_valid(gold):
				(gold as Coins).set_collection_target(target_center_pos)
	gold_list.clear()
```

> 原来 `clean_arena()` 里的 `spawner.clear_enemies()` 被移除（符合「不清敌人」）。金币仍会自己飞向金币袋，无需暂停。

---

## 9. 面板合并与互切按钮（同 v1）

### 9.1 商店面板加「煅体」按钮（右上角）

`scenes/ui/shop_panel/shop_panel.tscn` 在 `MarginContainer/Control` 下加按钮：

```text
[node name="ForgeButton" type="Button" parent="MarginContainer/Control"]
layout_mode = 1
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -240.0
offset_top = 15.0
offset_right = -40.0
offset_bottom = 95.0
theme_override_font_sizes/font_size = 40
text = "煅体"
```

末尾加连接：

```text
[connection signal="pressed" from="MarginContainer/Control/ForgeButton" to="." method="_on_forge_button_pressed"]
```

`scenes/ui/shop_panel/shop_panel.gd` 加：

```gdscript
signal on_forge_pressed

func _on_forge_button_pressed() -> void:
	SoundManager.play_sound(SoundManager.Sound.UI)
	on_forge_pressed.emit()
```

### 9.2 升级面板加「商店」按钮（右下角）

`scenes/ui/upgrade_panel/upgrade_panel.tscn` 根节点下加：

```text
[node name="ShopButton" type="Button" parent="."]
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -240.0
offset_top = -110.0
offset_right = -40.0
offset_bottom = -30.0
theme_override_font_sizes/font_size = 40
text = "商店"
```

末尾加连接：

```text
[connection signal="pressed" from="ShopButton" to="." method="_on_shop_button_pressed"]
```

`scenes/ui/upgrade_panel/upgrade_panel.gd` 加：

```gdscript
signal on_shop_pressed

func _on_shop_button_pressed() -> void:
	SoundManager.play_sound(SoundManager.Sound.UI)
	on_shop_pressed.emit()
```

### 9.3 Arena 连接 + 切换

`Arena._ready`（`arena.gd:76`）连接，并新增两个回调：

```gdscript
shop_panel.on_forge_pressed.connect(_on_shop_panel_forge_pressed)
upgrade_panel.on_shop_pressed.connect(_on_upgrade_panel_shop_pressed)

func _on_shop_panel_forge_pressed() -> void:
	shop_panel.hide()
	upgrade_panel.load_upgrades(spawner.wave_index)
	upgrade_panel.show()

func _on_upgrade_panel_shop_pressed() -> void:
	upgrade_panel.hide()
	shop_panel.show()
```

### 9.4 选升级后返回商店

`Arena._on_upgrade_selected`（`arena.gd:220`）改为返回商店，不再触发下一波：

```gdscript
func _on_upgrade_selected() -> void:
	upgrade_panel.hide()
	shop_panel.show()      # ★ 返回商店；下一波由离开安全区触发
```

---

## 10. 「离开」按钮 + 离场检测 → 下一波

### 10.1 商店面板：把「next wave」改成「离开」

`scenes/ui/shop_panel/shop_panel.tscn:341` 的 `NewWaveButton`（文字 "next wave"）改成「离开」按钮（只关闭商店，不直接开波）：

```text
[node name="LeaveButton" type="Button" parent="MarginContainer/Control/VBoxContainer"]
...（样式沿用）
text = "离开"
```

连接改为：

```text
[connection signal="pressed" from="MarginContainer/Control/VBoxContainer/LeaveButton" to="." method="_on_leave_button_pressed"]
```

`scenes/ui/shop_panel/shop_panel.gd`：

```gdscript
signal on_shop_leave          # 替换原 on_shop_next_wave

func _on_leave_button_pressed() -> void:
	SoundManager.play_sound(SoundManager.Sound.UI)
	on_shop_leave.emit()       # → Arena 关闭商店、恢复玩家移动
```

`Arena` 连接并处理「离开」：

```gdscript
shop_panel.on_shop_leave.connect(_on_shop_leave)

func _on_shop_leave() -> void:
	shop_panel.hide()
	upgrade_panel.hide()
	# 注意：这里不 start_new_wave，也不复位 shop_phase；
	# 下一波由玩家走出安全区触发（见 10.2）。
```

### 10.2 离场检测

`Arena._process`（`arena.gd:90`）顶部加检测：

```gdscript
## 玩家离开老板安全区即触发下一波。
func _process(delta: float) -> void:
	if Global.game_paused: return

	# ★ 商店阶段：玩家一旦走出老板安全区 → 结束商店、开启下一波
	if Global.shop_phase and is_instance_valid(shopkeeper) and is_instance_valid(Global.player):
		if Global.player.global_position.distance_to(shopkeeper.global_position) > shopkeeper.safe_radius:
			start_new_wave()
			return

	# 原有 UI 刷新
	wave_index_label.text = spawner.get_wave_text()
	wave_time_label.text = spawner.get_wave_timer_text()
```

> 这里直接复用老板的 `safe_radius`（300），玩家走出安全区边界即触发。商店阶段 `game_paused=false`，所以这段每帧都会跑。

---

## 11. 收获结算与敌人成长的时机调整

原 `_on_wave_timer_timeout` 里的 `get_harvesting_coins()` 和 `update_enemies_new_wave()` 移到 `start_new_wave()`，让「自然波末」和「波中跳波」两条路径都只结算一次：

`scenes/arena/arena.gd:130` 的 `start_new_wave()`：

```gdscript
func start_new_wave() -> void:
	Global.shop_phase = false            # ★ 退出商店阶段
	Global.game_paused = false
	shop_panel.hide()
	upgrade_panel.hide()

	Global.get_harvesting_coins()        # ★ 本波收获结算（移到这里）
	spawner.update_enemies_new_wave()    # ★ 敌人按波成长（移到这里）
	Global.player.update_player_new_wave()

	spawner.wave_index += 1
	spawn_shopkeeper()                    # 下一波的新老板（新位置 + 新安全区）
	spawner.start_wave()
```

> 敌人**不清理**：旧波残留的敌人会继续在场，和新一波刷的敌人一起打（这是「不清除敌人」的自然结果，见 §12 决策点 4）。

---

## 12. 决策点（需你拍板）

1. **安全区半径与斥力强度**：`safe_radius=300`、斥力系数 `600.0` 是建议值，需按地图尺寸和手感调。老板 `interact_distance` 保持 120。
2. **商店打开时是否软锁玩家**：§5 默认软锁（`Player._process` 加 `shop_phase` 早退）。若想商店打开时玩家也能动（更自由），去掉那行即可——但玩家可能在满屏 UI 下误走。建议保留软锁。
3. **波末金币动画等待**：本方案去掉了原来的 `await 1 秒`（金币在后台自己飞向金币袋）。若你希望保留「等金币飞完再开商店」的节奏，可在 `_on_spawner_on_wave_completed` 里加回 `await get_tree().create_timer(1.0).timeout`（不影响敌人，敌人仍在动）。
4. **旧波残留敌人**：因为不清敌人，跳波后上一波敌人会和新波敌人叠加，越积越多。这是「不清除」的直接后果。若担心性能/难度膨胀，可在 `start_new_wave` 里只对「剩余敌人」做一次温和处理（如仅清掉血量极低者），但默认按你的要求「不清」。
5. **商店阶段武器是否停火**：敌人被安全区挡在外，但武器射程若够长仍可能远程打到安全区外的敌人。若希望商店阶段彻底和平，可在武器行为里加 `if Global.shop_phase: return`；否则保持现状（玩家可在安全区内远程清怪）。
6. **抽卡死循环（前置必修）**：点「煅体」会触发 `upgrade_panel.load_upgrades` → `select_items_for_offer`，若 `upgrade_list` 普通品质物品 < 4 会死循环卡死（原理见 `card_draw_probability.md` §7，完整兜底修复见本文 §13）。实现前请先保证 `upgrade_list` 数量充足或给 `select_items_for_offer` 加兜底。

---

## 13. select_items_for_offer 死循环兜底修复（前置必修）

`autoloads/global.gd:298` 的 `select_items_for_offer()` 目前有死循环风险：`while offered_items.size() < 4` 没有任何兜底，抽不满 4 个不重复物品就永远空转。两个触发条件：

1. 物品池总数 < 4。
2. 某品质（尤其第一波的普通）物品数 < 4，且这些物品都被抽过了——此时 `potential_items` **非空**（所以降级回退不触发），但 `pick_random()` 一直抽到重复项、`has()` 恒为 true，永不 append。

修复（三处兜底）：

```gdscript
func select_items_for_offer(item_pool: Array, current_wave: int, config: Dictionary) -> Array:
	var tier_chances := calculate_tier_probability(current_wave, config)
	var legendary_limit = tier_chances[3]
	var epic_limit = legendary_limit + tier_chances[2]
	var rare_limit = epic_limit + tier_chances[1]

	var offered_items: Array = []
	# ★ 兜底 1：目标数量不超过池子里实际能提供的不同物品数
	var target_count := mini(4, item_pool.size())
	# ★ 兜底 2：最多尝试 target_count * 20 次，任何意外都不会死循环
	var max_attempts := target_count * 20

	while offered_items.size() < target_count and max_attempts > 0:
		max_attempts -= 1
		var roll := randf()
		var chosen_tier_index := 0
		if roll < legendary_limit:
			chosen_tier_index = 3
		elif roll < epic_limit:
			chosen_tier_index = 2
		elif roll < rare_limit:
			chosen_tier_index = 1

		var potential_items: Array = []
		var current_search_tier_index := chosen_tier_index
		while potential_items.is_empty() and current_search_tier_index >= 0:
			# ★ 兜底 3：过滤时排除已选过的物品，让"降级回退"在
			#    "该品质已抽完"时也能继续往低品质找
			potential_items = item_pool.filter(func(item: ItemBase):
				return item.item_tier == current_search_tier_index and not offered_items.has(item))
			if potential_items.is_empty():
				current_search_tier_index -= 1
			else:
				break

		if not potential_items.is_empty():
			offered_items.append(potential_items.pick_random())

	return offered_items
```

改动说明：

| 兜底 | 改什么 | 修掉哪个问题 |
| --- | --- | --- |
| 1 `target_count` | 上限从写死 `4` 改成 `mini(4, 池子大小)` | 池子 < 4 时永不凑满 → 死循环 |
| 2 `max_attempts` | 加尝试次数上限 | 兜底保险，任何意外都 break |
| 3 `filter` 排除已选 | `filter` 里加 `not offered_items.has(item)` | 该品质已抽完但非空 → 降级不触发 → 空转 |

关键点：原「降级回退」只在 `potential_items.is_empty()`（该品质**一个都没有**）时触发；加上「排除已选」后，该品质的**未选物品**被抽空也会让 `potential_items` 变空，从而正确降到低品质——这是根治触发条件 2 的关键。

> `mini(4, x)` 是 Godot 4 的整数 min；两侧都是 int 时 `min(4, item_pool.size())` 效果相同。

---

## 14. 安全区斥力：调参详解

### 14.1 推荐实现（有界线性衰减，防抖）

§4.2 里的 `600.0 / dist` 是 `1/dist` 衰减，越靠近老板力越大，接近 `dist→0` 时会爆炸、贴脸被瞬间弹飞，容易在边界抖动。推荐改成**有界线性衰减**：

`scenes/unit/enemy/enemy.gd` 顶部加导出参数：

```gdscript
## 安全区斥力峰值（相对追击速度的倍率）。越大敌人越难靠近老板。
@export var safe_zone_push_strength := 6.0
## 在安全区半径之外、提前多少像素开始往外推（缓冲带）。
@export var safe_zone_buffer := 120.0
```

`get_move_direction()` 里的斥力段改为：

```gdscript
	if is_instance_valid(Global.shopkeeper):
		var keeper := Global.shopkeeper
		var to_keeper := global_position - keeper.global_position   # 从老板指向自己
		var dist := to_keeper.length()
		var limit := keeper.safe_radius + safe_zone_buffer          # 斥力生效边界
		if dist < limit and dist > 0.001:
			# t：0（刚进入缓冲带）→ 1（贴到老板）；斥力从 0 平滑升到峰值
			var t := 1.0 - (dist / limit)
			direction += to_keeper.normalized() * (safe_zone_push_strength * t)
```

### 14.2 三个旋钮

| 参数 | 默认 | 作用 | 调大后果 |
| --- | --- | --- | --- |
| `Shopkeeper.safe_radius` | 300 | 安全区半径 | 敌人离老板更远 |
| `safe_zone_push_strength` | 6.0 | 斥力峰值倍率 | 敌人更早、更用力被推离 |
| `safe_zone_buffer` | 120 | 缓冲带宽度 | 斥力更早生效、过渡更平滑 |

### 14.3 平衡点估算

敌人每帧净移动 ≈（朝玩家的追击力 ≈ 1）+（安全区斥力）。两者相等处即敌人游走的平衡距离。

以默认值为例（`safe_radius=300`、`buffer=120`、`limit=420`、`strength=6`）：
- 平衡时 `t = 1 / 6 ≈ 0.167` → `dist / limit ≈ 0.833` → `dist ≈ 350`。
- 敌人会停在离老板约 350 处，**正好在安全区 300 之外**，进不来。

### 14.4 调参表（症状 → 处理）

| 症状 | 处理 |
| --- | --- |
| 敌人还是挤进了安全区 | 加大 `safe_zone_push_strength`（8~10），或加大 `safe_radius` |
| 敌人在边界来回抖、抽风 | 减小 `safe_zone_push_strength`，或加大 `safe_zone_buffer` 让过渡平缓 |
| 敌人被推得太远、像逃窜 | 减小 `safe_zone_push_strength`（3~4） |
| 玩家在安全区边缘仍被打到 | 检查 `safe_radius` 是否小于武器/敌人碰撞半径，适当加大 `safe_radius` |

> 提示：玩家站在老板「对面」时，追击方向正好穿过安全区、与斥力反向，是最吃斥力的情形——以这个位置为基准调参，保证它进不来即可，其余方向自然没问题。

---

## 15. 修改文件清单

**修改：**
```
autoloads/global.gd                        # §2：shop_phase + shopkeeper 引用
scenes/unit/Shopkeeper/shopkeeper.gd       # §3：safe_radius
scenes/unit/enemy/enemy.gd                 # §4/§14：get_move_direction 加安全区斥力（+导出参数）
scenes/unit/players/player.gd              # §5：shop_phase 软锁（可选）
scenes/arena/arena.gd                      # §6/7/8/9/10/11：open_shop、波末、start_new_wave、离场检测、按钮回调
scenes/arena/spawner.gd                    # §8/11：波末只停刷怪+发信号
scenes/ui/shop_panel/shop_panel.gd         # §9/10：on_forge_pressed / on_shop_leave 信号
scenes/ui/shop_panel/shop_panel.tscn       # §9/10：ForgeButton、LeaveButton + 连接
scenes/ui/upgrade_panel/upgrade_panel.gd   # §9：on_shop_pressed 信号
scenes/ui/upgrade_panel/upgrade_panel.tscn # §9：ShopButton + 连接
```

**不变：**
```
scenes/ui/upgrade_card/*                   # 升级卡显示/点击不变
autoloads/global.gd 的 select_items_for_offer / calculate_tier_probability  # 抽卡不变
scenes/ui/shop_card/*                      # 商品卡不变
```

---

## 16. 验证清单

- [ ] 敌人从波开始到波末**全程移动**，从未被冻结；接近老板时被安全区斥力挡开，进不了安全区。
- [ ] 玩家在老板安全区内不会被敌人攻击。
- [ ] 波中走进老板、按交互键 → 商店打开，右上角有「煅体」按钮；点「煅体」→ 升级面板（右下角有「商店」按钮），点「商店」→ 返回商店。
- [ ] 商店里点「离开」→ 商店关闭、玩家恢复移动；**不立即开波**。
- [ ] 玩家走出老板安全区 → 商店关闭、下一波开始（波数 +1、刷新老板、收获结算、敌人成长）。
- [ ] 波中找老板（无论是否购买）→ 离开安全区 → 当前波被跳过、直接进下一波。
- [ ] 自然波末：波计时到 → 玩家瞬移到老板安全区 → 商店打开 → 离开安全区 → 下一波。
- [ ] 多次循环（波 1→2→3）正常，无死循环、敌人不被清除、金币结算正常。
- [ ] 旧波残留敌人与新波敌人并存（符合「不清除」），性能可接受。

---

## 附：关键时序（文本）

```
波开始：Arena.start_new_wave
  → shop_phase=false、收金币、敌人成长、玩家成长、wave_index+1、刷新老板(Global.shopkeeper)、开波
波中：敌人追玩家，但被安全区斥力挡在老板外
  玩家走近老板按交互键 → Arena.open_shop（shop_phase=true、停刷怪/波计时、开商店）
     ├─ 点「煅体」→ 切升级面板；选升级 → 返回商店；点「商店」→ 返回商店
     └─ 点「离开」→ 关商店、恢复移动
  玩家走出安全区 → Arena._process 检测距离 > safe_radius → start_new_wave（下一波）

自然波末：WaveTimer 超时
  → Spawner._on_wave_timer_timeout（停刷怪、发信号，不清敌人）
  → Arena._on_spawner_on_wave_completed（收金币 → 瞬移玩家到老板安全区 → open_shop）
  → 同上面的「离开安全区 → 下一波」
```
