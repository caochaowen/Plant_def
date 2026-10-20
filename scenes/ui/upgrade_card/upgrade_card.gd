extends Panel
class_name UpgradeCard
## =============================================================================
## UpgradeCard（升级奖励卡片 / Panel）
## -----------------------------------------------------------------------------
## 作用：波末升级界面里的一个升级选项。显示图标/名称/描述并按品质着色；
##       点击后把升级效果应用到玩家，播放音效，并发出全局 on_upgrade_selected
##       信号通知 Arena 进入商店。
## =============================================================================


## 升级数据（ItemUpgrade）。使用 setter _set_data 在赋值时刷新显示。
@export var item_data: ItemUpgrade: set = _set_data


## ---------------------------------------------------------------------------
## 节点引用
## ---------------------------------------------------------------------------

## 升级图标控件。
@onready var item_icon: TextureRect = %Icon

## 升级名称标签。
@onready var item_name: Label = %Name

## 升级描述标签。
@onready var item_description: Label = %Description


## 函数说明：升级数据的 setter，赋值时刷新图标/名称/描述与品质边框。
## 被谁调用：由 Godot 在给 item_data 赋值时自动调用（UpgradePanel.load_upgrades）。
## 调用了：Global.get_tier_style()、add_theme_stylebox_override()。
func _set_data(value: ItemUpgrade) -> void:
	# 保存升级数据。
	item_data = value
	# 填充图标、名称、描述。
	item_icon.texture = item_data.item_icon
	item_name.text = item_data.item_name
	item_description.text = item_data.description

	# 用品质取样式覆盖 panel 样式，让升级卡片边框显示品质颜色。
	var style := Global.get_tier_style(item_data.item_tier)
	add_theme_stylebox_override("panel", style)


## 函数说明：升级卡片点击回调，应用升级并通知 Arena。
## 被谁调用：由卡片按钮的 pressed 信号触发。
## 调用了：item_data.apply_upgrade()、SoundManager.play_sound()、
##        Global.on_upgrade_selected.emit()。
func _on_custom_buttom_pressed() -> void:
	# 仅当有升级数据且玩家有效时才执行。
	if item_data and is_instance_valid(Global.player):
		# 把升级效果应用到玩家属性（累加对应 stat）。
		item_data.apply_upgrade()
		# 播放 UI 音效。
		SoundManager.play_sound(SoundManager.Sound.UI)
		# 发出全局 on_upgrade_selected 信号，Arena 收到后切换到商店。
		Global.on_upgrade_selected.emit()
