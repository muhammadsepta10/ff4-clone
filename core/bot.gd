## Headless "good player" bot. Plays a level through the GameCore seam only
## (state(), apply(), advance()). Used by the validator and tests to prove
## every level can be finished.
class_name Bot
extends RefCounted

const STEP_TICKS := 5
const MAX_TICKS := 72000  # 2 hours of game time

var _core: GameCore
var _cat: Content
var _s: LevelSession
var _sell := {}  # products made only to sell for a money goal
var _goal := {}  # goal products: they count when collected, so they can be sold
var _keep := {}  # product -> units the open goals still use; the truck sells only the rest


static func play(core: GameCore, level: Dictionary, seed: int, boosts: Array = []) -> Dictionary:
	var b := Bot.new()
	b._core = core
	b._cat = core.catalog()
	b._s = core.start_session(level, seed, boosts)
	return b._run()


## Makes one round of decisions on a live session without advancing it
## (used by the benchmark scene, which advances time itself).
static func act(core: GameCore, session: LevelSession) -> void:
	var b := Bot.new()
	b._core = core
	b._cat = core.catalog()
	b._s = session
	b._decide(session.state())


func _run() -> Dictionary:
	var first := true
	while not _s.is_won() and _s.tick() < MAX_TICKS:
		var st := _s.state()
		if first:
			for h in st.hidden_items:
				_s.apply(Cmd.find_hidden_item(h.id))
			first = false
		_decide(st)
		_s.advance(STEP_TICKS)
		_s.poll_events()
	return _s.result()


func _decide(st: Dictionary) -> void:
	for p in st.predators:
		for i in 3:
			_s.apply(Cmd.tap_predator(p.uid))
	var demand := _demand(_s.state())
	_collect(_s.state(), demand)
	_workshops(_s.state(), demand)
	_animals(_s.state(), demand)
	_plane(_s.state(), demand)
	_grass(_s.state())
	_truck(_s.state(), demand)
	_upgrades(_s.state(), demand)
	_s.apply(Cmd.tap())
	_s.apply(Cmd.tap())


## Remaining amount of each product the goals still need, expanded through recipes.
func _demand(st: Dictionary) -> Dictionary:
	var d := {}
	_keep = {}
	_goal = {}
	for g in st.goals:
		if g.type == "collect" and not g.done:
			_need(d, g.product, g.target - g.progress, st)
			_goal[g.product] = true
			var ws = _workshop_for(g.product, st)
			if ws != null:
				for p in ws.inputs:
					_mark_keep(p, ws.inputs[p] * (g.target - g.progress), st)
	_sell = {}
	if _money_open(st):
		# Make the best-paying product each spot can hold, to sell.
		for opts in st.slots:
			var best := ""
			for opt in opts:
				var out: String = _cat.workshops[opt].output
				if _makeable(out, st, 0) and (best == "" or _cat.products[out].sell_price > _cat.products[best].sell_price):
					best = out
			if best != "" and not d.has(best):
				_sell[best] = true
				_need(d, best, 4, st)
	return d


func _money_open(st: Dictionary) -> bool:
	return st.goals.any(func(g): return g.type == "money" and not g.done)


## True when the farm can get this product: from an animal, the plane or a recipe.
func _makeable(product: String, st: Dictionary, depth: int) -> bool:
	if depth > 8:
		return false
	var a = _producer_of(product)
	if a != null and st.available_animals.has(a.id):
		return true
	if st.plane.available and _cat.products[product].buy_price > 0:
		return true
	var ws = _workshop_for(product, st)
	if ws == null:
		return false
	for p in ws.inputs:
		if not _makeable(p, st, depth + 1):
			return false
	return true


func _mark_keep(product: String, qty: int, st: Dictionary) -> void:
	_keep[product] = _keep.get(product, 0) + qty
	var ws = _workshop_for(product, st)
	if ws != null:
		for p in ws.inputs:
			_mark_keep(p, ws.inputs[p] * qty, st)


