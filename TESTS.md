# VirtualTSZ PF Extension – teljes tesztlista

Jelölés: `[ ]` nincs lefuttatva, `[x]` OK, `[!]` hiba (írd mellé a log sort / leírást).
`_(auto)_` = a `vtszSelfTest` log igazolja (config és számítás szint). A valódi gépes szórás/aratás (`vtszSelfTest world`, kézi) külön marad.
Alap: Szalók térkép, FS25_precisionFarming + FS25_0_TRPFConfigurator aktív, a mod deploy-olva (`deploy.ps1`).
Segéd: `vtszNutrientDebug on`, `vtszNutrientSet <fieldId> <P|K|OM> <távolság a céltól>` (P, K: kg/ha, OM: %-pont; −120 = 120-szal a cél alatt); log: `log.txt`, prefix `[VTSZ-NUT]`.
A P, K és OM térkép **relatív** (TODO.23): a tárolt érték a talajtípus céljától mért távolság, a 0 minden talajtípuson a cél. Az alábbi `[ ]`-re visszaállított pontok a relatív P/K átállás miatt újratesztelendők; a `vtszSelfTest relative|config|ph|auto|ui|yield` az új számítási szintet fedi.

## 0. Előkészítés
- [x] 0.1 Játék indul, mod listában látszik, nincs hiányzó függőség hiba
- [ ] 0.2 Új mentés indítása Szalókon (PF + TR bekapcsolva)
- [x] 0.3 `vtszNutrientDebug on` fut, nincs "unknown command"
- [ ] 0.4 Mentés nélküli PF/TR esetén (opcionális): a mod nem omlik össze, érthető hibaüzenet

## 1. Betöltés, log
- [ ] 1.1 Log: `[VTSZ-NUT] P map 2048 x 2048, 8 bit, step 5, new` (K: 8 bit, step 5; OM: 8 bit, step 0.0243) – a térképméret a PF soilMap-jéből jön
- [x] 1.2 Log-ban nincs `Error` / `Warning` a `VTSZ` vagy `NutrientMap` kapcsán
- [ ] 1.3 Nincs hiányzó l10n kulcs (`vtsz_...`) figyelmeztetés, EN és HU nyelven is
- [ ] 1.4 Betöltés `config/NutrientMaps.xml`-ből, map.xml `<vtszNutrients>` felülírás működik (pl. egy target módosítása → új érték látszik)
- [ ] 1.5 Új mentés: a kezdőértékek soilType szerint helyesek (P/K/OM `initialValues`, mind `deltas`: távolság a céltól; P kb. −150 … +75, K kb. −180 … +100, OM −0,8 … +0,8), mezőnként zaj szerint 4 szint; a legrosszabb kezdő hozamtényező P/K-nál ≥ 0,80, OM-nél ≥ 0,90 _(auto: `vtszSelfTest config`, `.initialFactor`)_

## 2. PF térképválasztó és megjelenítés
- [x] 2.1 ESC > Térkép > PF választó: Foszfor, Kálium, Szervesanyag a Vetőmag-mennyiség után, a rejtett tramlineMap előtt
- [x] 2.2 A választó címkék rövidek, nem csúsznak ki (EN + HU)
- [x] 2.3 A többi PF réteg (N, pH, vetőmag, stb.) továbbra is váltható, sorrend/valueMapIndex nem tört
- [x] 2.4 Talajmintavevővel mintavétel után a P/K/OM rétegek megjelennek piros-sárga-zöld jelmagyarázattal
- [ ] 2.5 Jelmagyarázat ablaka (config `legendMin`-`legendMax`): P −300…+100 kg P2O5/ha, K −600…+300 kg K2O/ha (15 sáv, +200-ig zöld, csak fölötte kék), OM −1,4…+0,2 %-pont, mind a céltól (három relatív térkép; a térkép színe szintenként folytonos átmenet, a jelmagyarázat 8 sávja a sáv közepének színe)
- [ ] 2.5b ESC térkép, PF oldal: a választó rövid neveket mutat (P2O5, K2O, SzA), a jelmagyarázat sorai tartományt + hozamváltozást %-ban (pl. `-120 - -80 kg/ha  -4 %`), a szöveg nem lóg ki a sorból
- [x] 2.6 Mintavétel nélküli mezőn a réteg üres/nem felfedett
- [ ] 2.7 Mezőinfó sorok: `Foszfor (P2O5, a céltól): -75 kg/ha P2O5`, K ugyanígy (`Kálium (K2O, a céltól)`); OM: `%+.2f %%` (pl. −0,32 %). A K sora egyetlen szám (pl. `-120 kg/ha K2O`). A P sora is egyetlen szám, a talajcéltól mért egyszerű távolság (pl. `-150 kg/ha P2O5`), nincs perjel és nincs második szám. Szín a hozamtényezőből: zöld ≥ 0,99, sárga 0,90…0,99, piros alatta
- [ ] 2.7b A P és a K sora növénnyel és növény nélkül is egyetlen szám (nincs második szám); a pH a színt és a hozamtényezőt változtatja, a számot nem; ha a talaj a célon vagy fölötte van, de a hozamtényező csak a pH miatt < 0,99, a sor kiegészítő szövege `alacsony felvehetőség (pH)` (sárga ≥ 0,9, piros figyelmeztetéssel < 0,9)
- [x] 2.8 Szövegek: "very low / low / ..." besorolás a célhoz képest helyes
- [x] 2.9 Mezőinfó nem tartalmaz hibás nFactor/yieldPotential értéket (PF infoBox működik, nincs Lua hiba)
- [x] 2.10 Mezőn kívül állva nincs mezőinfó hiba
- [ ] 2.11 Egységek: a jelmagyarázat előjeles `+100 kg/ha P2O5` / `-200 kg/ha K2O`, a mezőinfó "Foszfor (P2O5, a céltól)" / "Kálium (K2O, a céltól)" (HU: "a céltól"), sehol nincs "kg/ha P" vagy "kg/ha K" oxid nélkül; a választó és a minimap neve rövid marad
- [ ] 2.12 Relatív réteg mind a 4 talajtípuson (agyagos homok, homokos vályog, vályog, iszapos agyag): `vtszNutrientSet <mező> P 0` és `K 0` után a térkép színe a célon ugyanaz a zöld mind a négy talajtípuson; −100-nál sárga, −300 / −400 alatt piros; a jelmagyarázat mínusz és plusz értékeket mutat (nincs abszolút kg/ha érték)
- [ ] 2.13 Mezőinfó K sor: cukorrépával vetett mezőn `vtszNutrientSet <mező> K -120` után a sor `-120 kg/ha K2O` (nincs második szám, a K cél növénytől független), búzán ugyanez; a P sora ugyanígy egyetlen szám _(a számítás: `vtszSelfTest relative`)_

