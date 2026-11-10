extends Item

func _init() -> void:
	item_id = "magnifier"
	display_name = "Magnifying Glass"
	description = "Peek at the shell in the chamber. Only you see it."

func build_prop() -> Node3D:
	var n := Models.spawn("magnifying_glass_01", 0.16)
	n.rotation_degrees = Vector3(-90, 30, 0)
	n.position.y = 0.012
	return n

func apply(gm: GameManager, user: Player, _t: Variant) -> void:
	var live: bool = gm.shells[0].live
	gm.learn(user, 0)
	gm.private_reveal(user, "The current shell is %s" % ("LIVE" if live else "BLANK"), live)
	gm.log_event("%s inspects the chamber." % user.display_name)
	await gm.wait(0.6)
