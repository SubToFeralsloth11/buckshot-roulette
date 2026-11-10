class_name GameManager
extends Node3D
## Game flow state machine: BOTTLE_SPIN -> ROUND_SETUP -> TURN -> ROUND_END -> GAME_OVER.

signal turn_started(player: Player)
signal shot_fired(shooter: Player, target: Player, live: bool)
signal item_used(user: Player, item: Item)
signal player_eliminated(player: Player)
signal round_started(round_num: int, live: int, blank: int)
signal human_action(action: Dictionary)

enum State { TITLE, BOTTLE_SPIN, ROUND_SETUP, TURN, ROUND_END, GAME_OVER }

const LIVE_COLOR := Color(0.95, 0.15, 0.12)
const BLANK_COLOR := Color(0.2, 0.45, 1.0)
const ACCENTS := [Color(0.1, 0.9, 0.8), Color(1.0, 0.6, 0.1), Color(0.95, 0.2, 0.75), Color(0.55, 0.95, 0.2)]
const REST_Y := Player.TABLE_Y + 0.035
const MAX_TURNS := 3000

## Settings survive scene reloads (restart / back to title).
static var humans := 1
static var show_title := true
static var autoplay := false

@onready var gun: Gun = $"../Gun"
@onready var bottle: Bottle = $"../Bottle"
@onready var hud: HUD = $"../HUD"
@onready var cam: CameraRig = $"../CameraRig"
@onready var ai: AIController = $"../AIController"

var state := State.TITLE
var players: Array[Player] = []
var shells: Array = []  # [{live: bool, id: int}], index 0 is in the chamber
var direction := 1
var saw_active := false
var current: Player
var viewer: Player
var round_num := 0
var over := false
var turns_taken := 0
var input_mode := ""
var pending_item: Item
var _forced_target := false
var _shell_seq := 0
var _hover: Object
var _drag_start := Vector2.ZERO

func _ready() -> void:
	if "--shots" in OS.get_cmdline_user_args():
		show_title = false
		humans = 0
		_capture_shots.call_deferred()
	if "--autoplay" in OS.get_cmdline_user_args():
		autoplay = true
		show_title = false
		humans = 0
		Engine.time_scale = 8.0
	gun.visible = false
	hud.start_requested.connect(func(h: int):
		humans = h
		show_title = false
		_start())
	hud.self_shoot_pressed.connect(func():
		if input_mode == "shoot":
			_emit({"type": "shoot", "target": current}))
	hud.cancel_pressed.connect(_cancel_mode)
	hud.restart_pressed.connect(func():
		show_title = false
		get_tree().paused = false
		get_tree().reload_current_scene())
	hud.title_pressed.connect(func():
		show_title = true
		get_tree().paused = false
		get_tree().reload_current_scene())
	cam.set_home(Vector3(0, 2.6, 3.4), Vector3(0, 0.8, 0), 0.0)
	if show_title:
		hud.show_title()
		cam.orbit = true
	else:
		_start.call_deferred()

func _start() -> void:
	hud.hide_title()
	cam.orbit = false
	Sfx.start_breathing()
	var bot_n := 1
	for i in 4:
		var human := i < humans
		var pname := ""
		if human:
			pname = "You" if humans == 1 else "Player %d" % (i + 1)
		else:
			bot_n += 1
			pname = "Bot %d" % (i + 1) if humans != 1 else "Bot %d" % bot_n
		var p := Player.new()
		p.setup(i, pname, ACCENTS[i], human, i * PI * 0.5)
		add_child(p)
		players.append(p)
	hud.set_players(players)
	if humans >= 1:
		await set_viewer(players[0], 0.0)
	else:
		cam.set_home(Vector3(0, 2.3, 2.4), Vector3(0, 0.8, 0), 0.8)
	_run()

# ---------------------------------------------------------------- flow

func _run() -> void:
	state = State.BOTTLE_SPIN
	current = await _bottle_phase()
	while not over:
		await _round_setup()
		while not over and not shells.is_empty():
			current = await _take_turn(current)
			turns_taken += 1
			if turns_taken > MAX_TURNS:
				push_error("Turn limit hit, ending game")
				over = true
	_game_over()