## Units of a product the truck may sell. Kept stock is capped so one
## product cannot fill the warehouse and stall every building.
func _spare(st: Dictionary, p: String) -> int:
	return maxi(0, st.warehouse.items[p] - mini(_keep.get(p, 0), _cap(st, p)))


func _cap(st: Dictionary, p: String) -> int:
	var share: int = 3 if st.warehouse.used * 10 < st.warehouse.capacity * 9 else 6
	return clampi(st.warehouse.capacity / (share * _cat.products[p].size), 4, 20)


func _by_surplus(st: Dictionary, demand: Dictionary) -> Array:
	var ps: Array = st.warehouse.items.keys()
	ps.sort_custom(func(a, b): return _sellable(st, a, demand) * _cat.products[a].size > _sellable(st, b, demand) * _cat.products[b].size)
	return ps


## Units the truck may take: spare stock, plus overflow of a needed product
## when the warehouse is almost full.
func _sellable(st: Dictionary, p: String, demand: Dictionary) -> int:
	if not demand.has(p) or _sell.has(p) or _goal.has(p):
		return _spare(st, p)
	if st.warehouse.used * 10 >= st.warehouse.capacity * 9:
		return maxi(0, st.warehouse.items[p] - _cap(st, p))
	return 0


func _need(d: Dictionary, product: String, qty: int, st: Dictionary) -> void:
	if qty <= 0:
		return
	d[product] = d.get(product, 0) + qty
	var ws = _workshop_for(product, st)
	if ws == null:
		return
	for p in ws.inputs:
		var have: int = st.warehouse.items.get(p, 0)
		_need(d, p, ws.inputs[p] * qty - have, st)


## The recipe for a product, if one of the level's slots can hold its building.
func _workshop_for(product: String, st: Dictionary):
	for w in _cat.workshops.values():
		if w.output == product and st.slots.any(func(o): return o.has(w.id)):
			return w
	return null


func _producer_of(product: String):
	for a in _cat.animals.values():
		if a.role == "producer" and a.product == product:
			return a
	return null


func _collect(st: Dictionary, demand: Dictionary) -> void:
	var ground: Array = st.ground.duplicate()
	ground.sort_custom(func(a, b): return int(demand.has(a.product)) > int(demand.has(b.product)))
	for g in ground:
		var st2 := _s.state()
		var useful: bool = demand.has(g.product) or g.product == "caged_bear" or _sell.has(g.product)
		if not useful and st2.warehouse.used * 10 >= st2.warehouse.capacity * 6:
			continue  # leave spare goods on the ground so the warehouse keeps room
		if useful and not _goal.has(g.product) and not _sell.has(g.product) and g.product != "caged_bear" \
				and st2.warehouse.items.get(g.product, 0) >= _cap(st2, g.product) and st2.warehouse.used * 10 >= st2.warehouse.capacity * 6:
			continue
		if not _s.apply(Cmd.collect(g.uid)) and (demand.has(g.product) or g.product == "caged_bear"):
			_make_room(_s.state(), demand)
			_s.apply(Cmd.collect(g.uid))


func _make_room(st: Dictionary, demand: Dictionary) -> void:
	if st.warehouse.can_upgrade and _s.apply(Cmd.upgrade_warehouse()):
		return
	if not st.truck.available or st.truck.away:
		return
	for p in _by_surplus(st, demand):
		var free: int = _s.state().truck.capacity - _s.state().truck.used
		var qty: int = mini(_sellable(st, p, demand), free / _cat.products[p].size)
		if qty > 0:
			_s.apply(Cmd.load_truck(p, qty))
	_s.apply(Cmd.send_truck())


