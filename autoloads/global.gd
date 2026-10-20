extends Node
## =============================================================================
## Global（全局单例 / Autoload）
## -----------------------------------------------------------------------------
## 作用：作为整个游戏的全局状态中枢与事件总线。它集中保存了
##   - 全局信号（用于跨场景/跨节点解耦通信）
##   - 预加载的公共资源（材质、场景、样式、颜色、概率配置、可选角色）
##   - 游戏运行时状态（金币、玩家引用、暂停状态、已选角色/武器、已装备武器）
##   - 与"随机掉落 / 商店 / 升级"相关的概率计算工具方法
## 它被设置为 Autoload，因此任何脚本都可以直接通过 `Global.xxx` 访问。
## =============================================================================


## ---------------------------------------------------------------------------
## 全局信号（事件总线）
## ---------------------------------------------------------------------------

## 信号：请求生成"格挡"浮动文字。
## 参数 unit：发生格挡的单位（Node2D）。由 Unit._on_hurtbox_component_on_damaged 发出。
signal on_create_block_text(unit: Node2D)

## 信号：请求生成"伤害"浮动文字。
## 参数 unit：受击单位；hitbox：造成伤害的碰撞盒（携带伤害值/是否暴击）。
## 由 Unit._on_hurtbox_component_on_damaged 发出。
signal on_create_damage_text(unit: Node2D, hitbox: HitboxComponent)

## 信号：请求生成"治疗"浮动文字。
## 参数 unit：被治疗单位；heal：治疗量。由 Player._on_hp_regen_timer_timeout /
## WeaponBehavior.apply_life_steal 发出。
signal on_create_heal_text(unit: Node2D, heal: float)

## 信号：玩家选择了一个升级。由 UpgradeCard._on_custom_buttom_pressed 发出。
signal on_upgrade_selected

## 信号：敌人死亡。参数 enemy：死亡的敌人。由 Enemy._on_health_component_on_unit_died 发出。
signal on_enemy_died(enemy: Enemy)


## ---------------------------------------------------------------------------
## 预加载常量（通过 UID 引用场景 / 资源）
## ---------------------------------------------------------------------------

## 受击闪烁用的 ShaderMaterial（ShaderMaterial）。
const FLASH_MATERIAL = preload("uid://coi4nu8ohpgeo")

## 浮动文字场景（FloatingText）。由 Arena.create_floating_text 实例化。
const FLOATING_TEXT_SCENE = preload("uid://bmy2qb3fuvnts")

## 金币场景（Coins）。由 Arena.spawn_coins 实例化。
const COINS_SCENE = preload("uid://c0gxgyeg3phog")

## 物品卡片场景（ItemCard，用于背包/武器/被动栏展示）。由 ShopPanel.create_item_card 实例化。
const ITEM_CARD_SCENE = preload("uid://d4ahqxku4821t")

## 选择卡片场景（SelectionCard，用于角色/初始武器选择）。由 SelectionPanel 实例化。
const SELECTION_CARD_SCENE = preload("uid://dnablojs1s8")

## 敌人出生特效场景（EnemySpawnEffect）。由 Spawner.spawn_enemy 实例化。
const SPAWN_EFFECT_SCENE = preload("uid://bghlbhbjte68a")


## ---------------------------------------------------------------------------
## 品质（UpgradeTier）对应的 StyleBoxFlat 样式（用于卡片边框着色）
## ---------------------------------------------------------------------------

## 普通品质样式（COMMON）。
const COMMON_STYLE = preload("uid://dn43vff5bgab1")

## 史诗品质样式（EPIC）。
const EPIC_STYLE = preload("uid://chxsktowv55wp")

## 传说品质样式（LEGENDARY）。
const LEGENDARY_STYLE = preload("uid://omjdrwevlaw8")

## 稀有品质样式（RARE）。
const RARE_STYLE = preload("uid://cu7iu2w861ga4")


## ---------------------------------------------------------------------------
## 概率配置常量
## ---------------------------------------------------------------------------
## 说明：品质概率按波数线性增长，`start_wave` 表示从第几波开始出现，
## `base_multi` 表示每过一波概率增加的基础倍率。最终会被玩家幸运值放大。

## 升级（Upgrade）奖励的品质概率配置。
const UPGRADE_PROBABILITY_CONFIG = {
	"rare": { "start_wave": 2, "base_multi": 0.06 },
	"epic": { "start_wave": 4, "base_multi": 0.02 },
	"legendary": { "start_wave": 7, "base_multi": 0.0023 },
}