## 3. Konzol parancsok
- [ ] 3.1 `vtszNutrientSet 1 P -120` → mezőinfó `-120 kg/ha P2O5` (a P érték **relatív**: kg/ha a talajcéltól, a konzol válasza `P of field 1 set to -120 kg/ha P2O5 (level 96)`)
- [ ] 3.2 `vtszNutrientSet 1 K -200`, `vtszNutrientSet 1 K 150`, `vtszNutrientSet 1 OM 0.5` (0,5 a cél fölött) működik; a K és a P érték ugyanúgy a céltól mért távolság, mint az OM
- [ ] 3.3 Határérték: P > +300 → levágva +300-ra (lágy plafon, `maxUnits`); K > +675 vagy < −600 → levágva a tárolt tartományra; OM > +2.19 vagy < −4.01 a céltól → levágva a tárolt tartományra; a válasz üzenet a levágott értéket írja
- [ ] 3.4 Negatív érték: P és K is a cél alatti távolság (pl. `K -600` → 0. szint, hozamtényező 0,65); nincs "0-ra vágás" többé
- [x] 3.5 Hibás fieldId / hibás típus / hiányzó paraméter → érthető használati üzenet, nincs crash
- [x] 3.6 Ugyanaz a mező több pixeléből: a teljes mező egyenletesen kap értéket
- [ ] 3.7 Multiplayerben kliensen a parancs jogosultsághoz kötött / szerveren fut

## 4. Kijuttatás (szervestrágya, műtrágya)
Mindegyiknél: `vtszNutrientSet` kezdőérték, majd kijuttatás, mintavétel/réteg ellenőrzés, debug log `spray fillType=... l/ha=... P=... K=... OM=...`.
- [x] 4.1 MANURE (trágyaszóró): P +1.75, K +4.2 kg / 1000 l, OM +0.0008 % / 1000 l _(auto)_
- [x] 4.2 LIQUIDMANURE (hígtrágya): P 1.7, K 5.0, OM 0.00034 _(auto)_
- [x] 4.3 DIGESTATE: P 3.0, K 5.0, OM 0.00038 _(auto)_
- [x] 4.4 FERTILIZER, `baseFertilizer` ki (alap): P és K nem változik, csak a PF N; a HUD sorban nincs P/K érték _(auto: `vtszSelfTest spray`)_
- [ ] 4.4b FERTILIZER, `<baseFertilizer enabled="true"/>` (config vagy map.xml): P 120, K 120 / 1000 l, a HUD és a súgó mutatja; 300 l/ha ≈ +36 P2O5 és +36 K2O
- [ ] 4.4c Játékban: FERTILIZER szórása kikapcsolt kapcsolóval, `vtszNutrientDebug on`: a `spray fillType=FERTILIZER` sor nem ír P/K-t; mentésből betöltve is így marad
- [x] 4.5 CARBOLIME: P 18, K 1.2, OM 0.00036 _(auto)_
- [x] 4.6 LIQUIDFERTILIZER: P/K nem változik (csak N) _(auto)_
- [x] 4.7 Pétisó 27 és Karbamid 46: csak N, P/K nem változik
- [x] 4.8 MAP 11-52-0: P +499.2 / 1000 l _(auto)_
- [x] 4.9 TSP 0-46-0: P +506 / 1000 l _(auto)_
- [x] 4.10 SSP 0-18-0: P +189 / 1000 l _(auto)_
- [x] 4.11 Kálisó 60: K +660 / 1000 l _(auto)_
- [x] 4.12 Patentkali: K +357 / 1000 l _(auto)_
- [x] 4.13 NPK 15-15-15: P és K +157.5 / 1000 l _(auto)_
- [x] 4.14 NPK 8-24-24: P és K +252 / 1000 l _(auto)_
- [x] 4.15 Élesztővinasz: P +3.78, K +37.8, OM +0.0028 / 1000 l (sűrűség 1.26) _(auto)_
- [ ] 4.16 Nitrosol UAN 30: csak N; a PF N értéke 1000 l-re 382.5 kg (sűrűség 1.275 × 30 %): 100 l/ha ≈ +38 kg N a PF N térképen
- [ ] 4.16b Nitrosol és Élesztővinasz a PF-ben: a fogyasztás (l/ha) a PF N-igényéhez képest kevesebb liter, mint a régi 1.0 sűrűséggel (Nitrosol: 1 / 1.275 ≈ 78 %); nincs hiba a PF auto-rate-nél
- [x] 4.17 Értékek arányosak a kijuttatott literrel (kétszer akkora l/ha → kétszer akkora növekedés) _(auto)_
- [x] 4.18 Pixelenként és termékenként egyszer (a mod zára: spray típus ÉS utolsó termék): ugyanazon az úton kétszer elmenve nem duplázódik az egyik menetben, külön menetben igen
- [ ] 4.19 Különböző szórószélességek/vontatott és önjáró gépek (szóró, permetező, trágyaszóró, hígtrágyás tartálykocsi, injektor/tárcsa)
- [ ] 4.20 Szórás mező határán: csak a mező pixelei változnak, szomszéd mező nem
- [ ] 4.21 Maximum: P a céltól +300 fölé nem megy (lágy plafon), K +675, OM +2.19 fölé / −4.01 alá nem megy
- [ ] 4.21b P túlszórás megáll +300-nál: `vtszNutrientSet <mező> P 250`, majd 1000 l/ha TSP 0-46-0 (+506 kg/ha) kijuttatása: a mezőinfó `+300 kg/ha P2O5` (nem több, nincs túlcsordulás, a log nem ír hibát); a pixelek a plafonon maradnak, új szórás nem emeli _(auto: `vtszSelfTest world <fieldId> confirm`, `WORLD.P.capSpray`, `WORLD.P.capSet`)_
- [x] 4.22 OM kis változás (< 1 szint) véletlenszerű kerekítéssel: nagy mezőn az átlag helyes, nincs rendszeres 0 vagy túlnövés _(auto)_
- [x] 4.23 Üres tartály / szórás leállítása: nincs változás
- [x] 4.24 Egyéb fill type (pl. mész, víz, gyomirtó): nincs P/K/OM változás, nincs hiba
- [ ] 4.25 Tilalmi időszak / szezonális szabály nincs a modban (nem kell tesztelni), de ellenőrizd, hogy a PF N szórás továbbra is rendben van (N térkép nő)

