extends Node
## Score, combo and wave number for the run in progress.
##
## Deliberately small. It owns numbers, not gameplay: it never spawns, moves or
## damages anything. The wave director and the player own those decisions and
## report here, which keeps this file from growing into the god object that
## every hobby project eventually regrets.

## Combo cannot exceed this, so late waves stay readable rather than exploding.
const COMBO_CEILING := 5.0

## Added to the multiplier per kill.
const COMBO_PER_KILL := 0.25

## Seconds of no kills before the multiplier starts falling.
const COMBO_GRACE := 2.0

## Multiplier lost per second once the grace period has run out.
const COMBO_DECAY := 0.7

var score: int = 0
var combo: float = 1.0
var wave: int = 0
var kills: int = 0
var is_running: bool = false

var _grace_left: float = 0.0

func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)

func _process(delta: float) -> void:
	if not is_running:
		return
	if _grace_left > 0.0:
		_grace_left -= delta
	elif combo > 1.0:
		combo = maxf(1.0, combo - COMBO_DECAY * delta)
		EventBus.score_changed.emit(score, combo)

## Clears the run and lets listeners reset their displays.
func start_run() -> void:
	score = 0
	combo = 1.0
	wave = 0
	kills = 0
	_grace_left = 0.0
	is_running = true
	EventBus.score_changed.emit(score, combo)

## Ends the run, folds it into the save profile and returns whether it was a
## personal best.
func end_run() -> bool:
	is_running = false
	return SaveManager.record_run(score, kills)

## Ends the run without recording it, for quitting to the menu mid-game.
## Walking away is not a finished run, and should not pad the statistics.
func abandon_run() -> void:
	is_running = false

## The whole-number multiplier shown in the HUD and applied to points.
func combo_multiplier() -> int:
	return int(floorf(combo))

func _on_enemy_killed(_at: Vector2, points: int, _colour: Color) -> void:
	if not is_running:
		return
	kills += 1
	score += points * combo_multiplier()
	combo = minf(COMBO_CEILING, combo + COMBO_PER_KILL)
	_grace_left = COMBO_GRACE
	EventBus.score_changed.emit(score, combo)
