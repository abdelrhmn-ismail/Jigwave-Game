class_name Economy
extends RefCounted
## Coins and stars in one place. Tweak the numbers to change the feel.

const START_COINS := 100
const HINT_PLACE_COST := 30
const HINT_PEEK_COST := 15
const PEEK_SECONDS := 5.0
const MAX_COINS := 999999


## 3 stars with few mistakes, 2 with some, 1 otherwise. The limits grow
## with the number of pieces.
static func stars(mistakes: int, pieces: int) -> int:
	if mistakes <= ceili(pieces * 0.10):
		return 3
	if mistakes <= ceili(pieces * 0.25):
		return 2
	return 1


## Coins for finishing a puzzle.
static func reward(pieces: int, star_count: int) -> int:
	return 10 + 5 * clampi(star_count, 0, 3) + pieces / 4
