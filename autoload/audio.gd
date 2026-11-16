extends Node
## Sounds and music. Audio.play("snap") looks for
## res://assets/sounds/snap.wav (or .ogg / .mp3); missing files are
## skipped silently, so sounds can be replaced any time.
## Music: "home" on the menus; the puzzle tracks take turns by level.
## All sounds are made by tools/make_audio.py (original).

const SOUND_DIR := "res://assets/sounds/"
const POOL_SIZE := 6
const MUSIC_DB := -11.0
const FADE := 0.6
const PUZZLE_TRACKS := ["music_puzzle_1", "music_puzzle_2", "music_puzzle_3"]

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_tween: Tween
## Track that should be playing (kept even while music is off).
var _wanted := ""


func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	add_child(_music)


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


## Track name for a level (0 = gallery puzzle: first puzzle track).
static func track_for_level(level: int) -> String:
	return PUZZLE_TRACKS[maxi(level - 1, 0) % PUZZLE_TRACKS.size()]


## Starts a music track ("music_home", "music_puzzle_2"…) with a fade.
func play_music(track: String) -> void:
	_wanted = track
	if not SaveData.music_on:
		_music.stop()
		return
	var stream := _get_stream(track)
	if stream == null or (_music.playing and _music.stream == stream):
		return
	_make_looping(stream)
	if _music_tween:
		_music_tween.kill()
	if _music.playing:
		_music_tween = create_tween()
		_music_tween.tween_property(_music, "volume_db", -40.0, FADE)
		_music_tween.tween_callback(_start_music.bind(stream))
		_music_tween.tween_property(_music, "volume_db", MUSIC_DB, FADE)
	else:
		_music.volume_db = -40.0
		_start_music(stream)
		_music_tween = create_tween()
		_music_tween.tween_property(_music, "volume_db", MUSIC_DB, FADE)


## Call after the music setting changes.
func refresh_music() -> void:
	if SaveData.music_on and _wanted != "":
		play_music(_wanted)
	else:
		_music.stop()


func current_music() -> String:
	if not _music.playing or _music.stream == null:
		return ""
	return _music.stream.resource_path.get_file().get_basename()


func vibrate(duration_ms: int = 20) -> void:
	if SaveData.vibration_on and OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)


func stop_all() -> void:
	for player in _players:
		player.stop()
	if _music_tween:
		_music_tween.kill()
	_music.stop()


func _exit_tree() -> void:
	stop_all()


func _start_music(stream: AudioStream) -> void:
	_music.stream = stream
	_music.play()


func _make_looping(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
	elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.set("loop", true)


func _get_stream(sound_name: String) -> AudioStream:
	if _streams.has(sound_name):
		return _streams[sound_name]
	var stream: AudioStream = null
	for ext: String in ["wav", "ogg", "mp3"]:
		var path: String = SOUND_DIR + sound_name + "." + ext
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	_streams[sound_name] = stream
	return stream
