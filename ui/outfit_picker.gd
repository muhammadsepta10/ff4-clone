## One "◀ option ▶" row per outfit slot, cycling through allowed options.
class_name OutfitPicker
extends RefCounted


## is_allowed(slot_id, option_id, unlock_achievement) -> bool
static func build(outfit: Dictionary, on_change: Callable, is_allowed: Callable) -> VBoxContainer:
	var v := UI.vbox()
	for slot in App.core.catalog().outfits:
		var opts: Array = slot.options.filter(func(o): return is_allowed.call(slot.id, o.id, o.unlock))
		var ids: Array = opts.map(func(o): return o.id)
		var lbl := UI.label("", 34)
		lbl.custom_minimum_size.x = 300
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var show := func():
			lbl.text = "%s: %s" % [App.tr("slot_" + slot.id), App.tr("opt_" + outfit[slot.id])]
		show.call()
		var step := func(d: int):
			var i := ids.find(outfit[slot.id])
			outfit[slot.id] = ids[(i + d + ids.size()) % ids.size()]
			show.call()
			on_change.call(slot.id, outfit[slot.id])
		v.add_child(UI.hbox([UI.button("◀", func(): step.call(-1)), lbl, UI.button("▶", func(): step.call(1))]))
	return v
