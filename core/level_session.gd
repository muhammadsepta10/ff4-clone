## One level being played. Deterministic: fixed 10 ticks per second, all randomness
## from the session's seeded RNG, integer-only state (ADR 0005). The only float
## operation is sqrt in _dist(), which IEEE 754 requires to be correctly rounded.
## Create through GameCore.start_session() / GameCore.restore_session().
##
## Rules follow the original game's mechanics (ADR 0004): animals produce only
## while fed and fall asleep when hungry with no grass; buildings and the well,
## warehouse, truck and plane have four levels; the warehouse counts space by
## item size; bears scare animals until caged; cats pick up goods, dogs cage bears.
class_name LevelSession
extends RefCounted

const TICKS_PER_SECOND := 10
const SNAPSHOT_VERSION := 2
const SLOTS := 6
const MAX_LEVEL := 4

var _c: Content
var _s: Dictionary
var _rng := RandomNumberGenerator.new()
var _events: Array = []


# ---------------------------------------------------------------- lifecycle

static func create(content: Content, level: Dictionary, seed: int, boost_ids: Array) -> LevelSession:
	var ses := LevelSession.new()
	ses._c = content
	ses._rng.seed = seed
	ses._init_state(level.duplicate(true), boost_ids)
	return ses


static func restore(content: Content, snap: Dictionary) -> LevelSession:
	assert(snap.get("version", 0) == SNAPSHOT_VERSION, "unsupported snapshot version")
	var ses := LevelSession.new()
	ses._c = content
	ses._s = snap.state.duplicate(true)
	ses._rng.seed = snap.rng_seed
	ses._rng.state = snap.rng_state
	ses._events = snap.events.duplicate(true)
	return ses


func snapshot() -> Dictionary:
	return {
		"version": SNAPSHOT_VERSION,
		"state": _s.duplicate(true),
		"rng_seed": _rng.seed,
		"rng_state": _rng.state,
		"events": _events.duplicate(true),
	}


func _init_state(lvl: Dictionary, boost_ids: Array) -> void:
	var well_lv: int = lvl.get("well_level", 1)
	_s = {
		"level": lvl,
		"tick": 0,
		"money": lvl.start_money,
		"next_uid": 1,
		"grass": _filled(_c.farm.field.cols * _c.farm.field.rows, 0),
		"well": {"level": well_lv, "water": _well_def(well_lv).water, "refill_left": 0},
		"animals": [],
		"ground": [],
		"warehouse": {"level": lvl.get("warehouse_level", 1), "bonus": 0, "items": {}},
		"workshops": _filled(SLOTS, null),
		"truck": {"level": 1, "cargo": {}, "left": 0},
		"plane": {"level": 1, "cargo": {}, "left": 0},
		"predators": [],
		"pred_warned": _filled(lvl.predators.size(), false),
		"pred_spawned": _filled(lvl.predators.size(), false),
		"click_meter": {"fill": 0, "found": []},
		"boosts": [],
		"goals": [],
		"collected": {},
		"stats": {"collected": {}, "products_crafted": 0, "bears_caged": 0, "moles_chased": 0,
			"animals_bought": 0, "trucks_sent": 0, "planes_sent": 0, "money_earned": 0,
			"hidden_found": 0, "click_rewards": 0, "grass_planted": 0},
		"won": false,
		"win_tick": -1,
		"trophy": "",
	}
	for i in mini(SLOTS, lvl.slots.size()):
		for o in lvl.slots[i]:
			if o.level > 0:
				_s.workshops[i] = _new_building(o.type, o.level)
				break
	for g in lvl.goals:
		var goal := {"type": g.type, "target": g.get("count", g.get("amount", 0)), "progress": 0, "done": false}
		if g.has("product"): goal.product = g.product
		if g.has("animal"): goal.animal = g.animal
		_s.goals.append(goal)
	for sa in lvl.start_animals:
		for i in sa.count:
			_spawn_animal(sa.type, _rand_x(), _rand_y())
	for id in boost_ids:
		var b: Dictionary = _c.boosts[id]
		match b.effect:
			"start_money": _s.money += b.value
			"big_warehouse": _s.warehouse.bonus += b.value
		if b.duration_ticks > 0:
			_s.boosts.append({"id": id, "effect": b.effect, "value": b.value, "left": b.duration_ticks})
	_schedule_predators()
	_evaluate_goals()


