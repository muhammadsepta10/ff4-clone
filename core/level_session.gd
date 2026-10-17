## One level being played. Deterministic: fixed 10 ticks per second, all randomness
## from the session's seeded RNG, integer-only state (ADR 0005).
## Create through GameCore.start_session() / GameCore.restore_session().
class_name LevelSession
extends RefCounted

const TICKS_PER_SECOND := 10
const SNAPSHOT_VERSION := 1

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
	var f: Dictionary = _c.farm
	_s = {
		"level": lvl,
		"tick": 0,
		"money": lvl.start_money,
		"next_uid": 1,
		"grass": _filled(f.field.cols * f.field.rows, 0),
		"well": {"water": f.well.capacity, "capacity": f.well.capacity, "refill_left": 0},
		"animals": [],
		"ground": [],
		"warehouse": {"level": 0, "bonus": 0, "items": {}},
		"workshops": _filled(lvl.workshop_slots, null),
		"truck": {"level": 0, "cargo": {}, "left": 0},
		"orders": [],
		"predators": [],
		"pred_warned": _filled(lvl.predators.size(), false),
		"pred_spawned": _filled(lvl.predators.size(), false),
		"click_meter": {"fill": 0, "found": []},
		"boosts": [],
		"goals": [],
		"breed": {},
		"collected": {},
		"stats": {"collected": {}, "products_crafted": 0, "bears_caged": 0, "moles_chased": 0,
			"animals_bought": 0, "hybrids_born": 0, "trucks_sent": 0, "money_earned": 0,
			"hidden_found": 0, "click_rewards": 0, "grass_planted": 0},
		"won": false,
		"win_tick": -1,
		"trophy": "",
	}
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
		"collect": ok = _collect(cmd.uid)
		"build_workshop": ok = _build_workshop(cmd.slot, cmd.workshop)
		"upgrade_workshop": ok = _upgrade_workshop(cmd.slot)
		"sell_workshop": ok = _sell_workshop(cmd.slot)
		"start_workshop": ok = _start_workshop(cmd.slot)
		"upgrade_warehouse": ok = _upgrade_warehouse()
		"load_truck": ok = _load_truck(cmd.product, cmd.qty)
		"unload_truck": ok = _unload_truck(cmd.product, cmd.qty)
		"send_truck": ok = _send_truck()
		"upgrade_truck": ok = _upgrade_truck()
		"buy_from_city": ok = _buy_from_city(cmd.product, cmd.qty)
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
	st.erase("breed")
	st.erase("pred_warned")
	st.erase("pred_spawned")
	st.level_id = lvl.id
	st.field = _c.farm.field.duplicate()
	st.trophy = lvl.trophy.duplicate()
	st.trophy_won = _s.trophy
	st.warehouse.capacity = _warehouse_capacity()
	st.warehouse.used = _warehouse_used()
	st.truck.capacity = _truck_capacity()
	st.truck.used = _cargo_used()
	st.truck.away = _s.truck.left > 0
	st.truck.trip_ticks = _c.farm.truck.levels[_s.truck.level].trip_ticks
	st.truck.can_upgrade = _s.truck.level + 1 < _c.farm.truck.levels.size()
	st.warehouse.can_upgrade = _s.warehouse.level + 1 < _c.farm.warehouse.levels.size()
	st.available_animals = lvl.available_animals.duplicate()
	st.available_workshops = lvl.available_workshops.duplicate()
	st.allow_hybrids = lvl.allow_hybrids
	for i in st.workshops.size():
		var w = st.workshops[i]
		if w != null:
			var d: Dictionary = _c.workshops[w.type]
			w.duration = _workshop_duration(_s.workshops[i])
			w.inputs = d.inputs.duplicate()
			w.output = d.output
			w.can_upgrade = w.level < d.upgrades.size()
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
	_tick_breeding()
	_tick_ground()
	_tick_workshops()
	_tick_truck()
	_tick_orders()
	_tick_predators()
	_evaluate_goals()


