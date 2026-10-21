## Game-style window: a wooden frame on parchment with a green title ribbon and
## a round close button, popping in over the farm. Used for every in-level window
## so the game never shows plain web-like dialogs.
class_name GamePopup
extends Control

signal closed

const WOOD := Color("#8d5a2b")
const WOOD_DARK := Color("#5d3a1a")
const PAPER := Color("#fdf1d4")
const RIBBON := Color("#6aa84f")
const RIBBON_DARK := Color("#38761d")

var body: VBoxContainer  # put content here
var _frame: PanelContainer
var _dim: ColorRect
var _ribbon: Control
var _x: Control


## Opens a popup on `parent`. `closable` adds the round ✕ button.
static func open(parent: Node, title: String, closable := true, dim := 0.35) -> GamePopup:
	var p := GamePopup.new()
	p._build(title, closable, dim)
	parent.add_child(p)
	return p


static func frame_style(bg := PAPER, border := WOOD, radius := 34, width := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 6)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 56
	sb.content_margin_bottom = 32
	return sb


## A round, chunky game button (the theme's default buttons are flatter).
static func big_button(text: String, cb: Callable, color := RIBBON, size := 40) -> Button:
	var b := UI.button(text, cb, size)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		var c := color
		match state:
			"hover": c = color.lightened(0.12)
			"pressed": c = color.darkened(0.15)
			"disabled": c = Color(0.62, 0.6, 0.56)
		sb.bg_color = c
		sb.border_color = c.darkened(0.4)
		sb.set_border_width_all(5)
		sb.border_width_bottom = 10 if state != "pressed" else 5
		sb.set_corner_radius_all(30)
		sb.content_margin_left = 34
		sb.content_margin_right = 34
		sb.content_margin_top = 10
		sb.content_margin_bottom = 14
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", color.darkened(0.55))
	b.add_theme_constant_override("outline_size", 8)
	return b


func _build(title: String, closable: bool, dim: float) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = Color(0.08, 0.05, 0.02, dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override("panel", frame_style())
	center.add_child(_frame)
	body = UI.vbox([], 18)
	_frame.add_child(body)
	# Ribbon and close button hang off the frame's edge, so they are placed
	# after layout instead of living inside the container.
	var ribbon := PanelContainer.new()
	var rs := frame_style(RIBBON, RIBBON_DARK, 24, 6)
	rs.content_margin_top = 6
	rs.content_margin_bottom = 10
	rs.content_margin_left = 48
	rs.content_margin_right = 48
	rs.shadow_size = 6
	ribbon.add_theme_stylebox_override("panel", rs)
	var tl := UI.label(title, 42, Color.WHITE)
	tl.add_theme_color_override("font_outline_color", RIBBON_DARK.darkened(0.3))
	tl.add_theme_constant_override("outline_size", 10)
	ribbon.add_child(tl)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.visible = title != ""
	add_child(ribbon)
	var x: Button = null
	if closable:
		x = big_button("✕", close, Color("#d9534f"), 36)
		x.custom_minimum_size = Vector2(96, 96)
		add_child(x)
	_ribbon = ribbon
	_x = x
	# pop in
	_frame.modulate.a = 0.0
	_frame.scale = Vector2(0.7, 0.7)


func _ready() -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(_frame, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_frame, "modulate:a", 1.0, 0.12)


# Ribbon and ✕ hang off the frame's edge; follow it every frame (cheap, and
# correct while the frame pops in or changes size).
func _process(_d: float) -> void:
	_frame.pivot_offset = _frame.size / 2
	_ribbon.modulate.a = _frame.modulate.a
	var r := Rect2(_frame.position, _frame.size)
	_ribbon.reset_size()
	_ribbon.position = r.position + Vector2((r.size.x - _ribbon.size.x) / 2, -_ribbon.size.y / 2) + _frame.get_parent().position
	if _x != null:
		_x.position = r.position + Vector2(r.size.x - 70, -30) + _frame.get_parent().position


## Rebuilds the content in place (no pop animation), e.g. after a command.
func clear() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()


func close() -> void:
	closed.emit()
	queue_free()


## A square product/animal tile: icon, a count badge and an optional caption.
static func tile(icon_id: String, count: String, caption: String, cb: Callable, enabled := true, px := 132) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(px, px + (34 if caption != "" else 0))
	b.disabled = not enabled
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color("#fff8e6"), "hover": Color("#fffdf3"), "pressed": Color("#f3e2b8"), "disabled": Color("#e9dfc8")}[state]
		sb.border_color = Color("#c9a66b")
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(22)
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(func():
		App.play_sfx("click")
		cb.call())
	var icon: Control = Art.icon(icon_id, int(px * 0.62))
	if Art.tex(icon_id) == null:
		icon = UI.label("◉", int(px * 0.45), Color("#e6b800"))
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.size = Vector2(px * 0.62, px * 0.62)
	icon.position = Vector2((px - px * 0.62) / 2, 12)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not enabled:
		icon.modulate = Color(1, 1, 1, 0.45)
	b.add_child(icon)
	if count != "":
		var badge := PanelContainer.new()
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color("#5d3a1a")
		bs.set_corner_radius_all(16)
		bs.content_margin_left = 10
		bs.content_margin_right = 10
		badge.add_theme_stylebox_override("panel", bs)
		badge.add_child(UI.label(count, 26, Color.WHITE))
		badge.position = Vector2(px - 64, px - 46)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
	if caption != "":
		var cl := UI.label(caption, 24)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.position = Vector2(0, px - 2)
		cl.size = Vector2(px, 32)
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cl)
	return b
