extends Item

func _init() -> void:
	item_id = "medkit"
	display_name = "Medkit"
	description = "Heal 1 life. Can go up to 4 lives."
	rarity = Rarity.RARE

func build_prop() -> Node3D:
	var n := Models.spawn("medical_box", 0.13)
	n.rotation_degrees.y = 15
	return n

func block_reason(_gm: GameManager, user: Player) -> String:
	return "" if user.lives < Player.HARD_MAX_LIVES else "Already at 4 lives."

func apply(gm: GameManager, user: Player, _t: Variant) -> void:
	gm.heal(user, 1, Player.HARD_MAX_LIVES)
	gm.log_event("%s patches up with a medkit (+1 life)." % user.display_name)
	await gm.wait(0.5)
