## Round trophy medal: gold / silver / bronze, or an empty outline.
class_name TrophyBadge
extends Control

const COLORS := {"gold": Color("#f1c232"), "silver": Color("#c0c0c0"), "bronze": Color("#cd7f32")}

var trophy := ""


static func make(t: String, d := 48) -> TrophyBadge:
	var b := TrophyBadge.new()
	b.trophy = t
	b.custom_minimum_size = Vector2(d, d)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _draw() -> void:
	var r := minf(size.x, size.y) / 2 - 2
	var c := size / 2
	if COLORS.has(trophy):
		draw_circle(c, r, COLORS[trophy])
		draw_circle(c, r * 0.6, COLORS[trophy].lightened(0.3))
		draw_arc(c, r, 0, TAU, 32, COLORS[trophy].darkened(0.3), 3)
	else:
		draw_arc(c, r, 0, TAU, 32, Color(0, 0, 0, 0.25), 3)
