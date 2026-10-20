extends Sprite2D
class_name EnemySpawnEffect
## =============================================================================
## EnemySpawnEffect（敌人出生特效 / Sprite2D）
## -----------------------------------------------------------------------------
## 作用：敌人刷出前的提示特效。仅持有一个 AnimationPlayer 引用，
##       由 Spawner.spawn_enemy 实例化后播放动画，动画结束后被释放。
## 注意：该节点本身没有方法逻辑，纯视觉表现。
## =============================================================================


## 动画播放器引用（负责播放出生动画）。
## 由 Spawner.spawn_enemy 读取 anim_player 并 await 其 animation_finished 信号。
@onready var anim_player: AnimationPlayer = $AnimationPlayer
