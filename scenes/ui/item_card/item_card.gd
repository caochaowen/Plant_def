extends Button
class_name ItemCard
## =============================================================================
## ItemCard（物品卡片 / Button）
## -----------------------------------------------------------------------------
## 作用：背包/商店栏里的一个物品图标卡片。显示物品图标，并根据物品品质
##       着色边框。仅当物品是武器时，点击才发出 on_item_card_selected 信号
##       （用于商店里的合成/出售选中逻辑）。
## =============================================================================


## 信号：卡片被选中（仅武器卡片发出）。参数 card：被选中的卡片自身。
## 连接到 ShopPanel._on_item_card_selected。
signal on_item_card_selected(card: ItemCard)


## 卡片绑定的物品数据（ItemBase）。使用 setter _set_item 在赋值时刷新显示。
@export var item: ItemBase: set = _set_item


## 物品图标控件（TextureRect）。
@onready var item_icon: TextureRect = $ItemIcon


## 函数说明：物品的 setter，赋值时刷新图标与品质边框。
## 被谁调用：由 Godot 在给 item 赋值时自动调用。
## 调用了：Global.get_tier_style()、add_theme_stylebox_override()。
func _set_item(value: ItemBase) -> void:
	# 先保存 value 到 item 成员。
	item = value
	# 把图标控件的纹理设为物品的图标。
	item_icon.texture = item.item_icon

	# 用物品品质取对应样式（Global.get_tier_style），并覆盖按钮 "normal" 状态样式，
	# 让卡片边框显示品质颜色。
	var style := Global.get_tier_style(item.item_tier)
	add_theme_stylebox_override("normal", style)


## 函数说明：卡片点击回调。播放 UI 音效；若是武器则发出选中信号。
## 被谁调用：由 Button 的 pressed 信号触发。
## 调用了：SoundManager.play_sound()、on_item_card_selected.emit()。
func _on_pressed() -> void:
	# 播放 UI 点击音效。
	SoundManager.play_sound(SoundManager.Sound.UI)
	# 仅当物品类型是武器时，发出 on_item_card_selected 信号（携带自身），
	# 让商店面板知道用户选中了哪个武器卡片以进行合成/出售。
	if item.item_type == ItemBase.ItemType.WEAPON:
		on_item_card_selected.emit(self)
