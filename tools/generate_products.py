"""Generates the fertilizer products of the mod (fill types, shop items, TR spray types, l10n, nutrient contents).

Run from the mod folder:  python tools/generate_products.py
Writes: xml/fillTypes.xml, shop/*.xml, xml/products_modDesc.snippet.xml (to paste into modDesc.xml),
        xml/products_nutrients.snippet.xml (fillType rows for config/NutrientMaps.xml), l10n/products_*.snippet.xml.
The generated files are committed; edit this table and run again to change a product.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# density: t per 1000 l (real, researched: UAN 30 N 1.275, yeast vinasse 1.26; the engine takes any massPerLiter for a liquid, and PF
# divides by it itself, so thPFConfig nitrogen amount stays the N mass fraction). price: per 1000 l (one bag / IBC). Balance: base game solid fert = 1920 per 1000 l (was 1000), so CAN 27 (density 1.0) = 1920;
# other solids = 1000 x real EUR/t ratio to CAN x density (CAN ~370, urea ~550, MAP ~750, TSP ~600, SSP ~230, MOP ~400, patentkali ~480, NPK ~480-520);
# UAN priced at the base game liquid fert cost per kg N (base 1.6/l = 3200 per 2000 l, was 1.2/l; 39% N); vinasse low (organic by-product).
# n/p/k: fraction of the product mass (N, P2O5, K2O). om: percent points per 1000 l per ha (E).
# regular: PF regularRate kg N/ha; None = no nitrogen, PF does not manage it.
PRODUCTS = [
    dict(id="PETISO27", hu="Pétisó 27 (27-0-0)", en="CAN 27 (27-0-0)", liquid=False, density=1.0, price=1920, n=0.27, p=0, k=0, om=0, regular=100),
    dict(id="KARBAMID46", hu="Karbamid (46-0-0)", en="Urea (46-0-0)", liquid=False, density=0.75, price=2150, n=0.46, p=0, k=0, om=0, regular=100),
    dict(id="MAP11_52", hu="MAP (11-52-0)", en="MAP (11-52-0)", liquid=False, density=0.96, price=3740, n=0.11, p=0.52, k=0, om=0, regular=40),
    dict(id="TSP46", hu="Tripleszuperfoszfát (0-46-0)", en="Triple superphosphate (0-46-0)", liquid=False, density=1.1, price=3420, n=0, p=0.46, k=0, om=0, regular=None),
    dict(id="SSP18", hu="Szuperfoszfát (0-18-0)", en="Single superphosphate (0-18-0)", liquid=False, density=1.05, price=1250, n=0, p=0.18, k=0, om=0, regular=None),
    dict(id="KALISO60", hu="Kálisó 60 (0-0-60)", en="Potassium chloride 60 MOP (0-0-60)", liquid=False, density=1.1, price=2290, n=0, p=0, k=0.60, om=0, regular=None),
    dict(id="PATENTKALI", hu="Patentkali (0-0-30)", en="Patentkali (0-0-30)", liquid=False, density=1.19, price=2980, n=0, p=0, k=0.30, om=0, regular=None),
    dict(id="NPK15_15_15", hu="NPK (15-15-15)", en="NPK (15-15-15)", liquid=False, density=1.05, price=2630, n=0.15, p=0.15, k=0.15, om=0, regular=100),
    dict(id="NPK8_24_24", hu="NPK (8-24-24)", en="NPK (8-24-24)", liquid=False, density=1.05, price=2820, n=0.08, p=0.24, k=0.24, om=0, regular=40),
    dict(id="NITROSOL30", hu="Nitrosol UAN (30-0-0)", en="Nitrosol UAN (30-0-0)", liquid=True, density=1.275, price=1267, n=0.30, p=0, k=0, om=0, regular=100),
    dict(id="ELESZTOVINASZ", hu="Élesztővinasz (3-0,5-5)", en="Yeast vinasse (3-0.5-5)", liquid=True, density=1.26, price=453, n=0.018, p=0.003, k=0.03, om=0.0028, regular=40),
]

# store icons: shop/store_<ID>.png, rendered with the GIANTS FS Icon Generator (tools/make_icongen.py)
HUD_SOLID = "$dataS/menu/hud/fillTypes/hud_fill_fertilizer.png"
HUD_LIQUID = "$dataS/menu/hud/fillTypes/hud_fill_liquidFertilizer.png"


def num(x):
    s = ("%.6f" % x).rstrip("0").rstrip(".")
    return s or "0"


def write(rel, text):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def fill_types_xml():
    out = ['<?xml version="1.0" encoding="utf-8" standalone="no" ?>', "<map>", "    <fillTypes>"]
    for p in PRODUCTS:
        hud = HUD_LIQUID if p["liquid"] else HUD_SOLID
        pallet = "shop/ibc_%s.xml" % p["id"] if p["liquid"] else "shop/bigBag_%s.xml" % p["id"]
        price = p["price"] / 1000.0
        out.append('        <fillType name="%s" title="$l10n_vtsz_ft_%s" showOnPriceTable="true" isBulkType="true" unitShort="$l10n_unit_literShort">' % (p["id"], p["id"]))
        out.append('            <physics massPerLiter="%s" maxPhysicalSurfaceAngle="%d" />' % (num(p["density"]), 0 if p["liquid"] else 15))
        out.append('            <economy pricePerLiter="%s" />' % num(price))
        if not p["liquid"]:
            out.append("            <effects>")
            out.append('                <alphaClip beltAlphaScale="0.29"/>')
            out.append("            </effects>")
        out.append('            <image hud="%s" />' % hud)
        out.append('            <pallet filename="%s" />' % pallet)
        if not p["liquid"]:
            out.append('            <textures diffuse="$data/fillPlanes/fertilizer_diffuse.png" unitSize="0.4" blendContrast="0.2" noiseScale="0.5" porosityAtZeroRoughness="0.9" porosityAtFullRoughness="1"')
            out.append('                      normal="$data/fillPlanes/fertilizer_normal.png"')
            out.append('                      height="$data/fillPlanes/fertilizer_height.png"')
            out.append('                      displacement="$data/fillPlanes/fertilizer_displacement.png" displacementMaxHeight="0.2" firmness="0.3" viscosity="0.5"')
            out.append('                      distance="$data/fillPlanes/distance/fertilizerDistance_diffuse.png" />')
        out.append("        </fillType>")
        out.append("")
    out.append("    </fillTypes>")
    out.append("")
    out.append("    <fillTypeCategories>")
    solids = " ".join(p["id"] for p in PRODUCTS if not p["liquid"])
    liquids = " ".join(p["id"] for p in PRODUCTS if p["liquid"])
    out.append("        <!-- vanilla categories: solids behave like FERTILIZER (spreaders, bulk storage, shovels), liquids like LIQUIDFERTILIZER (sprayers) -->")
    for cat in ("SPREADER", "BULK", "SHOVEL", "AUGERWAGON", "LOADINGVEHICLE"):
        out.append('        <fillTypeCategory name="%s">%s</fillTypeCategory>' % (cat, solids))
    out.append('        <fillTypeCategory name="SPRAYER">%s</fillTypeCategory>' % liquids)
    out.append("    </fillTypeCategories>")
    out.append("</map>")
    out.append("")
    write("xml/fillTypes.xml", "\n".join(out))


def bag_xml(p):
    ft = p["id"]
    return """<?xml version="1.0" encoding="utf-8" standalone="no" ?>
