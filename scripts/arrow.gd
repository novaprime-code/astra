class_name Arrow
extends Area2D
## A player arrow. Also used, with pierce, for the astra volley.
##
## An Area2D rather than a body: arrows should never push anything, only
## report that they touched it. Movement is integrated by hand instead of
## using physics so that speed stays exactly what the bow charge decided.

## Despawn after this long even if nothing was hit, so stray shots cannot
## accumulate off-screen.
@export_range(0.2, 10.0, 0.1) var lifetime: float = 2.4

## How many trailing positions are kept for the motion streak.
const TRAIL_LENGTH := 7
const SHAFT_LENGTH := 21.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 500.0
var damage: float = 1.0
## Extra enemies this arrow may pass through. 0 means it stops at the first.
var pierce_left: int = 0
var colour: Color = Color.WHITE

var _life_left: float = 0.0
var _trail: Array[Vector2] = []
## Enemies already damaged by this arrow, so a pierce cannot hit twice.
var _already_hit: Array[int] = []

## Called by the player before the arrow is added to the tree.
func setup(dir: Vector2, arrow_speed: float, arrow_damage: float, pierce: int, arrow_colour: Color) -> void:
	direction = dir.normalized()
	speed = arrow_speed
	damage = arrow_damage
	pierce_left = pierce
	colour = arrow_colour

func _ready() -> void:
	_life_left = lifetime
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()
		return

	_trail.push_front(global_position)
	if _trail.size() > TRAIL_LENGTH:
		_trail.resize(TRAIL_LENGTH)

	global_position += direction * speed * delta
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body is Enemy:
		var id := body.get_instance_id()
		if _already_hit.has(id):
			return
		_already_hit.append(id)
		body.take_damage(damage, direction)
		if pierce_left <= 0:
			queue_free()
		else:
			pierce_left -= 1
		return

	# Anything else an arrow can touch is scenery, so it stops here.
	EventBus.enemy_hit.emit(global_position, 0.0)
	queue_free()

func _draw() -> void:
	var back := -direction * SHAFT_LENGTH

	if _trail.size() > 1:
		var streak := colour
		streak.a = 0.22
		var points := PackedVector2Array()
		for p in _trail:
			points.push_back(to_local(p))
		draw_polyline(points, streak, 2.4, true)

	draw_line(back, Vector2.ZERO, colour, 2.4, true)

	# A small head, so direction reads at a glance even at high speed.
	var side := direction.orthogonal() * 4.2
	var head := PackedVector2Array([
		direction * 5.5,
		-direction * 4.0 + side,
		-direction * 4.0 - side,
	])
	draw_colored_polygon(head, colour)
