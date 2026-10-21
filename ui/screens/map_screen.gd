## Campaign map: four worlds, their levels with lock state and best trophy.
extends Screen

var _world := "w1"
var _levels_box: Control


func _ready() -> void:
	_world = args.get("world", _first_open_world())
	var root := safe_root()
	var v := UI.vbox([], 24)
	root.add_child(v)
	var p = App.campaign.profile(App.campaign.active_slot())
	var top := title_bar(p.name, "profiles")
	var cv := CharacterView.new()
	cv.outfit = p.outfit
	cv.custom_minimum_size = Vector2(110, 120)
	top.add_child(cv)
	top.add_child(UI.button(tr("outfit"), _outfit_dialog))
	top.add_child(UI.button(tr("achievements"), func(): main.goto("achievements")))
	v.add_child(top)
	var tabs := UI.hbox()
	for w in App.core.worlds():
		var b := UI.button(tr(w.name_key), func(): _show_world(w.id))
		b.disabled = not App.campaign.is_world_unlocked(w.id)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
	v.add_child(tabs)
	_levels_box = UI.vbox()
	_levels_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_levels_box)
	_show_world(_world)


func _first_open_world() -> String:
	var last := "w1"
	for w in App.core.worlds():
		if App.campaign.is_world_unlocked(w.id) and not App.core.level_ids_in_world(w.id).is_empty():
			last = w.id
	return last


func _show_world(id: String) -> void:
	_world = id
	for c in _levels_box.get_children():
		c.queue_free()
	var w: Dictionary = App.core.worlds().filter(func(x): return x.id == id)[0]
	var story := UI.panel(UI.para(tr(w.story_key), 1600, 34))
	story.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_levels_box.add_child(story)
	var ids := App.core.level_ids_in_world(id)
	if ids.is_empty():
		_levels_box.add_child(UI.label(tr("coming_soon"), 44))
		return
	# Levels stand along a winding dirt path, like stops on the farm road.
	var road := Control.new()
	road.custom_minimum_size = Vector2(1700, 640)
	road.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_levels_box.add_child(road)
	var spots: Array[Vector2] = []
	for i in ids.size():
		var t := float(i) / maxf(1, ids.size() - 1)
		spots.append(Vector2(160 + t * 1380, 320 + sin(i * 1.4 + 0.6) * 180))
	road.draw.connect(func():
		for i in spots.size() - 1:
			var a := spots[i]
			var b := spots[i + 1]
			var n := int(a.distance_to(b) / 34)
			for k in n:
				if k % 2 == 0:
					road.draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), Color("#8d5a2b"), 12.0, true))
	for i in ids.size():
		var lid: String = ids[i]
		var unlocked := App.campaign.is_level_unlocked(lid)
		# Round wooden level marker with the best trophy on its rim.
		var b := GamePopup.big_button(str(i + 1) if unlocked else "🔒", func(): main.goto("game", {"level_id": lid}),
			Color("#a0522d") if unlocked else Color("#8a8178"), 80)
		b.custom_minimum_size = Vector2(220, 220)
		for st in ["normal", "hover", "pressed", "disabled"]:
			(b.get_theme_stylebox(st) as StyleBoxFlat).set_corner_radius_all(110)
		b.disabled = not unlocked
		var best := App.campaign.best_trophy(lid)
		if best != "":
			var badge := TrophyBadge.make(best, 64)
			badge.position = Vector2(150, 0)
			b.add_child(badge)
		b.position = spots[i] - b.custom_minimum_size / 2
		road.add_child(b)


func _outfit_dialog() -> void:
	var slot := App.campaign.active_slot()
	var outfit: Dictionary = App.campaign.profile(slot).outfit
	var preview := CharacterView.new()
	preview.outfit = outfit
	var pickers := OutfitPicker.build(outfit, func(slot_id, opt):
		App.campaign.set_outfit(slot_id, opt)
		preview.outfit = App.campaign.profile(slot).outfit, func(slot_id, opt_id, _u): return App.campaign.is_outfit_unlocked(slot_id, opt_id))
	preview.custom_minimum_size = Vector2(260, 300)
	var p := GamePopup.open(self, tr("outfit"))
	p.body.add_child(UI.hbox([preview, pickers], 30))
	p.closed.connect(func():
		App.save_campaign()
		main.goto("map", {"world": _world}))