func _bottle_phase() -> Player:
	bottle.visible = true
	bottle.position = Vector3(0, Player.TABLE_Y, 0)
	await wait(0.8)
	var spinner: Player = players.pick_random()
	spinner.set_highlight(true)
	log_event("%s spins the bottle." % spinner.display_name)
	await hud.callout("%s SPINS THE BOTTLE" % spinner.display_name.to_upper(), spinner.accent, 1.4)
	var strength := randf_range(0.3, 1.0)
	if spinner.is_human:
		await set_viewer(spinner)
		_set_mode("bottle")
		hud.set_hint("Click and drag across the bottle to spin it")
		var act: Dictionary = await human_action
		strength = act.strength
		hud.set_hint("")
	else:
		await wait(0.8)
	await spinner.reach(true, bottle.global_position + Vector3(0, 0.08, 0), 0.35)
	var flick := spinner.create_tween()
	flick.tween_property(spinner.hand_r, "global_position", bottle.global_position + spinner.global_basis.x * 0.25 + Vector3(0, 0.1, 0), 0.15)
	await flick.finished
	spinner.rest_hands()
	spinner.set_highlight(false)
	await bottle.spin(strength)
	var dir := bottle.pointing_dir()
	var best: Player = players[0]
	var best_dot := -2.0
	for p in players:
		var d := Vector3(p.position.x, 0, p.position.z).normalized().dot(dir)
		if d > best_dot:
			best_dot = d
			best = p
	best.set_highlight(true)
	log_event("The bottle points at %s. They go first." % best.display_name)
	await hud.callout("%s GOES FIRST" % best.display_name.to_upper(), best.accent, 1.6)
	best.set_highlight(false)
	await bottle.slide_off(-dir)
	return best

func _round_setup() -> void:
	if round_num > 0:
		state = State.ROUND_END
		log_event("The gun is empty.")
		await hud.callout("RELOADING", Color(0.9, 0.85, 0.75), 1.0)
	state = State.ROUND_SETUP
	round_num += 1
	var n := randi_range(2, 8)
	var lives := clampi(int(round(n / 2.0)) + randi_range(-1, 1), 1, n - 1)
	shells.clear()
	for i in n:
		_shell_seq += 1
		shells.append({"live": i < lives, "id": _shell_seq})
	shells.shuffle()
	for p in players:
		p.known.clear()
	saw_active = false
	gun.set_sawed(false)
	hud.set_known(viewer, shells)
	await _gun_reveal(lives, n - lives)
	round_started.emit(round_num, lives, n - lives)
	hud.set_shells(lives, n - lives)
	log_event("Round %d: %d live, %d blank." % [round_num, lives, n - lives])
	await _deal_items()

