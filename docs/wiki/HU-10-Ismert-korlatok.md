🇬🇧 [English version](EN-10-Known-Limitations)

> [!WARNING]
> **A mod jelenleg is fejlesztés alatt áll, változások történhetnek, mindig legyen biztonsági másolatod a mentésedről.**

# Ismert korlátok és gyakori kérdések

**Röviden:**
- Itt találod, mit **nem** csinál a mod, és mit válaszolunk a leggyakoribb kérdésekre.
- A számok becslések (±20–30 %), ahol nincs másképp jelölve.
- Több dolog még nincs tesztelve (multiplayer, mod hozzáadása és eltávolítása).
- Források: [Források](HU-11-Forrasok).

**Gyors útmutató**
- Furcsán viselkedik a hozam vagy a tápanyagszám: [Hozam és tápanyagszintek](#hozam-és-tápanyagszintek)
- Kijuttatással, termékekkel, nitrogénnel akadsz el: [Kijuttatás és termékek](#kijuttatás-és-termékek)
- Aggódsz a mentésed vagy a szerver miatt: [Mentés, multiplayer, másik térkép](#mentés-multiplayer-másik-térkép)
- Tudni akarod, mi hiányzik a modból: [Mit nem tud a mod](#mit-nem-tud-a-mod)

---

# Gyakori kérdések

## Hozam és tápanyagszintek

### Miért esett a hozam, pedig a nitrogén tökéletes?
A hozamot a foszfor, a kálium és a szerves anyag is csökkentheti, ha a célérték alatt vannak. A foszfor és a kálium közül a szűkösebb számít, a szerves anyag ezt még külön szorozza. A mod soha nem ad több hozamot, mint a Precision Farming (PF). Nézd meg a mezőinfót és a három réteget, ahol a tápanyagonkénti információkat láthatod: [Foszfor](HU-02-Foszfor), [Kálium](HU-03-Kalium), [Szerves anyag](HU-04-Szerves-anyag).

### Miért „alacsony” a foszfor, ha a térkép a célon vagy fölötte van?
Savanyú vagy erősen meszes talajon a növény kevesebb foszfort tud felvenni, ezért a hozamtényezőben benne van a pH. A térkép és a mezőinfó száma az egyszerű távolság a talajtípus céljától marad, a sor kiegészítő szövege pedig „alacsony” helyett „alacsony felvehetőség (pH)”. Vályogon pH 5,5-nél például a teljes hozamhoz 600 helyett kb. 706 kg/ha kellene a talajban. Először a pH-t nézd meg, és mésszel javítsd: több foszfor nem segít, az automatikus mennyiség pedig csak a talajtípus céljáig tölti fel a hiányt. Részletek: [Foszfor](HU-02-Foszfor).

### Miért mutat a térkép mínusz értékeket?
A P, K és OM térkép a talajtípus céljától való távolságot mutatja: a 0 a célon van, a mínusz hiány, a plusz többlet. A talaj tartalmát magát nem látod. Részletek: [Első lépések](HU-01-Elso-lepesek).

### Miért fogy ilyen gyorsan a szerves anyag?
Ez a VirtualTSZ szerver beállítása. A szerver kb. egy valós évig fut, ez kb. 6 játékév. A szorzó (`timeScale` 6) azért van, hogy a szervesanyag-veszteség hatása rövidebb időn belül, egy valós éven belül is látszódjon: minden szervesanyag-változás játékévente 6-szoros. A VirtualTSZ szerveren ezért gyorsabban fogy. Vályogon a lebomlás így kb. −0,070 %-pont játékévente. Egy másik szerveren lassabb lehet. A [Szerves anyag](HU-04-Szerves-anyag) oldal megmutatja, mivel lehet ellensúlyozni.

### Miért térnek el a pixelek egyenletes szórás után?
A mod a kis változásokat véletlenszerűen kerekíti egy szintre, a mezőátlag viszont pontos. Emiatt egy talajminta értéke akár 5 kg (P, K) eltérést is mutathat a szomszédos mintától. Ez nem hiba. Részletek: [Technikai részletek](HU-08-Technikai-reszletek).

### Miért nem lehet a térképen egy bizonyos érték fölé jutni?
A térképeknek felső határa van, ami fölött a többlet elvész: a P térkép a céltól legfeljebb +675 kg P₂O₅/ha-t tárol, de a kijuttatás már +300-nál megáll. A K térkép a céltól +675 kg K₂O/ha-ig, az OM +2,19 %-pontig tárol. Érdemes tehát a célérték körül tartani a szintet, a több nem fér el. Részletek: [Technikai részletek](HU-08-Technikai-reszletek).

## Kijuttatás és termékek

### Miért nem szór semmit az automatikus mennyiség egy nitrogénben gazdag terméknél?
A P/K alapú automatikus mennyiség sosem juttat ki több nitrogént, mint amennyit a PF saját automatája az adott helyen kijuttatna. Ha a nitrogéncél már teljesül, a mennyiség 0-ra esik és a szóró nem szór, akkor sem, ha a P vagy a K hiányzik. Ilyenkor nitrogénmentes vagy P/K-dús terméket használj. Részletek: [Termékek és kijuttatás](HU-05-Termekek-es-kijuttatas).

### Miért nem látszik a második termék nitrogénje a nitrogéntérképen?
A PF nitrogéntérképe a talaj spray típusa szerint zár, és a bolti termékek mind ugyanazt a típust (`FERTILIZER`) használják. Ezt az állapotot kell keresned az Easy Development Controls modban. Ha két nitrogént tartalmazó terméket szórsz ugyanarra a pixelre művelés nélkül, a másodiké várhatóan nem kerül a PF nitrogéntérképére. A mod saját P, K és OM térképein viszont mindkét termék számít. Ezt szándékosan nem oldottuk meg: minden termékhez külön talajtípus sokat rontana a játék futásán.

Ha mégis szükséged van rá, két menet között törölheted a talaj `FERTILIZER` állapotát a [FS25_NotSoEasyDeveloperControls](https://github.com/borondy/FS25_NotSoEasyDeveloperControls) mod `clearFertilizerState` admin parancsával. Lásd [Termékek és kijuttatás](HU-05-Termekek-es-kijuttatas).

### Miért tér el az automatikus mennyiség a kívánt értéktől?
A PF nitrogénje 5 kg N/ha-os lépcsőkben mozog. Nitrogént tartalmazó terméknél ezért az automatikus mennyiség kb. ±16–30 l/ha-ral térhet el (NPK 15-15-15: egy lépcső kb. 32 l/ha, NPK 8-24-24: kb. 60 l/ha).

### Miért áll vissza a kijuttatási mennyiség betöltés után?
A kézi mennyiséget a mod szándékosan nem menti, mentés és betöltés után a termék alapértékére áll vissza. Állítsd be újra a gombokkal (Bal Alt + K és Bal Alt + M). Lásd [Termékek és kijuttatás](HU-05-Termekek-es-kijuttatas).

### Mi a helyzet a nagy kálisó-adagokkal?
A Kálisó 60 menetenkénti mennyiségét egy engedékeny, becsült felső korlát fogja (450 l/ha). Klorid-érzékeny növényeknél (burgonya, zöldségek) a nagyobb igényt érdemes két menetben vagy Patentkalival kiadni, mert a mod növényenkénti klorid-érzékenységet nem kezel.

### Mi történik, ha új terméket veszek fel, vagy törlök egyet?
A termékazonosítók eltolódnak, a mentett termékzár pedig a régi azonosítókat tartalmazza. Egy menetre ezért tévedhet: egy pixel eggyel több vagy kevesebb kijuttatást kaphat. A mod legfeljebb 31 terméket kezel.

## Mentés, multiplayer, másik térkép

### Tönkreteszi a mentésemet?
Nem valószínű. A mod saját térképfájlokat ír a mentés mappájába (`vtsz_pMap8.grle`, `vtsz_kMap8.grle`, `vtsz_omMap8.grle`, `vtsz_productMap.grle`), és befolyásolja a hozamot. A mod hozzáadása meglévő mentéshez és az eltávolítása még nincs tesztelve. Egy későbbi verzió a térképeket alaphelyzetbe állíthatja. A relatív (8 bites) P és K térképre való átálláskor a régi, 5 bites P és K térkép nem töltődik be, a két térkép a kezdőértékekről indul újra. Biztonsági másolat nélkül ne használd értékes mentésen.

### Működik multiplayerben?
A terv szerint igen: csak a szerver számol, a kliensek szinkronban látják a térképet. Ez azonban a `TESTS.md` szerint még nincs játékban végigtesztelve, és a kliensoldali konzolparancs-jogosultság sincs ellenőrizve. Számíts hibákra.

### Használhatom másik térképen?
Elvileg igen, de más térképen még nem próbáltuk. A térkép méretét a mod a PF talajtérképéből veszi, az ismeretlen terményeket és termékeket kihagyja. A Szalókra hangolt értékeket (célértékek, 3 kaszálás évente) át kell nézni: [Térképkészítőknek](HU-07-Terkepkeszitoknek).

### Hogyan ellenőrzöm, hogy működik a mod?
Ha a Precision Farming nézetben és a mezőinfóban megjelennek az új tápanyagok, a mod valószínűleg működik. A parancsos tesztet a [Konzolparancsok](HU-09-Konzolparancsok) oldalon találod.

---

# Korlátok

## Mit nem tud a mod

Ezek tudatos egyszerűsítések vagy hiányzó részek, nem hibák.

| Téma | Mi a helyzet |
|---|---|
| Foszfor-kimosódás | Nincs. A P szint csak kijuttatással és betakarítással változik. (A káliumnak van kimosódása, a szerves anyagnak lebomlása.) |
| Abszolút tartalom a térképen | A térképek a céltól való távolságot mutatják, nem a talaj tartalmát. A súgóoldal a növényenkénti elvitelt mutatja (bálázott szalmával vagy szecskázással is, ahol az eltér), célértékeket nem. Egy második oldal minden műtrágya 1000 literenkénti tartalmát listázza. |
| Talajművelés és szerves anyag | A talajművelés nem gyorsítja a lebomlást. A takarónövények bedolgozása és mulcsozása viszont szerves anyagot ad. |
| Nitrogénveszteség | Nincs (kimosódás, denitrifikáció). A PF sem modellezi, ezért a fel nem használt nitrogén a térképen marad. A mod a PF nitrogéntérképét csak a lebomló szerves anyag nitrogénjével növeli. |
| Lucerna nitrogénkötése | Nincs modellezve, a PF sem teszi. A példavetésforgókban a kaszálásonkénti hígtrágya pótolja. |
| Klorid-érzékenység | Növényenként nincs, lásd fent a Kálisó adagolását. |
| Kén és magnézium | Nincs. A Patentkali és a szuperfoszfát hordozza őket, de a játékban nincs hatásuk. Új tápanyagtérkép egyelőre nem tervezett. |
| Magyar humusztábla | Nincs. A szerves anyag számítása a német VDLUFA humuszmérleg módszerét használja, mert a magyar táblák (Nitrát kézikönyv, 59/2008 FVM, Műtrágyázási irányelvek) nem voltak elérhetők. |

## Játékszabályok, nem a valóság

Itt a mod szándékosan eltér a valóságtól, hogy a játék működjön.

- **Térképplafonok.** A P, K és OM térképek felső határát lásd a gyakori kérdéseknél. Ami ennél több kerülne a talajba, elvész.
- **A nitrogéntérkép 220 kg N/ha-os plafonja.** A Szalók térképen a PF nitrogéncélja legfeljebb 220 kg N/ha, több nitrogén nem fér a térképre. Ez a szervestrágya-példáknál korlátozza a hasznos mennyiséget (lásd [Vetésforgók](HU-06-Vetesforgok)).
- **A szerver gyors időskálája.** A számok a VirtualTSZ szerver `timeScale` 6 beállításához vannak hangolva, és az egyensúly még nincs átnézve a szerver tapasztalatai alapján. A számok változhatnak.

## Ami még nyitott

- **Multiplayer** és a kliensoldali konzolparancs-jogosultság: még nincs végigtesztelve.
- **Mod hozzáadása és eltávolítása** meglévő mentésen: nincs tesztelve.
- **A tesztlista egy része még nyitott.** A kijuttatást, a betakarítást és a számítások nagy részét a `vtszSelfTest` igazolja, de sok játékbeli ellenőrzés (például a mentés-betöltés, a mod eltávolítása, a termékek a boltban) még nincs lefuttatva.

---
Lásd még: [Foszfor](HU-02-Foszfor) · [Termékek és kijuttatás](HU-05-Termekek-es-kijuttatas) · [Technikai részletek](HU-08-Technikai-reszletek) · [Források](HU-11-Forrasok)
