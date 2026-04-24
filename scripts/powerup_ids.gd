class_name PowerupIds

## Canonical powerup ID constants.
## Use these everywhere instead of raw strings to prevent typos.

# Passive
const JUMP_BOOST      := "jump_boost"
const DAMAGE_BOOST    := "damage_boost"
const KNOCKBACK_BOOST := "knockback_boost"
const EXTRA_HEARTS    := "extra_hearts"
const LOW_GRAVITY     := "low_gravity"

# Active
const SPEED_BOOST := "speed_boost"
const HOMER_ONCE  := "homer_once"

const ALL_ACTIVE: Array[String] = [SPEED_BOOST, HOMER_ONCE]

## How many times each powerup can be picked. Omitted = DEFAULT_MAX_STACKS.
const DEFAULT_MAX_STACKS := 10
const MAX_STACKS: Dictionary = {
	JUMP_BOOST:  2,
	LOW_GRAVITY: 1,
	SPEED_BOOST: 1,
	HOMER_ONCE:  1,
}

static func get_max_stacks(id: String) -> int:
	return MAX_STACKS.get(id, DEFAULT_MAX_STACKS)
