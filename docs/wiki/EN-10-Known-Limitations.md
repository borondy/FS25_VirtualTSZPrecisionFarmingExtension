🇭🇺 [Magyar változat](HU-10-Ismert-korlatok)

> [!WARNING]
> **The mod is still in development and things may change. Always keep a backup of your savegame.**

# Known limitations and FAQ

**In short:**
- Here you find what the mod does **not** do, and answers to the most common questions.
- Numbers are estimates (±20–30 %) unless marked otherwise.
- Several things are not tested yet (multiplayer, adding and removing the mod).
- Sources: [Sources](EN-11-Sources).

**Quick guide**
- Yield or nutrient numbers look odd: [Yield and nutrient levels](#yield-and-nutrient-levels)
- Stuck with application, products or nitrogen: [Application and products](#application-and-products)
- Worried about your savegame or the server: [Savegame, multiplayer, other maps](#savegame-multiplayer-other-maps)
- Want to know what the mod lacks: [What the mod does not do](#what-the-mod-does-not-do)

---

# Frequently asked questions

## Yield and nutrient levels

### Why did my yield drop although nitrogen is perfect?
Phosphorus, potassium and organic matter can each lower yield when they are below target. Of phosphorus and potassium only the scarcer one counts, and organic matter multiplies on top. The mod never gives more yield than Precision Farming (PF). Check the field info box and the three layers, where you see the information for each nutrient: [Phosphorus](EN-02-Phosphorus), [Potassium](EN-03-Potassium), [Organic matter](EN-04-Organic-Matter).

### Why is my phosphorus "low" when the map shows 0 or more?
The map shows the soil against its soil type target. On acid or strongly alkaline soil plants take up less phosphorus, so the yield factor includes the pH. The map and the number in the field info row stay the plain distance from the soil type target, and the row says "low availability (pH)" instead of "low". On loam at pH 5.5, for example, you would need about 706 instead of 600 kg/ha in the soil for full yield. Check the pH first and fix it with lime: more phosphorus does not help, and the automatic rate only fills the gap to the soil type target. Details: [Phosphorus](EN-02-Phosphorus).

### Why does the map show minus values?
The P, K and OM maps show the distance from the target of the soil type: 0 is on target, minus is a deficit, plus is a surplus. You do not see the content in the soil itself. Details: [Getting started](EN-01-Getting-Started).

### Why does organic matter drop so fast?
This is a VirtualTSZ server setting. The server runs for about one real year, which is about 6 game years. The multiplier (`timeScale` 6) exists so that the effect of organic matter loss shows up in the shorter term, within one real year: every organic matter change is 6 times larger per game year. That is why it drops faster on the VirtualTSZ server, about −0.070 percentage points per game year on loam. On another server it can be slower. The [Organic matter](EN-04-Organic-Matter) page shows what offsets it.

### Why do pixels differ after an even spread?
The mod rounds small changes randomly to a level, and the field average stays exact. That is why a soil sample can differ from its neighbour by a few steps (one step is 5 kg for P and K). This is not a bug. Details: [Technical details](EN-08-Technical-Details).

### Why can't the map go above a certain value?
The maps have an upper limit, and anything above it is lost: the P map stores at most +675 kg P₂O₅/ha above its target (and spreading stops at +300), the K map at most +675 kg K₂O/ha above its target, and organic matter at most +2.19 percentage points above its target. Keep the level around the target, more does not fit. Details: [Technical details](EN-08-Technical-Details).

## Application and products

### Why does the automatic rate spread nothing on a nitrogen-rich product?
The P/K-based automatic rate never applies more nitrogen than PF's own automatic rate would apply at that spot. Once the nitrogen target is met the rate drops to 0 and the spreader stops, even if P or K is missing. Use a nitrogen-free or P/K-rich product instead. Details: [Products and application](EN-05-Products-and-Application).

### Why does the second product's nitrogen not show on the nitrogen map?
The PF nitrogen map locks by the soil's spray type, and all shop products use the same one (`FERTILIZER`). If you spread two nitrogen-containing products on the same pixel without tillage in between, the nitrogen of the second is expected not to reach the PF nitrogen map. On the mod's own P, K and OM maps both products count. We left this unsolved on purpose, because a separate spray type per product would cost a lot of performance.

If you need it anyway, you can clear the soil's `FERTILIZER` state between two passes with the `clearFertilizerState` admin command of the [FS25_NotSoEasyDeveloperControls](https://github.com/borondy/FS25_NotSoEasyDeveloperControls) mod. The `FERTILIZER` state is what you have to look for in Easy Development Controls. See [Products and application](EN-05-Products-and-Application).

### Why does the automatic rate differ from the value I want?
PF handles nitrogen in 5 kg N/ha steps. For products that contain nitrogen the automatic rate can therefore be off by about ±16–30 l/ha (NPK 15-15-15: one step is about 32 l/ha, NPK 8-24-24: about 60 l/ha).

### Why does the application rate reset after loading?
The mod does not save the manual rate; this is intentional. After saving and loading it returns to the product's default. Set it again with the keys (Left Alt + K and Left Alt + M). See [Products and application](EN-05-Products-and-Application).

### What about large Potassium chloride 60 MOP rates?
The amount of Potassium chloride 60 MOP per pass is held by a lenient, estimated cap (450 l/ha). For chloride-sensitive crops (potato, vegetables) split larger needs over two passes or use Patentkali, because the mod has no per-crop chloride sensitivity.

### What happens if I add or remove a product?
The product IDs shift, and the saved product lock holds the old IDs. One pass may therefore be off: a pixel can receive one application too many or too few. The mod handles at most 31 products.

## Savegame, multiplayer, other maps

### Will it break my savegame?
Not likely, but we cannot rule it out. The mod writes its own map files into the savegame folder (`vtsz_pMap8.grle`, `vtsz_kMap8.grle`, `vtsz_omMap8.grle`, `vtsz_productMap.grle`) and affects yield. Phosphorus and potassium used to be stored in a different format (`vtsz_pMap.grle`, `vtsz_kMap.grle`); a savegame from such an older version starts the P and K maps again from the starting values. Adding the mod to an existing savegame and removing it again are not tested yet. A later version may reset the maps. Do not use it on a valuable savegame without a backup.

### Does it work in multiplayer?
By design yes: only the server calculates and clients see the same maps. According to `TESTS.md` this has not been checked in game yet, and client permissions for console commands are untested too. Expect bugs.

### Can I use it on another map?
In principle yes, but we have not tried another map yet. The mod takes the map size from the PF soil map and skips unknown crops and products. Values tuned for Szalók (targets, 3 cuts per year) need a review: [For map makers](EN-07-For-Map-Makers).

### How do I check that the mod works?
If the new nutrients appear in the Precision Farming view and in the field info, the mod probably works. For the command-level test see the [Console commands](EN-09-Console-Commands) page.

---

# Limitations

## What the mod does not do

These are deliberate simplifications or missing parts, not bugs.

| Topic | What is the situation |
|---|---|
| Phosphorus leaching | None. The P level changes only through application and harvest. (Potassium does leach, and organic matter does decompose.) |
| Absolute content on the map | The maps show the distance from the target, not the content in the soil. The help page shows the removal per crop (also with baled straw or a forage harvest where that differs), no targets. A second page lists the content of every fertilizer per 1000 l. |
| Tillage and organic matter | Tillage does not speed up decomposition. Incorporating or mulching catch crops does add organic matter, though. |
| Nitrogen losses | None (leaching, denitrification). PF does not model them either, so unused nitrogen stays on the map. The mod only adds the nitrogen released by decomposing organic matter to the PF nitrogen map. |
| Nitrogen fixation by alfalfa | Not modelled, and PF does not model it either. In the example rotations, slurry after each cut makes up for it. |
| Chloride sensitivity | None per crop, see the Potassium chloride 60 MOP answer above. |
| Sulphur and magnesium | None. Patentkali and superphosphate carry them, but they have no effect in the game. A new nutrient map is not planned for now. |
| Hungarian humus table | None. Organic matter uses the German VDLUFA humus balance method, because the Hungarian tables (Nitrát kézikönyv, 59/2008 FVM, Műtrágyázási irányelvek) were not available. |

## Game rules, not reality

Here the mod deliberately differs from reality so the game works.

- **Map caps.** For the upper limits of the P, K and OM maps see the FAQ above. Anything beyond them is lost.
- **The 220 kg N/ha ceiling of the nitrogen map.** On Szalók the PF nitrogen target is at most 220 kg N/ha and more nitrogen does not fit on the map. In the manure examples this limits how much manure is useful (see [Crop rotations](EN-06-Crop-Rotations)).
- **The fast time scale of the server.** The numbers are tuned for the VirtualTSZ server's `timeScale` 6, and the balance has not been reviewed with server experience yet. The numbers may change.

## What is still open

- **Multiplayer** and client permissions for console commands: not fully tested yet.
- **Adding and removing the mod** on an existing savegame: not tested.
- **Part of the test list is still open.** Application, harvest and most calculations are confirmed by `vtszSelfTest`, but many in-game checks (for example save and load, removing the mod, products in the shop) have not been run yet.

---
See also: [Phosphorus](EN-02-Phosphorus) · [Products and application](EN-05-Products-and-Application) · [Technical details](EN-08-Technical-Details) · [Sources](EN-11-Sources)