func _workshops(st: Dictionary, demand: Dictionary) -> void:
	for i in st.slots.size():
		var w = st.workshops[i]
		if w != null and w.left == 0 and w.queued == 0:
			# Swap the building for another option on the same spot when the goals
			# need that one and it has work ready while this one does not.
			for opt in st.slots[i]:
				if opt != w.type and demand.has(_cat.workshops[opt].output) and not _built(st, opt) \
						and _should_swap(st, w, opt, demand):
					if _s.apply(Cmd.sell_workshop(i)):
						st = _s.state()
						w = null
					break
		if w == null:
			var opt := _pick_build(st, i, demand)
			if opt != "" and _s.apply(Cmd.build_workshop(i, opt)):
				st = _s.state()
	for i in st.workshops.size():
		var w = st.workshops[i]
		if w != null and demand.has(w.output):
			while _s.apply(Cmd.start_workshop(i)):
				pass


## The building to put on an empty spot: one the goals need, preferring one
## that has work ready now, then the cheapest.
func _pick_build(st: Dictionary, i: int, demand: Dictionary) -> String:
	var opts: Array = st.slots[i].filter(func(o): return demand.has(_cat.workshops[o].output) and not _built(st, o))
	opts.sort_custom(func(a, b):
		var ra := int(_batches(st, _cat.workshops[a]) > 0)
		var rb := int(_batches(st, _cat.workshops[b]) > 0)
		if ra != rb:
			return ra > rb
		return _cat.workshops[a].levels[0].price < _cat.workshops[b].levels[0].price)
	return "" if opts.is_empty() else opts[0]


func _should_swap(st: Dictionary, w: Dictionary, opt: String, demand: Dictionary) -> bool:
	if not demand.has(w.output):
		return true
	var o: Dictionary = _cat.workshops[opt]
	# Only sell when the sale pays for the new building.
	if st.money + w.sell_price < o.levels[0].price + _reserve(st):
		return false
	var want: int = mini(demand[o.output], 3)
	if _batches(st, o) < want:
		return false
	# This building has nothing to work on, or the other one uses its output
	# and there is already enough of it in stock.
	return _batches(st, _cat.workshops[w.type]) == 0 \
		or o.inputs.has(w.output) and st.warehouse.items.get(w.output, 0) >= demand[o.output]


## How many batches the warehouse holds inputs for.
func _batches(st: Dictionary, ws: Dictionary) -> int:
	var n := 1 << 30
	for p in ws.inputs:
		n = mini(n, st.warehouse.items.get(p, 0) / ws.inputs[p])
	return n


func _built(st: Dictionary, type: String) -> bool:
	return st.workshops.any(func(x): return x != null and x.type == type)


func _animals(st: Dictionary, demand: Dictionary) -> void:
	var want := {}
	for g in st.goals:
		if g.type == "animal" and not g.done:
			want[g.animal] = maxi(want.get(g.animal, 0), g.target)
	for p in demand:
		var a = _producer_of(p)
		if a != null and st.available_animals.has(a.id):
			want[a.id] = maxi(want.get(a.id, 0), clampi(demand[p] / 4 + 2, 2, 6))
	if st.available_animals.has("dog") and not st.predators.filter(func(p): return p.type == "bear").is_empty():
		want["dog"] = maxi(want.get("dog", 0), 1)
	var reserve := _reserve(st)
	var ids := want.keys()
	ids.sort_custom(func(a, b): return _cat.animals[a].price < _cat.animals[b].price)
	for id in ids:
		var have: int = st.animals.filter(func(x): return x.type == id).size()
		var price: int = _cat.animals[id].price
		while have < want[id] and _s.state().money - price >= reserve:
			if not _s.apply(Cmd.buy_animal(id)):
				break
			have += 1


## Money kept back for refilling the well. A money goal stays done once
## reached, so spending never undoes it.
func _reserve(_st: Dictionary) -> int:
	return _cat.farm.well.refill_price


