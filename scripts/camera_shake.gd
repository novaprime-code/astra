extends Camera2D
## Screen shake, driven entirely by [signal EventBus.screen_shake_requested].
##
## Nothing in the game holds a reference to the camera. A shot, a hit or a
## death just announces how hard it felt, and this decides what to do with it.
## That is the whole argument for an event bus in one file.

## Fraction of the remaining shake lost per second.
@export_range(0.5, 30.0, 0.5) var decay: float = 9.0
## Requests above this are clamped, so nothing can rattle the view to mush.
@export_range(1.0, 80.0, 1.0) var max_strength: float = 22.0

var _strength: float = 0.0

func _ready() -> void:
	EventBus.screen_shake_requested.connect(_on_shake_requested)

func _process(delta: float) -> void:
	if _strength <= 0.05:
		if offset != Vector2.ZERO:
			offset = Vector2.ZERO
			_strength = 0.0
		return
	_strength = lerpf(_strength, 0.0, minf(1.0, decay * delta))
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _strength

## Shakes take the strongest request rather than summing, so a death during a
## busy wave does not multiply into nausea.
func _on_shake_requested(strength: float) -> void:
	_strength = minf(max_strength, maxf(_strength, strength))
