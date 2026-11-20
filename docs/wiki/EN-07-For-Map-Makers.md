🇭🇺 [Magyar változat](HU-07-Terkepkeszitoknek)

> [!WARNING]
> **In development (v0.1, testing).** The mod is unstable: expect bugs, and expect changes that may reset the nutrient maps in your savegame. Do not use it on a savegame you cannot afford to lose.

# For map makers

**You can override the mod's settings from your map's `map.xml`, without editing the mod's own files.**

- Write only what differs from the defaults; everything else comes from the mod.
- You can change targets, starting values, crop removal and the nutrient content of products.
- It has not been tried on other maps: Szalók is the only tested map.
- Do not change the bit depth on a savegame that has already been played.

As a player you do not need this page: [Getting started](EN-01-Getting-Started) is enough.

## Can I use it on my map?

The mod needs two other mods, both required: **Precision Farming** (`FS25_precisionFarming`) and the **TR PF Configurator** (`FS25_0_TRPFConfigurator`). The mod takes the map size from the Precision Farming soil map and has no fixed size built in. If the soil map is not 2048 × 2048, the mod uses that size and writes a warning to the log (2048 is the expected size with TR).

**It is tested on one map only: Szalók.** We have not tried any other map, so expect bugs and unknown behaviour there. What is specific to Szalók:

- **The config values were made for Szalók**: targets and starting values for four soil types (1 = Loamy Sand, 2 = sandy loam, 3 = loam, 4 = silty clay), and removal values for the crops grown on Szalók. The nitrogen targets and nitrogen removal do not come from the mod, they come from the map's own Precision Farming block.
- **CARBOLIME** is a Szalók product (sugar factory lime sludge). On other maps its config row is ignored.
- **3 cuts a year** for grass, alfalfa and clover (that is how we farm on the server). For these crops, removal and OM gain are per-cut values. If your map uses a different number of cuts, recalculate (see below).
- **`timeScale` 6** for organic matter: on the VirtualTSZ server about 6 game years pass per real year, and the OM values are scaled to match.

What the mod **skips automatically** on other maps:

- a product in the config (`fillType`) that does not exist on that map (for example CARBOLIME),
- a crop (`fruitRequirement`) that the map does not know,
- a catch crop in the `catchCrops` list that is not on the map.

These cause no error, the mod skips them. The log line only appears at the developer log level (`Logging.devInfo`), so you may not see it in a default `log.txt`: `[VTSZ-NUT] P: fill type 'CARBOLIME' does not exist on this map, ignored`, `[VTSZ-NUT] P: unknown fruit type '...' in fruitRequirements, ignored`, `[VTSZ-NUT] catch crop fruit type '...' does not exist on this map, ignored`.

**What it does not skip, but handles through the `DEFAULT` row:** if your map adds a crop that has no `fruitRequirement` row, the mod uses the default row. The default removal is 50 kg P₂O₅ for phosphorus (straw +12), 50 kg K₂O for potassium (straw +80), and 0 for organic matter. These are generic values, not measured for any particular crop: write rows for your map's own crops (see the recipes below).

## How do you override the settings?

The mod reads configuration twice, in this order:

1. its own `config/NutrientMaps.xml` (the defaults),
2. the `<vtszNutrients>` block in the map's `map.xml`, if there is one (under the `<map>` root).

The map block uses the same structure as the mod config, and you only write what differs. Example: the phosphorus target for loam (soil type 3) is 400 instead of 600.

```xml
<map ...>
  <vtszNutrients>
    <nutrientMaps>
      <nutrientMap id="P">
        <targets><target soilTypeIndex="3" value="400"/></targets>
      </nutrientMap>
    </nutrientMaps>
  </vtszNutrients>
</map>
```

The `id` is `P`, `K` or `OM`. The mod always reads its own config first, so you do not have to copy everything, and values you leave alone follow mod updates.

> [!NOTE]
> Do not edit the mod's `config/NutrientMaps.xml` for your map: a mod update overwrites it. Map settings belong in your `map.xml`.

## What stays and what gets replaced (merge rules)

Each rule was verified against the code.

### Merged per entry

An entry in the map replaces the mod's entry with the same key. All other entries stay.