## 商店（Shop）商品的品质概率配置。
const SHOP_PROBABILITY_CONFIG = {
	"rare": { "start_wave": 2, "base_multi": 0.10 },
	"epic": { "start_wave": 4, "base_multi": 0.06 },
	"legendary": { "start_wave": 7, "base_multi": 0.01 },
}


## ---------------------------------------------------------------------------
## 品质 → 描边颜色 映射（用于武器轮廓着色）
## ---------------------------------------------------------------------------
## 键为 UpgradeTier 枚举，值为对应描边颜色。由 Weapon.apply_tier_outline 使用。
const TIER_COLORS: Dictionary[UpgradeTier, Color] = {
	UpgradeTier.RARE: Color(0.0, 0.557, 0.741),
	UpgradeTier.EPIC: Color(0.478, 0.251, 0.71),
	UpgradeTier.LEGENDARY: Color(0.906, 0.212, 0.212),
}


## ---------------------------------------------------------------------------
## 运行时变量
## ---------------------------------------------------------------------------

## 可选角色字典：角色名（String）→ 角色场景（PackedScene）。
## 由 get_selected_player 根据 main_player_selected.name 取用。
var available_players: Dictionary[String, PackedScene] = {
	"Brawler": preload("uid://b6emn4n6ogmg8"),
	"Bunny": preload("uid://dx5yb8804ik6x"),
	"Crazy": preload("uid://dkjqu0ys4k662"),
	"Knight": preload("uid://cecw4o0onlxq8"),
	"Well Rounded": preload("uid://bwo04frw2wqoy"),
}

## 品质枚举：COMMON(普通) / RARE(稀有) / EPIC(史诗) / LEGENDARY(传说)。
## 用于物品（ItemBase.item_tier）、概率计算与样式着色。
enum UpgradeTier{
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

## 玩家当前拥有的金币总数。由 Coins.add_coins、ShopCard._on_buy_buttom_pressed、
## ShopPanel._on_sell_button_pressed 等读写。
var coins: int = 500

## 当前玩家实例的引用（Player）。在 get_selected_player 中赋值。
var player: Player

## 游戏是否暂停（用于波次结算/商店/升级界面时冻结战斗）。
var game_paused := false

## 玩家在角色选择界面选中的角色数据（UnitStats）。由 SelectionPanel._on_player_selected 赋值。
var main_player_selected: UnitStats

## 玩家在角色选择界面选中的初始武器（ItemWeapon）。由 SelectionPanel._on_weapon_selected 赋值。
var main_weapon_selected: ItemWeapon

## 当前已装备的武器数据列表（Array[ItemWeapon]）。
## 由 ShopPanel / Arena 在装备、购买、合成、出售武器时维护。
var equipped_weapons: Array[ItemWeapon]


## ---------------------------------------------------------------------------
## 方法
## ---------------------------------------------------------------------------

## 函数说明：结算"收获"阶段，将玩家 stats.harvesting（收获值）累加到全局金币。
## 被谁调用：Spawner._on_wave_timer_timeout（每波计时结束、进入结算时）。
## 调用了：无（仅直接读写 Global.coins 与玩家属性）。
func get_harvesting_coins() -> void:
	# player.stats.harvesting 是玩家的"收获"属性（每波结束结算的金币数）；
	# 用 += 把它累加到全局金币 coins 上，完成本波收获结算。
	coins += player.stats.harvesting


## 函数说明：根据已选角色名实例化对应的玩家场景，并保存到 Global.player 后返回。
## 被谁调用：Arena._on_selection_panel_on_selection_completed。
## 调用了：available_players 字典查找、PackedScene.instantiate()。
func get_selected_player() -> Player:
	# 用已选角色名 main_player_selected.name 作为键，从 available_players 字典
	# 取出对应的角色场景 PackedScene（若名字不存在会报错并返回 null）。
	var player_scene := available_players[main_player_selected.name]
	# instantiate() 把 PackedScene 实例化为实际的 Player 节点（尚未加入场景树）。
	var player_instance := player_scene.instantiate()
	# 把实例保存到全局引用 Global.player，供其它脚本访问。
	player = player_instance
	# 返回该玩家实例，由调用方（Arena）把它 add_child 到场景中。
	return player


## 函数说明：进行概率判定，返回"是否成功"。生成 [0,1) 随机数，小于给定概率即成功。
## 被谁调用：
##   - Unit._on_hurtbox_component_on_damaged（格挡概率判定）
##   - WeaponBehavior.get_damage（暴击概率判定）
##   - WeaponBehavior.apply_life_steal（吸血概率判定）
## 调用了：randf_range()。
func get_chance_sucess(chance: float) -> bool:
	# randf_range(0, 1.0) 生成一个 [0, 1.0) 区间内均匀分布的随机浮点数，
	# 用它模拟一次"掷骰"，作为本次判定的随机基准。
	var random := randf_range(0, 1.0)
	# 若随机数小于给定概率 chance，则视为判定成功，返回 true。
	if random < chance:
		return true
	# 否则判定失败，返回 false。
	return false


## 函数说明：根据品质枚举返回对应的 StyleBoxFlat 样式（用于卡片边框）。
## 被谁调用：
##   - ItemCard._set_item
##   - ShopCard._set_shop_item
##   - UpgradeCard._set_data
## 调用了：无（仅 match 分支返回对应常量）。
func get_tier_style(tier: UpgradeTier) -> StyleBoxFlat:
	# match 相当于多分支 switch，按传入的品质枚举 tier 匹配不同的常量样式：
	match tier:
		# 普通品质返回 COMMON_STYLE（普通边框样式）。
		UpgradeTier.COMMON:
			return COMMON_STYLE
		# 稀有品质返回 RARE_STYLE。
		UpgradeTier.RARE:
			return RARE_STYLE
		# 史诗品质返回 EPIC_STYLE。
		UpgradeTier.EPIC:
			return EPIC_STYLE
		# `_` 是通配分支，匹配其余值（此处即 LEGENDARY），返回传说样式。
		_:
			return LEGENDARY_STYLE


## 函数说明：根据当前波数与配置，计算四种品质（普通/稀有/史诗/传说）的出现概率数组。
## 被谁调用：select_items_for_offer。
## 调用了：Global.player.stats.luck、print()。
func calculate_tier_probability(current_wave: int, config: Dictionary) -> Array[float]:
	# 四个品质的初始概率都置 0，后续按条件累加。
	var common_chance := 0.0
	var rare_chance := 0.0
	var epic_chance := 0.0
	var legendary_chance := 0.0

