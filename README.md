# Platform 8

First-person anomaly-spotting game set in a looping underground metro station (fictional line). Godot 4.7, built on GodotTemplate v0.2.

## Run it

1. Open this folder in Godot 4.7 and press **F5**.
2. On the title screen press **Enter**.

| Control | Key |
|---|---|
| Walk | W A S D or arrow keys |
| Look | Mouse |
| Free the mouse | Esc (click to capture it again) |

## The rules

Every loop you walk the same route: **concourse → AFC gates → passage → escalator → platform**.

Each loop has 0 or 1 anomaly. If you saw **nothing wrong**, take the **forward** choice. If you saw **an anomaly**, take the **back** choice.

- Right call: station count +1 and you arrive at the next station (new name, number and line colour).
- Wrong call: count goes back to 0, you come back to the **same** station, and the PA says *"Yeh station [name] hai."*
- Reach **8 / 8**: the exit behind the starting point opens. Turn around and walk through it to finish.

The **first loop is always clean**, so the first right answer is always forward.

The station is meant to feel wrong even when it isn't: dark, low ceilings, fog, hum, echoing footsteps, distant trains. Judge only by the checklist below, not by mood.

## Decision points

The choice isn't always at the train. Each station picks one decision point at random. The top of the screen tells you which one, and a **yellow `DECISION POINT` sticker** marks it on the floor.

| Decision point | From station | Forward (nothing wrong) | Back (anomaly) |
|---|---|---|---|
| **Train** (platform, middle) | 0 | Right door, `FORWARD ▶` | Left door, `◀ OPPOSITE` |
| **Escalator bottom** | 2 | Step on the sticker, then walk on to the platform | Step on the sticker, then walk back **up** the escalator |
| **AFC gates** | 3 | Step on the sticker, then go through the gates | Step on the sticker, then turn round and walk back to the concourse |

You only need to look at the part of the station **before** the decision point. The game never hides the anomaly past it. For example, with the gates decision, the anomaly is always in the concourse.

## What "normal" looks like

Learn this on loop 1. It's what you compare against every time after.

**Concourse** (where you start, facing the gates)

| What | Normal |
|---|---|
| Sign over the passage opening | Station name in white capitals, `STATION n / 8` under it (and the same name in the top-left HUD) |
| Clock, front wall left of the opening | Red second hand going **clockwise** |
| Yellow tactile strip on the floor, spawn → gates | Yellow all the way |
| Left wall | Blue token machine by the start, lit cream poster (**red square top-left**, `SAFE TRAVEL →` / `KEEP LEFT` / `MIND THE GAP`), water cooler near the gates with a **dry floor** |
| Right wall | Green `EXIT →` sign (points back towards the real exit behind you), **closed** lift doors, a **green dustbin on this wall** near the start |
| Ceiling, just before the gates | **Two** CCTV cameras, one each side |
| AFC gates | Red flaps **closed**; they open only when you walk up to them |
| Lights | Dim, pale greenish |
| PA subtitle on arrival | `Yeh <name> station hai. This is <name>.` |

**Passage**

| What | Normal |
|---|---|
| Right wall | **Red** fire extinguisher, red `FIRE` label |
| Hanging sign near the end | `PLATFORM 1 & 2 ↓` |
| Ceiling tube | Steady (the one over the train doors is the flickery one) |
| Left wall | Blank wall, no door, silent |
| Ceiling height | Same as the concourse opening |

**Escalator and platform**

| What | Normal |
|---|---|
| Escalator step lines | Moving **down** |
| Board at the escalator bottom | Amber `NEXT TRAIN   2 MIN` |
| Floor sticker by the right door | `MIND THE GAP`, stops at the platform edge |
| Train behind the right door | Destination `▶ <next station>` |
| Platform far end | Lit, station name on the end wall |

Always there and **never an anomaly**: the flickering tube over the train doors, the hum, the rumble, and the distant train screech.

## Anomaly solutions

All of these mean: **take the BACK choice.** Tier sets when they can appear: **Subtle** from station 0, **Creepy** from station 4, **Intense** from station 7.

### Subtle (stations 0 and up)

| # | Anomaly | Where | Tell |
|---|---|---|---|
| 1 | Mirrored poster | Concourse, left wall | Red square is **top-right**, text is mirror-writing |
| 2 | Floor strip changes colour | Concourse floor | A stretch of the yellow tactile strip turns **blue** halfway to the gates |
| 3 | CCTV camera missing | Concourse ceiling, right side before the gates | Only the empty **mount** is left |
| 4 | Dustbin moved | Concourse | The green dustbin is on the **left** wall instead of the right |
| 5 | Blue fire extinguisher | Passage, right wall | Extinguisher is **blue**, the label stays red |
| 6 | Wrong platform number | Passage, hanging sign | `PLATFORM 1 & 3 ↓` (there are only 2 platforms) |
| 7 | Exit arrow wrong | Concourse, right wall | `← EXIT` points deeper into the station instead of back at the exit |
| 8 | Station name backwards | Concourse sign (and platform end) | `KALINDI BAGH` → `HGAB IDNILAK`; compare it with the HUD |
| 9 | Gates open by themselves | AFC gates | All red flaps already **open** while you're far away |
| 10 | Water cooler overflows | Concourse, left wall by the gates | A **puddle** spreads across the floor |
| 11 | Escalator runs the wrong way | Escalator | Step lines move **up** while you walk down |
| 12 | Red emergency lighting | Everywhere | The whole station is lit **red** |
| 13 | Tube flickers in a rhythm | Passage ceiling | Off-on-off-on at a perfectly steady beat (not random like the door tube) |
| 14 | Clock runs backwards | Concourse, front wall | Second hand goes **anticlockwise** |
| 15 | Next train: 88 min | Board at the escalator bottom | `NEXT TRAIN  88 MIN` |

