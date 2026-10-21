## Level briefing: story, goals, trophy limits, exchange items for boosts.
extends Screen

var _boost_box: VBoxContainer


func _ready() -> void:
	var lid: String = args.level_id
	var lvl := App.core.get_level(lid)
	var root := safe_root()
	var v := UI.vbox([], 24)
	root.add_child(v)
	var n := App.core.level_ids_in_world(lvl.world).find(lid) + 1
	v.add_child(title_bar("%s — %s" % [tr("world_" + lvl.world), App.t("level_n", {"n": n})], "map"))
	var cols := UI.hbox([], 40)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left := UI.vbox()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var story := _story_keys(lid, lvl)
	var line := StoryDialog.parse(tr(lvl.get("story_key", "")))
	var story_row := UI.hbox([], 20)
	var line_label := UI.para(("%s: %s" % [line.speaker, line.text]) if line.speaker != "" else line.text, 700, 36)
	line_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_row.add_child(line_label)
	story_row.add_child(UI.button(tr("story_replay"), func(): StoryDialog.show_keys(self, story), 30))
	left.add_child(story_row)
	left.add_child(UI.label(tr("briefing"), 44, App.COLOR_ACCENT_DARK))
	for g in lvl.goals:
		left.add_child(UI.label("• " + App.goal_text({"type": g.type, "target": g.get("count", g.get("amount", 0)),
			"product": g.get("product", ""), "animal": g.get("animal", "")}), 36))
	left.add_child(UI.hbox([TrophyBadge.make("gold"), UI.label(App.format_time(lvl.trophy.gold_ticks)),
		TrophyBadge.make("silver"), UI.label(App.format_time(lvl.trophy.silver_ticks)),
		UI.label(App.t("result_trophy", {"t": tr(App.campaign.best_trophy(lid)) if App.campaign.best_trophy(lid) != "" else "-"}), 30)]))
	var lp := UI.panel(left)
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(lp)
	_boost_box = UI.vbox()
	_boost_box.custom_minimum_size.x = 640
	cols.add_child(UI.panel(_boost_box))
	_refresh_boosts()
	var start := UI.button(tr("start"), func():
		App.clear_session()
		main.goto("game", {"level_id": lid, "boosts": App.campaign.take_prepared_boosts()}), 48)
	start.custom_minimum_size = Vector2(420, 120)
	start.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(start)
	# Tell the story the first time a level is opened (until it is beaten).
	if App.campaign.best_trophy(lid) == "":
		StoryDialog.show_keys(self, story)


## World intro on a world's first level, then the level's own line.
func _story_keys(lid: String, lvl: Dictionary) -> Array:
	var keys := []
	if App.core.level_ids_in_world(lvl.world).find(lid) == 0:
		for w in App.core.catalog().worlds:
			if w.id == lvl.world:
				keys.append(w.story_key)
	keys.append(lvl.get("story_key", ""))
	return keys


func _refresh_boosts() -> void:
	for c in _boost_box.get_children():
		c.queue_free()
	_boost_box.add_child(UI.label(tr("boosts"), 44, App.COLOR_ACCENT_DARK))
	var items := App.campaign.items()
	var parts := []
	for it in App.core.catalog().items:
		parts.append("%s ×%d" % [tr("item_" + it.id), items.get(it.id, 0)])
	_boost_box.add_child(UI.label(tr("items") + ": " + ", ".join(parts), 30))
	var prepared := App.campaign.prepared_boosts()
	for b in App.core.catalog().boosts.values():
		var cost := []
		for i in b.cost:
			cost.append("%d %s" % [b.cost[i], tr("item_" + i)])
		var btn: Button
		if prepared.has(b.id):
			btn = UI.button("✔ " + tr("boost_" + b.id), func(): pass, 30)
			btn.disabled = true
		else:
			btn = UI.button("%s (%s)" % [tr("boost_" + b.id), ", ".join(cost)], func():
				if App.campaign.prepare_boost(b.id):
					App.save_campaign()
					_refresh_boosts(), 30)
		_boost_box.add_child(btn)
