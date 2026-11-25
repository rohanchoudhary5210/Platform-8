# Platform 8

First-person anomaly-spotting game set in a looping underground metro station (fictional line). Godot 4.7, built on GodotTemplate v0.2.

## Run it

1. Open this folder in Godot 4.7 and press **F5**.
2. On the title screen press **Enter** (or **L** to switch the language first).

| Control | Keyboard and mouse | Gamepad |
|---|---|---|
| Walk | W A S D or arrow keys | Left stick |
| Look | Mouse | Right stick |
| Use: buy a token at the machine, pick a token up | E, while looking at it | A |
| Pause menu | Esc (click to capture the mouse again after) | Start |
| Menus | Mouse, arrows + Enter | D-pad / left stick + A |

**Pause menu**: Resume, Restart run, Hardcore, Language, Quit to home. Settings are saved straight away.

- **Hardcore (no HUD)**: hides the station counter (the top-left HUD and the `STATION n / 8` sign) and the decision-point hint at the top. You have to remember where you are and read the yellow stickers yourself. The HUD-counter anomaly is never picked in hardcore, since you couldn't see it.
- **Language**: English or Hindi (Devanagari) for the HUD hints, the rules notice, the menus and the ending screen. The PA stays bilingual, like the real metro. Hindi uses the system's Devanagari font (Nirmala UI on Windows).

## The rules

Every loop you walk the same route: **concourse → AFC gates → passage → escalator → platform**.

Each loop has 0 or 1 anomaly. If you saw **nothing wrong**, take the **forward** choice. If you saw **an anomaly**, take the **back** choice.

- Right call: station count +1 and you arrive at the next station (new name, number and line colour).
- Wrong call: count goes back to 0, you come back to the **same** station, and the PA says *"Yeh station [name] hai."*
- After a **wrong call** you first see a 3-second **replay** of the loop from your own eyes, around the moment you were closest to the anomaly, with it circled in red. If the loop was clean it says *"There was no anomaly."*
- Reach **8 / 8**: the exit behind the starting point opens. Turn around, walk up the exit corridor and out onto the street. The ending screen shows your time, wrong calls, anomalies found and the seed. Press Enter to go back to the title.

## Lost & Found and the save file

The title screen shows the **Lost & Found** board: one card per anomaly. An anomaly is "found" the first time you call it right, and its card then shows its name and category. The rest stay `? ? ?`. Above the board: best station reached, number of clears and fastest clear.

Everything is in one save file, `%APPDATA%\Godot\app_userdata\Platform 8\platform8_save.cfg`: found anomalies, best station, clears, best time, and the settings (mouse sensitivity, volume, hardcore, language). Delete it to reset. Tests use a separate scratch file, so they never touch it.

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
| Notice board on a stand, just ahead on your left | `PASSENGER NOTICE` in white on blue, then the rules in 7 black lines (`Nothing unusual: go FORWARD.` / `Something unusual: turn **BACK**.` …) |
| Sign over the passage opening | Station name in white capitals, `STATION n / 8` under it (and the same name in the top-left HUD) |
| Clock, front wall left of the opening | Red second hand going **clockwise** |
| Screen, front wall right of the opening | Blue ad: `METRO SMART CARD` / `Recharge karo · 10% bachao` |
| Yellow tactile strip on the floor, spawn → gates | Yellow all the way |
| Left wall | Blue token machine by the start (screen shows `<this station> → <next>`, **tray empty**; press E to buy a token, E again on the token to pick it up; the gates take it as you walk through), lit cream poster (**red square top-left**, a smiling face **gazing up and to the right**, `SAFE TRAVEL →` / `KEEP LEFT` / `MIND THE GAP`), water cooler near the gates with a **dry floor**. Between the token machine and the poster, a railed stairwell (`SUBWAY ↓` sign) goes down to a closed shutter: **20 steps**, each with a yellow edge strip |
| Right wall | Green `EXIT →` sign (points back towards the real exit behind you), **closed** lift doors, a **green dustbin on this wall** near the start |
| Ceiling, just before the gates | **Two** CCTV cameras, one each side |
| AFC gates | Red flaps **closed**; they open only when you walk up to them |
| People | A **security guard** standing right of the gates, facing you; a **sweeper** in an orange vest on the left, half turned away, who **never moves from his spot**; a commuter with a backpack **pacing up and down** the right side. Everyone breathes and looks around a little |
| Lights | Dim, pale greenish |
| PA subtitle on arrival | `Yeh <name> station hai. This is <name>.` |
| Sound | Your own footsteps, the hum, the rumble. **Nothing walks behind you** |

