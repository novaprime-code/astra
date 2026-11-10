class_name Player
extends CharacterBody2D
## The archer.
##
## The one mechanic worth defending in this game: the bow must be drawn, and
## drawing slows you to a crawl. Every interesting decision falls out of that
## tension, so the numbers below are the ones to tune first and the ones to
## leave alone last.
##
## Damage is pushed in from outside via [method take_damage]; the player never
## scans for enemies. Enemies own their own attacks.

const BODY_RADIUS := 15.0
const BOW_OFFSET := 18.0
const BOW_RADIUS := 15.0
const MUZZLE_OFFSET := 30.0

@export_group("Movement")
@export_range(40.0, 600.0, 5.0) var move_speed: float = 285.0
## Fraction of [member move_speed] kept while the bow is drawn.
@export_range(0.0, 1.0, 0.05) var draw_speed_scale: float = 0.42
## Pixels per second squared. High enough to feel responsive, low enough that
## direction changes still read as weight.
@export_range(200.0, 6000.0, 50.0) var acceleration: float = 2200.0
@export_range(200.0, 6000.0, 50.0) var friction: float = 2600.0

@export_group("Bow")
@export_range(0.1, 3.0, 0.05) var charge_time: float = 0.52
## Below this charge the shot still fires, but weakly. Releasing early should
## cost something without feeling like the input was eaten.
@export_range(0.0, 1.0, 0.05) var min_charge: float = 0.18
@export_range(100.0, 2000.0, 10.0) var arrow_speed_min: float = 430.0
@export_range(100.0, 2000.0, 10.0) var arrow_speed_max: float = 900.0
@export_range(0.5, 20.0, 0.5) var arrow_damage_min: float = 1.0
@export_range(0.5, 20.0, 0.5) var arrow_damage_max: float = 3.0
## Minimum seconds between two releases, so the bow cannot be spammed by
## tapping at zero charge.
@export_range(0.0, 2.0, 0.01) var shot_cooldown: float = 0.14

@export_group("Dodge")
@export_range(100.0, 2000.0, 10.0) var dodge_speed: float = 660.0
@export_range(0.05, 1.0, 0.01) var dodge_duration: float = 0.17
@export_range(0.1, 5.0, 0.05) var dodge_cooldown: float = 0.75

@export_group("Astra")
@export_range(3, 64, 1) var astra_arrows: int = 16
@export_range(1.0, 60.0, 0.5) var astra_cooldown: float = 11.0
@export_range(0.5, 20.0, 0.5) var astra_damage: float = 2.0
@export_range(100.0, 2000.0, 10.0) var astra_speed: float = 540.0
@export_range(0, 10, 1) var astra_pierce: int = 3

@export_group("Survival")
@export_range(1, 20, 1) var max_health: int = 5
## Seconds of immunity after taking a hit.
@export_range(0.0, 5.0, 0.05) var invulnerable_time: float = 0.9

@export_group("Wiring")
@export var arrow_scene: PackedScene

## Where spawned arrows are parented. The arena sets this so projectiles are
## siblings of enemies rather than children of a moving player.
var projectile_parent: Node = null

var health: int = 5
var is_alive: bool = true

var _aim_angle: float = 0.0
var _is_drawing: bool = false
var _charge: float = 0.0
var _shot_cooldown_left: float = 0.0
var _dodge_left: float = 0.0
var _dodge_cooldown_left: float = 0.0
var _dodge_dir: Vector2 = Vector2.RIGHT
var _invulnerable_left: float = 0.0
var _astra_cooldown_left: float = 0.0
var _was_astra_ready: bool = true

func _ready() -> void:
	health = max_health
	EventBus.player_health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	if not is_alive:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	_tick_timers(delta)
	_update_aim()
	_handle_dodge()
	_handle_bow(delta)
	_handle_astra()
	_apply_movement(delta)
	queue_redraw()