<vehicle type="bigBag" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="../../../shared/xml/schema/vehicle.xsd">
    <parentFile xmlFilename="$data/objects/bigBag/bigBag.xml">
        <attributes>
            <set path="vehicle.storeData.name" value="$l10n_vtsz_ft_%(ft)s"/>
            <set path="vehicle.storeData.image" value="%(icon)s"/>
            <set path="vehicle.storeData.price" value="%(price)d"/>
            <set path="vehicle.storeData.brand" value="NONE"/>
            <set path="vehicle.storeData.functions.function" value="$l10n_vtsz_function_bag"/>
            <set path="vehicle.storeData.financeCategory" value="PURCHASE_FERTILIZER"/>

            <set path="vehicle.fillUnit.fillUnitConfigurations.fillUnitConfiguration(0).fillUnits.fillUnit#fillTypes" value="%(ft)s"/>
            <set path="vehicle.fillUnit.fillUnitConfigurations.fillUnitConfiguration(0).fillUnits.fillUnit#startFillType" value="%(ft)s"/>
            <set path="vehicle.fillUnit.fillUnitConfigurations.fillUnitConfiguration(0).fillUnits.fillUnit#capacity" value="1000"/>
            <set path="vehicle.fillUnit.fillUnitConfigurations.fillUnitConfiguration(0).fillUnits.fillUnit#startFillLevel" value="1000"/>
            <set path="vehicle.fillUnit.fillUnitConfigurations.fillUnitConfiguration(0).fillUnits.fillUnit.fillTypeMaterials.material(1)#fillType" value="%(ft)s"/>
            <set path="vehicle.fillUnit.fillUnitConfigurations.fillUnitConfiguration(0).fillUnits.fillUnit.fillTypeMaterials.material(1)#refNode" value="fertilizerHelm_mat"/>
            <!-- own copy of the bag model, its Helm material carries our label texture (tools/generate_textures.py) -->
            <set path="vehicle.base.filename" value="models/vtszBag_%(ft)s.i3d"/>
        </attributes>
    </parentFile>

    <!-- ONLY FOR ICON GENERATION -->
    <storeData>
        <name>$l10n_vtsz_ft_%(ft)s</name>
        <image>%(icon)s</image>
        <brand>NONE</brand>
        <category>bigbags</category>
        <storeIconRendering>
            <settings cameraXRot="-15" cameraYRot="35"/>
        </storeIconRendering>
        <vertexBufferMemoryUsage>0</vertexBufferMemoryUsage>
        <indexBufferMemoryUsage>0</indexBufferMemoryUsage>
        <textureMemoryUsage>0</textureMemoryUsage>
        <audioMemoryUsage>0</audioMemoryUsage>
        <instanceVertexBufferMemoryUsage>0</instanceVertexBufferMemoryUsage>
        <instanceIndexBufferMemoryUsage>0</instanceIndexBufferMemoryUsage>
    </storeData>
