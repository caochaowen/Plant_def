extends Panel
class_name DeckCard

## 空卡占位标签（当前占位用；未来填入真实卡牌内容后隐藏）。
@onready var empty_label: Label = %EmptyLabel

## 把本卡槽重置为空卡占位状态。
func set_empty() -> void:
	empty_label.show()

## 在本卡槽上显示一张具体技能卡牌（占位实现，未来扩展）。
func set_card_data(_card_data) -> void:
	empty_label.hide()
