class_name Enemy
extends CharacterBody2D
## One enemy scene for every enemy in the game.
##
## Shape, speed, health, colour and behaviour all come from the [EnemyType]
## resource in [member type]. The three behaviours below are the whole AI: no
## navigation mesh, no steering library, no state machine framework. At this
## scale a match statement is honest and debuggable, and it is what fits in a
## jam weekend.

## Assigned by the wave director before this node enters the tree.
@export var type: EnemyType

@export_group("Wiring")
@export var enemy_arrow_scene: PackedScene

## Where fired projectiles are parented, so they outlive their shooter.
var projectile_parent: Node = null

var health: float = 1.0
var max_health: float = 1.0

var _player: Player = null
var _flash: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _contact_cooldown: float = 0.0
var _fire_cooldown: float = 0.0
var _dash_cooldown: float = 0.0
var _telegraph_left: float = 0.0
var _dash_left: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _strafe_sign: float = 1.0
var _spawn_grace: float = 0.25

@onready var _collider: CollisionShape2D = $CollisionShape2D
@onready var _contact_box: Area2D = $ContactBox
@onready var _contact_shape: CollisionShape2D = $ContactBox/CollisionShape2D

func _ready() -> void:
	if type == null:
		push_error("Enemy spawned without an EnemyType; falling back to defaults.")
		type = EnemyType.new()

	max_health = type.max_health
	health = max_health
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0
	_fire_cooldown = randf_range(0.3, type.fire_interval)
	_dash_cooldown = randf_range(0.4, type.dash_interval)

	_resize_shapes()
	add_to_group(&"enemies")
	_player = _find_player()

func _resize_shapes() -> void:
	# Shapes authored in the scene are shared between every instance, so each
	# enemy needs its own copy before the radius is changed.
	var body_shape := CircleShape2D.new()
	body_shape.radius = type.radius
	_collider.shape = body_shape

	var contact_shape := CircleShape2D.new()
	contact_shape.radius = type.radius + 3.0
	_contact_shape.shape = contact_shape

func _find_player() -> Player:
	var found := get_tree().get_first_node_in_group(&"player")
	return found as Player

func _physics_process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 5.0)
	_contact_cooldown = maxf(0.0, _contact_cooldown - delta)
	_spawn_grace = maxf(0.0, _spawn_grace - delta)
	_knockback = _knockback.lerp(Vector2.ZERO, minf(1.0, 8.0 * delta))

	if _player == null or not is_instance_valid(_player) or not _player.is_alive:
		_player = _find_player()
		if _player == null or not _player.is_alive:
			velocity = _knockback
			move_and_slide()
			queue_redraw()
			return

	match type.behaviour:
		EnemyType.Behaviour.CHASE:
			_act_chase(delta)
		EnemyType.Behaviour.DASHER:
			_act_dasher(delta)
		EnemyType.Behaviour.SHOOTER:
			_act_shooter(delta)
		_:
			_act_chase(delta)

	move_and_slide()
	_apply_contact_damage()
	queue_redraw()

func _to_player() -> Vector2:
	return _player.global_position - global_position

func _act_chase(_delta: float) -> void:
	velocity = _to_player().normalized() * type.speed + _knockback

func _act_dasher(delta: float) -> void:
	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = _dash_dir * type.dash_speed + _knockback
		return

	if _telegraph_left > 0.0:
		_telegraph_left -= delta
		# Rooted while winding up, which is what makes the dash dodgeable.
		velocity = _knockback
		if _telegraph_left <= 0.0:
			_dash_dir = _to_player().normalized()
			_dash_left = type.dash_duration
		return

	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	var distance := _to_player().length()
	if _dash_cooldown == 0.0 and distance < 260.0:
		_telegraph_left = type.dash_telegraph
		_dash_cooldown = type.dash_interval + type.dash_telegraph + type.dash_duration
		velocity = _knockback
		return

	velocity = _to_player().normalized() * type.speed + _knockback

