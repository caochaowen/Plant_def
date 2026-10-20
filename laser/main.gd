extends Node2D
@onready var player: CharacterBody2D = $Player
@onready var glow_layer: CanvasLayer = $GlowLayer

func _ready() -> void:
	Engine.physics_ticks_per_second = 120
