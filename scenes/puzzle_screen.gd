class_name PuzzleScreen
extends Node2D
## The play screen: the board, the scrolling tray of pieces, dragging,
## snapping, hints and the "complete" celebration.
## The rules live in PuzzleState; the piece shapes in JigsawCut.

signal exit_to_home
signal play_level(level: int)
signal open_gallery

## How far a dragged piece floats above the finger (in board cells).
const LIFT_CELLS := 0.75
## Finger movement (px) before a touch on the tray counts as scroll/drag.
const TOUCH_SLOP := 22.0
const TRAY_PAD := 30.0

## Set by Main before the screen is added.
var state: PuzzleState

var picture: Dictionary
var texture: Texture2D
var cut: JigsawCut
var pieces := {} # index -> PieceNode
var completed := false
var peeking := false

# --- layout ---
var view_size := Vector2.ZERO
var board_rect := Rect2()
var board_scale := 1.0
var tray_rect := Rect2()
var slot_w := 240.0
var tray_scale := 0.3
var scroll := 0.0
var scroll_vel := 0.0
var wrong_flash := 0.0:
	set(v):
		wrong_flash = v
		queue_redraw()

# --- touch ---
var touch_mode := "" # "", "tray", "scroll", "drag"
var touch_start := Vector2.ZERO
var candidate := -1
var drag_piece: PieceNode

# --- nodes ---
var board_layer: Node2D
var guide: GuideLines
var peek_sprite: Sprite2D
var placed_layer: Node2D
var tray_layer: Node2D
var drag_layer: Node2D
var fx_layer: Node2D
var hud_layer: CanvasLayer
var overlay_layer: CanvasLayer
var hud: Control
var title_label: Label
var progress_label: Label
var coins_box: HBoxContainer
var back_button: Button
var hint_buttons := {}
var toast: Label
var overlay: OverlayPanel


## Lines of every piece, drawn faintly on the empty board (drawn once).
class GuideLines extends Node2D:
	var cut: JigsawCut

	func _draw() -> void:
		var w := 2.0 / maxf(absf(global_scale.x), 0.05)
		for i in cut.piece_count():
			var pts := cut.outline(i)
			pts.append(pts[0])
			draw_polyline(pts, UIKit.GUIDE, w, true)


## A ring and a few sparks where a piece snapped in (frees itself).
class Sparkle extends Node2D:
	var t := 0.0
	var radius := 60.0
	var color := UIKit.MINT

	func _process(delta: float) -> void:
		t += delta / 0.5
		if t >= 1.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 - t
		draw_arc(Vector2.ZERO, radius * (0.6 + t * 0.9), 0, TAU, 40, Color(color, a), 6.0 * a + 1.0, true)
		for k in 8:
			var dir := Vector2.RIGHT.rotated(k * TAU / 8.0 + 0.3)
			draw_circle(dir * radius * (0.5 + t * 1.3), 7.0 * a + 1.0, Color(UIKit.GOLD, a))


func _ready() -> void:
	picture = Catalog.get_item(state.picture_id)
	texture = load(picture["file"])
	Audio.play_music(Audio.track_for_level(state.level))
	cut = JigsawCut.new(state.grid, float(texture.get_width()), state.cut_seed)

	board_layer = Node2D.new()
	add_child(board_layer)
	guide = GuideLines.new()
	guide.cut = cut
	board_layer.add_child(guide)
	peek_sprite = Sprite2D.new()
	peek_sprite.texture = texture
	peek_sprite.centered = false
	peek_sprite.modulate.a = 0.0
	board_layer.add_child(peek_sprite)
	placed_layer = Node2D.new()
	board_layer.add_child(placed_layer)
	tray_layer = Node2D.new()
	add_child(tray_layer)
	fx_layer = Node2D.new()
	add_child(fx_layer)
	drag_layer = Node2D.new()
	add_child(drag_layer)

	for i in cut.piece_count():
		var node := PieceNode.new()
		node.setup(i, cut, texture)
		pieces[i] = node
		if state.placed[i]:
			placed_layer.add_child(node)
			node.position = _cell_center(i)
		else:
			tray_layer.add_child(node)

	hud_layer = CanvasLayer.new()
	hud_layer.layer = 1
	add_child(hud_layer)
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 2
	add_child(overlay_layer)
	_build_hud()
	get_viewport().size_changed.connect(_layout)
	_layout()
	set_process(false)
	if state.is_complete():
		_complete.call_deferred()


