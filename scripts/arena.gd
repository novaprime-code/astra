class_name Arena
extends Node2D
## The playfield: bounds, walls, floor, and the glue between systems.
##
## The arena owns nothing clever. It measures the viewport, builds walls to
## match, tells the wave director where it may spawn, hands the HUD a player
## to read, and turns bus events into sparks. Every actual decision lives in
## the player, the enemies or the director.

@export_group("Playfield")
## Space left between the viewport edge and the wall, per side.
@export var margin_left: float = 44.0
@export var margin_right: float = 44.0
## Larger, because the HUD lives along the top.
@export var margin_top: float = 92.0
@export var margin_bottom: float = 48.0
## Walls are made deliberately thick so nothing can tunnel through at speed.
@export var wall_thickness: float = 256.0

@export_group("Wiring")
@export var spark_scene: PackedScene

@onready var _entities: Node2D = $Entities
@onready var _walls: Node2D = $Walls
@onready var _player: Player = $Player
@onready var _director: WaveDirector = $WaveDirector
@onready var _hud: Hud = $UI/HUD
@onready var _camera: Camera2D = $Camera2D

var _bounds: Rect2 = Rect2()

func _ready() -> void:
	_bounds = _compute_bounds()
	_build_walls()

	var centre := _bounds.get_center()
	_player.global_position = centre
	_player.projectile_parent = _entities
	_camera.global_position = centre

	_hud.bind(_player)
	_director.configure(_entities, _bounds)

	EventBus.enemy_hit.connect(_on_enemy_hit)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.player_hit.connect(_on_player_hit)
	EventBus.player_died.connect(_on_player_died)

	GameState.start_run()
	_director.start()
	queue_redraw()

## The interior of the arena, in global coordinates.
func bounds() -> Rect2:
	return _bounds

## The player instance. Exposed for the HUD's sake and for the smoke test.
func player() -> Player:
	return _player

## The wave director driving this arena.
func director() -> WaveDirector:
	return _director

## Where enemies, arrows and sparks are parented.
func entities() -> Node2D:
	return _entities

func _compute_bounds() -> Rect2:
	var size := get_viewport_rect().size
	return Rect2(
		Vector2(margin_left, margin_top),
		Vector2(
			maxf(100.0, size.x - margin_left - margin_right),
			maxf(100.0, size.y - margin_top - margin_bottom)
		)
	)

## Four static bodies hugging the interior. Built in code so the collision
## shapes can never drift out of step with the drawn floor.
func _build_walls() -> void:
	for child in _walls.get_children():
		child.queue_free()

	var t := wall_thickness
	var sides := {
		"Top": Rect2(
			Vector2(_bounds.position.x - t, _bounds.position.y - t),
			Vector2(_bounds.size.x + t * 2.0, t)
		),
		"Bottom": Rect2(
			Vector2(_bounds.position.x - t, _bounds.end.y),
			Vector2(_bounds.size.x + t * 2.0, t)
		),
		"Left": Rect2(
			Vector2(_bounds.position.x - t, _bounds.position.y - t),
			Vector2(t, _bounds.size.y + t * 2.0)
		),
		"Right": Rect2(
			Vector2(_bounds.end.x, _bounds.position.y - t),
			Vector2(t, _bounds.size.y + t * 2.0)
		),
	}

	for side_name: String in sides:
		var rect: Rect2 = sides[side_name]
		var body := StaticBody2D.new()
		body.name = side_name
		# Layer 5 ("wall"); masks nothing, because walls never initiate.
		body.collision_layer = 16
		body.collision_mask = 0
		body.position = rect.get_center()

		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collider := CollisionShape2D.new()
		collider.shape = shape
		body.add_child(collider)
		_walls.add_child(body)

func _on_enemy_hit(at: Vector2, _amount: float) -> void:
	_spawn_spark(at, 5, Color(1.0, 0.98, 0.9), 70.0, 190.0, 0.22)

func _on_enemy_killed(at: Vector2, _points: int, colour: Color) -> void:
	_spawn_spark(at, 16, colour.lightened(0.2), 110.0, 330.0, 0.42)

func _on_player_hit() -> void:
	_spawn_spark(_player.global_position, 12, Palette.HEART, 90.0, 260.0, 0.38)

func _on_player_died(_final_score: int) -> void:
	_director.stop()
	_spawn_spark(_player.global_position, 28, Palette.SAFFRON, 120.0, 420.0, 0.7)

func _spawn_spark(at: Vector2, count: int, colour: Color, speed_min: float, speed_max: float, life: float) -> void:
	if spark_scene == null:
		return
	var spark := spark_scene.instantiate()
	if spark.has_method("burst"):
		spark.burst(count, colour, speed_min, speed_max, life)
	spark.global_position = at
	_entities.add_child(spark)

func _draw() -> void:
	# Floor.
	draw_rect(_bounds, Palette.FLOOR, true)

	# A loose grid, purely so movement has something to read against.
	var step := 48.0
	var x := _bounds.position.x + step
	while x < _bounds.end.x:
		draw_line(Vector2(x, _bounds.position.y), Vector2(x, _bounds.end.y), Palette.FLOOR_LINE, 1.0, false)
		x += step
	var y := _bounds.position.y + step
	while y < _bounds.end.y:
		draw_line(Vector2(_bounds.position.x, y), Vector2(_bounds.end.x, y), Palette.FLOOR_LINE, 1.0, false)
		y += step

	# Wall face.
	draw_rect(_bounds, Palette.WALL, false, 3.0)

	# Corner ticks, which stop the arena reading as a plain rectangle.
	var tick := 26.0
	var corners := [
		[_bounds.position, Vector2(1.0, 0.0), Vector2(0.0, 1.0)],
		[Vector2(_bounds.end.x, _bounds.position.y), Vector2(-1.0, 0.0), Vector2(0.0, 1.0)],
		[Vector2(_bounds.position.x, _bounds.end.y), Vector2(1.0, 0.0), Vector2(0.0, -1.0)],
		[_bounds.end, Vector2(-1.0, 0.0), Vector2(0.0, -1.0)],
	]
	for corner in corners:
		var origin: Vector2 = corner[0]
		var along: Vector2 = corner[1]
		var down: Vector2 = corner[2]
		draw_line(origin, origin + along * tick, Palette.SAFFRON_DEEP, 3.0, true)
		draw_line(origin, origin + down * tick, Palette.SAFFRON_DEEP, 3.0, true)
