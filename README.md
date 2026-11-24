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

At the middle of the platform there are two open doors in the platform screen doors:

| Door | Sign | Take it when… |
|---|---|---|
| Right | `FORWARD ▶` | you saw **nothing** wrong |
| Left | `◀ OPPOSITE` | you saw **an anomaly** |

- Right call: station count +1 and you arrive at the next station (new name, number and line colour).
- Wrong call: count goes back to 0, you come back to the **same** station, and the PA says *"Yeh station [name] hai."*
- Reach **8 / 8**: the exit behind the starting point opens. Turn around and walk through it to finish.

Each loop has 0 or 1 anomaly. The **first loop is always clean**, so the first right answer is always FORWARD.

## What "normal" looks like

Learn this on loop 1, it's what you compare against every time after.

| Place | Normal |
|---|---|
| Concourse, over the passage opening | Station name in white capitals, `STATION n / 8` under it |
| Concourse, left wall | Cream poster, **red square in the top-left corner**, text `SAFE TRAVEL →` / `KEEP LEFT` / `MIND THE GAP` |
| All areas | Warm white ceiling lights |
| Passage, right wall | **Red** fire extinguisher with a red `FIRE` label above it |
| Platform, hanging board at the escalator bottom | Amber `NEXT TRAIN   2 MIN` |
| Platform, far end wall | Station name again, in white capitals |

## Anomaly solutions

All of these mean: **take the OPPOSITE (left) train.**

### 1. Mirrored poster — concourse
- **Where:** left wall of the concourse, before the AFC gates.
- **Tell:** the red square has jumped to the **top-right** corner and the text reads backwards (`→ LEVART EFAS`-style mirror writing).
- **Tip:** glance left as soon as you spawn; you don't need to walk up to it.

### 2. Blue fire extinguisher — passage
- **Where:** right wall of the passage, about a third of the way in.
- **Tell:** the extinguisher is **blue**; the `FIRE` label above it stays red.
- **Tip:** it's small and the passage is dim. Look right as you enter the passage.

### 3. Backwards station name — concourse and platform
- **Where:** the big name sign over the passage opening (you see it from spawn), and the one on the platform's far wall.
- **Tell:** the name is reversed letter by letter, e.g. `KALINDI BAGH` → `HGAB IDNILAK`. The HUD in the top-left still shows the real name, so compare the sign against it.
- **Tip:** this is visible from the very first second of the loop.

### 4. Red emergency lighting — everywhere
- **Where:** every ceiling light in the station.
- **Tell:** the whole station is lit **dim red** instead of warm white.
- **Tip:** the easiest one; if the station looks red, go OPPOSITE.

### 5. "Next train: 88 min" — platform
- **Where:** the hanging board right at the bottom of the escalator.
- **Tell:** it says `NEXT TRAIN  88 MIN` instead of `2 MIN`.
- **Tip:** read it as you come off the escalator; you pass under it about 5 seconds before the doors.

### No anomaly
If all six "normal" checks above match, take the **FORWARD (right)** train.

## Quick checklist per loop

1. Spawn: name sign correct? Lights white? Poster square top-left?
2. Passage: extinguisher red?
3. Escalator bottom: board says `2 MIN`?
4. Platform: far-wall name correct?
5. Anything off → **left door**. All fine → **right door**.

## Cheating while testing

Every loop prints a line to Godot's **Output** panel:

```
[INFO]  Loop | { "count": 3, "anomaly": &"blue_extinguisher" }
```

`"none"` means a clean loop. The run's seed is printed at the start (`Run started | { "seed": … }`) and shown on the ending screen.

## Tests

From this folder (takes about 45 s, mostly the real-time walk test):

```powershell
& "C:\Users\Asus\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless -s res://game/tests/test_platform8.gd
```

Prints `ALL TESTS PASSED`. They cover the loop rules, the anomaly picker over 300 seeds, apply/revert for every anomaly, a scripted 8-station run, and a physics walk to both train doors.

## Adding an anomaly

1. Write a script in `game/scripts/platform8/anomalies/` that `extends Anomaly` and implements `apply(slot)` / `revert(slot)`.
2. Add a `.tres` in `game/data/anomalies/` (id, category, tier, `script_path`, `slot_name` = node path inside the Station).
3. List it in `game/scripts/platform8/AnomalyCatalog.gd`.
4. Add a section to this README and run the tests (they check revert is exact).