	# RARE: Starts increasing from wave 2 (0% at wave 1)
	# 若当前波数 >= 稀有品质的 start_wave（2），说明稀有开始出现。
	if current_wave >= config.rare.start_wave:
		# 稀有概率 = (波数-1) * base_multi，随波数线性增长；
		# min(1.0, x) 把结果上限截断为 1.0（概率不能超过 100%）。
		rare_chance = min(1.0, (current_wave - 1) * config.rare.base_multi)

	# EPIC: Starts increasing from wave 4 (0% at wave 3)
	# 史诗品质从第 4 波开始出现，概率 = (波数-3) * base_multi，同样上限 1.0。
	if current_wave >= config.epic.start_wave:
		epic_chance = min(1.0, (current_wave - 3) * config.epic.base_multi)

	# LEGENDARY: Starts increasing from wave 7 (0% at wave 6)
	# 传说品质从第 7 波开始出现，概率 = (波数-6) * base_multi，上限 1.0。
	if current_wave >= config.legendary.start_wave:
		legendary_chance = min(1.0, (current_wave - 6) * config.legendary.base_multi)

	# Player luck increases the chance of finding higher tiers.
	# Example: 10 luck = 10% chance = 1.1 multi
	# 玩家幸运值会放大高稀有度概率：luck/100 作为加值，例如 10 点幸运 → 1.1 倍。
	# Global.player.stats.luck 读取玩家当前的幸运属性。
	var luck_factor := 1.0 + (Global.player.stats.luck / 100.0)
	# 用幸运倍率放大稀有/史诗/传说三种非普通品质的概率。
	rare_chance *= luck_factor
	epic_chance *= luck_factor
	legendary_chance *= luck_factor

	# Normalize probabilities
	# 计算三种非普通品质概率之和，用于后续归一化。
	var total_non_common_chances := rare_chance + epic_chance + legendary_chance
	# 若总和非普通概率超过 1.0（因幸运放大导致），需要等比缩放回 1.0，
	# 保证所有概率之和恰好等于 1（100%）。
	if total_non_common_chances > 1.0:
		# 缩放系数 = 1 / 总和，用乘法等比缩小每个概率。
		var scale_down := 1.0 / total_non_common_chances
		rare_chance *= scale_down
		epic_chance *= scale_down
		legendary_chance *= scale_down
		# 缩放后总和即为 1.0。
		total_non_common_chances = 1.0

