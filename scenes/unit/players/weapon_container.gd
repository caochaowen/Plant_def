extends Node2D
class_name WeaponContainer
## =============================================================================
## WeaponContainer（武器挂点容器 / Node2D）
## -----------------------------------------------------------------------------
## 作用：管理玩家身上武器的挂点布局。根据当前武器数量选择对应的参考节点
##       （One~Six，内含若干 Marker2D 子节点），把每把武器放到对应挂点上，
##       实现多把武器围绕玩家的排列。
## =============================================================================


## ---------------------------------------------------------------------------
## 节点引用（1~6 把武器时分别对应的参考节点）
## ---------------------------------------------------------------------------

## 1 把武器时的挂点参考节点。
@onready var one: Node2D = $One

## 2 把武器时的挂点参考节点。
@onready var two: Node2D = $Two

## 3 把武器时的挂点参考节点。
@onready var three: Node2D = $Three

## 4 把武器时的挂点参考节点。
@onready var four: Node2D = $Four

## 5 把武器时的挂点参考节点。
@onready var five: Node2D = $Five

## 6 把武器时的挂点参考节点。
@onready var six: Node2D = $Six


## 函数说明：根据武器数量把每把武器放到对应挂点位置。
## 被谁调用：Player.add_weapon（装配/合成武器时）。
## 调用了：reference_node.get_children()。
func update_weapons_position(weapons: Array[Weapon]) -> void:
	# 取当前武器数量。
	var count := weapons.size()
	# reference_node 用于存放选中的参考节点。
	var reference_node: Node2D
	# match 按武器数量选择对应的参考节点（1~6 各对应 One~Six）。
	match count:
		1: reference_node = one
		2: reference_node = two
		3: reference_node = three
		4: reference_node = four
		5: reference_node = five
		6: reference_node = six

	# 取参考节点的子节点数组（即该布局下的各挂点 Marker2D）。
	var markers := reference_node.get_children()
	# 若挂点数量与武器数量不一致（配置错误），直接返回，不调整位置。
	if markers.size() != count:
		return

	# 遍历每把武器，把其世界坐标设为对应挂点的世界坐标（按顺序一一对应）。
	for i in count:
		weapons[i].global_position = markers[i].global_position