### Creepy (stations 4 and up)

| # | Anomaly | Where | Tell |
|---|---|---|---|
| 16 | Mind the gap too long | Platform floor by the right door | Sticker stretches **past the platform edge** over the track |
| 17 | PA says your name | Arrival subtitle | An extra line: `<your Windows user name>, aap yahin rahenge.` |
| 18 | Phone in the wall | Passage, left wall | A phone **rings from the blank wall**; caption `[ a phone is ringing inside the wall ]` |
| 19 | Lift doors | Concourse, right wall | Lift doors **open and close** on their own with a ding |
| 20 | Dark platform end | Platform | The far third of the platform is **unlit** |
| 21 | New door | Passage, left wall | A brown staff **door** where there was blank wall |
| 22 | Low ceiling | Passage | Ceiling and tube light are much **lower**, almost touching your head |
| 23 | Train has no destination | Train behind the right door | Destination board is **blank** |

### Intense (stations 7 and 8)

| # | Anomaly | Where | Tell |
|---|---|---|---|
| 24 | HUD counter jumps | Top-left HUD | The count **flickers to `8 / 8`** every few seconds, then back |
| 25 | Lights die towards you | Everywhere | Lights switch off **one by one** from the platform end towards you, each with a heavy clunk |

### No anomaly
If everything matches the "normal" tables (up to the decision point), take the **forward** choice.

## Full anomaly list (GDD)

The GDD's 48-anomaly pool plus its train-side extras. ✅ = in the game now (25), ⏳ = planned.

| GDD # | Anomaly | Category | Tier | Status |
|---|---|---|---|---|
| 1 | Ad poster is mirrored | Small visual | Subtle | ✅ |
| 2 | Floor pattern changes colour in one stretch | Small visual | Subtle | ✅ (tactile strip) |
| 3 | One CCTV camera missing | Small visual | Subtle | ✅ |
| 4 | Dustbin moved to the other wall | Small visual | Subtle | ✅ |
| 5 | Fire extinguisher a different colour | Small visual | Subtle | ✅ |
| 6 | Hindi signboard spelling slightly off | Text and signage | Subtle | ⏳ needs Hindi signage + font |
| 7 | Platform number on the sign is wrong | Text and signage | Subtle | ✅ |
| 8 | Route map has a station that doesn't exist | Text and signage | Creepy | ⏳ needs a route map |
| 9 | "Exit" arrow points the wrong way | Text and signage | Subtle | ✅ |
| 10 | "Mind the gap" sticker too long | Text and signage | Creepy | ✅ |
| 11 | Station name is backwards | Text and signage | Subtle | ✅ |
| 12 | PA announcement in the wrong language | Audio | Subtle | ⏳ needs PA voice |
| 13 | PA says the player's name | Audio | Creepy | ✅ (subtitle) |
| 14 | Footsteps echo late | Audio | Creepy | ⏳ |
| 15 | Escalator hum stops | Audio | Subtle | ⏳ needs an escalator hum |
| 16 | A phone rings inside the wall | Audio | Creepy | ✅ |
| 17 | "Doors will open on the left", then right | Audio | Creepy | ⏳ needs PA voice + train doors |
| 18 | Same passenger on every bench | NPCs | Creepy | ⏳ needs NPCs |
| 19 | Guard never blinks and follows you | NPCs | Creepy | ⏳ needs NPCs |
| 20 | Whole crowd faces one wall | NPCs | Creepy | ⏳ needs NPCs |
| 21 | Kid with a balloon has no shadow | NPCs | Creepy | ⏳ needs NPCs |
| 22 | Sweeper sweeps through the walls | NPCs | Intense | ⏳ needs NPCs |
| 23 | Token machine won't stop dispensing | Object behaviour | Creepy | ⏳ machine model is in, tokens next |
| 24 | AFC gate opens before you reach it | Object behaviour | Subtle | ✅ |
| 25 | Escalator runs the wrong direction | Object behaviour | Subtle | ✅ |
| 26 | Water cooler overflows | Object behaviour | Subtle | ✅ |
| 27 | Lift doors open and close by themselves | Object behaviour | Creepy | ✅ |
| 28 | One tube light flickers in a rhythm | Lighting | Subtle | ✅ |
| 29 | The player has no shadow | Lighting | Creepy | ⏳ needs a player body + shadows |
| 30 | Platform end is completely dark | Lighting | Creepy | ✅ |
| 31 | Emergency lighting is red | Lighting | Subtle | ✅ |
| 32 | Lights switch off one by one towards you | Danger | Intense | ✅ |
| 33 | Passage is a few metres longer | Spatial | Creepy | ⏳ |
| 34 | Stairs have extra steps | Spatial | Creepy | ⏳ needs stairs |
| 35 | Escalator never reaches the bottom | Spatial | Intense | ⏳ |
| 36 | A door appears where there was a wall | Spatial | Creepy | ✅ |
| 37 | Ceiling is lower | Spatial | Creepy | ✅ |
| 38 | Poster model's eyes follow you | Reactive | Creepy | ⏳ |
| 39 | Things change only when you look away | Reactive | Intense | ⏳ |
| 40 | NPC turns to face you when you look | Reactive | Creepy | ⏳ needs NPCs |
| 41 | Someone runs at you from the passage | Danger | Intense | ⏳ |
| 42 | Platform floods with water | Danger | Intense | ⏳ |
| 43 | Clock runs backwards | Time | Subtle | ✅ |
| 44 | "Next train: 88 min" | Time | Subtle | ✅ |
| 45 | Crowd freezes mid-step | Time | Creepy | ⏳ needs NPCs |
| 46 | HUD station counter jumps by itself | Meta / UI | Intense | ✅ |
| 47 | Subtitles don't match the announcement | Meta / UI | Creepy | ⏳ needs PA voice |
| 48 | Every coach has the same passenger | Inside the train | Creepy | ⏳ needs NPCs |
| — | Forward train's destination board is blank | Inside the train | Creepy | ✅ |
| — | Forward train has no driver | Inside the train | — | ⏳ |
| — | Coach is empty at rush hour | Inside the train | — | ⏳ |
| — | In-coach display shows the wrong direction | Inside the train | — | ⏳ |
| — | "Agla station: [same station]" before arrival | Inside the train | — | ⏳ |

