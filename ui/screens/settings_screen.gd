## Language and separate music / effects volume.
extends Screen


func _ready() -> void:
	var root := safe_root()
	var v := UI.vbox([], 32)
	root.add_child(v)
	v.add_child(title_bar(tr("settings"), "profiles"))
	var lang := UI.hbox([UI.label(tr("language"), 40)])
	for code in [["id", "Bahasa Indonesia"], ["en", "English"]]:
		var b := UI.button(code[1], func(): App.set_language(code[0]))
		b.disabled = App.settings.language == code[0]
		lang.add_child(b)
	v.add_child(lang)
	for key in ["music", "sfx"]:
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = 1
		s.step = 0.05
		s.value = App.settings[key]
		s.custom_minimum_size = Vector2(700, 80)
		s.value_changed.connect(func(val): App.set_volume(key, val))
		var l := UI.label(tr(key + "_volume"), 40)
		l.custom_minimum_size.x = 420
		v.add_child(UI.hbox([l, s]))
