extends Node2D
class_name LaserBeam

## =============================================================================
## LaserBeam —— 射线激光子弹（把 laser 项目的镭射效果整合为"一种子弹"）
## -----------------------------------------------------------------------------
## 一个场景 + 一个脚本表现 4 种镭射效果，通过面板 `mode` 枚举切换。
## 激光的粗细 / 速度 / 长度 都做成 @export，可在 Inspector 面板直接调试。
## =============================================================================

## —— 激光模式枚举（对应 laser 项目的 4 个 .gd）——
enum LaserMode {
	FREEZE,   # 冻结激光 freeze_laser：射出一段，命中敌人造成一次伤害并消失
	MULTI,    # 多重激光 multi_laser：命中墙体后反射（需墙体碰撞层，见第 11 节）
	HOT,      # 灼热激光 hot_laser：持续照射，持续掉血
	BOOM,     # 爆裂激光 boom_laser：先蓄力，再瞬间爆发粗光束
}

## ---------------------------------------------------------------------------
## 面板可调参数（Inspector）
## ---------------------------------------------------------------------------
@export var mode: LaserMode = LaserMode.FREEZE          # 选择哪种镭射效果
@export var beam_width: float = 8.0                     # 激光粗细（像素）
@export var beam_speed: float = 4000.0                  # 激光延伸速度（像素/秒）
@export var beam_max_length: float = 1000.0             # 激光最大长度（像素）
@export var beam_color: Color = Color(0.878, 1.0, 1.0)  # 激光颜色

## ---------------------------------------------------------------------------
## 运行时参数（由 LaserBehavior.fire() 注入）
## ---------------------------------------------------------------------------
var damage: float = 1.0
var critical: bool = false
var knockback: float = 0.0
var source: Node2D           # 攻击来源（玩家），用于击退方向
var target: Node2D           # 追踪目标（HOT 模式每帧指向它）

## ---------------------------------------------------------------------------
## 内部状态
## ---------------------------------------------------------------------------
var direction: Vector2 = Vector2.RIGHT   # 发射方向（FREEZE/MULTI/BOOM 用）
var travel_distance: float = 0.0         # 已飞行距离（MULTI 反射用）
var shooting := false
var fading := false
var _fade_tween: Tween
var _hot_accum := 0.0                    # HOT 模式 DPS 累加器
var _boom_hit: Array = []                # BOOM 模式已命中的敌人（防重复扣血）
var _boom_charging := true
var _boom_releasing := false

## ---------------------------------------------------------------------------
## 节点引用
## ---------------------------------------------------------------------------
@onready var ray: RayCast2D = $Ray
@onready var line: Line2D = $Line2D
@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var shape_cast: ShapeCast2D = $ShapeCast        # BOOM 用
@onready var xuli_line: Line2D = $XuliLine               # BOOM 蓄力线
@onready var boom_line: Line2D = $BoomLine               # BOOM 爆发线


## =============================================================================
## 发射入口
## =============================================================================

## 函数说明：由 LaserBehavior.create_projectile 调用，注入方向/伤害等参数并启动。
func fire(new_direction: Vector2, new_damage: float, is_critical: bool,
		new_knockback: float, new_source: Node2D, new_target: Node2D) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	critical = is_critical
	knockback = new_knockback
	source = new_source
	target = new_target

	rotation = direction.angle()      # 让整条光束朝向发射方向（光束沿 +X 绘制）
	shooting = true
	_apply_visuals()

	# 按模式启用对应检测节点：射线模式用 RayCast2D，爆裂模式用 ShapeCast2D
	ray.enabled = mode != LaserMode.BOOM
	shape_cast.enabled = mode == LaserMode.BOOM
	particles.emitting = false
	_boom_hit.clear()
	_boom_charging = true
	_boom_releasing = false
	_hot_accum = 0.0
	travel_distance = 0.0


## 函数说明：根据面板参数设置线的颜色/粗细，并把所有线长度清零。
func _apply_visuals() -> void:
	line.default_color = beam_color
	line.width = beam_width
	xuli_line.default_color = beam_color
	xuli_line.width = beam_width * 4.0
	boom_line.default_color = beam_color
	boom_line.width = beam_width * 5.0

	line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	xuli_line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	boom_line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	ray.target_position = Vector2.ZERO
	shape_cast.target_position = Vector2.ZERO


## =============================================================================
## 主循环：按模式分发
## =============================================================================
func _physics_process(delta: float) -> void:
	if not shooting:
		return
	match mode:
		LaserMode.FREEZE:
			_process_freeze(delta)
		LaserMode.MULTI:
			_process_multi(delta)
		LaserMode.HOT:
			_process_hot(delta)
		LaserMode.BOOM:
			_process_boom(delta)


## ---------------------------------------------------------------------------
## 模式 1：FREEZE（冻结激光）
## ---------------------------------------------------------------------------
func _process_freeze(delta: float) -> void:
	# 光束向前延伸（不超过最大长度）
	ray.target_position.x = minf(ray.target_position.x + beam_speed * delta, beam_max_length)
	line.points[1].x = ray.target_position.x

	# 命中敌人：造成一次伤害，然后消失
	if ray.is_colliding():
		_try_damage(ray.get_collider())
		_fade_out()
		return
	# 达到最大长度：消失
	if ray.target_position.x >= beam_max_length:
		_fade_out()


