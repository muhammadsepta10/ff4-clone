## Draws the farm field from LevelSession state (fixed camera, Y-sorted, ADR 0002)
## and turns taps into commands. Never mutates simulation state except via commands.
## Sprites come from approved asset batches in art/ (style bible); anything without
## an approved sprite yet falls back to procedural placeholder art.
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
var _grass_shown := {}  # cell index -> displayed growth, eased toward the sim value
# Walk animation state per uid (view only).
var _phase := {}     # step phase, advanced by distance walked
var _face := {}      # -1 left, +1 right; only flips on clear horizontal movement
var _last := {}      # last drawn position, to measure walking
var _moving := {}    # 0..1, eased walking amount
var _peck := {}      # seconds left of the eating animation
var _spawned := {}   # ground uid -> seconds since it appeared (pop-in)
var _flying: Array = []  # collected products flying to the warehouse: {product, from, to, t}
var warehouse_pos := Vector2(-130, 700)  # warehouse in this view's local px; set by the screen

# Fraction of each sprite's height that is legs, swung while walking.
const LEGS := {"chicken": 0.24, "sheep": 0.2, "cow": 0.22, "bear": 0.22, "fluffhen": 0.24}


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


## Visual reactions to simulation events (called by the game screen).
func on_event(e: Dictionary) -> void:
	match e.type:
		"animal_ate":
			_peck[e.uid] = 0.7
		"product_spawned":
			_spawned[e.uid] = 0.0
		"product_collected":
			_flying.append({"product": e.product, "from": Vector2(e.x, e.y) * SCALE, "to": warehouse_pos, "t": 0.0})


func pop_text(field_pos: Vector2, text: String, color := Color.WHITE) -> void:
	_fx.append({"pos": field_pos, "text": text, "color": color, "life": 1.0, "max": 1.0})


func _process(delta: float) -> void:
	_time += delta
	for f in _fx.duplicate():
		f.life -= delta
		if f.life <= 0:
			_fx.erase(f)
	for k in _peck.keys():
		_peck[k] -= delta
		if _peck[k] <= 0:
			_peck.erase(k)
	for k in _spawned.keys():
		_spawned[k] += delta
		if _spawned[k] > 1.0:
			_spawned.erase(k)
	for f in _flying.duplicate():
		f.t += delta / 0.7
		if f.t >= 1.0:
			_flying.erase(f)
	if not _cur.is_empty():
		_advance_walk(delta)
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
	var cs: float = f.cell * SCALE
	if Art.tex("grass") == null:
		_draw_grass_placeholder(f, cs)
	else:
		_draw_grass(f, cs)
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
			"ground": _draw_ground(it.e)
			"predator": _draw_predator(it.e)
	for fl in _flying:
		var t: float = fl.t
		var pos: Vector2 = fl.from.lerp(fl.to, t * t) + Vector2(0, -sin(t * PI) * 160)
		var sc := 1.0 - 0.5 * t
		draw_set_transform(pos, 0, Vector2(sc, sc))
		if Art.tex(fl.product) != null:
			_draw_sprite(fl.product, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO)
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
	if Art.tex(a.type) != null:
		draw_set_transform(p + Vector2(0, 26), 0, Vector2(1, 0.4))
		draw_circle(Vector2.ZERO, Art.height(a.type) * 0.32, Color(0, 0, 0, 0.18))
		draw_set_transform(Vector2.ZERO)
		_draw_walker(a.type, a.uid, p + Vector2(0, 26))
		_draw_hungry(a, p)
		return
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
	_draw_hungry(a, p)


## Draws a sprite centred on x with its bottom edge at `feet`, in the current draw transform.
func _draw_sprite(type: String, feet: Vector2) -> void:
	var tex := Art.tex(type)
	var hgt := Art.height(type)
	var sz := Vector2(hgt * tex.get_width() / tex.get_height(), hgt)
	draw_texture_rect(tex, Rect2(feet - Vector2(sz.x / 2, sz.y), sz), false)


func _draw_hungry(a: Dictionary, p: Vector2) -> void:
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
	if Art.tex(product) != null:
		_draw_sprite(product, p + Vector2(0, 18))
		return
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
	if Art.tex(pr.type) != null:
		var feet := 34.0 if pr.type == "bear" else 24.0
		draw_set_transform(p + Vector2(0, feet - 4), 0, Vector2(1, 0.4))
		draw_circle(Vector2.ZERO, Art.height(pr.type) * 0.4, Color(0, 0, 0, 0.2))
		draw_set_transform(Vector2.ZERO)
		if LEGS.has(pr.type):
			_draw_walker(pr.type, pr.uid, p + Vector2(0, feet))
		else:
			# Mole: stretches up out of its hole and ducks back.
			var t := Art.tex(pr.type)
			var hgt := Art.height(pr.type)
			var sz := Vector2(hgt * t.get_width() / t.get_height(), hgt)
			var up := 0.9 + 0.12 * absf(sin(_time * 3 + pr.uid))
			var foot := p + Vector2(0, feet)
			draw_texture_rect(t, Rect2(foot - Vector2(sz.x / 2 * (2 - up), sz.y * up), Vector2(sz.x * (2 - up), sz.y * up)), false)
	elif pr.type == "bear":
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


