extends Control
## Shown while the tree is paused.

signal resume_pressed()
signal menu_pressed()

@onready var _resume: Button = $Resume
@onready var _menu: Button = $Menu

func _ready() -> void:
	# Must run while paused, or its own buttons would be dead.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resume.pressed.connect(_on_resume)
	_menu.pressed.connect(_on_menu)
	_resume.grab_focus()

func _on_resume() -> void:
	AudioManager.play("ui_select", -8.0)
	resume_pressed.emit()

func _on_menu() -> void:
	AudioManager.play("ui_select", -8.0)
	menu_pressed.emit()

func _draw() -> void:
	draw_rect(get_viewport_rect(), Color(0.03, 0.03, 0.06, 0.78), true)