## ---------------------------------------------------------------------------
## 模式 2：MULTI（多重/反射激光）
## ---------------------------------------------------------------------------
func _process_multi(delta: float) -> void:
	if travel_distance > beam_max_length:
		_fade_out()
		return

	if ray.is_colliding():
		if _try_damage(ray.get_collider()):
			# 命中敌人：终止本光束
			travel_distance = beam_max_length
			_fade_out()
		else:
			# 命中墙体：反射（要求墙体在 Ray 的 collision_mask 内，见第 11 节）
			shooting = false
			_fade_out()
			_reflect(ray.get_collision_point(), ray.get_collision_normal())
	else:
		ray.target_position.x = minf(ray.target_position.x + beam_speed * delta, beam_max_length)
		line.points[1].x = ray.target_position.x
		travel_distance += beam_speed * delta


## 函数说明：在命中点按反弹方向生成一条新光束（反射）。
func _reflect(hit_point: Vector2, normal: Vector2) -> void:
	var reflected := direction.bounce(normal).normalized()
	var scene := load("res://scenes/projectiles/projectile_laser_beam.tscn") as PackedScene
	var new_beam := scene.instantiate() as LaserBeam
	get_tree().root.add_child(new_beam)
	new_beam.global_position = hit_point
	new_beam.fire(reflected, damage, critical, knockback, source, target)
	new_beam.travel_distance = travel_distance


## ---------------------------------------------------------------------------
## 模式 3：HOT（灼热激光，持续照射）
## ---------------------------------------------------------------------------
func _process_hot(delta: float) -> void:
	# 持续指向追踪目标（若目标仍有效）
	if is_instance_valid(target):
		rotation = global_position.direction_to(target.global_position).angle()

	if ray.is_colliding():
		# 命中：光束停在命中点，粒子出现在命中点
		ray.target_position.x = global_position.distance_to(ray.get_collision_point())
		line.points[1].x = ray.target_position.x
		particles.global_position = ray.get_collision_point()
		particles.emitting = true
		# 持续伤害：按 DPS 累积，攒够 1 点扣一次（避免每帧都触发受击流程）
		_hot_accum += damage * delta
		if _hot_accum >= 1.0:
			var ticks := int(_hot_accum)
			_hot_accum -= float(ticks)
			_try_damage(ray.get_collider(), float(ticks))
	else:
		ray.target_position.x = minf(ray.target_position.x + beam_speed * delta, beam_max_length)
		line.points[1].x = ray.target_position.x
		particles.emitting = false

	if ray.target_position.x >= beam_max_length:
		_fade_out()


## ---------------------------------------------------------------------------
## 模式 4：BOOM（爆裂激光：蓄力 → 爆发）
## ---------------------------------------------------------------------------
func _process_boom(delta: float) -> void:
	if _boom_charging:
		# 蓄力阶段：xuli_line 缓慢增长到最大长度
		if xuli_line.points[1].x < beam_max_length:
			xuli_line.points[1].x = minf(
				xuli_line.points[1].x + beam_speed * 0.25 * delta,
				beam_max_length)
		else:
			_boom_charging = false
			_boom_releasing = true
	elif _boom_releasing:
		# 爆发阶段：boom_line 快速扫过，用 ShapeCast 检测并伤害敌人
		if shape_cast.target_position.x < beam_max_length:
			shape_cast.target_position.x = minf(
				shape_cast.target_position.x + beam_speed * delta,
				beam_max_length)
			boom_line.points[1].x = shape_cast.target_position.x
			particles.emitting = true
			for i in shape_cast.get_collision_count():
				var collider := shape_cast.get_collider(i)
				if collider is HurtboxComponent and not _boom_hit.has(collider):
					_boom_hit.append(collider)
					_try_damage(collider)
		else:
			_fade_out()


## =============================================================================
## 伤害与消失
## =============================================================================

## 函数说明：对命中对象造成伤害；命中敌人返回 true，否则返回 false。
##          通过构造一个轻量 HitboxComponent 并 emit 受击盒的 on_damaged 信号，
##          复用项目统一的受击管线（格挡/受击闪白/伤害文字/击退）。
func _try_damage(collider: Object, amount: float = -1.0) -> bool:
	if amount < 0.0:
		amount = damage
	var hurtbox := collider as HurtboxComponent
	if hurtbox == null or not is_instance_valid(hurtbox):
		return false

	var src := source if is_instance_valid(source) else self
	var hitbox := HitboxComponent.new()
	hitbox.setup(amount, critical, knockback, src)
	hurtbox.on_damaged.emit(hitbox)   # 走统一受击管线
	hitbox.free()
	return true


## 函数说明：渐隐所有光束线后销毁自身。
func _fade_out() -> void:
	if fading:
		return
	fading = true
	shooting = false
	particles.emitting = false
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(line, "width", 0.0, 0.3)
	_fade_tween.parallel().tween_property(xuli_line, "width", 0.0, 0.3)
	_fade_tween.parallel().tween_property(boom_line, "width", 0.0, 0.3)
	_fade_tween.tween_callback(queue_free)