func _tick_well() -> void:
	var w: Dictionary = _s.well
	if w.refill_left > 0:
		w.refill_left -= 1
		if w.refill_left == 0:
			w.water = w.capacity
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
	var rate := 10 * (100 + _boost_value("fast_production")) / 100
	for a in _s.animals.duplicate():
		var d: Dictionary = _c.animals[a.type]
		a.food = maxi(0, a.food - 1)
		if a.food == 0:
			a.starve += 1
			if a.starve >= d.starve_ticks:
				_s.animals.erase(a)
				_emit("animal_died", {"uid": a.uid, "animal": a.type, "x": a.x, "y": a.y})
				continue
		if a.breed_cd > 0:
			a.breed_cd -= 1
		var hungry: bool = a.food < d.hungry_below
		if hungry and not a.hungry:
			_emit("animal_hungry", {"uid": a.uid, "x": a.x, "y": a.y})
		a.hungry = hungry
		var cell := _nearest_grass(a.x, a.y) if hungry else -1
		if cell >= 0:
			var cx := _cell_cx(cell)
			var cy := _cell_cy(cell)
			if _move(a, cx, cy, d.speed):
				_s.grass[cell] -= 1
				a.food = mini(d.food_max, a.food + d.bite_food)
				a.starve = 0
				a.hungry = a.food < d.hungry_below
				_emit("animal_ate", {"uid": a.uid})
		else:
			if _move(a, a.tx, a.ty, d.speed):
				a.tx = _rand_x()
				a.ty = _rand_y()
		if a.food > 0:
			a.produce += rate
			if a.produce >= d.produce_ticks * 10:
				a.produce -= d.produce_ticks * 10
				_spawn_ground(d.product, a.x, a.y)


func _tick_breeding() -> void:
	if not _s.level.allow_hybrids:
		return
	var next := {}
	for h in _c.hybrids:
		for a in _s.animals:
			if a.type != h.parents[0] or a.breed_cd > 0:
				continue
			for b in _s.animals:
				if b.type != h.parents[1] or b.breed_cd > 0 or a.breed_cd > 0:
					continue
				if _dist(a.x, a.y, b.x, b.y) > h.range:
					continue
				var key := "%d:%d" % [a.uid, b.uid]
				var p: int = _s.breed.get(key, 0) + 1
				if p >= h.breed_ticks:
					a.breed_cd = h.cooldown_ticks
					b.breed_cd = h.cooldown_ticks
					var child := _spawn_animal(h.result, (a.x + b.x) / 2, (a.y + b.y) / 2)
					child.breed_cd = h.cooldown_ticks
					_s.stats.hybrids_born += 1
					_emit("hybrid_born", {"uid": child.uid, "animal": h.result, "x": child.x, "y": child.y})
				else:
					next[key] = p
	_s.breed = next


func _tick_ground() -> void:
	for g in _s.ground.duplicate():
		g.life -= 1
		if g.life <= 0:
			_s.ground.erase(g)
			_emit("product_expired", {"uid": g.uid, "product": g.product, "x": g.x, "y": g.y})


func _tick_workshops() -> void:
	for i in _s.workshops.size():
		var w = _s.workshops[i]
		if w == null or w.left == 0:
			continue
		w.left -= 1
		if w.left == 0:
			var out: String = _c.workshops[w.type].output
			_s.stats.products_crafted += 1
			_spawn_ground(out, _workshop_x(i) + _rng.randi_range(-30, 30), _workshop_y() + 70)
			_emit("workshop_done", {"slot": i, "product": out})


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


func _tick_orders() -> void:
	for o in _s.orders.duplicate():
		o.left -= 1
		if o.left <= 0:
			_s.orders.erase(o)
			var fw := _field_w()
			var fh := _field_h()
			for i in o.qty:
				_spawn_ground(o.product, fw - 60 - _rng.randi_range(0, 120), fh / 2 + _rng.randi_range(-200, 200))
			_emit("order_arrived", {"product": o.product, "qty": o.qty})


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
			var pr := {"uid": _uid(), "type": p.type, "x": _rand_x(), "y": _rand_y(), "tx": _rand_x(), "ty": _rand_y(),
				"hits": 0, "decay": 0, "life": _c.farm.predators[p.type].life_ticks, "attack": 0, "eat": 0}
			_s.predators.append(pr)
			_emit("predator_arrived", {"uid": pr.uid, "predator": p.type, "x": pr.x, "y": pr.y})


