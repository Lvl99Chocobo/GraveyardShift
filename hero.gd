extends Node2D
signal heal_requested(hero: Node2D)
signal died
signal hail_of_arrows_requested(damage: float)
signal fireball_requested(target: Node2D, damage: float)
signal hit_received

@export var uses_fireball: bool = false
@export var uses_hail_of_arrows: bool = false

var attacks_since_skill: int = 0
var living_texture: Texture2D

@onready var living_bar_color: Color = $Background.color
@export var max_health: float = 100.0
@export var healing_per_click: float = 10.0
@export var hero_color: Color = Color("#65b5ff")
@export var attack_damage: float = 5.0
@export var attack_interval: float = 1.0
@export var attack_target: Node2D
@export var hero_texture: Texture2D
@export var death_texture: Texture2D
@export var attack_start_offset: float = 0.0
@export var resurrection_effect_texture: Texture2D

var health: float = 100.0
var is_dead: bool = false
var attack_elapsed: float = 0.0
var heal_tween: Tween
var damage_tween: Tween
var attack_tween: Tween

@onready var body: Polygon2D = $Body
@onready var click_area: Area2D = $ClickArea
@onready var character_sprite: Sprite2D = $CharacterSprite
@onready var sprite_rest_position: Vector2 = character_sprite.position

func _process(delta: float) -> void:
	if is_dead:
		return

	if not is_instance_valid(attack_target):
		return

	attack_elapsed += delta

	if attack_elapsed >= attack_interval:
		attack_elapsed = 0.0
		play_attack_animation(attack_target)
		if uses_hail_of_arrows or uses_fireball:
			attacks_since_skill += 1

			if attacks_since_skill == 4:
				attacks_since_skill = 0

				if uses_fireball:
					fireball_requested.emit(attack_target, attack_damage * 2.0)
				else:
					hail_of_arrows_requested.emit(attack_damage)

				return

		attack_target.take_damage(attack_damage)


func _ready() -> void:
	health = max_health
	body.color = hero_color
	update_health_visual()
	click_area.input_event.connect(_on_click_area_input_event)
	attack_elapsed = clampf(attack_start_offset, 0.0, attack_interval)
	if hero_texture != null:
		$CharacterSprite.texture = hero_texture
	living_texture = character_sprite.texture



func take_damage(amount: float) -> void:
	if is_dead:
		return

	health = maxf(health - amount, 0.0)
	hit_received.emit()

	if health <= 0.0:
		die()
	else:
		flash_on_damage()

	update_health_visual()

	update_health_visual()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return

	var previous_health: float = health
	health = minf(health + amount, max_health)

	update_health_visual()

	var restored_health: float = health - previous_health

	if restored_health > 0.0:
		flash_on_heal()
		show_heal_number(restored_health)


func update_health_visual() -> void:
	var health_ratio: float = clampf(health / max_health, 0.0, 1.0)
	var right_edge: float = -8.0 + 16.0 * health_ratio

	body.polygon = PackedVector2Array([
		Vector2(-8.0, -8.0),
		Vector2(right_edge, -8.0),
		Vector2(right_edge, 8.0),
		Vector2(-8.0, 8.0)
	])
	body.visible = health_ratio > 0.0


func _on_click_area_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			heal_requested.emit(self)

func die() -> void:
	is_dead = true
	$Background.color = Color("#643b45")
	if damage_tween != null:
		damage_tween.kill()

	$CharacterSprite.self_modulate = Color.WHITE
	if attack_tween != null:
		attack_tween.kill()

	character_sprite.position = sprite_rest_position
	if death_texture != null:
		$CharacterSprite.texture = death_texture
	died.emit()

func flash_on_heal() -> void:
	if heal_tween != null:
		heal_tween.kill()

	body.modulate = Color.WHITE
	body.color = Color("#72ff8a")

	heal_tween = create_tween()
	heal_tween.tween_property(
		body,
		"color",
		hero_color,
		0.2
	)

func show_heal_number(amount: float) -> void:
	var heal_label := Label.new()

	heal_label.text = "+%d" % int(round(amount))
	heal_label.position = Vector2(-24, -32)
	heal_label.size = Vector2(48, 20)
	heal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heal_label.add_theme_color_override(
		"font_color",
		Color("#72ff8a")
	)
	heal_label.add_theme_color_override(
		"font_outline_color",
		Color("#18251c")
	)
	heal_label.add_theme_constant_override("outline_size", 3)

	add_child(heal_label)

	var number_tween := create_tween()
	number_tween.set_parallel(true)

	number_tween.tween_property(
		heal_label,
		"position",
		heal_label.position + Vector2(0, -20),
		0.6
	)
	number_tween.tween_property(
		heal_label,
		"modulate:a",
		0.0,
		0.6
	)

	number_tween.chain().tween_callback(heal_label.queue_free)

func flash_on_damage() -> void:
	if damage_tween != null:
		damage_tween.kill()

	$CharacterSprite.self_modulate = Color("#ff6666")
	damage_tween = create_tween()
	damage_tween.tween_property(
		$CharacterSprite,
		"self_modulate",
		Color.WHITE,
		0.18
	)

func play_attack_animation(target: Node2D) -> void:
	if attack_tween != null:
		attack_tween.kill()

	character_sprite.position = sprite_rest_position

	var direction: Vector2 = (
		to_local(target.global_position) - sprite_rest_position
	).normalized()

	attack_tween = create_tween()
	attack_tween.tween_property(
		character_sprite, "position",
		sprite_rest_position + direction * 5.0, 0.07
	)
	attack_tween.tween_property(
		character_sprite, "position",
		sprite_rest_position, 0.12
	)

func resurrect() -> void:
	is_dead = false
	health = max_health * 0.5
	attack_elapsed = 0.0
	character_sprite.texture = living_texture
	$Background.color = living_bar_color
	update_health_visual()
	flash_on_heal()
	show_resurrection_effect()

func show_resurrection_effect() -> void:
	if resurrection_effect_texture == null:
		return

	var halo := Sprite2D.new()
	halo.texture = resurrection_effect_texture
	halo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	halo.position = Vector2(0, 10)
	halo.z_index = 5
	add_child(halo)

	var effect := halo.create_tween()
	effect.tween_interval(0.15)
	effect.tween_property(halo, "position:y", -16.0, 0.45)
	effect.parallel().tween_property(halo, "modulate:a", 0.0, 0.45)
	effect.tween_callback(halo.queue_free)
