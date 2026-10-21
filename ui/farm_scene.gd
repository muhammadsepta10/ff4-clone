## Painted backdrop for a level: sky, rolling hills, river, fence and a dirt yard that
## the field and buildings stand on. Drawn procedurally so it stays sharp at any
## resolution; decoration sprites (trees) come from Art. Purely visual.
class_name FarmScene
extends Control

const STAGE := Vector2(1920, 1080)
const YARD_CENTER := Vector2(960, 655)
const YARD_RADII := Vector2(930, 445)

var _yard := PackedVector2Array()
var _speckles: Array = []   # [pos, radius, color]
var _flowers: Array = []    # [pos, color]
var _trees: Array = []      # [foot, height]


func _init() -> void:
	size = STAGE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 96:
		var a := TAU * i / 96.0
		var c := cos(a)
		var s := sin(a)
		# Superellipse (squarer than an ellipse) with a gentle wobble.
		var r := 1.0 + 0.025 * sin(a * 7) + 0.02 * sin(a * 13 + 1.0)
		var x := signf(c) * pow(absf(c), 0.6) * YARD_RADII.x * r
		var y := signf(s) * pow(absf(s), 0.6) * YARD_RADII.y * r
		_yard.append(YARD_CENTER + Vector2(x, y))
	for i in 260:
		var p := Vector2(rng.randf_range(120, 1800), rng.randf_range(260, 1060))
		if _in_yard(p):
			_speckles.append([p, rng.randf_range(3, 9), Color("#c99b45") if rng.randf() < 0.6 else Color("#f3d58c")])
	for i in 140:
		var p := Vector2(rng.randf_range(0, 1920), rng.randf_range(270, 1080))
		if not _in_yard(p):
			_flowers.append([p, [Color.WHITE, Color("#fff176"), Color("#f8bbd0")][rng.randi() % 3]])
	for f in [Vector2(70, 330), Vector2(1850, 320), Vector2(40, 620), Vector2(1880, 640), Vector2(230, 250),
			Vector2(1690, 245), Vector2(1880, 980), Vector2(30, 990)]:
		_trees.append([f, rng.randf_range(150, 200)])


func _in_yard(p: Vector2) -> bool:
	var d := (p - YARD_CENTER) / (YARD_RADII * 0.98)
	return pow(absf(d.x), 1 / 0.6) + pow(absf(d.y), 1 / 0.6) <= 1.0


func _draw() -> void:
	# Sky
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(STAGE.x, 0), Vector2(STAGE.x, 260), Vector2(0, 260)]),
		PackedColorArray([Color("#8fd3f4"), Color("#8fd3f4"), Color("#e8f7ff"), Color("#e8f7ff")]))
	# Hills, far to near
	_hill(150, 40, 0.004, 0.0, Color("#a5d6a7"))
	_hill(185, 34, 0.006, 2.0, Color("#8bc34a"))
	_hill(215, 26, 0.009, 4.0, Color("#7cb342"))
	# River
	var river := PackedVector2Array()
	for x in range(0, 1941, 40):
		river.append(Vector2(x, 232 + sin(x * 0.01) * 6))
	for x in range(1920, -41, -40):
		river.append(Vector2(x, 262 + sin(x * 0.01 + 1) * 6))
	draw_colored_polygon(river, Color("#4fb3e8"))
	for x in range(30, 1920, 140):
		draw_line(Vector2(x, 244 + sin(x * 0.01) * 6), Vector2(x + 50, 244 + sin((x + 50) * 0.01) * 6), Color(1, 1, 1, 0.5), 3)
	# Meadow
	draw_rect(Rect2(0, 262, STAGE.x, STAGE.y - 262), Color("#8cc63f"))
	for f in _flowers:
		draw_circle(f[0], 4, f[1])
	# Fence along the river bank
	for x in range(10, 1920, 70):
		draw_rect(Rect2(x, 262, 10, 34), Color("#8b5a2b"))
	draw_line(Vector2(0, 272), Vector2(1920, 272), Color("#a0703a"), 6)
	draw_line(Vector2(0, 288), Vector2(1920, 288), Color("#a0703a"), 6)
	# Trees behind the yard
	for t in _trees:
		_sprite("tree", t[0], t[1])
	# Yard: grass rim, then dirt with a lighter centre
	var rim := PackedVector2Array()
	for p in _yard:
		rim.append(YARD_CENTER + (p - YARD_CENTER) * 1.025)
	draw_colored_polygon(rim, Color("#6e9f2c"))
	for i in _yard.size():
		var j := (i + 1) % _yard.size()
		draw_polygon(PackedVector2Array([YARD_CENTER, _yard[i], _yard[j]]),
			PackedColorArray([Color("#f0cf7d"), Color("#d9ad55"), Color("#d9ad55")]))
	for s in _speckles:
		draw_set_transform(s[0], 0, Vector2(1, 0.5))
		draw_circle(Vector2.ZERO, s[1], s[2])
	draw_set_transform(Vector2.ZERO)


func _hill(base: float, amp: float, freq: float, phase: float, color: Color) -> void:
	var pts := PackedVector2Array([Vector2(0, 300)])
	for x in range(0, 1941, 30):
		pts.append(Vector2(x, base - amp * (0.6 * sin(x * freq + phase) + 0.4 * sin(x * freq * 2.3 + phase * 1.7))))
	pts.append(Vector2(1920, 300))
	draw_colored_polygon(pts, color)


func _sprite(id: String, foot: Vector2, height: float) -> void:
	var t := Art.tex(id)
	if t == null:
		return
	var sz := Vector2(height * t.get_width() / float(t.get_height()), height)
	draw_texture_rect(t, Rect2(foot - Vector2(sz.x / 2, sz.y), sz), false)
