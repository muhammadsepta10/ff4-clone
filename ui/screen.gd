## Base for screens: router reference, args, safe-area root.
class_name Screen
extends Control

var main: Node
var args := {}


## A full-rect MarginContainer honoring the display safe area.
func safe_root() -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := UI.safe_margins(self) if is_inside_tree() else {"left": 24, "top": 16, "right": 24, "bottom": 16}
	for side in sm:
		m.add_theme_constant_override("margin_" + side, sm[side])
	add_child(m)
	return m


func title_bar(title: String, back_to := "") -> HBoxContainer:
	var h := UI.hbox()
	if back_to != "":
		h.add_child(GamePopup.big_button("◀", func(): main.goto(back_to), Color("#a0522d"), 40))
	var l := UI.label(title, 60, Color("#fff3d6"))
	l.add_theme_color_override("font_outline_color", Color("#5d3a1a"))
	l.add_theme_constant_override("outline_size", 16)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h