func _plane(st: Dictionary, demand: Dictionary) -> void:
	if not st.plane.available or st.plane.away:
		return
	for p in demand:
		var prod: Dictionary = _cat.products[p]
		if prod.buy_price <= 0:
			continue
		var have: int = st.warehouse.items.get(p, 0) + st.ground.filter(func(g): return g.product == p).size()
		var qty: int = mini(demand[p], _cap(st, p)) - have - st.plane.cargo.get(p, 0)
		# Leave a tenth of the warehouse free for what the farm makes.
		var room: int = st.warehouse.capacity * 9 / 10 - st.warehouse.used - _cargo_size(_s.state().plane.cargo)
		qty = mini(qty, room / prod.size)
		while qty > 0 and _s.apply(Cmd.order_plane(p, 1)):
			qty -= 1
	st = _s.state()
	if not st.plane.cargo.is_empty():
		if st.money - st.plane.cost >= _reserve(st):
			_s.apply(Cmd.send_plane())


func _cargo_size(cargo: Dictionary) -> int:
	var n := 0
	for p in cargo:
		n += cargo[p] * _cat.products[p].size
	return n


func _grass(st: Dictionary) -> void:
	var cell: int = st.field.cell
	if st.well.water == 0:
		if not _s.apply(Cmd.refill_well()) and st.well.can_upgrade:
			_s.apply(Cmd.upgrade_well())
		return
	for a in st.animals:
		if not a.hungry:
			continue
		var cx: int = a.x / cell
		var cy: int = a.y / cell
		if _grass_near(st, cx, cy):
			continue
		if _s.apply(Cmd.plant_grass(cx, cy)):
			st = _s.state()
		else:
			_s.apply(Cmd.refill_well())
			return


func _grass_near(st: Dictionary, cx: int, cy: int) -> bool:
	var cols: int = st.field.cols
	var rows: int = st.field.rows
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var x := cx + dx
			var y := cy + dy
			if x >= 0 and y >= 0 and x < cols and y < rows and st.grass[y * cols + x] > 0:
				return true
	return false


func _truck(st: Dictionary, demand: Dictionary) -> void:
	if not st.truck.available or st.truck.away:
		return
	var need_money := _needs_money(st, demand)
	var nearly_full: bool = st.warehouse.used * 10 >= st.warehouse.capacity * 7
	if not need_money and not nearly_full:
		return
	for p in _by_surplus(st, demand):
		var free: int = st.truck.capacity - st.truck.used
		var qty: int = mini(_sellable(st, p, demand), free / _cat.products[p].size)
		if qty > 0 and _s.apply(Cmd.load_truck(p, qty)):
			st = _s.state()
	st = _s.state()
	if st.truck.used > 0 and (st.truck.used * 2 >= st.truck.capacity or nearly_full or _all_but_money_done(st) or need_money):
		_s.apply(Cmd.send_truck())


## True when a money goal is open, or the goals need an animal, building or
## plane order the farm cannot pay for yet.
func _needs_money(st: Dictionary, demand: Dictionary) -> bool:
	for g in st.goals:
		if g.type == "money" and not g.done:
			return true
	if st.money < 400:
		return true
	for p in demand:
		var a = _producer_of(p)
		if a != null and st.available_animals.has(a.id) and not st.animals.any(func(x): return x.type == a.id):
			return true
		var w = _workshop_for(p, st)
		if w != null and not _built(st, w.id):
			return true
	return false


func _upgrades(st: Dictionary, demand: Dictionary) -> void:
	var spare: int = st.money - _reserve(st) - 500
	if spare <= 0:
		return
	if st.well.can_upgrade and st.well.upgrade_price < spare / 2:
		_s.apply(Cmd.upgrade_well())
	for i in st.workshops.size():
		var w = st.workshops[i]
		if w != null and demand.has(w.output) and w.can_upgrade and w.upgrade_price < spare / 3:
			_s.apply(Cmd.upgrade_workshop(i))


func _all_but_money_done(st: Dictionary) -> bool:
	return st.goals.all(func(g): return g.type == "money" or g.done)
