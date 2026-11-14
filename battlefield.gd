extends Node2D

const ENEMY_SCENE = preload("res://enemy.tscn")

var enemies: Array[Node2D] = []
var wave_number: int = 0
var heal_cooldown: float = 1.2
var heal_cooldown_remaining: float = 0.0
var game_over: bool = false
var group_heal_amount: float = 30.0
var group_heal_cooldown: float = 8.0
var group_heal_remaining: float = 0.0
var run_kills: int = 0
var run_gold: int = 0
var between_waves: bool = false
var wave_delay_remaining: float = 0.0
var wave_types: Array[String] = [
	"Assault",
	"Crossfire",
	"Ritual"
]
var resurrection_remaining: int = 0
var next_hero_hit_sound_ms: int = 0
enum TutorialStep { OFF, CLICK_HEAL, GROUP_HEAL, FOCUS_ENEMY }

var tutorial_step: TutorialStep = TutorialStep.OFF
var first_upgrade_bought_this_run: bool = false
const AUDIO_SETTINGS_PATH: String = "user://audio_settings.cfg"

@onready var music_slider: HSlider = $HUD/OptionsPanel/MusicSlider
@onready var sfx_slider: HSlider = $HUD/OptionsPanel/SFXSlider
@onready var upgrade_tutorial_panel: Panel = $HUD/UpgradeTutorialPanel
@onready var upgrade_tutorial_hint: Label = $HUD/UpgradeTutorialPanel/Hint
@onready var tutorial_target: Label = $TutorialTarget
@onready var hero_hit_sound: AudioStreamPlayer = $HeroHitSound
@onready var resurrection_upgrade_button: Button = $HUD/SkillTreePanel/ResurrectionUpgradeButton
@export var hail_arrow_texture: Texture2D
@export var fireball_texture: Texture2D
@onready var tank = $Tank
@onready var heroes: Array = [$Tank, $DPS1, $DPS2]
@onready var gold_label: Label = $HUD/GoldLabel
@onready var wave_label: Label = $HUD/WaveLabel
@onready var heal_cooldown_bar: ProgressBar = $HUD/HealCooldownBar
@onready var heal_cooldown_label: Label = $HUD/HealCooldownLabel
@onready var game_over_panel: Panel = $HUD/GameOverPanel
@onready var restart_button: Button = $HUD/GameOverPanel/RestartButton
@onready var group_heal_button: Button = $HUD/GroupHealButton
@onready var run_stats_label: Label = $HUD/GameOverPanel/RunStatsLabel
@onready var wave_status_label: Label = $HUD/WaveStatusLabel
@onready var controls_hint: Label = $HUD/ControlsHint
@onready var main_menu_button: Button = $HUD/GameOverPanel/MainMenuButton
@onready var heal_upgrade_button: Button = $HUD/SkillTreePanel/HealUpgradeButton
@onready var dps1_upgrade_button: Button = $HUD/SkillTreePanel/DPS1UpgradeButton
@onready var dps2_upgrade_button: Button = $HUD/SkillTreePanel/DPS2UpgradeButton
@onready var skill_tree_panel: Panel = $HUD/SkillTreePanel
@onready var skill_tree_button: Button = $HUD/GameOverPanel/SkillTreeButton
@onready var skill_tree_back_button: Button = $HUD/SkillTreePanel/BackButton
@onready var skill_tree_gold_label: Label = $HUD/SkillTreePanel/SkillTreeGoldLabel
@onready var tank_hp_upgrade_button: Button = $HUD/SkillTreePanel/TankHPUpgradeButton
@onready var dps1_hp_upgrade_button: Button = $HUD/SkillTreePanel/DPS1HPUpgradeButton
@onready var dps2_hp_upgrade_button: Button = $HUD/SkillTreePanel/DPS2HPUpgradeButton
@onready var base_dps_hp: Array[float] = [$DPS1.max_health, $DPS2.max_health]
@onready var checkpoint_button: Button = $HUD/GameOverPanel/CheckpointButton
@onready var base_tank_hp: float = tank.max_health
@onready var resurrection_icon: TextureRect = $HUD/ResurrectionIcon
@onready var resurrection_count: Label = $HUD/ResurrectionCount
@onready var tank_damage_upgrade_button: Button = $HUD/SkillTreePanel/TankDamageUpgradeButton
@onready var base_tank_damage: float = tank.attack_damage
@onready var heal_sound: AudioStreamPlayer = $HealSound
@onready var enemy_hit_sound: AudioStreamPlayer = $EnemyHitSound
@onready var fireball_impact_sound: AudioStreamPlayer = $FireballImpactSound
@onready var arrow_rain_impact_sound: AudioStreamPlayer = $ArrowRainImpactSound
@onready var ritual_impact_sound: AudioStreamPlayer = $RitualImpactSound
@onready var group_heal_sound: AudioStreamPlayer = $GroupHealSound
@onready var tutorial_panel: Panel = $HUD/TutorialPanel
@onready var graveyard: Node2D = $Graveyard
@onready var graveyard_color: Color = graveyard.modulate
@onready var hero_death_sound: AudioStreamPlayer = $HeroDeathSound

