## Three profile slots: create (name + outfit), select, delete with confirmation.
extends Screen


func _ready() -> void:
	var root := safe_root()
	var v := UI.vbox([], 28)
	root.add_child(v)
	var top := title_bar(tr("app_title"))
	top.add_child(UI.button(tr("settings"), func(): main.goto("settings")))
	top.add_child(UI.button(tr("credits"), func(): main.goto("credits")))
	top.add_child(UI.button(tr("benchmark"), func(): main.goto("benchmark")))
	v.add_child(top)
	v.add_child(UI.label(tr("profile_select"), 40))
	var slots := UI.hbox([], 32)
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(slots)
	for i in Campaign.SLOTS:
		slots.add_child(_slot_card(i))


func _slot_card(i: int) -> Control:
	var p = App.campaign.profile(i)
	var box := UI.vbox()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(480, 600)
	if p == null:
		box.add_child(UI.label(tr("profile_empty"), 40))
		box.add_child(UI.button(tr("profile_new"), func(): _create_dialog(i)))
	else:
		var cv := CharacterView.new()
		cv.outfit = p.outfit
		cv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(cv)
		box.add_child(UI.label(p.name, 44))
		box.add_child(UI.label("🏆 %d" % p.best.size(), 32))
		box.add_child(UI.button(tr("play"), func(): _select(i)))
		box.add_child(UI.button(tr("profile_delete"), func():
			UI.confirm(self, App.t("profile_delete_confirm", {"name": p.name}), func():
				App.campaign.delete_profile(i)
				App.save_campaign()
				main.goto("profiles")), 28))
	return UI.panel(box)


func _select(i: int) -> void:
	App.campaign.select_profile(i)
	App.save_campaign()
	var snap := App.pending_session()
	if snap.is_empty():
		main.goto("map")
		return
	var box := UI.vbox()
	box.add_child(UI.para(tr("resume_level"), 800, 40))
	box.add_child(UI.hbox([
		UI.button(tr("map"), func():
			App.clear_session()
			main.goto("map")),
		UI.button(tr("resume"), func(): main.goto("game", {"snapshot": snap})),
	]))
	UI.modal(self, box)


## Name + outfit picker. Only unlocked outfits (base ones for a new profile) are offered.
func _create_dialog(slot: int) -> void:
	var outfit := {}
	for s in App.core.catalog().outfits:
		outfit[s.id] = s.options[0].id
	var box := UI.vbox()
	box.custom_minimum_size.x = 1000
	box.add_child(UI.label(tr("profile_new"), 48))
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = tr("profile_name")
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(600, 96)
	box.add_child(name_edit)
	var preview := CharacterView.new()
	preview.outfit = outfit
	var pickers := OutfitPicker.build(outfit, func(slot_id, opt):
		outfit[slot_id] = opt
		preview.outfit = outfit.duplicate(), func(_slot_id, _opt_id, unlock): return unlock == "")
	box.add_child(UI.hbox([preview, pickers]))
	box.add_child(UI.hbox([
		UI.button(tr("cancel"), func(): UI.close(box)),
		UI.button(tr("profile_create"), func():
			if App.campaign.create_profile(slot, name_edit.text, outfit):
				App.save_campaign()
				UI.close(box)
				main.goto("profiles")
			else:
				App.play_sfx("error")
				name_edit.grab_focus()),
	]))
	UI.modal(self, box)

