# Changelog

Newest first. Version numbers follow `modDesc.xml`.

## 1.0.0 (2026-11-19)

First stable release.

- Phosphorus (P₂O₅), potassium (K₂O) and organic matter (OM) value maps for the Szalók map, 11 fertiliser products.
- P and K maps are relative: the map shows the soil state, the field info shows the crop need.
- Baled straw removes the OM that chopped straw would have added.
- Fertilising cultivators apply P/K/OM; locked against the ground spray type.
- Short map selector names, yield % in the P/K/OM legend rows.
- Fertilizing sowing machines (seeders with a fertiliser tank) support the mod's sprayer functions: P/K/OM go into the maps while sowing, the HUD shows l/ha and N / P2O5 / K2O kg/ha, manual and automatic rate work as on sprayers. Not tested in game yet.
- Own `VTSZ_RATE_*` key bindings for the application rate.
- Nutrient dose per ha stays correct with Manual Section Control; `vtszIsRateControlled` exposed for optional Manual Section Control support.
- Performance: shared field info lookups, precomputed spray noise ranges, per-tick width cache.
- Admin console commands work from a multiplayer client.
- Documentation: full player wiki in English and Hungarian.

---

## 1.0.0 (2026-11-19) – magyar

Első stabil kiadás.

- Foszfor (P₂O₅), kálium (K₂O) és szerves anyag (OM) értéktérképek a Szalók térképhez, 11 műtrágyatermék.
- A P és K térkép relatív: a térkép a talaj állapotát mutatja, a mezőinfó a növény igényét.
- A bálázott szalma elviszi az OM-et, amit az aprított szalma hozzáadna.
- A műtrágyázó kultivátorok is kijuttatják a P/K/OM-et; a talaj spray típusához zárva.
- Rövid térképválasztó nevek, hozam % a P/K/OM jelmagyarázat soraiban.
- A műtrágyázó vetőgépek (műtrágyatartályos vetőgépek) is támogatják a mod permetező funkcióit: vetés közben a P/K/OM bekerül a térképekbe, a HUD l/ha és N / P2O5 / K2O kg/ha értéket mutat, a kézi és az automatikus mennyiség úgy működik, mint a permetezőknél. Játékban még nem tesztelt.
- Saját `VTSZ_RATE_*` billentyűk a kijuttatási mennyiséghez.
- A tápanyag adag hektáronként helyes marad Manual Section Control mellett; a `vtszIsRateControlled` elérhető az opcionális Manual Section Control támogatáshoz.
- Teljesítmény: közös mezőinfó lekérdezések, előre számolt szórási zaj tartományok, tickenkénti szélesség gyorsítótár.
- Az admin konzolparancsok multiplayer kliensről is működnek.
- Dokumentáció: teljes játékos wiki angolul és magyarul.
