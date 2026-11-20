🇬🇧 [English version](EN-07-For-Map-Makers)

> [!WARNING]
> **Fejlesztés alatt (v0.1, tesztelés).** A mod jelenleg instabil: hibákra és olyan változásokra is számíts, amelyek a mentésben lévő tápanyagtérképeket alaphelyzetbe állíthatják. Olyan mentésen ne használd, amelyet nem szeretnél elveszíteni.

# Térképkészítőknek

**A mod beállításait a térkép `map.xml` fájljából írhatod felül, a mod fájljainak szerkesztése nélkül.**

- Csak azt kell beleírned, ami eltér az alapértéktől; a többi a modból jön.
- Átírhatod a célértékeket, a kezdőértékeket, a növények elvonását és a termékek tápanyagtartalmát.
- Más térképen még nem próbáltuk, a Szalók az egyetlen tesztelt térkép.
- A mentésfájlok és a bitmélység nem módosíthatók már játszott mentésen.

Játékosként nem kell ismerned ezt az oldalt: a hétköznapi használathoz az [Első lépések](HU-01-Elso-lepesek) elég.

## Használhatom a saját térképemen?

A mod két másik modra épül, mindkettő kell hozzá: a **Precision Farming** (`FS25_precisionFarming`) és a **TR PF Configurator** (`FS25_0_TRPFConfigurator`). A térkép méretét a mod a PF talajtérképéből veszi, nem tartalmaz beégetett méretet. Ha a talajtérkép nem 2048 × 2048, a mod azt a méretet használja, és figyelmeztetést ír a logba (a TR-rel együtt 2048 a várt méret).

**Egyetlen térképen van tesztelve: a Szalókon.** Más térképen még nem próbáltuk, ezért ott hibára és ismeretlen viselkedésre számíts. Ami Szalók-specifikus:

- **A config értékei Szalókra készültek**: négy talajtípus (1 = agyagos homok, 2 = homokos vályog, 3 = vályog, 4 = iszapos agyag) célértékei és kezdőértékei, és a Szalókon termesztett növények elvonásai. Az N-célok és az N-elvonás nem a modból jön, hanem a térkép PF-blokkjából.
- **CARBOLIME** a Szalók saját terméke (cukorgyári mésziszap). Más térképen ez a configsor figyelmen kívül marad.
- **Évi 3 vágás** a fűnél, a lucernánál és a herénél (a szerveren így termesztjük): ezeknél az elvonás és az OM-nyereség vágásonkénti érték. Ha a te térképeden más a vágásszám, számold át (lásd lent).
- **`timeScale` 6** az OM-nál: a VirtualTSZ szerveren kb. 6 játékév telik el egy valós év alatt, és a szerves anyag ehhez igazodik.

Amit a mod más térképen **automatikusan átugrik**:

- olyan termék a configban (`fillType`), amely nem létezik azon a térképen (például CARBOLIME),
- olyan növény (`fruitRequirement`), amelyet a térkép nem ismer,
- olyan takarónövény a `catchCrops` listában, amely nincs a térképen.

Ezek nem okoznak hibát, a mod kihagyja őket. A naplósor csak fejlesztői naplózási szinten jelenik meg (`Logging.devInfo`), ezért egy alapbeállítású `log.txt`-ben nem biztos, hogy látod: `[VTSZ-NUT] P: fill type 'CARBOLIME' does not exist on this map, ignored`, `[VTSZ-NUT] P: unknown fruit type '...' in fruitRequirements, ignored`, `[VTSZ-NUT] catch crop fruit type '...' does not exist on this map, ignored`.

**Amit nem ugrik át, hanem a `DEFAULT` sorból számol:** ha a térképed olyan növényt ad hozzá, amelynek nincs `fruitRequirement` sora, a mod az alapsort használja. Az alap elvonás P-nél 50 kg P₂O₅ (szalma +12), K-nál 50 kg K₂O (szalma +80), az OM-nál 0. Ezek általános értékek, nem egy adott növényre mértek: a térképed saját növényeihez írj sort (lásd a recepteknél).

## Hogyan írod felül a beállításokat?

A mod kétszer olvas konfigurációt, ebben a sorrendben:

1. a saját `config/NutrientMaps.xml` fájlját (az alapértékek),
2. a térkép `map.xml` fájljának `<vtszNutrients>` blokkját, ha van (a `<map>` gyökér alatt).

