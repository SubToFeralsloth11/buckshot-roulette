extends Item

func _init() -> void:
	item_id = "beer"
	display_name = "Beer"
	description = "Rack the gun: eject the current shell and reveal it."

func build_prop() -> Node3D:
	return Models.spawn("can_rusted", 0.11, "y")

func use_anim() -> void:
	var tw := create_tween()
	tw.tween_property(_prop, "rotation:z", -2.0, 0.3)
	tw.tween_interval(0.3)
	await tw.finished

func apply(gm: GameManager, user: Player, _t: Variant) -> void:
	var live := await gm.eject_current()
	gm.log_event("%s drinks a beer. Ejected a %s shell." % [user.display_name, "LIVE" if live else "BLANK"])
	gm.hud.callout("EJECTED: %s" % ("LIVE" if live else "BLANK"), GameManager.LIVE_COLOR if live else GameManager.BLANK_COLOR, 1.0)
	await gm.wait(0.4)