## 5. Kijuttatási mennyiség (N nélküli termékek: TSP, SSP, Kálisó, Patentkali)
- [x] 5.1 Alapértelmezett l/ha: TSP 230, SSP 240, Kálisó 230, Patentkali 210 _(auto)_
- [ ] 5.2 `Bal Ctrl + K` növeli, `Bal Ctrl + M` csökkenti a mennyiséget (lépés 25, min 10, max 800; Kálisó 60: max 450 – `rateControl` szerint)
- [ ] 5.3 A gombok átköthetők a billentyűbeállításokban (`VTSZ_RATE_INCREASE/DECREASE`), nincs ütközés a PF sajátjával
- [ ] 5.4 Határ: min alá/max fölé nem megy
- [ ] 5.5 A mennyiség járműnként külön érték
- [ ] 5.6 Mentés/betöltés után visszaáll az alapra (nincs mentve – szándékos)
- [ ] 5.7 HUD sor (bal felül): `l/ha | N | P2O5 | K2O kg/ha` (oxid jelöléssel), értékek a termék tartalmának és az l/ha-nak megfelelők
- [ ] 5.8 PF által kezelt termékeknél (Pétisó, Karbamid, MAP, NPK, UAN, Élesztővinasz) a HUD a PF aktuális l/ha-ját mutatja
- [ ] 5.9 A tényleges kijuttatott mennyiség megegyezik a HUD értékkel (liter fogyás / terület)
- [ ] 5.10 Multiplayer: a mennyiség szinkronizál (`VtszSprayerRateEvent`), kliens változtat → szerver és más kliensek látják
- [ ] 5.12 Műtrágyázó vetőgép (FertilizingSowingMachine): HUD sor megjelenik, `Bal Ctrl + K/M` és az automata (`Bal Alt + ,`, `Bal Alt + B`) működik, vetés közben a P/K térkép nő a sávban (`vtszNutrientDebug on`), nem bekapcsolt (`needsSetIsTurnedOn`) gépnél nem nő
- [ ] 5.11 PF automata (alap N) permetezőn: csak a PF N működik, a mod nem avatkozik be (a P/K alap: 5b)
- [ ] 5.12 Gép váltás / leszállás / újra felszállás: mennyiség és HUD nem romlik el
- [ ] 5.13 Termékváltás tartályban: a mennyiség az új termék alapértelmezett értékére áll

