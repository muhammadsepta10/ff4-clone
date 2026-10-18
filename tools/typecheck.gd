## Loads every GDScript in the project so parse/type errors surface (autoloads available).
## Usage: godot --headless --path . -s tools/typecheck.gd
extends SceneTree


func _initialize() -> void:
	var bad := 0
	for f in _scripts("res://"):
		if f == "res://tools/typecheck.gd":
			continue
		var s: GDScript = load(f)
		if s == null or not s.can_instantiate():
			printerr("FAIL ", f)
			bad += 1
	print("typecheck: %d failing script(s)" % bad)
	quit(1 if bad > 0 else 0)


func _scripts(dir: String) -> Array:
	var out := []
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			out.append_array(_scripts(dir.path_join(d)))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out