**Passage**

| What | Normal |
|---|---|
| Right wall | **Red** fire extinguisher, red `FIRE` label |
| Hanging sign near the end | `PLATFORM 1 & 2 ↓` |
| Ceiling tube | Steady (the one over the train doors is the flickery one) |
| Left wall | Blank wall, no door, silent |
| Ceiling height | Same as the concourse opening |
| People and length | **Empty**. About 20 m: you pass the `PLATFORM` sign **once** and the escalator starts |

**Escalator and platform**

| What | Normal |
|---|---|
| Escalator step lines | Moving **down** |
| Board at the escalator bottom | Amber `NEXT TRAIN   2 MIN` |
| Floor sticker by the right door | `MIND THE GAP`, stops at the platform edge |
| Train behind the right door | Destination `▶ <next station>` |
| Screen doors | **Glass**: you can see into both parked trains |
| Inside both trains | Lit, **people standing** in every coach (rush hour) |
| Destination LED in each coach's middle window | Forward train: `AGLA STATION` / `<next station> ▶`. Opposite train: `◀ TERMINUS` |
| Front of the forward train | Walk to the far end of the platform: the **driver** stands in the cab behind the last window |
| Platform far end | Lit, station name on the end wall |
| People | A commuter with a backpack on the left facing the OPPOSITE doors; one in a maroon kurta further down on the right, facing along the platform |

Always there and **never an anomaly**: the flickering tube over the train doors, the hum, the rumble, and the distant train screech.

## Anomaly solutions

All of these mean: **take the BACK choice.** Tier sets when they can appear: **Subtle** from station 0, **Creepy** from station 4, **Intense** from station 7. Once every anomaly of your tier has been shown in a run, the game borrows an unshown one from the next tier up; it only repeats once nothing unshown fits the loop.

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
| 16 | Empty coaches at rush hour | Forward train, through the windows | **Nobody** in the forward train; the opposite one is still full |
| 17 | Coach display shows the wrong direction | Forward train's window LEDs | They read `◀ TERMINUS`, the opposite train's text |

### Creepy (stations 4 and up)

| # | Anomaly | Where | Tell |
|---|---|---|---|
| 18 | Mind the gap too long | Platform floor by the right door | Sticker stretches **past the platform edge** over the track |
| 19 | PA says your name | Arrival subtitle | An extra line: `<your Windows user name>, aap yahin rahenge.` |
| 20 | Phone in the wall | Passage, left wall | A phone **rings from the blank wall**; caption `[ a phone is ringing inside the wall ]` |
| 21 | Lift doors | Concourse, right wall | Lift doors **open and close** on their own with a ding |
| 22 | Dark platform end | Platform | The far third of the platform is **unlit** |
| 23 | New door | Passage, left wall | A brown staff **door** where there was blank wall |
| 24 | Low ceiling | Passage | Ceiling and tube light are much **lower**, almost touching your head |
| 25 | Train has no destination | Train behind the right door | Destination board is **blank** |
| 26 | Guard watches you | Concourse, by the gates | The guard **turns to face you** and slowly follows you around the concourse |
| 27 | Everyone faces one wall | Concourse and platform | The guard, the sweeper and both commuters all stand **facing the right-hand wall** |
| 28 | Token machine won't stop | Concourse, left wall by the start | Tokens keep **dropping on their own** with a clatter, filling the tray and spilling over the floor |
| 29 | Everyone freezes | Concourse (and platform) | The pacing commuter **stops mid-step** and nobody moves at all, not even breathing |
| 30 | Guard charges | Concourse, in front of the gates (gates decision only) | **Danger.** The guard stands **in the middle of the walkway** in front of the gates, facing you, instead of off to the right. Get within about 3.5 m and he charges: that counts as reaching the decision point, so **back off towards the spawn** at once. If he reaches you, you're caught |
| 31 | Poster's eyes follow you | Concourse, left wall | The face on the poster **looks at you** wherever you stand, instead of gazing up and to the right |
| 32 | Footsteps behind you | Anywhere you walk | A heavier step lands **just after each of yours**, a few metres behind, and stops when you stop. Nobody is there |
| 33 | Ad screen shows you | Concourse, front wall right of the opening | The ad is gone: a greenish **live camera view from behind you**, a dark figure standing where you stand |
| 34 | Commuter turns to you | Platform, backpack commuter on the left | Look straight at him and he **turns to face you**; glance away and he's facing the doors again |
| 35 | Passage too long | Passage | Just past the `PLATFORM` sign you're put back about 8 m: the sign **comes round twice** and the walk takes longer |
| 36 | Stairs have extra steps | Concourse, the subway stairwell on the left | Same stairs, same depth, but **28 steps** instead of 20: the yellow edge strips are packed noticeably closer |
| 37 | Forward train has no driver | Far end of the platform, the forward train's cab | The cab is lit but **empty** |
| 38 | "Agla station" is this station | Forward train's window LEDs | `AGLA STATION` / **`<this station>`** instead of the next one |
| 39 | A rule has changed | Notice board by the spawn | The 4th rule reads `Something unusual: go FORWARD.` **Don't obey it**: the rules never change, so this is the anomaly. Turn back |