# ---------------------------------------------------------------- public API

func advance(ticks: int) -> void:
	for i in ticks:
		if _s.won:
			return
		_step()


func apply(cmd: Dictionary) -> bool:
	if _s.won:
		return false
	var ok := false
	match cmd.get("type", ""):
		"buy_animal": ok = _buy_animal(cmd.animal)
		"sell_animal": ok = _sell_animal(cmd.uid)
		"plant_grass": ok = _plant_grass(cmd.cx, cmd.cy)
		"refill_well": ok = _refill_well()
		"upgrade_well": ok = _upgrade_well()
		"collect": ok = _collect(cmd.uid)
		"build_workshop": ok = _build_workshop(cmd.slot, cmd.workshop)
		"upgrade_workshop": ok = _upgrade_workshop(cmd.slot)
		"sell_workshop": ok = _sell_workshop(cmd.slot)
		"start_workshop": ok = _start_workshop(cmd.slot)
		"upgrade_warehouse": ok = _upgrade_warehouse()
		"load_truck": ok = _load_truck(cmd.product, cmd.qty)
		"unload_truck": ok = _unload_truck(cmd.product, cmd.qty)
		"send_truck": ok = _send_truck()
		"upgrade_truck": ok = _upgrade_vehicle("truck")
		"order_plane": ok = _order_plane(cmd.product, cmd.qty)
		"send_plane": ok = _send_plane()
		"upgrade_plane": ok = _upgrade_vehicle("plane")
		"tap_predator": ok = _tap_predator(cmd.uid)
		"tap": ok = _tap()
		"find_hidden_item": ok = _find_hidden(cmd.id)
	if ok:
		_evaluate_goals()
	return ok


## Read-only copy of the state plus derived values for the view, bot and tests.
func state() -> Dictionary:
	var st := _s.duplicate(true)
	var lvl: Dictionary = st.level
	st.erase("level")
	st.erase("pred_warned")
	st.erase("pred_spawned")
	st.level_id = lvl.id
	st.field = _c.farm.field.duplicate()
	st.trophy = lvl.trophy.duplicate()
	st.trophy_won = _s.trophy
	st.trophy_now = _s.trophy if _s.won else _trophy_at(_s.tick)
	var wd := _well_def(_s.well.level)
	st.well.capacity = wd.water
	st.well.refill_ticks = wd.refill_ticks
	st.well.refill_price = _c.farm.well.refill_price
	_upgrade_info(st.well, "well", _s.well.level, _c.farm.well.levels)
	st.warehouse.capacity = _warehouse_capacity()
	st.warehouse.used = _warehouse_used()
	_upgrade_info(st.warehouse, "warehouse", _s.warehouse.level, _c.farm.warehouse.levels)
	for v in ["truck", "plane"]:
		var t: Dictionary = st[v]
		var d: Dictionary = _c.farm[v].levels[_s[v].level - 1]
		t.available = lvl.get(v, false)
		t.capacity = d.capacity
		t.used = _size_of(_s[v].cargo)
		t.away = _s[v].left > 0
		t.trip_ticks = d.trip_ticks
		_upgrade_info(t, v, _s[v].level, _c.farm[v].levels)
		t.can_upgrade = t.can_upgrade and t.available and not t.away
	st.plane.cost = _plane_cost()
	st.available_animals = lvl.available_animals.duplicate()
	st.slots = []
	for i in SLOTS:
		var opts: Array = lvl.slots[i].map(func(o): return o.type) if i < lvl.slots.size() else []
		st.slots.append(opts)
		var w = st.workshops[i]
		if w != null:
			var d: Dictionary = _c.workshops[w.type]
			var ld: Dictionary = d.levels[w.level - 1]
			w.duration = _workshop_duration(_s.workshops[i])
			w.queue_max = ld.queue
			w.inputs = d.inputs.duplicate()
			w.output = d.output
			_upgrade_info(w, w.type, w.level, d.levels)
			w.sell_price = _building_sell_price(_s.workshops[i])
			w.x = _workshop_x(i)
			w.y = _workshop_y()
	st.hidden_items = lvl.hidden_items.map(func(h): return {"id": h.id, "x": h.x, "y": h.y, "found": _s.click_meter.found.has(h.id)})
	st.hidden_items_left = lvl.hidden_items.size() - _s.click_meter.found.size()
	var total := 0
	for g in _s.grass:
		total += g
	st.grass_total = total
	return st


