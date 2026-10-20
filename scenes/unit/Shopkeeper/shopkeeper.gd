extends Unit
class_name Shopkeeper
## =============================================================================
## Shopkeeper（商店老板 NPC / Unit 子类）
## -----------------------------------------------------------------------------
## 作用：每波开始时被 Arena 刷到地图随机位置、原地不动的交互 NPC。
##       玩家进入交互距离后显示提示，按「interact」键发出 on_interact 信号，
##       由 Arena 收到后打开商店面板。本身不参与任何战斗逻辑。
## =============================================================================


## 信号：玩家在范围内按交互键。由 Arena.spawn_shopkeeper 连接到 open_shop。
signal on_interact


## 交互触发距离（像素）。
@export var interact_distance := 120.0


## 交互提示标签（"按空格打开商店"）。
@onready var interact_label: Label = $InteractLabel


## 玩家是否在交互范围内。
var player_in_range := false


## 函数说明：就绪时初始化父类、隐藏提示标签、隐藏血条。
## 被谁调用：由 Godot 引擎在节点进入场景树时调用。
## 调用了：super._ready()。
func _ready() -> void:
	# 父类 Unit._ready 会 health_component.setup(stats)，因此本节点需要有效的 stats。
	super._ready()
	# 隐藏提示标签。
	interact_label.visible = false
	# 隐藏血条（商店老板不需要显示生命条）。
	$HealthBar.visible = false


## 函数说明：每帧检测玩家距离，控制提示显隐并响应交互键。
## 被谁调用：由 Godot 引擎每帧调用。
## 调用了：Input.is_action_just_pressed()、on_interact.emit()。
func _process(_delta: float) -> void:
	# 游戏暂停（商店/升级/结算中）时不响应。
	if Global.game_paused:
		return

	# 玩家尚未生成或已被释放则跳过。
	if not is_instance_valid(Global.player):
		return

	# 计算与玩家的距离。
	var dist := global_position.distance_to(Global.player.global_position)
	var in_range := dist <= interact_distance

	# 状态变化时才刷新提示显隐（避免每帧重复赋值）。
	if in_range != player_in_range:
		player_in_range = in_range
		interact_label.visible = in_range

	# 在范围内且刚按下交互键，发出交互信号。
	if player_in_range and Input.is_action_just_pressed("interact"):
		on_interact.emit()