### Intense (stations 7 and 8)

| # | Anomaly | Where | Tell |
|---|---|---|---|
| 40 | Sweeper creeps closer | Concourse, left side | The sweeper is **a step closer every time you look away**, standing still and facing you. Watch him and he never moves |
| 41 | HUD counter jumps | Top-left HUD | The count **flickers to `8 / 8`** every few seconds, then back |
| 42 | Lights die towards you | Everywhere | Lights switch off **one by one** from the platform end towards you, each with a heavy clunk |
| 43 | Platform floods | Platform (train decision only) | **Danger.** Step off the escalator and dark water fills the track pits, then climbs the platform. Get to the **left door** before it reaches your waist (about 15 s), or you're **caught**: it counts as a wrong call |
| 44 | Someone runs out of the passage | Concourse, seen through the gates (gates decision only) | **Danger.** A man in a maroon kurta stands **deep in the passage**, facing you (the passage is normally empty). Get about halfway to the gates and he sprints at you, faster than the guard: **turn back** at once |
| 45 | Escalator never ends | Escalator (escalator decision only) | Near the foot you're quietly put back a few steps, over and over: the bottom **never gets closer**. Ride back up to escape |

**Danger anomalies** don't wait for you. If the threat reaches you, it's the same as taking the forward choice: a wrong call, the replay, and back to the same station. Turn back in time and it's a right call like any other.

### No anomaly
If everything matches the "normal" tables (up to the decision point), take the **forward** choice.

## Full anomaly list (GDD)

