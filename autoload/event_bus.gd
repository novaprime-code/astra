extends Node
## Global, typed signal hub.
##
## Systems that do not own each other talk through here instead of reaching
## across the scene tree with get_node("../../Something"). The HUD never needs
## a reference to the wave director; it just listens for [signal wave_started].
##
## Rule of thumb: a signal belongs here when more than one unrelated system
## cares about it. Anything local (a button inside a menu) stays local.

## A player arrow, or an astra arrow, removed an enemy from the arena.
signal enemy_killed(at: Vector2, points: int, colour: Color)

## Any damage was dealt to an enemy, whether or not it survived.
signal enemy_hit(at: Vector2, amount: float)

## Emitted once on spawn and again on every change, so late listeners
## (such as a HUD built after the player) can draw the correct value.
signal player_health_changed(current: int, maximum: int)

## The player took a hit but is still alive.
signal player_hit()

## The run is over. [param final_score] is already combo-adjusted.
signal player_died(final_score: int)

## A wave began spawning. [param size] is the number of enemies queued.
signal wave_started(number: int, size: int)

## Every enemy of the wave is gone; the breather before the next one starts.
signal wave_cleared(number: int)

## Score or combo multiplier moved.
signal score_changed(score: int, combo: float)

## The astra volley was spent.
signal astra_fired()

## The astra cooldown finished and the ability is available again.
signal astra_ready()

## Request a camera kick. [param strength] is in pixels of peak offset.
signal screen_shake_requested(strength: float)