## 5b. Automatikus mennyiség (alap tápanyag)
- [x] 5b.1 `vtszSelfTest auto`: az alapértelmezett alap (15-15-20 → K, 0-46-0 → P, 15-15-15 → N, 8-24-24 → P) és a mennyiségképlet _(auto)_
- [ ] 5b.2 Kálisó 60 (N nélküli) a gépben: `Bal Alt + ,` bekapcsolja az automatát, a HUD `(auto K)`-t mutat, a mennyiség a felfedett térkép szerint változik (hiányos mezőn több, a cél fölött 0)
- [ ] 5b.2b Az automata pontosan a mezőinfó hiányát juttatja ki (nincs építési idő, nincs elvonás-pótlás): `vtszNutrientSet <mező> K -150` és `P -200`, búzával: Kálisó 60 automata ≈ 150 + 22 = 172 kg K2O/ha, TSP ≈ 200 + 0 kg P2O5/ha (a mezőinfó két száma közti különbség). Nagy hiánynál (pl. K -400) a termék `rateControl` max értéke és a `maxLitersPerHa` korlátozza: Kálisó 60 max 450 l/ha ≈ 297 kg K2O/ha egy menetben, a hiány több menetben épül le _(a képlet: `vtszSelfTest auto`, `AUTO.units.K.gap`, `.cropGap`)_
- [ ] 5b.2c Az automata a cél fölött 0 l/ha (`vtszNutrientSet <mező> P 100`), P-nél savanyú mezőn (pH ≈ 5,0, vályog) is: az automata a pH-t nem veszi figyelembe, `vtszNutrientSet <mező> P 0` után 0 l/ha (a rés a talajcélig 0), de a mezőinfó a `alacsony felvehetőség (pH)` figyelmeztetést mutatja, és a hozamtényező 1 alatt van _(`AUTO.units.P.phIgnored`)_
- [ ] 5b.3 Talajmintavétel nélküli (fedett) területen az automata a kézi mennyiséget használja, nincs hiba
- [ ] 5b.4 NPK 8-24-24 PF automatával: az alap alapértelmezetten P; `Bal Alt + B` K-ra vált, a HUD `(auto K)`; a l/ha a K igényből jön, a PF N térképe annyi N-t kap, amennyi a kijuttatott literekben van (nincs eltérés)
- [ ] 5b.5 Alap N-re állítva a PF saját automatája dolgozik, mint a mod nélkül
- [ ] 5b.6 Termékváltás után az alap visszaáll az alapértelmezettre; a gomb csak ≥ 2 tápanyagú terméknél aktív
- [ ] 5b.7 Dedikált szerver: a kliens HUD-ja a szerver mennyiségét mutatja, a be/ki és az alap szinkronizál
- [ ] 5b.8 A PF kézi módja és a kézi mennyiség (N nélküli terméknél `Bal Ctrl + K` / `,`) változatlanul működik
- [ ] 5b.9 Mintavétel nélküli (fedett) talajon a mod saját P/K automatája a kézi mennyiséget adja (N nélküli termékek); a PF N automatája a PF szerinti
- [x] 5b.10 Hígtrágya: traktor + tartály + ejtőfüggöny: `Bal Alt + B` aktív, a HUD `(auto N)`-t mutat, N alapnál a PF szerinti ~110 kg N/ha körüli mennyiség, K/P-re váltva a l/ha változik; tartálycsere után az alap visszaáll N-re; a minimap követi a terméket
- [x] 5b.11 Trágya, Fermentált és Hígtrágya alapja N, NPK 8-24-24 alapja P (`vtszSelfTest auto`)

## 6. Minimap kijuttatás közben
- [ ] 6.1 Mezőn, termékkel a gépben a minimap automatikusan a termék legnagyobb tartalmú tápanyagának rétegére vált (MAP/TSP/NPK 8-24-24: P; Kálisó/Patentkali: K; szerves trágyák: N)
- [ ] 6.2 `Bal Alt + .` (`VTSZ_MINIMAP_LAYER`) lapoz: Auto > N > P > K > OM
- [ ] 6.3 Termékváltáskor a választás visszaáll Autóra
- [ ] 6.4 Ismert hiba: NPK 8-24-24 és Élesztővinasz szórásakor a minimap ne váltogasson folyamatosan N és más réteg között
- [ ] 6.5 NPK 15-15-15 hasonló viselkedés ellenőrzése
- [ ] 6.6 Mezőről kilépve/gép kikapcsolva a minimap visszaáll az eredeti nézetre
- [ ] 6.7 A gomb átköthető, nincs ütközés más gombbal
- [ ] 6.8 Nem szóró járműnél a gomb nem csinál semmit

## 7. Betakarítás – P és K elvonás
Debug log: `harvest P actual=... target=... factor=...`.
- [ ] 7.1 Búza aratás: P −64, K −44 kg/ha (tipikus hozamnál)
- [ ] 7.2 Szalma lehordva (nincs aprító): extra P −19, K −90 (`removalStraw`)
- [ ] 7.3 Szalma felaprítva (szecskázó be): nincs extra elvonás (strawChopperGain=0)
- [ ] 7.4 Árpa, zab, rozs, tritikálé, tönkölybúza: saját értékek
- [ ] 7.5 Kukorica (szem), silókukorica, cirok, zöldrozs, rozsos bükköny; a cirok P −55, K −170 (a silókukoricánál nem nagyobb: 65 / 190), a súgó növénylistája ugyanezt mutatja; a "Műtrágyák tartalma" oldal minden műtrágyát és meszet mutat 1000 literenként (N / P2O5 / K2O; OM és pH csak ahol van; a leírt mod-termékek és az alap FERTILIZER: csak N, ha a baseFertilizer ki van kapcsolva; a LIME csak pH; a nem létező anyagok hiányoznak) (alapsor: szem, szalma aprítva; gabonánál külön sor bálázott szalmával); a "Műtrágyák használata" oldal megnyílik, a bekezdései (munkarend, termékcsoportok, naptár, növények, játékszabályok, házi szabályok) olvashatók és nem lógnak ki a panelből
- [ ] 7.6 Repce (a szalma mindig a földön marad, nincs szalma-elvonás: P −55, K −30), napraforgó
- [ ] 7.7 Cukorrépa, burgonya (nagy K elvonás)
- [ ] 7.8 Szója, borsó, takarmányborsó, lóbab
- [ ] 7.9 Fű, mezei fű, lucerna, here kaszálás (vágásonként)
- [x] 7.9b Kaszálás (kaszálógép) `vtszNutrientDebug on` mellett: a log aratás sora `yieldScale=` értéket ír (nem mindig 1.0), és a vágásonkénti P/K elvonás a skálával arányos (jól kezelt rétnél kb. +30 % a táblázathoz képest, gyomos/hiányos rétnél kevesebb); a szecskázó és a kombájn ugyanígy _(kaszálógép és kombájn log rendben 2026-11-02: K 800→720 = 66 × 1.2, a régi fű-elvonással (GRASS 66) mérve; a config most GRASS K 87 (lucerna 93), újratesztnél várt érték 87 × 1.2 = 104; szecskázó: a skála a logban rendben (szorzó 2.18, potenciál 1.25 → 1.5), a tényleges elvonás még nincs ellenőrizve: mezőinfó P/K aratás előtt és után, silókukorica skála 1.5 mellett kb. −97 P és −285 K)_
- [ ] 7.10 Ismeretlen/DEFAULT növény: P −50, K −50
- [x] 7.11 Az elvonás követi a hozamot (hozamskála = PF szorzó / `yieldReference`, 0.3..2.0, 0.1 lépés): `vtszNutrientDebug on` aratás sora `yieldScale=` értéket ír; gyenge hozamú (gyomos, N-hiányos) és jó hozamú aratásnál az elvonás aránya a skála szerint változik _(a számítás: `vtszSelfTest scale`)_
- [ ] 7.11b `yieldReference="0"`: a skála 1, az elvonás rögzített; kombájn, kaszálógép és szecskázó is a skálát használja; a log hibamentes
- [x] 7.12 Minimum 0 alá nem megy
- [ ] 7.13 Részleges aratás (fél mező): csak az arat pixelek változnak
- [ ] 7.14 `<balance removalScale>` módosítás hatása (az OM-ból leadott N is skálázódik: 0 = nincs OM-veszteség és nincs N-leadás, 2 = mindkettő dupla)

