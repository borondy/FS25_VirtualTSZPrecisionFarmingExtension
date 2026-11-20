🇭🇺 [Magyar változat](HU-11-Forrasok)

> [!WARNING]
> **In development (v0.1, testing).** The mod is still being built and may change, even reset the nutrient maps. Always keep a backup of your savegame.

# Sources

**This page shows where the mod's numbers come from.** It is for anyone who wants to check them.

They are simplified for the game, so values are **estimates (±20–30 %)** unless marked otherwise. **(E)** marks an estimate without a source. The Hungarian manure and removal tables (Nitrát kézikönyv, 59/2008 FVM, Műtrágyázási irányelvek) were not available, so German values are used.

The titles below come from the mod's own source notes. We add a link only where we have a real, stable address. No source URLs have been collected yet, so the entries below are titles only.

## Humus and organic matter

- **VDLUFA Standpunkt "Humusbilanzierung" (2014):** humus equivalents (Häq), humus demand and gain, values for organic fertilizers. The organic matter calculation is built on this.
- **Long-term trials (Groß Kreutz):** the humus value of straw is about 55 Häq/t (the VDLUFA default is 100). The mod uses 55 for by-products.
- **Organic matter range of Hungarian soils:** loamy sand 1.8 %, sandy loam 2.5 %, loam 3.2 %, silty clay 4.0 %. Targets estimated from literature ranges (E).

## P and K removal, manure contents

- **LfL Bayern, Basisdaten (2025):** removal by cereals, maize, rapeseed, sunflower, beet and potato; table 5a gives manure nutrient contents; table 2 gives grass (0.81 kg P₂O₅ and 3.28 kg K₂O per dt dry matter, 80 dt DM/ha, at least 3 cuts).
- **Soybean:** IPNI / Ohio State (29–39 kg P₂O₅, about 57 kg K₂O at 3 t/ha yield); LfL (15 and 17 kg/t).
- **Sorghum:** Embrapa (silage maize and sorghum balance, about 5.2 kg P₂O₅ and 15.7 kg K₂O per t dry matter). The mod's value is derived from silage maize (E).
- **Alfalfa, clover:** about 6 kg P₂O₅ and 28–30 kg K₂O per t hay, 10 t hay per year, 3 cuts (E).

## Targets and supply classes

- **NAK Zsebkönyv, MÉM-NAK, Csathó:** AL-P₂O₅ and AL-K₂O supply classes. 1 mg/kg AL extract is about 4 kg/ha (0–30 cm, our own calculation).
- **Crop-dependent target (build-up plus maintenance fertilizing):** VDLUFA supply classes, Sachsen LfULG (P-Düngebedarf), Merkblatt Düngeplanung Phosphor (RLP), Mallarino (Iowa State, 2026). The K share (0.5) is a game-balance estimate.
- **Yield curves (floor 0.65):** long-term trials without P and K show 20–40 % losses. Because the server runs 3–5 times faster, this is game balance, not a measured value.

## pH, leaching, nitrogen

- **P availability and pH:** Füleky (Hungarian soils); an overview of calcareous soils (optimum pH 6.5–7.5). The percentages are estimates (E).
- **K leaching:** UK potash note (about 1.2 kg K₂O per 100 mm), a Danish study (0.6 and 8.4 kg per 100 mm at 24 and 5 % clay), 150–250 mm annual runoff. The per-soil-type values are estimates (E).
- **Nitrogen release from organic matter:** UC ANR (22–45 kg N per 1 % OM), literature +10–20 kg N per 1 % OM. The mod uses a smaller, net value.
- **Chloride (the Kálisó cap):** APNI, K+S: usual crops show no damage up to about 140 kg Cl/ha, chloride-sensitive ones up to about 675 kg Cl/ha; potato trials 115–237 kg KCl/ha. No source gives a hard single-dose limit, so the 450 l/ha cap is a lenient estimate.

## Products

- **NÉBIH product register; Nitrogénművek safety data sheets** (Pétisó 27, Nitrosol UAN 30 % N, density 1.275); distributor data sheets (MAP, TSP, Kálisó 60, NPKs, Patentkali, superphosphate, urea). Some data for superphosphate, NPK 8-24-24 and Patentkali are estimates (E).
- **Yeast vinasse:** NÉBIH (on dry matter: OM ≥ 60 %, N ≥ 3 %, P₂O₅ ≥ 0.5 %, K₂O ≥ 5 %). The dilute (60 %) grade and the OM value are estimates.
- **Sugar factory lime (CARBOLIME):** Nordzucker and AGRANA (Carbokalk) data sheets (CaO, P₂O₅, K₂O, N). The OM effect is an estimate (E).
- **Prices:** game prices scaled from estimated 2026 EU price ratios (CAN, urea and MOP as reference; the prices of MAP, TSP, SSP, Patentkali and NPK are estimates too). These are not euro prices.

## Game and Precision Farming data

- **Precision Farming** (decompiled `FS25_precisionFarming` scripts, read-only reference): `NitrogenMap.lua` (N removal, chopped straw +25 kg N, yield curve), `HarvestExtension.lua` (harvest, mowing, yield multiplier), `CoverMap.lua`.
- **Szalók `map.xml` (`<precisionFarming>`):** N targets, removals and yield potentials per crop and soil type. The 220 kg/ha nitrogen ceiling is a game rule.
- **Base game `foliage/*.xml`:** `chopperType` (crops that get +25 kg N when chopped), `maps_fruitTypes.xml`.

---
See also: [Known limitations](EN-10-Known-Limitations) · [Organic matter](EN-04-Organic-Matter) · [Phosphorus](EN-02-Phosphorus) · [Potassium](EN-03-Potassium)
