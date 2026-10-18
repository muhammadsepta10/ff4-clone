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
	_levels_box.add_child(UI.para(tr(w.story_key), 1700, 34))
	var ids := App.core.level_ids_in_world(id)
	if ids.is_empty():
		_levels_box.add_child(UI.label(tr("coming_soon"), 44))
		return
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 28)
	_levels_box.add_child(UI.centered(grid))
	for i in ids.size():
		var lid: String = ids[i]
		var unlocked := App.campaign.is_level_unlocked(lid)
		var b := UI.button(App.t("level_n", {"n": i + 1}), func(): main.goto("briefing", {"level_id": lid}), 40)
		b.custom_minimum_size = Vector2(300, 200)
		b.disabled = not unlocked
		var badge := TrophyBadge.make(App.campaign.best_trophy(lid), 56)
		badge.position = Vector2(230, 10)
		b.add_child(badge)
		grid.add_child(b)


func _outfit_dialog() -> void:
	var slot := App.campaign.active_slot()
	var outfit: Dictionary = App.campaign.profile(slot).outfit
	var preview := CharacterView.new()
	preview.outfit = outfit
	var overlay: Control
	var pickers := OutfitPicker.build(outfit, func(slot_id, opt):
		App.campaign.set_outfit(slot_id, opt)
		preview.outfit = App.campaign.profile(slot).outfit, func(slot_id, opt_id, _u): return App.campaign.is_outfit_unlocked(slot_id, opt_id))
	var box := UI.vbox([UI.label(tr("outfit"), 48), UI.hbox([preview, pickers]),
		UI.button(tr("close"), func():
			App.save_campaign()
			overlay.queue_free()
			main.goto("map", {"world": _world}))])
	overlay = UI.modal(self, box)