## 8. Betakarítás – szervesanyag (OM)
Az alábbi OM-értékek valós idejűek (VDLUFA); a játékban az OM `timeScale` (alap 6) szorozza őket. A `vtszSelfTest` ezt beleszámolja.
- [x] 8.1 Fogyasztók (alapon felül, VDLUFA): silókukorica, cukornád, cirok, zöldrozs, rozsos bükköny, sárgarépa, paszternák −0.01167; burgonya −0.02; cukorrépa −0.02 + levél 0.014 = −0.006; rizs, zöldbab, cékla 0 _(auto)_
- [x] 8.2 Gabonák: szalma lehordva 0 (csak az alap lebomlás), aprítva +0.0147 búza, +0.0112 árpa, +0.0126 zab, +0.0124 rozs, +0.0134 tritikálé, +0.0092 tönköly (55 Haeq/t szalma) _(auto)_
- [x] 8.3 Építők: borsó, takarmányborsó, lóbab, szója +0.0183; repce +0.0136; napraforgó +0.0160; szemes kukorica +0.0113 (szár +0.0229, igény −0.0117) _(auto)_
- [x] 8.4 Fű, mezei fű, rét, lucerna, here +0.00944 / vágás (3 vágás évente) _(auto)_
- [x] 8.5 Határ: az OM a céltól +2.19 fölé és −4.01 alá nem megy (a tárolt 0..255 tartomány; abszolút 0 % nincs külön védve)
- [x] 8.6 Kis változások (a 0.0243 szintlépés alatt) véletlenszerűen kerekítődnek, nagy mezőn az átlag a konfigurációval egyezik _(auto)_
- [ ] 8.7 Több aratás egymás után: összeadódik, értelmes tendencia
- [ ] 8.8 `<balance removalScale/inputScale>` hatása OM-re (removalScale az N-leadást is skálázza)
- [ ] 8.9 `timeScale`: a `vtszSelfTest harvest|spray|mineral` hibamentes (OM elvárások × `timeScale`); `timeScale="1"` a configban a régi (valós idejű) értékeket adja
- [ ] 8.10 Kasza: búza/árpa kaszálógéppel aratva az OM csökken (−(0.00583 + `removalStraw`) × `timeScale`), nincs szalma- vagy szárjóváírás, aprító sem számít; a fű/lucerna kaszálása +`gain` marad
- [ ] 8.11 Forage-fej (Kemper Plus / Claas Orbis / Direct Disc): egész növényes árpa/búza ugyanúgy csökkenti az OM-et; ugyanaz a növény kombájn gabonafejjel aprított szalmával nem
- [ ] 8.12 MaizePlus-szal (ha elérhető): a kaszás aratás ugyanúgy szecskázásnak számít; egy kaszás lépés után a `harvestIsMower` jelző nem ragad be (a következő kombájn-lépés normál)
- [ ] 8.13 Forázsfejjel (silózó) gabona aratás: a P és K csökkenés a szalmás szemes aratással egyezik (removalStraw levonva, szalma-nyereség nincs)

## 8b. Szervesanyag lebomlása (mineralizáció)
- [x] 8b.1 Az OM `<mineralisation>` súlyai 12 értékűek, összegük 1; 12 időszak összege = rate × cél, minden talajtípusra _(auto: `vtszSelfTest mineral`)_
- [x] 8b.2 A véletlen kerekítés átlaga az éves veszteséggel egyezik (3 % tűrés) _(auto)_
- [ ] 8b.3 Játékban: `vtszNutrientSet 1 OM -0.2` (0,2 a cél alatt), majd időszakváltás: a log `OM mineralisation period N: soil1=... soil4=...` sort ír, az OM térkép csökken (nyáron a legtöbbet)
- [ ] 8b.4 Egy játékév (12 időszak) alatt vályogon kb. −0.070 %-pont (−0.0117 × `timeScale` 6), iszapos agyagon kb. −0.088 (mezőátlag, `vtszNutrientSet` + mezőinfó)
- [ ] 8b.5 OM = 0 mezőn a lebomlás nem megy 0 alá (nincs túlcsordulás 255-re)
- [ ] 8b.6 `rate="0"` kikapcsolja; `<balance removalScale>` skálázza
- [ ] 8b.7 Dedikált szerver: csak a szerver számol, a kliens ugyanazt a térképet látja
- [ ] 8b.8 Mentés/betöltés után a lebomlás folytatódik, hiba nélkül

