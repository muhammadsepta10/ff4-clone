## Shows CREDITS.md (every third-party asset with source and license, ADR 0007).
extends Screen


func _ready() -> void:
	var root := safe_root()
	var v := UI.vbox()
	root.add_child(v)
	v.add_child(title_bar(tr("credits"), "profiles"))
	var text := RichTextLabel.new()
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 30)
	text.add_theme_color_override("default_color", App.COLOR_INK)
	text.text = _plain(FileAccess.get_file_as_string("res://CREDITS.md"))
	v.add_child(text)


## Markdown table rows become "a — b — c" lines; headings and separators are simplified.
static func _plain(md: String) -> String:
	var out := []
	for line in md.split("\n"):
		var l := line.strip_edges()
		if l.begins_with("|---") or l.begins_with("| ---"):
			continue
		if l.begins_with("|"):
			var cells := Array(l.trim_prefix("|").trim_suffix("|").split("|")).map(func(c): return c.strip_edges())
			out.append(" — ".join(cells))
		else:
			out.append(l.trim_prefix("# ").trim_prefix("## "))
	return "\n".join(out)
