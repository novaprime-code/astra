class_name Palette
extends RefCounted
## The whole game's colour vocabulary, in one place.
##
## Nothing here is loaded or instantiated; these are constants referenced as
## Palette.SAFFRON. Keeping them together is what makes a game drawn from
## primitives look deliberate instead of like placeholder art.

const VOID := Color(0.055, 0.06, 0.094)
const FLOOR := Color(0.125, 0.117, 0.145)
const FLOOR_LINE := Color(0.18, 0.168, 0.2)
const WALL := Color(0.27, 0.235, 0.27)

const SAFFRON := Color(0.95, 0.72, 0.33)
const SAFFRON_DEEP := Color(0.78, 0.5, 0.18)
const BOWSTRING := Color(0.85, 0.87, 0.93)
const ARROW := Color(0.96, 0.97, 1.0)
const ASTRA := Color(0.56, 0.84, 0.95)

const BLOOD := Color(0.79, 0.31, 0.31)
const HEART := Color(0.9, 0.35, 0.4)
const HEART_SPENT := Color(0.28, 0.24, 0.28)

const TEXT := Color(0.92, 0.93, 0.97)
const TEXT_DIM := Color(0.58, 0.59, 0.68)
const WARN := Color(0.95, 0.76, 0.35)
