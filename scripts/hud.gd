class_name HUD
extends CanvasLayer
## All 2D UI: post effects, lives, turn, shell counts, intel, log, callouts,
## tooltips, title / pause / game-over screens.

signal start_requested(humans: int)
signal self_shoot_pressed
signal cancel_pressed
signal restart_pressed
signal title_pressed

const FX_SHADER := """
shader_type canvas_item;
uniform float vignette = 0.75;
uniform float grain = 0.035;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	float d = distance(UV, vec2(0.5));
	float v = smoothstep(0.32, 0.85, d) * vignette;
	float n = hash(floor(FRAGCOORD.xy * 0.5) + fract(TIME * 7.13) * 91.7);
	COLOR = vec4(vec3(n * 0.6), clamp(v + n * grain, 0.0, 1.0));
	COLOR.rgb *= (1.0 - v);
}
"""

var _font_color := Color(0.92, 0.88, 0.8)
var _players: Array = []
var _player_rows := {}
var _turn: Label
var _shells_live: Label
var _shells_blank: Label
var _intel: RichTextLabel
var _log: RichTextLabel
var _log_lines: Array[String] = []
var _hint: Label
var _callout: Label
var _private: PanelContainer
var _private_label: Label
var _tooltip: PanelContainer
var _tooltip_label: Label
var _shoot_bar: HBoxContainer
var _self_btn: Button
var _title: Control
var _pause: Control
var _over: Control
var _over_label: Label
var _game_ui: Control
var _callout_tw: Tween
var _private_tw: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fx := ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = FX_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	fx.material = sm
	add_child(fx)

	_game_ui = Control.new()
	_game_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_ui.visible = false
	add_child(_game_ui)

	var pause_btn := _button("II", toggle_pause)
	pause_btn.custom_minimum_size = Vector2(64, 64)
	pause_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE, 16)
	_game_ui.add_child(pause_btn)

	var lives_box := VBoxContainer.new()
	lives_box.name = "Lives"
	lives_box.position = Vector2(24, 20)
	lives_box.add_theme_constant_override("separation", 4)
	_game_ui.add_child(lives_box)

	_turn = _label(30, HORIZONTAL_ALIGNMENT_CENTER)
	_turn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_turn.offset_left = -400
	_turn.offset_right = 400
	_turn.offset_top = 18
	_game_ui.add_child(_turn)

	var shells := VBoxContainer.new()
	shells.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	shells.offset_left = -260
	shells.offset_right = -24
	shells.offset_top = 20
	shells.alignment = BoxContainer.ALIGNMENT_BEGIN
	_game_ui.add_child(shells)
	_shells_live = _label(24, HORIZONTAL_ALIGNMENT_RIGHT)
	_shells_live.add_theme_color_override("font_color", GameManager.LIVE_COLOR)
	_shells_blank = _label(24, HORIZONTAL_ALIGNMENT_RIGHT)
	_shells_blank.add_theme_color_override("font_color", GameManager.BLANK_COLOR.lightened(0.2))
	shells.add_child(_shells_live)
	shells.add_child(_shells_blank)
	_intel = RichTextLabel.new()
	_intel.bbcode_enabled = true
	_intel.fit_content = true
	_intel.custom_minimum_size = Vector2(236, 0)
	_intel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intel.add_theme_font_size_override("normal_font_size", 16)
	shells.add_child(_intel)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_active = false
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_log.offset_top = -190
	_log.offset_bottom = -20
	_log.offset_left = 24
	_log.offset_right = 560
	_log.add_theme_font_size_override("normal_font_size", 15)
	_log.add_theme_color_override("default_color", Color(0.75, 0.72, 0.66))
	_game_ui.add_child(_log)

	_hint = _label(18, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -420
	_hint.offset_right = 420
	_hint.offset_top = -110
	_hint.offset_bottom = -80
	_game_ui.add_child(_hint)

	_shoot_bar = HBoxContainer.new()
	_shoot_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_shoot_bar.offset_left = -200
	_shoot_bar.offset_right = 200
	_shoot_bar.offset_top = -70
	_shoot_bar.offset_bottom = -26
	_shoot_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_shoot_bar.add_theme_constant_override("separation", 16)
	_shoot_bar.visible = false
	_game_ui.add_child(_shoot_bar)
	_self_btn = _button("SHOOT YOURSELF", func(): self_shoot_pressed.emit())
	_shoot_bar.add_child(_self_btn)
	_shoot_bar.add_child(_button("CANCEL", func(): cancel_pressed.emit()))

	_callout = _label(54, HORIZONTAL_ALIGNMENT_CENTER)
	_callout.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_callout.offset_left = -700
	_callout.offset_right = 700
	_callout.offset_top = -170
	_callout.offset_bottom = -60
	_callout.add_theme_constant_override("outline_size", 10)
	_callout.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_callout.modulate.a = 0.0
	add_child(_callout)

	_private = _panel()
	_private.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_private.offset_left = -260
	_private.offset_right = 260
	_private.offset_top = 60
	_private.offset_bottom = 150
	var pv := VBoxContainer.new()
	var ptitle := _label(13, HORIZONTAL_ALIGNMENT_CENTER)
	ptitle.text = "ONLY YOU CAN SEE THIS"
	ptitle.modulate = Color(1, 1, 1, 0.55)
	_private_label = _label(28, HORIZONTAL_ALIGNMENT_CENTER)
	pv.add_child(ptitle)
	pv.add_child(_private_label)
	_private.add_child(pv)
	_private.modulate.a = 0.0
	add_child(_private)

	_tooltip = _panel()
	_tooltip_label = _label(16, HORIZONTAL_ALIGNMENT_LEFT)
	_tooltip.add_child(_tooltip_label)
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tooltip)

	_title = _screen(Color(0, 0, 0, 0.55))
	var tv := _center_box(_title)
	var t1 := _label(84, HORIZONTAL_ALIGNMENT_CENTER)
	t1.text = "BUCKSHOT ROULETTE"
	t1.add_theme_color_override("font_color", Color(0.85, 0.15, 0.1))
	tv.add_child(t1)
	var t2 := _label(18, HORIZONTAL_ALIGNMENT_CENTER)
	t2.text = "four masks. one gun. nobody leaves."
	t2.modulate.a = 0.6
	tv.add_child(t2)
	tv.add_child(_spacer(30))
	tv.add_child(_button("PLAY  (you vs 3 bots)", func(): start_requested.emit(1)))
	tv.add_child(_button("HOT-SEAT  (2 players + 2 bots)", func(): start_requested.emit(2)))
	tv.add_child(_button("HOT-SEAT  (4 players)", func(): start_requested.emit(4)))
	tv.add_child(_button("WATCH  (4 bots)", func(): start_requested.emit(0)))
	if not OS.has_feature("web"):
		tv.add_child(_button("QUIT", func(): get_tree().quit()))
	_title.visible = false

	_pause = _screen(Color(0, 0, 0, 0.7))
	var pvb := _center_box(_pause)
	var pl := _label(60, HORIZONTAL_ALIGNMENT_CENTER)
	pl.text = "PAUSED"
	pvb.add_child(pl)
	pvb.add_child(_spacer(20))
	pvb.add_child(_button("RESUME", toggle_pause))
	pvb.add_child(_button("RESTART", func(): restart_pressed.emit()))
	pvb.add_child(_button("QUIT TO TITLE", func(): title_pressed.emit()))
	_pause.visible = false

	_over = _screen(Color(0, 0, 0, 0.6))
	var ovb := _center_box(_over)
	_over_label = _label(72, HORIZONTAL_ALIGNMENT_CENTER)
	ovb.add_child(_over_label)
	ovb.add_child(_spacer(20))
	ovb.add_child(_button("PLAY AGAIN", func(): restart_pressed.emit()))
	ovb.add_child(_button("QUIT TO TITLE", func(): title_pressed.emit()))
	_over.visible = false

