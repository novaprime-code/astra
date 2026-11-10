# Contributing

Contributions are welcome, including from people who have never opened Godot
before. This is a small codebase on purpose, and most of it can be understood
in an afternoon.

## Getting set up

1. Install [Godot 4.4](https://godotengine.org/download) or newer. The standard
   build is fine; there is no C# or GDExtension here.
2. Clone the repository and open the folder in Godot, or run `godot .`.
3. Press F5 to play.

No other dependencies. `tools/make_sounds.py` needs Python 3.9+ and nothing
from PyPI.

## Before you open a pull request

Run the smoke test. It takes a few seconds:

```bash
godot --headless --path . res://tests/smoke_test.tscn
echo $?   # 0 means pass
```

It must exit 0, and the output must contain no `SCRIPT ERROR` lines and no
leak warnings. CI checks all three.

If you changed anything visual, regenerate the screenshots so the README keeps
matching the game:

```bash
godot --path . tools/screenshot.tscn -- docs/images
```

## House style

- **Tabs for indentation**, which is the Godot default.
- **Static types everywhere**: `var speed: float = 0.0`, `func f(x: int) -> void`.
  Untyped GDScript is slower and hides real mistakes.
- **`##` doc comments on anything public.** Say *why*, not *what*. The code
  already says what.
- **One script per scene**, named after it: `enemy.tscn` ↔ `enemy.gd`.
- **Tuning values are `@export`ed**, with a sensible `@export_range`. If a
  number needs changing to playtest it, it should not require editing code.
- **Put a signal on the `EventBus` only when more than one unrelated system
  cares about it.** Local signals stay local.
- **No new third-party assets.** Everything here is original and MIT licensed,
  which keeps the repository usable as jam starter code without anyone having
  to audit attribution. Generated or hand-made contributions are very welcome.

## Good first issues

Roughly in order of difficulty. Each is deliberately self-contained.

1. **Tune an enemy.** Edit a `.tres` in `resources/enemies/` and say in the PR
   what it felt like before and after. No code at all.
2. **Add a fourth enemy type.** Duplicate a `.tres`, change the numbers and
   colour, add its path to `WaveDirector.DEFAULT_ENEMY_TYPES`. Reuses an
   existing behaviour.
3. **Hit-stop.** Freeze the game for ~60 ms on a kill by setting
   `Engine.time_scale` and restoring it. Enormous feel improvement for very
   little code.
4. **Gamepad aiming.** The input map already has joypad bindings for movement.
   Wire the right stick to `Player._update_aim`, with a deadzone and a rule for
   switching back to the mouse.
5. **Remappable controls.** A settings screen writing to `SaveManager`.
6. **A new behaviour.** Add a case to `EnemyType.Behaviour` and to the `match`
   in `enemy.gd` — a shielded enemy that only takes damage from behind, say.
   Bonus points for converting the `match` into state nodes first.
7. **Music.** Extend `tools/make_sounds.py`, or contribute an original track.

## Pull requests

Keep them focused — one change per PR — and say what you tested and how it
plays. Screenshots or a short clip are worth a lot for anything visual.

Bug reports should include your OS, your Godot version, and what you expected
to happen.

## Licence

By contributing you agree that your contribution is licensed under the
[MIT licence](LICENSE), the same as the rest of the project.
