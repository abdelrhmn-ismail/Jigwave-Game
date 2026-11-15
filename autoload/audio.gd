extends Node
## Plays sounds by name: Audio.play("snap") looks for
## res://assets/sounds/snap.wav (or .ogg / .mp3). Missing files are
## skipped silently, so sounds can be added any time.

const SOUND_DIR := "res://assets/sounds/"
const POOL_SIZE := 6
## Our names → files (placeholder sounds until Phase 6).
const ALIASES := {"snap": "place", "wrong": "invalid", "win": "new_best"}

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func play(sound_name: String, pitch: float = 1.0) -> void:
	if not SaveData.sound_on:
		return
	var stream := _get_stream(sound_name)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = stream
	player.pitch_scale = pitch
	player.play()


func vibrate(duration_ms: int = 20) -> void:
	if SaveData.vibration_on and OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)


func _get_stream(sound_name: String) -> AudioStream:
	if _streams.has(sound_name):
		return _streams[sound_name]
	var stream: AudioStream = null
	for name_try: String in [sound_name, ALIASES.get(sound_name, "")]:
		if name_try == "":
			continue
		for ext: String in ["wav", "ogg", "mp3"]:
			var path: String = SOUND_DIR + name_try + "." + ext
			if ResourceLoader.exists(path):
				stream = load(path)
				break
		if stream != null:
			break
	_streams[sound_name] = stream
	return stream