func _tick_timers(delta: float) -> void:
	_shot_cooldown_left = maxf(0.0, _shot_cooldown_left - delta)
	_dodge_left = maxf(0.0, _dodge_left - delta)
	_dodge_cooldown_left = maxf(0.0, _dodge_cooldown_left - delta)
	_invulnerable_left = maxf(0.0, _invulnerable_left - delta)

	if _astra_cooldown_left > 0.0:
		_astra_cooldown_left = maxf(0.0, _astra_cooldown_left - delta)
		if _astra_cooldown_left == 0.0 and not _was_astra_ready:
			_was_astra_ready = true
			EventBus.astra_ready.emit()

func _update_aim() -> void:
	var to_pointer := get_global_mouse_position() - global_position
	if to_pointer.length_squared() > 4.0:
		_aim_angle = to_pointer.angle()

func _handle_dodge() -> void:
	if not Input.is_action_just_pressed("dodge"):
		return
	if _dodge_cooldown_left > 0.0 or _dodge_left > 0.0:
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dodge_dir = input_dir if input_dir.length_squared() > 0.01 else Vector2.from_angle(_aim_angle)
	_dodge_left = dodge_duration
	_dodge_cooldown_left = dodge_cooldown
	# Dodging out of a draw loses the charge. That is the price of the escape.
	_is_drawing = false
	_charge = 0.0
	AudioManager.play("dodge", -6.0)

func _handle_bow(delta: float) -> void:
	# No drawing mid-dodge; the roll is a commitment.
	if _dodge_left > 0.0:
		return

	if Input.is_action_pressed("shoot"):
		if not _is_drawing and _shot_cooldown_left == 0.0:
			_is_drawing = true
			_charge = 0.0
		if _is_drawing:
			_charge = minf(1.0, _charge + delta / charge_time)
		return

	if _is_drawing:
		_release_arrow()

func _release_arrow() -> void:
	var charge := maxf(min_charge, _charge)
	var dir := Vector2.from_angle(_aim_angle)
	var speed := lerpf(arrow_speed_min, arrow_speed_max, charge)
	var damage := lerpf(arrow_damage_min, arrow_damage_max, charge)
	_spawn_arrow(dir, speed, damage, 0, Palette.ARROW)

	_is_drawing = false
	_charge = 0.0
	_shot_cooldown_left = shot_cooldown
	# Recoil, so a full-power shot physically commits you to a direction.
	velocity -= dir * lerpf(20.0, 95.0, charge)
	AudioManager.play("bow_release", -8.0 + 4.0 * charge)
	EventBus.screen_shake_requested.emit(lerpf(0.6, 2.6, charge))

func _handle_astra() -> void:
	if not Input.is_action_just_pressed("astra"):
		return
	if _astra_cooldown_left > 0.0:
		return
	for i in astra_arrows:
		var angle := _aim_angle + TAU * float(i) / float(astra_arrows)
		_spawn_arrow(Vector2.from_angle(angle), astra_speed, astra_damage, astra_pierce, Palette.ASTRA)
	_astra_cooldown_left = astra_cooldown
	_was_astra_ready = false
	_is_drawing = false
	_charge = 0.0
	AudioManager.play("astra", -2.0)
	EventBus.astra_fired.emit()
	EventBus.screen_shake_requested.emit(7.0)

func _spawn_arrow(dir: Vector2, speed: float, damage: float, pierce: int, colour: Color) -> void:
	if arrow_scene == null:
		push_warning("Player: arrow_scene is not assigned; no arrow was fired.")
		return
	var arrow := arrow_scene.instantiate()
	if arrow is Arrow:
		arrow.setup(dir, speed, damage, pierce, colour)
	arrow.global_position = global_position + dir * MUZZLE_OFFSET
	var parent := projectile_parent if projectile_parent != null else get_parent()
	parent.add_child(arrow)

func _apply_movement(delta: float) -> void:
	if _dodge_left > 0.0:
		velocity = _dodge_dir * dodge_speed
		move_and_slide()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed_scale := draw_speed_scale if _is_drawing else 1.0
	var target := input_dir * move_speed * speed_scale
	var rate := acceleration if input_dir.length_squared() > 0.01 else friction
	velocity = velocity.move_toward(target, rate * delta)
	move_and_slide()

