extends Camera2D
class_name Camera
## =============================================================================
## Camera（跟随摄像机 / Camera2D）
## -----------------------------------------------------------------------------
## 作用：让摄像机始终跟随玩家。每帧把自身位置同步为玩家位置，
##       实现镜头锁定在角色身上。
## =============================================================================


## 函数说明：每帧将摄像机位置对齐到玩家位置。
## 被谁调用：由 Godot 引擎每帧调用。
## 调用了：is_instance_valid()。
func _process(delta: float) -> void:
	# is_instance_valid(Global.player) 检查玩家节点是否仍有效（未被 queue_free 释放），
	# 避免在玩家销毁后访问空引用。
	if is_instance_valid(Global.player):
		# 把摄像机的世界坐标设为玩家世界坐标，实现镜头跟随。
		global_position = Global.player.global_position
