🇬🇧 [English version](EN-11-Sources)

> [!WARNING]
> **Fejlesztés alatt (v0.1, tesztelés).** A mod fejlesztés alatt áll, változások történhetnek, akár a tápanyagtérképek alaphelyzetbe állása is. Mindig legyen biztonsági másolatod a mentésedről.

# Források

**Ez az oldal azt mutatja meg, honnan származnak a mod számai.** Annak szól, aki ellenőrizni akarja őket.

A játékhoz egyszerűsítettünk, ezért az értékek **becslések (±20–30 %)**, ahol nincs másképp jelölve. Az **(E)** forrás nélküli becslést jelent. A magyar trágya- és elvonási táblák (Nitrát kézikönyv, 59/2008 FVM, Műtrágyázási irányelvek) nem voltak elérhetők, ezért német értékeket használunk.

A források címei a mod forráselemzéséből származnak. Linket csak ott adunk, ahol biztos, stabil címünk van. URL-eket még nem gyűjtöttünk, ezért az alábbi tételek egyelőre csak címek.

## Humusz és szerves anyag

- **VDLUFA Standpunkt „Humusbilanzierung” (2014):** humuszéquivalensek (Häq), humuszigény és -nyereség, szerves trágyák értékei. Ebből jön a szerves anyag számítása.
- **Hosszú távú kísérletek (Groß Kreutz):** a szalma humuszértéke kb. 55 Häq/t (a VDLUFA alapérték 100). A mod az 55-öt használja a melléktermékekre.
- **Magyar talajok szervesanyag-tartománya:** agyagos homok 1,8 %, homokos vályog 2,5 %, vályog 3,2 %, iszapos agyag 4,0 %. Szakirodalmi tartományok alapján becsült célok (E).

## P és K elvonás, szerves trágyák tartalma

- **LfL Bayern, Basisdaten (2025):** gabonák, kukorica, repce, napraforgó, répa és burgonya elvonása; az 5a. táblázat a trágyák tápanyagtartalma; a 2. táblázat a fű (0,81 kg P₂O₅ és 3,28 kg K₂O / dt szárazanyag, 80 dt SZ/ha, legalább 3 vágás).
- **Szója:** IPNI / Ohio State (29–39 kg P₂O₅, kb. 57 kg K₂O 3 t/ha termésnél); LfL (15 és 17 kg/t).
- **Cirok:** Embrapa (silókukorica és cirok mérlege, kb. 5,2 kg P₂O₅ és 15,7 kg K₂O / t szárazanyag). A mod értéke silókukoricából származtatott (E).
- **Lucerna, here:** kb. 6 kg P₂O₅ és 28–30 kg K₂O / t széna, 10 t széna évente, 3 vágás (E).

## Célértékek és ellátottság

- **NAK Zsebkönyv, MÉM-NAK, Csathó:** AL-P₂O₅ és AL-K₂O ellátottsági osztályok. 1 mg/kg AL-kivonat kb. 4 kg/ha (0–30 cm, saját számítás).
- **Növényfüggő cél (építő + fenntartó trágyázás):** VDLUFA ellátottsági osztályok, Sachsen LfULG (P-Düngebedarf), Merkblatt Düngeplanung Phosphor (RLP), Mallarino (Iowa State, 2026). A K-arány (0,5) játékegyensúlyi becslés.
- **Hozamgörbék (a padló 0,65):** hosszú távú, P és K nélküli kísérletek 20–40 % veszteséget mutatnak. A szerver 3–5-szörös sebessége miatt ez játékegyensúly, nem mért érték.

## pH, kimosódás, nitrogén

- **P felvehetősége és a pH:** Füleky (magyar talajok); meszes talajok áttekintése (optimum pH 6,5–7,5). A százalékos értékek becslések (E).
- **K kimosódás:** UK potash note (kb. 1,2 kg K₂O / 100 mm), dán tanulmány (0,6 és 8,4 kg / 100 mm 24 és 5 % agyagnál), 150–250 mm éves lefolyás. A talajtípusonkénti értékek becslések (E).
- **Nitrogén-felszabadulás az OM-ból:** UC ANR (22–45 kg N / 1 % OM), szakirodalmi +10–20 kg N / 1 % OM. A mod ennél kisebb, nettó értéket használ.
- **Klorid (a Kálisó korlátja):** APNI, K+S: a szokásos növények kb. 140 kg Cl/ha-ig nem mutatnak kárt, a klorid-érzékenyek kb. 675 kg Cl/ha-ig; burgonya-kísérletek 115–237 kg KCl/ha. Egy forrás sem ad kemény egyszeri határt, a 450 l/ha korlát engedékeny becslés.

## Termékek

- **NÉBIH termék-nyilvántartás; Nitrogénművek biztonsági adatlapok** (Pétisó 27, Nitrosol UAN 30 % N, sűrűség 1,275); forgalmazói adatlapok (MAP, TSP, Kálisó 60, NPK-k, Patentkali, Szuperfoszfát, Karbamid). A szuperfoszfát, az NPK 8-24-24 és a Patentkali egyes adatai becslések (E).
- **Élesztővinasz:** NÉBIH (szárazanyagra: OM ≥ 60 %, N ≥ 3 %, P₂O₅ ≥ 0,5 %, K₂O ≥ 5 %). A híg (60 %-os) minőség és az OM-érték becslés.
- **Cukorgyári mésziszap (CARBOLIME):** Nordzucker és AGRANA (Carbokalk) adatlapok (CaO, P₂O₅, K₂O, N). Az OM-hatás becslés (E).
- **Árak:** játékbeli árak, becsült 2026-os EU-árarányokból skálázva (viszonyítás: pétisó, karbamid, MOP; a MAP, TSP, SSP, Patentkali és NPK ára is becsült). Nem euróárak.

## Játék és Precision Farming adatok

- **Precision Farming** (a dekompilált `FS25_precisionFarming` szkriptek, csak olvasásra): `NitrogenMap.lua` (N-elvonás, aprított szalma +25 kg N, hozamgörbe), `HarvestExtension.lua` (aratás, kaszálás, hozamszorzó), `CoverMap.lua`.
- **Szalók `map.xml` (`<precisionFarming>`):** N-célok, elvonások és hozampotenciálok növényenként és talajtípusonként. A 220 kg/ha-os nitrogénplafon játékszabály.
- **Alapjáték `foliage/*.xml`:** `chopperType` (az aprítással +25 kg N-t kapó növények), `maps_fruitTypes.xml`.

---
Lásd még: [Ismert korlátok](HU-10-Ismert-korlatok) · [Szerves anyag](HU-04-Szerves-anyag) · [Foszfor](HU-02-Foszfor) · [Kálium](HU-03-Kalium)
