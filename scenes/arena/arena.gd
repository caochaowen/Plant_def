extends Node2D
class_name Arena
## =============================================================================
## Arena（竞技场 / 主战斗场景根节点）
## -----------------------------------------------------------------------------
## 作用：战斗场景的总控制器。它连接全局信号与 UI/逻辑：
##   - 监听 Global 的浮动文字、升级、敌人死亡等信号并生成对应效果；
##   - 驱动波次流程：升级选择 → 商店 → 新一波；
##   - 清理战场、掉落金币、生成浮动文字、实例化玩家并装配初始武器。
## =============================================================================


## ---------------------------------------------------------------------------
## 导出字段（浮动文字颜色）
## ---------------------------------------------------------------------------

## 普通伤害文字颜色。
@export var normal_color: Color

## 格挡文字颜色。
@export var blocked_color: Color

## 暴击伤害文字颜色。
@export var critical_color: Color

## 治疗文字颜色。
@export var hp_color: Color


## ---------------------------------------------------------------------------
## 节点引用（@onready）
## ---------------------------------------------------------------------------

## 波次序号标签（显示"Wave N"）。
@onready var wave_index_label: Label = %WaveIndexLabel

## 波次倒计时标签。
@onready var wave_time_label: Label = %WaveTimeLabel

## 刷怪器节点（Spawner）。
@onready var spawner: Spawner = $Spawner

## 升级面板（UpgradePanel）。
@onready var upgrade_panel: UpgradePanel = %UpgradePanel

## 商店面板（ShopPanel）。
@onready var shop_panel: ShopPanel = %ShopPanel

## 金币袋 UI（CoinsBag）。
@onready var coins_bag: CoinsBag = %CoinsBag


## ---------------------------------------------------------------------------
## 运行时变量
## ---------------------------------------------------------------------------

## 当前场上已生成的金币列表（Coins），用于波末清理时统一飞向金币袋。
var gold_list: Array[Coins]


<<<<<<< HEAD

## 商店老板场景（Shopkeeper）预加载。由 spawn_shopkeeper 实例化。
const SHOPKEEPER_SCENE = preload("res://scenes/unit/shopkeeper/shopkeeper.tscn")

## 当前场上的商店老板实例。
var shopkeeper: Shopkeeper

## 上一波商店老板的位置（用于保证每波位置不同）。
var last_shopkeeper_pos := Vector2.ZERO



=======
>>>>>>> 737d3c7866ace77ccd9525ecf998dca41fae4516
## 函数说明：场景就绪时连接全局信号到本地回调。
## 被谁调用：由 Godot 引擎在节点进入场景树时自动调用。
## 调用了：Global 信号的 connect()。
func _ready() -> void:
	# 依次把 Global 上的 5 个全局信号连接到本脚本对应的 _on_xxx 回调函数上，
	# connect(回调) 表示"该信号触发时调用此回调"：
	# 生成格挡文字、生成伤害文字、升级选择、生成治疗文字、敌人死亡。
	Global.on_create_block_text.connect(_on_create_block_text)
	Global.on_create_damage_text.connect(_on_create_damage_text)
	Global.on_upgrade_selected.connect(_on_upgrade_selected)
	Global.on_create_heal_text.connect(_on_create_heal_text)
	Global.on_enemy_died.connect(_on_enemy_died)


## 函数说明：每帧刷新波次标签（波数 + 倒计时）。
## 被谁调用：由 Godot 引擎每帧调用。
## 调用了：spawner.get_wave_text()、spawner.get_wave_timer_text()。
func _process(delta: float) -> void:
	# 若游戏处于暂停（结算/商店/升级阶段），直接 return，暂停刷新 UI。
	if Global.game_paused: return
	# 用刷怪器返回的文本更新波数标签与波次倒计时标签的显示内容。
	wave_index_label.text = spawner.get_wave_text()
	wave_time_label.text = spawner.get_wave_timer_text()


## 函数说明：在指定单位附近生成一个浮动文字节点并返回。
## 被谁调用：_on_create_block_text、_on_create_damage_text、_on_create_heal_text。
## 调用了：Global.FLOATING_TEXT_SCENE.instantiate()、randf_range()。
func create_floating_text(unit: Node2D) -> FloatingText:
	# 实例化浮动文字场景（Global.FLOATING_TEXT_SCENE 是预加载的 PackedScene），
	# `as FloatingText` 把实例转型为 FloatingText 类型以便访问其成员。
	var instance := Global.FLOATING_TEXT_SCENE.instantiate() as FloatingText
	# 把实例加到场景树根节点（get_tree().root），使其参与渲染与每帧更新。
	get_tree().root.add_child(instance)
	# randf_range(0, TAU) 生成 [0, 2π) 的随机角度，×35 得到半径 35 的随机偏移量。
	var random_pos := randf_range(0, TAU) * 35
	# Vector2.RIGHT（即 (1,0)）旋转 random_pos 角度后得到随机方向的偏移向量，
	# 加到单位 global_position 上得到浮动文字的生成位置。
	var spawn_pos := unit.global_position + Vector2.RIGHT.rotated(random_pos)
	# 设置实例的世界坐标，并返回给调用方进一步 setup 文字内容。
	instance.global_position = spawn_pos
	return instance