</vehicle>
""" % dict(ft=ft, icon="shop/store_%s.png" % ft, price=p["price"])


def bag_multi_xml(p):
    ft = p["id"]
    prices = "\n".join('        <multipleItemPurchaseAmountConfiguration name="%d" price="%d"/>' % (i, 0 if i == 1 else p["price"] * (i - 1)) for i in range(1, 9))
    return """<?xml version="1.0" encoding="utf-8" standalone="no" ?>
<vehicle type="multipleItemPurchase" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="../../../shared/xml/schema/vehicle.xsd">
    <storeData>
        <name>$l10n_vtsz_ft_%(ft)s</name>
        <specs>
            <weight ignore="true"/>
        </specs>
        <functions>
            <function>$l10n_vtsz_function_bag</function>
        </functions>
        <image>%(icon)s</image>
        <price>%(price)d</price>
        <lifetime>600</lifetime>
        <allowLeasing>false</allowLeasing>
        <canBeSold>false</canBeSold>
        <rotation>0</rotation>
        <brand>NONE</brand>
        <category>bigbags palletFertilizerHerbicide</category>
        <financeCategory>PURCHASE_FERTILIZER</financeCategory>
        <shopLoadingDelay initial="0.2" config="0.2"/>
        <vertexBufferMemoryUsage>512</vertexBufferMemoryUsage>
        <indexBufferMemoryUsage>256</indexBufferMemoryUsage>
        <textureMemoryUsage>65536</textureMemoryUsage>
        <instanceVertexBufferMemoryUsage>0</instanceVertexBufferMemoryUsage>
        <instanceIndexBufferMemoryUsage>0</instanceIndexBufferMemoryUsage>
        <storeIconRendering>
            <settings cameraXRot="-15" cameraYRot="35"/>
        </storeIconRendering>
        <audioMemoryUsage>0</audioMemoryUsage>
    </storeData>

    <base>
        <typeDesc>$l10n_typeDesc_pallet</typeDesc>
        <filename>$data/objects/multiPurchaseItem/multiPurchaseItem.i3d</filename>
        <size width="2.0" length="3.4" height="1.65"/>
        <components>
            <component centerOfMass="0 0 0" solverIterationCount="10" mass="100"/>
        </components>
    </base>

    <fillUnit>
        <fillUnitConfigurations>
            <fillUnitConfiguration>
                <fillUnits>
                    <fillUnit fillTypes="%(ft)s" capacity="1000" />
                </fillUnits>
            </fillUnitConfiguration>
        </fillUnitConfigurations>
    </fillUnit>

    <multipleItemPurchase filename="shop/bigBag_%(ft)s.xml" isVehicle="true">
        <offsets>
            <offset amount="2" offset="0.5 0 0"/>
            <offset amount="3" offset="0.5 0 0.425"/>
            <offset amount="5" offset="0.5 0 0.850"/>
            <offset amount="7" offset="0.5 0 1.275"/>
        </offsets>
        <itemPositions>
            <itemPosition position="0 0 0" rotation="0 0 0"/>
            <itemPosition position="-1 0 0" rotation="0 0 0"/>
            <itemPosition position="0 0 -0.85" rotation="0 0 0"/>
            <itemPosition position="-1 0 -0.85" rotation="0 0 0"/>
            <itemPosition position="0 0 -1.7" rotation="0 0 0"/>
            <itemPosition position="-1 0 -1.7" rotation="0 0 0"/>
            <itemPosition position="0 0 -2.55" rotation="0 0 0"/>
            <itemPosition position="-1 0 -2.55" rotation="0 0 0"/>
        </itemPositions>
    </multipleItemPurchase>

    <multipleItemPurchaseAmountConfigurations>
