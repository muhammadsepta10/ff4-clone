## Draws the farm field from LevelSession state (fixed camera, Y-sorted, ADR 0002)
## and turns taps into commands. Never mutates simulation state except via commands.
## Art is procedural placeholder until the approved asset batch lands.
class_name FarmView
extends Control

signal command(cmd: Dictionary)

const SCALE := 0.75

const PRODUCT_COLORS := {
	"egg": Color("#fff8e7"), "milk": Color("#e8f4ff"), "wool": Color("#f4f4f4"), "fluff_egg": Color("#ffb6d9"),
	"caged_bear": Color("#8b5a2b"), "pastry": Color("#e3a857"), "butter": Color("#ffe066"), "cloth": Color("#7fb3d5"),
	"cake": Color("#f5a3c7"), "coat": Color("#a0522d"),
}

var _prev := {}   # uid -> Vector2 (field units) from the previous tick
var _cur: Dictionary = {}
var _alpha := 1.0
var _time := 0.0
var _fx: Array = []  # floating texts/pops: {pos, text, color, life, max}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false


## Called after every simulation tick with the new state.
func push_state(st: Dictionary) -> void:
	_prev.clear()
	if not _cur.is_empty():
		for e in _cur.animals + _cur.predators:
			_prev[e.uid] = Vector2(e.x, e.y)
	_cur = st


func set_alpha(a: float) -> void:
	_alpha = clampf(a, 0.0, 1.0)


func pop_text(field_pos: Vector2, text: String, color := Color.WHITE) -> void:
	_fx.append({"pos": field_pos, "text": text, "color": color, "life": 1.0, "max": 1.0})


func _process(delta: float) -> void:
	_time += delta
	for f in _fx.duplicate():
		f.life -= delta
		if f.life <= 0:
			_fx.erase(f)
	queue_redraw()


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if _cur.is_empty():
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	var p: Vector2 = event.position / SCALE
	for pr in _cur.predators:
		if p.distance_to(_pos(pr)) < 100:
			command.emit(Cmd.tap_predator(pr.uid))
			return
	var best = null
	var best_d := 70.0
	for g in _cur.ground:
		var d := p.distance_to(Vector2(g.x, g.y))
		if d < best_d:
			best_d = d
			best = g
	if best != null:
		command.emit(Cmd.collect(best.uid))
		return
	for h in _cur.hidden_items:
		if not h.found and p.distance_to(Vector2(h.x, h.y)) < 60:
			command.emit(Cmd.find_hidden_item(h.id))
			return
	var cell: int = _cur.field.cell
	command.emit(Cmd.plant_grass(int(p.x) / cell, int(p.y) / cell))


# ---------------------------------------------------------------- drawing

func _pos(e: Dictionary) -> Vector2:
	var now := Vector2(e.x, e.y)
	return _prev.get(e.uid, now).lerp(now, _alpha)


func _draw() -> void:
	if _cur.is_empty():
		return
	var f: Dictionary = _cur.field
	var w: float = f.cols * f.cell * SCALE
	var h: float = f.rows * f.cell * SCALE
	draw_rect(Rect2(Vector2(-14, -14), Vector2(w + 28, h + 28)), Color("#8b6b3d"))
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color("#c8a96a"))
	var cs: float = f.cell * SCALE
	for i in _cur.grass.size():
		var g: int = _cur.grass[i]
		if g <= 0:
			continue
		var o := Vector2((i % f.cols) * cs, (i / f.cols) * cs)
		draw_rect(Rect2(o + Vector2(2, 2), Vector2(cs - 4, cs - 4)), Color("#7cb342").lerp(Color("#33691e"), g / 3.0 - 0.33))
		for k in g * 3:
			var t := o + Vector2(10 + (k * 23) % int(cs - 20), 14 + (k * 37) % int(cs - 24))
			draw_line(t, t + Vector2(-4, -12 - sin(_time * 3 + k) * 2), Color("#aed581"), 3)
			draw_line(t, t + Vector2(4, -12 + sin(_time * 3 + k) * 2), Color("#aed581"), 3)
	for hi in _cur.hidden_items:
		if not hi.found:
			var hp := Vector2(hi.x, hi.y) * SCALE
			var a := 0.12 + 0.08 * sin(_time * 2 + hi.x)
			draw_circle(hp, 10, Color(1, 1, 0.7, a))
			draw_line(hp - Vector2(14, 0), hp + Vector2(14, 0), Color(1, 1, 1, a), 2)
			draw_line(hp - Vector2(0, 14), hp + Vector2(0, 14), Color(1, 1, 1, a), 2)
	var items: Array = []
	for a in _cur.animals:
		items.append({"y": _pos(a).y, "kind": "animal", "e": a})
	for g in _cur.ground:
		items.append({"y": float(g.y) - 1, "kind": "ground", "e": g})
	for p in _cur.predators:
		items.append({"y": _pos(p).y, "kind": "predator", "e": p})
	items.sort_custom(func(a, b): return a.y < b.y)
	for it in items:
		match it.kind:
			"animal": _draw_animal(it.e)
			"ground": _draw_product(it.e.product, Vector2(it.e.x, it.e.y) * SCALE, it.e.life)
			"predator": _draw_predator(it.e)
	var font := get_theme_default_font()
	for fx in _fx:
		var t: float = 1.0 - fx.life / fx.max
		var c: Color = fx.color
		c.a = 1.0 - t
		var pos: Vector2 = fx.pos * SCALE + Vector2(-40, -40 - t * 60)
		draw_string_outline(font, pos, fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 6, Color(0, 0, 0, c.a * 0.7))
		draw_string(font, pos, fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, c)


