class_name ItemDB
## Item registry and weighted random drops.

const ITEMS := {
	"magnifier": preload("res://scripts/items/magnifying_glass.gd"),
	"handcuffs": preload("res://scripts/items/handcuffs.gd"),
	"cigarettes": preload("res://scripts/items/cigarettes.gd"),
	"beer": preload("res://scripts/items/beer.gd"),
	"saw": preload("res://scripts/items/hand_saw.gd"),
	"inverter": preload("res://scripts/items/inverter.gd"),
	"medicine": preload("res://scripts/items/expired_medicine.gd"),
	"phone": preload("res://scripts/items/burner_phone.gd"),
	"adrenaline": preload("res://scripts/items/adrenaline.gd"),
	"medkit": preload("res://scripts/items/medkit.gd"),
	"reverser": preload("res://scripts/items/turn_reverser.gd"),
}
const WEIGHTS := {
	"magnifier": 12, "handcuffs": 10, "cigarettes": 12, "beer": 12, "saw": 10,
	"inverter": 5, "medicine": 5, "phone": 5,
	"adrenaline": 2, "medkit": 2, "reverser": 2,
}

static func create(id: String) -> Item:
	return ITEMS[id].new()

static func random_id() -> String:
	var total := 0
	for w in WEIGHTS.values():
		total += w
	var r := randi() % total
	for id in WEIGHTS:
		r -= WEIGHTS[id]
		if r < 0:
			return id
	return "beer"
