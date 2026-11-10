class_name Hud
extends Control
## Heads-up display: hearts, score, combo, wave banner, charge and astra.
##
## Two sources of truth, on purpose. Things that change in steps (score, wave,
## health) arrive as bus signals, because missing one would be a bug. Things
## that change every frame (bow charge, astra cooldown) are read straight off
## the player, because a signal per frame is just a slower variable.

const HEART_RADIUS := 7.0
const HEART_SPACING := 22.0
const CHARGE_BAR_SIZE := Vector2(190.0, 6.0)
## The wave banner sits over the playfield, so it never reaches full opacity.
const BANNER_ALPHA := 0.8

@onready var _score_label: Label = $Score
@onready var _combo_label: Label = $Combo
@onready var _wave_label: Label = $Wave
@onready var _banner_label: Label = $Banner

var _player: Player = null
var _health: int = 0
var _max_health: int = 0
var _banner_left: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.wave_started.connect(_on_wave_started)
	_banner_label.text = ""
	_refresh_score(GameState.score, GameState.combo)

## Gives the HUD the player whose charge and astra it should mirror.
func bind(player: Player) -> void:
	_player = player
	_health = player.health
	_max_health = player.max_health
	queue_redraw()

func _process(delta: float) -> void:
	if _banner_left > 0.0:
		_banner_left -= delta
		_banner_label.modulate.a = clampf(_banner_left / 0.6, 0.0, 1.0) * BANNER_ALPHA
		if _banner_left <= 0.0:
			_banner_label.text = ""
	queue_redraw()

func _on_health_changed(current: int, maximum: int) -> void:
	_health = current
	_max_health = maximum
	queue_redraw()

func _on_score_changed(score: int, combo: float) -> void:
	_refresh_score(score, combo)

func _refresh_score(score: int, combo: float) -> void:
	_score_label.text = str(score)
	var multiplier := int(floorf(combo))
	if multiplier > 1:
		_combo_label.text = "x%d" % multiplier
		_combo_label.modulate = Palette.WARN
	else:
		_combo_label.text = ""

func _on_wave_started(number: int, size: int) -> void:
	_wave_label.text = "WAVE %d" % number
	_banner_label.text = "WAVE %d  ·  %d" % [number, size]
	_banner_left = 1.9
	_banner_label.modulate.a = BANNER_ALPHA

func _draw() -> void:
	_draw_hearts()
	if _player != null and is_instance_valid(_player):
		_draw_charge()
		_draw_astra()

func _draw_hearts() -> void:
	var origin := Vector2(46.0, 46.0)
	for i in _max_health:
		var centre := origin + Vector2(HEART_SPACING * float(i), 0.0)
		var filled := i < _health
		var colour := Palette.HEART if filled else Palette.HEART_SPENT
		draw_circle(centre, HEART_RADIUS, colour)
		if filled:
			draw_arc(centre, HEART_RADIUS + 2.0, 0.0, TAU, 18, colour.lightened(0.3), 1.2, true)

func _draw_charge() -> void:
	var ratio := _player.charge_ratio()
	if ratio <= 0.0:
		return
	var size := get_viewport_rect().size
	var origin := Vector2(size.x * 0.5 - CHARGE_BAR_SIZE.x * 0.5, size.y - 54.0)
	draw_rect(Rect2(origin, CHARGE_BAR_SIZE), Color(0.0, 0.0, 0.0, 0.45), true)
	var full := ratio >= 1.0
	var fill := Palette.ARROW if full else Palette.SAFFRON
	draw_rect(Rect2(origin, Vector2(CHARGE_BAR_SIZE.x * ratio, CHARGE_BAR_SIZE.y)), fill, true)
	draw_rect(Rect2(origin, CHARGE_BAR_SIZE), Palette.WALL, false, 1.0)

func _draw_astra() -> void:
	var ratio := _player.astra_ratio()
	var size := get_viewport_rect().size
	var centre := Vector2(size.x * 0.5, size.y - 30.0)
	var is_ready := ratio >= 1.0
	var colour := Palette.ASTRA if is_ready else Palette.TEXT_DIM

	draw_arc(centre, 9.0, 0.0, TAU, 20, Color(0.0, 0.0, 0.0, 0.4), 6.0, true)
	draw_arc(centre, 9.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 20, colour, 3.0, true)
	if is_ready:
		draw_circle(centre, 3.4, Palette.ASTRA)
