class_name Player
extends Node3D
## A seat at the table: floating gas mask, gloved hands, lives, inventory.

signal lives_changed(player: Player)

const MAX_ITEMS := 8
const BASE_MAX_LIVES := 3
const HARD_MAX_LIVES := 4
const SEAT_RADIUS := 1.55
const TABLE_Y := 0.81

var index := 0
var display_name := ""
var accent := Color.WHITE
var is_human := false
var lives := 3
var eliminated := false
var cuffed := false
var inventory: Array = []  # Item or null per slot
var known := {}            # shell id -> bool (live) this player has learned

var mask_pivot: Node3D
var hand_l: Node3D
var hand_r: Node3D
var hand_rest_l := Vector3(-0.3, TABLE_Y + 0.12, -0.62)
var hand_rest_r := Vector3(0.3, TABLE_Y + 0.12, -0.62)
var _eye_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _life_mats: Array = []
var _life_nodes: Array = []
var _t := 0.0
var _phase := 0.0
var _hands_busy := false
var _highlight := false
var _mask_light: OmniLight3D

func setup(i: int, pname: String, color: Color, human: bool, angle: float) -> void:
	index = i
	display_name = pname
	accent = color
	is_human = human
	inventory.resize(MAX_ITEMS)
	position = Vector3(sin(angle), 0.0, cos(angle)) * SEAT_RADIUS
	_phase = randf() * TAU
	_build()

func _ready() -> void:
	look_at(Vector3(0, position.y, 0), Vector3.UP)

func _build() -> void:
	mask_pivot = Node3D.new()
	mask_pivot.position = Vector3(0, 1.3, 0)
	add_child(mask_pivot)
	var mask := Models.spawn("old_gas_mask", 1.2, "y")
	mask.rotation_degrees.y = 180.0  # model faces +Z, seat faces -Z
	mask.position = Vector3(0, -1.09, 0)  # eyes at pivot origin
	mask_pivot.add_child(mask)
	# Glowing lens eyes.
	_eye_mat = Models.glow(accent.lerp(Color.WHITE, 0.3), 1.2)
	for x in [-0.045, 0.045]:
		var eye := Models.mesh(Models.cyl(0.024, 0.01), _eye_mat, Vector3(x, 1.09, 0.062), Vector3(90, 0, 0))
		mask.add_child(eye)
	# Accent strap ring around the head and a coloured band on the filter.
	_ring_mat = Models.glow(accent.darkened(0.65), 0.15)
	var strap := Models.mesh(Models.torus(0.085, 0.1), _ring_mat, Vector3(0, 1.1, -0.01), Vector3(90, 0, 0))
	strap.scale = Vector3(1.0, 1.0, 1.25)
	mask.add_child(strap)
	var band := Models.mesh(Models.cyl(0.075, 0.03), _ring_mat, Vector3(0, 0.17, 0))
	mask.add_child(band)
	_mask_light = OmniLight3D.new()
	_mask_light.light_color = Color(1.0, 0.85, 0.7).lerp(accent, 0.25)
	_mask_light.light_energy = 1.2
	_mask_light.omni_range = 0.6
	_mask_light.position = Vector3(0, 0.05, -0.3)
	mask_pivot.add_child(_mask_light)
	# Lives lights above the mask.
	for n in HARD_MAX_LIVES:
		var m := Models.glow(Color(1.0, 0.25, 0.2), 1.5)
		var s := Models.mesh(Models.sphere(0.018), m, Vector3((n - 1.5) * 0.06, 0.19, 0))
		mask_pivot.add_child(s)
		_life_mats.append(m)
		_life_nodes.append(s)
	var a := Models.area(0.2, "player", self, Vector3(0, -0.05, 0))
	mask_pivot.add_child(a)
	hand_l = _make_hand(false)
	hand_r = _make_hand(true)
	hand_l.position = hand_rest_l
	hand_r.position = hand_rest_r
	add_child(hand_l)
	add_child(hand_r)
	set_lives(lives)

func _make_hand(right: bool) -> Node3D:
	var h := Node3D.new()
	var leather := Models.mat(Color(0.12, 0.09, 0.07), 0.0, 0.55)
	var cuff := Models.mat(accent.darkened(0.55), 0.0, 0.6)
	var g := Node3D.new()
	g.rotation_degrees = Vector3(0, 0, -12.0 if right else 12.0)
	h.add_child(g)
	g.add_child(Models.mesh(Models.box(Vector3(0.085, 0.03, 0.09)), leather))
	g.add_child(Models.mesh(Models.cyl(0.045, 0.05), cuff, Vector3(0, 0, 0.065), Vector3(90, 0, 0)))
	for f in 4:
		var cap := CapsuleMesh.new()
		cap.radius = 0.0105
		cap.height = 0.07 - absf(f - 1.5) * 0.008
		var finger := Models.mesh(cap, leather, Vector3(-0.031 + f * 0.0205, -0.006, -0.072), Vector3(-80, 0, 0))
		g.add_child(finger)
	var tc := CapsuleMesh.new()
	tc.radius = 0.012
	tc.height = 0.06
	var sx := -1.0 if right else 1.0
	g.add_child(Models.mesh(tc, leather, Vector3(0.05 * sx, -0.004, -0.015), Vector3(-60, 0, 50 * sx)))
	return h

