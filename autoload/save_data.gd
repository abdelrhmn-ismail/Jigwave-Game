extends Node
## Progress, coins, settings and the unfinished puzzle, saved to
## user://save.json on the phone.

const PATH := "user://save.json"

var coins := Economy.START_COINS
## The next level to play (1 = nothing finished yet).
var level := 1
## Best stars per puzzle: {"<picture_id>|<grid>": 1..3}.
var best_stars := {}
var sound_on := true
var music_on := true
var vibration_on := true
var language := ""
## Snapshot from PuzzleState.to_dict(), or {} when nothing is in progress.
var current := {}
## A level puzzle put aside while a gallery puzzle is played; it comes
## back when that level is played again (so no placed piece is lost).
var parked := {}


func _ready() -> void:
	load_data()


func load_data() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	coins = clampi(int(data.get("coins", Economy.START_COINS)), 0, Economy.MAX_COINS)
	level = maxi(1, int(data.get("level", 1)))
	var stars = data.get("best_stars", {})
	best_stars = stars if typeof(stars) == TYPE_DICTIONARY else {}
	sound_on = bool(data.get("sound_on", true))
	music_on = bool(data.get("music_on", true))
	vibration_on = bool(data.get("vibration_on", true))
	language = str(data.get("language", ""))
	var cur = data.get("current", {})
	current = cur if typeof(cur) == TYPE_DICTIONARY else {}
	var park = data.get("parked", {})
	parked = park if typeof(park) == TYPE_DICTIONARY else {}


func write() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({
		"coins": coins,
		"level": level,
		"best_stars": best_stars,
		"sound_on": sound_on,
		"music_on": music_on,
		"vibration_on": vibration_on,
		"language": language,
		"current": current,
		"parked": parked,
	}))


func add_coins(amount: int) -> void:
	coins = clampi(coins + amount, 0, Economy.MAX_COINS)
	write()


## Pays for a hint. Returns false (and spends nothing) if too poor.
func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	write()
	return true


func stars_for(picture_id: String, grid: int) -> int:
	return int(best_stars.get("%s|%d" % [picture_id, grid], 0))


## Records a finished puzzle; returns the coins it paid.
func finish_puzzle(state: PuzzleState) -> int:
	var key := "%s|%d" % [state.picture_id, state.grid]
	var star_count := state.stars()
	var old_stars := int(best_stars.get(key, 0))
	best_stars[key] = maxi(old_stars, star_count)
	if state.level > 0 and state.level >= level:
		level = state.level + 1
	var won := Economy.reward(state.piece_count(), star_count) if old_stars == 0 \
		else Economy.replay_reward(state.piece_count(), old_stars, star_count)
	coins = clampi(coins + won, 0, Economy.MAX_COINS)
	current = {}
	write()
	return won
