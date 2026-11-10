extends Item

func _init() -> void:
	item_id = "saw"
	display_name = "Hand Saw"
	description = "Saw off the barrel: next shot deals double damage if live."

func build_prop() -> Node3D:
	var n := Models.spawn("handsaw_wood", 0.26, "z")
	n.rotation_degrees = Vector3(0, 60, 90)
	n.position.y = 0.005
	return n

func block_reason(gm: GameManager, _user: Player) -> String:
	return "" if not gm.saw_active else "The barrel is already sawed off."

func use_anim() -> void:
	var tw := create_tween().set_loops(3)
	tw.tween_property(_prop, "position:x", 0.05, 0.08)
	tw.tween_property(_prop, "position:x", -0.05, 0.08)
	await tw.finished

func apply(gm: GameManager, user: Player, _t: Variant) -> void:
	gm.saw_active = true
	gm.gun.set_sawed(true)
	gm.log_event("%s saws off the barrel. Next live shot does double damage." % user.display_name)
	await gm.wait(0.4)