func _cell_center(index: int) -> Vector2:
	return cut.piece_origin(index) + Vector2.ONE * cut.cell * 0.5


# =====================================================================
# Layout
# =====================================================================

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Positions are set by hand (with their own RTL handling): no mirroring.
	hud.layout_direction = Control.LAYOUT_DIRECTION_LTR
	hud_layer.add_child(hud)

	back_button = UIKit.button("<", Vector2(120, 120), 60)
	back_button.text_direction = Control.TEXT_DIRECTION_LTR # keep "<" in Arabic too
	back_button.pressed.connect(_go_home)
	hud.add_child(back_button)
	var title := Lang.t("LEVEL") % state.level if state.level > 0 else Lang.t("PIECES") % state.piece_count()
	title_label = UIKit.label(title, 54)
	hud.add_child(title_label)
	progress_label = UIKit.label("", 36, UIKit.TEXT_DIM)
	hud.add_child(progress_label)
	coins_box = UIKit.coin_pill(46)
	hud.add_child(coins_box)

	hint_buttons.clear()
	for kind in ["peek", "place", "edges"]:
		var cost: int = {"peek": Economy.HINT_PEEK_COST, "place": Economy.HINT_PLACE_COST, "edges": 0}[kind]
		var b := _hint_button(Lang.t(kind.to_upper()), cost)
		b.pressed.connect(_on_hint.bind(kind))
		hud.add_child(b)
		hint_buttons[kind] = b

	toast = UIKit.label("", 44, UIKit.WRONG)
	toast.modulate.a = 0.0
	hud.add_child(toast)
	_refresh_hud()


func _hint_button(text: String, cost: int) -> Button:
	var b := UIKit.button("", Vector2(300, 120), 40, UIKit.BUTTON)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_bottom = -6
	row.add_child(UIKit.label(text, 40))
	if cost > 0:
		var coin := CoinIcon.new()
		coin.custom_minimum_size = Vector2(32, 32)
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(coin)
		row.add_child(UIKit.label(str(cost), 36, UIKit.GOLD_TEXT))
	b.add_child(row)
	return b


func _refresh_hud() -> void:
	progress_label.text = "%d / %d" % [state.placed_count(), state.piece_count()]
	(coins_box.get_node("Amount") as Label).text = str(SaveData.coins)
	if hint_buttons.has("place"):
		hint_buttons["place"].disabled = state.tray.is_empty() or completed
		hint_buttons["peek"].disabled = completed or peeking
		hint_buttons["edges"].disabled = state.tray.is_empty() or completed