## Grass as overlapping tufts with jittered positions, so planted cells read as an
## organic patch. Growth eases in and out instead of popping.
func _draw_grass(f: Dictionary, cs: float) -> void:
	var tex := Art.tex("grass")
	var k := 1.0 - exp(-get_process_delta_time() * 6.0)
	for i in _cur.grass.size():
		var target: float = _cur.grass[i]
		var shown: float = _grass_shown.get(i, 0.0)
		shown = lerpf(shown, target, k)
		if absf(shown - target) < 0.01:
			shown = target
		if shown <= 0.02:
			_grass_shown.erase(i)
			continue
		_grass_shown[i] = shown
		var o := Vector2((i % f.cols) * cs, (i / f.cols) * cs)
		for t in 4:
			var h := hash(i * 7 + t)
			var j := Vector2((h % 1000) / 1000.0, ((h / 1000) % 1000) / 1000.0)
			var foot := o + Vector2(cs * (0.15 + 0.7 * j.x), cs * (0.35 + 0.6 * j.y))
			var hgt := 30.0 + 16.0 * shown * (0.85 + 0.3 * j.x)
			var sz := Vector2(hgt * tex.get_width() / tex.get_height(), hgt)
			var sway := sin(_time * 2.0 + i * 0.7 + t) * 0.04
			draw_set_transform(foot, sway, Vector2.ONE)
			draw_texture_rect(tex, Rect2(Vector2(-sz.x / 2, -sz.y), sz), false)
	draw_set_transform(Vector2.ZERO)


func _draw_grass_placeholder(f: Dictionary, cs: float) -> void:
	for i in _cur.grass.size():
		var g: int = _cur.grass[i]
		if g > 0:
			var o := Vector2((i % f.cols) * cs, (i / f.cols) * cs)
			draw_rect(Rect2(o + Vector2(2, 2), Vector2(cs - 4, cs - 4)), Color("#7cb342").lerp(Color("#33691e"), g / 3.0 - 0.33))


func _draw_ground(g: Dictionary) -> void:
	var p := Vector2(g.x, g.y) * SCALE
	if _spawned.has(g.uid):
		# Pop out of the animal with a small arc and an overshooting scale.
		var t: float = minf(_spawned[g.uid] / 0.35, 1.0)
		var sc := 1.0 + sin(t * PI) * 0.35 if t < 1.0 else 1.0
		sc *= t
		var lift := sin(t * PI) * 30.0
		draw_set_transform(p + Vector2(0, -lift), 0, Vector2(sc, sc))
		_draw_product(g.product, Vector2.ZERO, g.life)
		draw_set_transform(Vector2.ZERO)
	else:
		_draw_product(g.product, p, g.life)


func _advance_walk(delta: float) -> void:
	var seen := {}
	for e in _cur.animals + _cur.predators:
		var uid: int = e.uid
		seen[uid] = true
		var now := _pos(e)
		var last: Vector2 = _last.get(uid, now)
		var moved := now.distance_to(last)
		_last[uid] = now
		if absf(now.x - last.x) > 0.3:
			_face[uid] = 1.0 if now.x > last.x else -1.0
		var target := 1.0 if moved > 0.05 else 0.0
		_moving[uid] = lerpf(_moving.get(uid, 0.0), target, 1.0 - exp(-delta * 10.0))
		# About one step per 22 field units walked.
		_phase[uid] = fmod(_phase.get(uid, randf() * TAU) + moved * TAU / 22.0, TAU * 100)
	for k in _last.keys():
		if not seen.has(k):
			_last.erase(k)
			_face.erase(k)
			_moving.erase(k)
			_phase.erase(k)


## Draws a walking sprite with its feet at `foot`: the body bobs and waddles while
## the leg strip is split in two halves that swing in opposite directions, so the
## animal visibly steps. Eating tilts the body forward (a peck).
func _draw_walker(type: String, uid: int, foot: Vector2) -> void:
	var tex := Art.tex(type)
	var hgt := Art.height(type)
	var W := hgt * tex.get_width() / tex.get_height()
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var lf: float = LEGS.get(type, 0.2)
	var ph: float = _phase.get(uid, 0.0)
	var mv: float = _moving.get(uid, 0.0)
	var face: float = _face.get(uid, 1.0)
	var idle := sin(_time * 2.5 + uid) * 0.015
	var bob := absf(sin(ph)) * 3.0 * mv
	var waddle := sin(ph) * 0.07 * mv + idle
	var peck := 0.0
	if _peck.has(uid):
		var t: float = 1.0 - _peck[uid] / 0.7
		peck = absf(sin(t * PI * 3)) * 0.35
	# Art faces left; mirror to face the walking direction. Origin at the feet.
	var base := Transform2D(waddle, Vector2(-face, 1), 0, foot + Vector2(0, -bob))
	var hip := -hgt * lf
	# Legs: two halves swinging opposite ways around the hip line.
	var swing := sin(ph) * 0.45 * mv
	for half in 2:
		var sk := swing if half == 0 else -swing
		draw_set_transform_matrix(base * Transform2D(0, Vector2.ONE, sk, Vector2(0, hip)))
		var sx := 0.0 if half == 0 else tw / 2
		draw_texture_rect_region(tex, Rect2(-W / 2 + half * W / 2, 0, W / 2, hgt * lf),
			Rect2(sx, th * (1 - lf), tw / 2, th * lf))
	# Body, pivoting at the hip for the peck (forward is -x in art space).
	draw_set_transform_matrix(base * Transform2D(-peck, Vector2(1, 1 + sin(ph * 2) * 0.02 * mv), 0, Vector2(0, hip)))
	draw_texture_rect_region(tex, Rect2(-W / 2, -hgt * (1 - lf), W, hgt * (1 - lf) + 1),
		Rect2(0, 0, tw, th * (1 - lf) + 1))
	draw_set_transform(Vector2.ZERO)
