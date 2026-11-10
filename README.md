# Buckshot Roulette 3D (Godot 4)

Four floating gas masks around a table under a single hanging lamp: one gun, hidden live and blank shells, and a box of items for every player each round.

## Run
1. Open Godot 4.4 or newer (tested on 4.7) and choose **Import**, then pick `project.godot`.
2. Press **F5**. The first open imports the models, which takes a few seconds.

Headless AI-vs-AI test (prints the log and the winner, then quits):
```
godot --headless --path . -- --autoplay
```

## Controls
| Input | Action |
|---|---|
| Mouse hover | Tooltip for items, masks and the gun |
| Click your item | Use it. Handcuffs ask for a target, Adrenaline asks for an item to steal |
| Click the gun | Targeting mode: click a mask to shoot it, or press **SHOOT YOURSELF** |
| Drag across the bottle | Spin it (a longer drag spins harder) |
| Right-click / Esc | Cancel targeting |
| Esc | Pause (resume, restart, quit to title) |

The title screen offers solo play against 3 bots, hot-seat with 2 humans and 2 bots, hot-seat with 4 humans, and watching 4 bots play.

## Rules
- A random player spins the bottle, and whoever it points at goes first.
- Each round the gun is loaded with 2 to 8 shells (at least 1 live and 1 blank). You see the counts but not the order. Everyone gets a box of 2 to 5 items, and nobody can hold more than 8.
- On your turn you can use any number of items, then you must shoot:
  - yourself with a blank: you keep the turn
  - yourself with a live shell: you lose 1 life
  - someone else: a live shell costs them 1 life (2 if the barrel is sawed off), and the turn passes either way
- Everyone has 3 lives. At 0 you are out. The last mask standing wins.

| Item | Rarity | Effect |
|---|---|---|
| Magnifying Glass | Common | See the current shell (only you see it) |
| Handcuffs | Common | The target skips their next turn (doesn't stack) |
| Cigarettes | Common | +1 life, up to 3 |
| Beer | Common | Eject the current shell and show it to everyone |
| Hand Saw | Common | The next live shot does double damage |
| Inverter | Uncommon | Flip the current shell |
| Expired Medicine | Uncommon | 50%: +2 lives, 50%: -1 life |
| Burner Phone | Uncommon | Learn what the Nth upcoming shell is (only you see it) |
| Adrenaline | Rare | Steal another player's item and use it right away |
| Medkit | Rare | +1 life, up to 4 |
| Turn Reverser | Rare | Reverse the turn order |

## Structure
- `main.tscn`: Room, CameraRig, Gun, Bottle, AIController, HUD, GameManager
- `scripts/game_manager.gd`: the state machine (BOTTLE_SPIN, ROUND_SETUP, TURN, ROUND_END, GAME_OVER), the signals (`turn_started`, `shot_fired`, `item_used`, `player_eliminated`, `round_started`) and mouse input
- `scripts/player.gd`: mask, gloved hands, lives, inventory and what each player knows about the shells
- `scripts/gun.gd`, `scripts/bottle.gd`, `scripts/ai_controller.gd`, `scripts/hud.gd`, `scripts/camera_rig.gd`, `scripts/room.gd`, `scripts/sfx.gd` (procedural sound)
- `scripts/items/`: the `Item` base class, one subclass per item, and `ItemDB` (weighted drops)

## Assets
The 3D models are from [Poly Haven](https://polyhaven.com) (CC0): gas mask, rifle, wine bottle, table, hanging lamp, crates, barrels, shelves, chair, cardboard box, magnifying glass, cigarette pack, hand saw, medical box and beer can. The gloved hands, shells, handcuffs, inverter, medicine bottle, phone, syringe and turn reverser are built from primitives. All sound is generated in code.
