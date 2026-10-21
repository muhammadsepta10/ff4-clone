## Approved sprites from art/<batch>/ (docs/style-bible.md). Callers fall back to
## procedural placeholder art when a sprite is missing.
class_name Art
extends RefCounted

# id -> [path, on-screen height in px at 1080p, including the image's padding]
const SPRITES := {
	# batch 1: animals and predators (art faces left, cropped to content)
	"chicken": ["res://art/batch1/chicken.png", 90.0],
	"sheep": ["res://art/batch1/sheep.png", 100.0],
	"cow": ["res://art/batch1/cow.png", 125.0],
	"bear": ["res://art/batch1/bear.png", 140.0],
	"mole": ["res://art/batch1/mole.png", 90.0],
	# batch 2: workshops and products (cropped to content)
	"bakery": ["res://art/batch2/bakery.png", 130.0],
	"churn": ["res://art/batch2/dairy.png", 130.0],
	"weaver": ["res://art/batch2/loom.png", 130.0],
	"studio": ["res://art/batch2/tailor.png", 130.0],
	"egg": ["res://art/batch2/egg.png", 58.0],
	"milk": ["res://art/batch2/milk.png", 66.0],
	"wool": ["res://art/batch2/wool.png", 58.0],
	"sweet_roll": ["res://art/batch2/pastry.png", 58.0],
	"butter": ["res://art/batch2/butter.png", 56.0],
	"cloth": ["res://art/batch2/cloth.png", 56.0],
	# batch 3: sweet shop, caged bear (cropped)
	"confectory": ["res://art/batch3/patisserie.png", 130.0],
	"caged_bear": ["res://art/batch3/caged_bear.png", 110.0],
	# scene: buildings and decoration (cropped to content)
	"well": ["res://art/scene/well.png", 200.0],
	"warehouse": ["res://art/scene/warehouse.png", 220.0],
	"truck": ["res://art/scene/truck.png", 130.0],
	"plane": ["res://art/scene/plane.png", 130.0],
	"grass": ["res://art/scene/grass.png", 60.0],
	"tree": ["res://art/scene/tree.png", 170.0],
	"plot": ["res://art/scene/plot.png", 140.0],
	# story: character portraits (cropped to content)
	"char_sari": ["res://art/story/sari.png", 560.0],
	"char_darto": ["res://art/story/darto.png", 560.0],
	"char_wulan": ["res://art/story/wulan.png", 560.0],
	# batch 4: FF4 animals, buildings and products (cropped)
	"pig": ["res://art/batch4/pig.png", 105.0],
	"cat": ["res://art/batch4/cat.png", 80.0],
	"dog": ["res://art/batch4/dog.png", 90.0],
	"mixer": ["res://art/batch4/mixer.png", 130.0],
	"dryer": ["res://art/batch4/dryer.png", 130.0],
	"butchery": ["res://art/batch4/butchery.png", 130.0],
	"separator": ["res://art/batch4/separator.png", 130.0],
	"spinner": ["res://art/batch4/spinner.png", 130.0],
	"cheese_maker": ["res://art/batch4/cheese_maker.png", 130.0],
	"sausage_maker": ["res://art/batch4/sausage_maker.png", 130.0],
	"dye_works": ["res://art/batch4/dye_works.png", 130.0],
	"smokehouse": ["res://art/batch4/smokehouse.png", 130.0],
	"grill": ["res://art/batch4/grill.png", 130.0],
	"egg_mix": ["res://art/batch4/egg_mix.png", 58.0],
	"egg_powder": ["res://art/batch4/egg_powder.png", 58.0],
	"pancake": ["res://art/batch4/pancake.png", 58.0],
	"sugar": ["res://art/batch4/sugar.png", 58.0],
	"meat": ["res://art/batch4/meat.png", 58.0],
	"steak": ["res://art/batch4/steak.png", 58.0],
	"sausage": ["res://art/batch4/sausage.png", 58.0],
	"smoked_sausage": ["res://art/batch4/smoked_sausage.png", 58.0],
	"coal": ["res://art/batch4/coal.png", 58.0],
	"grilled_sausage": ["res://art/batch4/grilled_sausage.png", 58.0],
	"cream": ["res://art/batch4/cream.png", 58.0],
	"ferment": ["res://art/batch4/ferment.png", 58.0],
	"cheese": ["res://art/batch4/cheese.png", 58.0],
	"thread": ["res://art/batch4/thread.png", 58.0],
	"paint": ["res://art/batch4/paint.png", 58.0],
	"coloured_cloth": ["res://art/batch4/coloured_cloth.png", 58.0],
	"chalk": ["res://art/batch4/chalk.png", 58.0],
	"dress": ["res://art/batch4/dress.png", 58.0],
	"char_bowo": ["res://art/story/bowo.png", 560.0],
	"char_rina": ["res://art/story/rina.png", 560.0],
	"char_lurah": ["res://art/story/lurah.png", 560.0],
	"char_tari": ["res://art/story/tari.png", 560.0],
	"char_karto": ["res://art/story/karto.png", 560.0],
	"char_zibo": ["res://art/story/zibo.png", 560.0],
}

static var _cache := {}


## The sprite for `id`, or null when no approved sprite exists.
static func tex(id: String) -> Texture2D:
	if not _cache.has(id):
		var t: Texture2D = null
		if SPRITES.has(id) and ResourceLoader.exists(SPRITES[id][0]):
			t = load(SPRITES[id][0])
		_cache[id] = t
	return _cache[id]


static func height(id: String) -> float:
	return SPRITES[id][1]


## A small fixed-size icon for menus and rows; empty Control when there is no sprite.
static func icon(id: String, px := 56.0) -> Control:
	var t := tex(id)
	var r := TextureRect.new()
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if t != null:
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return r
