extends Item

func _init() -> void:
	item_id = "phone"
	display_name = "Burner Phone"
	description = "A voice tells you what one upcoming shell is. Only you hear it."
	rarity = Rarity.UNCOMMON

func build_prop() -> Node3D:
	var n := Node3D.new()
	n.add_child(Models.mesh(Models.box(Vector3(0.05, 0.015, 0.1)), Models.mat(Color(0.08, 0.08, 0.09), 0.3, 0.5), Vector3(0, 0.008, 0)))
	n.add_child(Models.mesh(Models.box(Vector3(0.04, 0.002, 0.045)), Models.glow(Color(0.4, 0.9, 0.6), 1.5), Vector3(0, 0.016, -0.02)))
	return n

func apply(gm: GameManager, user: Player, _t: Variant) -> void:
	var n: int = gm.shells.size()
	gm.log_event("%s makes a call." % user.display_name)
	if n <= 1:
		gm.private_reveal(user, "How unfortunate... (only one shell left)", false, true)
		await gm.wait(0.6)
		return
	var idx := randi_range(1, n - 1)
	var live: bool = gm.shells[idx].live
	gm.learn(user, idx)
	gm.private_reveal(user, "%s shell from now is %s" % [GameManager.ordinal(idx + 1), "LIVE" if live else "BLANK"], live)
	await gm.wait(0.6)
