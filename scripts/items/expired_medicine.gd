extends Item

func _init() -> void:
	item_id = "medicine"
	display_name = "Expired Medicine"
	description = "50%: gain 2 lives. 50%: lose 1 life."
	rarity = Rarity.UNCOMMON

func build_prop() -> Node3D:
	var n := Node3D.new()
	var amber := Models.mat(Color(0.75, 0.38, 0.08), 0.0, 0.2)
	amber.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	amber.albedo_color.a = 0.85
	n.add_child(Models.mesh(Models.cyl(0.025, 0.07), amber, Vector3(0, 0.035, 0)))
	n.add_child(Models.mesh(Models.cyl(0.027, 0.02), Models.mat(Color(0.9, 0.9, 0.88)), Vector3(0, 0.08, 0)))
	n.add_child(Models.mesh(Models.cyl(0.0255, 0.03), Models.mat(Color(0.95, 0.93, 0.85)), Vector3(0, 0.035, 0)))
	return n

func apply(gm: GameManager, user: Player, _t: Variant) -> void:
	if randf() < 0.5:
		gm.heal(user, 2, Player.BASE_MAX_LIVES)
		gm.log_event("%s takes expired medicine... +2 lives!" % user.display_name)
	else:
		gm.log_event("%s takes expired medicine... it was bad (-1 life)." % user.display_name)
		await gm.damage(user, 1)
	await gm.wait(0.4)