%(prices)s
    </multipleItemPurchaseAmountConfigurations>
</vehicle>
""" % dict(ft=ft, icon="shop/store_%s.png" % ft, price=p["price"], prices=prices)


def ibc_xml(p):
    ft = p["id"]
    return """<?xml version="1.0" encoding="utf-8" standalone="no" ?>
<vehicle type="pallet" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="../../../shared/xml/schema/vehicle.xsd">
    <storeData>
        <name>$l10n_vtsz_ft_%(ft)s</name>
        <functions>
            <function>$l10n_vtsz_function_ibc</function>
        </functions>
        <specs>
            <capacity>1000</capacity>
            <fillTypes>%(ft)s</fillTypes>
            <weight ignore="true"/>
        </specs>
        <image>%(icon)s</image>
        <price>%(price)d</price>
        <allowLeasing>false</allowLeasing>
        <canBeSold>false</canBeSold>
        <showInStore>false</showInStore>
        <rotation>0</rotation>
        <shopHeight>2</shopHeight>
        <brand>NONE</brand>
        <category>ibc palletFertilizerHerbicide</category>
        <financeCategory>PURCHASE_FERTILIZER</financeCategory>
        <vertexBufferMemoryUsage>54784</vertexBufferMemoryUsage>
        <indexBufferMemoryUsage>18176</indexBufferMemoryUsage>
        <textureMemoryUsage>458752</textureMemoryUsage>
        <instanceVertexBufferMemoryUsage>0</instanceVertexBufferMemoryUsage>
        <instanceIndexBufferMemoryUsage>0</instanceIndexBufferMemoryUsage>
        <storeIconRendering>
            <settings cameraXRot="-15" cameraYRot="25" />
        </storeIconRendering>
        <audioMemoryUsage>0</audioMemoryUsage>
    </storeData>

    <base>
        <typeDesc>$l10n_typeDesc_pallet</typeDesc>
        <filename>models/vtszTank_%(ft)s.i3d</filename>
        <size width="1.35" length="1.35" height="1.55" />
        <input allowed="false"/>
        <canBeReset>false</canBeReset>
        <components maxMass="850">
            <component centerOfMass="0 0.1 0" solverIterationCount="10" mass="100" />
        </components>
        <showInVehicleMenu>false</showInVehicleMenu>
        <mapHotspot available="false" />

        <objectChanges>
            <!-- Helm decal slot shows our label (own i3d copy, tools/generate_textures.py); the second decal (herbicide) and the Corteva logo are hidden -->
            <objectChange node="helmConfiguration"          visibilityActive="true"/>
            <objectChange node="decalHelmLiquidHerbicide"   visibilityActive="false"/>
            <objectChange node="cortevaConfiguration"       visibilityActive="false"/>
        </objectChanges>
    </base>

    <fillUnit>
        <fillUnitConfigurations>
            <fillUnitConfiguration>
                <fillUnits removeVehicleIfEmpty="true">
                    <fillUnit unitTextOverride="$l10n_unit_literShort" fillTypes="%(ft)s" capacity="1000" startFillType="%(ft)s" startFillLevel="1000" ignoreFillLimit="true">
                        <fillRootNode node="0>" />
                    </fillUnit>
                </fillUnits>
            </fillUnitConfiguration>
        </fillUnitConfigurations>
    </fillUnit>

    <fillTriggerVehicle triggerNode="fillTrigger" fillUnitIndex="1" litersPerSecond="200"/>

    <dynamicMount triggerNode="dynamicMountTrigger" triggerForceAcceleration="5" additionalMountDistance="1.5" jointTransY="0.11" jointLimitToRotY="true"/>

    <dischargeable requiresTipOcclusionArea="false" />

    <tensionBeltObject>
        <meshNodes>
            <meshNode node="fertilizerTank_vis"/>
        </meshNodes>
    </tensionBeltObject>

    <i3dMappings>
        <i3dMapping id="dynamicMountTrigger" node="0>0|0" />
        <i3dMapping id="fillTrigger" node="0>0|1" />
        <i3dMapping id="floorCollision01" node="0>1|0" />
        <i3dMapping id="floorCollision02" node="0>1|1" />
        <i3dMapping id="helmConfiguration" node="0>2|0" />
        <i3dMapping id="decalHelmLiquidHerbicide" node="0>2|0|0" />
        <i3dMapping id="decalHelmLiquidFertilizer" node="0>2|0|1" />
        <i3dMapping id="cortevaConfiguration" node="0>2|1" />
        <i3dMapping id="fertilizerTank_vis" node="0>3|0" />
        <i3dMapping id="materialHerbicide" node="0>3|1" />
    </i3dMappings>
