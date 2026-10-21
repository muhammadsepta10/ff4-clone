## End-of-level summary: time, trophy, money, items gained, new achievements.
extends Screen


func _ready() -> void:
	var r: Dictionary = args.result
	var out: Dictionary = args.out
	var box := UI.vbox([], 20)
	box.custom_minimum_size.x = 900
	box.add_child(UI.label(tr("level_complete"), 60, App.COLOR_ACCENT_DARK))
	var badge := TrophyBadge.make(r.trophy, 160)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(badge)
	badge.scale = Vector2.ZERO
	badge.pivot_offset = Vector2(80, 80)
	create_tween().tween_property(badge, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	box.add_child(UI.label(App.t("result_trophy", {"t": tr(r.trophy)}), 40))
	box.add_child(UI.label(App.t("result_time", {"t": App.format_time(r.ticks)}), 40))
	box.add_child(UI.label(App.t("result_money", {"m": r.money}), 40))
	var items := []
	for i in out.items_gained:
		items.append("%d %s" % [out.items_gained[i], tr("item_" + i)])
	box.add_child(UI.label(App.t("result_items", {"i": ", ".join(items) if not items.is_empty() else tr("none")}), 40))
	for a in out.new_achievements:
		box.add_child(UI.label("★ " + App.t("achievement_unlocked", {"name": tr(a)}), 34, Color("#b45f06")))
	App.play_sfx("win")
	if not out.new_achievements.is_empty():
		get_tree().create_timer(1.4).timeout.connect(func(): App.play_sfx("achievement"))
	var ids := App.core.all_level_ids()
	var next_i := ids.find(r.level_id) + 1
	var buttons := UI.hbox([UI.button(tr("map"), func(): main.goto("map")),
		UI.button(tr("restart"), func(): main.goto("briefing", {"level_id": r.level_id}))])
	if next_i < ids.size() and App.campaign.is_level_unlocked(ids[next_i]):
		buttons.add_child(UI.button(tr("next"), func(): main.goto("briefing", {"level_id": ids[next_i]})))
	box.add_child(buttons)
	add_child(UI.centered(UI.panel(box)))
