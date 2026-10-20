extends HBoxContainer
class_name CoinsBag
## =============================================================================
## CoinsBag（金币袋 UI / HBoxContainer）
## -----------------------------------------------------------------------------
## 作用：屏幕角落的金币显示控件。每帧把全局金币数（Global.coins）刷新到
##       一个 Label 上。同时它也被 Arena.clean_arena 用作"波末金币收集"的目标位置。
## =============================================================================


## 显示金币数量的标签（Label）。由 _process 每帧刷新。
@onready var coins: Label = $Coins


## 函数说明：每帧刷新金币显示文本。
## 被谁调用：由 Godot 引擎每帧调用。
## 调用了：str()。
func _process(delta: float) -> void:
	# str(Global.coins) 把全局金币数转成字符串，赋给 Label 的 text 显示。
	coins.text = str(Global.coins)
