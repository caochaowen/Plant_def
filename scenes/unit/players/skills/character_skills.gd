extends Node
class_name CharacterSkills
## CharacterSkills（角色技能基类 / Node）
## 作用：定义两个技能（Q/E）的公共框架：冷却计时、体力消耗判定、输入触发，
##       以及对 HUD 的查询接口。具体技能效果由子类重写 _execute_skill_1/2。


## 技能 1 名称（显示用，可选）。
@export var skill_1_name := "Skill 1"
## 技能 2 名称。
@export var skill_2_name := "Skill 2"

## 技能 1 图标。
@export var skill_1_icon: Texture2D
## 技能 2 图标。
@export var skill_2_icon: Texture2D

## 技能 1 冷却时间（秒）。
@export var skill_1_cooldown := 3.0
## 技能 2 冷却时间（秒）。
@export var skill_2_cooldown := 3.0

## 技能 1 体力消耗。
@export var skill_1_stamina_cost := 20.0
## 技能 2 体力消耗。
@export var skill_2_stamina_cost := 20.0


var player: Player
var _skill_1_timer: Timer
var _skill_2_timer: Timer


func _ready() -> void:
	# Skills 作为玩家的子节点，get_parent() 即 Player。
	player = get_parent() as Player
	_skill_1_timer = _make_timer()
	_skill_2_timer = _make_timer()


func _make_timer() -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	add_child(timer)
	return timer


## 尝试施放技能 1（Q）。
func try_cast_skill_1() -> void:
	_try_cast(_skill_1_timer, skill_1_cooldown, skill_1_stamina_cost, _execute_skill_1)


## 尝试施放技能 2（E）。
func try_cast_skill_2() -> void:
	_try_cast(_skill_2_timer, skill_2_cooldown, skill_2_stamina_cost, _execute_skill_2)


func _try_cast(timer: Timer, cooldown: float, cost: float, exec: Callable) -> void:
	# 冷却未结束 / 体力不足则不能施放。
	if not timer.is_stopped():
		return
	if player.current_stamina < cost:
		return
	# 扣体力 → 执行技能 → 进入冷却。
	player.current_stamina -= cost
	exec.call()
	timer.wait_time = cooldown
	timer.start()


## 技能 1 具体效果（子类重写）。
func _execute_skill_1() -> void:
	pass


## 技能 2 具体效果（子类重写）。
func _execute_skill_2() -> void:
	pass


## HUD 查询：某个技能槽的剩余冷却时间（slot：0=技能1，1=技能2）。
func get_cooldown_time_left(slot: int) -> float:
	return (_skill_1_timer if slot == 0 else _skill_2_timer).time_left


## HUD 查询：某个技能槽的总冷却时间。
func get_cooldown_total(slot: int) -> float:
	return (_skill_1_timer if slot == 0 else _skill_2_timer).wait_time


## HUD 查询：某个技能槽的图标。
func get_icon(slot: int) -> Texture2D:
	return skill_1_icon if slot == 0 else skill_2_icon
