-- VtszSelfTest: console driven self test of the P, K, OM maps. Results go to log.txt only.
--
-- Safety rules (this file must never be able to break the mod):
--   * It is loaded with pcall from VtszNutrients.lua and only when the file exists. Without it the mod runs the same.
--   * It installs no hooks and wraps no game function. The only entry points are the console commands below.
--   * Every test case runs inside pcall. An exception becomes a FAIL line, never a Lua error.
--   * The default tests are pure: they read config and call pure functions. They write no map, no savegame, no state.
--   * Only `vtszSelfTest world <fieldId> confirm` writes map data (on one field), and only after the explicit "confirm".
--
-- Output: one line per check, `[VTSZ-NUT][TEST] PASS|FAIL|WARN|SKIP <id> <detail>`, then one SUMMARY line.
-- Read it from log.txt: grep "\[VTSZ-NUT\]\[TEST\]".

VtszSelfTest = {}

local TAG = "[VTSZ-NUT][TEST] "

-- Expected values taken from the design (README / TODO). A mismatch is a WARN: it may be a deliberate rebalance.
local GOLDEN_SPRAY = {
	P = { MANURE = 1.75, LIQUIDMANURE = 1.7, DIGESTATE = 3.0, FERTILIZER = 120, LIQUIDFERTILIZER = 0, CARBOLIME = 18,
		MAP11_52 = 499.2, TSP46 = 506, SSP18 = 189, NPK15_15_15 = 157.5, NPK8_24_24 = 252, ELESZTOVINASZ = 3.78 },
	K = { MANURE = 4.2, LIQUIDMANURE = 5.0, DIGESTATE = 5.0, FERTILIZER = 120, LIQUIDFERTILIZER = 0, CARBOLIME = 1.2,
		KALISO60 = 660, PATENTKALI = 357, NPK15_15_15 = 157.5, NPK8_24_24 = 252, ELESZTOVINASZ = 37.8 },
	OM = { MANURE = 0.0008, LIQUIDMANURE = 0.00034, DIGESTATE = 0.00038, CARBOLIME = 0.00036, ELESZTOVINASZ = 0.0028 },
}

-- OM change per harvest {straw baled and removed, straw chopper}: gain - removal (+ strawGain with the chopper), computed from the VDLUFA
-- model (see the comment in config/NutrientMaps.xml). A mismatch is a FAIL.
local GOLDEN_OM_HARVEST = {
	SILAGEMAIZE = { -0.01167, -0.01167 },
	SUGARCANE = { -0.01167, -0.01167 },
	SORGHUM = { -0.01167, -0.01167 },
	GREENRYE = { -0.01167, -0.01167 },
	VETCHRYE = { -0.01167, -0.01167 },
	POTATO = { -0.02, -0.02 },
	SUGARBEET = { -0.006, -0.006 },
	BEETROOT = { 0, 0 },
	CARROT = { -0.01167, -0.01167 },
	PARSNIP = { -0.01167, -0.01167 },
	RICE = { 0, 0 },
	RICELONGGRAIN = { 0, 0 },
	GREENBEAN = { 0, 0 },
	WHEAT = { -0.01467, 0.01467 },
	WINTERWHEAT = { -0.01467, 0.01467 },
	BARLEY = { -0.01123, 0.01123 },
	WINTERBARLEY = { -0.01123, 0.01123 },
	OAT = { -0.0126, 0.0126 },
	RYE = { -0.01238, 0.01238 },
	TRITICALE = { -0.01341, 0.01341 },
	SPELT = { -0.00917, 0.00917 },
	MAIZE = { 0.01125, 0.01125 },
	CANOLA = { 0.01364, 0.01364 },
	SUNFLOWER = { 0.01604, 0.01604 },
	PEA = { 0.01833, 0.01833 },
	FODDERPEA = { 0.01833, 0.01833 },
	FABABEAN = { 0.01833, 0.01833 },
	SOYBEAN = { 0.01833, 0.01833 },
	GRASS = { 0.00944, 0.00944 },
	FIELDGRASS = { 0.00944, 0.00944 },
	MEADOW = { 0.00944, 0.00944 },
	ALFALFA = { 0.00944, 0.00944 },
	CLOVER = { 0.00944, 0.00944 },
}
local GOLDEN_OM_DESTROY = {
	OILSEEDRADISH = 0.008, MUSTARD = 0.008, FLOWERINGCATCHCROP = 0.007, HUMUSACTIVE = 0.012,
}

----------------------------------------------------------------------------------------------------
-- Result collection
----------------------------------------------------------------------------------------------------

local counts

local function record(status, id, fmt, ...)
	counts[status] = (counts[status] or 0) + 1
	local detail = fmt ~= nil and string.format(fmt, ...) or ""
	Logging.info("%s%s %s %s", TAG, status, id, detail)
end

local function check(id, condition, fmt, ...)
	record(condition and "PASS" or "FAIL", id, fmt, ...)
	return condition
end

local function near(a, b, tolerance)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tolerance or 1e-6)
end