## 函数说明：显示升级面板（根据当前波数加载升级选项）。
## 被谁调用：_on_spawner_on_wave_completed（波次结束后）。
## 调用了：upgrade_panel.load_upgrades()、upgrade_panel.show()。
func show_upgrades() -> void:
	# 用当前波数加载升级选项（根据概率从升级池随机选）。
	upgrade_panel.load_upgrades(spawner.wave_index)
	# show() 使升级面板可见。
	upgrade_panel.show()


## 函数说明：开始新一波。
## 被谁调用：_on_shop_panel_on_shop_next_wave（商店点击下一波时）。
## 调用了：Global.player.update_player_new_wave()、spawner.start_wave()。
func start_new_wave() -> void:
	# 解除游戏暂停，恢复战斗。
	Global.game_paused = false
	# 玩家在新一波开始时成长（生命上限按波增加并重置当前生命）。
	Global.player.update_player_new_wave()
	# 波数 +1。
	spawner.wave_index += 1
	# 让刷怪器按新波数启动本波刷怪。
	spawner.start_wave()
<<<<<<< HEAD
	spawn_shopkeeper()
=======
>>>>>>> 737d3c7866ace77ccd9525ecf998dca41fae4516


## 函数说明：清理战场：让所有金币飞向金币袋，并清除剩余敌人。
## 被谁调用：_on_spawner_on_wave_completed（波末调用两次）。
## 调用了：gold.set_collection_target()、spawner.clear_enemies()。
func clean_arena() -> void:
	# 若场上有金币，先把它们全部"吸"向金币袋 UI。
	if gold_list.size() > 0:
		# 计算金币袋中心的世界坐标：金币袋位置 + 其尺寸的一半（size 是控件尺寸）。
		var target_center_pos := coins_bag.global_position + coins_bag.size / 2.0
		# 遍历所有金币。
		for gold in gold_list:
			# is_instance_valid(gold) 判断节点是否仍有效（未被 queue_free 释放）。
			if is_instance_valid(gold):
				# 转型为 Coins 并设置它的收集目标（让它飞向金币袋）。
				var gold_item := gold as Coins
				gold_item.set_collection_target(target_center_pos)

	# 清空金币列表（金币节点本身稍后会自行销毁）。
	gold_list.clear()
	# 清除所有剩余敌人（播放死亡动画后释放）。
	spawner.clear_enemies()


## 函数说明：在敌人死亡位置生成一枚金币。
## 被谁调用：_on_enemy_died。
## 调用了：Global.COINS_SCENE.instantiate()、call_deferred()。
func spawn_coins(enemy: Enemy) -> void:
	# randf_range(0, TAU) 生成随机角度，右方向旋转该角度 ×35 得到随机偏移，用于散开金币。
	var random_angle := randf_range(0, TAU)
	var offset := Vector2.RIGHT.rotated(random_angle) * 35
	# 金币生成位置 = 敌人位置 + 随机偏移。
	var spawn_pos := enemy.global_position + offset

	# 实例化金币场景（Coins）。
	var gold_instance := Global.COINS_SCENE.instantiate() as Coins
	# 把金币加入 gold_list 以便波末统一收集。
	gold_list.append(gold_instance)

	# 设置金币世界坐标与面值（面值取自敌人的金币掉落属性 gold_drop）。
	gold_instance.global_position = spawn_pos
	gold_instance.value = enemy.stats.gold_drop
	# call_deferred("add_child", gold_instance) 把"加入场景树"推迟到本帧末尾的空闲阶段执行，
	# 避免在信号回调中即时修改场景树可能带来的时序问题。
	call_deferred("add_child", gold_instance)


## 函数说明：Global.on_create_block_text 信号回调，生成"格挡"文字。
## 被谁调用：由 Global.on_create_block_text 信号触发（Unit 受击被格挡时）。
## 调用了：create_floating_text()、text.setup()。
func _on_create_block_text(unit: Node2D) -> void:
	# 在单位处生成浮动文字，然后 setup 设置文字内容为 "Blocked!"、颜色为格挡色。
	var text := create_floating_text(unit)
	text.setup("Blocked!", blocked_color)


## 函数说明：Global.on_create_damage_text 信号回调，生成伤害文字。
## 被谁调用：由 Global.on_create_damage_text 信号触发。
## 调用了：create_floating_text()、text.setup()。
func _on_create_damage_text(unit: Node2D, hitbox: HitboxComponent) -> void:
	# 在单位处生成浮动文字。
	var text := create_floating_text(unit)
	# 三元表达式：若攻击盒 critical（暴击）用暴击色，否则用普通伤害色。
	var color := critical_color if hitbox.critical else normal_color
	# setup 设置文字为伤害数值（str() 把数字转字符串）、颜色为上面选定的颜色。
	text.setup(str(hitbox.damage), color)


