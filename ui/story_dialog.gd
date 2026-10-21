## Story dialog: a character portrait beside a speech bubble, tap to continue.
## Lines come from i18n strings written as `Speaker: "text"`; a line without a
## speaker is narrated by Grandma Sari.
class_name StoryDialog
extends ColorRect

signal finished

# Speaker names in every language -> portrait sprite id
const SPEAKERS := {
	"Nenek Sari": "char_sari", "Grandma Sari": "char_sari",
	"Pak Darto": "char_darto", "Mr. Darto": "char_darto",
	"Bu Wulan": "char_wulan", "Mrs. Wulan": "char_wulan",
}
const NARRATOR := "char_sari"

var _lines: Array = []
var _i := 0
var _portrait: TextureRect
var _name: Label
var _text: Label
var _hint: Label
var _bubble: Control
var _type_tw: Tween


## Shows the dialog for the given i18n keys (missing keys are skipped).
## Returns null when there is nothing to say.
static func show_keys(parent: Node, keys: Array) -> StoryDialog:
	var lines := []
	for k in keys:
		var s := App.tr(k)
		if k != "" and s != k:
			lines.append(parse(s))
	return show_lines(parent, lines)


## Shows already-parsed lines ({speaker, sprite, text}); null when empty.
static func show_lines(parent: Node, lines: Array) -> StoryDialog:
	if lines.is_empty():
		return null
	var d := StoryDialog.new()
	d._lines = lines
	parent.add_child(d)
	return d


## Splits `Speaker: "text"` into {speaker, sprite, text}.
static func parse(line: String) -> Dictionary:
	var i := line.find(":")
	if i > 0 and i < 24 and SPEAKERS.has(line.substr(0, i)):
		var who := line.substr(0, i)
		var t := line.substr(i + 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
		return {"speaker": who, "sprite": SPEAKERS[who], "text": t}
	return {"speaker": "", "sprite": NARRATOR, "text": line}


func _ready() -> void:
	color = Color(0.1, 0.07, 0.03, 0.55)
	var vp := get_viewport_rect().size
	top_level = true  # cover the whole screen whatever the parent's layout
	position = Vector2.ZERO
	size = vp
	mouse_filter = Control.MOUSE_FILTER_STOP

	_bubble = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = App.COLOR_PANEL
	sb.border_color = Color("#8d5a2b")
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(28)
	sb.content_margin_left = 48
	sb.content_margin_right = 48
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 10
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.position = Vector2(560, vp.y - 400)
	_bubble.custom_minimum_size = Vector2(vp.x - 560 - 120, 300)
	add_child(_bubble)
	var v := UI.vbox([], 12)
	_bubble.add_child(v)
	_name = UI.label("", 40, Color("#b45f06"))
	v.add_child(_name)
	_text = UI.para("", vp.x - 560 - 120 - 96, 40)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text)
	_hint = UI.label("▶ " + App.tr("tap_to_continue"), 28, Color(App.COLOR_INK, 0.6))
	_hint.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(_hint)

	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size = Vector2(460, 560)
	_portrait.position = Vector2(80, vp.y - 600)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)

	var skip := UI.button(App.tr("skip"), _close, 30)
	skip.position = Vector2(vp.x - 260, 30)
	skip.custom_minimum_size = Vector2(220, 90)
	add_child(skip)
	_show_line()


func _show_line() -> void:
	var l: Dictionary = _lines[_i]
	var tex := Art.tex(l.sprite)
	_portrait.texture = tex
	_name.text = l.speaker
	_name.visible = l.speaker != ""
	_text.text = l.text
	_text.visible_ratio = 0.0
	if _type_tw:
		_type_tw.kill()
	_type_tw = create_tween()
	_type_tw.tween_property(_text, "visible_ratio", 1.0, clampf(l.text.length() * 0.025, 0.3, 1.6))
	# portrait slides in from the left on every new line
	_portrait.modulate.a = 0.0
	_portrait.position.x = 20
	var pt := create_tween().set_parallel()
	pt.tween_property(_portrait, "modulate:a", 1.0, 0.2)
	pt.tween_property(_portrait, "position:x", 80.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _gui_input(e: InputEvent) -> void:
	var tap: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
		or (e is InputEventScreenTouch and e.pressed)
	if not tap:
		return
	accept_event()
	App.play_sfx("click")
	if _text.visible_ratio < 1.0:
		_type_tw.kill()
		_text.visible_ratio = 1.0  # first tap finishes the typing
		return
	_i += 1
	if _i >= _lines.size():
		_close()
	else:
		_show_line()


func _close() -> void:
	finished.emit()
	queue_free()
