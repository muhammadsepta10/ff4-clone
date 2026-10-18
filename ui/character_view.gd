## Procedural farmer portrait from an outfit dictionary (placeholder art until the
## approved asset batch replaces it).
class_name CharacterView
extends Control

const COLORS := {"red": Color("#d9534f"), "blue": Color("#428bca"), "green": Color("#5cb85c"), "gold": Color("#e6b800")}

var outfit := {}:
	set(v):
		outfit = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(220, 260)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2
	var main_col: Color = COLORS.get(outfit.get("color", "red"), Color.RED)
	var u := minf(size.x, size.y) / 260.0
	# body / shirt
	var shirt: String = outfit.get("shirt", "plaid")
	draw_rect(Rect2(c + Vector2(-60, 10) * u, Vector2(120, 110) * u), main_col)
	if shirt == "plaid":
		for i in 4:
			draw_line(c + Vector2(-60 + i * 40, 10) * u, c + Vector2(-60 + i * 40, 120) * u, main_col.darkened(0.35), 4 * u)
			draw_line(c + Vector2(-60, 10 + i * 36) * u, c + Vector2(60, 10 + i * 36) * u, main_col.darkened(0.35), 4 * u)
	elif shirt == "overall":
		draw_rect(Rect2(c + Vector2(-45, 40) * u, Vector2(90, 80) * u), Color("#4a6fa5"))
	elif shirt == "apron":
		draw_rect(Rect2(c + Vector2(-40, 30) * u, Vector2(80, 90) * u), Color.WHITE)
	# head
	draw_circle(c + Vector2(0, -35) * u, 48 * u, Color("#f1c27d"))
	draw_circle(c + Vector2(-16, -40) * u, 6 * u, App.COLOR_INK)
	draw_circle(c + Vector2(16, -40) * u, 6 * u, App.COLOR_INK)
	draw_arc(c + Vector2(0, -25) * u, 18 * u, 0.3, PI - 0.3, 12, App.COLOR_INK, 4 * u)
	# hat
	match outfit.get("hat", "straw"):
		"straw":
			draw_rect(Rect2(c + Vector2(-80, -78) * u, Vector2(160, 14) * u), Color("#e8c37a"))
			draw_rect(Rect2(c + Vector2(-45, -115) * u, Vector2(90, 40) * u), Color("#e8c37a"))
		"cap":
			draw_rect(Rect2(c + Vector2(-50, -100) * u, Vector2(100, 30) * u), main_col)
			draw_rect(Rect2(c + Vector2(30, -78) * u, Vector2(55, 10) * u), main_col.darkened(0.3))
		"bandana":
			draw_rect(Rect2(c + Vector2(-50, -88) * u, Vector2(100, 22) * u), Color("#cc0000"))
		"crown":
			var pts := PackedVector2Array([c + Vector2(-45, -75) * u, c + Vector2(-45, -115) * u, c + Vector2(-20, -95) * u,
				c + Vector2(0, -120) * u, c + Vector2(20, -95) * u, c + Vector2(45, -115) * u, c + Vector2(45, -75) * u])
			draw_colored_polygon(pts, Color("#f1c232"))
