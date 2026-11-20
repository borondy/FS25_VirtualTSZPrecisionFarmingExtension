# Performance test cases

Only cases that are not yet proven cheap. Proven cheap in the first baseline (`CONCLUSIONS.md`) and removed from here: idle minimap (0.29 ms/s, 0 KB/s) and harvest (0.32 ms/s, 9 KB/s). Re-add them only after a change to the minimap or harvest path.

## Tool

Profiler: `scripts/VtszProfiler.lua`. Console (`~`): `vtszPerf start <label>`, `vtszPerf stop` (restores functions, writes the report), `vtszPerf report`, `vtszPerf reset`.

Report lines in log.txt start with `[VTSZ-PERF]`. Columns: function | calls | calls/s | avg ms | max ms | total ms/s | alloc KB/s.
Read `total ms/s` (cost per real second) and `alloc KB/s` (garbage per second) first. `avg ms` and `max ms` are noisy.

## Rules

1. Same savegame, weather, time of day, vehicles, fill type, field, route and speed for every run. Game speed 1x. No menus during a run.
2. Wait 20 s after loading the savegame. Run 60 s. One run per case; repeat only if the result looks odd.
3. Single player (host mode, server and client in one process), one `log.txt`. Dedicated server and client runs come later, only if the console can be enabled there; the profiler reports per game instance, so those would need separate `log.txt` files.
4. No `vtszSelfTest` or `vtszNutrientDebug` during a run.

## Setup (fill in once)

| Item | Value |
|---|---|
| Savegame | |
| Field id | |
| Sprayer (widest boom) | |
| Product for P/K test | |
| Build (commit) | |

## Cases

For every case: `vtszPerf start <label>`, do the action for 60 s, `vtszPerf stop`. Copy the lines into the results table.

### D. Spreading P/K product, widest boom
Setup: sprayer with the widest boom, P/K product, filled, attached. Field with known P/K level. Auto rate on. Minimap visible.
Action: spread at normal speed, straight passes.
Expect: `vtszApplyNutrients`, `applySpray`, `addUnitsAtArea`, `VtszSprayer:onUpdate`, `vtszUpdateAutoRate`, `getAutoRateAt`, `onDraw`, `VtszMinimap:update`.
Why: the only noticeable cost in the baseline (5.4 ms/s, about 130 KB/s garbage in `applySpray`).

### H. Field info HUD
Setup: player on foot at the field edge, PF field info shown.
Action: look at the field 30 s, walk along the edge 30 s.
Expect: `NutrientMap:updateFieldInfoDisplay` (one call per nutrient map per HUD update), `field info yield hook`, `combineFactors`.
Why: the yield hook was measured (0.43 ms/s); the display rows (soil, fruit and target lookups) were never measured.

### J. Catch crop destroy (plough)
Setup: field with a catch crop that has an OM gain (`catchCropNames` in the config), growth state 2 or higher.
Action: plough the catch crop for 60 s.
Expect: `VtszNutrients:preDestroy`, `postDestroy`, `NutrientMap:addUnitsFromMask`.
Why: pre and post run density map mask passes per work area step (`preDestroy` is 10 ms/s in the baseline). The mulcher runs the same hooks at the same cost; its extra cost (about 94 ms/s) is base game code, so it is not tested here.

## Results

One row per function per run. Label: `base-<case>`, then `<change>-<case>`.

| label | case | function | calls/s | avg ms | max ms | total ms/s | alloc KB/s |
|---|---|---|---|---|---|---|---|
| base-D | D | VtszMinimap:update | 45.5 | 0.0128 | 0.135 | 0.581 | 0.00 |
| base-D | D | VtszSprayer:onDraw | 45.5 | 0.0035 | 0.112 | 0.161 | 0.00 |
| base-D | D | VtszSprayer:onUpdate (incl. vtszUpdateAutoRate) | 45.5 | 0.0397 | 0.161 | 1.808 | 9.06 |
| base-D | D | vtszUpdateAutoRate (nested, not summed) | 45.5 | 0.0061 | 0.131 | 0.277 | 0.93 |
| base-D | D | getAutoRateAt (nested, 1.7 calls per update) | 77.9 | 0.0066 | 0.188 | 0.511 | 0.48 |
| base-D | D | vtszApplyNutrients (contains applySpray) | 20.9 | 0.1600 | 0.422 | 3.347 | 165.07 |
| base-D | D | applySpray (nested, not summed) | 19.9 | 0.1599 | 0.414 | 3.186 | 165.07 |
| base-D | D | addUnitsAtArea (nested, 3 calls per spray) | 59.8 | 0.0208 | 0.169 | 1.243 | 101.39 |
| base-D | D | getUnitsForFillType (nested) | 137.7 | 0.0005 | 0.015 | 0.073 | 0.00 |
| base-D | D | getLockData (nested) | 19.9 | 0.0005 | 0.001 | 0.010 | 0.00 |
| sp1-D | D | vtszApplyNutrients (contains applySpray) | 19.3 | 0.1463 | 0.474 | 2.825 | 116.89 |
| sp1-D | D | applySpray (nested, not summed) | 18.5 | 0.1430 | 0.463 | 2.649 | 116.86 |
| sp1-D | D | addUnitsAtArea (nested, 3 calls per spray) | 55.6 | 0.0153 | 0.306 | 0.848 | 59.76 |
| sp1-D | D | VtszSprayer:onUpdate | 43.5 | 0.0408 | 0.323 | 1.773 | 7.51 |
| sp1-D | D | VtszMinimap:update | 43.5 | 0.0190 | 0.195 | 0.827 | 0.00 |
| sp1-D | D | VtszSprayer:onDraw | 43.5 | 0.0039 | 0.241 | 0.169 | 0.00 |
| base-H | H | updateFieldInfoDisplay (3 nutrient maps x 59 per s) | 177.2 | 0.0160 | 0.409 | 2.837 | 854.70 |
| base-H | H | VtszMinimap:update (idle, not part of H) | 59.1 | 0.0046 | 0.049 | 0.269 | 0.00 |
| fi1-H | H | updateFieldInfoDisplay (3 nutrient maps x 50 per s) | 150.4 | 0.0144 | 0.300 | 2.172 | 486.43 |
| fi1-H | H | field info yield hook (contains combineFactors) | 50.1 | 0.0073 | 0.197 | 0.365 | 0.00 |
| fi1-H | H | combineFactors (nested) | 50.1 | 0.0018 | 0.123 | 0.090 | 0.00 |
| base-J | J | preDestroy | 21.3 | 0.4820 | 0.908 | 10.266 | 231.60 |
| base-J | J | postDestroy (contains addUnitsFromMask) | 21.3 | 0.1323 | 0.378 | 2.818 | 64.48 |
| base-J | J | addUnitsFromMask (nested, not summed) | 21.3 | 0.0146 | 0.097 | 0.312 | 27.82 |

Sum for D without nested lines: 0.581 + 0.161 + 1.808 + 3.347 = 5.897 ms/s (`base-D`, auto rate on, 42.1 s, 2026-11-07). After spray-hot-path (`sp1-D`, 44.8 s): 0.827 + 0.169 + 1.773 + 2.825 = 5.594 ms/s.

## Decision guide

- A function under 0.5 ms/s and 10 KB/s is cheap: do not optimise it.
- High KB/s with low ms/s still loads the garbage collector (frame spikes). Judge it by `max ms` and frame time.
- After an optimisation the target lines must drop. If not, the change did not work or the wrapper cost dominates.
- Behaviour must stay the same: run `vtszSelfTest` and the test plan items of the touched area.
