class_name Levels
extends RefCounted
## Level number → picture and piece count. Levels never run out: the
## picture list repeats while the piece count keeps growing.

## [first level, grid size]. Grid N means N×N pieces.
const STEPS := [
	[1, 3], # 9 pieces
	[6, 4], # 16
	[16, 5], # 25
	[36, 6], # 36
	[71, 7], # 49
	[121, 8], # 64
	[251, 9], # 81
	[401, 10], # 100
]

## Piece counts offered in the gallery (free play).
const FREE_PLAY_GRIDS := [3, 4, 6, 8, 10]


static func grid_for_level(level: int) -> int:
	var grid: int = STEPS[0][1]
	for step in STEPS:
		if level >= step[0]:
			grid = step[1]
	return grid


## Index into the play order (Catalog.play_order()) for this level.
static func picture_index(level: int, picture_count: int) -> int:
	if picture_count <= 0:
		return -1
	return (maxi(level, 1) - 1) % picture_count


## Seed for the piece shapes of a level (same level = same cuts).
static func cut_seed(level: int) -> int:
	return 1000 + level * 31


## Pictures the player has reached (level `next_level` not finished yet):
## the first next_level - 1 pictures of the play order, at least one.
static func unlocked_count(next_level: int, picture_count: int) -> int:
	return clampi(next_level - 1, 1, picture_count)
