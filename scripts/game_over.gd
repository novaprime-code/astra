extends Control
## Results screen for a finished run.

signal retry_pressed()
signal menu_pressed()

@onready var _title: Label = $Title
@onready var _score: Label = $Score
@onready var _detail: Label = $Detail
@onready var _retry: Button = $Retry
@onready var _menu: Button = $Menu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_retry.pressed.connect(_on_retry)
	_menu.pressed.connect(_on_menu)
	_retry.grab_focus()

## Fills in the run's numbers. Called by the root scene after instantiation.
func setup(score: int, best: int, is_record: bool, wave: int, kills: int) -> void:
	_title.text = "NEW BEST" if is_record else "FELLED"
	_title.modulate = Palette.SAFFRON if is_record else Palette.TEXT
	_score.text = str(score)
	_detail.text = "wave %d   ·   %d felled   ·   best %d" % [wave, kills, best]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		_on_retry()

func _on_retry() -> void:
	AudioManager.play("ui_select", -8.0)
	retry_pressed.emit()

func _on_menu() -> void:
	AudioManager.play("ui_select", -8.0)
	menu_pressed.emit()

func _draw() -> void:
	draw_rect(get_viewport_rect(), Color(0.03, 0.03, 0.06, 0.82), true)