| Element | Key | What stays if you do not set it |
|---|---|---|
| `target` | `soilTypeIndex` | the targets of the other soil types |
| `initialValue` | `soilTypeIndex` | the starting values of the other soil types; for that soil type, the 4 noise values are replaced **as a whole** |
| `fruitRequirement` | `fruitTypeName` | any attribute you do not set, **attribute by attribute** (write only `removal` and `removalStraw` stays) |
| `fillType` | `name` | the rows of the other products; in the row you write, a missing `value` becomes 0, it does not keep the old one |
| `leaching` / `rate` | `soilTypeIndex` | the leaching of the other soil types |
| `mineralisation` | attribute by attribute | an unset `rate`, `nPerPercent` or `weights` stays |
| `minimap` / `product` | `fillType` | the rows of the other products |
| `autoBaseDefault` / `product` | `fillType` | the rows of the other products |
| `rateControl` / `product` | `fillType` | the rows of the other products; **in the row you write, a missing attribute does not keep the old value** but gets the fallback: `default` 100, `step` 10, `min` 10, `max` 1500 |
| `balance`, `autoRate`, `baseFertilizer` | attribute by attribute | an unset attribute stays |

The attributes on the `nutrientMap` element itself (`step`, `timeScale`, `legendMin` …) are also kept one by one when you do not set them.

### Replaced as a whole when present

