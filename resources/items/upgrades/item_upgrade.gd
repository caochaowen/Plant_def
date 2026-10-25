extends ItemBase
class_name ItemUpgrade
## =============================================================================
## ItemUpgrade（升级道具 / Resource）
## -----------------------------------------------------------------------------
## 作用：继承 ItemBase，描述一个"升级奖励"：指定要提升的玩家属性（stat_id）
##       及其增加值（value），在波次结算时作为可选项供玩家挑选。
## =============================================================================


### 升级提升的数值（加到 stat_id 指定的属性上）。
#@export var value: float
#
### 升级的描述文本（直接作为展示文案，非 BBCode 计算）。
@export var description: String
#
### 要提升的属性 id（对应 UnitStats 字段名，如 "damage"）。
#@export var stat_id: String
#
#
### 函数说明：把升级效果应用到玩家属性上（在现有值基础上累加 value）。
### 被谁调用：UpgradeCard._on_custom_buttom_pressed（玩家点选升级卡时）。
### 调用了：Global.player.stats.get() / set()。
#func apply_upgrade() -> void:
	## stats.get(stat_id) 用属性名取玩家当前该属性的值（不存在则返回 null），
	## `as float` 把结果安全转型为 float（用于后续加法）。
	#var current_value := Global.player.stats.get(stat_id) as float
	## 新值 = 升级提供值 value + 当前值 current_value；float() 确保 value 是浮点。
	#var new_value := float(value) + float(current_value)
	## stats.set(stat_id, new_value) 把新值写回玩家属性字典（按属性名覆盖）。
	#Global.player.stats.set(stat_id, new_value)
#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------


## 作用：描述一个"升级奖励"。可同时调整多个玩家属性：每个可调属性都是一个
##       数字字段，正数=增加、负数=减少、0=不涉及；点击卡片时把所有非 0 项
##       一次性应用到 Global.player.stats。

## ---------------------------------------------------------------------------
## 可调整属性（字段名必须与 UnitStats 的 @export 字段名一致，apply_upgrade
## 靠名字写回玩家 stats）。正=增加，负=减少，0=不涉及。
## ---------------------------------------------------------------------------
@export var damage := 0.0          # 伤害
@export var speed := 0.0           # 移动速度
@export var health := 0.0          # 生命上限
@export var hp_regen := 0.0        # 生命回复
@export var life_steal := 0.0      # 生命偷取（百分比点数）
@export var luck := 0.0            # 幸运
@export var block_chance := 0.0    # 格挡率（百分比点数）
@export var harvesting := 0.0      # 收获

## 手动描述（留空则 get_description() 按非 0 项自动生成）。可选，一般留空即可。
#@export var description := "0"


## 所有可调整属性名清单（新增属性：上面加字段 + 这里加名字）。
const STAT_NAMES: Array[String] = [
	"damage", "speed", "health", "hp_regen",
	"life_steal", "luck", "block_chance", "harvesting",
]


## 应用升级：把所有非 0 字段一次性累加到玩家对应属性。
## 被谁调用：UpgradeCard._on_custom_buttom_pressed（点击卡片）。
func apply_upgrade() -> void:
	for stat_name in STAT_NAMES:
		var v: float = get(stat_name)          # 反射读本字段当前值（正/负/0）
		if v == 0.0:
			continue
		var current := Global.player.stats.get(stat_name) as float
		Global.player.stats.set(stat_name, current + v)   # 正加负减


## 生成描述文本：优先用手写的 description，否则列出所有非 0 项。
## 被谁调用：UpgradeCard._set_data（显示卡片描述）。
func get_description() -> String:
	if description != "":
		return description
	var lines: Array[String] = []
	for stat_name in STAT_NAMES:
		var v: float = get(stat_name)
		if v > 0.0:
			lines.append("+%s %s" % [_fmt(v), stat_name])
		elif v < 0.0:
			lines.append("%s %s" % [_fmt(v), stat_name])
	return "\n".join(lines)


## 整数则去掉小数点（5.0 → "5"），否则保留原样。
func _fmt(v: float) -> String:
	if v == int(v):
		return str(int(v))
	return str(v)
