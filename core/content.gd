## Loads content JSON, validates against schemas and cross-references,
## and normalises integral numbers to int (simulation is integer-only).
class_name Content
extends RefCounted

const FILES := ["products", "animals", "workshops", "farm", "items", "outfits", "tutorials", "worlds", "achievements"]

var errors: Array[String] = []
var products := {}      # id -> def
var animals := {}       # id -> def
var workshops := {}     # id -> def
var farm := {}
var items: Array = []
var trophy_rewards := {}
var boosts := {}        # id -> def
var outfits: Array = []
var tutorials := {}
var worlds: Array = []
var achievements: Array = []
var levels := {}        # id -> def
var level_order: Array = []   # campaign order of level ids
var world_levels := {}  # world id -> [level ids]


static func load_dir(dir: String) -> Content:
	var c := Content.new()
	var schema_dir := "res://content/schema"
	var raw := {}
	for f in FILES:
		raw[f] = c._load_validated("%s/%s.json" % [dir, f], "%s/%s.schema.json" % [schema_dir, f])
	if not c.errors.is_empty():
		return c
	c._index(raw)
	for w in c.worlds:
		c.world_levels[w.id] = []
		if w.levels_file == "":
			continue
		var lv = c._load_validated("%s/%s" % [dir, w.levels_file], "%s/levels.schema.json" % schema_dir)
		if lv == null:
			continue
		for l in lv.levels:
			c.levels[l.id] = l
			c.level_order.append(l.id)
			c.world_levels[w.id].append(l.id)
	if c.errors.is_empty():
		c._check_references()
	return c


func _load_validated(path: String, schema_path: String):
	var data = _read_json(path)
	var schema = _read_json(schema_path)
	if data == null or schema == null:
		return null
	for e in SchemaValidator.validate(data, schema, path.get_file()):
		errors.append(e)
	return _ints(data)


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		errors.append("%s: file not found" % path)
		return null
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s:%d: %s" % [path, j.get_error_line(), j.get_error_message()])
		return null
	return j.data


static func _ints(v):
	if typeof(v) == TYPE_FLOAT and v == floor(v):
		return int(v)
	if v is Array:
		return v.map(func(x): return _ints(x))
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _ints(v[k])
		return d
	return v


func _index(raw: Dictionary) -> void:
	for p in raw.products.products: products[p.id] = p
	for a in raw.animals.animals: animals[a.id] = a
	for w in raw.workshops.workshops: workshops[w.id] = w
	farm = raw.farm
	items = raw.items.items
	trophy_rewards = raw.items.trophy_rewards
	for b in raw.items.boosts: boosts[b.id] = b
	outfits = raw.outfits.slots
	for t in raw.tutorials.tutorials: tutorials[t.id] = t
	worlds = raw.worlds.worlds
	achievements = raw.achievements.achievements


func _check_references() -> void:
	var item_ids := items.map(func(i): return i.id)
	for a in animals.values():
		if a.role == "producer":
			_ref(products, a.product, "animal %s: unknown product" % a.id)
			if a.produce_ticks <= 0 or a.food_ticks <= 0 or a.bites <= 0:
				errors.append("animal %s: producer needs produce_ticks, food_ticks and bites" % a.id)
	for w in workshops.values():
		_ref(products, w.output, "workshop %s: unknown product" % w.id)
		for p in w.inputs: _ref(products, p, "workshop %s: unknown product" % w.id)
	_ref(products, farm.predators.bear.cage_product, "bear: unknown product")
	for b in boosts.values():
		for i in b.cost:
			if not item_ids.has(i): errors.append("boost %s: unknown item '%s'" % [b.id, i])
	for t in trophy_rewards.values():
		for i in t:
			if not item_ids.has(i): errors.append("trophy_rewards: unknown item '%s'" % i)
	for slot in outfits:
		for o in slot.options:
			if o.unlock != "" and not achievements.any(func(a): return a.id == o.unlock):
				errors.append("outfit %s: unknown achievement '%s'" % [o.id, o.unlock])
	for l in levels.values():
		var tag := "level %s" % l.id
		if l.trophy.gold_ticks > l.trophy.silver_ticks:
			errors.append("%s: gold_ticks > silver_ticks" % tag)
		for a in l.start_animals: _ref(animals, a.type, tag + ": unknown animal")
		for a in l.available_animals: _ref(animals, a, tag + ": unknown animal")
		for slot in l.slots:
			for o in slot: _ref(workshops, o.type, tag + ": unknown workshop")
		for k in l.max_level:
			if not ["well", "warehouse", "truck", "plane"].has(k): _ref(workshops, k, tag + ": unknown max_level key")
		for p in l.predators:
			if p.type == "mole" and not p.has("tier"): errors.append(tag + ": mole needs a tier")
		for t in l.get("tutorials", []): _ref(tutorials, t, tag + ": unknown tutorial")
		for g in l.goals:
			match g.type:
				"collect":
					if not g.has("product") or not g.has("count"): errors.append(tag + ": collect goal needs product+count")
					else: _ref(products, g.product, tag + ": unknown product")
				"animal":
					if not g.has("animal") or not g.has("count"): errors.append(tag + ": animal goal needs animal+count")
					else: _ref(animals, g.animal, tag + ": unknown animal")
				"money":
					if not g.has("amount"): errors.append(tag + ": money goal needs amount")


func _ref(table: Dictionary, id: String, msg: String) -> void:
	if not table.has(id):
		errors.append("%s '%s'" % [msg, id])