	# Common takes the remaining probability
	# 普通品质占据剩余的概率（1 - 非普通概率总和）。
	common_chance = 1.0 - total_non_common_chances

	# Debug print
	# print() 输出调试信息；%d/%f/%.1f/%.2f 是格式化占位符，分别对应整数、
	# 浮点、保留 1 位/2 位小数的浮点，由后面的数组依次填充。
	print("Wave: %d, Luck: %.1f => Chances: C:%.2f R:%.2f E:%.2f L:%.2f" %
	[current_wave, Global.player.stats.luck, common_chance, rare_chance, epic_chance, legendary_chance])

	# 返回 [普通, 稀有, 史诗, 传说] 四个概率；max(0.0, x) 保证每个值不为负数。
	return [
		max(0.0, common_chance),
		max(0.0, rare_chance),
		max(0.0, epic_chance),
		max(0.0, legendary_chance),
	]


## 函数说明：从物品池中按品质概率随机挑选最多 4 个不重复的物品作为本次 offer。
## 被谁调用：
##   - ShopPanel.load_shop（商店）
##   - UpgradePanel.load_upgrades（升级奖励）
## 调用了：calculate_tier_probability、randf()、item_pool.filter()、pick_random()。
func select_items_for_offer(item_pool: Array, current_wave: int, config: Dictionary) -> Array:

	# [ 0.7 , 0.2 , 0.08 , 0.02 ]
	# 先调用 calculate_tier_probability 得到四种品质的概率数组 [普通, 稀有, 史诗, 传说]。
	var tier_chances := calculate_tier_probability(current_wave, config)

	# 三个累计阈值用于把 randf() 的 [0,1) 随机数映射到某个品质区间：
	# legendary_limit：roll 小于它 → 传说（区间 [0, 传说概率)）。
	var legendary_limit = tier_chances[3]
	# epic_limit：roll 小于它且 >= legendary_limit → 史诗（区间 [传说, 传说+史诗)）。
	var epic_limit = legendary_limit + tier_chances[2]
	# rare_limit：roll 小于它且 >= epic_limit → 稀有（区间 [传说+史诗, 传说+史诗+稀有)）。
	var rare_limit = epic_limit + tier_chances[1]

	# offered_items 存放最终选出的物品，初始为空。
	var offered_items: Array = []
	# 循环直到凑满 4 个物品。
	while offered_items.size() < 4:
		# randf() 生成 [0,1) 随机浮点数，用于确定本次抽到的品质。
		var roll := randf()
		# chosen_tier_index 默认 0（普通品质）。
		var chosen_tier_index := 0
		# 按 roll 落入的累计区间确定目标品质的枚举索引（3=传说, 2=史诗, 1=稀有）。
		if roll < legendary_limit:
			chosen_tier_index = 3 # Legendary
		elif roll < epic_limit:
			chosen_tier_index = 2 # Epic
		elif roll < rare_limit:
			chosen_tier_index = 1 # Rare
		# 若 roll 落在 rare_limit 之上，则保持 0（普通），无需额外分支。

		# potential_items 存放目标品质下可选的物品。
		var potential_items: Array = []
		# current_search_tier_index 记录当前实际检索的品质，从目标品质开始。
		var current_search_tier_index := chosen_tier_index

		# 若目标品质没有可选物品，就逐级向下（传说明 → 普通）回退搜索，
		# 保证一定能选出物品（最坏退到普通）。
		while potential_items.is_empty() and current_search_tier_index >= 0:
			# filter() 返回 item_pool 中满足条件的子数组；这里的 lambda 匿名函数
			# `func(item): return item.item_tier == current_search_tier_index`
			# 用于筛选出 item_tier 等于当前检索品质的所有物品。
			potential_items = item_pool.filter(func(item: ItemBase): return item.item_tier == current_search_tier_index)

			# 若该品质仍为空，品质索引 -1 继续向更低品质搜索。
			if potential_items.is_empty():
				current_search_tier_index -= 1
			else:
				# 找到非空候选则跳出循环。
				break

		# 若有可用候选物品。
		if not potential_items.is_empty():
			# pick_random() 从候选数组中随机返回一个物品。
			var selected_item = potential_items.pick_random()

			# has() 判断该物品是否已被选过，避免重复；未选过才加入结果。
			if not offered_items.has(selected_item):
				offered_items.append(selected_item)

	# 返回选出的最多 4 个物品（若物品池太小可能不足 4 个）。
	return offered_items
