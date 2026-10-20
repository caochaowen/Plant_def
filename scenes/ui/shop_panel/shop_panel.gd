extends Panel
class_name ShopPanel
## =============================================================================
## ShopPanel（商店面板 / Panel）
## -----------------------------------------------------------------------------
## 作用：波次之间的商店界面。负责：
##   - 按品质概率生成商品列表（load_shop）；
##   - 处理购买（武器入背包、被动直接生效）；
##   - 处理武器选中后的合成（两把同类合成为 upgrade_to）与出售；
##   - 发出 on_shop_next_wave 信号进入下一波。
## =============================================================================


## 信号：玩家点击"下一波"。连接到 Arena._on_shop_panel_on_shop_next_wave。
signal on_shop_next_wave


## 商店卡片场景（ShopCard）预加载。
const SHOP_CARD_SCENE = preload("uid://csmrkxii0a74i")


## ---------------------------------------------------------------------------
## 导出字段
## ---------------------------------------------------------------------------

## 商店可出售的全部物品池（ItemBase 数组）。
@export var shop_items: Array[ItemBase]


## ---------------------------------------------------------------------------
## 节点引用
## ---------------------------------------------------------------------------

## 商店商品卡片容器（HBoxContainer）。
@onready var items_container: HBoxContainer = %ItemsContainer

## 被动道具栏容器（GridContainer）。
@onready var passives_container: GridContainer = %PassivesContainer

## 武器栏容器（GridContainer）。
@onready var weapons_container: GridContainer = %WeaponsContainer

## 合成按钮（Button）。
@onready var combine_button: Button = %CombineButton


## ---------------------------------------------------------------------------
## 运行时变量
## ---------------------------------------------------------------------------

## 当前选中的武器卡片（ItemCard），用于合成/出售操作目标。
var context_card: ItemCard


## 函数说明：就绪时清空被动栏与武器栏。
## 被谁调用：由 Godot 引擎在节点进入场景树时调用。
## 调用了：无（直接遍历 queue_free）。
func _ready() -> void:
	# 清空被动栏与武器栏所有子节点。
	for child in passives_container.get_children(): child.queue_free()
	for child in weapons_container.get_children(): child.queue_free()


## 函数说明：根据当前波数与概率配置生成商店商品。
## 被谁调用：Arena._on_upgrade_selected（升级选择后）。
## 调用了：Global.select_items_for_offer()、SHOP_CARD_SCENE.instantiate()。
func load_shop(current_wave: int) -> void:
	# 先清空商品容器旧内容。
	for child in items_container.get_children(): child.queue_free()

	# 用商店概率配置从物品池随机选 4 个商品（Global.select_items_for_offer）。
	var config := Global.SHOP_PROBABILITY_CONFIG
	var selected_items := Global.select_items_for_offer(shop_items, current_wave, config)
	# 为每个选中的商品生成一张商品卡片。
	for shop_item : ItemBase in selected_items:
		# 实例化 ShopCard。
		var card_instance := SHOP_CARD_SCENE.instantiate() as ShopCard
		# 连接该卡片的购买信号到 _on_item_purchased。
		card_instance.on_item_purchased.connect(_on_item_purchased)
		# 加入商品容器，并赋值 shop_item（触发 setter 刷新显示）。
		items_container.add_child(card_instance)
		card_instance.shop_item = shop_item


## 函数说明：创建并返回一个 ItemCard，并连接其选中信号。
## 被谁调用：create_item_weapon、_on_item_purchased、_on_combine_button_pressed。
## 调用了：Global.ITEM_CARD_SCENE.instantiate()。
func create_item_card() -> ItemCard:
	# 实例化物品卡片（ItemCard）。
	var item_card := Global.ITEM_CARD_SCENE.instantiate() as ItemCard
	# 连接卡片选中信号到 _on_item_card_selected（用于合成/出售的选中状态）。
	item_card.on_item_card_selected.connect(_on_item_card_selected)
	# 返回卡片，由调用方决定加入哪个容器并设置 item。
	return item_card


## 函数说明：在武器栏创建一把武器的 ItemCard。
## 被谁调用：Arena._on_selection_panel_on_selection_completed（装配初始武器时）。
## 调用了：create_item_card()。
func create_item_weapon(weapon: ItemWeapon) -> void:
	# 创建一张物品卡片。
	var card := create_item_card()
	# 加入武器栏容器。
	weapons_container.add_child(card)
	# 设置卡片 item（触发 setter 刷新图标与品质边框）。
	card.item = weapon


## 函数说明："下一波"按钮回调，发出进入下一波信号。
## 被谁调用：由"下一波"按钮的 pressed 信号触发。
## 调用了：SoundManager.play_sound()、on_shop_next_wave.emit()。
func _on_new_wave_button_pressed() -> void:
	# 播放 UI 音效。
	SoundManager.play_sound(SoundManager.Sound.UI)
	# 发出进入下一波信号（Arena 收到后隐藏商店并 start_new_wave）。
	on_shop_next_wave.emit()


