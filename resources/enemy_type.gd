class_name EnemyType
extends Resource
## Everything that makes one enemy different from another.
##
## There is a single enemy scene and a single enemy script. A footman, a
## charger and an archer are the same scene holding a different EnemyType.
## Adding a fourth enemy means authoring a .tres file, not writing a class.
##
## This is the pattern worth carrying into a jam: data in resources, behaviour
## in a small number of well-tested branches.

## How this enemy decides where to go.
enum Behaviour {
	## Walk straight at the player and deal damage on contact.
	CHASE,
	## Close the gap slowly, telegraph, then dash in a straight line.
	DASHER,
	## Hold a preferred distance and shoot.
	SHOOTER,
}

@export_group("Identity")
@export var id: StringName = &"footman"
@export var display_name: String = "Footman"
@export var colour: Color = Color(0.79, 0.31, 0.31)

@export_group("Body")
## Collision and draw radius, in pixels.
@export_range(5.0, 40.0, 0.5) var radius: float = 11.0
@export_range(1.0, 50.0, 0.5) var max_health: float = 3.0
@export_range(10.0, 400.0, 1.0) var speed: float = 72.0
## How hard an arrow pushes this enemy back, in pixels per second.
@export_range(0.0, 400.0, 1.0) var knockback: float = 110.0

@export_group("Offence")
@export var behaviour: Behaviour = Behaviour.CHASE
@export_range(0, 10, 1) var contact_damage: int = 1
## Minimum seconds between two contact hits on the player.
@export_range(0.1, 5.0, 0.05) var attack_interval: float = 0.75

@export_subgroup("Dasher")
@export_range(50.0, 900.0, 5.0) var dash_speed: float = 340.0
## Seconds spent visibly winding up, so the dash can be read and dodged.
@export_range(0.05, 2.0, 0.05) var dash_telegraph: float = 0.45
@export_range(0.2, 2.0, 0.05) var dash_duration: float = 0.28
@export_range(0.5, 10.0, 0.05) var dash_interval: float = 2.2

@export_subgroup("Shooter")
## Distance this enemy tries to keep from the player.
@export_range(40.0, 600.0, 5.0) var preferred_range: float = 230.0
@export_range(40.0, 600.0, 5.0) var projectile_speed: float = 185.0
@export_range(0.2, 10.0, 0.05) var fire_interval: float = 1.9

@export_group("Spawning")
## Score awarded before the combo multiplier is applied.
@export_range(1, 500, 1) var points: int = 10
## The earliest wave this type may appear in.
@export_range(1, 50, 1) var unlock_wave: int = 1
## How much of a wave's spawn budget one of these consumes.
@export_range(0.5, 20.0, 0.5) var spawn_cost: float = 1.0
## Relative likelihood of being picked once unlocked.
@export_range(0.0, 10.0, 0.1) var spawn_weight: float = 1.0