func _tick_predators() -> void:
	for p in _s.predators.duplicate():
		var d: Dictionary = _c.farm.predators[p.type]
		p.life -= 1
		if p.life <= 0:
			_s.predators.erase(p)
			_emit("predator_left", {"uid": p.uid, "predator": p.type})
			continue
		if p.hits > 0:
			p.decay += 1
			if p.decay >= d.hit_decay_ticks:
				p.hits -= 1
				p.decay = 0
		if p.type == "bear":
			_tick_bear(p, d)
		else:
			_tick_mole(p, d)


func _tick_bear(p: Dictionary, d: Dictionary) -> void:
	var prey = null
	var best := 1 << 40
	for a in _s.animals:
		var dd := _dist(p.x, p.y, a.x, a.y)
		if dd < best:
			best = dd
			prey = a
	if prey == null:
		if _move(p, p.tx, p.ty, d.speed):
			p.tx = _rand_x()
			p.ty = _rand_y()
		return
	if best <= d.attack_range:
		p.attack += 1
		if p.attack >= d.attack_ticks:
			p.attack = 0
			_s.animals.erase(prey)
			_emit("animal_eaten", {"uid": prey.uid, "animal": prey.type, "x": prey.x, "y": prey.y})
	else:
		_move(p, prey.x, prey.y, d.speed)


func _tick_mole(p: Dictionary, d: Dictionary) -> void:
	if _move(p, p.tx, p.ty, d.speed):
		p.tx = _rand_x()
		p.ty = _rand_y()
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
		if g.product != _c.farm.predators.bear.cage_product and _dist(p.x, p.y, g.x, g.y) <= d.eat_range:
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
		var t: Dictionary = _s.level.trophy
		_s.trophy = "gold" if _s.tick <= t.gold_ticks else ("silver" if _s.tick <= t.silver_ticks else "bronze")
		_emit("level_won", {"ticks": _s.tick, "trophy": _s.trophy})


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
	if w.refill_left > 0 or w.water >= w.capacity or _s.money < price:
		return false
	_s.money -= price
	w.refill_left = _c.farm.well.refill_ticks
	_emit("well_refilling", {})
	return true


func _collect(uid: int) -> bool:
	var g = _find(_s.ground, uid)
	if g == null:
		return false
	var size: int = _c.products[g.product].size
	if _warehouse_used() + size > _warehouse_capacity():
		_emit("warehouse_full", {"product": g.product})
		return false
	_s.ground.erase(g)
	_add(_s.warehouse.items, g.product, 1)
	_add(_s.collected, g.product, 1)
	_add(_s.stats.collected, g.product, 1)
	_emit("product_collected", {"uid": uid, "product": g.product, "x": g.x, "y": g.y})
	return true


func _build_workshop(slot: int, type: String) -> bool:
	if slot < 0 or slot >= _s.workshops.size() or _s.workshops[slot] != null:
		return false
	if not _s.level.available_workshops.has(type):
		return false
	var d: Dictionary = _c.workshops[type]
	if _s.money < d.build_price:
		return false
	_s.money -= d.build_price
	_s.workshops[slot] = {"type": type, "level": 0, "left": 0}
	_emit("workshop_built", {"slot": slot, "workshop": type})
	return true


func _upgrade_workshop(slot: int) -> bool:
	var w = _workshop_at(slot)
	if w == null:
		return false
	var ups: Array = _c.workshops[w.type].upgrades
	if w.level >= ups.size() or _s.money < ups[w.level].price:
		return false
	_s.money -= ups[w.level].price
	w.level += 1
	_emit("workshop_upgraded", {"slot": slot, "level": w.level})
	return true


func _sell_workshop(slot: int) -> bool:
	var w = _workshop_at(slot)
	if w == null or w.left > 0:
		return false
	_s.money += _c.workshops[w.type].sell_price
	_s.workshops[slot] = null
	_emit("workshop_sold", {"slot": slot})
	return true


func _start_workshop(slot: int) -> bool:
	var w = _workshop_at(slot)
	if w == null or w.left > 0:
		return false
	var d: Dictionary = _c.workshops[w.type]
	for p in d.inputs:
		if _s.warehouse.items.get(p, 0) < d.inputs[p]:
			return false
	for p in d.inputs:
		_add(_s.warehouse.items, p, -d.inputs[p])
	w.left = maxi(1, _workshop_duration(w) * 100 / (100 + _boost_value("fast_workshops")))
	_emit("workshop_started", {"slot": slot})
	return true