## 函数说明：商品购买回调，按类型处理武器/被动道具。
## 被谁调用：由 ShopCard.on_item_purchased 信号触发。
## 调用了：create_item_card()、Global.player.add_weapon()、passive.apply_passive()。
func _on_item_purchased(item: ItemBase) -> void:
	# 为购买的物品创建一张物品卡片（将显示在武器栏或被动栏）。
	var item_card := create_item_card()

	# 若购买的是武器。
	if item.item_type == ItemBase.ItemType.WEAPON:
		# 卡片加入武器栏。
		weapons_container.add_child(item_card)
		# `as ItemWeapon` 转型为武器类型。
		var weapon := item as ItemWeapon
		# 装配到玩家并加入全局已装备武器列表。
		Global.player.add_weapon(weapon)
		Global.equipped_weapons.append(weapon)

	# 若购买的是被动道具。
	elif item.item_type == ItemBase.ItemType.PASSIVE:
		# 卡片加入被动栏。
		passives_container.add_child(item_card)
		# 转型为被动道具并立即 apply_passive() 把效果应用到玩家属性。
		var passive := item as ItemPassive
		passive.apply_passive()

	# 设置卡片 item（显示图标）。
	item_card.item = item


## 函数说明：武器卡片选中回调，判断是否可合成并更新合成按钮状态。
## 被谁调用：由 ItemCard.on_item_card_selected 信号触发。
## 调用了：无（遍历 Global.equipped_weapons 计数）。
func _on_item_card_selected(card: ItemCard) -> void:
	# 记录当前选中的卡片，供合成/出售使用。
	context_card = card

	# 先假设不可合成。
	var can_merge := false
	# 只有武器才可能合成。
	if card.item.item_type == ItemBase.ItemType.WEAPON:
		# 统计已装备武器中与选中武器同名的数量。
		var count := 0
		for weapon: ItemWeapon in Global.equipped_weapons:
			if weapon.item_name == card.item.item_name:
				count += 1

		# 同名武器 ≥2 把即可合成。
		if count >= 2:
			can_merge = true

	# 根据能否合成设置合成按钮的 disabled 状态（不可合成则置灰）。
	combine_button.disabled = not can_merge


## 函数说明：合成按钮回调，把两把同名武器合成为升级武器。
## 被谁调用：由合成按钮的 pressed 信号触发。
## 调用了：SoundManager.play_sound()、load()、Global.player.add_weapon()、create_item_card()。
func _on_combine_button_pressed() -> void:
	# 播放 UI 音效。
	SoundManager.play_sound(SoundManager.Sound.UI)

	# 若无选中卡片，返回。
	if not context_card:
		return

	# 取出选中的武器。
	var clicked_weapon := context_card.item as ItemWeapon
	# 若该武器没有升级目标（upgrade_to 为空），无法合成，返回。
	if not clicked_weapon.upgrade_to:
		return

	# filter(func) 用 lambda 筛选出玩家当前武器列表中与选中武器同名的武器，
	# slice(0, 2) 取前 2 把（合成需要消耗 2 把）。
	var weapons_to_remove: Array[Weapon] = Global.player.current_weapons.filter(func(w: Weapon):
		return w.data.item_name == clicked_weapon.item_name).slice(0, 2)

	# 同理筛选武器栏中同名卡片的前 2 张。
	var card_to_remove = weapons_container.get_children().filter(func(c: ItemCard):
		return c.item.item_name == clicked_weapon.item_name).slice(0, 2)

	# 若不足 2 把武器或 2 张卡片，条件不满足，返回。
	if weapons_to_remove.size() < 2 or card_to_remove.size() < 2:
		return

	# Delete weapons
	# 删除这 2 把武器：从玩家当前武器列表、全局装备列表移除，并释放节点。
	for weapon: Weapon in weapons_to_remove:
		Global.player.current_weapons.erase(weapon)
		Global.equipped_weapons.erase(weapon.data)
		weapon.queue_free()

	# Delete cards
	# 删除对应的 2 张卡片。
	for card: ItemCard in card_to_remove:
		card.queue_free()

	# Create new Weapon
	# load(resource_path) 用升级目标的资源路径加载 ItemWeapon 资源（新建独立实例）。
	var upgraded_weapon: ItemWeapon = load(clicked_weapon.upgrade_to.resource_path)
	# 装配升级武器并加入全局装备列表。
	Global.player.add_weapon(upgraded_weapon)
	Global.equipped_weapons.append(upgraded_weapon)

	# Create new Item Card
	# 创建新卡片显示升级后的武器。
	var new_card := create_item_card()
	weapons_container.add_child(new_card)
	new_card.item = upgraded_weapon

	# 清空选中状态。
	context_card = null


## 函数说明：出售按钮回调，以 75% 价格卖出选中的武器。
## 被谁调用：由出售按钮的 pressed 信号触发。
## 调用了：SoundManager.play_sound()、queue_free()。
func _on_sell_button_pressed() -> void:
	# 播放 UI 音效。
	SoundManager.play_sound(SoundManager.Sound.UI)

	# 若无选中卡片，返回。
	if not context_card:
		return

	# 取出选中的武器，售价 = 原价 × 0.75。
	var clicked_weapon := context_card.item as ItemWeapon
	var coins := clicked_weapon.item_cost * 0.75

	# 在玩家当前武器中筛出同名武器的第一把（front()）。
	var weapon_to_remove: Weapon = Global.player.current_weapons.filter(func(w: Weapon):
		return w.data.item_name == clicked_weapon.item_name).front()

	# 若找到可售的武器实例，从玩家与全局列表移除并释放。
	if weapon_to_remove:
		Global.player.current_weapons.erase(weapon_to_remove)
		Global.equipped_weapons.erase(weapon_to_remove.data)
		weapon_to_remove.queue_free()

	# 释放选中的卡片并清空选中状态。
	context_card.queue_free()
	context_card = null

	# 把售价累加到全局金币。
	Global.coins += coins