func update_heal_cooldown_visual() -> void:
	var progress: float = 1.0 - (
		heal_cooldown_remaining / heal_cooldown
	)

	heal_cooldown_bar.value = progress

	if heal_cooldown_remaining <= 0.0:
		heal_cooldown_label.text = "Heal ready"
	else:
		heal_cooldown_label.text = "Recharging..."

func update_hud() -> void:
	gold_label.text = "Gold: %d" % Progression.gold
	wave_label.text = "Wave: %d — %s" % [
		wave_number,
		get_wave_type(wave_number)
	]

	wave_label.text = "Wave: %d — %s" % [
		wave_number,
		get_wave_type(wave_number)
	]

	var cost: int = Progression.get_heal_upgrade_cost()

	heal_upgrade_button.tooltip_text = (
		"Healing Upgrade — %d gold\n\n" % cost
	) + heal_upgrade_button.tooltip_text
	heal_upgrade_button.disabled = (
		not game_over or Progression.gold < cost
	)

	var main_heal: float = Progression.get_healing_per_click()
	var group_heal: float = 30.0 + (main_heal - 30.0) * 0.5

	heal_upgrade_button.tooltip_text = (
		"Healing Upgrade — %d gold\n\n"
		+ "Improves healing for your next run.\n\n"
		+ "Main Heal: %.0f → %.0f HP (+6)\n"
		+ "Group Heal: %.0f → %.0f HP per hero (+3)"
	) % [cost, main_heal, main_heal + 6.0, group_heal, group_heal + 3.0]
	
	var dps_names: Array[String] = ["Archer", "Mage"]
	var dps_buttons: Array[Button] = [
		dps1_upgrade_button,
		dps2_upgrade_button
	]

	for index in range(dps_buttons.size()):
		var button: Button = dps_buttons[index]
		var price: int = Progression.get_dps_upgrade_cost(index)
		var damage: float = Progression.get_dps_damage(index)

		button.disabled = not game_over or Progression.gold < price

		button.tooltip_text = (
			"%s Damage — %d gold\n\n"
			+ "Improves this hero's damage per attack for your next run.\n\n"
			+ "Damage per attack: %.0f → %.0f (+1)"
		) % [dps_names[index], price, damage, damage + 1.0]
	
	skill_tree_gold_label.text = "Gold: %d" % Progression.gold
	
	var tank_hp_cost: int = Progression.get_tank_hp_upgrade_cost()
	var current_tank_hp: float = base_tank_hp + Progression.get_tank_hp_bonus()

	tank_hp_upgrade_button.disabled = (
		not game_over or Progression.gold < tank_hp_cost
	)

	tank_hp_upgrade_button.tooltip_text = (
		"Knight Vitality — %d gold\n\n"
		+ "Improves Knight health for your next run.\n\n"
		+ "Knight Max HP: %.0f → %.0f (+25)"
	) % [tank_hp_cost, current_tank_hp, current_tank_hp + 25.0]
	
	var hp_buttons: Array[Button] = [
		dps1_hp_upgrade_button,
		dps2_hp_upgrade_button
	]

	for index in range(hp_buttons.size()):
		var button: Button = hp_buttons[index]
		var price: int = Progression.get_dps_hp_upgrade_cost(index)
		var current_hp: float = base_dps_hp[index] + Progression.get_dps_hp_bonus(index)
		var hp_gain: float = Progression.DPS_HP_PER_UPGRADE

		button.disabled = not game_over or Progression.gold < price
		button.tooltip_text = (
			"%s Vitality — %d gold\n\n"
			+ "Improves this hero's health for your next run.\n\n"
			+ "Max HP: %.0f → %.0f (+%.0f)"
		) % [dps_names[index], price, current_hp, current_hp + hp_gain, hp_gain]
		
	var resurrection_cost: int = Progression.get_resurrection_cost()
	var resurrection_level: int = Progression.resurrection_level

	resurrection_upgrade_button.disabled = (
		not game_over or Progression.gold < resurrection_cost
	)
	resurrection_upgrade_button.tooltip_text = (
		"Resurrection — %d gold\n\n"
		+ "Click a fallen hero to revive them at 50%% HP.\n"
		+ "Uses per run: %d → %d (+1)"
	) % [resurrection_cost, resurrection_level, resurrection_level + 1]

	var show_resurrection: bool = (
		resurrection_level > 0
		and not game_over
		and tutorial_step == TutorialStep.OFF
	)
	resurrection_icon.visible = show_resurrection
	resurrection_count.visible = show_resurrection
	resurrection_icon.modulate.a = 1.0 if resurrection_remaining > 0 else 0.35
	resurrection_count.text = "×%d" % resurrection_remaining
	var tank_damage_cost: int = Progression.get_tank_damage_upgrade_cost()
	var current_tank_damage: float = base_tank_damage + Progression.get_tank_damage_bonus()

	tank_damage_upgrade_button.disabled = (
		not game_over or Progression.gold < tank_damage_cost
	)
	tank_damage_upgrade_button.tooltip_text = (
		"Knight Damage — %d gold\n\n"
		+ "Increases the Knight's damage per attack next run.\n\n"
		+ "Damage per attack: %.0f → %.0f (+1)"
	) % [tank_damage_cost, current_tank_damage, current_tank_damage + 1.0]
	
