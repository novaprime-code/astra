extends Node2D
## A one-shot burst of short streaks, used for impacts and deaths.
##
## Hand-rolled rather than CPUParticles2D because it is a dozen lines, costs
## nothing, and makes the drawing code one less black box while learning. If
## the counts ever climb into the thousands, this is the first thing to
## replace with a pooled particle system.

class Streak:
	var position: Vector2
	var velocity: Vector2
	var length: float

var _streaks: Array[Streak] = []
var _colour: Color = Color.WHITE
var _life: float = 0.35
var _life_left: float = 0.0
var _drag: float = 4.5

## Fills the burst. Call before adding the node to the tree.
func burst(count: int, colour: Color, speed_min: float = 60.0, speed_max: float = 220.0, life: float = 0.35) -> void:
	_colour = colour
	_life = maxf(0.05, life)
	_life_left = _life
	_streaks.clear()
	for _i in count:
		var streak := Streak.new()
		var angle := randf() * TAU
		var speed := randf_range(speed_min, speed_max)
		streak.position = Vector2.from_angle(angle) * randf_range(0.0, 3.0)
		streak.velocity = Vector2.from_angle(angle) * speed
		streak.length = randf_range(3.0, 7.0)
		_streaks.append(streak)

## Biases the burst along [param along], which makes an arrow impact spray
## away from the shot instead of in a perfect circle.
func burst_directional(count: int, colour: Color, along: Vector2, spread: float = 1.1, speed_min: float = 80.0, speed_max: float = 260.0, life: float = 0.32) -> void:
	burst(0, colour, speed_min, speed_max, life)
	var base := along.angle()
	for _i in count:
		var streak := Streak.new()
		var angle := base + randf_range(-spread, spread)
		var speed := randf_range(speed_min, speed_max)
		streak.position = Vector2.ZERO
		streak.velocity = Vector2.from_angle(angle) * speed
		streak.length = randf_range(3.0, 8.0)
		_streaks.append(streak)

func _process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()
		return
	for streak in _streaks:
		streak.position += streak.velocity * delta
		streak.velocity = streak.velocity.lerp(Vector2.ZERO, minf(1.0, _drag * delta))
	queue_redraw()

func _draw() -> void:
	var fade := clampf(_life_left / _life, 0.0, 1.0)
	var colour := _colour
	colour.a = fade
	for streak in _streaks:
		var tail := streak.position - streak.velocity.normalized() * streak.length * fade
		draw_line(tail, streak.position, colour, 1.8, true)
