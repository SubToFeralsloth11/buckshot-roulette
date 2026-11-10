class_name CameraRig
extends Node3D
## Seat camera with idle sway, screen shake and cinematic focus moves.

var cam: Camera3D
var home_xf := Transform3D.IDENTITY
var orbit := false
var _trauma := 0.0
var _t := 0.0
var _tween: Tween

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.near = 0.03
	add_child(cam)
	cam.make_current()

func _xf(pos: Vector3, look: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)

func _move(xf: Transform3D, dur: float) -> void:
	if _tween:
		_tween.kill()
	if dur <= 0.0:
		transform = xf
		return
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "transform", xf, dur)
	await _tween.finished

func set_home(pos: Vector3, look: Vector3, dur := 0.8) -> void:
	home_xf = _xf(pos, look)
	await _move(home_xf, dur)

func go_home(dur := 0.6) -> void:
	await _move(home_xf, dur)

func focus(pos: Vector3, look: Vector3, dur := 0.6) -> void:
	await _move(_xf(pos, look), dur)

## Push in from the home position toward a point of interest.
func focus_on(point: Vector3, dur := 0.5) -> void:
	var pos := home_xf.origin.lerp(point, 0.25)
	await _move(_xf(pos, point), dur)

func shake(amount: float) -> void:
	_trauma = clampf(maxf(_trauma, amount), 0.0, 1.0)

func _process(delta: float) -> void:
	_t += delta
	if orbit:
		var a := _t * 0.12
		transform = _xf(Vector3(sin(a) * 2.6, 1.9, cos(a) * 2.6), Vector3(0, 0.9, 0))
	_trauma = maxf(0.0, _trauma - delta * 1.6)
	var s := _trauma * _trauma
	cam.position = Vector3(sin(_t * 0.6) * 0.012, sin(_t * 0.9) * 0.008, 0.0) + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * s * 0.06
	cam.rotation = Vector3(sin(_t * 0.5) * 0.004 + randf_range(-1, 1) * s * 0.03, sin(_t * 0.37) * 0.006 + randf_range(-1, 1) * s * 0.03, randf_range(-1, 1) * s * 0.05)
