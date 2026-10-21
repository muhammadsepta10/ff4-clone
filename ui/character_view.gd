## Farmer avatar drawn from an outfit dictionary (hat, shirt, colour) in the
## game's cartoon style: soft shapes with dark ink outlines.
class_name CharacterView
extends Control

const COLORS := {"red": Color("#d9534f"), "blue": Color("#4a86c8"), "green": Color("#5cb85c"), "gold": Color("#e6b800")}
const INK := Color("#3b2a1a")
const SKIN := Color("#f6c99b")
const HAIR := Color("#6b3e1f")

var outfit := {}:
	set(v):
		outfit = v
		queue_redraw()

var _u := 1.0
var _c := Vector2.ZERO
var _t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(220, 260)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _p(v: Vector2) -> Vector2:
	return _c + v * _u


func _ellipse(center: Vector2, r: Vector2, fill: Color, outline := true, from := 0.0, to := TAU) -> void:
	var pts := PackedVector2Array()
	var n := 28
	for i in n + 1:
		var a := lerpf(from, to, float(i) / n)
		pts.append(_p(center + Vector2(cos(a) * r.x, sin(a) * r.y)))
	if to - from < TAU - 0.01:
		pts.append(_p(center))
	draw_colored_polygon(pts, fill)
	if outline:
		draw_polyline(pts, INK, 4.0 * _u, true)


func _poly(points: Array, fill: Color, outline := true) -> void:
	var pts := PackedVector2Array()
	for v in points:
		pts.append(_p(v))
	draw_colored_polygon(pts, fill)
	if outline:
		pts.append(pts[0])
		draw_polyline(pts, INK, 4.0 * _u, true)


