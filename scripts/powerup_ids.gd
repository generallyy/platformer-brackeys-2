class_name PowerupIds

## Canonical powerup ID constants.
## Use these everywhere instead of raw strings to prevent typos.

# Passive
const JUMP_BOOST        := "jump_boost"
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
	JUMP_BOOST:        2,
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
