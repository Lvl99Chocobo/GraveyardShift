extends Node
const TEST_FRESH_START: bool = true
const SAVE_PATH: String = "user://progression.cfg"
const DPS_HP_PER_UPGRADE: float = 15.0
const RESURRECTION_COST: int = 120
var resurrection_level: int = 0
var dps_hp_upgrade_levels: Array[int] = [0, 0]
var gold: int = 0
var heal_upgrade_level: int = 0
var dps_upgrade_levels: Array[int] = [0, 0]
var best_wave: int = 0
var tank_hp_upgrade_level: int = 0
var wave_5_unlocked: bool = false
var requested_start_wave: int = 1
var tank_damage_upgrade_level: int = 0
var tutorial_completed: bool = false
var upgrade_tutorial_completed: bool = false

func _ready() -> void:
	if TEST_FRESH_START:
		return

	load_progress()

func get_dps_damage(index: int) -> float:
	return 5.0 + dps_upgrade_levels[index]


func get_dps_upgrade_cost(index: int) -> int:
	return 10 + dps_upgrade_levels[index] * 5


func buy_dps_upgrade(index: int) -> bool:
	var cost: int = get_dps_upgrade_cost(index)

	if gold < cost:
		return false

	gold -= cost
	dps_upgrade_levels[index] += 1
	save_progress()
	return true
func get_healing_per_click() -> float:
	return 30.0 + heal_upgrade_level * 6.0


func get_heal_upgrade_cost() -> int:
	return 10 + heal_upgrade_level * 5


func buy_heal_upgrade() -> bool:
	var cost: int = get_heal_upgrade_cost()

	if gold < cost:
		return false

	gold -= cost
	heal_upgrade_level += 1
	save_progress()
	return true

func save_progress() -> void:
	if TEST_FRESH_START:
		return
	var save_file := ConfigFile.new()

	save_file.set_value("progression", "gold", gold)
	save_file.set_value(
		"progression",
		"heal_upgrade_level",
		heal_upgrade_level
	)
	save_file.set_value("progression", "dps1_damage_level", dps_upgrade_levels[0])
	save_file.set_value("progression", "dps2_damage_level", dps_upgrade_levels[1])
	
	save_file.set_value("progression", "best_wave", best_wave)
	save_file.set_value("progression", "tank_hp_upgrade_level", tank_hp_upgrade_level)
	save_file.set_value("progression", "dps1_hp_level", dps_hp_upgrade_levels[0])
	save_file.set_value("progression", "dps2_hp_level", dps_hp_upgrade_levels[1])
	save_file.set_value("progression", "wave_5_unlocked", wave_5_unlocked)
	save_file.set_value("progression", "resurrection_level", resurrection_level)
	save_file.set_value("progression", "tank_damage_upgrade_level", tank_damage_upgrade_level)
	save_file.set_value("progression", "tutorial_completed", tutorial_completed)
	save_file.set_value(
		"progression", "upgrade_tutorial_completed", upgrade_tutorial_completed
	)
	var error := save_file.save(SAVE_PATH)

	if error != OK:
		push_warning("Could not save progression: %s" % error)


func load_progress() -> void:
	var save_file := ConfigFile.new()
	var error := save_file.load(SAVE_PATH)

	if error != OK:
		return

	gold = int(save_file.get_value("progression", "gold", 0))
	heal_upgrade_level = int(
		save_file.get_value("progression", "heal_upgrade_level", 0)
	)
	dps_upgrade_levels[0] = int(
		save_file.get_value("progression", "dps1_damage_level", 0)
	)
	dps_upgrade_levels[1] = int(
		save_file.get_value("progression", "dps2_damage_level", 0)
	)
	best_wave = int(
		save_file.get_value("progression", "best_wave", 0)
	)
	tank_hp_upgrade_level = int(
		save_file.get_value("progression", "tank_hp_upgrade_level", 0)
	)
	dps_hp_upgrade_levels[0] = int(save_file.get_value("progression", "dps1_hp_level", 0))
	dps_hp_upgrade_levels[1] = int(save_file.get_value("progression", "dps2_hp_level", 0))
	wave_5_unlocked = bool(
		save_file.get_value("progression", "wave_5_unlocked", false)
	)
	resurrection_level = int(
		save_file.get_value("progression", "resurrection_level", 0)
	
	)
	tank_damage_upgrade_level = int(
		save_file.get_value("progression", "tank_damage_upgrade_level", 0)
	)
	tutorial_completed = bool(
		save_file.get_value("progression", "tutorial_completed", false)
	)
	upgrade_tutorial_completed = bool(
		save_file.get_value("progression", "upgrade_tutorial_completed", false)
	)
func get_tank_hp_bonus() -> float:
	return tank_hp_upgrade_level * 25.0


func get_tank_hp_upgrade_cost() -> int:
	return 20 + tank_hp_upgrade_level * 10


func buy_tank_hp_upgrade() -> bool:
	var cost: int = get_tank_hp_upgrade_cost()

	if gold < cost:
		return false

	gold -= cost
	tank_hp_upgrade_level += 1
	save_progress()
	return true

func get_dps_hp_bonus(index: int) -> float:
	return dps_hp_upgrade_levels[index] * DPS_HP_PER_UPGRADE


func get_dps_hp_upgrade_cost(index: int) -> int:
	return 10 + dps_hp_upgrade_levels[index] * 5


func buy_dps_hp_upgrade(index: int) -> bool:
	var cost: int = get_dps_hp_upgrade_cost(index)

	if gold < cost:
		return false

	gold -= cost
	dps_hp_upgrade_levels[index] += 1
	save_progress()
	return true

func get_resurrection_cost() -> int:
	return RESURRECTION_COST * (resurrection_level + 1)


func buy_resurrection() -> bool:
	var cost: int = get_resurrection_cost()
	if gold < cost:
		return false

	gold -= cost
	resurrection_level += 1
	save_progress()
	return true

func get_tank_damage_bonus() -> float:
	return float(tank_damage_upgrade_level)


func get_tank_damage_upgrade_cost() -> int:
	return 20 + tank_damage_upgrade_level * 10


func buy_tank_damage_upgrade() -> bool:
	var cost: int = get_tank_damage_upgrade_cost()
	if gold < cost:
		return false

	gold -= cost
	tank_damage_upgrade_level += 1
	save_progress()
	return true
