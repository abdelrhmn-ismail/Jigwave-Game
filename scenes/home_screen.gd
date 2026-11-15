class_name HomeScreen
extends Control
## Start screen: logo, coins, the next level's picture with a big Play
## (or Continue) button, the gallery, and a few settings.

signal play_pressed(resume: bool)
signal gallery_pressed

var overlay: OverlayPanel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var insets := UIKit.safe_insets(get_viewport())

	var coins := UIKit.coin_pill(50)
	coins.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	coins.position = Vector2(get_viewport_rect().size.x - 270, 50 + insets.x)
	add_child(coins)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 34)
	center.add_child(box)

	var logo := UIKit.label("Puzzlo", 150, UIKit.ACCENT)
	logo.add_theme_constant_override("shadow_offset_y", 8)
	box.add_child(logo)

	var resume := _resume_state()
	var pic: Dictionary
	var info: String
	if resume != null:
		pic = Catalog.get_item(resume.picture_id)
		info = "%s · %d / %d" % [
			Lang.t("LEVEL") % resume.level if resume.level > 0 else Lang.t("GALLERY"),
			resume.placed_count(), resume.piece_count()]
	else:
		pic = Catalog.picture_for_level(SaveData.level)
		info = "%s · %s" % [Lang.t("LEVEL") % SaveData.level,
			Lang.t("PIECES") % (Levels.grid_for_level(SaveData.level) * Levels.grid_for_level(SaveData.level))]

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.panel_style(UIKit.PANEL, 44, 28, 4))
	box.add_child(card)
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 22)
	card.add_child(card_box)
	if not pic.is_empty():
		var tex := TextureRect.new()
		tex.texture = load(pic["file"])
		tex.custom_minimum_size = Vector2(620, 620)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		# Not finished yet: show it dimmed, like a picture still to reveal.
		tex.modulate = Color(0.55, 0.6, 0.7) if resume == null else Color.WHITE
		card_box.add_child(tex)
	card_box.add_child(UIKit.label(info, 44, UIKit.TEXT))
	var play := UIKit.button(Lang.t("CONTINUE") if resume != null else Lang.t("PLAY"), Vector2(620, 150), 64, UIKit.ACCENT)
	play.pressed.connect(func(): play_pressed.emit(resume != null))
	card_box.add_child(play)

	var gallery := UIKit.button(Lang.t("GALLERY"), Vector2(676, 130), 52, UIKit.BUTTON)
	gallery.pressed.connect(func(): gallery_pressed.emit())
	box.add_child(gallery)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	var sound := UIKit.button("", Vector2(210, 100), 34)
	var refresh_sound := func(): sound.text = "%s: %s" % [Lang.t("SOUND"), Lang.t("ON") if SaveData.sound_on else Lang.t("OFF")]
	refresh_sound.call()
	sound.pressed.connect(func():
		if not UIKit.accept_action():
			return
		SaveData.sound_on = not SaveData.sound_on
		SaveData.write()
		refresh_sound.call())
	row.add_child(sound)
	var lang := UIKit.button(Lang.language_name(), Vector2(210, 100), 34)
	lang.pressed.connect(func():
		if UIKit.accept_action():
			Lang.cycle_language())
	row.add_child(lang)
	var credits := UIKit.button(Lang.t("CREDITS"), Vector2(210, 100), 30)
	credits.pressed.connect(_show_credits)
	row.add_child(credits)


## The unfinished puzzle, if there is a valid one.
func _resume_state() -> PuzzleState:
	if SaveData.current.is_empty():
		return null
	var s := PuzzleState.new()
	if not s.from_dict(SaveData.current) or Catalog.get_item(s.picture_id).is_empty():
		SaveData.current = {}
		SaveData.write()
		return null
	return s


func _show_credits() -> void:
	var panel := OverlayPanel.new()
	panel.add_text(Lang.t("CREDITS"), 60)
	panel.add_text(Lang.t("CREDITS_TEXT"), 38, UIKit.TEXT_DIM)
	panel.add_button(Lang.t("BACK"), func():
		overlay = null
		panel.close(), UIKit.ACCENT)
	overlay = panel
	add_child(panel)
