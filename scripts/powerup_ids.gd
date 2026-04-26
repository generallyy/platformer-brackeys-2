class_name PowerupIds

## Canonical powerup ID constants.
## Use these everywhere instead of raw strings to prevent typos.

# Passive
const DAMAGE_BOOST      := "damage_boost"
const KNOCKBACK_BOOST   := "knockback_boost"
const EXTRA_HEARTS      := "extra_hearts"
const LOW_GRAVITY       := "low_gravity"
const SPEED_UP          := "speed_up"
const EXTRA_JUMP        := "extra_jump"
const GET_BIGGER        := "get_bigger"
const GET_SMALLER       := "get_smaller"
const LIFESTEAL         := "lifesteal"
const BIG_MELEE         := "big_melee"
const SLOW_ON_HIT       := "slow_on_hit"
const DASH_BOOST_GROUND := "dash_boost_ground"
const DASH_BOOST_AIR    := "dash_boost_air"
const SHIELD_SPIKE      := "shield_spike"
const PARRY_STUN        := "parry_stun"
const GHOST_HUNTER      := "ghost_hunter"
const HEAVY_HITTER      := "heavy_hitter"

# Active
const SPEED_BOOST   := "speed_boost"
const HOMER_ONCE    := "homer_once"
const INVISIBLE     := "invisible"
const TELEPORT      := "teleport"
const HEART_RESET   := "heart_reset"
const CONFUSION_RAY := "confusion_ray"

const ALL_ACTIVE: Array[String] = [
	SPEED_BOOST, HOMER_ONCE,
	INVISIBLE, TELEPORT, HEART_RESET, CONFUSION_RAY,
]

## How many times each powerup can be picked. Omitted = DEFAULT_MAX_STACKS.
const DEFAULT_MAX_STACKS := 10
const MAX_STACKS: Dictionary = {
	LOW_GRAVITY:       1,
	SPEED_BOOST:       1,
	HOMER_ONCE:        1,
	SPEED_UP:          3,
	EXTRA_JUMP:        2,
	GET_BIGGER:        1,
	GET_SMALLER:       1,
	LIFESTEAL:         2,
	BIG_MELEE:         2,
	SLOW_ON_HIT:       1,
	DASH_BOOST_GROUND: 2,
	DASH_BOOST_AIR:    2,
	SHIELD_SPIKE:      2,
	PARRY_STUN:        1,
	GHOST_HUNTER:      1,
	HEAVY_HITTER:      3,
	INVISIBLE:         1,
	TELEPORT:          1,
	HEART_RESET:       1,
	CONFUSION_RAY:     1,
}

static func get_max_stacks(id: String) -> int:
	return MAX_STACKS.get(id, DEFAULT_MAX_STACKS)

const DISPLAY_NAMES: Dictionary = {
	DAMAGE_BOOST:      "Heavy Hitter",
	KNOCKBACK_BOOST:   "Knock Out",
	EXTRA_HEARTS:      "Extra Hearts",
	LOW_GRAVITY:       "Featherweight",
	SPEED_UP:          "Swift",
	EXTRA_JUMP:        "Extra Jump",
	GET_BIGGER:        "Grow",
	GET_SMALLER:       "Shrink",
	LIFESTEAL:         "Lifesteal",
	BIG_MELEE:         "Big Swing",
	SLOW_ON_HIT:       "Chilling Strikes",
	DASH_BOOST_GROUND: "Power Slide",
	DASH_BOOST_AIR:    "Rocket Boost",
	SHIELD_SPIKE:      "Thorns",
	PARRY_STUN:        "Parry",
	GHOST_HUNTER:      "Ghost Hunter",
	HEAVY_HITTER:      "Heavyweight",
	SPEED_BOOST:       "Speed Surge",
	HOMER_ONCE:        "Seeker",
	INVISIBLE:         "Cloak",
	TELEPORT:          "Blink",
	HEART_RESET:       "Equalizer",
	CONFUSION_RAY:     "Confusion Ray",
}

static func get_display_name(id: String) -> String:
	return DISPLAY_NAMES.get(id, id)


## ---------------------------------------------------------------
## Modifiers — tweak these to change how each powerup feels.
## ---------------------------------------------------------------

# SPEED_UP: multiplier applied per stack to movement speed
const SPEED_UP_MULT              := 1.10
# GET_BIGGER / GET_SMALLER: player scale and speed effect
const GET_BIGGER_SCALE           := Vector2(1.25, 1.25)
const GET_SMALLER_SCALE          := Vector2(0.75, 0.75)
const GET_BIGGER_SPEED_MULT      := 1.15  # +15 % speed
const GET_SMALLER_SPEED_MULT     := 0.80  # -20 % speed
# HEAVY_HITTER: speed and knockback multipliers per stack
const HEAVY_HITTER_SPEED_MULT    := 0.80  # -20 % speed per stack
const HEAVY_HITTER_KNOCKBACK_MULT := 1.20
# DASH_BOOST (ground & air): dash speed multiplier per stack
const DASH_BOOST_MULT            := 1.30
# KNOCKBACK_BOOST: knockback multiplier per stack
const KNOCKBACK_BOOST_MULT       := 1.60
# BIG_MELEE: hitbox scale multiplier per stack
const BIG_MELEE_SCALE_MULT       := 1.20
# SLOW_ON_HIT: duration (seconds) and movement speed multiplier while slowed
const SLOW_DURATION              := 1.5
const SLOW_SPEED_MULT            := 0.80  # -20 % speed
# LIFESTEAL: hits needed to steal 1 HP at stack 1 (decreases by 1 per extra stack)
const LIFESTEAL_THRESHOLD_BASE   := 4
# EXTRA_HEARTS: max hearts added per stack
const EXTRA_HEARTS_PER_STACK     := 2
# INVISIBLE: cloak duration in seconds
const INVISIBLE_DURATION         := 3.0