A térkép blokkja ugyanazt a szerkezetet használja, mint a mod configja, és csak azt kell beleírni, ami eltér. Példa: a vályog (3. talajtípus) foszfor-célja 600 helyett 400.

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

Az `id` értéke `P`, `K` vagy `OM`. A mod mindig a `config/NutrientMaps.xml` mellett olvassa a térképét, tehát nem kell mindent átmásolnod, és a mod frissítésekor az érintetlen értékek is frissülnek.

> [!NOTE]
> A mod `config/NutrientMaps.xml` fájlját ne szerkeszd a saját térképedhez: a mod frissítése felülírja. A térkép saját beállításai a `map.xml`-be valók.

## Mi marad meg, és mi cserélődik le? (összefésülési szabályok)

Mindegyik szabályt ellenőriztük a kód alapján.

### Bejegyzésenként összefésülődik

A térkép bejegyzése a mod azonos kulcsú bejegyzését írja át, a többi érintetlen marad.

| Elem | Kulcs | Mit tart meg, ha nem adod meg |
|---|---|---|
| `target` | `soilTypeIndex` | a többi talajtípus célját |
| `initialValue` | `soilTypeIndex` | a többi talajtípus kezdőértékét; az adott talajtípus 4 zajértékét **egészében** cseréli |
| `fruitRequirement` | `fruitTypeName` | az **attribútumonként** meg nem adott értéket (például csak `removal`-t írsz, a `removalStraw` marad) |
| `fillType` | `name` | a többi termék sorát; az adott sorban a hiányzó `value` 0-ra áll, nem marad a régi |
| `leaching` / `rate` | `soilTypeIndex` | a többi talajtípus kimosódását |
| `mineralisation` | attribútumonként | a meg nem adott `rate`, `nPerPercent`, `weights` marad |
| `minimap` / `product` | `fillType` | a többi termék sora |
| `autoBaseDefault` / `product` | `fillType` | a többi termék sora |
| `rateControl` / `product` | `fillType` | a többi termék sora; **az adott sorban a hiányzó attribútum nem marad meg**, hanem az alap kerül be: `default` 100, `step` 10, `min` 10, `max` 1500 |
| `balance`, `autoRate`, `baseFertilizer` | attribútumonként | a meg nem adott attribútum marad |

A `nutrientMap` elem saját attribútumai (`step`, `timeScale`, `legendMin` …) is egyenként tartódnak meg, ha nem adod meg őket.

### Egészében cserélődik, ha jelen van

- **`<yieldMappings>`**: ha a térképed ír egy `yieldMapping` blokkot, az **összes** kulcsot meg kell adnia (a mod sorozata elvész).
- **`<phEfficiency>`** (a P térkép pH-hatékonysága): ugyanígy az egész kulcssorozat cserélődik.
- **`<catchCrops fruitTypes="…">`**: a teljes takarónövény-lista cserélődik (szóközzel elválasztott nevek).

### A 12 értékű súlyok

A `leaching#weights` (K) és a `mineralisation#weights` (OM) az évszakos súly, 12 érték, az 1. érték a március. **Csak akkor érvényes, ha pontosan 12 számot adsz meg.** Más darabszám esetén a mod csendben, hibaüzenet nélkül figyelmen kívül hagyja, és marad a mod értéke. A súlyok összegét a mod 1-re normálja, a negatív értéket 0-nak veszi, tehát az arány számít, nem az összeg.

### Globális blokkok

Ezek nem egy `nutrientMap`-hoz tartoznak: `<balance>`, `<autoRate>`, `<baseFertilizer>`, `<catchCrops>`, `<minimap>`, `<autoBaseDefault>`, `<rateControl>`. Mindhárom térképre (P, K, OM) érvényesek, a `<nutrientMaps>` mellé, közvetlenül a `<vtszNutrients>` alá kell írni őket. Egy `<nutrientMap id="P">` alá írva nincs hatásuk.

### A takarónövények sorrendje

Ha a térkép `map.xml` fájlja tartalmaz PF `coverCropBonus` listát (`<precisionFarming><subsidies><coverCropBonus><fruitType name="…"/>`), az **elsőbbséget élvez** a mod `catchCrops` listájával szemben, bármelyik `<catchCrops>` blokkal szemben (a mod sajátjával és a térkép `vtszNutrients` blokkjával is). A mod ezt a P térkép betöltésekor olvassa. Ha a lista üres vagy nincs, a `catchCrops` lista érvényes. Egy takarónövény OM-nyereségét a `fruitRequirement` `destroyGain` értéke adja, nélküle az OM térkép `catchCropGain` alapértéke (0,008 a modban, a valós idejű érték a játékban `timeScale`-lel szorozva).

