extends Control

@export var battlefield_scene: PackedScene
const AUDIO_SETTINGS_PATH: String = "user://audio_settings.cfg"

@onready var music_slider: HSlider = $OptionsPanel/MusicSlider
@onready var sfx_slider: HSlider = $OptionsPanel/SFXSlider

func _ready() -> void:
	$StartButton.pressed.connect(_on_start_pressed.bind(1))
	$CheckpointButton.pressed.connect(_on_start_pressed.bind(5))

	$CheckpointButton.visible = Progression.wave_5_unlocked
	$OptionsButton.pressed.connect(_open_options)
	$OptionsPanel/BackButton.pressed.connect(_close_options)
	$CreditsButton.pressed.connect(_open_credits)
	$CreditsPanel/BackButton.pressed.connect(_close_credits)

	_load_audio_settings()
	music_slider.value_changed.connect(_set_bus_volume.bind("Music"))
	sfx_slider.value_changed.connect(_set_bus_volume.bind("Sound Effects"))


func _on_start_pressed(starting_wave: int) -> void:
	Progression.requested_start_wave = starting_wave
	get_tree().change_scene_to_packed(battlefield_scene)
	
func _set_bus_volume(value: float, bus_name: StringName) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return

	AudioServer.set_bus_mute(bus_index, value <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(value, 0.001)))


func _load_audio_settings() -> void:
	var config := ConfigFile.new()
	config.load(AUDIO_SETTINGS_PATH)

	music_slider.value = float(config.get_value("audio", "music", 1.0))
	sfx_slider.value = float(config.get_value("audio", "sfx", 1.0))

	_set_bus_volume(music_slider.value, "Music")
	_set_bus_volume(sfx_slider.value, "Sound Effects")


func _close_options() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_slider.value)
	config.set_value("audio", "sfx", sfx_slider.value)
	config.save(AUDIO_SETTINGS_PATH)
	$OptionsPanel.hide()
	_set_main_menu_visible(true)

func _open_options() -> void:
	_set_main_menu_visible(false)
	$OptionsPanel.show()


func _set_main_menu_visible(show_menu: bool) -> void:
	$"The Graveyard Shift".visible = show_menu
	$StartButton.visible = show_menu
	$OptionsButton.visible = show_menu
	$CheckpointButton.visible = show_menu and Progression.wave_5_unlocked
	$CreditsButton.visible = show_menu

func _open_credits() -> void:
	_set_main_menu_visible(false)
	$CreditsPanel.show()


func _close_credits() -> void:
	$CreditsPanel.hide()
	_set_main_menu_visible(true)
