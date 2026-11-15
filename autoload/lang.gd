extends Node
## Current language. Lang.t("PLAY") returns the text in that language.
## Texts live in logic/strings.gd. The first launch follows the phone.

signal language_changed

const MAIN_FONT := "res://assets/fonts/Fredoka.ttf"
const ARABIC_FONT := "res://assets/fonts/Tajawal-Bold.ttf"

var code := "en"


func _ready() -> void:
	_add_font_fallback()
	var saved := SaveData.language
	apply(saved if saved != "" else Strings.from_locale(OS.get_locale()))


func t(key: String) -> String:
	var entry: Dictionary = Strings.TEXT.get(key, {})
	return entry.get(code, entry.get("en", key))


func is_rtl() -> bool:
	return Strings.RTL.has(code)


func language_name() -> String:
	return Strings.NAMES.get(code, code)


func apply(new_code: String) -> void:
	code = new_code if Strings.LANGS.has(new_code) else "en"
	TranslationServer.set_locale(code)
	language_changed.emit()


func cycle_language() -> void:
	apply(Strings.next(code))
	SaveData.language = code
	SaveData.write()


## Fredoka has no Arabic letters: let Godot use Tajawal for those.
func _add_font_fallback() -> void:
	var main_font := load(MAIN_FONT) as Font
	var arabic := load(ARABIC_FONT) as Font
	if main_font == null or arabic == null:
		return
	if not main_font.fallbacks.has(arabic):
		var list := main_font.fallbacks.duplicate()
		list.append(arabic)
		main_font.fallbacks = list
