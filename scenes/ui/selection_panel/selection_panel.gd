extends Panel
class_name SelectionPanel
## =============================================================================
## SelectionPanel（角色/初始武器选择面板 / Panel）
## -----------------------------------------------------------------------------
## 作用：游戏开始前的选择界面。加载可选角色与初始武器卡片，玩家点选后把
##       选择结果写入 Global（main_player_selected / main_weapon_selected），
##       并在右侧展示角色详情；点击"继续"后发出 on_selection_completed 信号。
## =============================================================================


## 信号：选择完成（玩家点了继续且已选角色与武器）。连接到 Arena 开始游戏。
signal on_selection_completed


## ---------------------------------------------------------------------------
## 导出字段
## ---------------------------------------------------------------------------

## 可选角色列表（UnitStats 数组）。
@export var players: Array[UnitStats]

## 可选初始武器列表（ItemWeapon 数组）。
@export var start_weapons: Array[ItemWeapon]


## ---------------------------------------------------------------------------
## 节点引用
## ---------------------------------------------------------------------------

## 角色卡片容器（HBoxContainer）。
@onready var player_container: HBoxContainer = %PlayerContainer

## 武器卡片容器（HBoxContainer）。
@onready var weapon_container: HBoxContainer = %WeaponContainer

## 角色详情：图标控件。
@onready var player_icon: TextureRect = %PlayerIcon

## 角色详情：名称标签。
@onready var player_name: Label = %PlayerName

## 角色详情：标题标签。
@onready var player_title: Label = %PlayerTitle

## 角色详情：描述富文本。
@onready var player_description: RichTextLabel = %PlayerDescription


## 函数说明：就绪时清空容器、隐藏详情并加载角色/武器卡片。
## 被谁调用：由 Godot 引擎在节点进入场景树时调用。
## 调用了：show_player_info()、load_players()、load_weapons()。
func _ready() -> void:
	# 清空角色容器与武器容器的所有子节点（get_children() 返回子节点数组，逐个 queue_free）。
	for child in player_container.get_children(): child.queue_free()
	for child in weapon_container.get_children(): child.queue_free()

	# 初始隐藏角色详情区。
	show_player_info(false)
	# 加载角色卡片与武器卡片。
	load_players()
	load_weapons()


## 函数说明：根据 players 列表生成角色选择卡片。
## 被谁调用：_ready。
## 调用了：Global.SELECTION_CARD_SCENE.instantiate()、card.set_icon()。
func load_players() -> void:
	# 无可选角色则直接返回。
	if players.is_empty():
		return

	# 遍历每个角色数据。
	for player: UnitStats in players:
		# 实例化选择卡片（SelectionCard）。
		var card: SelectionCard = Global.SELECTION_CARD_SCENE.instantiate()
		# card.pressed.connect(_on_player_selected.bind(player))：
		#   - pressed 是 Button 点击信号；
		#   - bind(player) 把该角色数据作为参数预先绑定到回调，这样点击时回调能知道是哪个角色。
		card.pressed.connect(_on_player_selected.bind(player))
		# 把卡片加入角色容器，并设置其图标。
		player_container.add_child(card)
		card.set_icon(player.icon)


## 函数说明：根据 start_weapons 列表生成武器选择卡片。
## 被谁调用：_ready。
## 调用了：Global.SELECTION_CARD_SCENE.instantiate()。
func load_weapons() -> void:
	# 无可选武器则直接返回。
	if start_weapons.is_empty():
		return

	# 遍历每把武器数据。
	for weapon: ItemWeapon in start_weapons:
		# 实例化选择卡片，连接点击信号并绑定该武器数据。
		var card: SelectionCard = Global.SELECTION_CARD_SCENE.instantiate()
		card.pressed.connect(_on_weapon_selected.bind(weapon))
		# 加入武器容器并直接设置按钮图标（icon 是 Button 属性）。
		weapon_container.add_child(card)
		card.icon = weapon.item_icon


## 函数说明：设置角色详情区各控件的可见性。
## 被谁调用：_ready、_on_player_selected。
## 调用了：无（直接赋值 visible）。
func show_player_info(value: bool) -> void:
	# 把图标/名称/标题/描述四个控件的 visible 属性统一设为 value，控制详情区显隐。
	player_icon.visible = value
	player_name.visible = value
	player_title.visible = value
	player_description.visible = value


## 函数说明：玩家选中某个角色卡片的回调，记录选择并展示详情。
## 被谁调用：由角色卡片的 pressed 信号触发。
## 调用了：show_player_info()。
func _on_player_selected(player: UnitStats) -> void:
	# 把选中的角色数据写入全局，供后续实例化玩家使用。
	Global.main_player_selected = player
	# 显示角色详情区。
	show_player_info(true)

	# 填充详情：图标、名称，以及用 BBCode 拼出的属性描述（生命/伤害/速度/幸运/格挡）。
	player_icon.texture = player.icon
	player_name.text = player.name
	player_description.text = "[code]Health: [color=green]%s[/color]\nDamage: [color=green]%s[/color]\nSpeed: [color=green]%s[/color]\nLuck: [color=green]%s[/color]\nBlock Chance: [color=green]%s%%[/color][/code]" % [player.health, player.damage, player.speed, player.luck, player.block_chance]


## 函数说明：玩家选中某个武器卡片的回调，记录初始武器选择。
## 被谁调用：由武器卡片的 pressed 信号触发。
## 调用了：无。
func _on_weapon_selected(weapon: ItemWeapon) -> void:
	# 把选中的武器数据写入全局，作为玩家的初始武器。
	Global.main_weapon_selected = weapon


## 函数说明："继续"按钮回调，校验选择并发出完成信号。
## 被谁调用：由"继续"按钮的 pressed 信号触发。
## 调用了：SoundManager.play_sound()、on_selection_completed.emit()、hide()。
func _on_continue_buttom_pressed() -> void:
	# 播放 UI 点击音效。
	SoundManager.play_sound(SoundManager.Sound.UI)

	# 若角色或武器尚未选择，直接返回（不允许继续）。
	if not Global.main_player_selected and not Global.main_weapon_selected:
		return

	# 发出选择完成信号（Arena 收到后开始游戏）。
	on_selection_completed.emit()
	# 隐藏本选择面板。
	hide()
