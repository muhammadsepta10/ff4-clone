## The painted farm behind the menus, scaled to cover the screen, with a light
## veil so menu text stays readable.
class_name MenuBackdrop
extends Control

const STAGE := Vector2(1920, 1080)

var _scene: Control
var _veil: ColorRect


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_scene = FarmScene.new()
	_scene.size = STAGE
	add_child(_scene)
	_veil = ColorRect.new()
	_veil.color = Color(1, 0.97, 0.88, 0.25)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)


func _process(_d: float) -> void:
	var s := maxf(size.x / STAGE.x, size.y / STAGE.y)
	_scene.scale = Vector2(s, s)
	_scene.position = (size - STAGE * s) / 2