func poll_events() -> Array:
	var e := _events
	_events = []
	return e


func is_won() -> bool:
	return _s.won


func level_id() -> String:
	return _s.level.id


func tick() -> int:
	return _s.tick


func result() -> Dictionary:
	return {
		"level_id": _s.level.id,
		"won": _s.won,
		"ticks": _s.win_tick if _s.won else _s.tick,
		"trophy": _s.trophy,
		"money": _s.money,
		"stats": _s.stats.duplicate(true),
	}


# ---------------------------------------------------------------- simulation step

func _step() -> void:
	_s.tick += 1
	_schedule_predators()
	_tick_well()
	_tick_boosts()
	_tick_animals()
	_tick_ground()
	_tick_workshops()
	_tick_truck()
	_tick_plane()
	_tick_predators()
	_evaluate_goals()


func _tick_well() -> void:
	var w: Dictionary = _s.well
	if w.refill_left > 0:
		w.refill_left -= 1
		if w.refill_left == 0:
			w.water = _well_def(w.level).water
			_emit("well_refilled", {})


func _tick_boosts() -> void:
	for b in _s.boosts.duplicate():
		b.left -= 1
		if b.left <= 0:
			_s.boosts.erase(b)
			_emit("boost_expired", {"id": b.id})


func _boost_value(effect: String) -> int:
	var v := 0
	for b in _s.boosts:
		if b.effect == effect:
			v += b.value
	return v


func _tick_animals() -> void:
	for a in _s.animals:
		var d: Dictionary = _c.animals[a.type]
		match d.role:
			"cat": _tick_cat(a, d)
			"dog": _tick_dog(a, d)
			_: _tick_producer(a, d)


## Fed animals walk around and produce; hungry ones look for grass and eat
## `bites` units of it; with no grass they doze off until grass is planted.
func _tick_producer(a: Dictionary, d: Dictionary) -> void:
	var bear = _scary_bear(a)
	if bear != null:
		a.scared = true
		a.asleep = false
		var away := Vector2i(a.x - bear.x, a.y - bear.y)
		if away == Vector2i.ZERO:
			away = Vector2i(1, 0)
		_move(a, clampi(a.x + away.x * 4, 30, _field_w() - 30), clampi(a.y + away.y * 4, 30, _field_h() - 30), d.run_speed)
		return
	a.scared = false
	if a.full > 0:
		a.full -= 1
		a.produce += 10 * (100 + _boost_value("fast_production")) / 100
		if a.produce >= d.produce_ticks * 10:
			a.produce -= d.produce_ticks * 10
			_spawn_ground(d.product, a.x, a.y)
		if a.full == 0:
			a.hungry = true
			a.hungry_ticks = 0
			_emit("animal_hungry", {"uid": a.uid, "x": a.x, "y": a.y})
		if _move(a, a.tx, a.ty, d.speed):
			a.tx = _rand_x()
			a.ty = _rand_y()
		return
	var cell := _nearest_grass(a.x, a.y)
	if cell < 0:
		a.hungry_ticks += 1
		if not a.asleep and a.hungry_ticks >= d.sleep_after_ticks:
			a.asleep = true
			_emit("animal_asleep", {"uid": a.uid, "x": a.x, "y": a.y})
		if not a.asleep and _move(a, a.tx, a.ty, d.speed):
			a.tx = _rand_x()
			a.ty = _rand_y()
		return
	if a.asleep:
		a.asleep = false
		_emit("animal_woke", {"uid": a.uid})
	if _move(a, _cell_cx(cell), _cell_cy(cell), d.speed):
		_s.grass[cell] -= 1
		a.eaten += 1
		if a.eaten >= d.bites:
			a.eaten = 0
			a.full = d.food_ticks
			a.hungry = false
			a.hungry_ticks = 0
			_emit("animal_ate", {"uid": a.uid})


## Cats walk to the nearest good on the ground and carry it to the warehouse.
func _tick_cat(a: Dictionary, d: Dictionary) -> void:
	var best = null
	var best_d := 1 << 40
	for g in _s.ground:
		if g.product == _cage_product() or not _fits(g.product, 1):
			continue
		var dd := _dist(a.x, a.y, g.x, g.y)
		if dd < best_d:
			best_d = dd
			best = g
	if best == null:
		if _move(a, a.tx, a.ty, d.speed):
			a.tx = _rand_x()
			a.ty = _rand_y()
		return
	_move(a, best.x, best.y, d.run_speed)
	if _dist(a.x, a.y, best.x, best.y) <= _c.farm.helpers.cat.pick_range:
		_collect(best.uid)


