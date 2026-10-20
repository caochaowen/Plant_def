extends Control
class_name HealthBar
## =============================================================================
## HealthBar（血条 UI / Control）
## -----------------------------------------------------------------------------
## 作用：单位头顶/身上的血条。在 _ready 时用导出的颜色给进度条的背景/填充
##       上色；通过 update_bar 更新进度条与血量数字；并监听 HealthComponent 的
##       on_health_changed 信号自动刷新。
## =============================================================================


## ---------------------------------------------------------------------------
## 导出字段
## ---------------------------------------------------------------------------

## 血条背景颜色。
@export var back_color: Color

## 血条填充（当前血量）颜色。
@export var fill_color: Color


## ---------------------------------------------------------------------------
## 节点引用
## ---------------------------------------------------------------------------

## 进度条控件（ProgressBar）。
@onready var progress_bar: ProgressBar = $ProgressBar

## 显示血量数字的标签（Label）。
@onready var health_label: Label = $HealthAmount


## 函数说明：就绪时把导出颜色应用到进度条的背景与填充样式。
## 被谁调用：由 Godot 引擎在节点进入场景树时调用。
## 调用了：progress_bar.get_theme_stylebox()、duplicate()、add_theme_stylebox_override()。
func _ready() -> void:
	# get_theme_stylebox("background") 取进度条主题里名为 "background" 的样式盒，
	# duplicate() 复制一份（避免直接修改共享的主题资源），再改它的 bg_color 为背景色。
	var back_style := progress_bar.get_theme_stylebox("background").duplicate()
	back_style.bg_color = back_color

	# 同理复制 "fill"（填充条）样式盒并设为填充色。
	var fill_style := progress_bar.get_theme_stylebox("fill").duplicate()
	fill_style.bg_color = fill_color

	# add_theme_stylebox_override(name, style) 把自定义样式覆盖回进度条主题，
	# 分别覆盖背景与填充，使血条呈现导出的颜色。
	progress_bar.add_theme_stylebox_override("background", back_style)
	progress_bar.add_theme_stylebox_override("fill", fill_style)


## 函数说明：更新血条数值与血量数字显示。
## 被谁调用：_on_health_component_on_health_changed。
## 调用了：无（直接赋值）。
func update_bar(value: float, health: float) -> void:
	# 设置进度条当前值（比例 0~1）。
	progress_bar.value = value
	# str(health) 把血量数字转字符串显示在标签上。
	health_label.text = str(health)


## 函数说明：HealthComponent 血量变化信号回调，刷新血条。
## 被谁调用：由 HealthComponent.on_health_changed 信号触发。
## 调用了：update_bar()。
func _on_health_component_on_health_changed(current: float, max: float) -> void:
	# 计算血量比例 = 当前生命 / 最大生命（0~1）。
	var value = current / max
	# 用比例与当前血量更新血条显示。
	update_bar(value, current)