func _layout() -> void:
	view_size = get_viewport_rect().size
	var insets := UIKit.safe_insets(get_viewport())
	var top := 30.0 + insets.x
	var bottom := view_size.y - insets.y - 24.0
	var hint_h := 120.0
	var min_tray := 330.0
	var board_px := minf(view_size.x - 60.0, bottom - (top + 170.0) - hint_h - 50.0 - min_tray)
	board_px = maxf(board_px, 300.0)
	board_rect = Rect2((view_size.x - board_px) * 0.5, top + 170.0, board_px, board_px)
	board_scale = board_px / (cut.cell * cut.cols)
	board_layer.position = board_rect.position
	board_layer.scale = Vector2.ONE * board_scale
	guide.queue_redraw()
	for i in pieces:
		if state.placed[i]:
			pieces[i].queue_redraw()

	var hint_y := board_rect.end.y + 34.0
	var tray_top := hint_y + hint_h + 22.0
	tray_rect = Rect2(0, tray_top, view_size.x, maxf(bottom - tray_top, 200.0))
	slot_w = clampf(tray_rect.size.y * 0.8, 200.0, 300.0)
	# Tray pieces fill their slot, even when that is bigger than a board
	# cell (big puzzles): easy to see and grab; they shrink while dragged.
	var on_screen_cell := slot_w / (1.0 + 2.0 * JigsawCut.TAB_REACH)
	tray_scale = on_screen_cell / cut.cell

	back_button.position = Vector2(40, top)
	title_label.size = Vector2(view_size.x, 70)
	title_label.position = Vector2(0, top - 4)
	progress_label.size = Vector2(view_size.x, 50)
	progress_label.position = Vector2(0, top + 68)
	coins_box.position = Vector2(view_size.x - 260, top + 30)
	coins_box.size = Vector2(220, 60)
	var kinds := ["peek", "place", "edges"]
	if Lang.is_rtl():
		kinds.reverse()
	var gap := 24.0
	var bw := (minf(view_size.x - 80.0, 1000.0) - gap * 2.0) / 3.0
	var x0 := (view_size.x - (bw * 3.0 + gap * 2.0)) * 0.5
	for i in kinds.size():
		var b: Button = hint_buttons[kinds[i]]
		b.custom_minimum_size = Vector2(bw, hint_h)
		b.size = Vector2(bw, hint_h)
		b.position = Vector2(x0 + i * (bw + gap), hint_y)
	toast.size = Vector2(view_size.x, 60)
	toast.position = Vector2(0, board_rect.position.y - 64)
	_clamp_scroll()
	_layout_tray(false)
	queue_redraw()


func _max_scroll() -> float:
	return maxf(0.0, TRAY_PAD * 2.0 + slot_w * state.tray.size() - view_size.x)


func _clamp_scroll() -> void:
	scroll = clampf(scroll, 0.0, _max_scroll())


func _slot_position(slot: int) -> Vector2:
	var x := TRAY_PAD + slot_w * (slot + 0.5) - scroll
	# Few pieces: center them.
	var content := TRAY_PAD * 2.0 + slot_w * state.tray.size()
	if content < view_size.x:
		x += (view_size.x - content) * 0.5
	return Vector2(x, tray_rect.get_center().y)


