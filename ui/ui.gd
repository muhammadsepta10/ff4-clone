## Small helpers for building touch-friendly UI in code.
class_name UI
extends RefCounted

const MIN_TOUCH := Vector2(120, 96)  # ≈48 dp at 1080p logical height


static func label(text: String, size := 36, color := App.COLOR_INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Wrapping label for long text; needs a width because wrapped labels have no minimum width.
static func para(text: String, width: float, size := 36, color := App.COLOR_INK) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


static func button(text: String, on_press: Callable, size := 36) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = MIN_TOUCH
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func():
		App.play_sfx("click")
		on_press.call())
	return b


static func vbox(children: Array = [], sep := 16) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	for c in children:
		v.add_child(c)
	return v


static func hbox(children: Array = [], sep := 16) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	for c in children:
		h.add_child(c)
	return h


static func panel(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_child(child)
	return p


static func centered(child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(child)
	return c


## Full-screen dimmed modal with a centered panel. Returns the overlay; free it
## or call close() with any node inside it to close.
static func modal(parent: Node, content: Control) -> Control:
	var overlay := ColorRect.new()
	overlay.set_meta("ui_modal", true)
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(centered(panel(content)))
	parent.add_child(overlay)
	content.scale = Vector2(0.85, 0.85)
	var tw := content.create_tween()
	tw.tween_property(content, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return overlay


## Closes the modal that contains `node`. Button callbacks use this because a
## lambda captures a local's value when it is created, so an `overlay` variable
## assigned after the buttons are built is still null inside them.
static func close(node: Node) -> void:
	while node != null and not node.has_meta("ui_modal"):
		node = node.get_parent()
	if node != null:
		node.queue_free()


static func confirm(parent: Node, text: String, on_yes: Callable) -> void:
	var box := vbox()
	box.add_child(para(text, 800))
	box.add_child(hbox([
		button(App.tr("cancel"), func(): close(box)),
		button(App.tr("ok"), func():
			close(box)
			on_yes.call()),
	]))
	box.custom_minimum_size.x = 800
	modal(parent, box)


## Margins that keep content out of camera cut-outs and rounded corners.
static func safe_margins(node: Control) -> Dictionary:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var vp := node.get_viewport_rect().size
	if win.x <= 0 or safe.size.x <= 0 or OS.get_name() != "Android":
		return {"left": 24, "top": 16, "right": 24, "bottom": 16}
	var sx := vp.x / win.x
	var sy := vp.y / win.y
	return {
		"left": int(safe.position.x * sx) + 16,
		"top": int(safe.position.y * sy) + 12,
		"right": int((win.x - safe.end.x) * sx) + 16,
		"bottom": int((win.y - safe.end.y) * sy) + 12,
	}
