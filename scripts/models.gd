class_name Models
## Loads the Poly Haven glTF models in res://models and normalises their size.

static var _cache := {}

## Returns a Node3D whose child is the model, scaled so its largest extent
## (or the given axis: "x", "y", "z") equals `size`, centred on X/Z with its
## bottom at y = 0. `keep` limits the model to mesh nodes whose name contains it.
static func spawn(model: String, size: float, axis := "max", keep := "") -> Node3D:
	if not _cache.has(model):
		_cache[model] = load("res://models/%s/%s.gltf" % [model, model])
	var inst: Node3D = (_cache[model] as PackedScene).instantiate()
	if keep != "":
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			if not String(m.name).contains(keep):
				m.get_parent().remove_child(m)
				m.free()
	var ab := _aabb(inst, Transform3D.IDENTITY)
	var dim: float
	match axis:
		"x": dim = ab.size.x
		"y": dim = ab.size.y
		"z": dim = ab.size.z
		_: dim = maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
	var s := size / maxf(dim, 0.0001)
	var c := ab.get_center()
	inst.transform = Transform3D(Basis.from_scale(Vector3.ONE * s), -Vector3(c.x, ab.position.y, c.z) * s) * inst.transform
	var wrap := Node3D.new()
	wrap.name = model
	wrap.add_child(inst)
	return wrap

static func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var has := false
	if n is Node3D:
		xf = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out = xf * (n as MeshInstance3D).get_aabb()
		has = true
	for ch in n.get_children():
		var a := _aabb(ch, xf)
		if a.size != Vector3.ZERO:
			out = a if not has else out.merge(a)
			has = true
	return out

## Emissive unshaded-ish material helper.
static func glow(color: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

static func mat(color: Color, metal := 0.0, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	return m

static func mesh(m: Mesh, material: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot
	return mi

static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

static func cyl(r: float, h: float, top := -1.0) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = r if top < 0.0 else top
	c.height = h
	c.radial_segments = 20
	return c

static func sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s

static func torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 24
	t.ring_segments = 10
	return t

## Clickable sphere area carrying metadata.
static func area(radius: float, meta_key: String, meta_val: Variant, offset := Vector3.ZERO) -> Area3D:
	var a := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = radius
	cs.shape = sh
	cs.position = offset
	a.add_child(cs)
	a.set_meta(meta_key, meta_val)
	a.input_ray_pickable = true
	return a