func _layout_tray(animate: bool) -> void:
	for slot in state.tray.size():
		var node: PieceNode = pieces[state.tray[slot]]
		if node == drag_piece or node.get_parent() != tray_layer:
			continue
		var target := _slot_position(slot)
		node.visible = target.x > -slot_w and target.x < view_size.x + slot_w
		if animate and node.visible:
			var tw := node.create_tween().set_parallel()
			tw.tween_property(node, "position", target, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(node, "scale", Vector2.ONE * tray_scale, 0.22)
			tw.chain().tween_callback(node.queue_redraw)
		else:
			node.position = target
			if not node.scale.is_equal_approx(Vector2.ONE * tray_scale):
				node.scale = Vector2.ONE * tray_scale
				node.queue_redraw()


func _draw() -> void:
	# Board frame and tray strip: drawn only when the layout changes.
	# A linen puzzle mat in a white frame that floats on a soft shadow;
	# the frame blushes red for a moment after a wrong drop.
	var frame := UIKit.panel_style(UIKit.BOARD, 30, 0, 14,
		UIKit.BOARD_EDGE.lerp(UIKit.WRONG, wrong_flash), 18)
	draw_style_box(frame, board_rect.grow(22))
	draw_style_box(UIKit.panel_style(Color(UIKit.PANEL, 0.75), 44, 0, 2, UIKit.PANEL_EDGE, 8),
		Rect2(16, tray_rect.position.y, view_size.x - 32, tray_rect.size.y))


# =====================================================================
# Touch
# =====================================================================

func _unhandled_input(event: InputEvent) -> void:
	if overlay != null or completed:
		return
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			touch_start = event.position
			touch_mode = ""
			candidate = -1
			if tray_rect.has_point(event.position):
				touch_mode = "tray"
				candidate = _tray_piece_at(event.position)
				scroll_vel = 0.0
				set_process(false)
		else:
			if touch_mode == "drag":
				_drop()
			elif touch_mode == "scroll" and absf(scroll_vel) > 60.0:
				set_process(true) # fling
			touch_mode = ""
	elif event is InputEventScreenDrag and event.index == 0:
		if touch_mode == "tray" and event.position.distance_to(touch_start) > TOUCH_SLOP:
			# Moving up (even at a slant) picks the piece; sideways scrolls.
			# Nothing to scroll: any movement picks.
			var d: Vector2 = event.position - touch_start
			var wants_piece := -d.y > absf(d.x) * 0.5 or _max_scroll() <= 0.0
			if candidate != -1 and wants_piece:
				_start_drag(candidate, event.position)
			else:
				touch_mode = "scroll"
		if touch_mode == "scroll":
			scroll -= event.relative.x
			scroll_vel = -event.velocity.x
			_clamp_scroll()
			_layout_tray(false)
		elif touch_mode == "drag":
			_move_drag(event.position)


## Tray fling after a quick swipe.
func _process(delta: float) -> void:
	scroll += scroll_vel * delta
	scroll_vel *= pow(0.04, delta)
	var before := scroll
	_clamp_scroll()
	if before != scroll or absf(scroll_vel) < 20.0:
		set_process(false)
	_layout_tray(false)


func _tray_piece_at(pos: Vector2) -> int:
	for slot in state.tray.size():
		if absf(_slot_position(slot).x - pos.x) <= slot_w * 0.5:
			return state.tray[slot]
	return -1


func _lift() -> Vector2:
	return Vector2(0, -cut.cell * board_scale * LIFT_CELLS - 24.0)


func _start_drag(index: int, pos: Vector2) -> void:
	touch_mode = "drag"
	drag_piece = pieces[index]
	drag_piece.visible = true
	drag_piece.reparent(drag_layer)
	drag_piece.lifted = true
	var tw := drag_piece.create_tween()
	tw.tween_property(drag_piece, "scale", Vector2.ONE * board_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(drag_piece.queue_redraw)
	_move_drag(pos)
	Audio.play("pick")


func _move_drag(pos: Vector2) -> void:
	drag_piece.position = pos + _lift()


func _drop() -> void:
	var node := drag_piece
	drag_piece = null
	touch_mode = ""
	node.lifted = false
	var local := (node.global_position - board_rect.position) / board_scale
	var size := cut.cell * cut.cols
	var cell_index := -1
	if local.x >= 0.0 and local.y >= 0.0 and local.x < size and local.y < size:
		cell_index = int(local.y / cut.cell) * cut.cols + int(local.x / cut.cell)
	if state.try_drop(node.index, cell_index):
		_snap(node, 0.12)
		Audio.play("snap", randf_range(0.95, 1.08))
		Audio.vibrate(15)
	else:
		if cell_index >= 0:
			_wrong()
		_return_to_tray(node)
	_save()
	_refresh_hud()


func _snap(node: PieceNode, duration: float) -> void:
	node.reparent(placed_layer)
	node.lifted = false
	node.visible = true
	var target := _cell_center(node.index)
	var tw := node.create_tween().set_parallel()
	tw.tween_property(node, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, duration)
	tw.chain().tween_callback(func():
		node.queue_redraw()
		_sparkle(board_layer.to_global(target)))
	_clamp_scroll()
	_layout_tray(true)
	if state.is_complete():
		get_tree().create_timer(duration + 0.25).timeout.connect(_complete)


func _return_to_tray(node: PieceNode) -> void:
	node.reparent(tray_layer)
	_clamp_scroll()
	_layout_tray(true)


func _wrong() -> void:
	Audio.play("wrong")
	Audio.vibrate(40)
	var tw := create_tween()
	tw.tween_property(self, "wrong_flash", 1.0, 0.08)
	tw.tween_property(self, "wrong_flash", 0.0, 0.35)


func _sparkle(at: Vector2) -> void:
	var s := Sparkle.new()
	s.position = at
	s.radius = cut.cell * board_scale * 0.45
	fx_layer.add_child(s)


func _save() -> void:
	SaveData.current = {} if state.is_complete() else state.to_dict()
	SaveData.write()


func _show_toast(text: String) -> void:
	toast.text = text
	var tw := toast.create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.2)
	tw.tween_property(toast, "modulate:a", 0.0, 0.3)


# =====================================================================
# Hints
# =====================================================================

func _on_hint(kind: String) -> void:
	if completed or drag_piece != null:
		return
	match kind:
		"edges":
			state.sort_edges_first()
			scroll = 0.0
			_layout_tray(true)
			_save()
		"peek":
			if not SaveData.spend_coins(Economy.HINT_PEEK_COST):
				_show_toast(Lang.t("NOT_ENOUGH"))
				return
			peeking = true
			Audio.play("peek")
			var tw := peek_sprite.create_tween()
			tw.tween_property(peek_sprite, "modulate:a", 0.45, 0.3)
			tw.tween_interval(Economy.PEEK_SECONDS)
			tw.tween_property(peek_sprite, "modulate:a", 0.0, 0.4)
			tw.tween_callback(func():
				peeking = false
				_refresh_hud())
		"place":
			if state.tray.is_empty():
				return
			if not SaveData.spend_coins(Economy.HINT_PLACE_COST):
				_show_toast(Lang.t("NOT_ENOUGH"))
				return
			# The first piece the player can see in the tray.
			var slot := clampi(int(scroll / slot_w), 0, state.tray.size() - 1)
			var index := state.tray[slot]
			state.place_by_hint(index)
			_snap(pieces[index], 0.45)
			Audio.play("magic")
			_save()
	_refresh_hud()


# =====================================================================
# Complete / leave
# =====================================================================

func _complete() -> void:
	if completed:
		return
	completed = true
	guide.visible = false
	# A clean copy of the picture fades in over the pieces (no seams).
	var final := Sprite2D.new()
	final.texture = texture
	final.centered = false
	final.modulate.a = 0.0
	board_layer.add_child(final)
	var tw := create_tween()
	tw.tween_property(final, "modulate:a", 1.0, 0.6)
	var won := SaveData.finish_puzzle(state)
	_refresh_hud()
	Audio.play("win")
	Audio.vibrate(60)
	tw.tween_interval(0.5)
	tw.tween_callback(_show_complete_panel.bind(won))


func _show_complete_panel(won: int) -> void:
	var panel := OverlayPanel.new()
	panel.add_text(Lang.t("COMPLETE"), 72, UIKit.TEXT)
	var stars := StarRow.new()
	stars.count = state.stars()
	stars.shown = 0.0
	stars.custom_minimum_size = Vector2(660, 150)
	panel.box.add_child(stars)
	var tw := stars.create_tween()
	tw.tween_interval(0.25)
	for i in 3:
		tw.tween_property(stars, "shown", float(i + 1), 0.3)
		if i < stars.count:
			tw.tween_callback(Audio.play.bind("star", 1.0 + 0.12 * i))
	tw.tween_callback(Audio.play.bind("coin"))
	panel.add_text(Lang.t("MISTAKES") % state.mistakes, 40, UIKit.TEXT_DIM)
	panel.add_text(Lang.t("COINS_WON") % won, 54, UIKit.GOLD_TEXT)
	if state.level > 0:
		panel.add_button(Lang.t("NEXT"), func(): play_level.emit(state.level + 1), UIKit.ACCENT)
	else:
		panel.add_button(Lang.t("GALLERY"), func(): open_gallery.emit(), UIKit.ACCENT)
	panel.add_button(Lang.t("HOME"), _go_home)
	_show_overlay(panel)


func _show_overlay(panel: OverlayPanel) -> void:
	overlay = panel
	overlay_layer.add_child(panel)


func _go_home() -> void:
	if not completed:
		_save()
	exit_to_home.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_home()
	elif what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		# A call or the home button can cut a drag off with no "finger up":
		# put the piece back so it is not left hanging.
		cancel_drag()
		if state != null and not completed:
			_save()


func cancel_drag() -> void:
	if drag_piece == null:
		return
	var node := drag_piece
	drag_piece = null
	touch_mode = ""
	node.lifted = false
	_return_to_tray(node)