## True while hits should be ignored, either from invulnerability frames or
## because the player is mid-dodge.
func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0 or _dodge_left > 0.0

## Applies [param amount] hearts of damage. Returns true if the hit landed,
## which lets callers skip their own hit effects on a whiffed attack.
func take_damage(amount: int) -> bool:
	if not is_alive or is_invulnerable() or amount <= 0:
		return false

	health = maxi(0, health - amount)
	_invulnerable_left = invulnerable_time
	_is_drawing = false
	_charge = 0.0
	EventBus.player_health_changed.emit(health, max_health)

	if health == 0:
		_die()
	else:
		EventBus.player_hit.emit()
		AudioManager.play("player_hurt", -3.0)
		EventBus.screen_shake_requested.emit(9.0)
	return true

func _die() -> void:
	is_alive = false
	_is_drawing = false
	AudioManager.play("game_over", -2.0)
	EventBus.screen_shake_requested.emit(16.0)
	EventBus.player_died.emit(GameState.score)

## 0..1 draw progress, for the HUD.
func charge_ratio() -> float:
	return _charge if _is_drawing else 0.0

## 1.0 when the astra is available, falling to 0.0 just after it is spent.
func astra_ratio() -> float:
	if astra_cooldown <= 0.0:
		return 1.0
	return 1.0 - (_astra_cooldown_left / astra_cooldown)

func _draw() -> void:
	# Blink while invulnerable, but never while dodging: the dodge should read
	# as fast, not as fragile.
	var alpha := 1.0
	if _invulnerable_left > 0.0 and _dodge_left == 0.0:
		alpha = 0.35 if int(_invulnerable_left * 14.0) % 2 == 0 else 1.0

	var forward := Vector2.from_angle(_aim_angle)
	var body := Palette.SAFFRON
	body.a = alpha

	draw_circle(Vector2(0.0, 5.0), BODY_RADIUS, Color(0.0, 0.0, 0.0, 0.25 * alpha))
	draw_circle(Vector2.ZERO, BODY_RADIUS, body)
	draw_arc(Vector2.ZERO, BODY_RADIUS, 0.0, TAU, 28, Palette.SAFFRON_DEEP, 2.0, true)

	_draw_bow(forward, alpha)

	if _is_drawing:
		_draw_charge_ring()

	if _dodge_left > 0.0:
		var trail := Palette.SAFFRON
		trail.a = 0.25
		draw_circle(-_dodge_dir * 17.0, BODY_RADIUS * 0.8, trail)

func _draw_bow(forward: Vector2, alpha: float) -> void:
	var centre := forward * BOW_OFFSET
	var limb := Palette.SAFFRON_DEEP
	limb.a = alpha
	draw_arc(centre, BOW_RADIUS, _aim_angle - 1.15, _aim_angle + 1.15, 20, limb, 3.2, true)

	var upper := centre + Vector2.from_angle(_aim_angle - 1.15) * BOW_RADIUS
	var lower := centre + Vector2.from_angle(_aim_angle + 1.15) * BOW_RADIUS
	var pull := lerpf(0.0, 10.0, _charge) if _is_drawing else 0.0
	var nock := centre - forward * (pull + 1.0)

	var string_colour := Palette.BOWSTRING
	string_colour.a = 0.75 * alpha
	draw_line(upper, nock, string_colour, 1.6, true)
	draw_line(nock, lower, string_colour, 1.6, true)

	if _is_drawing:
		var tip := centre + forward * (BOW_RADIUS * 0.6)
		draw_line(nock, tip, Palette.ARROW, 2.4, true)

func _draw_charge_ring() -> void:
	var full := _charge >= 1.0
	var colour := Palette.ARROW if full else Palette.SAFFRON
	colour.a = 0.85
	draw_arc(Vector2.ZERO, BODY_RADIUS + 9.0, -PI * 0.5, -PI * 0.5 + TAU * _charge, 32, colour, 2.4, true)
	if full:
		draw_arc(Vector2.ZERO, BODY_RADIUS + 13.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.25), 1.2, true)
