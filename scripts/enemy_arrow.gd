extends Area2D
## A projectile fired by a shooter enemy.
##
## Kept deliberately slow and visually distinct from player arrows: it exists
## to be dodged, not to be a damage race.

@export_range(0.2, 10.0, 0.1) var lifetime: float = 4.0
@export_range(1, 10, 1) var damage: int = 1

const RADIUS := 5.5

var direction: Vector2 = Vector2.RIGHT
var speed: float = 185.0
var colour: Color = Color(0.55, 0.42, 0.78)

var _life_left: float = 0.0
var _spin: float = 0.0

## Called by the firing enemy before this node is added to the tree.
func setup(dir: Vector2, projectile_speed: float, projectile_colour: Color) -> void:
	direction = dir.normalized()
	speed = projectile_speed
	colour = projectile_colour

func _ready() -> void:
	_life_left = lifetime
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()
		return
	global_position += direction * speed * delta
	_spin += delta * 7.0
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		if body.take_damage(damage):
			EventBus.enemy_hit.emit(global_position, 0.0)
		queue_free()
		return
	# Scenery.
	queue_free()

func _draw() -> void:
	var glow := colour
	glow.a = 0.25
	draw_circle(Vector2.ZERO, RADIUS * 2.1, glow)
	# A spinning diamond, which separates it from the player's straight arrows.
	var a := _spin
	var points := PackedVector2Array([
		Vector2.from_angle(a) * RADIUS * 1.6,
		Vector2.from_angle(a + PI * 0.5) * RADIUS,
		Vector2.from_angle(a + PI) * RADIUS * 1.6,
		Vector2.from_angle(a + PI * 1.5) * RADIUS,
	])
	draw_colored_polygon(points, colour)
