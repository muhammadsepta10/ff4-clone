## Main menu: game logo, three farmer profiles (create, play, delete) and round
## buttons for settings and credits.
extends Screen


func _ready() -> void:
	var root := safe_root()
	var v := UI.vbox([], 20)
	root.add_child(v)
	var top := UI.hbox([], 16)
	v.add_child(top)
	var logo := UI.label(tr("app_title"), 110, Color("#fff3d6"))
	logo.add_theme_color_override("font_outline_color", Color("#5d3a1a"))
	logo.add_theme_constant_override("outline_size", 26)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	logo.add_theme_constant_override("shadow_offset_y", 8)
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(logo)
	top.add_child(_round("⚙", func(): main.goto("settings")))
	top.add_child(_round("★", func(): main.goto("credits")))
	top.add_child(_round("⏱", func(): main.goto("benchmark")))
	var hint := UI.label(tr("profile_select"), 40, Color("#fff3d6"))
	hint.add_theme_color_override("font_outline_color", Color("#5d3a1a"))
	hint.add_theme_constant_override("outline_size", 12)
	v.add_child(hint)
	var slots := UI.hbox([], 40)
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(slots)
	for i in Campaign.SLOTS:
		slots.add_child(_slot_card(i))


func _round(text: String, cb: Callable) -> Button:
	var b := GamePopup.big_button(text, cb, Color("#a0522d"), 40)
	b.custom_minimum_size = Vector2(110, 110)
	return b


func _slot_card(i: int) -> Control:
	var p = App.campaign.profile(i)
	var box := UI.vbox([], 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(460, 600)
	if p == null:
		var plus := UI.label("+", 160, Color("#c9a66b"))
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(plus)
		var empty := UI.label(tr("profile_empty"), 36, Color(App.COLOR_INK, 0.6))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(empty)
		box.add_child(GamePopup.big_button(tr("profile_new"), func(): _create_dialog(i)))
	else:
		var cv := CharacterView.new()
		cv.outfit = p.outfit
		cv.custom_minimum_size = Vector2(250, 290)
		cv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(cv)
		var name := UI.label(p.name, 48)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name)
		var tro := UI.hbox([TrophyBadge.make("gold", 40), UI.label("%d" % p.best.size(), 34)], 8)
		tro.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(tro)
		var play := GamePopup.big_button("▶ " + tr("play"), func(): _select(i), GamePopup.RIBBON, 44)
		box.add_child(play)
		box.add_child(GamePopup.big_button(tr("profile_delete"), func():
			_confirm(App.t("profile_delete_confirm", {"name": p.name}), func():
				App.campaign.delete_profile(i)
				App.save_campaign()
				main.goto("profiles")), Color("#c0504d"), 26))
	return UI.panel(box)


func _confirm(text: String, on_yes: Callable) -> void:
	var p := GamePopup.open(self, "", false)
	p.body.add_child(UI.para(text, 760, 38))
	var row := UI.hbox([
		GamePopup.big_button(tr("cancel"), func(): p.close(), Color("#a0522d")),
		GamePopup.big_button(tr("ok"), func():
			p.close()
			on_yes.call(), Color("#c0504d")),
	], 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	p.body.add_child(row)


func _select(i: int) -> void:
	App.campaign.select_profile(i)
	App.save_campaign()
	var snap := App.pending_session()
	if snap.is_empty():
		main.goto("map")
		return
	var p := GamePopup.open(self, "", false)
	p.body.add_child(UI.para(tr("resume_level"), 760, 40))
	var row := UI.hbox([
		GamePopup.big_button(tr("map"), func():
			App.clear_session()
			main.goto("map"), Color("#a0522d")),
		GamePopup.big_button("▶ " + tr("resume"), func(): main.goto("game", {"snapshot": snap})),
	], 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	p.body.add_child(row)


## Name + outfit picker. Only unlocked outfits (base ones for a new profile) are offered.
func _create_dialog(slot: int) -> void:
	var outfit := {}
	for s in App.core.catalog().outfits:
		outfit[s.id] = s.options[0].id
	var p := GamePopup.open(self, tr("profile_new"))
	var box := p.body
	box.custom_minimum_size.x = 1000
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = tr("profile_name")
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(600, 96)
	name_edit.add_theme_font_size_override("font_size", 40)
	box.add_child(name_edit)
	var preview := CharacterView.new()
	preview.custom_minimum_size = Vector2(260, 300)
	preview.outfit = outfit
	var pickers := OutfitPicker.build(outfit, func(slot_id, opt):
		outfit[slot_id] = opt
		preview.outfit = outfit.duplicate(), func(_slot_id, _opt_id, unlock): return unlock == "")
	pickers.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(UI.hbox([preview, pickers], 30))
	var row := UI.hbox([
		GamePopup.big_button(tr("cancel"), func(): p.close(), Color("#a0522d")),
		GamePopup.big_button(tr("profile_create"), func():
			if App.campaign.create_profile(slot, name_edit.text, outfit):
				App.save_campaign()
				p.close()
				main.goto("profiles")
			else:
				App.play_sfx("error")
				name_edit.grab_focus()),
	], 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
