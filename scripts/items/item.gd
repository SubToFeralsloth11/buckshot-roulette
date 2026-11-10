class_name Item
extends Node3D
## Base class for usable items. Subclasses set the fields in _init(),
## build their prop in build_prop() and implement apply().

enum Rarity { COMMON, UNCOMMON, RARE }

var item_id := ""
var display_name := ""
var description := ""
var rarity := Rarity.COMMON
## "" = no target, "player" = another player, "steal" = an item on another player's table.
var target_kind := ""
var holder: Player
var _ring: MeshInstance3D
var _prop: Node3D

func _ready() -> void:
	_prop = build_prop()
	add_child(_prop)
	var rm := Models.glow(Color(1.0, 0.85, 0.4), 2.5)
	_ring = Models.mesh(Models.torus(0.07, 0.08), rm, Vector3(0, 0.003, 0))
	_ring.visible = false
	add_child(_ring)
	add_child(Models.area(0.08, "item", self, Vector3(0, 0.05, 0)))

func build_prop() -> Node3D:
	return Node3D.new()

func set_highlight(on: bool) -> void:
	if _ring:
		_ring.visible = on

## Why the item can't be used right now, or "" if it can.
func block_reason(_gm: GameManager, _user: Player) -> String:
	return ""

func valid_targets(gm: GameManager, user: Player) -> Array:
	return gm.alive_players().filter(func(p): return p != user)

## Plays the item's effect. Awaitable.
func apply(_gm: GameManager, _user: Player, _target: Variant) -> void:
	pass

## Little flourish played while the item is held up before apply().
func use_anim() -> void:
	var tw := create_tween()
	tw.tween_property(_prop, "rotation:y", TAU, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

func rarity_name() -> String:
	return ["Common", "Uncommon", "Rare"][rarity]

func tooltip() -> String:
	return "%s  [%s]\n%s" % [display_name, rarity_name(), description]
