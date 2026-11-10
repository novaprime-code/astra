extends Node
## Application root: owns scene flow and nothing else.
##
## The arena has no idea the main menu exists, and the menus have no idea what
## a wave is. Everything meets here, which is the one place a reader should
## have to look to answer "what happens after I die?".

@export_group("Scenes")
@export var arena_scene: PackedScene
@export var main_menu_scene: PackedScene
@export var pause_menu_scene: PackedScene
@export var game_over_scene: PackedScene

## Seconds between the killing blow and the results screen, so the death
## actually registers before the UI covers it.
@export_range(0.0, 3.0, 0.05) var death_delay: float = 0.85

@onready var _world: Node = $World
@onready var _overlay: CanvasLayer = $Overlay

var _arena: Node = null
var _run_over: bool = false

func _ready() -> void:
	# The pause menu has to keep working while the tree is paused, and so does
	# the input handler that opens it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.player_died.connect(_on_player_died)
	show_main_menu()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _arena == null or _run_over:
		return
	if get_tree().paused:
		_resume()
	else:
		_open_pause_menu()
	get_viewport().set_input_as_handled()

func show_main_menu() -> void:
	_run_over = false
	get_tree().paused = false
	GameState.abandon_run()
	AudioManager.stop_all()
	_clear(_world)
	_clear(_overlay)
	_arena = null

	var menu := _instantiate(main_menu_scene)
	if menu == null:
		return
	_overlay.add_child(menu)
	if menu.has_signal("play_pressed"):
		menu.play_pressed.connect(start_game)
	if menu.has_signal("quit_pressed"):
		menu.quit_pressed.connect(_quit)

func start_game() -> void:
	_run_over = false
	get_tree().paused = false
	_clear(_overlay)
	_clear(_world)

	_arena = _instantiate(arena_scene)
	if _arena == null:
		push_error("Main: arena_scene is not assigned.")
		return
	_world.add_child(_arena)

func _on_player_died(final_score: int) -> void:
	if _run_over:
		return
	_run_over = true

	var is_record := GameState.end_run()
	# process_always, so the delay still elapses if something pauses meanwhile.
	await get_tree().create_timer(death_delay, true).timeout
	if not is_inside_tree():
		return

	get_tree().paused = true
	var screen := _instantiate(game_over_scene)
	if screen == null:
		return
	_overlay.add_child(screen)
	if screen.has_method("setup"):
		screen.setup(final_score, SaveManager.best_score, is_record, GameState.wave, GameState.kills)
	if screen.has_signal("retry_pressed"):
		screen.retry_pressed.connect(start_game)
	if screen.has_signal("menu_pressed"):
		screen.menu_pressed.connect(show_main_menu)

func _open_pause_menu() -> void:
	get_tree().paused = true
	var menu := _instantiate(pause_menu_scene)
	if menu == null:
		get_tree().paused = false
		return
	_overlay.add_child(menu)
	if menu.has_signal("resume_pressed"):
		menu.resume_pressed.connect(_resume)
	if menu.has_signal("menu_pressed"):
		menu.menu_pressed.connect(show_main_menu)

func _resume() -> void:
	_clear(_overlay)
	get_tree().paused = false

func _quit() -> void:
	# There is nothing to quit to on the web build.
	if OS.has_feature("web"):
		return
	get_tree().quit()

func _instantiate(scene: PackedScene) -> Node:
	if scene == null:
		return null
	return scene.instantiate()

## Frees children immediately rather than at end of frame, so a rebuilt arena
## never briefly coexists with the old one.
func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
