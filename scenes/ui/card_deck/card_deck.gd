extends HBoxContainer
class_name CardDeck

## 牌组最大卡槽数量。
const MAX_CARDS := 5

## 5 个卡槽引用（按从左到右顺序）。就绪时自动收集子节点中的 DeckCard。
@onready var slots: Array[DeckCard] = []

func _ready() -> void:
	for child in get_children():
		if child is DeckCard:
			slots.append(child as DeckCard)

## 返回指定下标的卡槽（越界返回 null）。
func get_slot(index: int) -> DeckCard:
	if index < 0 or index >= slots.size():
		return null
	return slots[index]
