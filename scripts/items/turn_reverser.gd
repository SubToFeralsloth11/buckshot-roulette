extends Item

func _init() -> void:
	item_id = "reverser"
	display_name = "Turn Reverser"
	description = "Reverse the turn order."
	rarity = Rarity.RARE

func build_prop() -> Node3D:
	var n := Node3D.new()
	n.add_child(Models.mesh(Models.cyl(0.04, 0.015), Models.mat(Color(0.2, 0.18, 0.15), 0.8, 0.3), Vector3(0, 0.008, 0)))
	var arrow := Models.mesh(Models.torus(0.022, 0.03), Models.glow(Color(0.9, 0.5, 1.0), 2.5), Vector3(0, 0.018, 0))
	n.add_child(arrow)
	n.add_child(Models.mesh(Models.box(Vector3(0.016, 0.006, 0.016)), Models.glow(Color(0.9, 0.5, 1.0), 2.5), Vector3(0.026, 0.02, 0), Vector3(0, 45, 0)))
	return n

func use_anim() -> void:
	var tw := create_tween()
	tw.tween_property(_prop, "rotation:y", -TAU * 2.0, 0.6).set_trans(Tween.TRANS_CUBIC)
	await tw.finished

func apply(gm: GameManager, user: Player, _t: Variant) -> void:
	gm.direction = -gm.direction
	gm.log_event("%s reverses the turn order." % user.display_name)
	gm.hud.callout("TURN ORDER REVERSED", Color(0.9, 0.5, 1.0), 1.0)
	await gm.wait(0.5)
