## Approved sprites from art/<batch>/ (docs/style-bible.md). Callers fall back to
## procedural placeholder art when a sprite is missing.
class_name Art
extends RefCounted

# id -> [path, on-screen height in px at 1080p, including the image's padding]
const SPRITES := {
	# batch 1: animals and predators (art faces left)
	"chicken": ["res://art/batch1/chicken.png", 104.0],
	"sheep": ["res://art/batch1/sheep.png", 120.0],
	"cow": ["res://art/batch1/cow.png", 150.0],
	"bear": ["res://art/batch1/bear.png", 180.0],
	"mole": ["res://art/batch1/mole.png", 130.0],
	# batch 2: workshops and products (cropped to content)
	"bakery": ["res://art/batch2/bakery.png", 130.0],
	"dairy": ["res://art/batch2/dairy.png", 130.0],
	"loom": ["res://art/batch2/loom.png", 130.0],
	"tailor": ["res://art/batch2/tailor.png", 130.0],
	"egg": ["res://art/batch2/egg.png", 58.0],
	"milk": ["res://art/batch2/milk.png", 66.0],
	"wool": ["res://art/batch2/wool.png", 58.0],
	"pastry": ["res://art/batch2/pastry.png", 58.0],
	"butter": ["res://art/batch2/butter.png", 56.0],
	"cake": ["res://art/batch2/cake.png", 58.0],
	"cloth": ["res://art/batch2/cloth.png", 56.0],
	"coat": ["res://art/batch2/coat.png", 66.0],
	# batch 3: hybrid, its product, the last workshop, caged bear and farm buildings (cropped)
	"fluffhen": ["res://art/batch3/fluffhen.png", 92.0],
	"fluff_egg": ["res://art/batch3/fluff_egg.png", 62.0],
	"patisserie": ["res://art/batch3/patisserie.png", 130.0],
	"caged_bear": ["res://art/batch3/caged_bear.png", 110.0],
	"well": ["res://art/batch3/well.png", 150.0],
	"warehouse": ["res://art/batch3/warehouse.png", 150.0],
	"truck": ["res://art/batch3/truck.png", 120.0],
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