## Amit valószínűleg módosítani fogsz (receptek)

### Célértékek és kezdőértékek a saját talajtípusaidhoz

A célértékek a `targets` alatt vannak talajtípusonként (P és K kg/ha, OM %). A kezdőérték a térkép első indításakor tölti fel a pixeleket, négy zajértékkel (hogy a mezőn belül is legyen szórás):

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

- Mindhárom térkép (P, K, OM) **relatív**: a talajtípus céljától való távolságot tárolja, ezért a kezdőértéket `deltas`-szal add meg: kg/ha a céltól P-nél és K-nál (például `-95 -45 5 55`), %-pont az OM-nál (például `-0.8 -0.2 0.4 0.8`). A `levels` nyers tárolt szint (relatív térképen a 120 = a célon); a `deltas` egyszerűbb. Ha kevesebb mint négy számot adsz, az utolsó érték ismétlődik.
- A `targets` a relatív térképnél is kell: a pH-hatás, a lebomlás és a nitrogén-felszabadulás ezt használja. Nem a térkép értéke, hanem a „0” helye.
- A P és K legrosszabb kezdőértéke −150, illetve −180 kg/ha (mindkettőnél a hozamtényező kb. 0,91). Az OM-nál −0,8 %-pont, hogy az OM-tényező új térképen sem esik 0,92 alá.
- A térkép tárolási tartománya a céltól: P és K −600 … +675 kg/ha (8 bit, 5 kg-os lépés, `levelOffset` 120). A P térkép kijuttatása +300-nál megáll (`maxUnits`). Ezt ne állítsd +260 alá, mert a vályog pH 5,0-nál +257-et kér.
- Minden talajtípus-indexhez, amelyet a térképed használ, adj `target` sort. A hiányzó célt a kód "nincs érték"-ként kezeli; mi történik pontosan egy kihagyott talajtípusnál, nincs tesztelve.

### Elvonás a térképed saját növényeihez

Minden P és K `fruitRequirement` a főtermék elvonása kg-ban egy tipikus hozamnál (`removal`), plusz a lehordott szalma elvonása (`removalStraw`). Az OM-nál az érték %-pont, és van `gain` (aratáskor) és `strawGain` (aprított szalmánál). Példa egy új növényre (a számok csak szemléltetnek, nem mért értékek):

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

A sorok értékeit forrásból vedd (a mod forrásait a [Források](HU-11-Forrasok) oldalon találod). A config kommentjei megadják, melyik érték honnan jön, és hol becslés.

### Vágásszám fűnél, lucernánál és herénél

A configban a fű, a lucerna és a here értékei **vágásonkénti** értékek, **évi 3 vágásra** méretezve (VirtualTSZ-gyakorlat). Ha a térképeden más a vágásszám, számold át:

- elvonás = éves elvonás / vágásszám,
- OM-nyereség = (600 + 280) × 0,0000417 / vágásszám.

A 400 az évelő takarmány nettó humusznyeresége, a 280 a gabona humuszigénye (Häq/ha/év), az 1 Häq 0,0000417 %-pont. 3 vágásnál a nyereség 0,00944 %-pont vágásonként (ez a config értéke). Példa 4 vágásra, fűnél: a config forrása az éves elvonás (0,81 kg P₂O₅ és 3,28 kg K₂O / dt szárazanyag × 80 dt SZ/ha, azaz 64,8 P₂O₅ és 262,4 K₂O), osztva 4-gyel: 16,2 P₂O₅ és 65,6 K₂O vágásonként. Az OM-nyereség (400 + 280) × 0,0000417 / 4, kb. 0,00709 %-pont.

### `timeScale`

Az OM `nutrientMap` elemén a `timeScale` minden OM-változás szorzója (lebomlás, elvonás, nyereség, takarónövény, szerves trágya OM-je). Az alap 6. Ha a szervered sebessége más, állítsd át: 1 a valós idő. A célértéket, az `nPerPercent` értéket és a térkép lépését nem skálázza.

```xml
<nutrientMap id="OM" timeScale="1"/>
```

### `baseFertilizer`