## 8c. Térkép felső határa
- [ ] 8c.1 `vtszNutrientSet 1 P 295`, majd szórj sok P-t (pl. TSP): a mezőinfó nem ugrik vissza kicsire (nincs túlcsordulás), a P a +300 lágy plafonon marad (lásd 4.21b)
- [ ] 8c.2 Ugyanez K-val (`K 670`, a tárolt maximum +675) és OM-mel (+2.19 a céltól)
- [ ] 8c.3 A határ fölötti szórás hibát nem okoz a logban
- [ ] 8c.4 K kimosódás relatív küszöbbel: csak a talajcélon vagy fölötte (térképérték ≥ 0) lévő pixel veszít K-t időszakváltáskor (a log `K leaching period N` sora); egy hiányos mező (`vtszNutrientSet <mező> K -100`) nem veszít, egy `K 100` mező igen (talajtípusonként a `leaching` éves értéke, pl. vályogon 15 kg/ha/év) _(a küszöb: `vtszSelfTest mineral`, `LEACH.K.threshold`; a térképen futó rész kézi)_

## 9a. pH és foszfor
- [x] 9a.1 `vtszSelfTest ph`: a kulcsok sorrendje, 0.3..1 érték, interpoláció, ismeretlen pH → 1 _(auto)_
- [ ] 9a.2 Aratáskor a debug sor `pH=` értéket ír (nem `n/a`), kombájnnal és kaszálógéppel is
- [ ] 9a.3 Savanyú mezőn (pH ≈ 5.5, PF debug paranccsal állítva) vályogon `vtszNutrientSet <mező> P 0` után a mezőinfó `0 kg/ha P2O5` és az `alacsony felvehetőség (pH)` szöveg (a hozamtényező a 600 / 0,85 = 706 célhoz mért, < 0,99); optimális pH-n (6.2–7.2) nincs figyelmeztetés; a térkép színe a pH-tól nem változik
- [ ] 9a.4 Azonos P szint mellett savanyú mezőn kisebb a P-tényező az aratáskor, mint optimális pH-n
- [ ] 9a.5 Talajmintavétel nélküli (fedett) pixelen is működik az aratásnál
- [ ] 9a.6 `<phEfficiency>` blokk törlése: nincs hatás, nincs hiba
- [ ] 9a.7 pH-korlát (relatív): a hozamtényező pH-hoz igazított P célja a talajcél fölött legfeljebb a lágy plafon mínusz egy lépés (+295); minden talajtípuson elérhető a cél pH 3..10 között; vályog pH 5.0: 600 / 0,70 − 600 = +257 (nem éri el a korlátot), tényező 1 a +300-nál; a plafon (`maxUnits`) +260 alá nem állítható _(auto: `vtszSelfTest ph`, `PH.P.loam5`, `PH.P.capRoom`, `PH.P.definition`)_
- [ ] 9a.8 Játékban: vályog mezőn pH ≈ 5.0, `vtszNutrientSet <mező> P 300`: a mezőinfó `+300 kg/ha P2O5`, nincs figyelmeztetés, aratáskor a P-tényező 1.00; `P 0`-nál a mezőinfó `0 kg/ha P2O5`, az automata 0 l/ha (a pH-t nem veszi figyelembe), a hozamtényező a +257 célhoz mért; a többi talajtípus igazított célja a talajcél fölött: agyagos homok +180, homokos vályog +214, iszapos agyag +197
- [ ] 9a.9 A korlát nem csökkenti a célt az optimális pH-n (6.2–7.2): a mezőinfóban nincs `alacsony felvehetőség (pH)` szöveg

## 8d. OM → N (a mineralizált OM nitrogénje a PF N térképébe)
- [x] 8d.1 `vtszSelfTest mineral`: az éves N-felszabadulás talajtípusonként = `nPerPercent` × OM cél; a PF N térkép amountPerState / maxVisibleValue / mérete rendben _(auto)_
- [ ] 8d.2 Játékban időszakváltáskor a log `OM nitrogen release into the N map: soil1=.. kg N soil2=..` sort ír
- [ ] 8d.3 Egy üres (vetetlen) mezőn 12 időszak alatt az N térkép átlaga kb. +26 kg N-nel nő vályogon (mezőinfó N), nyáron gyorsabban
- [ ] 8d.4 A PF látható maximumánál (N térkép felső vége) megáll, nem csap át kicsire
- [ ] 8d.5 `nPerPercent="0"`: nincs N-változás; a PF automata N-adagolója kevesebbet ad magasabb talajszintnél
- [ ] 8d.6 Dedikált szerver: a kliens ugyanazt az N térképet látja

## 9. Takarónövények (ágyazás)
- [x] 9.1 Olajretek beszántva: OM +0.008 _(auto)_
- [x] 9.2 Mustár: +0.008 _(auto)_
- [x] 9.3 Virágos keverék: +0.007 _(auto)_
- [x] 9.4 Humusaktív keverék: +0.012 _(auto)_
- [ ] 9.5 A map.xml `coverCropBonus` lista felülírja a `catchCrops` listát, ha van
- [ ] 9.6 Nem takarónövény beszántása (pl. búza): nincs OM változás
- [ ] 9.7 Tárcsázás vs eke vs kultivátor vs mulcsozó: mindegyik destroy esemény helyesen számol
- [ ] 9.8 Nem teljesen kinőtt növény megsemmisítése (korai fázis): ellenőrizd a viselkedést (nincs/van gain, dokumentáld)
- [x] 9.9 Olajretek (vagy humuszaktív) mulcsozóval: az OM ugyanannyit nő, mint beszántáskor (`vtszNutrientDebug on`, OM előtte/utána); `vtszSelfTest` DESTROY.OM.mulcherHook/mulchedState/mulchMask zöld
- [x] 9.10 Második mulcsozó menet ugyanazon a területen: az OM nem nő tovább
- [x] 9.11 Mulcsozás, majd szántás: a szántás nem ad újabb OM-et (a mulcsozott maradék kizárva)