func _ready() -> void:
	heal_upgrade_button.pressed.connect(_on_heal_upgrade_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	checkpoint_button.pressed.connect(_on_restart_pressed.bind(5))
	dps1_upgrade_button.pressed.connect(_on_dps_upgrade_pressed.bind(0))
	dps2_upgrade_button.pressed.connect(_on_dps_upgrade_pressed.bind(1))
	group_heal_button.pressed.connect(_on_group_heal_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	skill_tree_button.pressed.connect(_on_skill_tree_pressed)
	skill_tree_back_button.pressed.connect(_on_skill_tree_back_pressed)
	skill_tree_panel.hide()
	tank_hp_upgrade_button.pressed.connect(_on_tank_hp_upgrade_pressed)
	tank.max_health = base_tank_hp + Progression.get_tank_hp_bonus()
	tank.health = tank.max_health
	tank.update_health_visual()
	dps1_hp_upgrade_button.pressed.connect(_on_dps_hp_upgrade_pressed.bind(0))
	dps2_hp_upgrade_button.pressed.connect(_on_dps_hp_upgrade_pressed.bind(1))
	$DPS1.hail_of_arrows_requested.connect(_on_hail_of_arrows_requested)
	$DPS2.fireball_requested.connect(_on_fireball_requested)
	resurrection_upgrade_button.pressed.connect(_on_resurrection_upgrade_pressed)
	resurrection_remaining = Progression.resurrection_level
	tank_damage_upgrade_button.pressed.connect(_on_tank_damage_upgrade_pressed)
	tank.attack_damage = base_tank_damage + Progression.get_tank_damage_bonus()
	$HUD/OptionsButton.pressed.connect(_open_options)
	$HUD/OptionsPanel/BackButton.pressed.connect(_close_options)

	_load_audio_settings()
	music_slider.value_changed.connect(_set_bus_volume.bind("Music"))
	sfx_slider.value_changed.connect(_set_bus_volume.bind("Sound Effects"))
	upgrade_tutorial_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dps_heroes: Array = [$DPS1, $DPS2]

	for index in range(dps_heroes.size()):
		var hero = dps_heroes[index]
		hero.max_health = base_dps_hp[index] + Progression.get_dps_hp_bonus(index)
		hero.health = hero.max_health
		hero.update_health_visual()


	for hero in heroes:
		hero.healing_per_click = Progression.get_healing_per_click()
		hero.heal_requested.connect(_on_hero_heal_requested)
		hero.died.connect(_on_hero_died)


	game_over_panel.hide()
	$DPS1.attack_damage = Progression.get_dps_damage(0)
	$DPS2.attack_damage = Progression.get_dps_damage(1)
	group_heal_amount = 30.0 + (
		Progression.get_healing_per_click() - 30.0
	) * 0.5
	group_heal_button.tooltip_text = (
		"Restores %.0f HP to each living hero.\n"
		+ "Cooldown: %.0f seconds."
	) % [group_heal_amount, group_heal_cooldown]
	update_wave_status()
	if Progression.requested_start_wave == 5 and Progression.wave_5_unlocked:
		wave_number = 4

	Progression.requested_start_wave = 1
	if wave_number == 0 and not Progression.tutorial_completed:
		begin_tutorial()
	else:
		start_wave()

func _on_hero_died() -> void:
	if game_over:
		return

	if not hero_death_sound.playing:
		hero_death_sound.play()

	for hero in heroes:
		if not hero.is_dead:
			return

	# Laat je bestaande Game Over-code vanaf hier staan.

	game_over = true
	$HUD/OptionsButton.hide()
	update_tutorial_appearance()
	# Laat de rest van je bestaande Game Over-code hier staan.
	update_wave_status()
	run_stats_label.text = (
		"Wave reached: %d\n"
		+ "Best wave: %d\n"
		+ "Enemies defeated: %d\n"
		+ "Gold earned: %d"
	) % [
		wave_number,
		Progression.best_wave,
		run_kills,
		run_gold
	]
	update_group_heal_visual()
	checkpoint_button.disabled = not Progression.wave_5_unlocked
	checkpoint_button.text = (
		"Start at Wave 5" if Progression.wave_5_unlocked else "Wave 5 (Locked)"
	)
	checkpoint_button.tooltip_text = "Clear Wave 4 to unlock."
	update_hud()

	heal_cooldown_label.hide()
	heal_cooldown_bar.hide()
	group_heal_button.hide()
	controls_hint.hide()

	for hero in heroes:
		hero.set_process(false)
	
	for enemy in enemies:
		enemy.stop_attacking()

	await get_tree().create_timer(1.0).timeout

	game_over_panel.show()
	update_upgrade_tutorial()

func _on_restart_pressed(starting_wave: int = 1) -> void:
	Progression.requested_start_wave = starting_wave
	get_tree().reload_current_scene()

func _process(delta: float) -> void:
	if game_over:
		return

	heal_cooldown_remaining = maxf(
		heal_cooldown_remaining - delta,
		0.0
	)

	group_heal_remaining = maxf(
		group_heal_remaining - delta,
		0.0
	)

	update_heal_cooldown_visual()
	update_group_heal_visual()
	if between_waves:
		wave_delay_remaining = maxf(
			wave_delay_remaining - delta,
			0.0
		)

		if wave_delay_remaining <= 0.0:
			between_waves = false
			start_wave()

	update_wave_status()

func _on_group_heal_pressed() -> void:
	if game_over or group_heal_remaining > 0.0:
		return
	if tutorial_step == TutorialStep.CLICK_HEAL:
		return

	var has_wounded_hero: bool = false

	for hero in heroes:
		if not hero.is_dead and hero.health < hero.max_health:
			has_wounded_hero = true
			break

	if not has_wounded_hero:
		return

	group_heal_sound.play()

	for hero in heroes:
		hero.heal(group_heal_amount)

	group_heal_remaining = group_heal_cooldown
	update_group_heal_visual()
	if tutorial_step == TutorialStep.GROUP_HEAL:
		tutorial_step = TutorialStep.FOCUS_ENEMY
		Progression.tutorial_completed = true
		Progression.save_progress()

		heal_cooldown_remaining = 0.0
		group_heal_remaining = 0.0
		update_heal_cooldown_visual()
		update_group_heal_visual()

		start_wave()
	
func update_group_heal_visual() -> void:
	group_heal_button.disabled = (
		game_over or group_heal_remaining > 0.0
	)

	if group_heal_remaining > 0.0:
		group_heal_button.text = "Group Heal (%.1fs)" % group_heal_remaining
	else:
		group_heal_button.text = "Group Heal [Space]"

func _on_hero_heal_requested(hero: Node2D) -> void:
	if game_over:
		return
	if tutorial_step == TutorialStep.GROUP_HEAL:
		return

	if hero.is_dead:
		if resurrection_remaining > 0:
			resurrection_remaining -= 1
			hero.resurrect()
			update_hud()
		return

	if heal_cooldown_remaining > 0.0 or hero.health >= hero.max_health:
		return

	hero.heal(hero.healing_per_click)
	heal_sound.pitch_scale = randf_range(0.94, 1.06)
	heal_sound.play()
	heal_cooldown_remaining = heal_cooldown
	update_heal_cooldown_visual()
	if tutorial_step == TutorialStep.CLICK_HEAL and hero == tank:
		tutorial_step = TutorialStep.GROUP_HEAL
		tutorial_target.hide()

		$DPS1.take_damage(20.0)
		$DPS2.take_damage(20.0)

		controls_hint.text = (
			"The Archer and Mage are both injured.\n"
			+ "Press Space to heal the party"
		)

func _on_heal_upgrade_pressed() -> void:
	if game_over and Progression.buy_heal_upgrade():
		on_upgrade_purchased()

	Progression.buy_heal_upgrade()
	update_hud()

func start_wave() -> void:
	if game_over:
		return

	wave_number += 1
	controls_hint.visible = tutorial_step == TutorialStep.FOCUS_ENEMY

	if controls_hint.visible:
		controls_hint.text = (
			"Right-click an enemy to focus your attacks.\n"
			+ "The thicker bar shows your target."
		)
	update_tutorial_appearance()
	var current_wave_type: String = get_wave_type(wave_number)

	if wave_number > Progression.best_wave:
		Progression.best_wave = wave_number
		Progression.save_progress()

	update_hud()
	var wave_health: float = 60.0 + (wave_number - 1) * 15.0
	var wave_damage: float = 8.0 + (wave_number - 1) * 1.0

	var spawn_positions: Array[Vector2] = [
		Vector2(280, 105),
		Vector2(320, 95),
		Vector2(360, 105)
	]

	for index in range(spawn_positions.size()):
		var enemy = ENEMY_SCENE.instantiate()

		enemy.position = spawn_positions[index]
		enemy.max_health = wave_health
		enemy.fallback_target = tank

		var attacks_dps: bool = false
		var is_ritual_wave: bool = current_wave_type == "Ritual"

		if is_ritual_wave:
			enemy.target = tank

			if index == 2:
				enemy.is_ritual = true

		elif current_wave_type == "Crossfire":
			# Crossfire
			if index == 0:
				enemy.target = heroes[1]
				attacks_dps = true
			elif index == 2:
				enemy.target = heroes[2]
				attacks_dps = true
			else:
				enemy.target = tank

		else:
			# Assault
			if index == 2:
				enemy.target = heroes[2]
				attacks_dps = true
			else:
				enemy.target = tank

		if enemy.is_ritual:
			enemy.damage = wave_damage * 2.2
			enemy.modulate = Color.WHITE
		elif attacks_dps:
			enemy.damage = wave_damage * 0.6
		else:
			enemy.damage = wave_damage

		enemy.target_requested.connect(_on_enemy_target_requested)

		enemy.died.connect(_on_enemy_died.bind(enemy))
		enemy.ritual_impacted.connect(_on_ritual_impacted)
		

		enemies.append(enemy)
		enemy.party = heroes
		add_child(enemy)

	assign_targets()


func assign_targets(preferred_target: Node2D = null) -> void:
	var next_target: Node2D = null

	if is_instance_valid(preferred_target) and enemies.has(preferred_target):
		next_target = preferred_target
	elif not enemies.is_empty():
		next_target = enemies[0]

	for hero in heroes:
		hero.attack_target = next_target

	for enemy in enemies:
		enemy.set_focused(enemy == next_target)


func _on_enemy_died(enemy: Node2D) -> void:
	enemies.erase(enemy)
	if enemies.size() == 1 and not game_over:
		enemies[0].enrage()

	run_kills += 1
	run_gold += 5

	Progression.gold += 5
	if wave_number == 4 and enemies.is_empty():
		Progression.wave_5_unlocked = true
	Progression.save_progress()
	update_hud()

	assign_targets(heroes[0].attack_target)

	if enemies.is_empty() and not game_over:
		between_waves = true
		wave_delay_remaining = 2.0
		update_wave_status()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_R:
			get_tree().reload_current_scene()

func _on_dps_upgrade_pressed(index: int) -> void:
	if game_over and Progression.buy_dps_upgrade(index):
		on_upgrade_purchased()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("group_heal"):
		_on_group_heal_pressed()
		get_viewport().set_input_as_handled()

func update_wave_status() -> void:
	wave_status_label.visible = between_waves and not game_over

	if between_waves:
		var next_wave: int = wave_number + 1

		wave_status_label.text = "Next: %s — %.1fs" % [
			get_wave_type(next_wave),
			wave_delay_remaining
		]

func get_wave_type(number: int) -> String:
	while wave_types.size() < number:
		var next_types: Array[String] = [
			"Assault",
			"Crossfire",
			"Ritual"
		]

		next_types.shuffle()

		if next_types[0] == wave_types[-1]:
			var first_type: String = next_types[0]
			next_types[0] = next_types[1]
			next_types[1] = first_type

		wave_types.append_array(next_types)

	return wave_types[number - 1]

func _on_enemy_target_requested(enemy: Node2D) -> void:
	if game_over or enemy.is_dead:
		return

	assign_targets(enemy)
	if tutorial_step == TutorialStep.FOCUS_ENEMY:
		tutorial_step = TutorialStep.OFF
	update_tutorial_appearance()

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_skill_tree_pressed() -> void:
	if not game_over:
		return

	game_over_panel.hide()
	skill_tree_panel.show()
	update_upgrade_tutorial()
	update_hud()

func _on_skill_tree_back_pressed() -> void:
	skill_tree_panel.hide()
	game_over_panel.show()
	update_upgrade_tutorial()

func _on_tank_hp_upgrade_pressed() -> void:
	if game_over and Progression.buy_tank_hp_upgrade():
		on_upgrade_purchased()

func _on_dps_hp_upgrade_pressed(index: int) -> void:
	if game_over and Progression.buy_dps_hp_upgrade(index):
		on_upgrade_purchased()

func _on_hail_of_arrows_requested(damage: float) -> void:
	if game_over or enemies.is_empty():
		return

	var targets: Array[Node2D] = enemies.duplicate()
	var landing_area := Rect2(targets[0].position, Vector2.ZERO)

	for enemy in targets:
		landing_area = landing_area.expand(enemy.position)
		spawn_hail_arrow(enemy.position, randf_range(0.0, 0.14))

	landing_area = landing_area.grow(12.0)

	for index in range(12 - targets.size()):
		var landing_position := Vector2(
			randf_range(landing_area.position.x, landing_area.end.x),
			randf_range(landing_area.position.y, landing_area.end.y)
		)
		spawn_hail_arrow(landing_position, randf_range(0.0, 0.14))

	await get_tree().create_timer(0.36).timeout

	if game_over:
		return

	var played_impact: bool = false

	for enemy in targets:
		if is_instance_valid(enemy) and enemies.has(enemy):
			if not played_impact:
				arrow_rain_impact_sound.play()
				played_impact = true

			enemy.take_damage(damage)


func spawn_hail_arrow(landing_position: Vector2, delay: float) -> void:
	var arrow := Sprite2D.new()
	arrow.texture = hail_arrow_texture
	arrow.position = landing_position + Vector2(-18.0, -54.0)
	arrow.rotation = deg_to_rad(-18.0)
	arrow.z_index = 5
	arrow.hide()
	add_child(arrow)

	var fall := arrow.create_tween()
	fall.tween_interval(delay)
	fall.tween_callback(arrow.show)
	fall.tween_property(arrow, "position", landing_position, 0.22)
	fall.tween_interval(0.08)
	fall.tween_callback(arrow.queue_free)

func _on_fireball_requested(target: Node2D, damage: float) -> void:
	if game_over or not is_instance_valid(target):
		return

	var start_position: Vector2 = to_local($DPS2.global_position)
	var impact_position: Vector2 = to_local(target.global_position)

	var fireball := Sprite2D.new()
	fireball.texture = fireball_texture
	fireball.position = start_position
	fireball.rotation = (impact_position - start_position).angle()
	fireball.z_index = 5
	add_child(fireball)

	var flight := fireball.create_tween()
	flight.tween_property(fireball, "position", impact_position, 0.25)
	await flight.finished

	fireball.queue_free()

	if not game_over and is_instance_valid(target) and enemies.has(target):
		fireball_impact_sound.play()
		target.take_damage(damage)

func _on_resurrection_upgrade_pressed() -> void:
	if game_over and Progression.buy_resurrection():
		on_upgrade_purchased()

func _on_tank_damage_upgrade_pressed() -> void:
	if game_over and Progression.buy_tank_damage_upgrade():
		on_upgrade_purchased()

func _on_enemy_hit_received() -> void:
	if enemy_hit_sound.playing:
		return

	enemy_hit_sound.pitch_scale = randf_range(0.94, 1.06)
	enemy_hit_sound.play()


func _on_hero_hit_received() -> void:
	var now_ms: int = Time.get_ticks_msec()
	if hero_hit_sound.playing or now_ms < next_hero_hit_sound_ms:
		return

	next_hero_hit_sound_ms = now_ms + 220
	hero_hit_sound.pitch_scale = randf_range(0.94, 1.06)
	hero_hit_sound.play()

func _on_ritual_impacted() -> void:
	ritual_impact_sound.play()

func begin_tutorial() -> void:
	tutorial_step = TutorialStep.CLICK_HEAL

	controls_hint.text = (
		"Your party attacks automatically. Your job is to keep them alive.\n"
		+ "Left-click the injured Knight to heal."
	)
	update_tutorial_appearance()

	tutorial_target.position = tank.position + Vector2(-70, -48)
	tutorial_target.show()

	await get_tree().create_timer(0.5).timeout
	tank.take_damage(20.0)
	
func update_tutorial_appearance() -> void:
	var active: bool = tutorial_step != TutorialStep.OFF and not game_over

	tutorial_panel.visible = active
	controls_hint.visible = active

	graveyard.modulate = graveyard_color
	if active:
		graveyard.modulate = graveyard_color * Color(0.55, 0.55, 0.55, 1.0)
	update_hud()

func update_upgrade_tutorial() -> void:
	var show_hint: bool = game_over and (
		not Progression.upgrade_tutorial_completed or first_upgrade_bought_this_run
	)
	upgrade_tutorial_panel.visible = show_hint

	if not show_hint:
		return

	if skill_tree_panel.visible:
		upgrade_tutorial_panel.position = Vector2(100, 8)
		upgrade_tutorial_panel.size = Vector2(440, 62)

		if first_upgrade_bought_this_run:
			upgrade_tutorial_hint.text = (
				"Upgrade purchased! Press Back, then start a new run."
			)
		elif Progression.gold < Progression.get_heal_upgrade_cost():
			upgrade_tutorial_hint.text = (
				"Hover over an icon to see its cost and effect.\n"
				+ "Need more gold? Press Back and play another run."
			)
		else:
			upgrade_tutorial_hint.text = (
   			 "Hover over an icon for its price and effect.\n"
				+ "Click to buy an upgrade for future runs."
)
	else:
		upgrade_tutorial_panel.position = Vector2(488, 163)
		upgrade_tutorial_panel.size = Vector2(144, 56)

		if first_upgrade_bought_this_run:
			upgrade_tutorial_hint.text = "Start a new run to use your upgrade."
		else:
			upgrade_tutorial_hint.text = "Open Upgrades\nto spend gold."

	
func on_upgrade_purchased() -> void:
	if not Progression.upgrade_tutorial_completed:
		Progression.upgrade_tutorial_completed = true
		first_upgrade_bought_this_run = true
		Progression.save_progress()

	update_hud()
	update_upgrade_tutorial()

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
	
func _open_options() -> void:
	if game_over:
		return

	$HUD/OptionsButton.hide()
	$HUD/OptionsPanel.show()
	get_tree().paused = true


func _close_options() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_slider.value)
	config.set_value("audio", "sfx", sfx_slider.value)
	config.save(AUDIO_SETTINGS_PATH)

	$HUD/OptionsPanel.hide()
	$HUD/OptionsButton.show()
	get_tree().paused = false