# ---------------------------------------------------------------- widgets

func _label(size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", _font_color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.035, 0.03, 0.9)
	sb.border_color = Color(0.55, 0.45, 0.3, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 48)
	b.add_theme_font_size_override("font_size", 20)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.08, 0.06, 0.05, 0.92)
	n.border_color = Color(0.6, 0.45, 0.25, 0.7)
	n.set_border_width_all(1)
	n.set_corner_radius_all(3)
	var h := n.duplicate()
	h.bg_color = Color(0.35, 0.08, 0.05, 0.95)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", n)
	b.pressed.connect(func():
		Sfx.play("click", 1.4, -6.0)
		cb.call())
	return b

func _screen(bg: Color) -> Control:
	var c := ColorRect.new()
	c.color = bg
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	return c

func _center_box(parent: Control) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	return v

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

# ---------------------------------------------------------------- API

func show_title() -> void:
	_title.visible = true

func hide_title() -> void:
	_title.visible = false
	_game_ui.visible = true

func set_players(players: Array) -> void:
	_players = players
	var box: VBoxContainer = _game_ui.get_node("Lives")
	for p in players:
		var row := _label(20, HORIZONTAL_ALIGNMENT_LEFT)
		box.add_child(row)
		_player_rows[p] = row
		p.lives_changed.connect(func(_p): refresh())
	refresh()