func _act_shooter(delta: float) -> void:
	var to_player := _to_player()
	var distance := to_player.length()
	var forward := to_player.normalized()
	var desired := Vector2.ZERO

	# Hold a ring around the player: back off when crowded, close when far,
	# and strafe in the dead zone so it never stands perfectly still.
	if distance < type.preferred_range - 30.0:
		desired = -forward
	elif distance > type.preferred_range + 30.0:
		desired = forward
	else:
		desired = forward.orthogonal() * _strafe_sign

	velocity = desired * type.speed + _knockback

	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	if _fire_cooldown == 0.0 and distance < type.preferred_range * 2.0:
		_fire(forward)
		_fire_cooldown = type.fire_interval

func _fire(direction: Vector2) -> void:
	if enemy_arrow_scene == null:
		return
	var projectile := enemy_arrow_scene.instantiate()
	if projectile.has_method("setup"):
		projectile.setup(direction, type.projectile_speed, type.colour)
	projectile.global_position = global_position + direction * (type.radius + 7.0)
	var parent := projectile_parent if projectile_parent != null else get_parent()
	parent.add_child(projectile)

func _apply_contact_damage() -> void:
	if type.contact_damage <= 0 or _contact_cooldown > 0.0 or _spawn_grace > 0.0:
		return
	for body in _contact_box.get_overlapping_bodies():
		if body is Player:
			if body.take_damage(type.contact_damage):
				_contact_cooldown = type.attack_interval
				# Bounce off, so a hit does not become a grind.
				_knockback = -_to_player().normalized() * 140.0
			return

## Applies [param amount] damage. [param from_direction] is the direction the
## hit travelled in, used for knockback and for the impact spray.
func take_damage(amount: float, from_direction: Vector2 = Vector2.ZERO) -> void:
	if health <= 0.0:
		return
	health -= amount
	_flash = 1.0
	_knockback += from_direction.normalized() * type.knockback
	EventBus.enemy_hit.emit(global_position, amount)
	AudioManager.play("arrow_hit", -12.0)

	if health <= 0.0:
		_die()

func _die() -> void:
	EventBus.enemy_killed.emit(global_position, type.points, type.colour)
	AudioManager.play("enemy_death", -9.0)
	EventBus.screen_shake_requested.emit(1.6)
	queue_free()

func _draw() -> void:
	var body := type.colour.lerp(Color.WHITE, _flash * 0.8)
	var radius := type.radius

	# Winding up: swell and brighten, the only warning the player gets.
	if _telegraph_left > 0.0:
		var t := 1.0 - (_telegraph_left / maxf(0.01, type.dash_telegraph))
		radius = type.radius * (1.0 + 0.22 * t)
		body = body.lerp(Color.WHITE, 0.35 + 0.3 * sin(t * 24.0))
		var aim := _to_player().normalized()
		draw_line(aim * radius, aim * (radius + 34.0), Color(1.0, 1.0, 1.0, 0.3), 2.0, true)

	draw_circle(Vector2(0.0, 3.0), radius, Color(0.0, 0.0, 0.0, 0.22))
	draw_circle(Vector2.ZERO, radius, body)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, type.colour.darkened(0.45), 1.8, true)

	if type.behaviour == EnemyType.Behaviour.SHOOTER:
		var forward := _to_player().normalized() if _player != null and is_instance_valid(_player) else Vector2.RIGHT
		draw_arc(forward * radius * 0.7, radius * 0.75, forward.angle() - 1.1, forward.angle() + 1.1, 12, type.colour.darkened(0.3), 2.0, true)

	if health < max_health:
		_draw_health_bar(radius)

func _draw_health_bar(radius: float) -> void:
	var width := radius * 2.2
	var top := -radius - 9.0
	var ratio := clampf(health / maxf(0.01, max_health), 0.0, 1.0)
	draw_rect(Rect2(-width * 0.5, top, width, 3.0), Color(0.0, 0.0, 0.0, 0.45), true)
	draw_rect(Rect2(-width * 0.5, top, width * ratio, 3.0), type.colour.lightened(0.35), true)