## Dogs run at the nearest bear and cage it on contact.
func _tick_dog(a: Dictionary, d: Dictionary) -> void:
	var best = null
	var best_d := 1 << 40
	for p in _s.predators:
		if p.type != "bear":
			continue
		var dd := _dist(a.x, a.y, p.x, p.y)
		if dd < best_d:
			best_d = dd
			best = p
	if best == null:
		if _move(a, a.tx, a.ty, d.speed):
			a.tx = _rand_x()
			a.ty = _rand_y()
		return
	_move(a, best.x, best.y, d.run_speed)
	if _dist(a.x, a.y, best.x, best.y) <= _c.farm.helpers.dog.catch_range:
		_cage_bear(best)


func _scary_bear(a: Dictionary):
	var r: int = _c.farm.predators.bear.scare_range
	for p in _s.predators:
		if p.type == "bear" and _dist(a.x, a.y, p.x, p.y) <= r:
			return p
	return null


func _tick_ground() -> void:
	for g in _s.ground.duplicate():
		g.life -= 1
		if g.life > 0:
			continue
		_s.ground.erase(g)
		if g.product == _cage_product():
			var pr := _spawn_predator("bear", g.x, g.y, "")
			_emit("bear_escaped", {"uid": pr.uid, "x": g.x, "y": g.y})
		else:
			_emit("product_expired", {"uid": g.uid, "product": g.product, "x": g.x, "y": g.y})


func _tick_workshops() -> void:
	for i in SLOTS:
		var w = _s.workshops[i]
		if w == null or w.left == 0:
			continue
		w.left -= 1
		if w.left > 0:
			continue
		var out: String = _c.workshops[w.type].output
		_s.stats.products_crafted += 1
		_spawn_ground(out, _workshop_x(i) + _rng.randi_range(-30, 30), _workshop_y() + 70)
		_emit("workshop_done", {"slot": i, "product": out})
		if w.queued > 0:
			w.queued -= 1
			w.left = _batch_ticks(w)


func _tick_truck() -> void:
	var t: Dictionary = _s.truck
	if t.left == 0:
		return
	t.left -= 1
	if t.left == 0:
		var earned := 0
		for p in t.cargo:
			earned += _c.products[p].sell_price * t.cargo[p]
		t.cargo = {}
		_s.money += earned
		_s.stats.money_earned += earned
		_emit("truck_returned", {"money": earned})


func _tick_plane() -> void:
	var t: Dictionary = _s.plane
	if t.left == 0:
		return
	t.left -= 1
	if t.left > 0:
		return
	var fw := _field_w()
	var fh := _field_h()
	for p in t.cargo:
		for i in t.cargo[p]:
			var g := _spawn_ground(p, fw - 60 - _rng.randi_range(0, 160), fh / 2 + _rng.randi_range(-220, 220))
			g.bought = true
	_emit("plane_returned", {"cargo": t.cargo.duplicate()})
	t.cargo = {}


func _schedule_predators() -> void:
	var warn: int = _c.farm.predator_warning_ticks
	var plan: Array = _s.level.predators
	for i in plan.size():
		var p: Dictionary = plan[i]
		if not _s.pred_warned[i] and _s.tick >= p.tick - warn:
			_s.pred_warned[i] = true
			_emit("predator_warning", {"predator": p.type, "arrives_at": p.tick})
		if not _s.pred_spawned[i] and _s.tick >= p.tick:
			_s.pred_spawned[i] = true
			for n in p.get("count", 1):
				var pr := _spawn_predator(p.type, _rand_x(), _rand_y(), p.get("tier", ""))
				_emit("predator_arrived", {"uid": pr.uid, "predator": p.type, "x": pr.x, "y": pr.y})


func _spawn_predator(type: String, x: int, y: int, tier: String) -> Dictionary:
	var d: Dictionary = _c.farm.predators[type]
	var hits: int = d.hits[tier] if d.hits is Dictionary else d.hits
	var pr := {"uid": _uid(), "type": type, "x": x, "y": y, "tx": _rand_x(), "ty": _rand_y(),
		"hits": 0, "needed": hits, "decay": 0, "life": d.get("life_ticks", 0), "eat": 0}
	_s.predators.append(pr)
	return pr


