extends Item

func _init() -> void:
	item_id = "handcuffs"
	display_name = "Handcuffs"
	description = "Choose a player: they skip their next turn. Can't stack."
	target_kind = "player"

func build_prop() -> Node3D:
	var n := Node3D.new()
	var steel := Models.mat(Color(0.7, 0.72, 0.75), 1.0, 0.25)
	n.add_child(Models.mesh(Models.torus(0.032, 0.042), steel, Vector3(-0.045, 0.006, 0)))
	n.add_child(Models.mesh(Models.torus(0.032, 0.042), steel, Vector3(0.045, 0.006, 0)))
	n.add_child(Models.mesh(Models.box(Vector3(0.03, 0.008, 0.008)), steel, Vector3(0, 0.006, 0)))
	return n

func valid_targets(gm: GameManager, user: Player) -> Array:
	return gm.alive_players().filter(func(p): return p != user and not p.cuffed)

func block_reason(gm: GameManager, user: Player) -> String:
	return "" if not valid_targets(gm, user).is_empty() else "Everyone is already cuffed."

func apply(gm: GameManager, user: Player, target: Variant) -> void:
	var p: Player = target
	p.cuffed = true
	var cuff := build_prop()
	gm.add_child(cuff)
	cuff.global_position = global_position
	var tw := create_tween()
	tw.tween_property(cuff, "global_position", p.hand_l.global_position.lerp(p.hand_r.global_position, 0.5), 0.5).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.5)
	tw.tween_property(cuff, "scale", Vector3.ONE * 0.01, 0.25)
	tw.tween_callback(cuff.queue_free)
	gm.log_event("%s handcuffs %s." % [user.display_name, p.display_name])
	gm.hud.callout("%s IS CUFFED" % p.display_name.to_upper(), p.accent, 1.0)
	await tw.finished