- **`<yieldMappings>`**: if your map writes a `yieldMapping` block, it must give **all** keys (the mod's series is dropped).
- **`<phEfficiency>`** (pH efficiency of the P map): the whole key series is replaced in the same way.
- **`<catchCrops fruitTypes="…">`**: the whole catch crop list is replaced (names separated by spaces).

### The 12-value weights

`leaching#weights` (K) and `mineralisation#weights` (OM) are seasonal weights, 12 values, the first one is March. **They only count if you give exactly 12 numbers.** Any other count is silently ignored, without an error message, and the mod's value stays. The mod normalises the sum to 1 and treats a negative value as 0, so the ratio matters, not the sum.

### Global blocks

These do not belong to one `nutrientMap`: `<balance>`, `<autoRate>`, `<baseFertilizer>`, `<catchCrops>`, `<minimap>`, `<autoBaseDefault>`, `<rateControl>`. They apply to all three maps (P, K, OM) and go directly under `<vtszNutrients>`, next to `<nutrientMaps>`. Written inside a `<nutrientMap id="P">` they have no effect.

### Catch crop priority

If the map's `map.xml` contains a Precision Farming `coverCropBonus` list (`<precisionFarming><subsidies><coverCropBonus><fruitType name="…"/>`), it **takes priority** over any `<catchCrops>` block, the mod's own and the one in your `vtszNutrients` block. The mod reads it when it loads the P map. If the list is empty or missing, the `catchCrops` list applies. The OM gain of a catch crop is the `destroyGain` of its `fruitRequirement`; without one, the OM map default `catchCropGain` applies (0.008 in the mod, a real-time value, multiplied by `timeScale` in game).

## What you will most likely change (recipes)

### Targets and starting values for your soil types

Targets are under `targets`, per soil type (P and K in kg/ha, OM in %). Starting values fill the pixels the first time the map starts, with four noise values so that a field is not perfectly uniform:

```xml
<nutrientMap id="P">
  <initialValues>
    <initialValue soilTypeIndex="1" deltas="-95 -45 5 55"/>
  </initialValues>
  <targets>
    <target soilTypeIndex="1" value="420"/>
  </targets>
</nutrientMap>
```

- All three maps are **relative**: they store the distance from the soil type target, and `0` is the target. Give starting values as `deltas`: kg/ha from the target for P and K (for example `-95 -45 5 55`), percentage points for OM (for example `-0.8 -0.2 0.4 0.8`). If you give fewer than four numbers, the last one is repeated. `levels` are raw stored levels (on a relative map 120 = on target); `deltas` is easier.
- The `target` is still needed: it is the zero of the map, and it drives the pH effect on P, the OM decomposition and the nitrogen release. Changing a target moves what `0` means in soil content.
- The config keeps the worst start at −150 kg/ha for P and −180 kg/ha for K (yield factor about 0.91 for both) and at −0.8 percentage points for OM (0.92), so no map starts below 0.90.
- The stored range is −600 … +675 kg/ha for P and K (256 levels of 5 kg, `levelOffset` 120). The −600 end is where the yield factor reaches its floor of 0.65. P also has a soft cap, `maxUnits` 300: spreading never raises a pixel above +300. Keep it above +260, because loam at pH 5.0 needs +257.
- Give a `target` row for every soil type index your map uses. The code treats a missing target as "no value"; what exactly happens for a soil type you left out is not tested.

### Removal for crops your map adds

Every P and K `fruitRequirement` is the removal of the main product in kg at a typical yield (`removal`), plus the removal of baled straw (`removalStraw`). For OM the value is in percentage points, and there are `gain` (at harvest) and `strawGain` (for chopped straw). Example for a new crop (the numbers only illustrate, they are not measured values):

```xml
<nutrientMaps>
  <nutrientMap id="P">
    <fruitRequirements>
      <fruitRequirement fruitTypeName="MYCROP" removal="50" removalStraw="12"/>
    </fruitRequirements>
  </nutrientMap>
  <nutrientMap id="K">
    <fruitRequirements>
      <fruitRequirement fruitTypeName="MYCROP" removal="80" removalStraw="60"/>
    </fruitRequirements>
  </nutrientMap>
</nutrientMaps>
```

Take the real values from a source (the sources of the mod are on the [Sources](EN-11-Sources) page). The comments in the config say where each value comes from and where it is an estimate.

### Cut count for grass, alfalfa and clover

In the config, the values for grass, alfalfa and clover are **per cut**, sized for **3 cuts a year** (VirtualTSZ practice). If your map has a different number of cuts, recalculate:

- removal = yearly removal / number of cuts,
- OM gain = (600 + 280) × 0.0000417 / number of cuts.

400 is the net humus gain of perennial forage and 280 is the humus demand of cereals (Haeq/ha/year); 1 Haeq is 0.0000417 percentage points. With 3 cuts the gain is 0.00944 percentage points per cut (the config value). Example with 4 cuts, for grass: the config derives the yearly removal from 0.81 kg P₂O₅ and 3.28 kg K₂O per dt dry matter × 80 dt DM/ha, that is 64.8 P₂O₅ and 262.4 K₂O, divided by 4: 16.2 P₂O₅ and 65.6 K₂O per cut. The OM gain is (400 + 280) × 0.0000417 / 4, about 0.00709 percentage points.

### `timeScale`

`timeScale` on the OM `nutrientMap` multiplies every OM change (decomposition, removal, gain, catch crops, OM from organic fertiliser). The default is 6. If your server runs at a different speed, change it: 1 is real time. It does not scale the target, `nPerPercent` or the map step.

```xml
<nutrientMap id="OM" timeScale="1"/>
```

### `baseFertilizer`

The base game FERTILIZER gives **nitrogen only** by default, as in Precision Farming; P and K come from the mod's products. To also switch on its P and K content (300 l/ha gives +36 kg P₂O₅ and +36 kg K₂O; the config has 120/120 kg per 1000 l):

```xml
<baseFertilizer enabled="true"/>
```

### New products under `fillTypes`

The nutrient content of an existing fill type (for example a potash product from another mod) comes from the `fillTypes` rows of the P and K `nutrientMap` (kg of nutrient per 1000 l of product; for OM percentage points per 1000 l per ha). You can compute it from the product density: kg per 1000 l = density (t / 1000 l) × 1000 × nutrient share.

```xml
<!-- example: a product with density 1.0 t / 1000 l and 60 % K2O: 1.0 × 1000 × 0.60 = 600 -->
<nutrientMap id="K">
  <fillTypes>
    <fillType name="MYPRODUCT" value="600"/>
  </fillTypes>
</nutrientMap>
```

Things to watch:

- A new **solid** product shares the fill plane of FERTILIZER, and its name must also go into the `SOLID_PRODUCTS` list in `scripts/VtszNutrients.lua`. That is a change in the mod code, so it works only for the mod's own products (or in your fork), not from a map's `map.xml`.
- If a product without nitrogen needs its own application rate, add it to the `<rateControl>` list (`default`, `step`, `min`, `max` in l/ha).
- Adding or removing a product shifts the saved product IDs; for one pass the product lock can be wrong. Details: [Technical details](EN-08-Technical-Details).

### Catch crops

The OM gain of a catch crop is `destroyGain` in the OM `fruitRequirement` row. Without a row, the OM `catchCropGain` applies (0.008, multiplied by `timeScale`). If the map has a Precision Farming `coverCropBonus` list, it takes priority over the mod's `catchCrops` list (see above).

## Attributes and global blocks

<details>
<summary><strong>Attributes of the <code>nutrientMap</code> element</strong></summary>

| Attribute | Meaning | P | K | OM |
|---|---|---|---|---|
| `id` | `P`, `K` or `OM` | P | K | OM |
| `numChannels` | bit depth (the save file name depends on it) | 8 | 8 | 8 |
| `step` | value of one level in the map's unit | 5 | 5 | 0.0243137 |
| `unitFormat` | display format | `%+d kg/ha P2O5` | `%+d kg/ha K2O` | `%+.2f %%` |
| `legendMin`, `legendMax` | legend window (default 8 colour bands, `numBands` sets another count, K uses 15) | −300 / 100 | −600 / 300 | −1.4 / 0.2 |
| `surplusFrom` | with `surplusColors`: where green ends and the blue surplus colour starts (K: 200, the start of the oversupply penalty) | 0 | 200 | 0 |
| `levelOffset` | integer, ≥ 0. If > 0 the map is relative (stored around the target): value = (level − `levelOffset`) × `step` | 120 | 120 | 165 |
| `maxUnits` | soft cap in map units: spreading and `vtszNutrientSet` never raise a pixel above it. Without it only the stored maximum limits | 300 | none | none |
| `strawChopperGain` | OM/P/K gain for chopped straw (default: the crop's `strawGain`) | 0 | 0 | 0 |
| `catchCropGain` | catch crop gain (default: the crop's `destroyGain`) | 0 | 0 | 0.008 |
| `yieldScaling` | how strongly the harvest change follows the yield (1 full, 0 fixed) | 1 (default) | 1 (default) | 0.5 |
| `timeScale` | time multiplier of all changes, ≥ 0 | 1 (default) | 1 (default) | 6 |
| `targetRemovalShare` | crop target = soil target × `targetScale` + this × main product removal, ≥ 0. On a relative map the map shows the soil only, and this part is the crop's extra over the soil target. The default config uses 0 for P and K, so the target is the soil type target for every crop | 0 (default) | 0 (default) | 0 (default) |

`yieldScaling` and `timeScale` are not written on the P and K maps in the config, so the defaults apply (`yieldScaling` 1, `timeScale` 1).

</details>

<details>
<summary><strong>Attributes of the <code>fruitRequirement</code> element</strong></summary>

| Attribute | Meaning |
|---|---|
| `fruitTypeName` | crop name; the `DEFAULT` row applies to crops without their own row |
| `removal` | removal of the main product at a typical yield (P, K: kg/ha; OM: percentage points) |
| `removalStraw` | extra removal when the straw leaves the field (not chopped) |
| `forageRemoval` | for forage harvesting / mowing the OM change is −(max(`removal`, `forageRemoval`) + `removalStraw`), with no gain |
| `gain` | gain per harvest (OM) |
| `strawGain` | gain instead of `removalStraw` when the straw chopper is on (default: `strawChopperGain`) |
| `destroyGain` | gain when the catch crop is ploughed in (default: `catchCropGain`) |
| `targetScale` | multiplier of the soil target for this crop (default 1); on a relative map the crop's extra over the soil target is target × (`targetScale` − 1) |
| `targetRemovalShare` | this crop's own share in the target (overrides the map value) |

The default of an unset `removal` and `removalStraw` is 0, and of `targetScale` it is 1.

</details>

<details>
<summary><strong>Map-level elements under <code>nutrientMap</code></strong></summary>

| Element | Attributes | Default in the config |
|---|---|---|
| `initialValues/initialValue` | `soilTypeIndex`, `deltas` (distance from the target: kg/ha for P and K, percentage points for OM) or `levels` (raw stored levels, only for a map without `levelOffset`) | see the config; P loam −150 −75 0 75, K loam −180 −100 20 100 |
| `targets/target` | `soilTypeIndex`, `value` | P 420/500/600/460, K 500/700/740/820, OM 1.8/2.5/3.2/4.0 |
| `yieldMappings/yieldMapping` | `difference`, `yieldFactor` (linear between keys) | see the config |
| `phEfficiency/key` (P only) | `ph`, `value` (clamped to 0.3–1, sorted by pH; outside the range the first / last value holds) | 5.0 → 0.70 … 6.2–7.2 → 1.00 … 8.2 → 0.80 |
| `fruitRequirements/fruitRequirement` | see above | see the config |
| `fillTypes/fillType` | `name`, `value` (kg per 1000 l; OM: percentage points per 1000 l) | see the config |
| `leaching` (K only) | `weights` (12 values), `rate`: `soilTypeIndex`, `value` (kg K₂O/ha/year) | weights 0.16 0.12 0.08 0.06 0.03 0.02 0.03 0.06 0.10 0.11 0.11 0.12; rates 40/25/15/10 |
| `mineralisation` (OM only) | `rate` (yearly loss as a fraction of the target), `weights` (12 values), `nPerPercent` (kg N/ha/year per 1 % OM) | 0.00365; weights 0.06 0.09 0.11 0.13 0.15 0.15 0.12 0.08 0.05 0.02 0.02 0.02; 8 |

Leaching only affects content at or above the soil type target (0 or more on the map). Leaving out the `leaching` block in a map's `map.xml` does not switch leaching off, because the mod config is loaded before the map and stays. To switch it off, have the map give the `rate` values as 0. `rate="0"` in `mineralisation` switches off OM decomposition and the nitrogen release.

</details>

<details>
<summary><strong>Global blocks</strong></summary>

| Block | Attributes | Default | Effect |
|---|---|---|---|
| `<balance>` | `inputScale`, `removalScale`, `yieldReference` | 1, 1, 1.5 | `inputScale`: application, harvest gain, catch crop gain. `removalScale`: harvest removal, OM decomposition and the nitrogen it releases, K leaching, the crop part of `targetRemovalShare` (0 stops decomposition and nitrogen release too). `yieldReference`: the Precision Farming yield multiplier the removals are meant for; 0 switches yield scaling off |
| `<autoRate>` | `maxLitersPerHa` | 2500 | upper limit of the automatic P/K rate (l/ha). The rate itself is the gap to the target shown in the field info box, with no build-up time and no harvest removal |
| `<baseFertilizer>` | `enabled` | false | P and K content of the base game FERTILIZER |
| `<catchCrops>` | `fruitTypes` | OILSEEDRADISH MUSTARD HUMUSACTIVE FLOWERINGCATCHCROP | list of catch crops (separated by spaces) |
| `<minimap>` | `product`: `fillType`, `map` (`N`, `P`, `K`, `OM`) | MANURE, LIQUIDMANURE, DIGESTATE → N | minimap layer while spreading; by default the nutrient with the largest content in the product |
| `<autoBaseDefault>` | `product`: `fillType`, `base` (`N`, `P`, `K`) | MANURE, LIQUIDMANURE, DIGESTATE → N | base nutrient of the automatic rate |
| `<rateControl>` | `product`: `fillType`, `default`, `step`, `min`, `max` (l/ha) | TSP46 230/25/10/800, SSP18 240/25/10/800, KALISO60 230/25/10/450, PATENTKALI 210/25/10/800 | own application rate for products without nitrogen |

Fill type names are not case sensitive (the mod converts them to upper case).

</details>

## Save files

The maps are saved in the savegame folder as `.grle` files:

| Map | File |
|---|---|
| Phosphorus (P) | `vtsz_pMap8.grle` |
| Potassium (K) | `vtsz_kMap8.grle` |
| Organic matter (OM) | `vtsz_omMap8.grle` |
| Last applied product (product lock, 5 bit, server only) | `vtsz_productMap.grle` |

The file name depends on the bit depth: `vtsz_<id>Map.grle` at 5 bit, `vtsz_<id>Map<bit>.grle` at any other depth (hence `vtsz_pMap8`, `vtsz_kMap8` and `vtsz_omMap8`). Earlier versions stored P and K at 5 bit (`vtsz_pMap.grle`, `vtsz_kMap.grle`, absolute values). Those files are ignored now, so a savegame from an older version starts the P and K maps again from the starting values.

> [!WARNING]
> Changing `numChannels` **starts a new map**: the mod does not find the old file saved at the old depth, so the map starts from the `initialValues` and the players' P/K/OM state is lost. The same happens if the saved map has a different size from the Precision Farming soil map: the mod rebuilds the map from the starting values. Do not change the bit depth on a savegame that has been played.

![Screenshot coming soon: log.txt excerpt with the three [VTSZ-NUT] map lines (P, K, OM) at map load](images/placeholder-map-makers-log-lines.jpg)

On loading you should see three lines in `log.txt`, one per map, for example `[VTSZ-NUT] P map 2048 x 2048, 8 bit, step 5, new` (new map) or ending in `loaded from savegame`.

See also: [Getting started](EN-01-Getting-Started) · [Technical details](EN-08-Technical-Details) · [Console commands](EN-09-Console-Commands) · [Known limitations](EN-10-Known-Limitations)