## 10. Hozam
- [x] 10.1 Hozam = PF szorzó × min(pFactor, kFactor) × omFactor, mindegyik max 1; a `vtszNutrientDebug on` aratás sora `combined=` értéket ír (P 0.95 + K 0.95 → 0.95, nem 0.90) _(auto: `vtszSelfTest yield`)_
- [x] 10.2 P cél alatt (a térképen negatív érték): −100 → 0.95, −200 → 0.87, −300 → 0.80, −600 → 0.65 (köztes értékek interpoláltak) _(auto)_
- [x] 10.3 K cél alatt (a térképen negatív érték): −100 → 0.95, −250 → 0.88, −400 → 0.80, −600 → 0.65 _(auto)_
- [x] 10.4 K cél fölött (a térképen pozitív érték): +200 → 1.00, +400 → 0.97, +600 → 0.95 _(auto)_
- [x] 10.5 P cél fölött: nincs büntetés _(auto)_
- [ ] 10.6 OM cél alatt 0.2-es lépésekkel: −0.2 → 0.99, −0.4 → 0.97, −0.6 → 0.95, −0.8 → 0.92, −1.0 → 0.89, −1.25 → 0.855, −1.5 → 0.82, −2.0 → 0.75, −2.5 → 0.68 _(auto: `vtszSelfTest yield`)_
- [ ] 10.6a Relatív OM térkép: a minimap/térkép mind a 4 talajtípuson zöld a célon (`vtszNutrientSet <mező> OM 0`), sárga kb. −0,6-nál, piros −1,2 alatt; a jelmagyarázat −1,4…+0,2, 8 sáv; a mezőinfó a távolságot írja
- [ ] 10.6b Új mentésnél a legrosszabb OM kezdőszint talajtípusonként legalább 0.90 hozamtényezőt ad (−0.8 → 0.92) _(auto: `vtszSelfTest config`, `.initialFactor`)_
- [ ] 10.6c Dairy forgó (D, kompenzáció nélkül) a szerveren 6 játékév alatt kb. −0.41 %-pont OM-et (3.25 -> 2.84, README D táblázat) és kb. 0.98 OM-tényezőt ad (a legrosszabb aratási hozam 0.93, az 1. év zöldrozsa, K a növény céljához képest); szilárd trágya + lucerna-szünet hígtrágyával (E) stabilan tartja (3 lucerna-kaszálással; a 6. évre 3.14 %, a 8. évre 3.24 %)
- [x] 10.7 Talajtípus alapérték (a konfigban abszolút; a térképen ez a 0): P 420/500/600/460, K 500/700/740/820, OM 1.8/2.5/3.2/4.0 % _(auto)_
- [ ] 10.7b Nincs növényi extra (relatív K, P): `getTargetUnits(talaj, növény)` = 0 K-ra és P-re minden növényen és talajtípuson (`targetRemovalShare` 0 az alap konfigban); `getAbsoluteTargetUnits` = a talajcél (pl. K vályogon 740); az automatikus mennyiség a K-nál pontosan a hiány (a térképi érték ellentettje) _(auto: `vtszSelfTest relative|auto`)_
- [ ] 10.8 Mindhárom a célon vagy fölötte: hozam megegyezik a PF-fel (a nélküli modbeli hozammal)
- [ ] 10.9 Mezőnként ugyanaz a mező két különböző kezdőértékkel (`vtszNutrientSet`): a hozam különbség arányos
- [ ] 10.10 A mezőinfó "várható hozam" sora beszámolja a mod faktorait (`getFieldInfoYieldChange` burkolás, `fieldYieldFactor`): `vtszNutrientSet`-tel P-t a cél alá víve a várható hozam csökken, a cél fölött nem változik
- [ ] 10.11 Fruit type `targetScale` (DEFAULT=1) hatása a célértékre

## 11. Mentés, betöltés
- [ ] 11.1 Mentés után a mentési mappában: `vtsz_pMap8.grle`, `vtsz_kMap8.grle`, `vtsz_omMap8.grle` (mindhárom 8 bites, ezért a fájlnévben a `8`; a régi 5 bites `vtsz_pMap.grle` / `vtsz_kMap.grle` fájlokat az új verzió nem olvassa, a régi mentés P/K értékei az új kezdőértékre állnak)
- [ ] 11.2 Kilépés, újratöltés: szintek változatlanok (P, K, OM)
- [ ] 11.3 Autosave közben is ment
- [ ] 11.4 Mod eltávolítása után betöltés: nincs crash (PF működik tovább, P/K/OM fájlok figyelmen kívül)
- [ ] 11.5 Mod hozzáadása meglévő mentéshez: új térkép "new" kezdőértékekkel, nincs hiba
- [ ] 11.6 Megsérült/hiányzó grle fájl: újrainicializálás, log figyelmeztetés, nincs crash
- [ ] 11.7 Mezők vásárlása/eladása, farmland-változás: térkép nem romlik
- [ ] 11.8 Új gazdasági év / idő előretekerése (gyorsítás): nincs hiba

