extends Node3D
## Builds the dark room: environment, hanging lamp, table, clutter, dust.

var _lamp_pivot: Node3D
var _t := 0.0

func _ready() -> void:
	_environment()
	_lamp()
	_table()
	_floor_and_walls()
	_clutter()
	_dust()

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.26, 0.22)
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	env.ssao_enabled = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.018
	env.volumetric_fog_albedo = Color(0.9, 0.8, 0.7)
	env.volumetric_fog_length = 12.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	env.adjustment_contrast = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _lamp() -> void:
	_lamp_pivot = Node3D.new()
	_lamp_pivot.position = Vector3(0, 3.2, 0)
	add_child(_lamp_pivot)
	var lamp := Models.spawn("hanging_industrial_lamp", 1.3, "y")
	lamp.position = Vector3(0, -1.3, 0)
	_lamp_pivot.add_child(lamp)
	# The bulb sits inside the shade: the shade and bulb must not shadow the spot.
	for m in lamp.find_children("*", "GeometryInstance3D", true, false):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bulb := Models.mesh(Models.sphere(0.05), Models.glow(Color(1.0, 0.75, 0.45), 12.0), Vector3(0, -1.27, 0))
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lamp_pivot.add_child(bulb)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, -1.34, 0)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	spot.light_color = Color(1.0, 0.82, 0.62)
	spot.light_energy = 10.0
	spot.spot_range = 4.5
	spot.spot_angle = 50.0
	spot.spot_angle_attenuation = 0.6
	spot.shadow_enabled = true
	spot.light_volumetric_fog_energy = 0.8
	_lamp_pivot.add_child(spot)
	# Faint cold rim light far back, so the clutter is barely readable.
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2.5, 2.2, -3.5)
	rim.light_color = Color(0.35, 0.45, 0.6)
	rim.light_energy = 0.6
	rim.omni_range = 5.0
	rim.light_volumetric_fog_energy = 0.0
	add_child(rim)

func _table() -> void:
	var t := Models.spawn("round_wooden_table_01", 2.25, "x")
	var h := Models._aabb(t, Transform3D.IDENTITY).size.y
	t.scale.y = Player.TABLE_Y / h
	add_child(t)

func _floor_and_walls() -> void:
	var noise := NoiseTexture2D.new()
	noise.width = 512
	noise.height = 512
	noise.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	fn.fractal_octaves = 5
	noise.noise = fn
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.05, 0.05))
	grad.set_color(1, Color(0.2, 0.19, 0.17))
	noise.color_ramp = grad
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = noise
	floor_mat.uv1_scale = Vector3(6, 6, 6)
	floor_mat.roughness = 0.9
	var pm := PlaneMesh.new()
	pm.size = Vector2(14, 14)
	add_child(Models.mesh(pm, floor_mat))
	var wall_mat := floor_mat.duplicate()
	wall_mat.albedo_color = Color(0.6, 0.6, 0.6)
	for i in 4:
		var w := Models.mesh(Models.box(Vector3(14, 5, 0.2)), wall_mat)
		var a := i * PI * 0.5
		w.position = Vector3(sin(a) * 6.0, 2.5, cos(a) * 6.0)
		w.rotation.y = a
		add_child(w)
	var ceil := Models.mesh(Models.box(Vector3(14, 0.2, 14)), wall_mat, Vector3(0, 4.2, 0))
	add_child(ceil)

func _place(model: String, size: float, pos: Vector3, rot_deg := Vector3.ZERO, axis := "max") -> Node3D:
	var n := Models.spawn(model, size, axis)
	n.position = pos
	n.rotation_degrees = rot_deg
	add_child(n)
	return n

func _clutter() -> void:
	# Crate stacks.
	_place("wooden_crate_02", 1.1, Vector3(-3.4, 0, -2.4), Vector3(0, 20, 0))
	_place("wooden_crate_01", 0.85, Vector3(-3.3, 0.45, -2.3), Vector3(0, 35, 0))
	_place("old_military_crate", 0.95, Vector3(-3.6, 0, 1.2), Vector3(0, 80, 0))
	_place("cardboard_box_01", 0.5, Vector3(-3.0, 0, 2.2), Vector3(0, 10, 0))
	_place("cardboard_box_01", 0.4, Vector3(-3.05, 0.34, 2.25), Vector3(0, -25, 0))
	_place("wooden_crate_01", 0.8, Vector3(3.2, 0, 2.8), Vector3(0, -40, 0))
	# Barrels.
	_place("Barrel_01", 0.9, Vector3(3.3, 0, -2.6), Vector3.ZERO, "y")
	_place("Barrel_01", 0.9, Vector3(3.9, 0, -1.8), Vector3(0, 70, 0), "y")
	_place("wooden_barrels_01", 1.0, Vector3(2.8, 0, -3.6), Vector3(0, -30, 0))
	# Shelf against the back wall.
	_place("steel_frame_shelves_01", 2.3, Vector3(0.3, 0, -4.4), Vector3.ZERO, "y")
	# Broken chair: tipped on its side with a snapped leg nearby.
	_place("WoodenChair_01", 1.0, Vector3(2.6, 0.32, 1.4), Vector3(0, 30, 88), "y")
	var leg := Models.mesh(Models.box(Vector3(0.04, 0.04, 0.42)), Models.mat(Color(0.25, 0.15, 0.08)), Vector3(2.2, 0.02, 1.9), Vector3(0, 35, 0))
	add_child(leg)
	# Hanging chain.
	var steel := Models.mat(Color(0.35, 0.33, 0.3), 1.0, 0.45)
	for i in 34:
		var link := Models.mesh(Models.torus(0.018, 0.032), steel, Vector3(-2.1, 4.1 - i * 0.05, -1.7), Vector3(90, 90 * (i % 2), 0))
		link.scale = Vector3(1, 1, 1.6)
		add_child(link)

func _dust() -> void:
	var p := GPUParticles3D.new()
	p.amount = 220
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = Vector3(0, 1.4, 0)
	p.visibility_aabb = AABB(Vector3(-2, -1.5, -2), Vector3(4, 3, 4))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(1.0, 0.8, 1.0)
	m.direction = Vector3(0, 1, 0)
	m.spread = 180.0
	m.initial_velocity_min = 0.005
	m.initial_velocity_max = 0.03
	m.gravity = Vector3(0, -0.004, 0)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.3
	m.turbulence_noise_speed_random = 0.2
	m.scale_min = 0.5
	m.scale_max = 1.4
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.004, 0.004)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(1.0, 0.85, 0.6, 0.12)
	q.material = sm
	p.draw_pass_1 = q
	add_child(p)

func _process(delta: float) -> void:
	_t += delta
	_lamp_pivot.rotation.x = sin(_t * 0.8) * 0.025
	_lamp_pivot.rotation.z = sin(_t * 0.6 + 1.0) * 0.02
