extends Item

func _init() -> void:
	item_id = "adrenaline"
	display_name = "Adrenaline"
	description = "Steal an item from another player and use it immediately."
	rarity = Rarity.RARE
	target_kind = "steal"

func build_prop() -> Node3D:
	var n := Node3D.new()
	var glass := Models.mat(Color(0.8, 0.9, 1.0), 0.0, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.5
	n.add_child(Models.mesh(Models.cyl(0.012, 0.08), glass, Vector3(0, 0.014, 0), Vector3(90, 0, 0)))
	n.add_child(Models.mesh(Models.cyl(0.009, 0.06), Models.glow(Color(1.0, 0.85, 0.1), 1.5), Vector3(0, 0.014, 0), Vector3(90, 0, 0)))
	n.add_child(Models.mesh(Models.cyl(0.0015, 0.04), Models.mat(Color(0.8, 0.8, 0.8), 1.0, 0.2), Vector3(0, 0.014, -0.06), Vector3(90, 0, 0)))
	return n

func stealable(gm: GameManager, user: Player) -> Array:
	var out := []
	for p in gm.alive_players():
		if p == user:
			continue
		for it in p.items():
			if it.item_id != "adrenaline":
				out.append(it)
	return out

func block_reason(gm: GameManager, user: Player) -> String:
	return "" if not stealable(gm, user).is_empty() else "Nobody has anything to steal."

func use_anim() -> void:
	var tw := create_tween()
	tw.tween_property(_prop, "rotation:x", -1.2, 0.15)
	tw.tween_property(_prop, "scale", Vector3(1.2, 1.2, 0.6), 0.15)
	await tw.finished

func apply(gm: GameManager, user: Player, target: Variant) -> void:
	var stolen: Item = target
	var victim: Player = stolen.holder
	victim.remove_item(stolen)
	gm.log_event("%s injects adrenaline and steals %s from %s!" % [user.display_name, stolen.display_name, victim.display_name])
	Sfx.play("item", 1.4)
	var tw := create_tween()
	tw.tween_property(stolen, "global_position", user.slot_world(0) + Vector3(0, 0.15, 0), 0.45).set_trans(Tween.TRANS_CUBIC)
	await tw.finished
	stolen.holder = user
	if stolen.block_reason(gm, user) != "":
		gm.log_event("...but it's useless right now.")
		stolen.queue_free()
		return
	var t2: Variant = null
	if stolen.target_kind == "player":
		t2 = await gm.choose_item_target(user, stolen)
	await gm.perform_item(user, stolen, t2, false)