func _gun_reveal(lives: int, blanks: int) -> void:
	var toward := cam.home_xf.origin
	toward.y = 0.0
	toward = toward.normalized()
	var right := Vector3.UP.cross(toward).normalized()
	gun.visible = true
	gun.position = Vector3(0, 0.2, 0)
	gun.rotation = Vector3.ZERO
	gun.look_at(gun.position - right, Vector3.UP)
	cam.focus(toward * 1.05 + Vector3(0, 1.25, 0), Vector3(0, 1.0, 0), 0.9)
	Sfx.play("rack", 0.7)
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(gun, "position", Vector3(0, 1.08, 0), 1.0)
	tw.parallel().tween_property(gun, "rotation:y", gun.rotation.y + TAU, 1.0)
	await tw.finished
	var n := lives + blanks
	var row: Array[Node3D] = []
	var slots: Array[Vector3] = []
	for i in n:
		var s := Gun.make_shell(i < lives)
		add_child(s)
		var pos := Vector3(0, 0.93, 0) + toward * 0.3 + right * ((i - (n - 1) * 0.5) * 0.075)
		s.position = pos
		s.scale = Vector3.ONE * 0.01
		slots.append(pos)
		row.append(s)
		var pop := create_tween()
		pop.tween_interval(i * 0.08)
		pop.tween_callback(Sfx.play.bind("click", 1.6, -10.0))
		pop.tween_property(s, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await wait(0.3 + n * 0.08)
	await hud.callout("%d LIVE, %d BLANK" % [lives, blanks], Color(0.95, 0.9, 0.8), 1.8, true)
	for pass_i in 2:
		var order := slots.duplicate()
		order.shuffle()
		var sh := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		for i in n:
			var lift := Vector3(0, 0.06 if i % 2 == 0 else -0.02, 0)
			sh.tween_property(row[i], "position", order[i] + lift, 0.35)
		await sh.finished
	for i in n:
		var t := create_tween()
		t.tween_property(row[i], "global_position", gun.chamber_world(), 0.12)
		t.parallel().tween_property(row[i], "scale", Vector3.ONE * 0.2, 0.12)
		t.tween_callback(row[i].queue_free)
		Sfx.play("click", 1.2, -8.0)
		await wait(0.09)
	await wait(0.15)
	gun.rack()
	await wait(0.3)
	cam.go_home(0.8)
	await _rest_gun(current, 0.7)

func _deal_items() -> void:
	var alive := alive_players()
	for p in alive:
		_deal_box(p)
	await wait(2.6)

func _deal_box(p: Player) -> void:
	var box := Models.spawn("cardboard_box_01", 0.22)
	add_child(box)
	var base := p.local_to_world(Vector3(0.55, Player.TABLE_Y, -0.45))
	box.global_position = base + Vector3(0, 0.6, 0)
	box.rotation.y = p.rotation.y
	var tw := create_tween()
	tw.tween_property(box, "global_position", base, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(Sfx.play.bind("thud", 1.0, -6.0))
	tw.tween_property(box, "rotation:z", 0.12, 0.08)
	tw.tween_property(box, "rotation:z", -0.12, 0.08)
	tw.tween_property(box, "rotation:z", 0.0, 0.08)
	await tw.finished
	var count := randi_range(2, 5)
	for k in count:
		var slot := p.free_slot()
		if slot < 0:
			break
		var it := ItemDB.create(ItemDB.random_id())
		it.holder = p
		p.inventory[slot] = it
		add_child(it)
		it.global_position = base + Vector3(0, 0.12, 0)
		it.rotation.y = p.rotation.y
		it.scale = Vector3.ONE * 0.3
		var target := p.slot_world(slot)
		var mid := (it.global_position + target) * 0.5 + Vector3(0, 0.25, 0)
		var start := it.global_position
		var fly := func(t: float) -> void:
			it.global_position = start.lerp(mid, t).lerp(mid.lerp(target, t), t)
		var itw := create_tween()
		itw.tween_method(fly, 0.0, 1.0, 0.4).set_trans(Tween.TRANS_SINE)
		itw.parallel().tween_property(it, "scale", Vector3.ONE, 0.4)
		Sfx.play("item", 0.8 + k * 0.1, -10.0)
		await wait(0.18)
	var out := create_tween()
	out.tween_interval(0.4)
	out.tween_property(box, "scale", Vector3.ONE * 0.01, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	out.tween_callback(box.queue_free)
	if p == viewer:
		hud.refresh()

func _take_turn(p: Player) -> Player:
	if p.eliminated:
		return next_alive(p)
	if p.cuffed:
		p.cuffed = false
		log_event("%s is cuffed and skips a turn." % p.display_name)
		await hud.callout("%s SKIPS (CUFFED)" % p.display_name.to_upper(), p.accent, 1.2)
		return next_alive(p)
	state = State.TURN
	current = p
	if p.is_human:
		await set_viewer(p)
	turn_started.emit(p)
	hud.set_turn(p)
	p.set_highlight(true)
	await _rest_gun(p, 0.45)
	while not over:
		if shells.is_empty():
			p.set_highlight(false)
			await _round_setup()
			p.set_highlight(true)
			continue
		var act: Dictionary
		if p.is_human:
			act = await _human_choose(p)
		else:
			act = await ai.choose_action(self, p)
		if act.type == "item":
			await perform_item(p, act.item, act.get("target"), true)
			if p.eliminated:
				return next_alive(p)
			continue
		var target: Player = act.target
		var live := await shoot(p, target)
		if over:
			break
		if target == p and not live and not p.eliminated:
			log_event("Blank. %s keeps the turn." % p.display_name)
			if shells.is_empty():
				break
			continue
		p.set_highlight(false)
		return next_alive(p)
	p.set_highlight(false)
	return p

func _human_choose(p: Player) -> Dictionary:
	_set_mode("turn")
	hud.set_hint("Click an item to use it, or click the gun to shoot.")
	var act: Dictionary = await human_action
	_set_mode("")
	hud.set_hint("")
	return act

func _game_over() -> void:
	state = State.GAME_OVER
	_set_mode("")
	var alive := alive_players()
	var winner: Player = alive[0] if not alive.is_empty() else null
	var text := "NOBODY WINS"
	var won := false
	if winner:
		won = winner.is_human and humans == 1
		text = "YOU WIN" if won else ("%s WINS" % winner.display_name.to_upper())
		if humans == 1 and not winner.is_human:
			text = "YOU LOSE\n%s wins" % winner.display_name
		log_event("%s is the last one standing." % winner.display_name)
		winner.set_highlight(true)
	if autoplay:
		print("AUTOPLAY RESULT: winner=%s rounds=%d turns=%d" % [winner.display_name if winner else "none", round_num, turns_taken])
		get_tree().quit(0 if winner else 1)
		return
	await wait(1.5)
	hud.show_game_over(text, won or humans != 1)

# ---------------------------------------------------------------- actions

func shoot(shooter: Player, target: Player) -> bool:
	var shell: Dictionary = shells.pop_front()
	var live: bool = shell.live
	var self_shot := target == shooter
	log_event("%s aims at %s..." % [shooter.display_name, "themselves" if self_shot else target.display_name])
	# Pick up the gun.
	await shooter.hands_to(gun.grip_world(false), gun.grip_world(true), 0.35)
	var hold := shooter.local_to_world(Vector3(0, 1.08, -0.82 if self_shot else -0.62))
	var aim_at := target.mask_global()
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var aim_xf := Transform3D(Basis.looking_at(aim_at - hold, Vector3.UP), hold)
	tw.tween_property(gun, "global_transform", aim_xf, 0.55)
	await tw.finished
	_hands_on_gun(shooter, 0.15)
	if viewer == null or (viewer != shooter):
		cam.focus_on(shooter.mask_global().lerp(aim_at, 0.5), 0.6)
	await wait(0.9 if target.is_human else 0.6)
	var dmg := 2 if (saw_active and live) else 1
	saw_active = false
	await gun.fire(live)
	shot_fired.emit(shooter, target, live)
	for p in players:
		p.known.erase(shell.id)
	if live:
		cam.shake(0.8 if target == viewer else 0.45)
		target.flinch()
		log_event("BANG. %s loses %d %s." % [target.display_name, dmg, "life" if dmg == 1 else "lives"])
		await damage(target, dmg)
	else:
		log_event("*click* It was a blank.")
		if target == viewer:
			hud.callout("BLANK", BLANK_COLOR, 0.8)
	hud.set_shells(live_count(), blank_count())
	hud.set_known(viewer, shells)
	await wait(0.3)
	await gun.eject(live)
	cam.go_home(0.6)
	if not shooter.eliminated:
		shooter.rest_hands()
	await _rest_gun(next_alive(shooter) if not (self_shot and not live) else shooter, 0.5)
	return live

func _hands_on_gun(p: Player, dur: float) -> void:
	p.hands_to(gun.grip_world(false), gun.grip_world(true), dur)

func _rest_gun(toward: Player, dur: float) -> void:
	var to := Vector3.ZERO if toward == null else toward.global_position
	var rest_pos := Vector3(0, REST_Y, 0)
	var flat := to - rest_pos
	flat.y = 0.0
	if flat.length() < 0.01:
		flat = Vector3(0, 0, 1)
	# Lie across the table, muzzle turned 90 degrees from the next player.
	var muzzle_dir := Vector3.UP.cross(flat).normalized()
	var xf := Transform3D(Basis.looking_at(muzzle_dir, Vector3.UP), rest_pos)
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(gun, "global_transform", xf, dur)
	await tw.finished

func perform_item(user: Player, item: Item, target: Variant, from_inventory: bool) -> void:
	if from_inventory:
		user.remove_item(item)
	item.set_highlight(false)
	item_used.emit(user, item)
	await user.reach(true, item.global_position + Vector3(0, 0.05, 0), 0.3)
	var up := user.local_to_world(Vector3(0.1, 1.05, -0.6))
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "global_position", up, 0.35)
	tw.tween_property(user.hand_r, "global_position", up + Vector3(0, -0.05, 0.05), 0.35)
	await tw.finished
	Sfx.play("item")
	await item.use_anim()
	await item.apply(self, user, target)
	if is_instance_valid(item):
		var out := create_tween()
		out.tween_property(item, "scale", Vector3.ONE * 0.01, 0.2)
		out.tween_callback(item.queue_free)
	if not user.eliminated:
		await user.rest_hands(0.3)
	hud.refresh()

func choose_item_target(user: Player, item: Item) -> Variant:
	if user.is_human:
		pending_item = item
		_forced_target = true
		_set_mode("item_target")
		hud.set_hint("Choose a target for the %s." % item.display_name)
		var act: Dictionary = await human_action
		_forced_target = false
		_set_mode("")
		hud.set_hint("")
		return act.target
	return ai.pick_item_target(self, user, item)

func damage(p: Player, n: int) -> void:
	p.set_lives(p.lives - n)
	Sfx.play("hurt")
	hud.refresh()
	if p.lives <= 0 and not p.eliminated:
		log_event("%s has been eliminated." % p.display_name)
		player_eliminated.emit(p)
		hud.callout("%s ELIMINATED" % p.display_name.to_upper(), p.accent, 1.4)
		if alive_players().size() - 1 <= 1:
			over = true
		await p.eliminate()
		hud.refresh()

func heal(p: Player, n: int, cap: int) -> void:
	p.set_lives(maxi(p.lives, mini(cap, p.lives + n)))
	Sfx.play("heal")
	hud.refresh()

func learn(p: Player, idx: int) -> void:
	p.known[shells[idx].id] = shells[idx].live
	if p == viewer:
		hud.set_known(viewer, shells)

func private_reveal(user: Player, text: String, live: bool, neutral := false) -> void:
	if user.is_human and user == viewer:
		hud.private_reveal(text, Color(0.85, 0.85, 0.85) if neutral else (LIVE_COLOR if live else BLANK_COLOR))
	else:
		log_event("%s learns something..." % user.display_name)

func invert_current(user: Player) -> void:
	var s: Dictionary = shells[0]
	s.live = not s.live
	for p in players:
		p.known.erase(s.id)
	user.known[s.id] = s.live
	hud.set_shells(live_count(), blank_count())
	hud.set_known(viewer, shells)

func eject_current() -> bool:
	var s: Dictionary = shells.pop_front()
	for p in players:
		p.known.erase(s.id)
	await gun.eject(s.live)
	hud.set_shells(live_count(), blank_count())
	hud.set_known(viewer, shells)
	return s.live

# ---------------------------------------------------------------- helpers

func alive_players() -> Array:
	return players.filter(func(p): return not p.eliminated)

func next_alive(p: Player) -> Player:
	var idx := p.index
	for i in 4:
		idx = posmod(idx + direction, 4)
		if not players[idx].eliminated:
			return players[idx]
	return p

func live_count() -> int:
	return shells.filter(func(s): return s.live).size()

func blank_count() -> int:
	return shells.size() - live_count()

## Probability that the current shell is live, from `p`'s point of view.
func live_probability(p: Player) -> float:
	if shells.is_empty():
		return 0.0
	if p.known.has(shells[0].id):
		return 1.0 if p.known[shells[0].id] else 0.0
	var unknown_live := live_count()
	var unknown_n := shells.size()
	for i in range(1, shells.size()):
		if p.known.has(shells[i].id):
			unknown_n -= 1
			if p.known[shells[i].id]:
				unknown_live -= 1
	return float(unknown_live) / maxf(1.0, unknown_n)

func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func log_event(msg: String) -> void:
	if autoplay:
		print("  ", msg)
	hud.add_log(msg)

static func ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
	return "%dth" % n

func set_viewer(p: Player, dur := 0.9) -> void:
	if viewer == p:
		return
	if viewer and not viewer.eliminated:
		viewer.mask_pivot.visible = true
	var hotseat := viewer != null
	viewer = p
	p.mask_pivot.visible = false
	var d := Vector3(p.position.x, 0, p.position.z).normalized()
	cam.set_home(d * 1.72 + Vector3(0, 1.42, 0), Vector3(0, Player.TABLE_Y, 0) - d * 0.15, dur)
	hud.set_known(viewer, shells)
	hud.refresh()
	if hotseat:
		await hud.callout("%s, YOUR TURN" % p.display_name.to_upper(), p.accent, 1.2)
	elif dur > 0.0:
		await wait(dur)

# ---------------------------------------------------------------- input

func _emit(action: Dictionary) -> void:
	_set_mode("")
	human_action.emit(action)

func _set_mode(m: String) -> void:
	input_mode = m
	for p in players:
		p.set_highlight(p == current and m != "" and m != "bottle" and state == State.TURN)
		for it in p.items():
			it.set_highlight(false)
	hud.show_shoot_bar(m == "shoot", m in ["shoot", "steal"] or (m == "item_target" and not _forced_target))
	match m:
		"shoot":
			hud.set_hint("Click a mask to shoot them, or shoot yourself. Esc / right-click cancels.")
			for p in alive_players():
				p.set_highlight(true)
		"item_target":
			for p in pending_item.valid_targets(self, current):
				p.set_highlight(true)
		"steal":
			hud.set_hint("Click an item on another player's side of the table to steal it.")
			for it in pending_item.stealable(self, current):
				it.set_highlight(true)

func _cancel_mode() -> void:
	if input_mode in ["shoot", "steal"] or (input_mode == "item_target" and not _forced_target):
		_set_mode("turn")
		hud.set_hint("Click an item to use it, or click the gun to shoot.")

func _pick(screen: Vector2) -> Object:
	var c := cam.cam
	var from := c.project_ray_origin(screen)
	var q := PhysicsRayQueryParameters3D.create(from, from + c.project_ray_normal(screen) * 20.0)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var a: Object = hit.collider
	for k in ["item", "player", "gun", "bottle"]:
		if a.has_meta(k):
			return a.get_meta(k)
	return null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if input_mode in ["shoot", "steal"] or (input_mode == "item_target" and not _forced_target):
			_cancel_mode()
		elif state != State.TITLE and state != State.GAME_OVER:
			hud.toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var o := _pick(event.position)
		_hover = o
		if o is Item and is_instance_valid(o):
			var extra := ""
			if o.holder != current or input_mode == "":
				extra = "\n(%s's)" % o.holder.display_name if o.holder else ""
			hud.show_tooltip(o.tooltip() + extra, event.position)
		elif o is Player and input_mode in ["shoot", "item_target"]:
			hud.show_tooltip("%s  -  %d lives" % [o.display_name, o.lives], event.position)
		elif o is Gun and input_mode == "turn":
			hud.show_tooltip("Pick up the gun and shoot", event.position)
		else:
			hud.hide_tooltip()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_mode()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if input_mode == "bottle":
			if event.pressed:
				_drag_start = event.position
			else:
				var s := clampf(event.position.distance_to(_drag_start) / 500.0, 0.0, 1.0)
				_emit({"strength": maxf(s, 0.25)})
			return
		if not event.pressed:
			return
		var o := _pick(event.position)
		match input_mode:
			"turn":
				if o is Item and o.holder == current:
					var reason: String = o.block_reason(self, current)
					if reason != "":
						hud.flash_hint(reason)
					elif o.target_kind == "":
						_emit({"type": "item", "item": o})
					else:
						pending_item = o
						_set_mode("item_target" if o.target_kind == "player" else "steal")
						if o.target_kind == "player":
							hud.set_hint("Choose who to use the %s on." % o.display_name)
				elif o is Gun:
					_set_mode("shoot")
			"shoot":
				if o is Player and not o.eliminated:
					_emit({"type": "shoot", "target": o})
			"item_target":
				if o is Player and o in pending_item.valid_targets(self, current):
					_emit({"type": "item", "item": pending_item, "target": o})
			"steal":
				if o is Item and o in pending_item.stealable(self, current):
					_emit({"type": "item", "item": pending_item, "target": o})

## Debug: `-- --shots` saves screenshots to user://shots while bots play.
func _capture_shots() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	for t in [2.0, 6.0, 11.0, 16.0, 22.0, 30.0, 40.0]:
		await get_tree().create_timer(t - (Time.get_ticks_msec() / 1000.0)).timeout
		get_viewport().get_texture().get_image().save_png("user://shots/shot_%02d.png" % int(t))
	get_tree().quit()
