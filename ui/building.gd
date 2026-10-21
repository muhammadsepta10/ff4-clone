## A tappable building standing in the farm scene: sprite, a name/status badge under
## it and an optional green upgrade-price tag, like the buildings in the reference.
## Pressing gives a small squash tween and emits `tapped`.
class_name Building
extends Control

signal tapped

const BADGE_BG := Color("#5d3a1a")
const BADGE_FG := Color("#fff3d6")
const TAG_BG := Color("#2e7d32")

var sprite_id := ""
var _tex: Texture2D
var _height := 160.0
var _badge: Label
var _tag: Label
var _tag_panel: PanelContainer
var _badge_panel: PanelContainer
var _bar: ProgressBar
var _bar_color := Color.TRANSPARENT
var _squash := 0.0
var _bob := 0.0


## `height` is the drawn sprite height in stage px; the control is centred on `foot`.
func setup(id: String, foot: Vector2, height: float) -> Building:
	sprite_id = id
	_height = height
	set_sprite(id)
	var w := _height * (_tex.get_width() / float(_tex.get_height()) if _tex else 1.0)
	size = Vector2(maxf(w, 140), _height)
	position = foot - Vector2(size.x / 2, size.y)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_badge_panel = _pill(BADGE_BG)
	_badge = _pill_label(_badge_panel, 26)
	_tag_panel = _pill(TAG_BG)
	_tag = _pill_label(_tag_panel, 24)
	_tag_panel.visible = false
	return self


func set_sprite(id: String) -> void:
	_tex = Art.tex(id)
	queue_redraw()


func set_badge(text: String) -> void:
	if _badge.text == text and _badge_panel.visible == (text != ""):
		return
	_badge.text = text
	_badge_panel.visible = text != ""
	_place_pills()


## Upgrade price tag; empty hides it.
func set_tag(text: String) -> void:
	if _tag.text == text and _tag_panel.visible == (text != ""):
		return
	_tag.text = text
	_tag_panel.visible = text != ""
	_place_pills()


## Vertical meter at the building's side (well water, workshop progress). value < 0 hides it.
func set_meter(value: float, max_value: float, color: Color) -> void:
	if _bar == null:
		_bar = ProgressBar.new()
		_bar.show_percentage = false
		_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar.size = Vector2(22, size.y * 0.6)
		_bar.position = Vector2(size.x + 4, size.y * 0.3)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.35)
		bg.set_corner_radius_all(8)
		_bar.add_theme_stylebox_override("background", bg)
		add_child(_bar)
	if color != _bar_color:
		_bar_color = color
		var fill := StyleBoxFlat.new()
		fill.bg_color = color
		fill.set_corner_radius_all(8)
		_bar.add_theme_stylebox_override("fill", fill)
	_bar.visible = value >= 0
	_bar.max_value = max_value
	_bar.value = value


func bounce() -> void:
	_squash = 1.0


func _pill(bg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	sb.border_color = Color(0, 0, 0, 0.35)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	return p


func _pill_label(p: PanelContainer, font: int) -> Label:
	var l := UI.label("", font, BADGE_FG)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return l


func _place_pills() -> void:
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	_badge_panel.reset_size()
	_badge_panel.position = Vector2((size.x - _badge_panel.size.x) / 2, size.y - 8)
	_tag_panel.reset_size()
	_tag_panel.position = Vector2((size.x - _tag_panel.size.x) / 2, -_tag_panel.size.y + 10)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		bounce()
		App.play_sfx("click")
		tapped.emit()


func _process(delta: float) -> void:
	_bob += delta
	if _squash > 0:
		_squash = maxf(0.0, _squash - delta * 4)
		queue_redraw()


func _draw() -> void:
	if _tex == null:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#8b6b3d"))
		return
	var w := _height * _tex.get_width() / float(_tex.get_height())
	var s := sin(_squash * PI) * 0.08
	var sz := Vector2(w * (1 + s), _height * (1 - s))
	var foot := Vector2(size.x / 2, size.y)
	draw_set_transform(foot + Vector2(0, -12), 0, Vector2(1, 0.32))
	draw_circle(Vector2.ZERO, w * 0.45, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect(_tex, Rect2(foot - Vector2(sz.x / 2, sz.y), sz), false)