func _tick_predators() -> void:
	for p in _s.predators.duplicate():
		var d: Dictionary = _c.farm.predators[p.type]
		if p.hits > 0:
			p.decay += 1
			if p.decay >= d.hit_decay_ticks:
				p.hits -= 1
				p.decay = 0
		if _move(p, p.tx, p.ty, d.speed):
			p.tx = _rand_x()
			p.ty = _rand_y()
		if p.type == "mole":
			_tick_mole(p, d)


func _tick_mole(p: Dictionary, d: Dictionary) -> void:
	p.life -= 1
	if p.life <= 0:
		_s.predators.erase(p)
		_emit("predator_left", {"uid": p.uid, "predator": p.type})
		return
	p.eat += 1
	if p.eat < d.eat_every_ticks:
		return
	p.eat = 0
	var cols: int = _c.farm.field.cols
	var rows: int = _c.farm.field.rows
	var cell: int = _c.farm.field.cell
	var cx: int = clampi(p.x / cell, 0, cols - 1)
	var cy: int = clampi(p.y / cell, 0, rows - 1)
	var eaten := false
	for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var x: int = cx + off.x
		var y: int = cy + off.y
		if x >= 0 and y >= 0 and x < cols and y < rows and _s.grass[y * cols + x] > 0:
			_s.grass[y * cols + x] = 0
			eaten = true
	if eaten:
		_emit("grass_eaten", {"uid": p.uid, "cx": cx, "cy": cy})
	for g in _s.ground.duplicate():
		if g.product != _cage_product() and _dist(p.x, p.y, g.x, g.y) <= d.eat_range:
			_s.ground.erase(g)
			_emit("product_stolen", {"uid": g.uid, "product": g.product})


func _evaluate_goals() -> void:
	if _s.won:
		return
	var all_done := true
	for g in _s.goals:
		match g.type:
			"collect": g.progress = _s.collected.get(g.product, 0)
			"money": g.progress = _s.money
			"animal": g.progress = _s.animals.filter(func(a): return a.type == g.animal).size()
		if not g.done and g.progress >= g.target:
			g.done = true
			_emit("goal_reached", {"goal": _s.goals.find(g)})
		all_done = all_done and g.done
	if all_done:
		_s.won = true
		_s.win_tick = _s.tick
		_s.trophy = _trophy_at(_s.tick)
		_emit("level_won", {"ticks": _s.tick, "trophy": _s.trophy})


func _trophy_at(t: int) -> String:
	var lim: Dictionary = _s.level.trophy
	return "gold" if t <= lim.gold_ticks else ("silver" if t <= lim.silver_ticks else "bronze")


# ---------------------------------------------------------------- commands

func _buy_animal(type: String) -> bool:
	var d = _c.animals.get(type)
	if d == null or not d.buyable or not _s.level.available_animals.has(type) or _s.money < d.price:
		return false
	_s.money -= d.price
	var a := _spawn_animal(type, _rand_x(), _rand_y())
	_s.stats.animals_bought += 1
	_emit("animal_bought", {"uid": a.uid, "animal": type})
	return true


func _sell_animal(uid: int) -> bool:
	var a = _find(_s.animals, uid)
	if a == null:
		return false
	_s.animals.erase(a)
	_s.money += _c.animals[a.type].sell_price
	_emit("animal_sold", {"uid": uid, "animal": a.type})
	return true


func _plant_grass(cx: int, cy: int) -> bool:
	var cols: int = _c.farm.field.cols
	var rows: int = _c.farm.field.rows
	if cx < 0 or cy < 0 or cx >= cols or cy >= rows or _s.well.water <= 0 or _s.well.refill_left > 0:
		return false
	_s.well.water -= 1
	var mx: int = _c.farm.grass.max
	for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var x: int = cx + off.x
		var y: int = cy + off.y
		if x >= 0 and y >= 0 and x < cols and y < rows:
			_s.grass[y * cols + x] = mx
	_s.stats.grass_planted += 1
	_emit("grass_planted", {"cx": cx, "cy": cy})
	if _s.well.water == 0:
		_emit("well_empty", {})
	return true


func _refill_well() -> bool:
	var w: Dictionary = _s.well
	var price: int = _c.farm.well.refill_price
	if w.refill_left > 0 or w.water >= _well_def(w.level).water or _s.money < price:
		return false
	_s.money -= price
	w.refill_left = _well_def(w.level).refill_ticks
	_emit("well_refilling", {})
	return true


