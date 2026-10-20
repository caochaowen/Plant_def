extends Resource
class_name ItemBase
## =============================================================================
## ItemBase（物品基类 / Resource）
## -----------------------------------------------------------------------------
## 作用：所有物品（武器 Weapon / 升级 Upgrade / 被动 Passive）的抽象基类，
##       定义物品共有的数据字段（名称、图标、品质、类型、价格），
##       以及一个可供子类重写的描述生成方法 get_description()。
## 该 Resource 本身不直接实例化为场景，而是作为 ItemWeapon / ItemUpgrade /
## ItemPassive 的父类存在。
## =============================================================================


## ---------------------------------------------------------------------------
## 物品类型枚举
## ---------------------------------------------------------------------------
## 物品类型：WEAPON（武器）/ UPGRADE（升级）/ PASSIVE（被动道具）。
## 用于商店/背包逻辑区分物品行为（如 ShopPanel._on_item_purchased 按类型分发）。
enum ItemType {
	WEAPON,
	UPGRADE,
	PASSIVE
}


## ---------------------------------------------------------------------------
## 导出字段（物品公共属性）
## ---------------------------------------------------------------------------

## 物品名称（显示用）。
@export var item_name: String

## 物品图标（Texture2D）。
@export var item_icon: Texture2D

## 物品品质（Global.UpgradeTier 枚举：COMMON/RARE/EPIC/LEGENDARY）。
## 用于掉落概率筛选（select_items_for_offer）与卡片着色（get_tier_style）。
@export var item_tier: Global.UpgradeTier

## 物品类型（ItemType 枚举）。
@export var item_type: ItemType

## 物品价格（金币，仅商店购买/出售相关逻辑使用）。
@export var item_cost: int


## 函数说明：返回物品的描述文本（富文本 BBCode 字符串）。
## 被谁调用：ShopCard._set_shop_item（显示商品描述）。
## 调用了：无。
func get_description() -> String:
	# 基类默认返回空字符串；子类（ItemWeapon/ItemPassive）会重写本方法返回具体描述。
	return ""