## Station props

The station's models are built in Blender by [`art/build_props.py`](art/build_props.py) and saved as `.gltf` in `game/assets/models/`:

- dustbin
- fire extinguisher
- water cooler
- CCTV camera
- wall clock
- AFC gate
- bench
- pillar
- lift doors
- token vending machine

To change a prop, edit the script and rerun it with Blender. It overwrites the `.gltf` files, [`art/platform8_props.blend`](art/platform8_props.blend) and [`art/preview.png`](art/preview.png):

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" --background --factory-startup --python art/build_props.py
```

## Quick checklist per loop

1. **Read the top line**: which decision point? You only need to check up to there.
2. **Spawn**: name sign = HUD? Lights not red? Clock clockwise? Poster square top-left? Strip all yellow? Dustbin on the right? Lift closed? Two cameras? Gates closed? PA line normal?
3. **Passage**: extinguisher red? `PLATFORM 1 & 2`? Ceiling normal? No door or ringing on the left? Tube steady?
4. **Escalator**: steps going down? Board `2 MIN`?
5. **Platform**: sticker inside the edge? Destination shown? Far end lit?
6. Anything off → **back**. All fine → **forward**.

## Cheating while testing

Every loop prints a line to Godot's **Output** panel:

```
[INFO]  Loop | { "count": 3, "decision": &"gates", "anomaly": &"blue_extinguisher" }
```

`"none"` means a clean loop. The run's seed is printed at the start (`Run started | { "seed": … }`) and shown on the ending screen.

## Tests

From this folder (takes about 2 minutes, mostly real-time physics walks):

```powershell
& "C:\Users\Asus\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless -s res://game/tests/test_platform8.gd
```

Prints `ALL TESTS PASSED`. The tests cover:
- the loop rules
- the picker over 300 seeds (first loop empty, never more than 2 empty loops in a row, no category twice in a row, no repeats, no category over 20% of the pool)
- decision-point unlocks, and that anomalies never sit past the decision point
- apply/revert for every anomaly
- a scripted 8-station run
- physics walks for both choices at the train, the escalator and the gates

## Adding an anomaly

1. **Simple change** (one property, like a text, a colour, `visible`, a position or a metadata flag): add a `.tres` in `game/data/anomalies/` that uses `SetProperty.gd`, with `params = {"property": ..., "value": ...}`.
   **Anything else:** write a script in `game/scripts/platform8/anomalies/` that `extends Anomaly` and implements `apply(slot)` / `revert(slot)`.
2. Fill in the `.tres` fields: id, category (one of the GDD's 12), tier, `location` (concourse / passage / escalator / platform), and `slot_name`. The slot is a node path inside the Station: `.` means the Station itself, and `../HUD/<Label>` means a HUD label.
3. List it in `game/scripts/platform8/AnomalyCatalog.gd`.
4. Add it to this README and run the tests (they check that revert is exact).