func _upgrade_well() -> bool:
	var w: Dictionary = _s.well
	if w.refill_left > 0 or not _pay_upgrade("well", w.level, _c.farm.well.levels):
		return false
	w.level += 1
	w.water = _well_def(w.level).water
	_emit("well_upgraded", {"level": w.level})
	return true


func _collect(uid: int) -> bool:
	var g = _find(_s.ground, uid)
	if g == null:
		return false
	if not _fits(g.product, 1):
		_emit("warehouse_full", {"product": g.product})
		return false
	_s.ground.erase(g)
	_add(_s.warehouse.items, g.product, 1)
	# Goods bought in town are ingredients only; collect goals count what the farm makes.
	if not g.get("bought", false):
		_add(_s.collected, g.product, 1)
	_add(_s.stats.collected, g.product, 1)
	_emit("product_collected", {"uid": uid, "product": g.product, "x": g.x, "y": g.y})
	return true


func _build_workshop(slot: int, type: String) -> bool:
	if slot < 0 or slot >= SLOTS or _s.workshops[slot] != null:
		return false
	if not _slot_options(slot).has(type):
		return false
	var price: int = _c.workshops[type].levels[0].price
	if _s.money < price:
		return false
	_s.money -= price
	_s.workshops[slot] = _new_building(type, 1)
	_emit("workshop_built", {"slot": slot, "workshop": type})
	return true


func _upgrade_workshop(slot: int) -> bool:
	var w = _workshop_at(slot)
	if w == null or not _pay_upgrade(w.type, w.level, _c.workshops[w.type].levels):
		return false
	w.level += 1
	_emit("workshop_upgraded", {"slot": slot, "level": w.level})
	return true


func _sell_workshop(slot: int) -> bool:
	var w = _workshop_at(slot)
	if w == null or w.left > 0:
		return false
	_s.money += _building_sell_price(w)
	_s.workshops[slot] = null
	_emit("workshop_sold", {"slot": slot})
	return true


## Starts a batch, or queues it while one is running (queue size grows with level).
func _start_workshop(slot: int) -> bool:
	var w = _workshop_at(slot)
	if w == null:
		return false
	var d: Dictionary = _c.workshops[w.type]
	var busy: int = (1 if w.left > 0 else 0) + w.queued
	if busy >= d.levels[w.level - 1].queue:
		return false
	for p in d.inputs:
		if _s.warehouse.items.get(p, 0) < d.inputs[p]:
			return false
	for p in d.inputs:
		_add(_s.warehouse.items, p, -d.inputs[p])
	if w.left > 0:
		w.queued += 1
		_emit("workshop_queued", {"slot": slot, "queued": w.queued})
	else:
		w.left = _batch_ticks(w)
		_emit("workshop_started", {"slot": slot})
	return true


func _upgrade_warehouse() -> bool:
	if not _pay_upgrade("warehouse", _s.warehouse.level, _c.farm.warehouse.levels):
		return false
	_s.warehouse.level += 1
	_emit("warehouse_upgraded", {"level": _s.warehouse.level})
	return true


func _load_truck(product: String, qty: int) -> bool:
	var t: Dictionary = _s.truck
	if not _s.level.get("truck", false) or t.left > 0 or qty <= 0 or _s.warehouse.items.get(product, 0) < qty:
		return false
	if _size_of(t.cargo) + _c.products[product].size * qty > _vehicle(t, "truck").capacity:
		return false
	_add(_s.warehouse.items, product, -qty)
	_add(t.cargo, product, qty)
	return true


func _unload_truck(product: String, qty: int) -> bool:
	var t: Dictionary = _s.truck
	if t.left > 0 or qty <= 0 or t.cargo.get(product, 0) < qty:
		return false
	_add(t.cargo, product, -qty)
	_add(_s.warehouse.items, product, qty)
	return true


func _send_truck() -> bool:
	var t: Dictionary = _s.truck
	if t.left > 0 or t.cargo.is_empty():
		return false
	t.left = _vehicle(t, "truck").trip_ticks
	_s.stats.trucks_sent += 1
	_emit("truck_sent", {})
	return true