</vehicle>
""" % dict(ft=ft, icon="shop/store_%s.png" % ft, price=p["price"])


def ibc_multi_xml(p):
    ft = p["id"]
    prices = "\n".join('        <multipleItemPurchaseAmountConfiguration name="%d" price="%d"/>' % (i, 0 if i == 1 else p["price"] * (i - 1)) for i in range(1, 9))
    return """<?xml version="1.0" encoding="utf-8" standalone="no" ?>
<vehicle type="multipleItemPurchase" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="../../../shared/xml/schema/vehicle.xsd">
    <storeData>
        <name>$l10n_vtsz_ft_%(ft)s</name>
        <specs>
            <weight ignore="true"/>
        </specs>
        <functions>
            <function>$l10n_vtsz_function_ibc</function>
        </functions>
        <image>%(icon)s</image>
        <price>%(price)d</price>
        <allowLeasing>false</allowLeasing>
        <canBeSold>false</canBeSold>
        <rotation>0</rotation>
        <shopHeight>2</shopHeight>
        <brand>NONE</brand>
        <category>ibc palletFertilizerHerbicide</category>
        <financeCategory>PURCHASE_FERTILIZER</financeCategory>
        <vertexBufferMemoryUsage>512</vertexBufferMemoryUsage>
        <indexBufferMemoryUsage>256</indexBufferMemoryUsage>
        <textureMemoryUsage>65536</textureMemoryUsage>
        <instanceVertexBufferMemoryUsage>0</instanceVertexBufferMemoryUsage>
        <instanceIndexBufferMemoryUsage>0</instanceIndexBufferMemoryUsage>
        <storeIconRendering>
            <settings cameraXRot="-15" cameraYRot="25" />
        </storeIconRendering>
        <audioMemoryUsage>0</audioMemoryUsage>
    </storeData>

    <base>
        <typeDesc>$l10n_typeDesc_pallet</typeDesc>
        <filename>$data/objects/multiPurchaseItem/multiPurchaseItem.i3d</filename>
        <size width="2.9" length="6.1" height="1.6" lengthOffset="0.1"/>
        <input allowed="false"/>
        <canBeReset>false</canBeReset>
        <components>
            <component centerOfMass="0 0.1 0" solverIterationCount="10" mass="100" />
        </components>
        <showInVehicleMenu>false</showInVehicleMenu>
        <mapHotspot available="false" />
    </base>

    <fillUnit>
        <fillUnitConfigurations>
            <fillUnitConfiguration>
                <fillUnits>
                    <fillUnit unitTextOverride="$l10n_unit_literShort" fillTypes="%(ft)s" capacity="1000"/>
                </fillUnits>
            </fillUnitConfiguration>
        </fillUnitConfigurations>
    </fillUnit>

    <multipleItemPurchase filename="shop/ibc_%(ft)s.xml" isVehicle="true">
        <offsets>
            <offset amount="2" offset="0.775 0 0"/>
            <offset amount="3" offset="0.775 0 0.8"/>
            <offset amount="5" offset="0.775 0 1.6"/>
            <offset amount="7" offset="0.775 0 2.4"/>
        </offsets>
        <itemPositions>
            <itemPosition position="0 0 0" rotation="0 0 0"/>
            <itemPosition position="-1.55 0 0" rotation="0 0 0"/>
            <itemPosition position="0 0 -1.55" rotation="0 0 0"/>
            <itemPosition position="-1.55 0 -1.55" rotation="0 0 0"/>
            <itemPosition position="0 0 -3.1" rotation="0 0 0"/>
            <itemPosition position="-1.55 0 -3.1" rotation="0 0 0"/>
            <itemPosition position="0 0 -4.65" rotation="0 0 0"/>
            <itemPosition position="-1.55 0 -4.65" rotation="0 0 0"/>
        </itemPositions>
    </multipleItemPurchase>

    <multipleItemPurchaseAmountConfigurations>
