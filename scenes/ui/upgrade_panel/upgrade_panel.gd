extends Panel
class_name UpgradePanel
## =============================================================================
## UpgradePanel（升级奖励面板 / Panel）
## -----------------------------------------------------------------------------
## 作用：波末的升级选择界面。根据当前波数与升级概率配置，从升级池中随机
##       选出若干升级并生成卡片供玩家点选。
## =============================================================================


## 升级卡片场景（UpgradeCard）预加载。
const UPGRADE_CARD_SCENE = preload("uid://b0nwu1370004c")


## 可选的升级池（ItemUpgrade 数组）。
@export var upgrade_list: Array[ItemUpgrade]


## 升级卡片容器（HBoxContainer）。
@onready var items_container: HBoxContainer = %ItemsContainer


## 函数说明：根据当前波数生成升级选项卡片。
## 被谁调用：Arena.show_upgrades（波末）。
## 调用了：Global.select_items_for_offer()、UPGRADE_CARD_SCENE.instantiate()。
func load_upgrades(current_wave: int) -> void:
	# 先清空容器旧内容（queue_free 逐个释放子节点）。
	for child in items_container.get_children():
		child.queue_free()

	# 用升级概率配置从升级池随机选若干升级（Global.select_items_for_offer）。
	var config := Global.UPGRADE_PROBABILITY_CONFIG
	var selected_upgrades := Global.select_items_for_offer(upgrade_list, current_wave, config)
	# 为每个选中的升级生成一张升级卡片。
	for random_upg: ItemUpgrade in selected_upgrades:
		# 实例化 UpgradeCard。
		var card_instance := UPGRADE_CARD_SCENE.instantiate() as UpgradeCard
		# 加入容器。
		items_container.add_child(card_instance)
		# 赋值 item_data（触发 setter 刷新显示）。
		card_instance.item_data = random_upg
