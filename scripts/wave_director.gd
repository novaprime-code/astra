class_name WaveDirector
extends Node
## Decides what spawns, when, and where.
##
## Waves are generated from a budget rather than hand-authored, so difficulty
## keeps climbing past the point anyone would bother writing tables for. The
## enemies themselves are data ([EnemyType] resources); only the pacing lives
## here.
##
## Spawns are staggered instead of appearing all at once, which gives the
## player time to read the arena and reposition.

## Enemy types loaded when [member enemy_types] is left empty.
##
## Listed explicitly rather than discovered by scanning the folder: an export
## preset may convert .tres to binary, which breaks directory listings but
## never breaks load() on the original path. Adding an enemy means adding a
## .tres file and one line here.
const DEFAULT_ENEMY_TYPES: Array[String] = [
	"res://resources/enemies/footman.tres",
	"res://resources/enemies/charger.tres",
	"res://resources/enemies/archer.tres",
]

@export_group("Content")
## Every enemy type that may appear. Gated individually by unlock_wave.
## Left empty, [constant DEFAULT_ENEMY_TYPES] is loaded instead.
@export var enemy_types: Array[EnemyType] = []
@export var enemy_scene: PackedScene
@export var enemy_arrow_scene: PackedScene

@export_group("Pacing")
## Spawn budget for wave 1.
@export_range(1.0, 40.0, 0.5) var base_budget: float = 4.0
## Extra budget added per wave.
@export_range(0.0, 10.0, 0.1) var budget_growth: float = 1.7
## Hard ceiling on simultaneous spawns, so late waves stay playable.
@export_range(4, 120, 1) var max_wave_size: int = 26
## Seconds between two spawns inside a wave.
@export_range(0.05, 2.0, 0.05) var spawn_interval: float = 0.34
## Seconds of calm between clearing a wave and the next one arriving.
@export_range(0.0, 10.0, 0.1) var breather: float = 2.6
## How far inside the arena walls enemies appear.
@export_range(0.0, 120.0, 1.0) var spawn_inset: float = 26.0

var _entities: Node = null
var _bounds: Rect2 = Rect2()
var _queue: Array[EnemyType] = []
var _spawn_cooldown: float = 0.0
var _breather_left: float = 0.0
var _running: bool = false
var _wave_in_progress: bool = false

func _ready() -> void:
	if enemy_types.is_empty():
		_load_default_enemy_types()

func _load_default_enemy_types() -> void:
	for path in DEFAULT_ENEMY_TYPES:
		if not ResourceLoader.exists(path):
			push_warning("WaveDirector: missing enemy type at %s." % path)
			continue
		var type := load(path)
		if type is EnemyType:
			enemy_types.append(type)
		else:
			push_warning("WaveDirector: %s is not an EnemyType." % path)

## Called by the arena once the playfield is known.
func configure(entities: Node, bounds: Rect2) -> void:
	_entities = entities
	_bounds = bounds

## Begins wave 1. Safe to call again to restart.
func start() -> void:
	_queue.clear()
	_spawn_cooldown = 0.0
	_breather_left = 0.0
	_wave_in_progress = false
	_running = true
	GameState.wave = 0
	_begin_next_wave()

func stop() -> void:
	_running = false
	_queue.clear()

func _process(delta: float) -> void:
	if not _running:
		return

	if not _queue.is_empty():
		_spawn_cooldown -= delta
		if _spawn_cooldown <= 0.0:
			_spawn_cooldown = spawn_interval
			spawn_enemy(_queue.pop_front())
		return

	if _wave_in_progress:
		if _live_enemy_count() == 0:
			_wave_in_progress = false
			_breather_left = breather
			EventBus.wave_cleared.emit(GameState.wave)
		return

	_breather_left -= delta
	if _breather_left <= 0.0:
		_begin_next_wave()

func _live_enemy_count() -> int:
	return get_tree().get_nodes_in_group(&"enemies").size()

func _begin_next_wave() -> void:
	GameState.wave += 1
	_queue = _build_wave(GameState.wave)
	if _queue.is_empty():
		push_warning("WaveDirector: no enemy types available for wave %d." % GameState.wave)
		_running = false
		return
	_wave_in_progress = true
	_spawn_cooldown = 0.0
	AudioManager.play("wave_start", -7.0)
	EventBus.wave_started.emit(GameState.wave, _queue.size())

## Fills a spawn budget with weighted random picks from the unlocked types.
## Returns the enemies to spawn, shuffled so the order feels unplanned.
func _build_wave(wave: int) -> Array[EnemyType]:
	var result: Array[EnemyType] = []
	var available: Array[EnemyType] = []
	for type in enemy_types:
		if type != null and type.unlock_wave <= wave:
			available.append(type)
	if available.is_empty():
		return result

	var budget := base_budget + budget_growth * float(wave - 1)
	var guard := 0
	while budget > 0.0 and result.size() < max_wave_size and guard < 500:
		guard += 1
		var pick := _weighted_pick(available, budget)
		if pick == null:
			break
		result.append(pick)
		budget -= pick.spawn_cost

	result.shuffle()
	return result

## Picks a type by spawn_weight, ignoring anything too expensive for what is
## left of the budget. Returns null when nothing affordable remains.
func _weighted_pick(available: Array[EnemyType], budget: float) -> EnemyType:
	var affordable: Array[EnemyType] = []
	var total := 0.0
	for type in available:
		if type.spawn_cost <= budget and type.spawn_weight > 0.0:
			affordable.append(type)
			total += type.spawn_weight
	if affordable.is_empty() or total <= 0.0:
		return null

	var roll := randf() * total
	for type in affordable:
		roll -= type.spawn_weight
		if roll <= 0.0:
			return type
	return affordable.back()

## Spawns one enemy of [param type] at a random arena edge and returns it.
##
## Public because the pacing loop is not the only legitimate caller: the
## headless smoke test spawns directly so it never has to wait on wall-clock
## timers. Returns null if the director has not been configured.
func spawn_enemy(type: EnemyType, at: Vector2 = Vector2.INF) -> Node:
	if enemy_scene == null or _entities == null or type == null:
		return null
	var enemy := enemy_scene.instantiate()
	if enemy is Enemy:
		enemy.type = type
		enemy.enemy_arrow_scene = enemy_arrow_scene
		enemy.projectile_parent = _entities
	enemy.global_position = _random_edge_point() if at == Vector2.INF else at
	_entities.add_child(enemy)
	return enemy

## A random point just inside the arena wall, so enemies always walk in from
## the outside rather than materialising next to the player.
func _random_edge_point() -> Vector2:
	var inner := _bounds.grow(-spawn_inset)
	match randi() % 4:
		0:
			return Vector2(randf_range(inner.position.x, inner.end.x), inner.position.y)
		1:
			return Vector2(randf_range(inner.position.x, inner.end.x), inner.end.y)
		2:
			return Vector2(inner.position.x, randf_range(inner.position.y, inner.end.y))
		_:
			return Vector2(inner.end.x, randf_range(inner.position.y, inner.end.y))
