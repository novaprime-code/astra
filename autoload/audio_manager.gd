extends Node
## A tiny pooled sound player.
##
## Allocating an AudioStreamPlayer per shot would churn the heap during a busy
## wave, so a fixed ring of players is created once and reused. Requests that
## arrive while every player is busy simply steal the oldest one, which is
## inaudible in practice and keeps the cost constant.
##
## Missing files are not an error: the project ships generated .wav files, but
## the game stays playable if a contributor deletes or replaces them.

const POOL_SIZE := 14

## Logical name -> file path. Add new sounds here and nowhere else.
const SOUNDS := {
	"bow_release": "res://assets/audio/bow_release.wav",
	"arrow_hit": "res://assets/audio/arrow_hit.wav",
	"enemy_death": "res://assets/audio/enemy_death.wav",
	"player_hurt": "res://assets/audio/player_hurt.wav",
	"dodge": "res://assets/audio/dodge.wav",
	"astra": "res://assets/audio/astra.wav",
	"wave_start": "res://assets/audio/wave_start.wav",
	"game_over": "res://assets/audio/game_over.wav",
	"ui_select": "res://assets/audio/ui_select.wav",
}

## When false, [method play] does nothing. The headless smoke test turns
## sound off so a half-finished playback cannot still be alive at exit, and
## it is the obvious hook for a mute setting later.
var enabled: bool = true

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0

func _ready() -> void:
	# Sound must keep playing while the tree is paused, otherwise the pause
	# menu swallows the click that opened it.
	process_mode = Node.PROCESS_MODE_ALWAYS

	for key: String in SOUNDS:
		var path: String = SOUNDS[key]
		if ResourceLoader.exists(path):
			var stream := load(path)
			if stream is AudioStream:
				_streams[key] = stream

	for _i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_pool.append(player)

## Plays [param key] if it was loaded. [param pitch_jitter] randomises pitch by
## +/- that fraction, which stops repeated hits sounding like a machine.
func play(key: String, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	if not enabled or not _streams.has(key):
		return
	var player := _take_player()
	player.stream = _streams[key]
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()

## How many sounds were found and loaded on startup. Used by the tests to
## confirm the generated .wav files still import.
func loaded_count() -> int:
	return _streams.size()

## Silences everything at once. Used when leaving a run, so a death sound does
## not trail over the main menu.
func stop_all() -> void:
	for player in _pool:
		player.stop()
		# Dropping the stream releases the playback object too. Without this
		# the engine reports leaked AudioStreamPlaybackWAV instances at exit.
		player.stream = null

## Prefers an idle player, and falls back to round-robin stealing.
func _take_player() -> AudioStreamPlayer:
	for _i in _pool.size():
		var player := _pool[_next]
		_next = (_next + 1) % _pool.size()
		if not player.playing:
			return player
	var stolen := _pool[_next]
	_next = (_next + 1) % _pool.size()
	return stolen
