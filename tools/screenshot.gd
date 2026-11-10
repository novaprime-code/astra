extends Node
## Renders the game to PNG files, unattended.
##
##     godot --path . tools/screenshot.tscn -- /path/to/output/dir
##
## Used to produce the README images and, more usefully, to look at the game
## on a machine with no screen: CI can render a frame and a human can check
## that the arena still looks like an arena. Composition is scripted rather
## than captured by hand so the shots are reproducible.

const ARENA := "res://scenes/arena.tscn"
const MAIN := "res://scenes/main.tscn"

var _out_dir: String = "res://screenshots"

func _ready() -> void:
	_out_dir = _resolve_out_dir()
	DirAccess.make_dir_recursive_absolute(_out_dir)
	print("Writing screenshots to %s" % _out_dir)

	await _shoot_menu()
	await _shoot_arena_early()
	await _shoot_arena_late()

	print("Done.")
	get_tree().quit(0)

func _resolve_out_dir() -> String:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] != "":
		return args[0]
	return ProjectSettings.globalize_path("user://screenshots")

# ------------------------------------------------------------------- captures

func _shoot_menu() -> void:
	var main: Node = load(MAIN).instantiate()
	add_child(main)
	await _frames(12)
	await _capture("01-menu.png")
	main.queue_free()
	await _frames(2)

func _shoot_arena_early() -> void:
	var arena: Arena = load(ARENA).instantiate()
	add_child(arena)
	await _frames(4)

	var player := arena.player()
	var centre := arena.bounds().get_center()
	_calm(arena)
	player.global_position = centre
	await _frames(2)

	# Aim right, so the bow and the drawn arrow are both legible.
	Input.warp_mouse(centre + Vector2(260.0, -40.0))
	await _frames(2)

	_place(arena, "footman", centre + Vector2(300.0, -90.0))
	_place(arena, "footman", centre + Vector2(360.0, 60.0))
	_place(arena, "charger", centre + Vector2(-260.0, 120.0))
	_place(arena, "archer", centre + Vector2(180.0, -220.0))
	await _frames(6)

	# One arrow already in flight, and the next at full draw.
	Input.action_press("shoot")
	await _frames(40)
	Input.action_release("shoot")
	await _frames(8)
	Input.action_press("shoot")
	await _frames(34)

	await _capture("02-arena.png")
	Input.action_release("shoot")

	arena.queue_free()
	await _frames(2)

func _shoot_arena_late() -> void:
	var arena: Arena = load(ARENA).instantiate()
	add_child(arena)
	await _frames(4)

	var player := arena.player()
	var centre := arena.bounds().get_center()
	_calm(arena)
	player.global_position = centre
	Input.warp_mouse(centre + Vector2(80.0, -240.0))
	await _frames(2)

	# A busier board, and the astra volley going out.
	for i in 7:
		var angle := TAU * float(i) / 7.0
		_place(arena, "footman", centre + Vector2.from_angle(angle) * 250.0)
	for i in 3:
		var angle := TAU * float(i) / 3.0 + 0.6
		_place(arena, "charger", centre + Vector2.from_angle(angle) * 330.0)
	_place(arena, "archer", centre + Vector2(-300.0, -180.0))
	await _frames(10)

	Input.action_press("astra")
	await _frames(2)
	Input.action_release("astra")
	await _frames(14)

	await _capture("03-astra.png")
	arena.queue_free()
	await _frames(2)

# -------------------------------------------------------------------- helpers

## Stops the wave director so the shot composition is exactly what is placed.
func _calm(arena: Arena) -> void:
	arena.director().stop()
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		enemy.queue_free()

func _place(arena: Arena, id: String, at: Vector2) -> void:
	for path: String in WaveDirector.DEFAULT_ENEMY_TYPES:
		var type: EnemyType = load(path)
		if type != null and String(type.id) == id:
			arena.director().spawn_enemy(type, at)
			return
	push_warning("screenshot: no enemy type with id %s" % id)

func _frames(count: int) -> void:
	for _i in maxi(1, count):
		await get_tree().physics_frame

func _capture(file_name: String) -> void:
	# The image is only valid once the frame has actually been drawn.
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join(file_name)
	var err := image.save_png(path)
	if err == OK:
		print("  %s  %dx%d" % [file_name, image.get_width(), image.get_height()])
	else:
		push_error("screenshot: could not write %s (error %d)" % [path, err])