func _rbox(r: Rect2, fill: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = INK
	sb.set_border_width_all(int(4 * _u))
	sb.set_corner_radius_all(int(radius * _u))
	sb.anti_aliasing = true
	draw_style_box(sb, Rect2(_p(r.position), r.size * _u))


func _draw() -> void:
	_u = minf(size.x / 220.0, size.y / 260.0)
	_c = size / 2 + Vector2(0, 10 * _u)
	var main: Color = COLORS.get(outfit.get("color", "red"), COLORS.red)
	var shirt: String = outfit.get("shirt", "plaid")
	var breathe := sin(_t * 2.0) * 1.5
	# shadow
	draw_set_transform(_p(Vector2(0, 118)), 0, Vector2(1, 0.25))
	draw_circle(Vector2.ZERO, 70 * _u, Color(0, 0, 0, 0.15))
	draw_set_transform(Vector2.ZERO)
	# arms behind the body
	_rbox(Rect2(Vector2(-78, 22 + breathe), Vector2(30, 74)), main.darkened(0.1), 14)
	_rbox(Rect2(Vector2(48, 22 + breathe), Vector2(30, 74)), main.darkened(0.1), 14)
	_ellipse(Vector2(-63, 98 + breathe), Vector2(14, 13), SKIN)
	_ellipse(Vector2(63, 98 + breathe), Vector2(14, 13), SKIN)
	# body
	_rbox(Rect2(Vector2(-56, 10 + breathe), Vector2(112, 112)), main, 34)
	match shirt:
		"plaid":
			var dark := main.darkened(0.3)
			for i in 3:
				var x := -30.0 + i * 30
				draw_line(_p(Vector2(x, 16 + breathe)), _p(Vector2(x, 116 + breathe)), dark, 5 * _u)
			for j in 3:
				var y := 40.0 + j * 28 + breathe
				draw_line(_p(Vector2(-52, y)), _p(Vector2(52, y)), dark, 5 * _u)
			_poly([Vector2(-20, 12 + breathe), Vector2(0, 34 + breathe), Vector2(20, 12 + breathe)], main.lightened(0.25))
		"overall":
			_rbox(Rect2(Vector2(-40, 46 + breathe), Vector2(80, 76)), Color("#3f6fb0"), 14)
			draw_line(_p(Vector2(-34, 14 + breathe)), _p(Vector2(-30, 50 + breathe)), Color("#3f6fb0"), 9 * _u)
			draw_line(_p(Vector2(34, 14 + breathe)), _p(Vector2(30, 50 + breathe)), Color("#3f6fb0"), 9 * _u)
			_ellipse(Vector2(-26, 56 + breathe), Vector2(5, 5), Color("#f1c232"))
			_ellipse(Vector2(26, 56 + breathe), Vector2(5, 5), Color("#f1c232"))
			_rbox(Rect2(Vector2(-16, 70 + breathe), Vector2(32, 22)), Color("#5a8ad0"), 6)
		"apron":
			_rbox(Rect2(Vector2(-38, 34 + breathe), Vector2(76, 88)), Color("#fffaf0"), 18)
			_rbox(Rect2(Vector2(-18, 74 + breathe), Vector2(36, 22)), Color("#f3e2b8"), 6)
	# head
	var hy := -40.0 + breathe * 0.6
	_ellipse(Vector2(-50, hy + 4), Vector2(11, 14), SKIN)
	_ellipse(Vector2(50, hy + 4), Vector2(11, 14), SKIN)
	_ellipse(Vector2(0, hy), Vector2(50, 48), SKIN)
	# hair fringe under the hat
	_ellipse(Vector2(0, hy - 30), Vector2(46, 20), HAIR, true, PI, TAU)
	# face
	var blink := 0.15 if fmod(_t, 3.6) > 3.45 else 1.0
	for sx in [-1.0, 1.0]:
		_ellipse(Vector2(18 * sx, hy - 2), Vector2(9, 11 * blink), Color.WHITE, blink > 0.5)
		if blink > 0.5:
			_ellipse(Vector2(18 * sx + 1, hy), Vector2(5, 6), INK, false)
			_ellipse(Vector2(18 * sx + 3, hy - 3), Vector2(2, 2), Color.WHITE, false)
		_ellipse(Vector2(30 * sx, hy + 16), Vector2(9, 6), Color(0.95, 0.45, 0.4, 0.45), false)
	_ellipse(Vector2(0, hy + 8), Vector2(6, 5), SKIN.darkened(0.12), false)
	draw_arc(_p(Vector2(0, hy + 14)), 15 * _u, 0.35, PI - 0.35, 14, INK, 4 * _u, true)
	# hat
	match outfit.get("hat", "straw"):
		"straw":
			_ellipse(Vector2(0, hy - 34), Vector2(78, 16), Color("#e8c37a"))
			_ellipse(Vector2(0, hy - 46), Vector2(40, 30), Color("#e8c37a"), true, PI, TAU)
			draw_line(_p(Vector2(-38, hy - 40)), _p(Vector2(38, hy - 40)), main, 7 * _u)
		"cap":
			_ellipse(Vector2(0, hy - 34), Vector2(48, 36), main, true, PI, TAU)
			_poly([Vector2(10, hy - 38), Vector2(78, hy - 32), Vector2(74, hy - 22), Vector2(10, hy - 28)], main.darkened(0.25))
			_ellipse(Vector2(0, hy - 70), Vector2(6, 5), main.darkened(0.25))
		"bandana":
			_ellipse(Vector2(0, hy - 30), Vector2(50, 30), Color("#cc3333"), true, PI, TAU)
			_poly([Vector2(44, hy - 34), Vector2(70, hy - 50), Vector2(66, hy - 22)], Color("#cc3333"))
			for i in 4:
				_ellipse(Vector2(-30 + i * 20, hy - 44 + (i % 2) * 6), Vector2(3, 3), Color.WHITE, false)
		"crown":
			_poly([Vector2(-40, hy - 30), Vector2(-44, hy - 76), Vector2(-20, hy - 54), Vector2(0, hy - 84),
				Vector2(20, hy - 54), Vector2(44, hy - 76), Vector2(40, hy - 30)], Color("#f1c232"))
			_ellipse(Vector2(0, hy - 44), Vector2(7, 7), Color("#d9534f"))
