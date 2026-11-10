# Architecture

Why the code is shaped the way it is, and where it would break under load.

The guiding constraint: this is a game that has to be understandable at 2am
near the end of a jam. Every structural choice below trades a little
generality for the ability to hold the whole thing in your head.

## Layers

```
          Autoloads (always present, own no gameplay)
          EventBus · GameState · SaveManager · AudioManager
                              │
                     signals  │  queries
                              ▼
  Main ──► Arena ──► WaveDirector ──► Enemy ──► EnemyArrow
   │         │                         ▲
   │         ├──► Player ──► Arrow ─────┘
   │         ├──► Camera2D (shake)
   │         └──► HUD
   └──► MainMenu · PauseMenu · GameOver
```

Arrows point at "creates or owns". Nothing points upward: an enemy has no
reference to the arena, the HUD has no reference to the wave director, and the
camera has no reference to anything at all.

## The four autoloads

| Autoload | Owns | Deliberately does not |
| --- | --- | --- |
| `EventBus` | Typed signal declarations, nothing else | Hold state |
| `GameState` | Score, combo, wave number, kill count | Spawn, move or damage anything |
| `SaveManager` | A single `ConfigFile` under `user://` | Know what a score means |
| `AudioManager` | A fixed pool of 14 `AudioStreamPlayer`s | Decide when sounds play |

Load order matters and is set in `project.godot`: `EventBus`, `SaveManager`,
`AudioManager`, `GameState`. `GameState` is last because it is the only one
that calls into the others.

### Why an event bus

The alternative is `get_node("../../HUD")`, which breaks the moment a scene is
reorganised, and which makes every system depend on the tree layout. With the
bus, screen shake is the clean example: an arrow release, an enemy death and a
player hit all emit `screen_shake_requested(strength)`. None of them knows a
camera exists. Delete the camera and the game still runs.

The rule used here: **a signal belongs on the bus when more than one unrelated
system cares about it.** A button inside a menu stays a local signal.

### Why not everything on the bus

Bow charge and astra cooldown change every frame. Emitting a signal 60 times a
second to move a progress bar is a slower variable with extra steps, so the
HUD holds a direct reference to the player (`Hud.bind`) and reads those two
values in `_process`. Step changes (score, health, wave) go through the bus,
because missing one of those would be a visible bug.

## Data-driven enemies

There is one `enemy.tscn` and one `enemy.gd`. The difference between a footman
and an archer is a `.tres` file:

```gdscript
# resources/enemy_type.gd
@export var max_health: float
@export var speed: float
@export var behaviour: Behaviour   # CHASE, DASHER, SHOOTER
@export var unlock_wave: int
@export var spawn_cost: float
@export var spawn_weight: float
```

`Enemy._ready()` copies its collision shapes before resizing them. Shapes
authored in a scene are shared between every instance of that scene, so
mutating one in place would resize every enemy on screen — a bug worth knowing
about before it happens to you.

### Adding an enemy

1. Duplicate a `.tres` in `resources/enemies/` and change the numbers.
2. Add its path to `WaveDirector.DEFAULT_ENEMY_TYPES`.

That is all. No new class, no new scene, and the spawn budget picks it up
automatically from `unlock_wave`, `spawn_cost` and `spawn_weight`.

The paths are listed explicitly rather than discovered by scanning the folder,
because export presets convert `.tres` to binary by default. That breaks a
`DirAccess` listing but never breaks `load()` on the original path.

## Waves as a budget

Hand-authored wave tables stop being written somewhere around wave 12. Instead
each wave gets a budget:

```
budget = base_budget + budget_growth × (wave − 1)
```

and is filled with weighted random picks from the types unlocked at that wave,
subtracting `spawn_cost` each time. Spawns are then staggered at
`spawn_interval` from random points just inside the walls, so enemies walk in
rather than materialising next to you.

This gives three tuning dials (`base_budget`, `budget_growth`,
`spawn_interval`) that change the whole difficulty curve, which is what you
want when playtesting is a 20-minute activity.

## Collision layers

| Bit | Layer | Who is on it | What they scan for |
| --- | --- | --- | --- |
| 1 | `player` | Player body | walls |
| 2 | `enemy` | Enemy bodies | walls, other enemies |
| 3 | `player_projectile` | Arrows | enemies, walls |
| 4 | `enemy_projectile` | Enemy arrows | player, walls |
| 5 | `wall` | Arena walls | nothing |

Two decisions worth stating:

- **The player does not collide with enemies.** Enemies walk through the
  player and deal contact damage from an `Area2D`. Solid bodies would turn
  every swarm into a shoving match and let the player get wedged.
- **Enemies do collide with each other.** It costs nothing, stops them
  stacking into a single visual blob, and the occasional traffic jam at a
  chokepoint reads as intentional.

Damage always flows one way: the attacker calls `take_damage` on the target.
Nothing ever scans for things to hurt itself.

## Rendering

Everything is drawn in `_draw()` from circles, arcs, lines and polygons. No
textures, no sprite sheets, no art pipeline. The entire colour vocabulary is in
`scripts/palette.gd`, which is the reason primitives look deliberate rather
than like placeholders — the discipline is in the palette, not the shapes.

The renderer is set to `gl_compatibility` for the widest browser and
old-hardware support. Note that 2D MSAA is not supported there, so smoothing
comes from passing `antialiased = true` to the individual draw calls.

Stretch mode is `canvas_items` with aspect `keep`: the arena is a fixed
playfield, and every player must see exactly the same amount of it.

## Where this would break

Honest limits, roughly in the order they would bite:

- **Spark particles are allocated per burst.** Fine at tens per second. At
  thousands, this needs a pool.
- **Enemies have no spatial partitioning.** Each one does a vector subtraction
  against the player, which is O(n) and free. Anything requiring
  enemy-to-enemy awareness (flocking, formations) would need a grid.
- **`_draw()` is immediate mode.** A hundred enemies each issuing five draw
  calls is a hundred redundant state changes. `MultiMeshInstance2D` is the
  answer, at the cost of per-entity flashes and health bars.
- **No object pooling for arrows.** At the astra's 16 arrows per press this
  does not register; a continuous-fire weapon would change that.
- **Behaviour is a `match` statement.** Correct at three behaviours. At ten,
  with interruptible states, it wants a real state machine — probably one
  `State` node per behaviour under the enemy.

None of these are worth fixing today. They are listed so the first person to
hit one knows it was a choice.
