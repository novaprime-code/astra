# Roadmap

Astra is jam preparation, not a product. This file says what it is preparing
for, what gets built next, and — honestly — what would and would not survive
being scaled up into something larger.

## Why small

The original plan for this effort was a 3D, mobile-first, low-poly
Mahabharata game combining action combat, battlefield strategy and a
story campaign across the eighteen days of Kurukshetra.

That is a genuinely good long-term project and a bad first one. It is three
games wearing one trenchcoat, on a platform (mobile 3D) where every mistake
costs a week, in an engine that has to be learned at the same time.

So Astra is the opposite on every axis:

| | The epic | Astra |
| --- | --- | --- |
| Dimensions | 3D | 2D |
| Platform | Android first | Desktop + web first |
| Art | Modelled, rigged, animated | Drawn from primitives at runtime |
| Systems | Combat + strategy + narrative | Combat |
| Content | 18 chapters | 1 arena |
| Finishable | In years | In days |

Everything transferable between the two columns is *engineering*: scene
composition, data-driven content, event decoupling, input handling, game feel,
export and CI. Astra teaches all of it at a scale where mistakes cost an hour.

## Jam calendar

Verify these before relying on them; dates move.

| Event | When | Notes |
| --- | --- | --- |
| **Global Game Jam 2027** | Late January 2027, if the pattern holds | TU Dresden has hosted a GGJ site at the Immersive Experience Lab (IXLab). GGJ 2026 ran 26 Jan – 1 Feb. Check `globalgamejam.org` for the 2027 dates and whether the Dresden site is registered. |
| **Dresden Gamedev Meetup jam** | Runs periodically, ~3 weeks long | Hosted at FHD Dresden, open to all skill levels, previous editions in Nov 2025 and Aug–Sep 2026. Lower pressure than a 48-hour jam and a good dry run. Watch the meetup's itch.io page. |

A three-week local jam before a 48-hour international one is the right order.
Do the low-stakes one first.

## Before the next jam

Each item is a thing to *build*, not a tutorial to watch. All of them fit
inside this repository.

### Skills that are still missing

- [ ] **Gamepad support.** The input map already has joypad bindings for
      movement; aiming with the right stick is not wired up. Needs
      `Input.get_vector` on the right stick with a deadzone, and a rule for
      switching between mouse and pad.
- [ ] **A real state machine.** The enemy `match` statement is fine at three
      behaviours. Rewrite it as one `State` node per behaviour to learn the
      pattern *before* needing it under time pressure.
- [ ] **Tweens and juice.** No `Tween` is used anywhere yet. Hit-stop on kills,
      a scale punch on damage, and an eased wave banner are each ten minutes
      and transform how the game feels.
- [ ] **Shaders.** One `CanvasItemMaterial` or a small fragment shader — a
      flash on hit, or a vignette that tightens at low health.
- [ ] **A tilemap.** Astra has none, and most jam games need one.
- [ ] **Music.** `tools/make_sounds.py` generates effects only. A short looping
      track, even a generated one, is the single biggest perceived-quality win.
- [ ] **Controller-free accessibility.** Remappable keys, a colourblind-safe
      check on the red/orange/purple enemy palette.

### Gameplay worth adding

- [ ] A second weapon with a different charge curve, to prove the bow is a
      `.tres` away from being data rather than code.
- [ ] A boss at every fifth wave.
- [ ] Pickups: health, a temporary fire-rate buff.
- [ ] A short run summary (accuracy, best combo, time alive).

## Jam-day playbook

Written down now, because nobody designs a process at hour 30.

**Scope rules**

1. One mechanic. Write it in a single sentence before building anything. If
   the sentence needs an "and", cut until it does not.
2. Ship something playable by the end of the first third. A rough complete
   loop beats a polished fragment every time.
3. No new art pipeline during a jam. Primitives, or assets you already have.
4. Export to web on day one, not at the end. The first export always breaks
   something, and a jam entry nobody can play in a browser loses most of its
   audience.

**Rough shape of 48 hours**

| Hours | Goal |
| --- | --- |
| 0–2 | Theme, three ideas, pick one, write the one-sentence mechanic |
| 2–8 | Core mechanic playable in a grey box |
| 8–12 | First web export, uploaded somewhere, even if ugly |
| 12–24 | Content and difficulty: the second and third enemy, the loop |
| 24–32 | Sleep. Not optional. |
| 32–40 | Juice: sound, screen shake, particles, menus |
| 40–44 | Playtest with someone who has never seen it |
| 44–48 | Final export, upload, write the page, stop |

**Steal from this repository**

The parts that are genuinely reusable on day zero of a jam: `event_bus.gd`,
`save_manager.gd`, `audio_manager.gd`, `palette.gd`, `camera_shake.gd`, the
`EnemyType` + budget-based `WaveDirector` pattern, both CI workflows, and
`tools/make_sounds.py`. That is maybe four hours of jam time already banked.

## If this grows into the Mahabharata project

Plainly, what carries over and what does not.

**Carries over**

- The autoload split, and the rule about what belongs on the bus.
- Data-driven content. `EnemyType` becomes `UnitType`; the pattern is
  identical and matters more as content grows.
- The budget-based wave generator, which is already most of a skirmish
  generator.
- CI, the headless smoke test, and the scripted screenshot tool. All three
  work unchanged in 3D.
- The habit of exporting early and testing on the target device.

**Does not carry over**

- Every `_draw()` call. 3D needs meshes, materials and lighting — the entire
  rendering approach is thrown away.
- Mouse aiming. Touch aiming is a different design problem, not a port.
- Straight-line chase AI. 3D terrain needs `NavigationAgent3D` and baked
  navigation meshes.
- The fixed single-screen arena and its four walls.
- Immediate-mode drawing at battlefield scale. Hundreds of units need
  `MultiMesh`, LOD and culling.

**The honest sequencing.** Do not start the epic by building the epic. Build
a vertical slice: one hero, one small battlefield, one mission, on an actual
Android device, with a performance budget decided before the first model is
imported. If that slice is not fun with grey boxes, more content will not save
it — and if it is, the content has something to attach to.

The narrative and cultural work deserves the same care as the code: consult
multiple traditional sources, and be deliberate about how sacred teachings,
divine weapons and religious figures are represented rather than treating them
as fantasy skins.
