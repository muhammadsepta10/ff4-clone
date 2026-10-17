## Minimal JSON Schema validator (subset used by content/schema/*.json).
## Supports: type, properties, required, additionalProperties (bool or schema),
## items, minItems, maxItems, enum, minimum, maximum, minLength.
class_name SchemaValidator
extends RefCounted


static func validate(value, schema: Dictionary, path := "$") -> Array[String]:
	var errs: Array[String] = []
	_check(value, schema, path, errs)
	return errs


static func _check(v, sc: Dictionary, path: String, errs: Array[String]) -> void:
	if sc.has("type") and not _type_ok(v, sc.type):
		errs.append("%s: expected %s, got %s" % [path, sc.type, type_string(typeof(v))])
		return
	if sc.has("enum") and not sc.enum.has(v):
		errs.append("%s: %s not in %s" % [path, v, sc.enum])
	if sc.has("minimum") and _is_num(v) and v < sc.minimum:
		errs.append("%s: %s < minimum %s" % [path, v, sc.minimum])
	if sc.has("maximum") and _is_num(v) and v > sc.maximum:
		errs.append("%s: %s > maximum %s" % [path, v, sc.maximum])
	if sc.has("minLength") and v is String and v.length() < sc.minLength:
		errs.append("%s: string shorter than %d" % [path, sc.minLength])
	if v is Array:
		if sc.has("minItems") and v.size() < sc.minItems:
			errs.append("%s: fewer than %d items" % [path, sc.minItems])
		if sc.has("maxItems") and v.size() > sc.maxItems:
			errs.append("%s: more than %d items" % [path, sc.maxItems])
		if sc.has("items"):
			for i in v.size():
				_check(v[i], sc.items, "%s[%d]" % [path, i], errs)
	if v is Dictionary:
		var props: Dictionary = sc.get("properties", {})
		for r in sc.get("required", []):
			if not v.has(r):
				errs.append("%s: missing required '%s'" % [path, r])
		for k in v:
			var child_path := "%s.%s" % [path, k]
			if props.has(k):
				_check(v[k], props[k], child_path, errs)
			elif sc.has("additionalProperties"):
				var ap = sc.additionalProperties
				if ap is bool:
					if not ap:
						errs.append("%s: unexpected property" % child_path)
				else:
					_check(v[k], ap, child_path, errs)


static func _is_num(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


static func _type_ok(v, t: String) -> bool:
	match t:
		"object": return v is Dictionary
		"array": return v is Array
		"string": return v is String
		"boolean": return v is bool
		"number": return _is_num(v)
		"integer": return typeof(v) == TYPE_INT or (typeof(v) == TYPE_FLOAT and v == floor(v))
	return false