## Adds (qty > 0) or removes (qty < 0) goods on the plane's shopping list.
func _order_plane(product: String, qty: int) -> bool:
	var t: Dictionary = _s.plane
	var d = _c.products.get(product)
	if not _s.level.get("plane", false) or t.left > 0 or d == null or d.buy_price <= 0 or qty == 0:
		return false
	if qty < 0:
		if t.cargo.get(product, 0) < -qty:
			return false
	elif _size_of(t.cargo) + d.size * qty > _vehicle(t, "plane").capacity:
		return false
	_add(t.cargo, product, qty)
	return true


func _send_plane() -> bool:
	var t: Dictionary = _s.plane
	var cost := _plane_cost()
	if t.left > 0 or t.cargo.is_empty() or _s.money < cost:
		return false
	_s.money -= cost
	t.left = _vehicle(t, "plane").trip_ticks
	_s.stats.planes_sent += 1
	_emit("plane_sent", {"cost": cost})
	return true


func _upgrade_vehicle(key: String) -> bool:
	var t: Dictionary = _s[key]
	if not _s.level.get(key, false) or t.left > 0 or not _pay_upgrade(key, t.level, _c.farm[key].levels):
		return false
	t.level += 1
	_emit(key + "_upgraded", {"level": t.level})
	return true


func _tap_predator(uid: int) -> bool:
	var p = _find(_s.predators, uid)
	if p == null:
		return false
	p.hits += 1
	p.decay = 0
	if p.hits < p.needed:
		_emit("predator_hit", {"uid": uid, "hits": p.hits, "needed": p.needed})
		return true
	if p.type == "bear":
		_cage_bear(p)
	else:
		_s.predators.erase(p)
		_s.stats.moles_chased += 1
		_emit("predator_chased", {"uid": uid, "x": p.x, "y": p.y})
	return true


func _cage_bear(p: Dictionary) -> void:
	_s.predators.erase(p)
	_s.stats.bears_caged += 1
	_spawn_ground(_cage_product(), p.x, p.y)
	_emit("predator_caged", {"uid": p.uid, "x": p.x, "y": p.y})


func _tap() -> bool:
	var cm: Dictionary = _c.farm.click_meter
	var m: Dictionary = _s.click_meter
	m.fill += cm.per_tap + cm.per_tap_per_hidden_item * m.found.size()
	while m.fill >= cm.max:
		m.fill -= cm.max
		_s.money += cm.reward
		_s.stats.money_earned += cm.reward
		_s.stats.click_rewards += 1
		_emit("click_reward", {"money": cm.reward})
	return true


func _find_hidden(id: String) -> bool:
	if _s.click_meter.found.has(id) or not _s.level.hidden_items.any(func(h): return h.id == id):
		return false
	_s.click_meter.found.append(id)
	_s.stats.hidden_found += 1
	_emit("hidden_found", {"id": id})
	return true


# ---------------------------------------------------------------- helpers

func _emit(type: String, data: Dictionary) -> void:
	data.type = type
	data.tick = _s.tick
	_events.append(data)


func _uid() -> int:
	var u: int = _s.next_uid
	_s.next_uid += 1
	return u


func _spawn_animal(type: String, x: int, y: int) -> Dictionary:
	var d: Dictionary = _c.animals[type]
	var a := {"uid": _uid(), "type": type, "x": x, "y": y, "tx": _rand_x(), "ty": _rand_y(),
		"full": d.food_ticks, "eaten": 0, "produce": 0, "hungry": false, "hungry_ticks": 0,
		"asleep": false, "scared": false}
	_s.animals.append(a)
	return a


func _spawn_ground(product: String, x: int, y: int) -> Dictionary:
	var g := {"uid": _uid(), "product": product, "x": clampi(x, 20, _field_w() - 20), "y": clampi(y, 20, _field_h() - 20),
		"life": _c.products[product].ground_ticks}
	_s.ground.append(g)
	_emit("product_spawned", {"uid": g.uid, "product": product, "x": g.x, "y": g.y})
	return g


func _new_building(type: String, level: int) -> Dictionary:
	return {"type": type, "level": clampi(level, 1, MAX_LEVEL), "left": 0, "queued": 0}


func _slot_options(slot: int) -> Array:
	var slots: Array = _s.level.slots
	if slot >= slots.size():
		return []
	return slots[slot].map(func(o): return o.type)


## Highest level the level allows for an upgradable thing (well, warehouse,
## truck, plane or a building type). Unlisted ones stay at their start level.
func _max_level(key: String, current: int) -> int:
	return maxi(current, mini(MAX_LEVEL, _s.level.get("max_level", {}).get(key, current)))