Az alapjáték FERTILIZER terméke alapból **csak N-t** ad, mint a PF-ben; a P és K a mod termékeiből jön. Ha a P és K tartalmát is be akarod kapcsolni (300 l/ha-nál +36 kg P₂O₅ és +36 kg K₂O, a configban 120/120 kg per 1000 l):

```xml
<baseFertilizer enabled="true"/>
```

### Új termék a `fillTypes` alá

Egy meglévő fill type (például egy másik modból érkező kálisó) tápanyagtartalmát a P és K `nutrientMap` `fillTypes` sorai adják (kg tápanyag per 1000 l termék; OM-nál %-pont per 1000 l per ha). A terméksűrűségből számolható: kg per 1000 l = sűrűség (t / 1000 l) × 1000 × a tápanyag aránya.

```xml
<!-- példa: 1,0 t / 1000 l sűrűségű, 60 % K2O-t tartalmazó termék: 1,0 × 1000 × 0,60 = 600 -->
<nutrientMap id="K">
  <fillTypes>
    <fillType name="MYPRODUCT" value="600"/>
  </fillTypes>
</nutrientMap>
```

Amire figyelj:

- A **szilárd** új termék a töltősíkot a FERTILIZERrel osztja meg, és ehhez a `scripts/VtszNutrients.lua` fájl `SOLID_PRODUCTS` listájába is be kell írni a nevét. Ez a mod kódjának módosítása, tehát csak a mod saját termékeihez (és ha te forkolod a modot) lehetséges, egy térkép `map.xml` felől nem.
- Ha egy N-et nem tartalmazó terméknek saját kijuttatási mennyiség kell, vedd fel a `<rateControl>` listába (`default`, `step`, `min`, `max` l/ha).
- Termék felvétele vagy törlése eltolja a mentett termékazonosítókat; egy menetre a termékzár tévedhet. Részletek: [Technikai részletek](HU-08-Technikai-reszletek).

### Takarónövények

A takarónövények OM-nyeresége az OM térkép `fruitRequirement` sorában a `destroyGain`. Sor nélkül az OM `catchCropGain` érték érvényes (0,008, szorozva `timeScale`-lel). Ha a térképnek van PF `coverCropBonus` listája, az elsőbbséget élvez a mod `catchCrops` listájával szemben (lásd fent).

## Attribútumok és globális blokkok

<details>
<summary><strong>A <code>nutrientMap</code> elem attribútumai</strong></summary>

| Attribútum | Jelentés | P | K | OM |
|---|---|---|---|---|
| `id` | `P`, `K` vagy `OM` | P | K | OM |
| `numChannels` | bitmélység (a mentésfájl neve ettől függ) | 8 | 8 | 8 |
| `step` | egy szint értéke a térkép egységében | 5 | 5 | 0,0243137 |
| `unitFormat` | a kijelzés formátuma | `%+d kg/ha P2O5` | `%+d kg/ha K2O` | `%+.2f %%` |
| `legendMin`, `legendMax` | a jelmagyarázat ablaka (alapból 8 színsáv, a `numBands` mást ad meg, a K 15-öt használ), a céltól | −300 / +100 | −600 / +300 | −1,4 / 0,2 |
| `surplusFrom` | `surplusColors` mellett: itt ér véget a zöld és kezdődik a kék többletszín (K: 200, a túlellátási büntetés kezdete) | 0 | 200 | 0 |
| `levelOffset` | egész, ≥ 0. Ha > 0, a térkép relatív (a cél körül tárol): érték = (szint − `levelOffset`) × `step` | 120 | 120 | 165 |
| `maxUnits` | opcionális lágy plafon a térkép egységében: a kijuttatás és a `vtszNutrientSet` nem visz a pixel fölé | 300 | nincs | nincs |
| `strawChopperGain` | OM/P/K nyereség aprított szalmánál (alap: a növény `strawGain`) | 0 | 0 | 0 |
| `catchCropGain` | takarónövény-nyereség (alap: a növény `destroyGain`) | 0 | 0 | 0,008 |
| `yieldScaling` | az aratási változás hozamkövetése (1 teljes, 0 rögzített) | 1 (alap) | 1 (alap) | 0,5 |
| `timeScale` | az összes változás időszorzója, ≥ 0 | 1 (alap) | 1 (alap) | 6 |
| `targetRemovalShare` | a növény célja = talajcél × `targetScale` + ez × a főtermék elvonása, ≥ 0. Relatív térképen a térkép csak a talajt mutatja, ez a rész a növény többlete a talajcél fölött. Az alap konfig P-re és K-ra 0-t használ, így a cél minden növénynél a talajtípus célja | 0 (alap) | 0 (alap) | 0 (alap) |

