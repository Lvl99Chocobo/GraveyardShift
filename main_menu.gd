extends Control

@export var battlefield_scene: PackedScene


func _ready() -> void:
	$StartButton.pressed.connect(_on_start_pressed.bind(1))
	$CheckpointButton.pressed.connect(_on_start_pressed.bind(5))

	$CheckpointButton.visible = Progression.wave_5_unlocked


func _on_start_pressed(starting_wave: int) -> void:
	Progression.requested_start_wave = starting_wave
	get_tree().change_scene_to_packed(battlefield_scene)