func refresh() -> void:
	for p in _players:
		var row: Label = _player_rows[p]
		var dots := ""
		for i in maxi(p.lives, Player.BASE_MAX_LIVES):
			dots += "● " if i < p.lives else "○ "
		var tag := ""
		if p.eliminated:
			tag = "  OUT"
			dots = ""
		elif p.cuffed:
			tag = "  [cuffed]"
		row.text = "%s  %s%s" % [p.display_name, dots, tag]
		row.add_theme_color_override("font_color", p.accent.darkened(0.6) if p.eliminated else p.accent)

func set_turn(p: Player) -> void:
	_turn.text = "YOUR TURN" if (p.is_human and _humans_count() == 1) else "%s'S TURN" % p.display_name.to_upper()
	_turn.add_theme_color_override("font_color", p.accent)

func _humans_count() -> int:
	return _players.filter(func(p): return p.is_human).size()

func set_shells(live: int, blank: int) -> void:
	_shells_live.text = "%d LIVE" % live
	_shells_blank.text = "%d BLANK" % blank

func set_known(viewer: Player, shells: Array) -> void:
	if viewer == null:
		_intel.text = ""
		return
	var lines := []
	for i in shells.size():
		var s: Dictionary = shells[i]
		if viewer.known.has(s.id):
			var live: bool = viewer.known[s.id]
			var c := GameManager.LIVE_COLOR if live else GameManager.BLANK_COLOR.lightened(0.2)
			var where := "CHAMBER" if i == 0 else "%s shell" % GameManager.ordinal(i + 1)
			lines.append("[right][color=#%s]■[/color] %s: %s[/right]" % [c.to_html(false), where, "LIVE" if live else "BLANK"])
	_intel.text = "" if lines.is_empty() else "[right][color=#a89a85]YOUR INTEL[/color][/right]\n" + "\n".join(lines)

func add_log(msg: String) -> void:
	_log_lines.append(msg)
	while _log_lines.size() > 8:
		_log_lines.pop_front()
	var out := ""
	for i in _log_lines.size():
		var a := 0.35 + 0.65 * float(i + 1) / _log_lines.size()
		out += "[color=#%s]%s[/color]\n" % [Color(0.85, 0.8, 0.72, a).to_html(true), _log_lines[i]]
	_log.text = out

func set_hint(t: String) -> void:
	_hint.text = t
	_hint.modulate = Color.WHITE

func flash_hint(t: String) -> void:
	_hint.text = t
	_hint.modulate = Color(1.0, 0.5, 0.4)
	Sfx.play("click", 0.6, -4.0)

func show_shoot_bar(self_btn: bool, visible_bar: bool) -> void:
	_shoot_bar.visible = visible_bar
	_self_btn.visible = self_btn

func callout(text: String, color: Color, hold := 1.2, keep_waiting := true) -> void:
	if _callout_tw:
		_callout_tw.kill()
	_callout.text = text
	_callout.add_theme_color_override("font_color", color)
	_callout.scale = Vector2.ONE
	_callout.pivot_offset = _callout.size * 0.5
	_callout_tw = create_tween()
	_callout_tw.tween_property(_callout, "modulate:a", 1.0, 0.15)
	_callout_tw.parallel().tween_property(_callout, "scale", Vector2.ONE * 1.06, 0.15).from(Vector2.ONE * 0.85)
	_callout_tw.tween_interval(hold)
	_callout_tw.tween_property(_callout, "modulate:a", 0.0, 0.35)
	if keep_waiting:
		await get_tree().create_timer(hold + 0.3).timeout

func private_reveal(text: String, color: Color) -> void:
	if _private_tw:
		_private_tw.kill()
	_private_label.text = text
	_private_label.add_theme_color_override("font_color", color)
	_private_tw = create_tween()
	_private_tw.tween_property(_private, "modulate:a", 1.0, 0.2)
	_private_tw.tween_interval(2.6)
	_private_tw.tween_property(_private, "modulate:a", 0.0, 0.5)

func show_tooltip(text: String, at: Vector2) -> void:
	_tooltip_label.text = text
	_tooltip.visible = true
	_tooltip.reset_size()
	var vp := get_viewport().get_visible_rect().size
	_tooltip.position = (at + Vector2(18, 18)).clamp(Vector2.ZERO, vp - _tooltip.size)

func hide_tooltip() -> void:
	_tooltip.visible = false

func toggle_pause() -> void:
	if _over.visible or _title.visible:
		return
	_pause.visible = not _pause.visible
	get_tree().paused = _pause.visible

func show_game_over(text: String, good: bool) -> void:
	_over_label.text = text
	_over_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.45) if good else Color(0.85, 0.15, 0.1))
	_over.visible = true
	_over.modulate.a = 0.0
	create_tween().tween_property(_over, "modulate:a", 1.0, 0.6)

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused and event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()
