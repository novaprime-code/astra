extends Control
## Title screen.

signal play_pressed()
signal quit_pressed()

@onready var _best: Label = $Best
@onready var _play: Button = $Play
@onready var _quit: Button = $Quit

func _ready() -> void:
	_play.pressed.connect(_on_play)
	_quit.pressed.connect(_on_quit)
	# Nothing to quit to in a browser tab.
	_quit.visible = not OS.has_feature("web")

	if SaveManager.runs_played > 0:
		_best.text = "best %d   ·   %d runs   ·   %d felled" % [
			SaveManager.best_score,
			SaveManager.runs_played,
			SaveManager.enemies_felled,
		]
	else:
		_best.text = ""

	_play.grab_focus()

func _on_play() -> void:
	AudioManager.play("ui_select", -8.0)
	play_pressed.emit()

func _on_quit() -> void:
	AudioManager.play("ui_select", -8.0)
	quit_pressed.emit()

func _draw() -> void:
	draw_rect(get_viewport_rect(), Palette.VOID, true)