%(prices)s
    </multipleItemPurchaseAmountConfigurations>
</vehicle>
""" % dict(ft=ft, icon="shop/store_%s.png" % ft, price=p["price"], prices=prices)


def moddesc_snippet():
    out = ['    <fillTypes filename="xml/fillTypes.xml"/>', "", "    <storeItems>"]
    for p in PRODUCTS:
        kind = "ibc" if p["liquid"] else "bigBag"
        out.append('        <storeItem xmlFilename="shop/%s_%s.xml"/>' % (kind, p["id"]))
        out.append('        <storeItem xmlFilename="shop/multiPurchase_%s_%s.xml"/>' % (kind, p["id"]))
    out.append("    </storeItems>")
    out.append("")
    out.append("    <!-- TR Configurator registers the spray types and hands them to Precision Farming; solids go to spreaders, liquids to sprayers -->")
    out.append("    <thPFConfig>")
    out.append("        <sprayTypes>")
    for p in PRODUCTS:
        base_lps = 0.0081 if p["liquid"] else 0.0060 * 0.8 / p["density"]
        out.append('            <sprayType name="%s" type="FERTILIZER" litersPerSecond="%s" sprayGroundType="FERTILIZER">' % (p["id"], num(base_lps)))
        if p["n"] > 0 and p["regular"] is not None:
            out.append('                <applicationRate autoAdjustToFruit="true" regularRate="%d">' % p["regular"])
            for soil, rate in ((1, 0.4), (2, 0.6), (3, 0.8), (4, 0.6)):
                out.append('                    <soil soilTypeIndex="%d" rate="%d"/>' % (soil, round(p["regular"] * rate)))
            out.append("                </applicationRate>")
            out.append("                <fertilizerUsage>")
            out.append('                    <nitrogen amount="%s"/>' % num(p["n"]))
            out.append("                </fertilizerUsage>")
        out.append('                <mapping group="FERTILIZER" isLiquid="%s"/>' % ("true" if p["liquid"] else "false"))
        out.append("            </sprayType>")
    out.append("        </sprayTypes>")
    out.append("    </thPFConfig>")
    write("xml/products_modDesc.snippet.xml", "\n".join(out) + "\n")


def nutrients_snippets():
    # per 1000 l = density (t per 1000 l) * 1000 kg * fraction
    for key, label in (("p", "P"), ("k", "K"), ("om", "OM")):
        rows = []
        for p in PRODUCTS:
            if key == "om":
                value = p["om"]
            else:
                value = p["density"] * 1000 * p[key]
            if value > 0:
                rows.append('                <fillType name="%s" value="%s"/>' % (p["id"], num(value)))
        write("xml/products_nutrients_%s.snippet.xml" % label, "\n".join(rows) + "\n")


def l10n_snippets():
    for lang, field in (("en", "en"), ("hu", "hu")):
        rows = ["        <!-- products (generated by tools/generate_products.py) -->"]
        for p in PRODUCTS:
            rows.append('        <text name="vtsz_ft_%s" text="%s"/>' % (p["id"], p[field].replace('"', "&quot;")))
        rows.append('        <text name="vtsz_function_bag" text="%s"/>' % ("Big bag of fertilizer for spreaders." if lang == "en" else "Big bag műtrágya műtrágyaszórókhoz."))
        rows.append('        <text name="vtsz_function_ibc" text="%s"/>' % ("1000 l IBC of liquid fertilizer for sprayers." if lang == "en" else "1000 literes IBC folyékony műtrágya permetezőkhöz."))
        write("l10n/products_%s.snippet.xml" % lang, "\n".join(rows) + "\n")


LIST_XML = """<?xml version="1.0" encoding="utf-8" standalone="no" ?>
<motionPathEffects>
    <motionPathEffect filename="xml/fertilizerMotionPath.xml"/>
