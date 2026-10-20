extends Node2D
class_name FloatingText
## =============================================================================
## FloatingText（浮动文字 / Node2D）
## -----------------------------------------------------------------------------
## 作用：战斗中飘出的临时文字（伤害/格挡/治疗）。setup 时设置文字、颜色、
##       随机缩放与旋转，然后用 Tween 做出"弹出→上浮→淡出"动画，
##       动画结束后自动销毁。
## =============================================================================


## 显示文字内容的标签（Label）。
@onready var value_label: Label = $ValueLabel


## 函数说明：设置文字内容/颜色，并播放弹出上浮淡出动画。
## 被谁调用：Arena.create_floating_text 的调用方（_on_create_block_text /
##        _on_create_damage_text / _on_create_heal_text）。
## 调用了：deg_to_rad()、randf_range()、create_tween()、queue_free()。
func setup(value: String, color: Color) -> void:
	# 设置标签文字与自身颜色；scale 置零让文字从 0 开始弹出。
	value_label.text = value
	modulate = color
	scale = Vector2.ZERO

	# deg_to_rad 把角度转弧度；randf_range(-10, 10) 生成 -10~10 的随机角度，
	# 作为文字的随机倾斜，使每个文字朝向略有不同。
	rotation = deg_to_rad(randf_range(-10, 10))
	# randf_range(0.8, 1.6) 生成随机目标缩放倍率，让文字弹出大小不一。
	var random_scale := randf_range(0.8, 1.6)

	# create_tween() 创建一个 Tween（补间动画对象）用于编排动画序列。
	var tween := create_tween()

	# parallel() 表示下面的两个 tween_property 并行执行：
	# 1) scale 在 0.4 秒内从 0 放大到 random_scale（弹出效果）；
	# 2) global_position 在 0.4 秒内向上平移 15 像素（上浮效果）。
	tween.parallel().tween_property(self, "scale", random_scale * Vector2.ONE, 0.4)
	tween.parallel().tween_property(self, "global_position", global_position + Vector2.UP * 15, 0.4)

	# tween_interval(0.5) 让动画在顶点停顿 0.5 秒（文字停留时间）。
	tween.tween_interval(0.5)

	# 最后一段并行动画：
	# 1) scale 在 0.4 秒内缩回 0（缩小消失）；
	# 2) modulate:a（透明度）在 0.4 秒内降为 0（淡出）。
	tween.parallel().tween_property(self, "scale", Vector2.ZERO, 0.4)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.4)

	# await tween.finished 等待整个动画播放完毕。
	await tween.finished
	# 动画结束后释放自身节点。
	queue_free()