## 12. Shop termékek
- [ ] 12.1 Mind a 11 termék megjelenik a boltban a helyes kategóriában
- [ ] 12.2 Big bag (1000 l): Pétisó 27, Karbamid 46, MAP, TSP, SSP, Kálisó 60, Patentkali, NPK 15-15-15, NPK 8-24-24
- [ ] 12.3 IBC (1000 l): Nitrosol UAN 30, Élesztővinasz; sűrűség 1.275 / 1.26 t per 1000 l, a bolti ár 1267 / 453 (README „Termékek”)
- [ ] 12.4 Ikonok, nevek, leírások HU + EN nyelven helyesek
- [ ] 12.5 Árak értelmesek (becsült, források: README „Források”); az N-ár (€/kg N) a Nitrosolnál nem lett drágább a sűrűségváltás után
- [ ] 12.6 Big bag a szóróhoz tölthető, IBC a permetezőhöz; a fill type a helyes gép típusba tölthető
- [ ] 12.7 Szórási effekt/animáció megjelenik (motionPath), nincs hiányzó textúra/shape hiba
- [ ] 12.8 Tárolás: raktárban/siló trigger elfogadja a termékeket (ha releváns)
- [ ] 12.9 Eladás/vásárlás a piacon: nincs hiba (ha engedélyezett)
- [ ] 12.10 Termékek TR spray típusként regisztrálva (PF N értékek helyesek: Pétisó, Karbamid, MAP, NPK-k, UAN, Élesztővinasz)
- [ ] 12.11 PF N szabályozás (auto rate) működik az N-es termékeknél

## 13. Súgó és nyelvek
- [ ] 13.1 Súgó oldalak (`VtszHelp`) megjelennek az ESC > Súgóban, ikonokkal
- [ ] 13.2 EN és HU szövegek teljesek, nincs `Missing l10n` a logban; a súgó növénylista és a műtrágyatartalom oldal bevezetője megemlíti az alapjáték FERTILIZER-t (csak N, `baseFertilizer`), az oxid jelölést, és hogy a gabonáknál van "Bálázott szalma" sor (elvitel + szalma), a többinél (répa, burgonya, kukorica, fű) csak az egy sor; a "Műtrágyák használata" oldal címe és bekezdései EN és HU nyelven is teljesek
- [ ] 13.3 Billentyű beállítások: `VTSZ_RATE_INCREASE`, `VTSZ_RATE_DECREASE`, `VTSZ_MINIMAP_LAYER` megjelennek, helyes névvel
- [ ] 13.4 modDesc title/description EN + HU a mod menüben

## 14. Multiplayer (dedikált szerver)
- [ ] 14.1 Szerverre és kliensekre is telepítve; csatlakozás hiba nélkül
- [ ] 14.2 P/K/OM térképek szinkronban a klienseken (PF density map syncer)
- [ ] 14.3 Kijuttatás (4.), aratás (7., 8.), ágyazás (9.) csak a szerveren számol, a kliens ugyanazt látja
- [ ] 14.4 Mennyiség esemény szinkron (5.10)
- [ ] 14.5 Minimap réteg és HUD helyi (kliens) szinten működik
- [ ] 14.6 Késői csatlakozó kliens ugyanazt a térképet látja
- [ ] 14.7 Kliens lecsatlakozás/újracsatlakozás nem rontja el az állapotot
- [ ] 14.8 Szerver mentés → újraindítás: értékek megmaradnak
- [ ] 14.9 Két játékos egyszerre szór ugyanazon a mezőn: nincs elveszett vagy duplázott írás
- [ ] 14.10 Több farm: mindenki a saját mezőjét látja/szórja, jogosultság helyes

## 15. Teljesítmény és stabilitás
- [ ] 15.1 Nincs érezhető FPS-esés mezőn szórás/aratás közben
- [ ] 15.2 Hosszú játék (több in-game év gyorsítva): nincs memória/log növekedés, nincs Lua hiba
- [ ] 15.3 Debug log korlátozott (throttle), `vtszNutrientDebug off` után nincs log
- [ ] 15.4 Több gép egyszerre dolgozik több mezőn: nincs hiba
- [ ] 15.5 Mod nélkül és modbbal PF alap viselkedés (N, pH, vetőmag, mész) érintetlen
- [ ] 15.6 Kompatibilitás: más modokkal (pl. más szóró/permetező modok, nagy szóró modok) nincs ütközés
- [ ] 15.7 Mezőn kívüli szórás (út, tarló): nincs hiba, nincs változás

## 16. Konfiguráció
- [ ] 16.1 `<balance inputScale>` megduplázva: kijuttatási nyereség ×2
- [ ] 16.2 `<balance removalScale>` megduplázva: elvonás ×2
- [ ] 16.3 map.xml `<vtszNutrients>` felülírás: `target`, `fillType`, `fruitRequirement` egyedi bejegyzések cserélődnek, a többi marad
- [ ] 16.4 Hibás XML érték (pl. szöveg szám helyett): log figyelmeztetés, alapértékre esik vissza, nincs crash
- [ ] 16.5 Új fillType hozzáadása a konfigba (pl. TR-ből MOP) → P/K változás kijuttatáskor
- [ ] 16.6 Hiányzó `rateControl` bejegyzés: PF alapviselkedés, nincs hiba
- [ ] 16.7 map.xml `<vtszNutrients><baseFertilizer enabled="true"/>` felülírja a mod alapját (ki): FERTILIZER P/K aktív csak azon a térképen
- [ ] 16.8 Hiányzó `<baseFertilizer>` elem: alapérték ki, nincs hiba; hibás érték (pl. `maybe`): log figyelmeztetés, ki
