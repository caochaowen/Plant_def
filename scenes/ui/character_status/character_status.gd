extends Panel
class_name CharacterStatus


@onready var face: TextureRect = %Face
@onready var hp_value: Label = %HPValue
@onready var hp_bar: ProgressBar = %HPBar
@onready var stamina_value: Label = %StaminaValue
@onready var stamina_bar: ProgressBar = %StaminaBar

@onready var skill_1_icon: TextureRect = %Skill1Icon
@onready var skill_1_overlay: ColorRect = %Skill1Overlay
@onready var skill_1_cd: Label = %Skill1Cooldown
@onready var skill_2_icon: TextureRect = %Skill2Icon
@onready var skill_2_overlay: ColorRect = %Skill2Overlay
@onready var skill_2_cd: Label = %Skill2Cooldown


var _initialized := false


func _process(delta: float) -> void:
	if not is_instance_valid(Global.player):
		return

	# 玩家生成后首次初始化头像与技能图标。
	if not _initialized:
		_initialized = true
		setup_from_player()

	var p: Player = Global.player

	# 血量。
	hp_bar.value = p.health_component.current_health / p.health_component.max_health
	hp_value.text = str(p.health_component.current_health)

	# 体力。
	stamina_bar.value = p.current_stamina / p.stats.stamina
	stamina_value.text = str(int(p.current_stamina))

	# 技能冷却。
	update_skill_cooldown(0, skill_1_overlay, skill_1_cd)
	update_skill_cooldown(1, skill_2_overlay, skill_2_cd)


func setup_from_player() -> void:
	var p: Player = Global.player
	face.texture = p.stats.icon
	skill_1_icon.texture = p.skills.get_icon(0)
	skill_2_icon.texture = p.skills.get_icon(1)


func update_skill_cooldown(slot: int, overlay: Control, cd_label: Label) -> void:
	var left := Global.player.skills.get_cooldown_time_left(slot)
	var total := Global.player.skills.get_cooldown_total(slot)
	if left <= 0.0 or total <= 0.0:
		overlay.visible = false
		cd_label.visible = false
		return
	overlay.visible = true
	cd_label.visible = true
	# 遮罩高度比例 = 剩余 / 总冷却。
	overlay.scale.y = left / total
	cd_label.text = "%.1f" % left
