## All 40 achievements with progress, unlocked or not.
extends Screen


func _ready() -> void:
	var root := safe_root()
	var v := UI.vbox()
	root.add_child(v)
	var list := App.campaign.achievements()
	var done := list.filter(func(a): return a.unlocked).size()
	v.add_child(title_bar("%s  %d/%d" % [tr("achievements"), done, list.size()], "map"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	for a in list:
		var row := UI.hbox([TrophyBadge.make("gold" if a.unlocked else "", 44)])
		var l := UI.label("%s  (%d/%d)" % [tr(a.id), a.progress, a.gte], 30, App.COLOR_INK if a.unlocked else Color(0, 0, 0, 0.45))
		l.custom_minimum_size.x = 780
		row.add_child(l)
		grid.add_child(row)
