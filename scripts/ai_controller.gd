class_name AIController
extends Node
## Bot brain: picks items and a shot target from known shells and odds.

func choose_action(gm: GameManager, p: Player) -> Dictionary:
	await gm.wait(randf_range(0.7, 1.5))
	var cur: Dictionary = gm.shells[0]
	var known: Variant = p.known.get(cur.id)
	var pl := gm.live_probability(p)
	var a := _usable(gm, p)
	# Healing first.
	if a.has("cigarettes") and p.lives < Player.BASE_MAX_LIVES:
		return _item(a.cigarettes)
	if a.has("medkit") and p.lives <= 2:
		return _item(a.medkit)
	if a.has("medicine") and p.lives == 2 and randf() < 0.6:
		return _item(a.medicine)
	# Gather information.
	if known == null:
		if a.has("magnifier"):
			return _item(a.magnifier)
		if a.has("phone") and gm.shells.size() > 1 and randf() < 0.5:
			return _item(a.phone)
		if a.has("adrenaline"):
			var steal := _steal_choice(gm, p, a.adrenaline, true)
			if steal:
				return _item(a.adrenaline, steal)
		if a.has("beer") and pl > 0.3 and pl < 0.7 and gm.shells.size() > 1:
			return _item(a.beer)
	# Turn a known blank into a live to hit someone.
	if known == false and a.has("inverter"):
		return _item(a.inverter)
	var going_live: bool = known == true or (known == null and pl >= 0.65)
	if going_live:
		if a.has("handcuffs") and gm.alive_players().size() > 2:
			return _item(a.handcuffs, pick_item_target(gm, p, a.handcuffs))
		if known == true and a.has("saw"):
			return _item(a.saw)
		if known == true and a.has("adrenaline"):
			var steal2 := _steal_choice(gm, p, a.adrenaline, false)
			if steal2:
				return _item(a.adrenaline, steal2)
	if a.has("reverser") and randf() < 0.35:
		var fwd := gm.next_alive(p)
		gm.direction = -gm.direction
		var back := gm.next_alive(p)
		gm.direction = -gm.direction
		if _danger(fwd) > _danger(back):
			return _item(a.reverser)
	await gm.wait(randf_range(0.3, 0.8))
	# Shoot.
	var self_shot := false
	if known != null:
		self_shot = known == false
	elif pl < 0.5:
		self_shot = randf() < 0.85
	elif is_equal_approx(pl, 0.5):
		self_shot = randf() < 0.4
	if self_shot:
		return {"type": "shoot", "target": p}
	return {"type": "shoot", "target": _shot_target(gm, p)}

func pick_item_target(gm: GameManager, p: Player, item: Item) -> Player:
	var opts: Array = item.valid_targets(gm, p)
	if opts.is_empty():
		return null
	opts.sort_custom(func(x, y): return _danger(x) > _danger(y))
	return opts[0]

func _shot_target(gm: GameManager, p: Player) -> Player:
	var opts: Array = gm.alive_players().filter(func(o): return o != p)
	opts.shuffle()
	# Prefer someone you can finish off, otherwise the most dangerous.
	var dmg := 2 if gm.saw_active else 1
	for o in opts:
		if o.lives <= dmg:
			return o
	opts.sort_custom(func(x, y): return _danger(x) > _danger(y))
	return opts[0]

func _danger(o: Player) -> float:
	return o.lives * 2.0 + o.item_count() * 0.5

func _usable(gm: GameManager, p: Player) -> Dictionary:
	var out := {}
	for it in p.items():
		if not out.has(it.item_id) and it.block_reason(gm, p) == "":
			out[it.item_id] = it
	return out

func _steal_choice(gm: GameManager, p: Player, adr: Item, unknown: bool) -> Item:
	var wanted := ["magnifier", "cigarettes", "medkit", "beer"] if unknown else ["saw", "handcuffs"]
	if p.lives >= Player.BASE_MAX_LIVES:
		wanted.erase("cigarettes")
	for id in wanted:
		for it in adr.stealable(gm, p):
			if it.item_id == id and it.block_reason(gm, p) == "":
				if id == "saw" and gm.saw_active:
					continue
				if id == "handcuffs" and it.valid_targets(gm, p).is_empty():
					continue
				return it
	return null

func _item(it: Item, target: Variant = null) -> Dictionary:
	return {"type": "item", "item": it, "target": target}
