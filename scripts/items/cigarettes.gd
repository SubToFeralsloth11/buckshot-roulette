extends Item

func _init() -> void:
	item_id = "cigarettes"
	display_name = "Cigarettes"
	description = "+1 life (up to the max of 3)."

func build_prop() -> Node3D:
	var n := Models.spawn("cigarette_pack", 0.1)
	n.rotation_degrees = Vector3(-90, 20, 0)
	n.position.y = 0.015
	return n

func block_reason(_gm: GameManager, user: Player) -> String:
	return "" if user.lives < Player.BASE_MAX_LIVES else "Already at full health."

func apply(gm: GameManager, user: Player, _t: Variant) -> void:
	gm.heal(user, 1, Player.BASE_MAX_LIVES)
	gm.log_event("%s smokes a cigarette (+1 life)." % user.display_name)
	await gm.wait(0.5)
