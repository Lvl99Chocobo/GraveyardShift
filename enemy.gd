extends Node2D
signal hit_received
signal died
signal target_requested(enemy: Node2D)
signal ritual_impacted

@export var max_health: float = 60.0
@export var damage: float = 12.0
@export var target: Node2D
@export var fallback_target: Node2D
@export var is_ritual: bool = false
@export var ritual_texture: Texture2D
@export var ritual_impact_texture: Texture2D
@export var skeleton_death_texture: Texture2D
@export var necromancer_death_texture: Texture2D

var is_casting: bool = false
var health: float = 60.0
var is_dead: bool = false
var hit_tween: Tween
var attack_tween: Tween
var body_start_position: Vector2
var is_enraged: bool = false
var party: Array = []
var normal_bar_size: Vector2
var normal_bar_position: Vector2
var original_target: Node2D

@onready var body: Sprite2D = $Body
@onready var attack_timer: Timer = $AttackTimer
@onready var health_bar: ProgressBar = $HealthBar
@onready var cast_label: Label = $CastLabel
@onready var ritual_cast_bar: ProgressBar = $RitualCastBar



func _ready() -> void:
	health = max_health
	health_bar.max_value = max_health
	health_bar.value = health
	body_start_position = body.position
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	var bar_position: Vector2 = health_bar.global_position
	health_bar.top_level = true
	health_bar.global_position = bar_position
	normal_bar_size = health_bar.size
	normal_bar_position = health_bar.global_position
	cast_label.hide()
	original_target = target

	if is_ritual:
		if ritual_texture != null:
			body.texture = ritual_texture

		attack_timer.wait_time = 3.0
		attack_timer.start()
		
	$ClickArea.input_event.connect(_on_click_area_input_event)

func take_damage(amount: float) -> void:
	if is_dead:
		return

	health = maxf(health - amount, 0.0)
	hit_received.emit()
	health_bar.value = health

	if health <= 0.0:
		is_dead = true
		stop_attacking()
		health_bar.hide()
		died.emit()
		show_death_sprite()
		return

	flash_on_hit()


func flash_on_hit() -> void:
	if hit_tween != null:
		hit_tween.kill()

	body.modulate = Color(2.0, 2.0, 2.0, 1.0)
	hit_tween = create_tween()
	hit_tween.tween_property(
		body,
		"modulate",
		Color.WHITE,
		0.15
	)


func _on_attack_timer_timeout() -> void:
	if is_dead:
		return

	if is_ritual:
		ritual_tick()
		return

	if not is_enraged:
		target = original_target

	if not is_instance_valid(target) or target.is_dead:
		if is_instance_valid(fallback_target) and not fallback_target.is_dead:
			target = fallback_target
		else:
			choose_next_target()

	if not is_instance_valid(target):
		return

	play_attack_animation()
	target.take_damage(damage)

	if is_enraged and not is_dead:
		choose_next_target()

func play_attack_animation() -> void:
	if attack_tween != null:
		attack_tween.kill()

	body.position = body_start_position

	var local_target: Vector2 = to_local(target.global_position)
	var direction: Vector2 = (
		local_target - body_start_position
	).normalized()

	attack_tween = create_tween()

	attack_tween.tween_property(
		body,
		"position",
		body_start_position + direction * 6.0,
		0.08
	)

	attack_tween.tween_property(
		body,
		"position",
		body_start_position,
		0.12
	)

func enrage() -> void:
	if is_ritual:
		return
	if is_dead or is_enraged:
		return

	is_enraged = true
	modulate = Color("#ff7868")
	damage *= 2.0

	choose_next_target()
	attack_timer.start()

func choose_next_target() -> void:
	var living_heroes: Array = []

	for hero in party:
		if not hero.is_dead:
			living_heroes.append(hero)

	if living_heroes.is_empty():
		target = null
		return

	target = living_heroes.pick_random()
	
func ritual_tick() -> void:
	if not is_casting:
		is_casting = true
		cast_label.show()

		attack_timer.wait_time = 1.2
		attack_timer.start()
		return

	is_casting = false
	cast_label.hide()
	ritual_impacted.emit()

	for hero in party:
		if not hero.is_dead:
			show_ritual_impact(hero)
			hero.take_damage(damage)

	for hero in party:
		if not hero.is_dead:
			attack_timer.wait_time = 3.0
			attack_timer.start()
			return

func _on_click_area_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_idx: int
) -> void:
	if is_dead:
		return

	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			target_requested.emit(self)

func set_focused(focused: bool) -> void:
	health_bar.size = normal_bar_size

	if focused:
		health_bar.size += Vector2(6, 3)

	var extra_size: Vector2 = health_bar.size - normal_bar_size
	health_bar.global_position = normal_bar_position - Vector2(
		extra_size.x / 2.0,
		extra_size.y
	)

func _process(_delta: float) -> void:
	ritual_cast_bar.visible = is_ritual and is_casting and not attack_timer.is_stopped()

	if ritual_cast_bar.visible:
		ritual_cast_bar.value = 1.0 - attack_timer.time_left / attack_timer.wait_time

func show_ritual_impact(hero: Node2D) -> void:
	if ritual_impact_texture == null:
		return

	var impact := Sprite2D.new()
	impact.texture = ritual_impact_texture
	impact.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	impact.centered = true
	impact.z_index = 4
	impact.scale = Vector2(1.25, 1.25)
	hero.add_child(impact)

	var pulse := impact.create_tween()
	pulse.tween_interval(0.15)
	pulse.tween_property(impact, "modulate:a", 0.0, 0.35)
	pulse.tween_callback(impact.queue_free)

func stop_attacking() -> void:
	attack_timer.stop()
	is_casting = false
	cast_label.hide()
	ritual_cast_bar.hide()

func show_death_sprite() -> void:
	var death_texture: Texture2D = (
		necromancer_death_texture if is_ritual else skeleton_death_texture
	)

	if death_texture == null:
		queue_free()
		return

	if attack_tween != null:
		attack_tween.kill()

	if hit_tween != null:
		hit_tween.kill()

	body.position = body_start_position
	body.modulate = Color.WHITE
	modulate = Color.WHITE
	body.texture = death_texture

	var fade := create_tween()
	fade.tween_interval(0.65)
	fade.tween_property(body, "modulate:a", 0.0, 0.25)
	fade.tween_callback(queue_free)
