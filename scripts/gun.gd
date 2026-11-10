class_name Gun
extends Node3D
## The gun: rifle model (muzzle along -Z), shell chamber visuals, fire/eject animations.

signal fired(live: bool)

const LENGTH := 0.95
var model: Node3D
var muzzle: Marker3D
var _flash_light: OmniLight3D
var _flash_mesh: MeshInstance3D
var _smoke: GPUParticles3D
var _saw_tween: Tween

func _ready() -> void:
	model = Node3D.new()
	add_child(model)
	var rifle := Models.spawn("bolt_action_rifle_7_62", LENGTH, "x")
	rifle.rotation_degrees.y = 90.0  # muzzle +X -> -Z
	rifle.position = Vector3(0, -0.06, 0.05)
	model.add_child(rifle)
	muzzle = Marker3D.new()
	muzzle.position = Vector3(0, 0.0, -LENGTH * 0.5 + 0.05)
	model.add_child(muzzle)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.7, 0.35)
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 4.0
	muzzle.add_child(_flash_light)
	_flash_mesh = Models.mesh(Models.sphere(0.07), Models.glow(Color(1.0, 0.75, 0.3), 8.0))
	_flash_mesh.scale = Vector3(1, 1, 2.2)
	_flash_mesh.position.z = -0.08
	_flash_mesh.visible = false
	muzzle.add_child(_flash_mesh)
	_smoke = GPUParticles3D.new()
	_smoke.emitting = false
	_smoke.one_shot = true
	_smoke.amount = 24
	_smoke.lifetime = 1.4
	_smoke.explosiveness = 0.9
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3(0, 0.15, 0)
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	_smoke.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.6, 0.55, 0.5, 0.25)
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = sm
	_smoke.draw_pass_1 = q
	muzzle.add_child(_smoke)
	add_child(Models.area(0.22, "gun", self))

func chamber_world() -> Vector3:
	return model.global_transform * Vector3(0, 0.02, 0.08)

func grip_world(right: bool) -> Vector3:
	return model.global_transform * (Vector3(0.0, -0.03, 0.28) if right else Vector3(0.0, -0.02, -0.12))

## Visual hint for the hand saw: barrel glows red while the double shot is armed.
func set_sawed(on: bool) -> void:
	if _saw_tween:
		_saw_tween.kill()
	_flash_mesh.visible = false
	_flash_light.light_color = Color(1.0, 0.2, 0.1) if on else Color(1.0, 0.7, 0.35)
	_flash_light.light_energy = 0.25 if on else 0.0
	_flash_light.omni_range = 0.6 if on else 4.0

func fire(live: bool) -> void:
	if live:
		Sfx.play("shot")
		_flash_light.omni_range = 4.0
		_flash_light.light_energy = 9.0
		_flash_mesh.visible = true
		_smoke.restart()
		var tw := create_tween().set_parallel()
		tw.tween_property(_flash_light, "light_energy", 0.0, 0.25)
		tw.tween_property(model, "position:z", 0.12, 0.05)
		tw.tween_property(model, "rotation:x", 0.35, 0.05)
		tw.chain().tween_callback(func(): _flash_mesh.visible = false)
		tw.tween_property(model, "position:z", 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(model, "rotation:x", 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		fired.emit(true)
		await tw.finished
	else:
		Sfx.play("click")
		var tw := create_tween()
		tw.tween_property(model, "position:z", 0.015, 0.04)
		tw.tween_property(model, "position:z", 0.0, 0.15)
		fired.emit(false)
		await tw.finished
	set_sawed(false)

## Ejects a shell that flies out sideways and lands on the table, showing its colour.
func eject(live: bool) -> void:
	Sfx.play("rack")
	var tw0 := create_tween()
	tw0.tween_property(model, "position:y", 0.03, 0.08)
	tw0.tween_property(model, "position:y", 0.0, 0.12)
	var shell := Gun.make_shell(live)
	get_parent().add_child(shell)
	shell.global_position = chamber_world()
	var side := model.global_transform.basis.x.normalized()
	var land := shell.global_position + side * 0.35 + Vector3(randf_range(-0.1, 0.1), 0, randf_range(-0.1, 0.1))
	land.y = Player.TABLE_Y + 0.025
	var mid := (shell.global_position + land) * 0.5 + Vector3(0, 0.3, 0)
	var start := shell.global_position
	var fly := func(t: float) -> void:
		shell.global_position = start.lerp(mid, t).lerp(mid.lerp(land, t), t)
		shell.rotation = Vector3(t * 9.0, t * 4.0, 0.0)
	var settle := func() -> void:
		Sfx.play("eject")
		shell.rotation = Vector3(0, randf() * TAU, PI * 0.5)
	var tw := create_tween()
	tw.tween_method(fly, 0.0, 1.0, 0.45)
	tw.tween_callback(settle)
	tw.tween_interval(1.4)
	tw.tween_property(shell, "scale", Vector3.ONE * 0.001, 0.3)
	tw.tween_callback(shell.queue_free)
	await get_tree().create_timer(0.5).timeout

static func make_shell(live: bool) -> Node3D:
	var s := Node3D.new()
	var col := Color(0.85, 0.08, 0.06) if live else Color(0.1, 0.25, 0.9)
	var body := Models.glow(col, 0.6)
	body.emission_energy_multiplier = 0.5
	body.roughness = 0.4
	s.add_child(Models.mesh(Models.cyl(0.022, 0.07), body, Vector3(0, 0.01, 0)))
	s.add_child(Models.mesh(Models.cyl(0.0235, 0.022), Models.mat(Color(0.8, 0.62, 0.25), 1.0, 0.3), Vector3(0, -0.035, 0)))
	return s

## Racks the slide with no shell coming out (after loading).
func rack() -> void:
	Sfx.play("rack")
	var tw := create_tween()
	tw.tween_property(model, "position:y", 0.03, 0.08)
	tw.tween_property(model, "position:y", 0.0, 0.12)
	await tw.finished
