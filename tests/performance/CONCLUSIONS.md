# Performance conclusions

Measured 2026-11-03 with `scripts/VtszProfiler.lua` (console `vtszPerf`), single player, Szalók map, about 50 fps. Raw numbers and the test procedure: `PerfTests.md` in this folder.

## Result

The mod is cheap. While spreading, all VTSZ code together costs about 5.4 ms of CPU per real second (about 0.5 % of one core). Idle and harvest cost under 0.5 ms/s. No optimisation work (TODO.Perf.1-4) is worth its risk. Decision: stop, change no mod code for performance.

## Baseline per case

| Case | Total ms/s | Alloc KB/s | Verdict |
|---|---|---|---|
| B. Tractor without sprayer | 0.29 | 0 | cheap |
| D. Spreading P/K, widest boom | 5.4 | about 130 | the only noticeable cost, still small |
| H. Field info HUD | 0.43 | 10 | cheap |
| G. Harvesting, chopper off | 0.32 | 9 | cheap |

Threshold used: under 0.5 ms/s and under 10 KB/s per function = not worth optimising.

## Per TODO

| TODO | Status | Reason |
|---|---|---|
| Perf.1 minimap controller | dropped | 0.29 ms/s idle, 0.74 ms/s with a loaded sprayer, 0 KB/s. `Vehicle:getChildVehicles()` returns a cached table, so the "allocates every frame" claim was wrong. |
| Perf.2 sprayer HUD and auto rate | optional, not planned | `onUpdate` 1.2-1.4 ms/s, 3.5-4.5 KB/s; `onDraw` 0.2 ms/s, 0 KB/s. |
| Perf.3 spreading hot path | reduced to optional | `applySpray` 2.6-2.8 ms/s, 126-136 KB/s. Only `addUnitsAtArea` (0.75 ms/s, 57 KB/s) is Lua work we can touch. About 1.8 ms/s and 70 KB/s sit in engine density map calls (`applyToModifier`, `setValueCompareParams`, `executeSet`) that Lua cannot reduce without changing behaviour. The work-area width loop is about 0.2 ms/s. Possible small win: scratch array instead of `unitsByMap`, precomputed noise ranges, at most about 30 KB/s. |
| Perf.4 harvest and yield hook | dropped | Field info hook 0.43 ms/s, 9.7 KB/s; harvest path 0.32 ms/s, 9 KB/s. |
| Perf.5 measure | done | Profiler built and kept as a dev tool. |

## When to look again

- Frame hitches while spreading: GC pressure from `applySpray` (about 126 KB/s) is the first suspect. Implement the small Perf.3 items, then re-run case D and compare `alloc KB/s` of `applySpray`.
- A new feature adds work to a per-frame or per-tick path: re-run the four cases and compare with the baseline.
- Re-run all four cases after major changes to spreading, harvest or the minimap.

## Limits of the data

- One run per case, 57-98 s each, one savegame. Differences under about 20 % are noise.
- The wrapper adds a small cost of its own, so values compare runs; they are not absolute.
- `alloc KB/s` sums positive Lua heap growth per call. It misses garbage freed during the call and any native memory.
- Host mode only. Dedicated server and multiplayer clients not measured.
- Case H first run lost the field info hook line (profiler bug, fixed); the second run is the one recorded.