func _upgrade_warehouse() -> bool:
	var lv: Array = _c.farm.warehouse.levels
	var n: int = _s.warehouse.level + 1
	if n >= lv.size() or _s.money < lv[n].price:
		return false
	_s.money -= lv[n].price
	_s.warehouse.level = n
	_emit("warehouse_upgraded", {"level": n})
	return true


func _load_truck(product: String, qty: int) -> bool:
	if _s.truck.left > 0 or qty <= 0 or _s.warehouse.items.get(product, 0) < qty:
		return false
	if _cargo_used() + _c.products[product].size * qty > _truck_capacity():
		return false
	_add(_s.warehouse.items, product, -qty)
	_add(_s.truck.cargo, product, qty)
	return true


func _unload_truck(product: String, qty: int) -> bool:
	if _s.truck.left > 0 or qty <= 0 or _s.truck.cargo.get(product, 0) < qty:
		return false
	if _warehouse_used() + _c.products[product].size * qty > _warehouse_capacity():
		return false
	_add(_s.truck.cargo, product, -qty)
	_add(_s.warehouse.items, product, qty)
	return true


func _send_truck() -> bool:
	if _s.truck.left > 0 or _s.truck.cargo.is_empty():
		return false
	_s.truck.left = _c.farm.truck.levels[_s.truck.level].trip_ticks
	_s.stats.trucks_sent += 1
	_emit("truck_sent", {})
	return true


func _upgrade_truck() -> bool:
	var lv: Array = _c.farm.truck.levels
	var n: int = _s.truck.level + 1
	if _s.truck.left > 0 or n >= lv.size() or _s.money < lv[n].price:
		return false
	_s.money -= lv[n].price
	_s.truck.level = n
	_emit("truck_upgraded", {"level": n})
	return true


func _buy_from_city(product: String, qty: int) -> bool:
	var d = _c.products.get(product)
	if d == null or d.buy_price <= 0 or qty <= 0 or _s.money < d.buy_price * qty:
		return false
	_s.money -= d.buy_price * qty
	_s.orders.append({"product": product, "qty": qty, "left": _c.farm.city.delivery_ticks})
	_emit("order_placed", {"product": product, "qty": qty})
	return true


func _tap_predator(uid: int) -> bool:
	var p = _find(_s.predators, uid)
	if p == null:
		return false
	var d: Dictionary = _c.farm.predators[p.type]
	p.hits += 1
	p.decay = 0
	if p.hits < d.hits:
		_emit("predator_hit", {"uid": uid, "hits": p.hits, "needed": d.hits})
		return true
	_s.predators.erase(p)
	if p.type == "bear":
		_s.stats.bears_caged += 1
		_spawn_ground(d.cage_product, p.x, p.y)
		_emit("predator_caged", {"uid": uid, "x": p.x, "y": p.y})
	else:
		_s.stats.moles_chased += 1
		_emit("predator_chased", {"uid": uid, "x": p.x, "y": p.y})
	return true


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
		"food": d.food_max, "starve": 0, "produce": 0, "hungry": false, "breed_cd": 0}
	_s.animals.append(a)
	return a


func _spawn_ground(product: String, x: int, y: int) -> void:
	var g := {"uid": _uid(), "product": product, "x": clampi(x, 20, _field_w() - 20), "y": clampi(y, 20, _field_h() - 20),
		"life": _c.products[product].ground_ticks}
	_s.ground.append(g)
	_emit("product_spawned", {"uid": g.uid, "product": product, "x": g.x, "y": g.y})


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
	return (slot + 1) * _field_w() / (_s.workshops.size() + 1)


func _workshop_y() -> int:
	return 0


func _workshop_at(slot: int):
	if slot < 0 or slot >= _s.workshops.size():
		return null
	return _s.workshops[slot]


func _workshop_duration(w: Dictionary) -> int:
	var d: Dictionary = _c.workshops[w.type]
	var pct: int = 100 if w.level == 0 else d.upgrades[w.level - 1].duration_pct
	return d.duration_ticks * pct / 100


func _warehouse_capacity() -> int:
	return _c.farm.warehouse.levels[_s.warehouse.level].capacity + _s.warehouse.bonus


func _warehouse_used() -> int:
	return _size_of(_s.warehouse.items)


func _truck_capacity() -> int:
	return _c.farm.truck.levels[_s.truck.level].capacity


func _cargo_used() -> int:
	return _size_of(_s.truck.cargo)


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