A P és K térkép `yieldScaling` és `timeScale` attribútuma a configban nincs kiírva, az alap érvényes (`yieldScaling` 1, `timeScale` 1). A `levelOffset` és a `maxUnits` a P-nél kiírt, a K-nál csak a `levelOffset` (nincs `maxUnits`, azaz nincs lágy plafon).

</details>

<details>
<summary><strong>A <code>fruitRequirement</code> elem attribútumai</strong></summary>

| Attribútum | Jelentés |
|---|---|
| `fruitTypeName` | a növény neve; a `DEFAULT` sor a megadott növénysor nélküli növényekre érvényes |
| `removal` | a főtermék elvonása egy tipikus hozamnál (P, K: kg/ha; OM: %-pont) |
| `removalStraw` | extra elvonás, ha a szalma lekerül a földről (nem aprított) |
| `forageRemoval` | szecskázásnál / kaszánál az OM-változás −(max(`removal`, `forageRemoval`) + `removalStraw`), nyereség nélkül |
| `gain` | nyereség aratásonként (OM) |
| `strawGain` | nyereség a `removalStraw` helyett, ha az aprító be van kapcsolva (alap: `strawChopperGain`) |
| `destroyGain` | nyereség, ha a takarónövényt bedolgozzák (alap: `catchCropGain`) |
| `targetScale` | a talajcél szorzója az adott növényre (alap 1) |
| `targetRemovalShare` | a növény saját aránya a célban (felülírja a térkép értékét) |

A megadatlan `removal`, `removalStraw` alapértéke 0, a `targetScale` alapértéke 1.

</details>

<details>
<summary><strong>Térkép-szintű elemek a <code>nutrientMap</code> alatt</strong></summary>

| Elem | Attribútumok | Alapérték a configban |
|---|---|---|
| `initialValues/initialValue` | `soilTypeIndex`, `deltas` (relatív térkép: P, K kg/ha, OM %-pont a céltól) vagy `levels` (tárolt szintek, abszolút térképhez) | lásd a config |
| `targets/target` | `soilTypeIndex`, `value` | P 420/500/600/460, K 500/700/740/820, OM 1,8/2,5/3,2/4,0 |
| `yieldMappings/yieldMapping` | `difference`, `yieldFactor` (a kulcsok közt lineáris) | lásd a config |
| `phEfficiency/key` (csak P) | `ph`, `value` (0,3–1 közé szorítva, pH szerint rendezve; a tartományon kívül az első / utolsó érték marad) | 5,0 → 0,70 … 6,2–7,2 → 1,00 … 8,2 → 0,80 |
| `fruitRequirements/fruitRequirement` | lásd fent | lásd a config |
| `fillTypes/fillType` | `name`, `value` (kg per 1000 l; OM: %-pont per 1000 l) | lásd a config |
| `leaching` (csak K) | `weights` (12 érték), `rate`: `soilTypeIndex`, `value` (kg K₂O/ha/év) | súlyok 0,16 0,12 0,08 0,06 0,03 0,02 0,03 0,06 0,10 0,11 0,11 0,12; arány 40/25/15/10 |
| `mineralisation` (csak OM) | `rate` (éves veszteség a cél törtrészében), `weights` (12 érték), `nPerPercent` (kg N/ha/év 1 % OM-ra) | 0,00365; súlyok 0,06 0,09 0,11 0,13 0,15 0,15 0,12 0,08 0,05 0,02 0,02 0,02; 8 |

A kimosódás csak a talajtípus célján (relatív térképen a 0-n) vagy fölötte lévő tartalmat érinti. Egy térkép `map.xml`-ében a `leaching` blokk elhagyása nem kapcsolja ki a kimosódást, mert a mod configja a térkép előtt töltődik be és megmarad. Kikapcsoláshoz a térkép adja meg a `rate` értékeket 0-val. A `mineralisation` `rate="0"` az OM lebomlását és az N-leadást kapcsolja ki.

</details>

<details>
<summary><strong>Globális blokkok</strong></summary>

