extends Node
## =============================================================================
## SoundManager（音效管理器 / Autoload）
## -----------------------------------------------------------------------------
## 作用：全局音效播放单例。通过枚举 Sound 映射到具体音频资源，
##       并维护一组 AudioStreamPlayer 池，实现"取一个空闲播放器来播放"，
##       支持同屏多个音效叠加、随机音高避免机械重复。
## =============================================================================


## ---------------------------------------------------------------------------
## 音效枚举
## ---------------------------------------------------------------------------
## 音效类型枚举：ENEMY_HIT（敌人受击）/ FIRE（开火）/ UI（界面点击）。
## 用于 play_sound 通过 sound_dictionary 查找对应音频资源。
enum Sound {
	ENEMY_HIT,
	FIRE,
	UI
}

## 音效类型 → 音频资源（Resource）的映射表。
## 由 play_sound 根据 type 取用；ENEMY_HIT 用于 HitboxComponent 命中，
## FIRE 用于远程武器开火，UI 用于各类按钮点击/悬停。
var sound_dictionary: Dictionary[Sound, Resource] = {
	Sound.ENEMY_HIT: preload("uid://blonjlaa37md0"),
	Sound.FIRE: preload("uid://g72hyxdnaath"),
	Sound.UI: preload("uid://6nolwqlami52"),
}

## 音频播放器池（在编辑器里手动指定的一组 AudioStreamPlayer 节点）。
## 由 get_free_stream_player 遍历查找空闲播放器。
@export var stream_players: Array[AudioStreamPlayer]


## 函数说明：播放指定类型的音效。
## 被谁调用：
##   - HitboxComponent._on_area_entered（ENEMY_HIT）
##   - RangeBehavior.execute_attack（FIRE）
##   - ItemCard / SelectionCard / ShopCard / ShopPanel / UpgradeCard 等 UI 按钮（UI）
## 调用了：get_free_stream_player()、randf_range()、AudioStreamPlayer.play()。
func play_sound(type: int) -> void:
	# 先调用 get_free_stream_player() 从播放器池里取一个当前空闲的播放器。
	var stream := get_free_stream_player()
	# 若没有空闲播放器（返回 null），直接 return，本次音效不播放（避免中断已有音效）。
	if not stream:
		return

	# 用 type（Sound 枚举值）作为键，从 sound_dictionary 取出对应的音频资源。
	var audio := sound_dictionary[type]
	# 把音频资源赋给播放器的 stream 属性（播放器要播放的内容）。
	stream.stream = audio
	# 设置随机音高 pitch_scale（0.8~1.3），让每次播放音高略有不同，
	# 避免连续同音效听起来机械重复。randf_range(0.8, 1.3) 生成该区间随机浮点数。
	stream.pitch_scale = randf_range(0.8, 1.3)
	# play() 让该播放器开始播放当前 stream 音频。
	stream.play()


## 函数说明：在播放器池中查找并返回一个当前未在播放的 AudioStreamPlayer。
## 被谁调用：play_sound。
## 调用了：无（遍历 stream_players，读取 playing 属性）。
func get_free_stream_player() -> AudioStreamPlayer:
	# 遍历 stream_players 数组；`stream: AudioStreamPlayer` 是带类型的 for 循环变量。
	for stream: AudioStreamPlayer in stream_players:
		# playing 是 AudioStreamPlayer 的只读属性，表示是否正在播放；
		# 找到第一个未在播放的播放器就立即返回它。
		if not stream.playing:
			return stream

	# 所有播放器都在播放则返回 null，表示当前无空闲播放器。
	return null