## 函数说明：Global.on_create_heal_text 信号回调，生成治疗文字。
## 被谁调用：由 Global.on_create_heal_text 信号触发。
## 调用了：create_floating_text()、text.setup()。
func _on_create_heal_text(unit: Node2D, heal: float) -> void:
	# 在单位处生成浮动文字，文字内容为 "+ 治疗量"，颜色为治疗色。
	var text := create_floating_text(unit)
	text.setup("+ %s" % heal, hp_color)


## 函数说明：Global.on_upgrade_selected 信号回调，升级选定后切换到商店。
## 被谁调用：由 Global.on_upgrade_selected 信号触发（UpgradeCard 点选后）。
## 调用了：upgrade_panel.hide()、shop_panel.load_shop()、shop_panel.show()。
func _on_upgrade_selected() -> void:
	# 隐藏升级面板。
	upgrade_panel.hide()
	# 用当前波数加载商店商品。
<<<<<<< HEAD
	#shop_panel.load_shop(spawner.wave_index)
	# 显示商店面板。
	#shop_panel.show()
	
	# ★ 不再自动打开商店，改为直接开始下一波（波开始时会刷商店老板）。
	start_new_wave()



=======
	shop_panel.load_shop(spawner.wave_index)
	# 显示商店面板。
	shop_panel.show()
>>>>>>> 737d3c7866ace77ccd9525ecf998dca41fae4516


## 函数说明：Spawner.on_wave_completed 信号回调，波末结算流程。
## 被谁调用：由 Spawner.on_wave_completed 信号触发（波计时结束）。
## 调用了：clean_arena()、get_tree().create_timer()、show_upgrades()。
func _on_spawner_on_wave_completed() -> void:
	# 若玩家尚未生成（理论上不会），直接返回，避免空引用。
	if not Global.player: return
	# 第一次清理：让金币飞向金币袋、清空剩余敌人。
	clean_arena()
	# get_tree().create_timer(1.0) 创建一个 1 秒定时器，await 其 timeout 信号，
	# 即暂停本函数执行 1 秒，让金币收集动画有时间播放完。
	await get_tree().create_timer(1.0).timeout
	# 显示升级面板。
	show_upgrades()
	# 再次清理（确保 1 秒等待期间可能出现的敌人/金币也被清掉）。
	clean_arena()


## 函数说明：ShopPanel.on_shop_next_wave 信号回调，商店"下一波"→ 开始新波。
## 被谁调用：由 ShopPanel.on_shop_next_wave 信号触发。
## 调用了：shop_panel.hide()、start_new_wave()。
func _on_shop_panel_on_shop_next_wave() -> void:
	# 隐藏商店面板。
	shop_panel.hide()
	# 开始新一波。
<<<<<<< HEAD
	#start_new_wave()
	# ★ 只恢复战斗，不再 start_new_wave（波数推进已移到 _on_upgrade_selected）。
	Global.game_paused = false
=======
	start_new_wave()
>>>>>>> 737d3c7866ace77ccd9525ecf998dca41fae4516


## 函数说明：Global.on_enemy_died 信号回调，敌人死亡 → 掉落金币。
## 被谁调用：由 Global.on_enemy_died 信号触发（Enemy 死亡时）。
## 调用了：spawn_coins()。
func _on_enemy_died(enemy: Enemy) -> void:
	# 在死亡敌人位置生成一枚金币。
	spawn_coins(enemy)


## 函数说明：SelectionPanel.on_selection_completed 信号回调，完成角色选择后开始游戏。
## 被谁调用：由 SelectionPanel.on_selection_completed 信号触发。
## 调用了：Global.get_selected_player()、player.add_weapon()、
##        shop_panel.create_item_weapon()、spawner.start_wave()。
func _on_selection_panel_on_selection_completed() -> void:
	# 用已选角色实例化玩家（Global.get_selected_player 内部会写入 Global.player）。
	var player := Global.get_selected_player()
	# 把玩家节点加入竞技场场景树。
	add_child(player)
	# 给玩家装配初始武器。
	player.add_weapon(Global.main_weapon_selected)
	# 在商店武器栏创建对应的武器卡片。
	shop_panel.create_item_weapon(Global.main_weapon_selected)
	# 把初始武器加入全局已装备武器列表。
	Global.equipped_weapons.append(Global.main_weapon_selected)

	# 启动第一波刷怪。
	spawner.start_wave()
	# 解除暂停，正式开始游戏。
	Global.game_paused = false
<<<<<<< HEAD
	# ★ 第一波也刷一个商店老板。
	spawn_shopkeeper()
	
	

#商店老板
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
=======
>>>>>>> 737d3c7866ace77ccd9525ecf998dca41fae4516
