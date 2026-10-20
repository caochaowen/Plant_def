extends Area2D
class_name HurtboxComponent
## =============================================================================
## HurtboxComponent（受击碰撞盒 / Area2D）
## -----------------------------------------------------------------------------
## 作用：代表单位"可被击中"的区域。当与攻击盒（HitboxComponent）重叠时，
##       发出 on_damaged 信号，把命中的攻击盒传递给单位做受伤处理。
## =============================================================================


## 信号：本受伤盒被攻击盒命中。参数 hitbox：命中的攻击盒。
## 连接到 Unit._on_hurtbox_component_on_damaged（及其子类 Enemy 的重写）。
signal on_damaged(hitbox: HitboxComponent)


## 函数说明：受伤盒与攻击盒重叠时触发，发出 on_damaged 信号。
## 被谁调用：由 Area2D 的 area_entered 信号触发。
## 调用了：on_damaged.emit()。
func _on_area_entered(area: Area2D) -> void:
	# 类型检查：只有重叠对象是 HitboxComponent（攻击盒）时才处理。
	if area is HitboxComponent:
		# 发出 on_damaged 信号，把命中的攻击盒传给单位，单位据此计算格挡/扣血。
		on_damaged.emit(area)
