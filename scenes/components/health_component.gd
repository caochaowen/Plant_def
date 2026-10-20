extends Node
class_name HealthComponent
## =============================================================================
## HealthComponent（生命组件 / Node）
## -----------------------------------------------------------------------------
## 作用：管理单位的生命值。提供初始化、受伤、治疗、死亡处理，并通过信号
##       对外广播"受击/死亡/血量变化"，供 UI（血条）与逻辑（死亡掉落）响应。
## =============================================================================


## 信号：单位受到一次伤害（非死亡判定，只是被 hit）。由 take_damage 发出。
signal on_unit_hit

## 信号：单位死亡。由 take_damage 在血量降到 0 时发出。
signal on_unit_died

## 信号：血量变化（当前/最大）。由 setup / take_damage / heal 发出，
## 连接到 HealthBar._on_health_component_on_health_changed。
signal on_health_changed(current: float, max: float)


## 最大生命值。由 setup 从 stats.health 赋值。
var max_health := 1.0

## 当前生命值。由 setup 初始化为 max_health。
var current_health := 1.0


## 函数说明：根据单位属性初始化生命值并广播初始血量。
## 被谁调用：Unit._ready（所有单位的初始化）。
## 调用了：on_health_changed.emit()。
func setup(stats: UnitStats) -> void:
	# 把单位属性的 health 作为最大生命。
	max_health = stats.health
	# 初始时当前生命 = 最大生命（满血出生）。
	current_health = max_health
	# emit() 发出 on_health_changed 信号，通知血条等监听者初始化显示。
	on_health_changed.emit(current_health, max_health)


## 函数说明：对单位造成伤害，血量归零时触发死亡。
## 被谁调用：Unit._on_hurtbox_component_on_damaged（受击时）。
## 调用了：on_unit_hit.emit()、on_health_changed.emit()、on_unit_died.emit()、die()。
func take_damage(value: float) -> void:
	# 若当前生命已 ≤0（已死亡），直接返回，避免重复扣血与重复死亡。
	if current_health <= 0:
		return

	# 减去伤害值。
	current_health -= value
	# max(current_health, 0) 把生命下限截断为 0（不为负）。
	current_health = max(current_health, 0)

	# 发出受击信号与血量变化信号（供 UI / 其它逻辑响应）。
	on_unit_hit.emit()
	on_health_changed.emit(current_health, max_health)

	# 若生命已降到 0，进入死亡流程。
	if current_health <= 0:
		current_health = 0
		# 发出死亡信号（例如 Enemy 会据此广播掉落金币）。
		on_unit_died.emit()
		# 调用 die() 执行真正的死亡处理（释放节点）。
		die()


## 函数说明：治疗单位，恢复生命但不超过上限。
## 被谁调用：Player._on_hp_regen_timer_timeout、WeaponBehavior.apply_life_steal。
## 调用了：on_health_changed.emit()。
func heal(amount: float) -> void:
	# 已死亡则无法治疗，直接返回。
	if current_health <= 0:
		return

	# 增加治疗量。
	current_health += amount
	# min(current_health, max_health) 把生命上限截断为最大生命（不溢出）。
	current_health = min(current_health, max_health)
	# 发出血量变化信号，刷新血条显示。
	on_health_changed.emit(current_health, max_health)


## 函数说明：死亡处理，释放所属单位节点。
## 被谁调用：take_damage（血量归零时）。
## 调用了：owner.queue_free()。
func die() -> void:
	# owner 是本组件所挂载的父级单位节点；queue_free() 把它标记为待释放。
	owner.queue_free()
