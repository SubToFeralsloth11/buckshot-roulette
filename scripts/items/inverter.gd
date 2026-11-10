extends Item

func _init() -> void:
	item_id = "inverter"
	display_name = "Inverter"
	description = "Flip the current shell: live becomes blank and vice versa."
	rarity = Rarity.UNCOMMON

func build_prop() -> Node3D:
	var n := Node3D.new()
	n.add_child(Models.mesh(Models.box(Vector3(0.06, 0.03, 0.1)), Models.mat(Color(0.15, 0.15, 0.17), 0.6, 0.4), Vector3(0, 0.015, 0)))
	n.add_child(Models.mesh(Models.box(Vector3(0.02, 0.006, 0.02)), Models.glow(GameManager.LIVE_COLOR, 3.0), Vector3(0, 0.032, -0.025)))
	n.add_child(Models.mesh(Models.box(Vector3(0.02, 0.006, 0.02)), Models.glow(GameManager.BLANK_COLOR, 3.0), Vector3(0, 0.032, 0.025)))
	return n

func apply(gm: GameManager, user: Player, _t: Variant) -> void:
	gm.invert_current(user)
	gm.log_event("%s uses an Inverter. The current shell is flipped." % user.display_name)
	await gm.wait(0.4)
