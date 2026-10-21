## Top-of-screen road from the farm to the town. While the truck is away its
## icon drives along the road to town and back, like the original's HUD.
class_name TransportBar
extends Control

const ROAD := Color("#7a4a22")
const ROAD_EDGE := Color("#4a2c12")

var _frac := 0.0      # 0 farm … 1 town (shown, eased toward _target)
var _target := 0.0
var _back := false    # returning
var _away := false


func _init() -> void:
	size = Vector2(560, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `left` and `trip` in ticks; left == 0 means the truck is home.
func set_trip(left: int, trip: int) -> void:
	_away = left > 0 and trip > 0
	if not _away:
		_target = 0.0
		_back = false
		return
	var done := 1.0 - float(left) / trip
	_back = done >= 0.5
	_target = done * 2.0 if not _back else (1.0 - done) * 2.0


func _process(delta: float) -> void:
	var f := move_toward(_frac, _target, delta * 1.5)
	if not is_equal_approx(f, _frac):
		_frac = f
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2(40, 22), Vector2(size.x - 80, 20))
	draw_style_box(_box(ROAD, ROAD_EDGE), r)
	var x := r.position.x + 16.0
	while x < r.end.x - 16:
		draw_line(Vector2(x, r.get_center().y), Vector2(x + 14, r.get_center().y), Color("#e8c37a"), 3.0)
		x += 30
	_icon("warehouse", Vector2(24, 32), 58, false)
	_city(Vector2(size.x - 24, 32))
	var tx := lerpf(r.position.x + 20, r.end.x - 20, _frac)
	# Art faces left; it drives right (to town) mirrored, left on the way back.
	_icon("truck", Vector2(tx, 30), 46 if _away else 40, not _back)


func _icon(id: String, c: Vector2, h: float, mirror: bool) -> void:
	var t := Art.tex(id)
	if t == null:
		draw_circle(c, h / 3, Color.WHITE)
		return
	var w := h * t.get_width() / t.get_height()
	draw_set_transform(c, 0, Vector2(-1 if mirror else 1, 1))
	draw_texture_rect(t, Rect2(Vector2(-w / 2, -h / 2), Vector2(w, h)), false)
	draw_set_transform(Vector2.ZERO)


## A tiny town: three houses with red roofs.
func _city(c: Vector2) -> void:
	for i in 3:
		var o := c + Vector2((i - 1) * 16, (i % 2) * 6 - 4)
		draw_rect(Rect2(o + Vector2(-10, -6), Vector2(20, 20)), Color("#fff3d6"))
		draw_rect(Rect2(o + Vector2(-10, -6), Vector2(20, 20)), ROAD_EDGE, false, 2.0)
		draw_colored_polygon(PackedVector2Array([o + Vector2(-13, -6), o + Vector2(0, -20), o + Vector2(13, -6)]), Color("#d9534f"))


func _box(bg: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	return sb