</motionPathEffects>
"""


def motion_path_xml():
    """Spreader particle effect for the solid products: the base FERTILIZER effect and material, our fill types added."""
    base = os.path.join("C:/Program Files (x86)/Steam/steamapps/common/Farming Simulator 25/data/effects/fertilizer/fertilizerEffects.xml")
    with open(base, encoding="utf-8-sig") as f:
        text = f.read()
    solids = " ".join(p["id"] for p in PRODUCTS if not p["liquid"])
    text = text.replace("../../../shared/xml/schema/mapMotionPathEffects.xsd", "../../shared/xml/schema/mapMotionPathEffects.xsd")
    text = text.replace('<typeDefinition fillTypes="FERTILIZER LIME ROADSALT SEEDS" speedScale="0.65"/>', '<typeDefinition fillTypes="%s" speedScale="0.65"/>' % solids)
    # keep only the FERTILIZER material (node 0|1|0) and give it our fill types
    import re
    text = re.sub(r'\s*<effectMaterial node="0\|1\|[123]" fillTypes="[A-Z]+" />', "", text)
    text = text.replace('<effectMaterial node="0|1|0" fillTypes="FERTILIZER" />', '<effectMaterial node="0|1|0" fillTypes="%s" />' % solids)
    write("xml/fertilizerMotionPath.xml", text)
    write("xml/motionPathEffects.xml", LIST_XML)


def main():
    fill_types_xml()
    for p in PRODUCTS:
        if p["liquid"]:
            write("shop/ibc_%s.xml" % p["id"], ibc_xml(p))
            write("shop/multiPurchase_ibc_%s.xml" % p["id"], ibc_multi_xml(p))
        else:
            write("shop/bigBag_%s.xml" % p["id"], bag_xml(p))
            write("shop/multiPurchase_bigBag_%s.xml" % p["id"], bag_multi_xml(p))
    moddesc_snippet()
    nutrients_snippets()
    l10n_snippets()
    motion_path_xml()
    print("generated %d products" % len(PRODUCTS))


if __name__ == "__main__":
    sys.exit(main())