| Blokk | Attribútumok | Alapérték | Hatás |
|---|---|---|---|
| `<balance>` | `inputScale`, `removalScale`, `yieldReference` | 1, 1, 1,5 | `inputScale`: kijuttatás, aratási nyereség, takarónövény-nyereség. `removalScale`: aratási elvonás, OM lebomlás és a belőle leadott N, K kimosódás, a `targetRemovalShare` növényi része (0 leállítja a lebomlást és az N-leadást is). `yieldReference`: az a PF hozamszorzó, amelyre az elvonások vonatkoznak; 0 kikapcsolja a hozamskálát |
| `<autoRate>` | `maxLitersPerHa` | 2500 | az automatikus P/K mennyiség felső korlátja (l/ha). A mennyiség maga a mezőinfóban látható célig tartó hiány, építési idő és a betakarítás elvonásának pótlása nélkül |
| `<baseFertilizer>` | `enabled` | false | az alapjáték FERTILIZER P és K tartalma |
| `<catchCrops>` | `fruitTypes` | OILSEEDRADISH MUSTARD HUMUSACTIVE FLOWERINGCATCHCROP | a takarónövények listája (szóközzel elválasztva) |
| `<minimap>` | `product`: `fillType`, `map` (`N`, `P`, `K`, `OM`) | MANURE, LIQUIDMANURE, DIGESTATE → N | a minitérkép rétege szóráskor; az alap a termék legnagyobb tartalmú tápanyaga |
| `<autoBaseDefault>` | `product`: `fillType`, `base` (`N`, `P`, `K`) | MANURE, LIQUIDMANURE, DIGESTATE → N | az automatikus mennyiség alap tápanyaga |
| `<rateControl>` | `product`: `fillType`, `default`, `step`, `min`, `max` (l/ha) | TSP46 230/25/10/800, SSP18 240/25/10/800, KALISO60 230/25/10/450, PATENTKALI 210/25/10/800 | saját kijuttatási mennyiség az N nélküli termékeknek |

A fill type nevek kis- és nagybetűre nem érzékenyek (a mod nagybetűre alakítja).

</details>

## Mentésfájlok

A térképek a mentés mappájába kerülnek `.grle` fájlként:

| Térkép | Fájl |
|---|---|
| Foszfor (P) | `vtsz_pMap8.grle` |
| Kálium (K) | `vtsz_kMap8.grle` |
| Szerves anyag (OM) | `vtsz_omMap8.grle` |
| Utolsó kijuttatott termék (zár, 5 bit, csak a szerveren) | `vtsz_productMap.grle` |

A fájlnév a bitmélységtől függ: 5 bit esetén `vtsz_<id>Map.grle`, bármely más mélységnél `vtsz_<id>Map<bit>.grle` (innen a `vtsz_pMap8`, a `vtsz_kMap8` és a `vtsz_omMap8`). A korábbi verziók a P és K térképet 5 biten tárolták (`vtsz_pMap.grle`, `vtsz_kMap.grle`, abszolút értékek). Ezeket a fájlokat most figyelmen kívül hagyja a mod, ezért egy régebbi verzió mentése a P és K térképet újra a kezdőértékekről indítja.

> [!WARNING]
> A `numChannels` megváltoztatása **új térképet indít**: a mentésben lévő régi mélységű fájlt a mod nem találja meg (így járnak a régi, 5 bites P és K térképet tartalmazó mentések is: a mod az új, 8 bites fájlt keresi, ezért a P és K a kezdőértékekről indul), ezért a térkép az `initialValues` kezdőértékeiről indul, a játékos addigi P/K/OM állapota elvész. Ugyanez történik, ha a mentett térkép mérete eltér a PF talajtérképétől: a mod újraépíti a térképet a kezdőértékekből. Egy már játszott mentésen ne változtasd a bitmélységet.

![Képernyőkép hamarosan: log.txt részlet a három [VTSZ-NUT] térképsorral (P, K, OM) betöltéskor](images/placeholder-map-makers-log-lines.jpg)

Betöltéskor a `log.txt`-ben három sort kell látnod, térképenként egyet, például `[VTSZ-NUT] P map 2048 x 2048, 8 bit, step 5, new` (új térkép) vagy a végén `loaded from savegame` (betöltött mentés).

Lásd még: [Első lépések](HU-01-Elso-lepesek) · [Technikai részletek](HU-08-Technikai-reszletek) · [Konzolparancsok](HU-09-Konzolparancsok) · [Ismert korlátok](HU-10-Ismert-korlatok)
