extends Panel
class_name ShopCard
## =============================================================================
## ShopCard（商店商品卡片 / Panel）
## -----------------------------------------------------------------------------
## 作用：商店里的一件商品。显示图标/名称/类型/描述/价格，并按品质着色；
##       玩家点击购买时校验武器数量上限与金币是否足够，足够则扣钱并发出
##       购买信号，然后销毁自身。
## =============================================================================


## 信号：商品被购买。参数 item：被购买的商品（ItemBase）。
## 连接到 ShopPanel._on_item_purchased。
signal on_item_purchased(item: ItemBase)


## 商品数据（ItemBase）。使用 setter _set_shop_item 在赋值时刷新显示。
@export var shop_item: ItemBase: set = _set_shop_item


## ---------------------------------------------------------------------------
## 节点引用
## ---------------------------------------------------------------------------

## 商品图标控件。
@onready var item_icon: TextureRect = %ItemIcon

## 商品名称标签。
@onready var item_name: Label = %ItemName

## 商品类型标签。
@onready var item_type: Label = %ItemType

## 商品描述富文本。
@onready var item_description: RichTextLabel = %ItemDescription

## 价格标签。
@onready var coins_label: Label = %CoinsLabel


## 函数说明：商品的 setter，赋值时刷新所有显示字段与品质边框。
## 被谁调用：由 Godot 在给 shop_item 赋值时自动调用（ShopPanel.load_shop）。
## 调用了：value.get_description()、Global.get_tier_style()、add_theme_stylebox_override()。
func _set_shop_item(value: ItemBase) -> void:
	# 保存商品数据到 shop_item。
	shop_item = value
	# 填充图标、名称、价格。
	item_icon.texture = value.item_icon
	item_name.text = value.item_name
	# ItemBase.ItemType.keys() 返回枚举所有键名（如 ["WEAPON","UPGRADE","PASSIVE"]），
	# 用 value.item_type（整数）作为下标取出对应的类型名文本。
	item_type.text = ItemBase.ItemType.keys()[value.item_type]
	# 调用商品的 get_description() 获取 BBCode 描述文本。
	item_description.text = value.get_description()
	# 价格文本。
	coins_label.text = str(value.item_cost)

	# 用品质取样式覆盖 panel 样式，让商品卡片边框显示品质颜色。
	var style := Global.get_tier_style(value.item_tier)
	add_theme_stylebox_override("panel", style)


## 函数说明：购买按钮回调，校验后购买商品。
## 被谁调用：由购买按钮的 pressed 信号触发。
## 调用了：SoundManager.play_sound()、on_item_purchased.emit()、queue_free()。
func _on_buy_buttom_pressed() -> void:
	# 播放 UI 点击音效。
	SoundManager.play_sound(SoundManager.Sound.UI)

	# 若已装备武器已达 6 把上限，直接返回（武器槽满，不允许再买武器）。
	if Global.equipped_weapons.size() >= 6:
		return

	# 若全局金币足够支付商品价格。
	if Global.coins >= shop_item.item_cost:
		# 扣除金币。
		Global.coins -= shop_item.item_cost
		# 发出购买信号（把商品传给 ShopPanel 处理入背包/生效）。
		on_item_purchased.emit(shop_item)
		# 购买成功后销毁本商品卡片。
		queue_free()
