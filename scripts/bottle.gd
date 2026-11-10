class_name Bottle
extends Node3D
## Bottle lying on the table; its neck points along local -Z.

var _spinning := false

func _ready() -> void:
	var holder := Node3D.new()
	holder.rotation_degrees.x = -90.0  # model +Y (neck) -> -Z
	var b := Models.spawn("wine_bottles_01", 0.34, "y", "bordeaux")
	b.position = Vector3(0, -0.17, 0)  # centre the bottle on the pivot lengthwise
	holder.add_child(b)
	holder.position.y = 0.037
	add_child(holder)
	add_child(Models.area(0.18, "bottle", self, Vector3(0, 0.04, 0)))

## Spins with an ease-out that feels like friction; returns when stopped.
func spin(strength: float) -> void:
	_spinning = true
	var turns := 3.0 + strength * 4.0 + randf() * 2.0
	var dur := 2.6 + strength * 1.6
	var target := rotation.y + turns * TAU
	var tw := create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation:y", target, dur)
	var ticks := create_tween().set_loops(int(dur / 0.25))
	ticks.tween_callback(func(): Sfx.play("spin", 1.0, -6.0))
	ticks.tween_interval(0.25)
	await tw.finished
	ticks.kill()
	_spinning = false

func pointing_dir() -> Vector3:
	return -global_transform.basis.z.normalized()

func slide_off(dir: Vector3) -> void:
	var tw := create_tween()
	tw.tween_property(self, "global_position", global_position + dir * 1.3, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "global_position:y", -1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	Sfx.play("thud", 1.4, -8.0)
	visible = false
