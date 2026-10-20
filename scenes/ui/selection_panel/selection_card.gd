extends Button
class_name SelectionCard
## =============================================================================
## SelectionCard（选择卡片 / Button）
## -----------------------------------------------------------------------------
## 作用：角色选择 / 初始武器选择界面里的一个图标按钮。提供设置图标的接口，
##       并在点击/悬停时播放 UI 音效。
## =============================================================================


## 函数说明：设置卡片图标纹理。
## 被谁调用：SelectionPanel.load_players（角色卡片）。
## 调用了：无（直接赋值 Button.icon）。
func set_icon(texture: Texture2D) -> void:
	# icon 是 Button 内置属性；把传入纹理赋给它，卡片即显示该图标。
	icon = texture


## 函数说明：卡片点击回调，播放 UI 音效。
## 被谁调用：由 Button 的 pressed 信号触发。
## 调用了：SoundManager.play_sound()。
func _on_pressed() -> void:
	# 播放 UI 点击音效。
	SoundManager.play_sound(SoundManager.Sound.UI)


## 函数说明：鼠标悬停回调，播放 UI 音效。
## 被谁调用：由 Button 的 mouse_entered 信号触发。
## 调用了：SoundManager.play_sound()。
func _on_mouse_entered() -> void:
	# 播放 UI 悬停音效。
	SoundManager.play_sound(SoundManager.Sound.UI)