The GDD's 48-anomaly pool plus its train-side extras. ✅ = in the game now (45), ⏳ = planned.

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
| 14 | Footsteps echo late | Audio | Creepy | ✅ (a few metres behind you) |
| 15 | Escalator hum stops | Audio | Subtle | ⏳ needs an escalator hum |
| 16 | A phone rings inside the wall | Audio | Creepy | ✅ |
| 17 | "Doors will open on the left", then right | Audio | Creepy | ⏳ needs PA voice + train doors |
| 18 | Same passenger on every bench | NPCs | Creepy | ⏳ needs NPCs |
| 19 | Guard never blinks and follows you | NPCs | Creepy | ✅ |
| 20 | Whole crowd faces one wall | NPCs | Creepy | ✅ |
| 21 | Kid with a balloon has no shadow | NPCs | Creepy | ⏳ needs NPCs |
| 22 | Sweeper sweeps through the walls | NPCs | Intense | ⏳ needs NPCs |
| 23 | Token machine won't stop dispensing | Object behaviour | Creepy | ✅ |
| 24 | AFC gate opens before you reach it | Object behaviour | Subtle | ✅ |
| 25 | Escalator runs the wrong direction | Object behaviour | Subtle | ✅ |
| 26 | Water cooler overflows | Object behaviour | Subtle | ✅ |
| 27 | Lift doors open and close by themselves | Object behaviour | Creepy | ✅ |
| 28 | One tube light flickers in a rhythm | Lighting | Subtle | ✅ |
| 29 | The player has no shadow | Lighting | Creepy | ⏳ needs a player body + shadows |
| 30 | Platform end is completely dark | Lighting | Creepy | ✅ |
| 31 | Emergency lighting is red | Lighting | Subtle | ✅ |
| 32 | Lights switch off one by one towards you | Danger | Intense | ✅ |
| 33 | Passage is a few metres longer | Spatial | Creepy | ✅ |
| 34 | Stairs have extra steps | Spatial | Creepy | ✅ |
| 35 | Escalator never reaches the bottom | Spatial | Intense | ✅ |
| 36 | A door appears where there was a wall | Spatial | Creepy | ✅ |
| 37 | Ceiling is lower | Spatial | Creepy | ✅ |
| 38 | Poster model's eyes follow you | Reactive | Creepy | ✅ |
| 39 | Things change only when you look away | Reactive | Intense | ✅ (the sweeper creeps closer) |
| 40 | NPC turns to face you when you look | Reactive | Creepy | ✅ (platform commuter) |
| 41 | Someone runs at you from the passage | Danger | Intense | ✅ |
| 42 | Platform floods with water | Danger | Intense | ✅ |
| 43 | Clock runs backwards | Time | Subtle | ✅ |
| 44 | "Next train: 88 min" | Time | Subtle | ✅ |
| 45 | Crowd freezes mid-step | Time | Creepy | ✅ |
| 46 | HUD station counter jumps by itself | Meta / UI | Intense | ✅ |
| 47 | Subtitles don't match the announcement | Meta / UI | Creepy | ⏳ needs PA voice |
| 48 | Every coach has the same passenger | Inside the train | Creepy | ⏳ needs NPCs |
| — | Ad screen shows a live feed of you from behind | Reactive | Creepy | ✅ |
| — | A rule on the notice board has changed | Text and signage | Creepy | ✅ |
| — | Forward train's destination board is blank | Inside the train | Creepy | ✅ |
| — | Forward train has no driver | Inside the train | Creepy | ✅ (seen in the cab from the platform) |
| — | Coach is empty at rush hour | Inside the train | Subtle | ✅ |
| — | In-coach display shows the wrong direction | Inside the train | Subtle | ✅ (window LED) |
| — | "Agla station: [same station]" before arrival | Inside the train | Creepy | ✅ (window LED, before you board) |

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
- metro coach: hollow, with see-through windows and door glass and the full interior inside (seen from the platform through the glass screen doors). Outside: doors with black surrounds and amber door lamps, window gaskets, line-colour stripes, roof AC units, underframe boxes, gangway bellows, a number plate
- coach interior for the train ride: stainless long benches with seat grooves, glass draft screens, yellow poles, hanging grab handles, route maps (`RouteMap*`) and ads over the windows, an LED display frame (`Display_L`) where the game writes `NEXT STATION`, doors with a red status lamp and alarm button, yellow door floor plates, a light strip and AC grilles
- stairs: one straight flight (3.5 m down, 6 m long) with yellow edge strips, stringers and handrails, exported twice: `stairs` (20 steps) and `stairs_extra` (28 steps, for anomaly #34)

Wall, floor, ceiling and track-pit textures come from [`art/build_textures.py`](art/build_textures.py) (cream ceramic tiles, speckled granite floor, metal ceiling slats, concrete). They are mapped world-space, so every wall gets tiles at the right size without UVs.

The **people** come from [`art/build_people.py`](art/build_people.py): an office commuter (glasses, watch, shirt pocket and buttons, padded backpack with straps), a woman in a maroon kurta (mustard dupatta, bindi, earrings, bangles, a plait, phone in hand), a security guard (beret with badge, epaulettes, chest badge and name plate, whistle cord, a lathi on the belt) and a sweeper (cap, orange vest with reflective bands, a long jhadu). Everyone has eyes with whites, a chin, collar and hands with a thumb. Each is one smooth body (a stick skeleton through Blender's Skin and Subdivision modifiers) with a face, ears and hair, rigged with 18 bones and three animations: `Idle`, `Walk`, and `Run` (high knees, pumping arms, a forward lean) for the guard charge and the passage runner. [`art/people_preview.png`](art/people_preview.png) shows them all.

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" --background --factory-startup --python art/build_people.py
```

To change a prop, edit the script and rerun it with Blender. It overwrites the `.gltf` files, [`art/platform8_props.blend`](art/platform8_props.blend) and [`art/preview.png`](art/preview.png):

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" --background --factory-startup --python art/build_props.py
```

## Quick checklist per loop

1. **Read the top line**: which decision point? You only need to check up to there.
2. **Spawn**: name sign = HUD? Notice says `turn BACK`? Lights not red? Clock clockwise? Poster square top-left, eyes looking up-right? Stairs strips spaced normally? Ad on the screen? Sweeper where he was? Only your own footsteps? Strip all yellow? Dustbin on the right? Lift closed? Two cameras? Gates closed? PA line normal?
3. **Passage**: empty? Extinguisher red? `PLATFORM 1 & 2`? Ceiling normal? No door or ringing on the left? Tube steady?
4. **Escalator**: steps going down? Bottom getting closer? Board `2 MIN`?
5. **Platform**: people in the forward train? Its LEDs say the next station? Driver in the cab at the far end? Sticker inside the edge? Backpack commuter keeps facing the doors when you look at him? Destination shown? Far end lit?
6. Anything off → **back**. All fine → **forward**.

## Cheating while testing

### Debug keys (editor / debug builds only)

Press these during a loop to test any anomaly straight away. The loop restarts at the spawn with that anomaly, and an orange line under the HUD says which one, where it is and which decision point it's using.

| Key | Does |
|---|---|
| **F2** | Next anomaly in the catalog |
| **F1** | Previous anomaly (the first press goes to the last one) |
| **F3** | Clean loop, no anomaly |
| **F4** | Skip to the next station, as if you'd called this loop right (no ride, no replay). At station 8 the exit opens |

The decision point is picked so the anomaly is fair: **AFC gates** for the guard charge and the passage runner, the **escalator** for the endless escalator, the **train** for everything else. Your decision then plays out normally (right/wrong call, replay, next station). Once you use a debug key, the run **stops saving**, so Lost & Found, best station and best time aren't affected. Exported release builds ignore these keys.

### Output log

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
- apply/revert for every anomaly, and that the guard really follows you
- the token machine: looking at it shows the prompt, a real E key press drops a token, E on the token picks it up, arrival empties the tray, and walking through the AFC gates uses it up
- the pacing commuter walks, freezes for #45, and walks on after
- a scripted 8-station run, including the ending screen and what it saves
- the save file: round-trip, fastest time kept, a save from a newer build ignored
- the wrong-call replay window
- physics walks for both choices at the train, the escalator and the gates
- the reactive anomalies (poster eyes, footsteps behind you, the ad camera feed, the sweeper and the commuter) and the spatial ones (longer passage, endless escalator, passage runner)
- the stairwell: walking down to the shutter and back, the railing, 20 vs 28 steps
- the pause menu, hardcore mode, English/Hindi switching (menu, rules board, decision hint, the rules anomaly in both) and that settings are saved
- gamepad: sticks walk and look, A uses the token machine; the guard chase plays the `Run` cycle
- the parked trains: passengers, driver, window LEDs, and the four train anomalies

## Adding an anomaly

1. **Simple change** (one property, like a text, a colour, `visible`, a position or a metadata flag): add a `.tres` in `game/data/anomalies/` that uses `SetProperty.gd`, with `params = {"property": ..., "value": ...}`.
   **Anything else:** write a script in `game/scripts/platform8/anomalies/` that `extends Anomaly` and implements `apply(slot)` / `revert(slot)`.
2. Fill in the `.tres` fields: id, category (one of the GDD's 12), tier, `location` (concourse / passage / escalator / platform), and `slot_name`. The slot is a node path inside the Station: `.` means the Station itself, and `../HUD/<Label>` means a HUD label.
3. List it in `game/scripts/platform8/AnomalyCatalog.gd`.
4. Add it to this README and run the tests (they check that revert is exact).