func _draw_animal(a: Dictionary) -> void:
	var p := _pos(a) * SCALE
	var prev: Vector2 = _prev.get(a.uid, Vector2(a.x, a.y))
	var face := -1.0 if a.x < prev.x else 1.0
	var bob := absf(sin(_time * 9 + a.uid)) * 5.0
	var squash := 1.0 + sin(_time * 18 + a.uid) * 0.04
	draw_set_transform(p + Vector2(0, -bob), 0, Vector2(face * squash, 2.0 - squash))
	draw_circle(Vector2(0, bob + 26), 26, Color(0, 0, 0, 0.18))
	match a.type:
		"chicken":
			draw_circle(Vector2.ZERO, 24, Color.WHITE)
			draw_circle(Vector2(18, -18), 13, Color.WHITE)
			draw_circle(Vector2(18, -32), 6, Color("#e53935"))
			draw_colored_polygon(PackedVector2Array([Vector2(30, -20), Vector2(40, -16), Vector2(30, -12)]), Color("#ffb300"))
			draw_circle(Vector2(22, -21), 2.5, Color.BLACK)
		"sheep", "fluffhen":
			var wool := Color.WHITE if a.type == "sheep" else Color("#ffc1e3")
			for k in 6:
				draw_circle(Vector2(cos(k) * 18, sin(k) * 10 - 4), 17, wool)
			var head := Color("#3e2723") if a.type == "sheep" else Color("#ff8a80")
			draw_circle(Vector2(30, -12), 12, head)
			draw_circle(Vector2(34, -15), 2.5, Color.WHITE)
		"cow":
			draw_rect(Rect2(-34, -22, 68, 40), Color.WHITE)
			draw_circle(Vector2(-14, -8), 9, Color.BLACK)
			draw_circle(Vector2(10, 6), 7, Color.BLACK)
			draw_circle(Vector2(38, -20), 15, Color.WHITE)
			draw_circle(Vector2(44, -16), 7, Color("#f8bbd0"))
			draw_circle(Vector2(40, -25), 2.5, Color.BLACK)
	draw_set_transform(Vector2.ZERO)
	if a.hungry:
		var bp := p + Vector2(0, -70 - absf(sin(_time * 5)) * 6)
		draw_circle(bp, 22, Color.WHITE)
		draw_circle(bp, 22, Color("#e53935"), false, 3)
		draw_string(get_theme_default_font(), bp + Vector2(-6, 12), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("#e53935"))


func _draw_product(product: String, p: Vector2, life: int) -> void:
	if life < 50 and int(_time * 8) % 2 == 0:
		return
	var c: Color = PRODUCT_COLORS.get(product, Color.WHITE)
	draw_circle(p + Vector2(0, 14), 18, Color(0, 0, 0, 0.2))
	match product:
		"egg", "fluff_egg":
			draw_set_transform(p, 0, Vector2(0.8, 1.0))
			draw_circle(Vector2.ZERO, 20, c)
			draw_circle(Vector2(-6, -6), 6, Color(1, 1, 1, 0.7))
			draw_set_transform(Vector2.ZERO)
		"milk":
			draw_rect(Rect2(p + Vector2(-14, -18), Vector2(28, 36)), c)
			draw_rect(Rect2(p + Vector2(-8, -28), Vector2(16, 12)), Color("#90caf9"))
		"wool":
			for k in 4:
				draw_circle(p + Vector2(cos(k * 1.6) * 9, sin(k * 1.6) * 7), 13, c)
		"caged_bear":
			draw_rect(Rect2(p + Vector2(-34, -34), Vector2(68, 60)), Color("#6d4c41"))
			for k in 5:
				draw_line(p + Vector2(-30 + k * 15, -34), p + Vector2(-30 + k * 15, 26), Color("#424242"), 4)
		_:
			draw_rect(Rect2(p + Vector2(-20, -20), Vector2(40, 40)), c)
			draw_rect(Rect2(p + Vector2(-20, -20), Vector2(40, 40)), c.darkened(0.4), false, 3)
			draw_string(get_theme_default_font(), p + Vector2(-10, 10), App.tr(product).substr(0, 1).to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 28, c.darkened(0.6))


func _draw_predator(pr: Dictionary) -> void:
	var p := _pos(pr) * SCALE
	var shake := Vector2(sin(_time * 40) * 3, 0) if pr.hits > 0 else Vector2.ZERO
	p += shake
	var needed: int = App.core.catalog().farm.predators[pr.type].hits
	if pr.type == "bear":
		draw_circle(p + Vector2(0, 34), 40, Color(0, 0, 0, 0.2))
		draw_circle(p, 42, Color("#795548"))
		draw_circle(p + Vector2(-26, -34), 14, Color("#795548"))
		draw_circle(p + Vector2(26, -34), 14, Color("#795548"))
		draw_circle(p + Vector2(0, 8), 16, Color("#d7ccc8"))
		draw_circle(p + Vector2(-14, -10), 5, Color.BLACK)
		draw_circle(p + Vector2(14, -10), 5, Color.BLACK)
	else:
		draw_circle(p + Vector2(0, 14), 30, Color("#6d4c41"))
		draw_circle(p, 20, Color("#9e9e9e"))
		draw_circle(p + Vector2(0, 8), 6, Color("#f48fb1"))
		draw_circle(p + Vector2(-8, -4), 3, Color.BLACK)
		draw_circle(p + Vector2(8, -4), 3, Color.BLACK)
	if pr.hits > 0:
		draw_arc(p, 58, -PI / 2, -PI / 2 + TAU * pr.hits / needed, 32, Color("#ffeb3b"), 8)