local function isFinite(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function sortedKeys(t)
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	return keys
end

local function fruitName(index)
	local fruitType = g_fruitTypeManager:getFruitTypeByIndex(index)
	return fruitType ~= nil and fruitType.name or tostring(index)
end

local function fillName(index)
	return g_fillTypeManager:getFillTypeNameByIndex(index) or tostring(index)
end

-- P, K and OM are relative maps: the stored level is the distance to the soil type target, so the "on target" content in map units is 0.
-- map.targets[soil] stays the absolute baseline (kg/ha, %) for the pH shift, leaching and mineralisation. For an absolute map
-- (levelOffset 0) the on-target content is the baseline itself. Derived here, not from getTargetUnits, so a wrong getTargetUnits is caught.
local function baselineUnits(map, soilTypeIndex)
	return map.relative and 0 or map.targets[soilTypeIndex]
end

-- pH adjusted target, computed from the definition: the usable share of baseline + surplus must reach the baseline + surplus.
-- Relative maps give the surplus over the baseline, capped one step below the highest reachable content.
local function expectedPhTarget(map, soilTypeIndex, target, efficiency)
	local top = map:levelToUnits(map:getCapLevel())
	if efficiency >= 1 then
		return target
	end
	if map.relative then
		local baseline = map.targets[soilTypeIndex]
		return math.min((baseline + target) / efficiency - baseline, math.max(target, top - map.step))
	end
	return math.min(target / efficiency, math.max(target, top - map.step))
end

-- true when the l10n file of that language defines the text key (the running game only knows the active language)
local function l10nFileHasKey(language, key)
	local xmlFile = loadXMLFile("VtszSelfTestL10n", VtszNutrients.MOD_DIR .. "l10n/l10n_" .. language .. ".xml")
	if xmlFile == nil or xmlFile == 0 then
		return nil
	end
	local found = false
	local i = 0
	while true do
		local base = string.format("l10n.texts.text(%d)", i)
		local name = getXMLString(xmlFile, base .. "#name")
		if name == nil then
			break
		end
		if name == key then
			found = true
			break
		end
		i = i + 1
	end
	delete(xmlFile)
	return found
end

----------------------------------------------------------------------------------------------------
-- Pure test groups
----------------------------------------------------------------------------------------------------

local function testConfig()
	for _, map in ipairs(VtszNutrients.maps) do
		local p = "CONFIG." .. map.nutrientId
		check(p .. ".step", isFinite(map.step) and map.step > 0, "step=%s", tostring(map.step))
		check(p .. ".channels", map.maxValue == 2 ^ map.numChannels - 1, "channels=%d maxValue=%s", map.numChannels, tostring(map.maxValue))
		-- the legend window may be narrower than the map range (better colour resolution), but it must lie inside it and be non-empty
		check(p .. ".legend", map.legendMin >= map:levelToUnits(0) and map.legendMin < map.legendMax and map.legendMax <= map:levelToUnits(map.maxValue) + map.step, "legend %s..%s, map range %s..%s", tostring(map.legendMin), tostring(map.legendMax), tostring(map:levelToUnits(0)), tostring(map:levelToUnits(map.maxValue)))
		check(p .. ".soilTypes", #map.soilTypeIndices >= 1, "soil types with a target: %d", #map.soilTypeIndices)

		for _, soilTypeIndex in ipairs(map.soilTypeIndices) do
			-- targets[] is the absolute soil type baseline (kg/ha, %): it drives the pH shift, leaching and mineralisation, also on relative maps
			local target = map.targets[soilTypeIndex]
			check(p .. ".target" .. soilTypeIndex, isFinite(target) and target > 0 and (map.relative or target / map.step <= map.maxValue), "baseline=%s (%s levels, max %d, relative=%s)", tostring(target), tostring(target / map.step), map.maxValue, tostring(map.relative))
			local levels = map.initialValues[soilTypeIndex]
			local ok = levels ~= nil and #levels > 0
			if ok then
				for _, level in ipairs(levels) do
					-- stored levels (relative maps: the deltas are already converted to levels), never above the soft cap
					if not (isFinite(level) and level >= 0 and level <= map:getCapLevel()) then
						ok = false
					end
				end
			end
			check(p .. ".initial" .. soilTypeIndex, ok, "levels=%s (cap level %d)", levels ~= nil and table.concat(levels, ",") or "missing", map:getCapLevel())
			-- a new map never starts far below the target, not even at the worst start level: OM 0.90, P / K 0.80
			if ok then
				local lowest = math.huge
				for _, level in ipairs(levels) do
					lowest = math.min(lowest, level)
				end
				local startFactor = map:getYieldFactor(map:levelToUnits(lowest), baselineUnits(map, soilTypeIndex))
				local minimum = map.nutrientId == "OM" and 0.90 or 0.80
				check(p .. ".initialFactor" .. soilTypeIndex, startFactor >= minimum, "worst start level %s (%s) gives factor %.3f (>= %.2f)", tostring(lowest), map:formatUnits(map:levelToUnits(lowest)), startFactor, minimum)
			end
		end

		-- relative map: level offset inside the stored range, the legend window around the target, an optional soft cap
		if map.levelOffset > 0 then
			check(p .. ".relative", map.relative == true and map.levelOffset < map.maxValue and near(map:levelToUnits(map.levelOffset), 0, 1e-9) and map:unitsToLevel(0) == map.levelOffset, "levelOffset=%d of max %d: level %d = 0 units, 0 units = level %d", map.levelOffset, map.maxValue, map.levelOffset, map:unitsToLevel(0))
			check(p .. ".legendAroundTarget", map.legendMin < 0 and map.legendMax > 0, "legend %s..%s contains the target 0", tostring(map.legendMin), tostring(map.legendMax))
		elseif map.nutrientId == "P" or map.nutrientId == "K" then
			record("WARN", p .. ".relative", "P and K are relative maps by design (levelOffset > 0), this map is absolute")
		end
		if map.maxUnits ~= nil then
			local cap = map:getCapLevel()
			check(p .. ".cap", cap > map.levelOffset and cap <= map.maxValue and near(map:levelToUnits(cap), map.maxUnits, map.step * 0.5 + 1e-9), "maxUnits=%s -> cap level %d (%s units, stored maximum level %d)", tostring(map.maxUnits), cap, tostring(map:levelToUnits(cap)), map.maxValue)
		end

		local sortedOk, factorsOk = true, true
		for i, key in ipairs(map.yieldKeys) do
			if i > 1 and key.difference <= map.yieldKeys[i - 1].difference then
				sortedOk = false
			end
			if not (isFinite(key.factor) and key.factor > 0 and key.factor <= 1) then
				factorsOk = false
			end
		end
		check(p .. ".yieldKeysSorted", sortedOk, "%d keys", #map.yieldKeys)
		check(p .. ".yieldKeysRange", factorsOk, "factors in (0, 1]")

		-- names in the config that the engine does not know: only a WARN, the map may not have the fruit / fill type
		for _, name in ipairs(sortedKeys(map.fillTypeConfigs)) do
			local index = g_fillTypeManager:getFillTypeIndexByName(name)
			if index == nil or index == FillType.UNKNOWN then
				record("WARN", p .. ".fillType." .. name, "not registered on this map, ignored")
			end
		end
		for _, name in ipairs(sortedKeys(map.fruitRequirementsByName)) do
			if name ~= "DEFAULT" and g_fruitTypeManager:getFruitTypeByName(name) == nil then
				record("WARN", p .. ".fruit." .. name, "not registered on this map, ignored")
			end
		end
	end

	check("CONFIG.scale", isFinite(VtszConfig.inputScale) and VtszConfig.inputScale >= 0 and isFinite(VtszConfig.removalScale) and VtszConfig.removalScale >= 0, "inputScale=%s removalScale=%s", tostring(VtszConfig.inputScale), tostring(VtszConfig.removalScale))
end

local function testSpray()
	for _, map in ipairs(VtszNutrients.maps) do
		local id = map.nutrientId
		local golden = GOLDEN_SPRAY[id] or {}
		for _, fillTypeIndex in ipairs(sortedKeys(map.fillTypeContents)) do
			local name = fillName(fillTypeIndex)
			local p = string.format("SPRAY.%s.%s", id, name)
			local value = map.fillTypeContents[fillTypeIndex].value
			local u1000 = map:getUnitsForFillType(fillTypeIndex, 1000)
			if value > 0 then
				local expected = value * VtszConfig.inputScale * map.timeScale
				check(p .. ".per1000", near(u1000, expected, 1e-6), "units/1000 l=%s expected=%s", tostring(u1000), tostring(expected))
				check(p .. ".linear", near(map:getUnitsForFillType(fillTypeIndex, 2000), 2 * (u1000 or 0), 1e-6) and near(map:getUnitsForFillType(fillTypeIndex, 0), 0, 1e-9), "2x liters = 2x units, 0 liters = 0")
				local levels = (u1000 or 0) / map.step
				check(p .. ".levels", isFinite(levels) and levels >= 0, "%.4f levels per 1000 l/ha", levels)
				-- the HUD helper must agree with the map
				local _, phosphorus, potassium = VtszNutrients:getNutrientsPerHa(fillTypeIndex, 1000)
				if id == "P" then
					check(p .. ".hud", near(phosphorus, value, 1e-6), "HUD P=%s config=%s", tostring(phosphorus), tostring(value))
				elseif id == "K" then
					check(p .. ".hud", near(potassium, value, 1e-6), "HUD K=%s config=%s", tostring(potassium), tostring(value))
				end
			else
				check(p .. ".none", u1000 == nil, "value 0 gives no units")
			end
			-- getXMLFloat is a 32 bit float: compare with a relative tolerance
			if golden[name] ~= nil and not near(value, golden[name], 1e-5 * math.max(1, math.abs(golden[name]))) then
				record("WARN", p .. ".golden", "config=%s design=%s", tostring(value), tostring(golden[name]))
			end
		end
		-- design products missing from the config
		for _, name in ipairs(sortedKeys(golden)) do
			local index = g_fillTypeManager:getFillTypeIndexByName(name)
			if index ~= nil and index ~= FillType.UNKNOWN and map.fillTypeContents[index] == nil and not (name == "FERTILIZER" and not VtszConfig.baseFertilizer) then
				record("WARN", string.format("SPRAY.%s.%s.missing", id, name), "design product has no entry in the config")
			end
		end
	end
end

-- base-game FERTILIZER must follow the <baseFertilizer> switch
local function testBaseFertilizer()
	local index = g_fillTypeManager:getFillTypeIndexByName("FERTILIZER")
	if index == nil or index == FillType.UNKNOWN then
		return
	end
	for _, map in ipairs(VtszNutrients.maps) do
		if map.nutrientId == "P" or map.nutrientId == "K" then
			local present = map.fillTypeContents[index] ~= nil
			check("SPRAY." .. map.nutrientId .. ".FERTILIZER.switch", present == (VtszConfig.baseFertilizer == true), "baseFertilizer=%s, FERTILIZER entry present=%s", tostring(VtszConfig.baseFertilizer), tostring(present))
		end
	end
end

local function testHarvest()
	local inputScale, removalScale = VtszConfig.inputScale, VtszConfig.removalScale
	for _, map in ipairs(VtszNutrients.maps) do
		local id = map.nutrientId
		for _, fruitTypeIndex in ipairs(sortedKeys(map.fruitRequirements)) do
			local requirement = map.fruitRequirements[fruitTypeIndex]
			local name = fruitName(fruitTypeIndex)
			local p = string.format("HARVEST.%s.%s", id, name)
			local gain = requirement.gain or 0
			local timeScale = map.timeScale
				local expectedStraw = (gain * inputScale - (requirement.removal + requirement.removalStraw) * removalScale) * timeScale
			local expectedChopper = ((gain + (requirement.strawGain or map.strawChopperGain)) * inputScale - requirement.removal * removalScale) * timeScale
			local straw = map:getHarvestChange(fruitTypeIndex, false)
			local chopper = map:getHarvestChange(fruitTypeIndex, true)
			check(p .. ".straw", isFinite(straw) and near(straw, expectedStraw, 1e-9), "change=%s expected=%s", tostring(straw), tostring(expectedStraw))
			check(p .. ".chopper", isFinite(chopper) and near(chopper, expectedChopper, 1e-9), "change=%s expected=%s", tostring(chopper), tostring(expectedChopper))
				-- forage harvester header / mower: crop and straw leave, no gain (the chopper flag is ignored); without forageRemoval the straw is taken like a grain harvest
				local forage = map:getHarvestChange(fruitTypeIndex, true, nil, true)
				local expectedForage = expectedStraw
				if requirement.forageRemoval ~= nil then
					expectedForage = -(math.max(requirement.removal, requirement.forageRemoval) + requirement.removalStraw) * removalScale * timeScale
				end
				check(p .. ".forage", isFinite(forage) and near(forage, expectedForage, 1e-9), "change=%s expected=%s", tostring(forage), tostring(expectedForage))
				if requirement.forageRemoval ~= nil then
					check(p .. ".forageLoses", forage <= 0 and forage <= straw + 1e-12, "forage change %s is a loss and not above the grain harvest %s", tostring(forage), tostring(straw))
				end
			-- one harvest may not swing the whole map range
			check(p .. ".bounded", math.abs(straw) <= map.maxValue * map.step and math.abs(chopper) <= map.maxValue * map.step, "|change| <= %s", tostring(map.maxValue * map.step))
		end
		-- fruit types without an entry use DEFAULT
		local default = map.defaultRequirement
		check(string.format("HARVEST.%s.DEFAULT", id), default ~= nil and isFinite(default.removal) and isFinite(default.removalStraw), "removal=%s removalStraw=%s", tostring(default and default.removal), tostring(default and default.removalStraw))
	end

	-- OM spec (README, section "Humuszmérleg (VDLUFA)" / crop OM tables), including the straw chopper
	local om = nil
	for _, map in ipairs(VtszNutrients.maps) do
		if map.nutrientId == "OM" then
			om = map
		end
	end
	if om == nil then
		record("SKIP", "HARVEST.OM.spec", "no OM map")
		return
	end
	-- the spec values are for scale 1; with another scale compare after undoing it
	if inputScale ~= 1 or removalScale ~= 1 then
		record("SKIP", "HARVEST.OM.spec", "balance scale is not 1 (input=%s removal=%s)", tostring(inputScale), tostring(removalScale))
	else
		for _, name in ipairs(sortedKeys(GOLDEN_OM_HARVEST)) do
			local fruitType = g_fruitTypeManager:getFruitTypeByName(name)
			if fruitType == nil then
				record("SKIP", "HARVEST.OM.spec." .. name, "fruit type not on this map")
			else
				local spec = GOLDEN_OM_HARVEST[name]
				local straw = om:getHarvestChange(fruitType.index, false) / om.timeScale
				local chopper = om:getHarvestChange(fruitType.index, true) / om.timeScale
				check("HARVEST.OM.spec." .. name, near(straw, spec[1], 1e-7) and near(chopper, spec[2], 1e-7), "straw=%s (spec %s) chopper=%s (spec %s)", tostring(straw), tostring(spec[1]), tostring(chopper), tostring(spec[2]))
			end
		end
	end

	-- catch crops (OM destroy gain)
	for _, name in ipairs(sortedKeys(GOLDEN_OM_DESTROY)) do
		local fruitType = g_fruitTypeManager:getFruitTypeByName(name)
		if fruitType == nil then
			record("SKIP", "DESTROY.OM." .. name, "fruit type not on this map")
		else
			local gain = om:getDestroyGain(fruitType.index) / om.timeScale
			check("DESTROY.OM." .. name, near(gain, GOLDEN_OM_DESTROY[name], 1e-7), "destroyGain=%s spec=%s", tostring(gain), tostring(GOLDEN_OM_DESTROY[name]))
		end
	end
	-- a crop that is not a catch crop gives nothing
	local wheat = g_fruitTypeManager:getFruitTypeByName("WHEAT")
	if wheat ~= nil then
		check("DESTROY.OM.WHEAT", near(om:getDestroyGain(wheat.index), om.catchCropGain * om.timeScale, 1e-9), "wheat uses the map default %s", tostring(om.catchCropGain))
	end
	-- catch crop list resolves
	local catchCrops = VtszNutrients:getCatchCropFruitTypes()
	check("DESTROY.catchCropList", #catchCrops > 0, "%d catch crop fruit types resolved", #catchCrops)
	-- mulcher hook: wrap installed on the server, mulched state is known per catch crop
	if g_server ~= nil then
		check("DESTROY.OM.mulcherHook", VtszNutrients.mulcherHookOriginal ~= nil and FSDensityMapUtil.updateMulcherArea ~= VtszNutrients.mulcherHookOriginal, "updateMulcherArea is wrapped")
	end
	for _, fruitType in ipairs(catchCrops) do
		local mulched = fruitType.mulchedState or 0
		-- 0 = mulcher removes the crop (plain destroy rule); >0 must be a real growth state, excluded from the destroy mask
		check("DESTROY.OM.mulchedState." .. fruitType.name, mulched >= 0 and mulched <= fruitType.numGrowthStates, "mulchedState=%d numGrowthStates=%d cutState=%s", mulched, fruitType.numGrowthStates, tostring(fruitType.cutState))
		if g_server ~= nil and #VtszNutrients:getGainCatchCrops() > 0 then
			local mask = VtszNutrients:getDestroyMask(fruitType)
			check("DESTROY.OM.mulchMask." .. fruitType.name, mask.notMulchedFilter ~= nil, "mask excludes the mulched state %d", mulched)
		end
	end
end

local testCombine

local function testYield()
	for _, map in ipairs(VtszNutrients.maps) do
		local id = map.nutrientId
		for _, soilTypeIndex in ipairs(map.soilTypeIndices) do
			local p = string.format("YIELD.%s.soil%d", id, soilTypeIndex)
			-- target of the yield factor without crop and pH: 0 on a relative map (the map is already the distance), the baseline otherwise
			local target = map:getTargetUnits(soilTypeIndex, nil)
			if target == nil then
				record("FAIL", p, "no target")
			else
				check(p .. ".baseline", near(target, baselineUnits(map, soilTypeIndex), 1e-9), "getTargetUnits(soil, nil) = %s expected %s", tostring(target), tostring(baselineUnits(map, soilTypeIndex)))
				check(p .. ".atTarget", near(map:getYieldFactor(target, target), 1, 1e-9), "factor at target = %s", tostring(map:getYieldFactor(target, target)))
				local previous, monotonic, bounded = 0, true, true
				local samples = 200
				for i = 0, samples do
					local lowest = map:levelToUnits(0)
					local actual = lowest + (map.legendMax - lowest) * i / samples
					local factor = map:getYieldFactor(actual, target)
					if not (isFinite(factor) and factor > 0 and factor <= 1) then
						bounded = false
					end
					-- below the target the factor never falls when the level rises
					if actual <= target then
						if factor < previous - 1e-9 then
							monotonic = false
						end
						previous = factor
					end
				end
				check(p .. ".bounded", bounded, "factor in (0, 1] over %s..%s", tostring(map:levelToUnits(0)), tostring(map.legendMax))
				check(p .. ".monotonic", monotonic, "never falls while the level rises up to the target")
				local keysOk = true
				for _, key in ipairs(map.yieldKeys) do
					if not near(map:getYieldFactor(target + key.difference, target), key.factor, 1e-9) then
						keysOk = false
					end
				end
				check(p .. ".keys", keysOk, "factor at every configured key equals its yieldFactor")
			end
		end
	end
	testCombine()
end

function testCombine()
	local combine = VtszNutrients.combineFactors
	check("YIELD.combine.minimum", near(combine({ P = 0.95, K = 0.95, OM = 0.97 }), 0.95 * 0.97, 1e-9), "P 0.95 K 0.95 OM 0.97 -> %s", tostring(combine({ P = 0.95, K = 0.95, OM = 0.97 })))
	check("YIELD.combine.worst", near(combine({ P = 0.5, K = 0.5, OM = 0.8 }), 0.4, 1e-9), "P 0.5 K 0.5 OM 0.8 -> %s", tostring(combine({ P = 0.5, K = 0.5, OM = 0.8 })))
	check("YIELD.combine.single", near(combine({ K = 0.7 }), 0.7, 1e-9), "K only")
	check("YIELD.combine.empty", near(combine({}), 1, 1e-9), "no factors -> 1")
	check("YIELD.combine.capped", near(combine({ P = 1.4, K = 1.2, OM = 1.1 }), 1, 1e-9), "factors above 1 are capped")
end

local function testRounding()
	local split = NutrientMap.splitLevels
	if split == nil then
		record("SKIP", "ROUNDING", "NutrientMap.splitLevels not exported")
		return
	end
	local samples = 20000
	for _, levels in ipairs({ 0.045, 0.37, 0.99, 2.6, 5.01 }) do
		local sum, valid = 0, true
		for _ = 1, samples do
			local whole, bands = split(levels)
			if whole < 0 or bands < 0 or bands > 3 or whole ~= math.floor(whole) or bands ~= math.floor(bands) then
				valid = false
			end
			sum = sum + whole + bands / 4
		end
		local mean = sum / samples
		check("ROUNDING." .. levels, valid and near(mean, levels, 0.01), "mean levels over %d samples = %.4f expected %s", samples, mean, tostring(levels))
	end
end

local function testYieldScale()
	local quantise = VtszNutrients.quantiseYieldScale
	local reference = VtszConfig.yieldReference
	check("YSCALE.reference", reference > 0, "yieldReference=%s", tostring(reference))
	check("YSCALE.typical", near(quantise(reference), 1, 1e-9), "multiplier = reference -> %s", tostring(quantise(reference)))
	check("YSCALE.min", near(quantise(0.01), VtszNutrients.YIELD_SCALE_MIN, 1e-9), "tiny multiplier -> %s", tostring(quantise(0.01)))
	check("YSCALE.max", near(quantise(100), VtszNutrients.YIELD_SCALE_MAX, 1e-9), "huge multiplier -> %s", tostring(quantise(100)))
	check("YSCALE.nil", near(quantise(nil), 1, 1e-9), "nil multiplier -> 1")
	check("YSCALE.step", near(quantise(reference * 1.07), 1.1, 1e-9), "1.07 -> %s (step %s)", tostring(quantise(reference * 1.07)), tostring(NutrientMap.YIELD_SCALE_STEP))
	for _, map in ipairs(VtszNutrients.maps) do
		local p = "YSCALE." .. map.nutrientId
		check(p .. ".weight", map.yieldScaling >= 0 and map.yieldScaling <= 1, "yieldScaling=%s", tostring(map.yieldScaling))
		local checked = 0
		for _, fruitTypeIndex in ipairs(sortedKeys(map.fruitRequirements)) do
			local base = map:getHarvestChange(fruitTypeIndex, false)
			if base ~= 0 then
				local half = map:getHarvestChange(fruitTypeIndex, false, 0.5)
				local double = map:getHarvestChange(fruitTypeIndex, false, 1.5)
				local factorHalf = 1 + (0.5 - 1) * map.yieldScaling
				local factorHigh = 1 + (1.5 - 1) * map.yieldScaling
				if not (near(half, base * factorHalf, 1e-9) and near(double, base * factorHigh, 1e-9) and near(map:getHarvestChange(fruitTypeIndex, false, 1), base, 1e-9)) then
					check(p .. ".change." .. fruitName(fruitTypeIndex), false, "base=%s half=%s high=%s", tostring(base), tostring(half), tostring(double))
				end
				checked = checked + 1
			end
		end
		check(p .. ".change", checked > 0, "%d fruit types scale with the yield as configured", checked)
	end
end

local function testPh()
	local configured = 0
	for _, map in ipairs(VtszNutrients.maps) do
		local keys = map.phEfficiencyKeys
		local p = "PH." .. map.nutrientId
		if #keys == 0 then
			check(p .. ".none", near(map:getPhEfficiency(4.0), 1, 1e-9) and near(map:getPhEfficiency(nil), 1, 1e-9), "no keys -> efficiency 1")
		else
			configured = configured + 1
			local inRange, sorted, optimum = true, true, false
			for i, key in ipairs(keys) do
				if key.value < 0.3 or key.value > 1 then
					inRange = false
				end
				if i > 1 and key.ph <= keys[i - 1].ph then
					sorted = false
				end
				if key.value >= 1 then
					optimum = true
				end
			end
			check(p .. ".keys", inRange and sorted and optimum, "%d keys: values 0.3..1, pH strictly rising, an optimum with 1.0", #keys)
			for _, key in ipairs(keys) do
				check(p .. ".at" .. key.ph, near(map:getPhEfficiency(key.ph), key.value, 1e-9), "efficiency at key pH %s = %s", tostring(key.ph), tostring(map:getPhEfficiency(key.ph)))
			end
			local bounded = true
			for ph = 3, 10, 0.05 do
				local e = map:getPhEfficiency(ph)
				if not (isFinite(e) and e >= 0.3 and e <= 1) then
					bounded = false
				end
			end
			check(p .. ".bounded", bounded, "efficiency in 0.3..1 over pH 3..10")
			check(p .. ".unknown", near(map:getPhEfficiency(nil), 1, 1e-9) and near(map:getPhEfficiency(0), 1, 1e-9), "unknown pH -> 1")
			local first, last = keys[1], keys[#keys]
			check(p .. ".ends", near(map:getPhEfficiency(first.ph - 1), first.value, 1e-9) and near(map:getPhEfficiency(last.ph + 1), last.value, 1e-9), "values beyond the first and last key hold")
			-- off-optimum pH needs a larger stock: same actual level gives a lower factor
			-- (relative map: the stock on the soil target is 0 and the adjusted target is a positive surplus over it)
			local soilTypeIndex = map.soilTypeIndices[1]
			local target = map:getTargetUnits(soilTypeIndex, nil)
			local worst = math.huge
			for _, key in ipairs(keys) do
				worst = math.min(worst, key.value)
			end
			local adjusted = map:getPhAdjustedTarget(target, worst, soilTypeIndex)
			check(p .. ".yield", adjusted >= target - 1e-9 and map:getYieldFactor(target, adjusted) <= map:getYieldFactor(target, target) + 1e-9, "on bad pH the target %s is not below %s and the factor at the unadjusted target stock is not higher", tostring(adjusted), tostring(target))
			if worst < 1 and map.relative then
				check(p .. ".yieldStrict", adjusted > target and map:getYieldFactor(target, adjusted) < 1, "pH efficiency %s: target %s above the soil target %s, factor %.3f", tostring(worst), tostring(adjusted), tostring(target), map:getYieldFactor(target, adjusted))
			end
		end
	end
	-- the adjusted target must stay reachable: the cap is the highest reachable content (soft cap maxUnits, else the stored maximum) minus one step.
	-- Relative maps: the target is the surplus over the soil type baseline, the pH share applies to baseline + surplus (loam P 600 / 0.70 - 600 = +257).
	for _, map in ipairs(VtszNutrients.maps) do
		if #map.phEfficiencyKeys > 0 then
			local p = "PH." .. map.nutrientId
			local topUnits = map:levelToUnits(map:getCapLevel())
			local reachable, matches = true, true
			for _, soilTypeIndex in ipairs(map.soilTypeIndices) do
				local targets = { map:getTargetUnits(soilTypeIndex, nil) }
				for _, fruitTypeIndex in ipairs(sortedKeys(map.fruitRequirements)) do
					table.insert(targets, map:getTargetUnits(soilTypeIndex, fruitTypeIndex))
				end
				for _, target in ipairs(targets) do
					for ph = 3, 10, 0.1 do
						local efficiency = map:getPhEfficiency(ph)
						local adjusted = map:getPhAdjustedTarget(target, efficiency, soilTypeIndex)
						if adjusted > math.max(target, topUnits - map.step) + 1e-9 or not near(map:getYieldFactor(topUnits, adjusted), 1, 1e-9) then
							reachable = false
						end
						if not near(adjusted, expectedPhTarget(map, soilTypeIndex, target, efficiency), 1e-6) then
							matches = false
						end
					end
				end
			end
			check(p .. ".reachable", reachable, "adjusted target <= highest reachable content %s - 1 step and factor 1 there, all soils and crops, pH 3..10", tostring(topUnits))
			check(p .. ".definition", matches, "adjusted target = (baseline + surplus) / efficiency - baseline, capped; all soils and crops, pH 3..10")
			local loam = map.targets[3]
			if map.nutrientId == "P" and loam ~= nil then
				local efficiency = map:getPhEfficiency(5.0)
				local adjusted = map:getPhAdjustedTarget(map:getTargetUnits(3, nil), efficiency, 3)
				local expected = math.min(map.relative and (loam / efficiency - loam) or (loam / efficiency), math.max(0, topUnits - map.step))
				check(p .. ".loam5", near(adjusted, expected, 1e-9) and near(map:getYieldFactor(topUnits, adjusted), 1, 1e-9), "loam, pH 5.0: target %s expected %s (baseline %s, efficiency %s), factor 1 at the highest reachable content %s", tostring(adjusted), tostring(expected), tostring(loam), tostring(efficiency), tostring(topUnits))
				if map.relative then
					check(p .. ".loam5uncapped", near(adjusted, loam / efficiency - loam, 1e-9), "the cap %s leaves room for loam at pH 5.0: +%s", tostring(topUnits - map.step), tostring(loam / efficiency - loam))
				end
			end
			-- the soft cap leaves room for the worst pH efficiency on every soil, so no soil is stuck below factor 1 (P maxUnits stays above +260)
			if map.relative and map.maxUnits ~= nil then
				local worst = 1
				for _, key in ipairs(map.phEfficiencyKeys) do
					worst = math.min(worst, key.value)
				end
				local room = true
				for _, soilTypeIndex in ipairs(map.soilTypeIndices) do
					local baseline = map.targets[soilTypeIndex]
					if baseline / worst - baseline > topUnits - map.step + 1e-9 then
						room = false
					end
				end
				check(p .. ".capRoom", room, "cap %s leaves room for the worst pH efficiency %s on every soil type", tostring(map.maxUnits), tostring(worst))
			end
			-- the soil type is a required input of the relative adjustment: different baselines give different surplus targets
			if map.relative and #map.soilTypeIndices >= 2 then
				local firstSoil, lastSoil = map.soilTypeIndices[1], map.soilTypeIndices[#map.soilTypeIndices]
				local first = map:getPhAdjustedTarget(0, 0.8, firstSoil)
				local second = map:getPhAdjustedTarget(0, 0.8, lastSoil)
				check(p .. ".soilDependent", not near(first, second, 1e-9), "surplus target at efficiency 0.8: soil %d %s, soil %d %s", firstSoil, tostring(first), lastSoil, tostring(second))
			end
		end
	end
	check("PH.configured", configured >= 1, "%d map(s) with a pH efficiency", configured)
end

local function testAuto()
	local pick = VtszNutrients.pickBase
	check("AUTO.pick.15-15-20", pick(15, 15, 20) == "K", "15-15-20 -> %s", tostring(pick(15, 15, 20)))
	check("AUTO.pick.15-15-15", pick(15, 15, 15) == "N", "tie -> N (PF as before): %s", tostring(pick(15, 15, 15)))
	check("AUTO.pick.0-46-0", pick(0, 46, 0) == "P", "0-46-0 -> %s", tostring(pick(0, 46, 0)))
	check("AUTO.pick.11-52-0", pick(11, 52, 0) == "P", "11-52-0 -> %s", tostring(pick(11, 52, 0)))
	check("AUTO.pick.8-24-24", pick(8, 24, 24) == "P", "8-24-24 -> %s (tie P/K keeps P)", tostring(pick(8, 24, 24)))
	check("AUTO.pick.none", pick(0, 0, 0) == nil, "no nutrient -> nil")
	check("AUTO.pick.floatTie", pick(157.49998, 157.5, 157.5) == "N", "float32 rounding is a tie -> %s", tostring(pick(157.49998, 157.5, 157.5)))
	check("AUTO.pick.close", pick(100, 102, 0) == "P", "2 %% apart is a real difference -> %s", tostring(pick(100, 102, 0)))
	for _, expected in ipairs({ { "KALISO60", "K" }, { "PATENTKALI", "K" }, { "TSP46", "P" }, { "SSP18", "P" }, { "MAP11_52", "P" }, { "NPK15_15_15", "N" }, { "PETISO27", "N" }, { "MANURE", "N" }, { "LIQUIDMANURE", "N" }, { "DIGESTATE", "N" } }) do
		local index = g_fillTypeManager:getFillTypeIndexByName(expected[1])
		if index == nil or index == FillType.UNKNOWN then
			record("SKIP", "AUTO.default." .. expected[1], "fill type not registered")
		else
			local base = VtszNutrients:getDefaultAutoBase(index)
			check("AUTO.default." .. expected[1], base == expected[2], "default base %s expected %s", tostring(base), expected[2])
		end
	end
	local kali = g_fillTypeManager:getFillTypeIndexByName("KALISO60")
	if kali ~= nil and kali ~= FillType.UNKNOWN then
		local bases = VtszNutrients:getAutoBases(kali)
		check("AUTO.bases.KALISO60", #bases == 1 and bases[1] == "K", "bases: %s", table.concat(bases, ","))
	end
	if VtszSprayerAutoEvent ~= nil then
		local roundTrip = true
		for _, id in ipairs({ "N", "P", "K" }) do
			roundTrip = roundTrip and VtszSprayerAutoEvent.indexToBase(VtszSprayerAutoEvent.baseToIndex(id)) == id
		end
		check("AUTO.event.index", roundTrip and VtszSprayerAutoEvent.baseToIndex(nil) == 0 and VtszSprayerAutoEvent.indexToBase(0) == nil, "base <-> wire index")
	end
	-- nitrogen cap: the N need is liters >= 0 or nil (no N target), never negative
	local npk = g_fillTypeManager:getFillTypeIndexByName("NPK15_15_15")
	if npk ~= nil and npk ~= FillType.UNKNOWN and g_localPlayer ~= nil and g_localPlayer.getCurrentPosition ~= nil then
		local px, _, pz = g_localPlayer:getCurrentPosition()
		local need = VtszNutrients:getNitrogenNeedLiters(npk, px, pz, nil)
		check("AUTO.nitrogenCap.need", need == nil or need >= 0, "N need liters %s", tostring(need))
	else
		record("SKIP", "AUTO.nitrogenCap.need", "no fill type or player position")
	end
	check("AUTO.config", VtszConfig.autoRate.maxLitersPerHa > 0, "max=%s", tostring(VtszConfig.autoRate.maxLitersPerHa))
	for _, map in ipairs(VtszNutrients.maps) do
		if map.nutrientId == "P" or map.nutrientId == "K" then
			local p = "AUTO.units." .. map.nutrientId
			local soilTypeIndex = map.soilTypeIndices[1]
			-- "actual" on the soil type target: 0 on a relative map (the stored value is the distance), the baseline on an absolute one
			local onTarget = baselineUnits(map, soilTypeIndex)
			check(p .. ".atTarget", near(map:getAutoRateUnits(onTarget, soilTypeIndex, nil, nil), 0, 1e-9), "at target (actual %s): dose 0, got %s", tostring(onTarget), tostring(map:getAutoRateUnits(onTarget, soilTypeIndex, nil, nil)))
			-- a deficit is a negative distance on a relative map: actual = -deficit. The dose is exactly the gap, no removal, no build-up.
			local gap = 120
			check(p .. ".gap", near(map:getAutoRateUnits(onTarget - gap, soilTypeIndex, nil, nil), gap, 1e-9), "gap %s: dose = gap, got %s", tostring(gap), tostring(map:getAutoRateUnits(onTarget - gap, soilTypeIndex, nil, nil)))
			check(p .. ".above", near(map:getAutoRateUnits(onTarget + 100, soilTypeIndex, nil, nil), 0, 1e-9), "above target -> 0")
			check(p .. ".nonNegative", map:getAutoRateUnits(map.legendMax * 10, soilTypeIndex, nil, nil) >= 0, "never negative")
			-- pH does not change the dose (low pH is a liming problem); only the yield factor and the field info warning know it
			check(p .. ".phIgnored", near(map:getAutoRateUnits(onTarget, soilTypeIndex, nil, 5.0), 0, 1e-9), "at target the dose is 0 at any pH")
		end
	end
	-- crop dependent target: on an absolute map baseline + targetRemovalShare x removal, on a relative map the surplus over the baseline;
	-- share 0 = crop independent; auto dose = the gap to the crop target
	local wheat = g_fruitTypeManager:getFruitTypeByName("WHEAT")
	local beet = g_fruitTypeManager:getFruitTypeByName("SUGARBEET")
	if wheat == nil or beet == nil then
		record("SKIP", "TARGET.crop", "WHEAT / SUGARBEET not on this map")
		return
	end
	for _, map in ipairs(VtszNutrients.maps) do
		local p = "TARGET." .. map.nutrientId
		local soilTypeIndex = map.soilTypeIndices[1]
		local soilTarget = map.targets[soilTypeIndex] -- absolute baseline
		local baseline = map:getTargetUnits(soilTypeIndex, nil) -- 0 on a relative map
		local wheatTarget = map:getTargetUnits(soilTypeIndex, wheat.index)
		local beetTarget = map:getTargetUnits(soilTypeIndex, beet.index)
		for _, fruit in ipairs({ wheat, beet }) do
			local requirement = map:getRequirement(fruit.index)
			local share = requirement.targetRemovalShare or map.targetRemovalShare
			local scale = requirement.targetScale or 1
			local extra = share * requirement.removal * VtszConfig.removalScale
			local expected = map.relative and (soilTarget * (scale - 1) + extra) or (soilTarget * scale + extra)
			check(p .. "." .. fruit.name, near(map:getTargetUnits(soilTypeIndex, fruit.index), expected, 1e-9), "target %s expected %s (%s)", tostring(map:getTargetUnits(soilTypeIndex, fruit.index)), tostring(expected), map.relative and "surplus over the baseline" or "absolute")
		end
		if map.targetRemovalShare <= 0 then
			check(p .. ".independent", near(wheatTarget, baseline, 1e-9) and near(beetTarget, baseline, 1e-9), "share 0: target = baseline %s", tostring(baseline))
		elseif map.nutrientId == "K" then
			check(p .. ".order", beetTarget > wheatTarget and wheatTarget >= baseline, "baseline %s <= wheat %s < sugar beet %s", tostring(baseline), tostring(wheatTarget), tostring(beetTarget))
		end
		if map.nutrientId == "P" or map.nutrientId == "K" then
			check(p .. ".cropTarget", near(map:getAutoRateUnits(beetTarget, soilTypeIndex, beet.index, nil), 0, 1e-9), "at the crop target the dose is 0")
			check(p .. ".cropGap", near(map:getAutoRateUnits(beetTarget - 50, soilTypeIndex, beet.index, nil), 50, 1e-9), "50 below the crop target the dose is 50")
		end
	end
end

local function testMineral()
	local split = NutrientMap.splitLevels
	local configured = 0
	for _, map in ipairs(VtszNutrients.maps) do
		if map.mineralisationRate > 0 then
			configured = configured + 1
			local p = "MINERAL." .. map.nutrientId
			local weights = map.mineralisationWeights
			local sum = 0
			for _, weight in ipairs(weights) do
				sum = sum + weight
			end
			check(p .. ".weights", #weights == 12 and near(sum, 1, 1e-6), "%d weights, sum %.6f", #weights, sum)
			for _, soilTypeIndex in ipairs(map.soilTypeIndices) do
				local yearly = 0
				for period = 1, 12 do
					yearly = yearly + map:getMineralisationUnits(soilTypeIndex, period)
				end
				local expected = map.mineralisationRate * map.targets[soilTypeIndex] * VtszConfig.removalScale * map.timeScale
				check(p .. ".yearly.soil" .. soilTypeIndex, near(yearly, expected, expected * 1e-6 + 1e-9), "12 periods lose %.5f, expected rate x target = %.5f", yearly, expected)
			end
			-- random rounding keeps the field average: one year of period steps, averaged over many fields
			if split ~= nil and map.soilTypeIndices[1] ~= nil then
				local soilTypeIndex = map.soilTypeIndices[#map.soilTypeIndices]
				local trials, total = 4000, 0
				for _ = 1, trials do
					for period = 1, 12 do
						local whole, bands = split(map:getMineralisationUnits(soilTypeIndex, period) / map.step)
						total = total + whole + bands / 4
					end
				end
				local mean = total / trials * map.step
				local expected = map.mineralisationRate * map.targets[soilTypeIndex] * VtszConfig.removalScale * map.timeScale
				check(p .. ".rounding", near(mean, expected, expected * 0.03), "mean yearly loss %.5f expected %.5f (3%%)", mean, expected)
			end
			check(p .. ".period", map:getMineralisationUnits(map.soilTypeIndices[1], 13) == 0, "period outside 1..12 loses nothing")
			-- nitrogen released into PF's N map
			if map.nitrogenPerPercent > 0 then
				local nitrogenMap = VtszNutrients.pf.nitrogenMap
				check(p .. ".nMap", nitrogenMap ~= nil and nitrogenMap.amountPerState ~= nil and nitrogenMap.amountPerState > 0 and nitrogenMap.maxVisibleValue ~= nil, "PF N map has amountPerState %s and maxVisibleValue %s", tostring(nitrogenMap and nitrogenMap.amountPerState), tostring(nitrogenMap and nitrogenMap.maxVisibleValue))
				check(p .. ".nSize", nitrogenMap == nil or (nitrogenMap.sizeX == map.sizeX and nitrogenMap.sizeY == map.sizeY), "N map %sx%s, OM map %sx%s", tostring(nitrogenMap and nitrogenMap.sizeX), tostring(nitrogenMap and nitrogenMap.sizeY), tostring(map.sizeX), tostring(map.sizeY))
				for _, soilTypeIndex in ipairs(map.soilTypeIndices) do
					local yearly = 0
					for period = 1, 12 do
						yearly = yearly + map:getNitrogenReleaseKg(soilTypeIndex, period)
					end
					local expectedN = map.nitrogenPerPercent * map.targets[soilTypeIndex] * VtszConfig.removalScale
					check(p .. ".nYearly.soil" .. soilTypeIndex, near(yearly, expectedN, expectedN * 1e-6 + 1e-9), "12 periods release %.3f kg N, expected %.3f", yearly, expectedN)
				end
				check(p .. ".nPeriod", map:getNitrogenReleaseKg(map.soilTypeIndices[1], 0) == 0, "period outside 1..12 releases nothing")
				-- removalScale scales the release: 0 = none, other values proportional (config restored afterwards)
				local savedScale = VtszConfig.removalScale
				local soil1 = map.soilTypeIndices[1]
				VtszConfig.removalScale = 1
				local base = map:getNitrogenReleaseKg(soil1, 6)
				VtszConfig.removalScale = 0
				local zero = map:getNitrogenReleaseKg(soil1, 6)
				VtszConfig.removalScale = 2
				local double = map:getNitrogenReleaseKg(soil1, 6)
				VtszConfig.removalScale = savedScale
				check(p .. ".nRemovalScale", base > 0 and zero == 0 and near(double, 2 * base, base * 1e-6), "removalScale 0 -> %.4f, 1 -> %.4f, 2 -> %.4f kg N", zero, base, double)
			end
		end
	end
	check("MINERAL.configured", configured >= 1, "%d map(s) with a mineralisation rate", configured)

	-- leaching (K): yearly sum equals the configured rate, random rounding keeps the average, bad period loses nothing
	for _, map in ipairs(VtszNutrients.maps) do
		if next(map.leachingRates) ~= nil then
			local p = "LEACH." .. map.nutrientId
			local sum = 0
			for _, weight in ipairs(map.leachingWeights) do
				sum = sum + weight
			end
			check(p .. ".weights", #map.leachingWeights == 12 and near(sum, 1, 1e-6), "%d weights, sum %.6f", #map.leachingWeights, sum)
			for soilTypeIndex, rate in pairs(map.leachingRates) do
				local yearly = 0
				for period = 1, 12 do
					yearly = yearly + map:getLeachingUnits(soilTypeIndex, period)
				end
				local expected = rate * VtszConfig.removalScale
				check(p .. ".yearly.soil" .. soilTypeIndex, near(yearly, expected, expected * 1e-6 + 1e-9), "12 periods lose %.4f, expected %.4f", yearly, expected)
				if split ~= nil and expected > 0 then
					local trials, total = 4000, 0
					for _ = 1, trials do
						for period = 1, 12 do
							local whole, bands = split(map:getLeachingUnits(soilTypeIndex, period) / map.step)
							total = total + whole + bands / 4
						end
					end
					local mean = total / trials * map.step
					check(p .. ".rounding.soil" .. soilTypeIndex, near(mean, expected, expected * 0.05), "mean yearly loss %.4f expected %.4f (5%%)", mean, expected)
				end
			end
			check(p .. ".period", map:getLeachingUnits(next(map.leachingRates), 13) == 0, "period outside 1..12 loses nothing")
			-- only content at or above the soil type target leaches: absolute map = level at the baseline, relative map = level >= levelOffset
			-- (applyLeaching filters level > levelOffset - 1). The map pass of applyLeaching is not part of the pure tests (manual: TESTS.md)
			if map.relative then
				check(p .. ".threshold", map.levelOffset >= 1 and map:levelToUnits(map.levelOffset - 1) < 0 and near(map:levelToUnits(map.levelOffset), 0, 1e-9), "leaching starts at level %d (units %s), the level below is a deficit (units %s)", map.levelOffset, tostring(map:levelToUnits(map.levelOffset)), tostring(map:levelToUnits(map.levelOffset - 1)))
			end
		end
	end
end

local function testRates()
	for _, name in ipairs(sortedKeys(VtszConfig.rates)) do
		local rate = VtszConfig.rates[name]
		local p = "RATE." .. name
		check(p .. ".range", rate.min > 0 and rate.min < rate.max and rate.default >= rate.min and rate.default <= rate.max and rate.step > 0, "default=%d step=%d min=%d max=%d", rate.default, rate.step, rate.min, rate.max)
		local index = g_fillTypeManager:getFillTypeIndexByName(name)
		if index == nil or index == FillType.UNKNOWN then
			record("WARN", p .. ".fillType", "fill type not registered")
		else
			local controlled = VtszNutrients:isRateControlled(index)
			local config = VtszNutrients:getRateConfig(index)
			check(p .. ".controlled", controlled == true and config == rate, "isRateControlled=%s (products without N must be true)", tostring(controlled))
		end
	end
end

-- Relative maps (P, K, OM): the stored level is the distance to the soil type target, P has a soft cap (maxUnits).
-- Pure checks of the level <-> units conversion, the cap, the crop targets and the absolute helper.
local function testRelative()
	local beet = g_fruitTypeManager:getFruitTypeByName("SUGARBEET")
	local removalScale = VtszConfig.removalScale
	local relativeMaps = 0
	for _, map in ipairs(VtszNutrients.maps) do
		local p = "REL." .. map.nutrientId
		local cap = map:getCapLevel()
		local highest = map:levelToUnits(map.maxValue)

		-- soft cap: unitsToLevel clamps at the cap level (without maxUnits the cap is the stored maximum), and at 0 below
		if map.maxUnits ~= nil then
			check(p .. ".capLevel", cap == math.min(math.floor(map.maxUnits / map.step + 0.5) + map.levelOffset, map.maxValue) and cap > map.levelOffset and cap <= map.maxValue, "maxUnits=%s -> cap level %d (levelOffset %d, stored maximum %d)", tostring(map.maxUnits), cap, map.levelOffset, map.maxValue)
			check(p .. ".capUnits", near(map:levelToUnits(cap), map.maxUnits, map.step * 0.5 + 1e-9), "cap level %d = %s units, maxUnits %s", cap, tostring(map:levelToUnits(cap)), tostring(map.maxUnits))
		else
			check(p .. ".capLevel", cap == map.maxValue, "no maxUnits: cap level %d = stored maximum %d", cap, map.maxValue)
		end
		check(p .. ".clampHigh", map:unitsToLevel(highest + 1000 * map.step) == cap and map:unitsToLevel(highest) == cap and map:unitsToLevel(map:levelToUnits(cap) + map.step) == cap, "units above the cap (%s) give level %d", tostring(map:levelToUnits(cap)), cap)
		check(p .. ".clampLow", map:unitsToLevel(map:levelToUnits(0) - 1000 * map.step) == 0, "units below the stored minimum give level 0")
		check(p .. ".belowCap", cap < 1 or map:unitsToLevel(map:levelToUnits(cap) - map.step) == cap - 1, "one step below the cap gives level %d", cap - 1)
		if map.nutrientId == "P" then
			-- design: loam at pH 5.0 needs +257, so the P cap must stay above +260
			if map.maxUnits == nil or map.maxUnits < 260 then
				record("WARN", p .. ".maxUnits", "design: P maxUnits is set and at least 260 (loam pH 5.0 needs +257), config has %s", tostring(map.maxUnits))
			else
				record("PASS", p .. ".maxUnits", "P soft cap %s kg/ha >= 260", tostring(map.maxUnits))
			end
		end

		if map.relative then
			relativeMaps = relativeMaps + 1
			local roundTrip = true
			for _, level in ipairs({ 0, map.levelOffset - 1, map.levelOffset, map.levelOffset + 1, cap }) do
				if map:unitsToLevel(map:levelToUnits(level)) ~= level then
					roundTrip = false
				end
			end
			check(p .. ".roundTrip", roundTrip, "unitsToLevel(levelToUnits(level)) = level at 0, offset -1/0/+1 and the cap")

			-- baseline: getTargetUnits(soil, nil) = 0, the absolute helper = the soil type baseline (+ the crop surplus with a crop)
			local baselineOk, absoluteOk, cropOk = true, true, true
			for _, soilTypeIndex in ipairs(map.soilTypeIndices) do
				local baseline = map.targets[soilTypeIndex]
				if not near(map:getTargetUnits(soilTypeIndex, nil), 0, 1e-9) then
					baselineOk = false
				end
				if not near(map:getAbsoluteTargetUnits(soilTypeIndex, nil), baseline, 1e-9) then
					absoluteOk = false
				end
				for _, fruitTypeIndex in ipairs(sortedKeys(map.fruitRequirements)) do
					local requirement = map.fruitRequirements[fruitTypeIndex]
					local share = requirement.targetRemovalShare or map.targetRemovalShare
					local surplus = baseline * ((requirement.targetScale or 1) - 1) + share * requirement.removal * removalScale
					if not near(map:getTargetUnits(soilTypeIndex, fruitTypeIndex), surplus, 1e-9) then
						cropOk = false
					end
					if not near(map:getAbsoluteTargetUnits(soilTypeIndex, fruitTypeIndex), baseline + surplus, 1e-9) then
						absoluteOk = false
					end
				end
			end
			check(p .. ".baseline", baselineOk, "getTargetUnits(soil, nil) is 0 on every soil type")
			check(p .. ".cropSurplus", cropOk, "crop target = baseline x (targetScale - 1) + share x removal x removalScale, every crop and soil type")
			check(p .. ".absoluteHelper", absoluteOk, "getAbsoluteTargetUnits = soil type baseline (+ crop surplus), every crop and soil type")
		end
	end
	check("REL.configured", relativeMaps >= 1, "%d relative map(s)", relativeMaps)

	-- potassium: no crop extra by default, the sugar beet target is the soil type target (0 on a relative map) on every soil type
	local kMap = nil
	for _, map in ipairs(VtszNutrients.maps) do
		if map.nutrientId == "K" then
			kMap = map
		end
	end
	if kMap == nil or not kMap.relative or beet == nil then
		record("SKIP", "REL.K.sugarBeet", "no relative K map or no SUGARBEET on this map")
		return
	end
	local requirement = kMap:getRequirement(beet.index)
	local share = requirement.targetRemovalShare or kMap.targetRemovalShare
	local expected = share * requirement.removal * removalScale
	local soilIndependent = (requirement.targetScale or 1) == 1
	for _, soilTypeIndex in ipairs(kMap.soilTypeIndices) do
		if not near(kMap:getTargetUnits(soilTypeIndex, beet.index), expected, 1e-9) then
			soilIndependent = false
		end
	end
	check("REL.K.sugarBeet", soilIndependent, "sugar beet K target = %s x %s x %s = %s on every soil type", tostring(share), tostring(requirement.removal), tostring(removalScale), tostring(expected))
	if not near(expected, 0, 1e-9) then
		record("WARN", "REL.K.sugarBeet.design", "sugar beet K surplus %s, design 0 (no crop extra on K)", tostring(expected))
	end
	-- field info need = target - stored distance: stored -120 -> need 120 + the crop extra (0 by design)
	local soilTypeIndex = kMap.soilTypeIndices[1]
	local stored = kMap:levelToUnits(kMap.levelOffset - math.floor(120 / kMap.step + 0.5))
	local need = kMap:getPhAdjustedTarget(kMap:getTargetUnits(soilTypeIndex, beet.index), 1, soilTypeIndex) - stored
	check("REL.K.sugarBeet.need", near(need, expected + 120, 1e-9), "stored %s, target %s: need %s, shown %s", tostring(stored), tostring(expected), tostring(need), kMap:formatUnits(need))
end

local function testUi()
	for _, map in ipairs(VtszNutrients.maps) do
		local id = map.nutrientId
		local lowBand = map:getBandIndex(map.legendMin)
		local highBand = map:getBandIndex(map.legendMax)
		check("UI." .. id .. ".bands", lowBand == 1 and highBand == map.numBands, "min -> band %d, max -> band %d", lowBand, highBand)
		local ok, text = pcall(map.formatUnits, map, map.step * 7.4)
		check("UI." .. id .. ".format", ok and type(text) == "string", "formatUnits -> %s", tostring(text))
		for _, key in ipairs({ "vtsz_map_" .. id, "vtsz_fieldInfo_" .. id }) do
			check("UI." .. id .. "." .. key, g_i18n:hasText(key, VtszNutrients.MOD_NAME), "l10n key present")
		end
		-- relative maps show the distance with a sign ("%+d kg/ha K2O"): + above, - below the target
		if map.relative and map.unitFormat:find("%%%+") ~= nil then
			local above, below = map:formatUnits(map.step * 4), map:formatUnits(-map.step * 4)
			check("UI." .. id .. ".sign", above:sub(1, 1) == "+" and below:sub(1, 1) == "-", "+4 steps -> '%s', -4 steps -> '%s'", above, below)
		end
		-- integer formats round the half unit up: the field info need of +207.5 is shown as 208 (P / K)
		if map.unitFormat:find("%%[%+%- ]?%d*d") ~= nil then
			check("UI." .. id .. ".round", map:formatUnits(207.5) == string.format(map.unitFormat, 208), "formatUnits(207.5) = '%s' expected '%s'", map:formatUnits(207.5), string.format(map.unitFormat, 208))
		end
	end
	for _, key in ipairs({ "vtsz_level_low", "vtsz_level_veryLow", "vtsz_level_ph", "vtsz_hud_rate" }) do
		check("UI.l10n." .. key, g_i18n:hasText(key, VtszNutrients.MOD_NAME), "l10n key present")
	end
end

local function testRegistration()
	local pf = VtszNutrients.pf
	local valueMaps = pf.valueMaps
	local tramline = nil
	local indexesOk = true
	for i, valueMap in ipairs(valueMaps) do
		if valueMap.valueMapIndex ~= i then
			indexesOk = false
		end
		if valueMap.name == "tramlineMap" then
			tramline = i
		end
	end
	check("REGISTER.valueMapIndex", indexesOk, "valueMapIndex equals the list position for all %d maps", #valueMaps)
	for _, map in ipairs(VtszNutrients.maps) do
		local position = nil
		for i, valueMap in ipairs(valueMaps) do
			if valueMap == map then
				position = i
			end
		end
		check("REGISTER." .. map.nutrientId .. ".position", position ~= nil and (tramline == nil or position < tramline), "position=%s tramlineMap=%s", tostring(position), tostring(tramline))
	end
	check("REGISTER.hooks", type(pf.nitrogenMap.harvestUpdate) == "function" and type(pf.nitrogenMap.getFieldInfoYieldChange) == "function" and type(pf.harvestExtension.getLastMultipliers) == "function", "PF harvest functions are callable")
end

local function testMaps()
	local soilSize = VtszNutrients.pf.soilMap ~= nil and VtszNutrients.pf.soilMap.sizeX or nil
	for _, map in ipairs(VtszNutrients.maps) do
		local p = "MAP." .. map.nutrientId
		check(p .. ".exists", map.bitVectorMap ~= nil and map.bitVectorMap ~= 0, "bitVectorMap present")
		local size = map.bitVectorMap ~= nil and getBitVectorMapSize(map.bitVectorMap) or nil
		check(p .. ".size", size == map.sizeX and (soilSize == nil or size == soilSize), "map=%s sizeX=%s PF soil map=%s", tostring(size), tostring(map.sizeX), tostring(soilSize))
	end
end

----------------------------------------------------------------------------------------------------
-- World test: writes map data on ONE field (needs "confirm"). Use a throwaway savegame.
----------------------------------------------------------------------------------------------------

local function readLevel(map, x, z)
	local terrainSize = g_currentMission.terrainSize
	local lx = MathUtil.round((x + terrainSize * 0.5) / terrainSize * map.sizeX + 0.5) - 1
	local lz = MathUtil.round((z + terrainSize * 0.5) / terrainSize * map.sizeY + 0.5) - 1
	return getBitVectorMapPoint(map.bitVectorMap, lx, lz, map.firstChannel, map.numChannels)
end

local function testWorld(fieldId)
	local field = g_fieldManager:getFieldById(tonumber(fieldId))
	if field == nil or field.getDensityMapPolygon == nil then
		record("SKIP", "WORLD", "field %s not found", tostring(fieldId))
		return
	end
	local x, z = field:getCenterOfFieldWorldPosition()
	local shape = field:getDensityMapPolygon()
	local sprayTypeIndex = nil
	local sprayType = g_sprayTypeManager:getSprayTypeByName("FERTILIZER")
	if sprayType ~= nil then
		sprayTypeIndex = sprayType.index
	end
	if sprayTypeIndex == nil then
		record("SKIP", "WORLD", "spray type FERTILIZER not found")
		return
	end

	local wasDebug = VtszNutrients.debug
	VtszNutrients.debug = false
	for _, map in ipairs(VtszNutrients.maps) do
		local id = map.nutrientId
		local original = readLevel(map, x, z)
		-- 1. set -> read back
		local startUnits = map:levelToUnits(math.floor(map:getCapLevel() / 4)) -- a quarter of the reachable range: room for one big spray under the soft cap
		local ok, level = map:setUnitsOnField(fieldId, startUnits)
		local afterSet = readLevel(map, x, z)
		check("WORLD." .. id .. ".set", ok and afterSet == level, "set level %s, read %s", tostring(level), tostring(afterSet))

		-- 2. real spray path (lock rule, noise, clamp) with each fill type that carries this nutrient
		for _, fillTypeIndex in ipairs(sortedKeys(map.fillTypeContents)) do
			local content = map.fillTypeContents[fillTypeIndex]
			if content.value > 0 then
				local name = fillName(fillTypeIndex)
				map:setUnitsOnField(fieldId, startUnits)
				local before = readLevel(map, x, z)
				VtszNutrients:applySpray(shape, sprayTypeIndex, fillTypeIndex, 1000)
				local after = readLevel(map, x, z)
				local expectedLevels = content.value * VtszConfig.inputScale * map.timeScale / map.step
				local id2 = string.format("WORLD.%s.spray.%s", id, name)
				if after == nil or before == nil then
					record("SKIP", id2, "level not readable")
				elseif after == before and expectedLevels >= 1 then
					-- the spray type lock (same spray type already on the pixel) also gives no change
					record("WARN", id2, "no change, expected +%.2f levels (pixel locked by the spray type?)", expectedLevels)
				else
					local gained = after - before
					local maxLevel = map:getCapLevel() -- the soft cap (P) or the stored maximum
					local expected = math.min(before + math.floor(expectedLevels), maxLevel) - before
					-- the fraction goes to 1/4 of the pixels by noise: the sampled pixel has whole or whole+1 levels
					check(id2, gained >= expected and gained <= expected + 1 and after <= maxLevel, "gained %d levels, expected %d (+0/1 noise)", gained, expected)
				end
			end
		end

		-- 3. cap: vtszNutrientSet above the highest reachable content gives the cap level (P: maxUnits), also on maps without maxUnits
		local capLevel = map:getCapLevel()
		local capOk, capSet = map:setUnitsOnField(fieldId, map:levelToUnits(map.maxValue))
		check("WORLD." .. id .. ".capSet", capOk and capSet == capLevel and readLevel(map, x, z) == capLevel, "set the stored maximum: level %s, read %s, cap level %d", tostring(capSet), tostring(readLevel(map, x, z)), capLevel)
		-- 4. a soft cap map (P): spreading a big dose one level below the cap ends exactly at the cap, never above
		if map.maxUnits ~= nil then
			local bestFillType, bestValue = nil, 0
			for _, fillTypeIndex in ipairs(sortedKeys(map.fillTypeContents)) do
				if map.fillTypeContents[fillTypeIndex].value > bestValue then
					bestFillType, bestValue = fillTypeIndex, map.fillTypeContents[fillTypeIndex].value
				end
			end
			local overshoot = bestFillType ~= nil and bestValue * VtszConfig.inputScale * map.timeScale / map.step or 0
			if bestFillType == nil or overshoot < 2 then
				record("SKIP", "WORLD." .. id .. ".capSpray", "no product that overshoots the cap by 2 levels per 1000 l/ha")
			else
				map:setUnitsOnField(fieldId, map:levelToUnits(capLevel - 1))
				local before = readLevel(map, x, z)
				VtszNutrients:applySpray(shape, sprayTypeIndex, bestFillType, 1000)
				local after = readLevel(map, x, z)
				if after == before then
					record("WARN", "WORLD." .. id .. ".capSpray", "no change with %s (pixel locked by the spray type?)", fillName(bestFillType))
				else
					check("WORLD." .. id .. ".capSpray", after == capLevel, "%s +%.1f levels from level %d: now %s, cap level %d", fillName(bestFillType), overshoot, before, tostring(after), capLevel)
				end
			end
		end

		-- restore: the field gets one uniform level (pixel variation is lost)
		map:setUnitsOnField(fieldId, map:levelToUnits(original or 0))
		record("WARN", "WORLD." .. id .. ".restore", "field %s set back to the uniform level %s", tostring(fieldId), tostring(original))
	end
	VtszNutrients.debug = wasDebug
end

----------------------------------------------------------------------------------------------------
-- Runner + console
----------------------------------------------------------------------------------------------------

local GROUPS = {
	registration = testRegistration,
	maps = testMaps,
	config = testConfig,
	relative = testRelative,
	spray = function() testSpray() testBaseFertilizer() end,
	harvest = testHarvest,
	yield = testYield,
	rounding = testRounding,
	mineral = testMineral,
	auto = testAuto,
	ph = testPh,
	scale = testYieldScale,
	rates = testRates,
	ui = testUi,
}
local GROUP_ORDER = { "registration", "maps", "config", "relative", "spray", "harvest", "yield", "rounding", "mineral", "ph", "auto", "scale", "rates", "ui" }

local function runGroup(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		record("FAIL", "EXCEPTION." .. name, "%s", tostring(err))
	end
end

function VtszSelfTest:run(group, arg1, arg2)
	counts = {}
	local startTime = getTimeSec()
	group = (group or "all"):lower()

	if VtszNutrients == nil or VtszNutrients.pf == nil or #VtszNutrients.maps == 0 then
		return "vtszSelfTest: the mod is not active"
	end

	Logging.info("%sBEGIN group=%s", TAG, group)
	if group == "world" then
		if tostring(arg2):lower() ~= "confirm" or arg1 == nil then
			Logging.info("%sworld test writes map data of one field. Use a throwaway savegame: vtszSelfTest world <fieldId> confirm", TAG)
			return "Usage: vtszSelfTest world <fieldId> confirm (writes map data, use a throwaway savegame)"
		end
		runGroup("world", testWorld, arg1)
	elseif group == "all" then
		for _, name in ipairs(GROUP_ORDER) do
			runGroup(name, GROUPS[name])
		end
	elseif GROUPS[group] ~= nil then
		runGroup(group, GROUPS[group])
	else
		return "Unknown group. Use: all, " .. table.concat(GROUP_ORDER, ", ") .. ", world <fieldId> confirm"
	end

	local summary = string.format("pass=%d fail=%d warn=%d skip=%d (%d ms)", counts.PASS or 0, counts.FAIL or 0, counts.WARN or 0, counts.SKIP or 0, (getTimeSec() - startTime) * 1000)
	Logging.info("%sSUMMARY group=%s %s", TAG, group, summary)
	return "vtszSelfTest " .. summary .. " - details in log.txt, prefix [VTSZ-NUT][TEST]"
end

-- Console entry: a failure here is only text for the console, never an error that leaves this function.
function VtszSelfTest:consoleRun(group, arg1, arg2)
	local ok, result = pcall(self.run, self, group, arg1, arg2)
	if not ok then
		Logging.info("%sABORT %s", TAG, tostring(result))
		return "vtszSelfTest aborted: " .. tostring(result)
	end
	return result
end

function VtszSelfTest:register()
	addConsoleCommand("vtszSelfTest", "Self test of the P, K, OM maps, result in log.txt", "consoleRun", self, "[all|registration|maps|config|relative|spray|harvest|yield|rounding|mineral|ph|auto|scale|rates|ui|world <fieldId> confirm]")
end

function VtszSelfTest:unregister()
	removeConsoleCommand("vtszSelfTest")
end
