## Headless "good player" bot. Plays a level through the GameCore seam only
## (state(), apply(), advance()). Used by the validator and the trophy balancer.
class_name Bot
extends RefCounted

const STEP_TICKS := 5
const MAX_TICKS := 36000  # 1 hour of game time

var _core: GameCore
var _cat: Content
var _s: LevelSession


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
	var demand := _demand(st)
	_collect(st, demand)
	st = _s.state()
	_workshops(st, demand)
	st = _s.state()
	_animals(st, demand)
	st = _s.state()
	_city(st, demand)
	st = _s.state()
	_grass(st)
	_truck(_s.state(), demand)
	_s.apply(Cmd.tap())
	_s.apply(Cmd.tap())


## Remaining amount of each product the goals still need, expanded through recipes.
func _demand(st: Dictionary) -> Dictionary:
	var d := {}
	for g in st.goals:
		if g.type == "collect" and not g.done:
			_need(d, g.product, g.target - g.progress, st)
	return d


func _need(d: Dictionary, product: String, qty: int, st: Dictionary) -> void:
	if qty <= 0:
		return
	d[product] = d.get(product, 0) + qty
	var ws = _workshop_for(product)
	if ws == null or not st.available_workshops.has(ws.id):
		return
	for p in ws.inputs:
		var have: int = st.warehouse.items.get(p, 0)
		_need(d, p, ws.inputs[p] * qty - have, st)


func _workshop_for(product: String):
	for w in _cat.workshops.values():
		if w.output == product:
			return w
	return null


func _animal_for(product: String):
	for a in _cat.animals.values():
		if a.product == product:
			return a
	return null


func _collect(st: Dictionary, demand: Dictionary) -> void:
	var ground: Array = st.ground.duplicate()
	ground.sort_custom(func(a, b): return int(demand.has(a.product)) > int(demand.has(b.product)))
	for g in ground:
		if not _s.apply(Cmd.collect(g.uid)) and demand.has(g.product):
			_make_room(_s.state(), demand)
			_s.apply(Cmd.collect(g.uid))


func _make_room(st: Dictionary, demand: Dictionary) -> void:
	if st.warehouse.can_upgrade and _s.apply(Cmd.upgrade_warehouse()):
		return
	for p in st.warehouse.items:
		if not demand.has(p):
			_s.apply(Cmd.load_truck(p, st.warehouse.items[p]))
	_s.apply(Cmd.send_truck())


func _workshops(st: Dictionary, demand: Dictionary) -> void:
	for wid in st.available_workshops:
		var w: Dictionary = _cat.workshops[wid]
		if not demand.has(w.output):
			continue
		var built: bool = st.workshops.any(func(x): return x != null and x.type == wid)
		if not built:
			var slot: int = st.workshops.find(null)
			if slot >= 0:
				_s.apply(Cmd.build_workshop(slot, wid))
				st = _s.state()
	for i in st.workshops.size():
		var w = st.workshops[i]
		if w != null and demand.has(w.output):
			_s.apply(Cmd.start_workshop(i))


func _animals(st: Dictionary, demand: Dictionary) -> void:
	var want := {}
	for g in st.goals:
		if g.type == "animal" and not g.done:
			want[g.animal] = maxi(want.get(g.animal, 0), g.target)
	for p in demand:
		var a = _animal_for(p)
		if a == null:
			continue
		if a.buyable and st.available_animals.has(a.id):
			want[a.id] = maxi(want.get(a.id, 0), clampi(demand[p] / 3 + 2, 2, 6))
		elif not a.buyable and st.allow_hybrids:
			for h in _cat.hybrids:
				if h.result == a.id:
					for parent in h.parents:
						want[parent] = maxi(want.get(parent, 0), 3)
	var reserve := _reserve(st)
	for id in want:
		var have: int = st.animals.filter(func(x): return x.type == id).size()
		var price: int = _cat.animals[id].price
		while have < want[id] and _s.state().money - price >= reserve:
			if not _s.apply(Cmd.buy_animal(id)):
				break
			have += 1


## Money kept back so a money goal is not undermined by spending.
func _reserve(st: Dictionary) -> int:
	var r: int = _cat.farm.well.refill_price
	for g in st.goals:
		if g.type == "money" and not g.done:
			var others_done: bool = st.goals.all(func(x): return x.type == "money" or x.done)
			if others_done:
				r = maxi(r, g.target)
	return r


func _city(st: Dictionary, demand: Dictionary) -> void:
	if not st.orders.is_empty():
		return
	for p in demand:
		var prod: Dictionary = _cat.products[p]
		if prod.kind != "raw" or prod.buy_price <= 0:
			continue
		var a = _animal_for(p)
		if a != null and a.buyable and st.available_animals.has(a.id):
			continue
		var on_ground: int = st.ground.filter(func(g): return g.product == p).size()
		var qty: int = mini(demand[p] - on_ground, st.warehouse.capacity - st.warehouse.used)
		if qty > 0:
			qty = mini(qty, (st.money - _reserve(st)) / prod.buy_price)
			if qty > 0:
				_s.apply(Cmd.buy_from_city(p, qty))


func _grass(st: Dictionary) -> void:
	var cols: int = st.field.cols
	var cell: int = st.field.cell
	if st.well.water == 0:
		_s.apply(Cmd.refill_well())
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
	if st.truck.away:
		return
	var need_money := false
	for g in st.goals:
		if g.type == "money" and not g.done:
			need_money = true
	var nearly_full: bool = st.warehouse.used * 10 >= st.warehouse.capacity * 7
	if not need_money and not nearly_full:
		return
	for p in st.warehouse.items:
		if demand.has(p):
			continue
		var free: int = st.truck.capacity - st.truck.used
		var qty: int = mini(st.warehouse.items[p], free / _cat.products[p].size)
		if qty > 0 and _s.apply(Cmd.load_truck(p, qty)):
			st = _s.state()
	st = _s.state()
	if st.truck.used > 0 and (st.truck.used * 2 >= st.truck.capacity or nearly_full or _all_but_money_done(st)):
		_s.apply(Cmd.send_truck())


func _all_but_money_done(st: Dictionary) -> bool:
	return st.goals.all(func(g): return g.type == "money" or g.done)