func _process(delta: float) -> void:
	_t += delta
	if eliminated:
		return
	var bob := sin(_t * 1.3 + _phase) * 0.025
	mask_pivot.position.y = 1.3 + bob
	mask_pivot.rotation.z = sin(_t * 0.7 + _phase) * 0.06
	mask_pivot.rotation.y = sin(_t * 0.5 + _phase * 2.0) * 0.08
	var glow := 1.2 + sin(_t * 1.3 + _phase) * 0.3
	if _highlight:
		glow = 3.0 + sin(_t * 8.0) * 1.0
	_eye_mat.emission_energy_multiplier = glow
	if not _hands_busy:
		hand_l.position = hand_rest_l + Vector3(0, sin(_t * 1.3 + _phase + 0.5) * 0.012, 0)
		hand_r.position = hand_rest_r + Vector3(0, sin(_t * 1.3 + _phase + 1.1) * 0.012, 0)

func set_highlight(on: bool) -> void:
	_highlight = on
	_ring_mat.emission_energy_multiplier = 1.5 if on else 0.15

func set_lives(n: int) -> void:
	lives = clampi(n, 0, HARD_MAX_LIVES)
	for i in HARD_MAX_LIVES:
		var on := i < lives
		_life_nodes[i].visible = on or i < BASE_MAX_LIVES
		_life_mats[i].emission_energy_multiplier = 1.5 if on else 0.0
		_life_mats[i].albedo_color = Color(1.0, 0.25, 0.2) if on else Color(0.05, 0.03, 0.03)
	lives_changed.emit(self)

func mask_global() -> Vector3:
	return mask_pivot.global_position

func local_to_world(p: Vector3) -> Vector3:
	return global_transform * p

func slot_world(i: int) -> Vector3:
	var row := i / 4
	var col := i % 4
	return local_to_world(Vector3((col - 1.5) * 0.17, TABLE_Y, -0.72 - row * 0.2))

func free_slot() -> int:
	for i in MAX_ITEMS:
		if inventory[i] == null:
			return i
	return -1

func item_count() -> int:
	var c := 0
	for it in inventory:
		if it != null:
			c += 1
	return c

func items() -> Array:
	return inventory.filter(func(it): return it != null)

func has_item(id: String) -> Item:
	for it in inventory:
		if it != null and it.item_id == id:
			return it
	return null

func remove_item(it: Item) -> void:
	var i := inventory.find(it)
	if i >= 0:
		inventory[i] = null

## Moves a hand to a world position (tweened); await it.
func reach(right: bool, world_pos: Vector3, dur := 0.35) -> void:
	_hands_busy = true
	var h := hand_r if right else hand_l
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(h, "global_position", world_pos, dur)
	await tw.finished

func hands_to(l_world: Vector3, r_world: Vector3, dur := 0.35) -> void:
	_hands_busy = true
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(hand_l, "global_position", l_world, dur)
	tw.tween_property(hand_r, "global_position", r_world, dur)
	await tw.finished

func rest_hands(dur := 0.35) -> void:
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(hand_l, "position", hand_rest_l, dur)
	tw.tween_property(hand_r, "position", hand_rest_r, dur)
	await tw.finished
	_hands_busy = false

func flinch() -> void:
	var tw := create_tween()
	tw.tween_property(mask_pivot, "position:z", 0.18, 0.06)
	tw.tween_property(mask_pivot, "position:z", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var tw2 := create_tween()
	tw2.tween_property(_eye_mat, "emission", Color.RED, 0.05)
	tw2.tween_property(_eye_mat, "emission", accent.lerp(Color.WHITE, 0.3), 0.8)

func eliminate() -> void:
	eliminated = true
	_highlight = false
	_ring_mat.emission_energy_multiplier = 0.0
	_mask_light.visible = false
	for it in items():
		it.queue_free()
	inventory.fill(null)
	var tw := create_tween().set_parallel()
	tw.tween_property(_eye_mat, "emission_energy_multiplier", 0.0, 1.2)
	tw.tween_property(_eye_mat, "albedo_color", Color(0.05, 0.05, 0.05), 1.2)
	tw.tween_property(mask_pivot, "rotation", Vector3(0.9, 0.4, 0.6), 1.6).set_delay(0.6)
	tw.tween_property(mask_pivot, "position", Vector3(0, -2.5, 0.6), 1.6).set_delay(0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(hand_l, "position", hand_rest_l + Vector3(0, -2.5, 0.3), 1.2).set_delay(0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(hand_r, "position", hand_rest_r + Vector3(0, -2.5, 0.3), 1.2).set_delay(0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	mask_pivot.visible = false
	hand_l.visible = false
	hand_r.visible = false