func _pay_upgrade(key: String, level: int, levels: Array) -> bool:
	if level >= _max_level(key, level) or level >= levels.size():
		return false
	var price: int = levels[level].price
	if _s.money < price:
		return false
	_s.money -= price
	return true


func _upgrade_info(into: Dictionary, key: String, level: int, levels: Array) -> void:
	into.can_upgrade = level < _max_level(key, level) and level < levels.size()
	into.upgrade_price = levels[level].price if into.can_upgrade else 0


func _building_sell_price(w: Dictionary) -> int:
	var total := 0
	for i in w.level:
		total += _c.workshops[w.type].levels[i].price
	return total / 2


## Moves e toward (tx, ty); returns true when it has arrived.
func _move(e: Dictionary, tx: int, ty: int, speed: int) -> bool:
	var dx: int = tx - e.x
	var dy: int = ty - e.y
	var dist := _dist(e.x, e.y, tx, ty)
	if dist <= speed:
		e.x = tx
		e.y = ty
		return true
	e.x += dx * speed / dist
	e.y += dy * speed / dist
	return false


static func _dist(x1: int, y1: int, x2: int, y2: int) -> int:
	var dx := x2 - x1
	var dy := y2 - y1
	return int(sqrt(float(dx * dx + dy * dy)))


func _nearest_grass(x: int, y: int) -> int:
	var best := -1
	var best_d := 1 << 40
	for i in _s.grass.size():
		if _s.grass[i] <= 0:
			continue
		var dx := _cell_cx(i) - x
		var dy := _cell_cy(i) - y
		var d := dx * dx + dy * dy
		if d < best_d:
			best_d = d
			best = i
	return best


func _cell_cx(i: int) -> int:
	return (i % _c.farm.field.cols) * _c.farm.field.cell + _c.farm.field.cell / 2


func _cell_cy(i: int) -> int:
	return (i / _c.farm.field.cols) * _c.farm.field.cell + _c.farm.field.cell / 2


func _field_w() -> int:
	return _c.farm.field.cols * _c.farm.field.cell


func _field_h() -> int:
	return _c.farm.field.rows * _c.farm.field.cell


func _rand_x() -> int:
	return _rng.randi_range(50, _field_w() - 50)


func _rand_y() -> int:
	return _rng.randi_range(50, _field_h() - 50)


func _workshop_x(slot: int) -> int:
	return (slot + 1) * _field_w() / (SLOTS + 1)


func _workshop_y() -> int:
	return 0


func _workshop_at(slot: int):
	if slot < 0 or slot >= SLOTS:
		return null
	return _s.workshops[slot]


func _workshop_duration(w: Dictionary) -> int:
	return _c.workshops[w.type].levels[w.level - 1].duration_ticks


func _batch_ticks(w: Dictionary) -> int:
	return maxi(1, _workshop_duration(w) * 100 / (100 + _boost_value("fast_workshops")))


func _well_def(level: int) -> Dictionary:
	return _c.farm.well.levels[level - 1]


func _vehicle(t: Dictionary, key: String) -> Dictionary:
	return _c.farm[key].levels[t.level - 1]


func _plane_cost() -> int:
	var n := 0
	for p in _s.plane.cargo:
		n += _c.products[p].buy_price * _s.plane.cargo[p]
	return n


func _cage_product() -> String:
	return _c.farm.predators.bear.cage_product


func _warehouse_capacity() -> int:
	return _c.farm.warehouse.levels[_s.warehouse.level - 1].capacity + _s.warehouse.bonus


func _warehouse_used() -> int:
	return _size_of(_s.warehouse.items)


func _fits(product: String, qty: int) -> bool:
	return _warehouse_used() + _c.products[product].size * qty <= _warehouse_capacity()


func _size_of(items: Dictionary) -> int:
	var n := 0
	for p in items:
		n += _c.products[p].size * items[p]
	return n


static func _add(d: Dictionary, key: String, n: int) -> void:
	var v: int = d.get(key, 0) + n
	if v == 0:
		d.erase(key)
	else:
		d[key] = v


static func _find(arr: Array, uid: int):
	for e in arr:
		if e.uid == uid:
			return e
	return null


static func _filled(n: int, v) -> Array:
	var a := []
	a.resize(n)
	a.fill(v)
	return a
