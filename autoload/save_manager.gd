extends Node
## Local persistence. No accounts, no cloud, no backend.
##
## Everything lives in a single ConfigFile under user://, which Godot maps to
## a per-platform writable directory (and to IndexedDB on the web export).
## Writes are cheap and happen on run end, so a crash loses at most one run.

const SAVE_PATH := "user://astra.cfg"
const SECTION := "progress"

var best_score: int = 0
var runs_played: int = 0
var enemies_felled: int = 0

func _ready() -> void:
	load_progress()

## Reads the save file into memory. Missing or corrupt files are treated as
## a fresh profile rather than an error, which is what a player expects.
func load_progress() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		best_score = 0
		runs_played = 0
		enemies_felled = 0
		return
	best_score = int(cfg.get_value(SECTION, "best_score", 0))
	runs_played = int(cfg.get_value(SECTION, "runs_played", 0))
	enemies_felled = int(cfg.get_value(SECTION, "enemies_felled", 0))

## Writes the current values back to disk.
func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "best_score", best_score)
	cfg.set_value(SECTION, "runs_played", runs_played)
	cfg.set_value(SECTION, "enemies_felled", enemies_felled)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Astra: could not write save file (error %d)." % err)

## Folds a finished run into the profile.
## Returns true when the run beat the stored best, so the UI can say so.
func record_run(score: int, kills: int) -> bool:
	runs_played += 1
	enemies_felled += kills
	var is_record := score > best_score
	if is_record:
		best_score = score
	save_progress()
	return is_record

## Wipes the profile. Exposed for the menu and for tests.
func reset_progress() -> void:
	best_score = 0
	runs_played = 0
	enemies_felled = 0
	save_progress()
