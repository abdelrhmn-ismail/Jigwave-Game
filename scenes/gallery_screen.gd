class_name GalleryScreen
extends Control
## Free play: every picture already reached in the levels, by category.
## Tap one, choose how many pieces, play it again for coins.

signal back_pressed
signal start_puzzle(picture_id: String, grid: int)

const COLUMNS := 3

var category := ""
var grid_box: GridContainer
var chips: HFlowContainer
var overlay: OverlayPanel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Positions here are set by hand: don't let Arabic mirror them.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	Audio.play_music("music_home")
	var view := get_viewport_rect().size
	var top := 30.0 + UIKit.safe_insets(get_viewport()).x

	# Add each node first, then place it (placing a node that is not in
	# the tree yet mirrors it off-screen in Arabic).
	var back := UIKit.button("<", Vector2(120, 120), 60)
	back.text_direction = Control.TEXT_DIRECTION_LTR # keep "<" in Arabic too
	back.pressed.connect(func(): back_pressed.emit())
	add_child(back)
	back.position = Vector2(40, top)
	var title := UIKit.label(Lang.t("GALLERY"), 64)
	add_child(title)
	title.size = Vector2(view.x, 120)
	title.position = Vector2(0, top)
	var coins := UIKit.coin_pill(46)
	add_child(coins)
	coins.position = Vector2(view.x - 260, top + 30)

	chips = HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 14)
	chips.add_theme_constant_override("v_separation", 14)
	chips.alignment = FlowContainer.ALIGNMENT_CENTER
	chips.custom_minimum_size = Vector2(view.x - 80, 0)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	scroll.position = Vector2(30, top + 150)
	scroll.size = Vector2(view.x - 60, view.y - top - 180)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 24)
	scroll.add_child(inner)
	# Category chips scroll with the pictures (they wrap to more rows
	# in longer languages without covering anything).
	inner.add_child(chips)
	grid_box = GridContainer.new()
	grid_box.columns = COLUMNS
	grid_box.add_theme_constant_override("h_separation", 18)
	grid_box.add_theme_constant_override("v_separation", 18)
	grid_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(grid_box)
	var hint := UIKit.label(Lang.t("LOCKED_HINT"), 36, UIKit.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(view.x - 120, 0)
	inner.add_child(hint)
	_build_chips()
	_fill()


func _unlocked() -> Array:
	var order := Catalog.play_order()
	return order.slice(0, Levels.unlocked_count(SaveData.level, order.size()))


func _build_chips() -> void:
	for c in chips.get_children():
		c.queue_free()
	var cats := [""]
	for it in _unlocked():
		if not cats.has(it["category"]):
			cats.append(it["category"])
	for c in cats:
		var text := Lang.t("CAT_ALL") if c == "" else Lang.t("CAT_" + c)
		var b := UIKit.button(text, Vector2(0, 90), 34, UIKit.ACCENT if c == category else UIKit.BUTTON)
		b.pressed.connect(func():
			category = c
			_build_chips()
			_fill())
		chips.add_child(b)


func _fill() -> void:
	for c in grid_box.get_children():
		c.queue_free()
	var side := (get_viewport_rect().size.x - 60.0 - 18.0 * (COLUMNS - 1)) / COLUMNS - 4.0
	for it in _unlocked():
		if category != "" and it["category"] != category:
			continue
		var b := TextureButton.new()
		b.texture_normal = load(it["thumb"])
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
		b.custom_minimum_size = Vector2(side, side)
		b.pressed.connect(_choose_size.bind(it["id"]))
		var best := 0
		for g in Levels.FREE_PLAY_GRIDS:
			best = maxi(best, SaveData.stars_for(it["id"], g))
		if best > 0:
			var stars := StarRow.new()
			stars.count = best
			stars.custom_minimum_size = Vector2(side, 60)
			stars.size = Vector2(side, 60)
			stars.position = Vector2(0, side - 64)
			b.add_child(stars)
		grid_box.add_child(b)


func _choose_size(picture_id: String) -> void:
	Audio.play("click")
	var panel := OverlayPanel.new()
	panel.add_text(Lang.t("CHOOSE_SIZE"), 56)
	for g in Levels.FREE_PLAY_GRIDS:
		var stars := SaveData.stars_for(picture_id, g)
		var text := Lang.t("PIECES") % (g * g) + ("  " + "★".repeat(stars) if stars > 0 else "")
		panel.add_button(text, func(): start_puzzle.emit(picture_id, g), UIKit.ACCENT if stars == 0 else UIKit.BUTTON)
	panel.add_button(Lang.t("BACK"), func():
		overlay = null
		panel.close())
	overlay = panel
	add_child(panel)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if overlay != null:
			overlay.close()
			overlay = null
		else:
			back_pressed.emit()
