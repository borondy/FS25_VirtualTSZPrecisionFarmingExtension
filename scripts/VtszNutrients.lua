-- VirtualTSZ Precision Farming Extension: P2O5, K2O and organic matter maps for Precision Farming.
-- Entry point (extraSourceFiles). Runs after FS25_precisionFarming and FS25_0_TRPFConfigurator (dependencies).

VtszConfig = {
	inputScale = 1,
	removalScale = 1,
	autoRate = { maxLitersPerHa = 2500 }, -- P/K automatic application rate, from <autoRate>
	yieldReference = 1.5, -- PF yield multiplier that counts as the typical yield of the removal values
	baseFertilizer = false, -- base-game FERTILIZER adds P and K only when enabled (<baseFertilizer enabled>)
	catchCropNames = {},
	mapCoverCropNames = nil,
	minimapMaps = {}, -- fill type name -> N / P / K / OM, minimap layer override from <minimap>
	autoBaseDefaults = {}, -- fill type name -> N / P / K, default base nutrient of the automatic rate from <autoBaseDefault>
	rates = {}, -- fill type name -> { default, step, min, max } l/ha, from rateControl
}

VtszNutrients = {}
VtszNutrients.PRODUCT_CHANNELS = 5
VtszNutrients.PRODUCT_MAX = 31
VtszNutrients.MOD_NAME = g_currentModName
VtszNutrients.MOD_DIR = g_currentModDirectory
VtszNutrients.debug = false
VtszNutrients.maps = {}

local modName = g_currentModName
local modDir = g_currentModDirectory

local function logInfo(fmt, ...)
	Logging.info("[VTSZ-NUT] " .. fmt, ...)
end

local function logError(fmt, ...)
	Logging.error("[VTSZ-NUT] " .. fmt, ...)
end

local pfEnv = _G["FS25_precisionFarming"]
local pf = pfEnv ~= nil and pfEnv.g_precisionFarming or nil

if pf == nil then
	logError("FS25_precisionFarming not found, the mod is disabled")
else
	source(modDir .. "scripts/NutrientMap.lua")
	source(modDir .. "scripts/VtszMinimap.lua")
	source(modDir .. "scripts/VtszHelp.lua")
	source(modDir .. "scripts/VtszAdminCommandEvent.lua")

	-- optional self test (console only). Absent or broken: the mod runs the same.
	if fileExists(modDir .. "scripts/VtszSelfTest.lua") then
		local ok, err = pcall(source, modDir .. "scripts/VtszSelfTest.lua")
		if not ok then
			VtszSelfTest = nil
			logError("self test not loaded: %s", tostring(err))
		end
	end

	-- optional dev profiler (console only, command vtszPerf)
	if fileExists(modDir .. "scripts/VtszProfiler.lua") then
		local ok, err = pcall(source, modDir .. "scripts/VtszProfiler.lua")
		if not ok then
			VtszProfiler = nil
			logError("profiler not loaded: %s", tostring(err))
		end
	end

	VtszNutrients.pf = pf

	---------------------------------------------------------------------------------------------
	-- 1. Register the maps with Precision Farming (before PF initialize / loadMap).
	--    The PF selector indexes valueMaps[state] but shows only maps with getShowInMenu(), so ours go
	--    before the hidden TramlineMap and CoverMap.
	---------------------------------------------------------------------------------------------
	local insertAt = #pf.valueMaps + 1
	for i, valueMap in ipairs(pf.valueMaps) do
		if valueMap.name == "tramlineMap" then
			insertAt = i
			break
		end
	end
	for i, def in ipairs({ { "P", "vtszPMap" }, { "K", "vtszKMap" }, { "OM", "vtszOMMap" } }) do
		local map = NutrientMap.new(pf, def[1], def[2])
		table.insert(pf.valueMaps, insertAt + i - 1, map)
		pf[def[2]] = map
		table.insert(VtszNutrients.maps, map)
	end
	for i, valueMap in ipairs(pf.valueMaps) do
		valueMap.valueMapIndex = i
	end

	---------------------------------------------------------------------------------------------
	-- 2. Add the sprayer specialization to every type that has "sprayer"
	---------------------------------------------------------------------------------------------
	local oldFinalizeTypes = TypeManager.finalizeTypes
	function TypeManager:finalizeTypes(...)
		if self.typeName == "vehicle" and g_modIsLoaded[modName] then
			local specName = modName .. ".vtszSprayer"
			for typeName, typeEntry in pairs(self:getTypes()) do
				if typeEntry.specializationsByName["sprayer"] ~= nil and typeEntry.specializationsByName[specName] == nil then
					self:addSpecialization(typeName, specName)
				end
			end
		end
		oldFinalizeTypes(self, ...)
	end
end

----------------------------------------------------------------------------------------------------
-- Helpers used by the hooks
----------------------------------------------------------------------------------------------------

function VtszNutrients:isNutrientFillType(fillTypeIndex)
	for _, map in ipairs(self.maps) do
		if map.fillTypeContents ~= nil and map.fillTypeContents[fillTypeIndex] ~= nil then
			return true
		end
	end
	return false
end

-- Products without nitrogen (PF does not manage their rate) get an own application rate, config rateControl.
function VtszNutrients:isRateControlled(fillTypeIndex)
	if fillTypeIndex == nil or fillTypeIndex == FillType.UNKNOWN then
		return false
	end
	local name = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)
	if name == nil or VtszConfig.rates[name] == nil then
		return false
	end
	local nitrogenMap = pf ~= nil and pf.nitrogenMap or nil
	if nitrogenMap ~= nil and nitrogenMap:getFillTypeIsFertilizer(fillTypeIndex) then
		return false
	end
	return true
end

function VtszNutrients:getRateConfig(fillTypeIndex)
	local name = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)
	return VtszConfig.rates[name] or { default = 100, step = 10, min = 10, max = 1500 }
end

-- Spray effects take their material per fill type from g_materialManager (filled from the base game material holders by
-- fill type name). Our liquid products have none, so the effect stays invisible: reuse the LIQUIDFERTILIZER materials.
VtszNutrients.LIQUID_FILL_TYPES = { "NITROSOL30", "ELESZTOVINASZ" }

function VtszNutrients:aliasLiquidMaterials()
	if self.liquidMaterialsAliased then
		return
	end
	local source = FillType.LIQUIDFERTILIZER
	if g_materialManager.materials[source] == nil then
		return -- materials not loaded yet, try again on the next vehicle
	end
	-- the base game registers only some material tables for LIQUIDFERTILIZER (sprayer: materials), alias what exists
	for _, name in ipairs(self.LIQUID_FILL_TYPES) do
		local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(name)
		if fillTypeIndex ~= nil then
			for _, target in ipairs({ g_materialManager.materials, g_materialManager.particleMaterials }) do
				if target[source] ~= nil and target[fillTypeIndex] == nil then
					target[fillTypeIndex] = target[source]
				end
			end
		end
	end
	self.liquidMaterialsAliased = true
end

function VtszNutrients:getPFSprayerSpecTableName()
	local extendedSprayer = pfEnv ~= nil and pfEnv.ExtendedSprayer or nil
	return extendedSprayer ~= nil and extendedSprayer.SPEC_TABLE_NAME or nil
end

-- kg/ha of N, P2O5, K2O for an application rate in l/ha
function VtszNutrients:getNutrientsPerHa(fillTypeIndex, litersPerHa)
	local nitrogen, phosphorus, potassium = 0, 0, 0
	local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
	local nitrogenMap = pf ~= nil and pf.nitrogenMap or nil
	if fillType ~= nil and nitrogenMap ~= nil then
		local amount = nitrogenMap:getNitrogenAmountFromFillType(fillTypeIndex)
		if amount ~= nil and amount > 0 then
			-- massPerLiter is tonnes per liter
			nitrogen = litersPerHa * fillType.massPerLiter * 1000 * amount
		end
	end
	for _, map in ipairs(self.maps) do
		local content = map.fillTypeContents ~= nil and map.fillTypeContents[fillTypeIndex] or nil
		if content ~= nil then
			if map.nutrientId == "P" then
				phosphorus = content.value * litersPerHa / 1000
			elseif map.nutrientId == "K" then
				potassium = content.value * litersPerHa / 1000
			end
		end
	end
	return nitrogen, phosphorus, potassium
end

-- mod texts are read when the game starts, so a text added later shows "Missing ..." until the game is restarted; use the default then
function VtszNutrients:getText(key, default)
	if g_i18n:hasText(key, modName) then
		return g_i18n:getText(key, modName)
	end
	return default
end

function VtszNutrients:getMapSize()
	local map = self.maps[1]
	return map ~= nil and map.sizeX or 1024
end

-- Product id per spray type (1..PRODUCT_MAX), stable across savegames: rank of the spray type name among the nutrient products.
function VtszNutrients:buildProductIds()
	local names = {}
	for _, sprayType in ipairs(g_sprayTypeManager.sprayTypes) do
		if sprayType.fillType ~= nil and self:isNutrientFillType(sprayType.fillType.index) then
			table.insert(names, sprayType.name)
		end
	end
	table.sort(names)
	if #names > VtszNutrients.PRODUCT_MAX then
		logError("%d products, only %d are tracked per pixel", #names, VtszNutrients.PRODUCT_MAX)
	end
	local ids = {}
	for rank, name in ipairs(names) do
		if rank <= VtszNutrients.PRODUCT_MAX then
			ids[g_sprayTypeManager:getSprayTypeByName(name).index] = rank
		end
	end
	return ids
end

-- Loads the last-product map from the savegame and hands it to `owner` (a NutrientMap) for saving and deleting. Server only.
function VtszNutrients:loadProductMap(owner, size)
	if g_server == nil or self.productMap ~= nil then
		return
	end
	local fileName = "vtsz_productMap.grle"
	local map = owner:loadSavedBitVectorMap("vtszProductMap", fileName, VtszNutrients.PRODUCT_CHANNELS, size)
	if getBitVectorMapSize(map) ~= size then
		delete(map)
		map = createBitVectorMap("vtszProductMap")
		loadBitVectorMapNew(map, size, size, VtszNutrients.PRODUCT_CHANNELS, false)
	end
	owner:addBitVectorMapToSave(map, fileName)
	owner:addBitVectorMapToDelete(map)
	self.productMap = map
end

function VtszNutrients:getLockData()
	local data = self.lockData
	if data == nil then
		local size = self:getMapSize()
		local lockMap = createBitVectorMap("vtszLockMap")
		loadBitVectorMapNew(lockMap, size, size, 1, false)
		data = {}
		data.bitVectorMap = lockMap
		data.modifier = DensityMapModifier.new(lockMap, 0, 1, g_terrainNode)
		-- default rounding (pixel centre inside the polygon), NOT INCLUSIVE: PF paints the ground spray type, which the lock reads,
		-- only inside the polygon. Pixels merely touched at the swath edge never got locked and were dosed every frame.
		-- The lock, product and add modifiers (NutrientMap:getSprayData) must all use the same pixel set.
		data.lockFilter = DensityMapFilter.new(lockMap, 0, 1)
		data.lockFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 0)
		local sprayTypeMapId, firstChannel, numChannels = g_currentMission.fieldGroundSystem:getDensityMapData(FieldDensityMap.SPRAY_TYPE)
		data.sprayTypeFilter = DensityMapFilter.new(sprayTypeMapId, firstChannel, numChannels)
		data.sprayTypeFilter:setSupersamplingMode(DensityFilterSupersamplingMode.ANY)
		-- PF paints the spray type only where the ground type is a field (FSDensityMapUtil.setGroundTypeLayerArea, fieldFilter),
		-- so pixels fully outside a field never get locked and were dosed on every frame: treat them as locked.
		local groundMapId, groundFirstChannel, groundNumChannels = g_currentMission.fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
		-- The lock above is only as good as PF's paint. The coarse map rounds the swath corners to whole pixels, the finer spray
		-- type map does not, so edge pixels inside our polygon can stay unpainted and would be dosed on every frame (blue lines
		-- beside the strip, different for each working width). passMap remembers per pixel which pass of which sprayer dosed it.
		local passMap = createBitVectorMap("vtszPassMap")
		loadBitVectorMapNew(passMap, size, size, VtszNutrients.PASS_CHANNELS, false)
		data.passMap = passMap
		data.passModifier = DensityMapModifier.new(passMap, 0, VtszNutrients.PASS_CHANNELS, g_terrainNode)
		data.passFilter = DensityMapFilter.new(passMap, 0, VtszNutrients.PASS_CHANNELS)
		data.offFieldFilter = DensityMapFilter.new(groundMapId, groundFirstChannel, groundNumChannels)
		data.offFieldFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 0)
		data.offFieldFilter:setSupersamplingMode(DensityFilterSupersamplingMode.ALL)
		-- all products share one ground spray type, so remember the last product per pixel as well
		local productMap = self.productMap
		if productMap == nil then
			-- not loaded with the savegame (should not happen): temporary map, not saved
			productMap = createBitVectorMap("vtszProductMap")
			loadBitVectorMapNew(productMap, size, size, VtszNutrients.PRODUCT_CHANNELS, false)
			data.ownsProductMap = true
		end
		data.productMap = productMap
		data.productModifier = DensityMapModifier.new(productMap, 0, VtszNutrients.PRODUCT_CHANNELS, g_terrainNode)
		data.productFilter = DensityMapFilter.new(productMap, 0, VtszNutrients.PRODUCT_CHANNELS)
		data.productFilter:setSupersamplingMode(DensityFilterSupersamplingMode.ANY)
		data.productIds = self:buildProductIds()
		self.lockData = data
	end
	return data
end

-- Spreading: add the nutrients of the sprayed fill type once per pixel and spray type (same lock rule as PF's N map).
local sprayUnits = {} -- scratch, reused each call (0 = nothing for that map)

-- Pass ids (1 .. PASS_MAX) tell one spreading pass of one sprayer from the next; a pixel dosed in a pass is not dosed again in it.
VtszNutrients.PASS_CHANNELS = 8
VtszNutrients.PASS_MAX = 255
VtszNutrients.PASS_GAP_MS = 2000 -- no dose for this long = the pass is over
VtszNutrients.lastPassId = 0

function VtszNutrients.nextPassId()
	VtszNutrients.lastPassId = VtszNutrients.lastPassId % VtszNutrients.PASS_MAX + 1
	return VtszNutrients.lastPassId
end

-- groundSprayTypeIndex (optional): the spray type the game writes to the ground when it differs from the product's own one
-- (fertilizing cultivators always write SprayType.FERTILIZER); the lock must compare with what the ground really carries.
-- passId (optional): pass of the calling sprayer, see VtszNutrients.nextPassId; nil = only the ground-based lock.
function VtszNutrients:applySpray(shape, sprayTypeIndex, fillTypeIndex, litersPerHa, groundSprayTypeIndex, passId)
	local sprayTypeDesc = g_sprayTypeManager:getSprayTypeByIndex(sprayTypeIndex)
	if sprayTypeDesc == nil then
		return
	end
	local maps = self.maps
	local numMaps = #maps
	local any = false
	for i = 1, numMaps do
		local units = maps[i]:getUnitsForFillType(fillTypeIndex, litersPerHa)
		if units ~= nil and units > 0 then
			sprayUnits[i] = units
			any = true
		else
			sprayUnits[i] = 0
		end
	end
	if not any then
		return
	end
	local lock = self:getLockData()
	local productId = lock.productIds[sprayTypeIndex] or 0
	shape:applyToModifier(lock.modifier)
	shape:applyToModifier(lock.productModifier)
	local groundDesc = groundSprayTypeIndex ~= nil and g_sprayTypeManager:getSprayTypeByIndex(groundSprayTypeIndex) or sprayTypeDesc
	lock.sprayTypeFilter:setValueCompareParams(DensityValueCompareType.EQUAL, (groundDesc or sprayTypeDesc).sprayGroundType)
	lock.productFilter:setValueCompareParams(DensityValueCompareType.EQUAL, productId)
	local debugPixels, debugLocked
	if self.debug then
		local _, total = lock.modifier:executeSetWithStats(0)
		debugPixels = total
	else
		lock.modifier:executeSet(0)
	end
	-- locked = ground still carries a spray type AND the last product here was this one
	if self.debug then
		local _, locked = lock.modifier:executeSetWithStats(1, lock.sprayTypeFilter, lock.productFilter)
		debugLocked = locked
	else
		lock.modifier:executeSet(1, lock.sprayTypeFilter, lock.productFilter)
	end
	lock.modifier:executeSet(1, lock.offFieldFilter)
	if passId ~= nil then
		-- dosed earlier in this pass (also edge pixels PF never painted)
		shape:applyToModifier(lock.passModifier)
		lock.passFilter:setValueCompareParams(DensityValueCompareType.EQUAL, passId)
		lock.modifier:executeSet(1, lock.passFilter)
	end
	for i = 1, numMaps do
		local units = sprayUnits[i]
		if units > 0 then
			maps[i]:addUnitsAtArea(shape, units, lock.lockFilter)
		end
	end
	lock.productModifier:executeSet(productId)
	if passId ~= nil then
		lock.passModifier:executeSet(passId)
	end
	if self.debug then
		local now = g_time or 0
		if self.lastDebugTime == nil or now - self.lastDebugTime > 1000 then
			self:debugThrottled(string.format("spray fillType=%s l/ha=%.0f width=%s P=%.2f K=%.2f OM=%.4f pixels=%s locked=%s (dosed=%s)", tostring(g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)), litersPerHa, tostring(self.debugWidth), sprayUnits[1] or 0, sprayUnits[2] or 0, sprayUnits[3] or 0, tostring(debugPixels), tostring(debugLocked), tostring((debugPixels or 0) - (debugLocked or 0))))
		end
	end
end

function VtszNutrients:debugThrottled(text)
	local now = g_time or 0
	if self.lastDebugTime == nil or now - self.lastDebugTime > 1000 then
		self.lastDebugTime = now
		logInfo("%s", text)
	end
end

----------------------------------------------------------------------------------------------------
-- Harvest: removal + yield factor. Wraps instance methods of PF objects (no PF file is changed).
----------------------------------------------------------------------------------------------------

-- Yield of the current harvest step relative to the typical yield the config removal values are for (1 = typical).
-- Uses PF's multiplier of this very step (PF sets its inputs before the cutter runs and clears them after the post-update,
-- so they are valid when harvestUpdate is called). nil inputs (other call paths) give 1. Clamped and quantised so the
-- cached multi modifiers of NutrientMap stay few.
VtszNutrients.YIELD_SCALE_MIN = 0.3
VtszNutrients.YIELD_SCALE_MAX = 2.0 -- PF multiplier 2.0 x yieldPotential 1.2 = 2.4 -> 1.6 at reference 1.5: no flat top for good fields

function VtszNutrients.quantiseYieldScale(multiplier)
	if multiplier == nil or multiplier ~= multiplier or VtszConfig.yieldReference <= 0 then
		return 1
	end
	local scale = math.clamp(multiplier / VtszConfig.yieldReference, VtszNutrients.YIELD_SCALE_MIN, VtszNutrients.YIELD_SCALE_MAX)
	local step = NutrientMap.YIELD_SCALE_STEP
	return math.floor(scale / step + 0.5) * step
end

function VtszNutrients:getYieldScale(extension)
	if extension == nil or extension.lastPlowFactor == nil or extension.replaceYieldPotential == nil then
		return 1
	end
	local ok, _, multiplier = pcall(extension.getLastMultipliers, extension, extension.replaceYieldPotential, extension.replaceRegularNFactor, extension.replaceNFactor, extension.replaceRegularPHFactor, extension.replacePHFactor)
	if not ok then
		return 1
	end
	self.lastMultiplier = multiplier -- debug line only
	return VtszNutrients.quantiseYieldScale(multiplier)
end

----------------------------------------------------------------------------------------------------
-- Automatic application rate with a base nutrient (N: PF's own auto mode, P / K: this mod)
----------------------------------------------------------------------------------------------------

VtszNutrients.AUTO_BASES = { "N", "P", "K" }

-- base nutrient with the highest content (kg per 1000 l = same order as the NPK percentages); a tie keeps the earlier one
-- (N first). A tie is a difference below 0.5 %: the N content comes from the engine's float32 massPerLiter, so 15-15-15
-- gives N 157.4999 against P 157.5.
function VtszNutrients.pickBase(n, p, k)
	local best, bestValue = nil, 0
	for i, value in ipairs({ n, p, k }) do
		if value > bestValue * 1.005 + 1e-9 then
			best, bestValue = VtszNutrients.AUTO_BASES[i], value
		end
	end
	return best
end

-- <autoBaseDefault> forces the default for a product (when it contains that nutrient), else the highest content
function VtszNutrients:getDefaultAutoBase(fillTypeIndex)
	local name = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)
	local forced = name ~= nil and VtszConfig.autoBaseDefaults[name] or nil
	if forced ~= nil then
		for _, id in ipairs(self:getAutoBases(fillTypeIndex)) do
			if id == forced then
				return forced
			end
		end
	end
	return VtszNutrients.pickBase(self:getNutrientsPerHa(fillTypeIndex, 1000))
end

-- base nutrients the product contains, in the order N, P, K
function VtszNutrients:getAutoBases(fillTypeIndex)
	local list = {}
	for i, value in ipairs({ self:getNutrientsPerHa(fillTypeIndex, 1000) }) do
		if value > 0 then
			table.insert(list, VtszNutrients.AUTO_BASES[i])
		end
	end
	return list
end

function VtszNutrients:getMapById(nutrientId)
	for _, map in ipairs(self.maps) do
		if map.nutrientId == nutrientId then
			return map
		end
	end
	return nil
end

-- Where the automatic rate reads the map: ahead of the work area in the driving direction. The centre of the area is on pixels the
-- sprayer just filled (they read 0 need), so the rate dropped to 0 while spreading and left unsprayed stripes.
function VtszNutrients.getWorkAreaSamplePoint(vehicle, workArea)
	local cx, cz = VtszNutrients.getWorkAreaCenter(workArea)
	if vehicle == nil or vehicle.rootNode == nil then
		return cx, cz
	end
	local sx, _, sz = getWorldTranslation(workArea.start)
	local hx, _, hz = getWorldTranslation(workArea.height)
	local depth = MathUtil.vector2Length(hx - sx, hz - sz)
	local dx, _, dz = localDirectionToWorld(vehicle.rootNode, 0, 0, 1)
	local length = MathUtil.vector2Length(dx, dz)
	if length < 0.0001 then
		return cx, cz
	end
	local direction = (vehicle.movingDirection or 1) >= 0 and 1 or -1
	local offset = depth * 0.5 + VtszNutrients.SAMPLE_AHEAD
	return cx + dx / length * direction * offset, cz + dz / length * direction * offset
end
VtszNutrients.SAMPLE_AHEAD = 3 -- m beyond the front edge of the work area (about 1.5 map pixels)

function VtszNutrients.getWorkAreaCenter(workArea)
	local sx, _, sz = getWorldTranslation(workArea.start)
	local wx, _, wz = getWorldTranslation(workArea.width)
	local hx, _, hz = getWorldTranslation(workArea.height)
	return sx + (wx - sx + hx - sx) * 0.5, sz + (wz - sz + hz - sz) * 0.5
end

-- l/ha of the product that brings the base nutrient (P or K) to what the soil at x, z needs, nil when there is no data
-- (soil not sampled, no soil type, product without that nutrient). fruitHint: planned fruit type, else the fruit standing there.
function VtszNutrients:getAutoRateAt(fillTypeIndex, baseId, x, z, fruitHint)
	local map = self:getMapById(baseId)
	if map == nil or map.soilMap == nil then
		return nil
	end
	local per1000 = map:getUnitsForFillType(fillTypeIndex, 1000)
	if per1000 == nil or per1000 <= 0 then
		return nil
	end
	local level = map:getLevelAtWorldPos(x, z)
	local soilTypeIndex = map.soilMap:getTypeIndexAtWorldPos(x, z)
	if level == nil or soilTypeIndex == nil or soilTypeIndex <= 0 then
		return nil
	end
	local fruitTypeIndex = fruitHint
	if fruitTypeIndex == nil or fruitTypeIndex == FruitType.UNKNOWN then
		fruitTypeIndex = FSDensityMapUtil.getFruitTypeIndexAtWorldPos(x, z)
	end
	local needUnits = map:getAutoRateUnits(map:levelToUnits(level), soilTypeIndex, fruitTypeIndex)
	return math.min(needUnits / per1000 * 1000, VtszConfig.autoRate.maxLitersPerHa)
end

-- PF's auto mode (products with nitrogen) works in N states of the N map: usage, N map change and HUD all follow PF's
-- nitrogen application rate. For a P / K base this wraps that rate and hands PF the N-equivalent of the liters the base
-- nutrient needs, so the N map stays consistent with what is spread. The result moves in whole N states (amountPerState,
-- 5 kg N/ha by default), so the liters are rounded accordingly. Context (vehicle, work area) comes from the wrapped
-- VtszSprayer:updateWorkAreaSubSectionData.
function VtszNutrients:getAutoNitrogenStates(context, sprayTypeIndex, fruitHint, nitrogenNeedStates)
	local vehicle = context.vehicle
	local pfSpecName = self:getPFSprayerSpecTableName()
	local pfSpec = pfSpecName ~= nil and vehicle[pfSpecName] or nil
	if pfSpec == nil or not pfSpec.sprayAmountAutoMode or not pfSpec.isFertilizing or vehicle.vtszGetAutoBase == nil then
		return nil
	end
	local sprayType = g_sprayTypeManager:getSprayTypeByIndex(sprayTypeIndex)
	if sprayType == nil or sprayType.fillType == nil then
		return nil
	end
	local fillTypeIndex = sprayType.fillType.index
	local baseId = vehicle:vtszGetAutoBase(fillTypeIndex)
	if baseId == nil or baseId == "N" then
		return nil
	end
	local nitrogenMap = pf.nitrogenMap
	local litersPerKgN = nitrogenMap:getFertilizerUsageByNitrogenAmount(1, fillTypeIndex)
	if litersPerKgN == nil or litersPerKgN <= 0 then
		return nil
	end
	local x, z = VtszNutrients.getWorkAreaSamplePoint(vehicle, context.workArea)
	local plannedFruit = pfSpec.nApplyAutoModeFruitType
	if plannedFruit == nil or plannedFruit == FruitType.UNKNOWN then
		plannedFruit = fruitHint
	end
	local liters = self:getAutoRateAt(fillTypeIndex, baseId, x, z, plannedFruit)
	if liters == nil then
		return nil
	end
	local states = math.floor(liters / litersPerKgN / nitrogenMap.amountPerState + 0.5)
	-- nitrogen cap: never more N than PF's own auto mode would apply here (the product carries N along with P / K, and
	-- surplus N is penalised hard); at the N target the rate drops to 0 and the sprayer stops spreading
	if nitrogenNeedStates ~= nil then
		states = math.min(states, nitrogenNeedStates)
	end
	return states
end

-- Liters/ha that carry the nitrogen PF's auto mode still wants at x, z (target - level of the N map, never negative);
-- nil when PF has no N target there (no fruit / soil data). Used for the HUD estimate; the spreading itself caps the states
-- in getAutoNitrogenStates with PF's own result.
function VtszNutrients:getNitrogenNeedLiters(fillTypeIndex, x, z, fruitTypeIndex)
	local nitrogenMap = pf.nitrogenMap
	local soilTypeIndex = pf.soilMap ~= nil and pf.soilMap:getTypeIndexAtWorldPos(x, z) or nil
	if nitrogenMap == nil or soilTypeIndex == nil or soilTypeIndex <= 0 then
		return nil
	end
	if fruitTypeIndex == nil or fruitTypeIndex == FruitType.UNKNOWN then
		fruitTypeIndex = FSDensityMapUtil.getFruitTypeIndexAtWorldPos(x, z)
	end
	local target = nitrogenMap:getNitrogenTargetLevel(fruitTypeIndex, soilTypeIndex)
	local level = nitrogenMap:getLevelAtWorldPos(x, z)
	if target == nil or level == nil then
		return nil
	end
	local litersPerKgN = nitrogenMap:getFertilizerUsageByNitrogenAmount(1, fillTypeIndex)
	return math.max(target - level, 0) * nitrogenMap.amountPerState * (litersPerKgN or 0)
end

-- l/ha PF's rate gives right now with the implement off (PF computes lastLitersPerHectar only while spraying): manual =
-- the chosen N states, auto = the N deficit under the machine, else PF's default state change
function VtszNutrients:getPFIdleLitersPerHa(pfSpec, fillTypeIndex)
	local nitrogenMap = pf ~= nil and pf.nitrogenMap or nil
	if nitrogenMap == nil then
		return nil
	end
	local states = pfSpec.sprayAmountManual
	if pfSpec.sprayAmountAutoMode then
		if pfSpec.nActualValue > 0 and pfSpec.nTargetValue > 0 then
			states = math.max(math.ceil(pfSpec.nTargetValue - pfSpec.nActualValue), 0)
		else
			states = nitrogenMap:getDefaultNitrogenStateChange()
		end
	end
	return (nitrogenMap:getFertilizerUsageByStateChange(states, fillTypeIndex))
end

function VtszNutrients:installAutoRateHooks()
	local nitrogenMap = pf.nitrogenMap
	if nitrogenMap == nil then
		logError("PF nitrogenMap not found, automatic P/K rate not installed")
		return
	end
	local original = nitrogenMap.getNitrogenApplicationRate
	nitrogenMap.getNitrogenApplicationRate = function(map, currentLevel, fruitTypeIndex, soilTypeIndex, sprayTypeIndex)
		local context = VtszNutrients.autoContext
		if context ~= nil then
			-- PF's own N need (states, may be negative above target); found = it came from an N target, not 0 for lack of data
			local needStates, found = original(map, currentLevel, fruitTypeIndex, soilTypeIndex, sprayTypeIndex)
			local cap = (found or (needStates or 0) > 0) and math.max(needStates or 0, 0) or nil
			local ok, states = pcall(VtszNutrients.getAutoNitrogenStates, VtszNutrients, context, sprayTypeIndex, fruitTypeIndex, cap)
			if ok and states ~= nil then
				return states, true
			elseif not ok and not VtszNutrients.autoErrorLogged then
				VtszNutrients.autoErrorLogged = true
				logError("automatic rate failed: %s", tostring(states))
			end
		end
		return original(map, currentLevel, fruitTypeIndex, soilTypeIndex, sprayTypeIndex)
	end
end

-- Soil pH at world position x, z from PF's pH map (also where the soil sampler has not uncovered it: the soil has a pH
-- either way). nil when PF has no pH map or no value is stored.
function VtszNutrients:getPhAtWorldPos(x, z)
	local pHMap = pf.pHMap
	if pHMap == nil or pHMap.bitVectorMap == nil or x == nil then
		return nil
	end
	local terrainSize = g_currentMission.terrainSize
	local lx = MathUtil.round((x + terrainSize * 0.5) / terrainSize * pHMap.sizeX + 0.5) - 1
	local lz = MathUtil.round((z + terrainSize * 0.5) / terrainSize * pHMap.sizeY + 0.5) - 1
	local level = getBitVectorMapPoint(pHMap.bitVectorMap, lx, lz, pHMap.firstChannel, pHMap.numChannels)
	local value = pHMap:getPhValueFromInternalValue(level)
	if value == nil or value <= 0 then
		return nil
	end
	return value
end

-- Soil type, fruit type and pH at x, z, shared by the three field info rows (P, K, OM ask the same position every frame).
-- Valid for one tick: the key is x, z and g_time. No table: the values live in fields on VtszNutrients.
function VtszNutrients:getFieldLookups(soilMap, x, z)
	if self.lookupTime ~= g_time or self.lookupX ~= x or self.lookupZ ~= z then
		self.lookupTime, self.lookupX, self.lookupZ = g_time, x, z
		self.lookupSoil = soilMap:getTypeIndexAtWorldPos(x, z)
		self.lookupFruit = FSDensityMapUtil.getFruitTypeIndexAtWorldPos(x, z)
		self.lookupPh = self:getPhAtWorldPos(x, z)
	end
	return self.lookupSoil, self.lookupFruit, self.lookupPh
end

-- pH under the machine of the current harvest step (the vehicle PF passed to updateLatestFactors just before).
function VtszNutrients:getHarvestPh()
	local vehicle = self.harvestVehicle
	if vehicle == nil or vehicle.rootNode == nil then
		return nil
	end
	local x, _, z = getWorldTranslation(vehicle.rootNode)
	return self:getPhAtWorldPos(x, z)
end

-- Forage harvest = forage harvester header (PF passes the cutter's allowsForageGrowthState as useMinForageState) or a mower step
-- (flag set by the wrappers in installHarvestHooks; PF passes MaizePlus state as useMinForageState there).
function VtszNutrients:onHarvestUpdate(filter, fruitTypeIndex, shape, useMinForageState, strawChopperActive, yieldScale, ph)
	self.lastYieldScale = yieldScale
	self.lastPh = ph
	local forageHarvest = useMinForageState == true or self.harvestIsMower == true
	for _, map in ipairs(self.maps) do
		local ok, result = pcall(map.harvestUpdate, map, filter, fruitTypeIndex, shape, forageHarvest, strawChopperActive, yieldScale, ph)
		if not ok then
			if not self.harvestErrorLogged then
				self.harvestErrorLogged = true
				logError("harvestUpdate %s failed: %s", map.nutrientId, tostring(result))
			end
		elseif result then
			self.hasFreshFactors = true
		end
	end
end

function VtszNutrients:collectFactors(vehicle)
	if not self.hasFreshFactors then
		return
	end
	self.hasFreshFactors = false
	if vehicle == nil then
		return
	end
	vehicle.vtszFactors = vehicle.vtszFactors or {}
	local parts = {}
	for _, map in ipairs(self.maps) do
		local factor, actual, target = map:popLastFactor()
		if factor ~= nil then
			vehicle.vtszFactors[map.nutrientId] = factor
			table.insert(parts, string.format("%s actual=%.2f target=%.2f factor=%.2f", map.nutrientId, actual or 0, target or 0, factor))
		end
	end
	if self.debug and #parts > 0 then
		table.insert(parts, string.format("combined=%.3f", VtszNutrients.combineFactors(vehicle.vtszFactors)))
		table.insert(parts, string.format("pH=%s", self.lastPh ~= nil and string.format("%.2f", self.lastPh) or "n/a"))
		table.insert(parts, string.format("yieldScale=%.1f (PF multiplier %.2f, yieldPotential %.2f)", self.lastYieldScale or 1, self.lastMultiplier or 0, pf.harvestExtension.replaceYieldPotential or 0))
		self:debugThrottled("harvest " .. table.concat(parts, " | "))
	end
end

-- Combined yield factor from per-nutrient factors { [nutrientId] = factor }.
-- Law of the minimum for the mineral nutrients (P, K): the scarcest one limits yield, the others do not stack.
-- OM is no limiting nutrient (structure, water), so its factor multiplies. Result is in 0..1.
function VtszNutrients.combineFactors(factors)
	local minimum, om = 1, 1
	for id, factor in pairs(factors) do
		factor = math.min(factor, 1)
		if id == "OM" then
			om = factor
		else
			minimum = math.min(minimum, factor)
		end
	end
	return minimum * om
end

function VtszNutrients:getVehicleFactor(vehicle)
	return VtszNutrients.combineFactors(vehicle ~= nil and vehicle.vtszFactors or {})
end

function VtszNutrients:installHarvestHooks()
	local nitrogenMap = pf.nitrogenMap
	local harvestExtension = pf.harvestExtension
	if nitrogenMap == nil or harvestExtension == nil then
		logError("PF nitrogenMap / harvestExtension not found, harvest hooks not installed")
		return
	end

	-- PF calls nitrogenMap:harvestUpdate with the filter of the harvested pixels: run ours with the same filter.
	local originalHarvestUpdate = nitrogenMap.harvestUpdate
	nitrogenMap.harvestUpdate = function(map, filter, fruitTypeIndex, shape, useMinForageState, strawChopperActive)
		local result = originalHarvestUpdate(map, filter, fruitTypeIndex, shape, useMinForageState, strawChopperActive)
		VtszNutrients:onHarvestUpdate(filter, fruitTypeIndex, shape, useMinForageState, strawChopperActive, VtszNutrients:getYieldScale(harvestExtension), VtszNutrients:getHarvestPh())
		return result
	end

	-- Mower steps: the harvest hooks run synchronously inside these calls, so a flag around them marks a mower harvest.
	for _, name in ipairs({ "preProcessMowerArea", "postProcessMowerArea" }) do
		local original = harvestExtension[name]
		if original ~= nil then
			harvestExtension[name] = function(extension, ...)
				VtszNutrients.harvestIsMower = true
				local ok, a, b, c = pcall(original, extension, ...)
				VtszNutrients.harvestIsMower = false
				if not ok then
					error(a, 0)
				end
				return a, b, c
			end
		end
	end

	-- PF refreshes its factors per vehicle here; collect ours at the same moment.
	local originalUpdateLatestFactors = harvestExtension.updateLatestFactors
	harvestExtension.updateLatestFactors = function(extension, pfModule, vehicle, requiresPHFactorUpdate, requiresNFactorUpdate)
		VtszNutrients.harvestVehicle = vehicle
		local nFactor, regularNFactor, yieldPotential, pHFactor, regularPHFactor = originalUpdateLatestFactors(extension, pfModule, vehicle, requiresPHFactorUpdate, requiresNFactorUpdate)
		VtszNutrients:collectFactors(vehicle)
		extension.vtszFactor = VtszNutrients:getVehicleFactor(vehicle)
		return nFactor, regularNFactor, yieldPotential, pHFactor, regularPHFactor
	end

	-- Final multiplier: PF result, lowered by our factors (each <= 1). The "regular" reference stays PF's.
	local originalGetLastMultipliers = harvestExtension.getLastMultipliers
	harvestExtension.getLastMultipliers = function(extension, ...)
		local regularMultiplier, newMultiplier = originalGetLastMultipliers(extension, ...)
		if extension.lastPlowFactor ~= nil then
			newMultiplier = newMultiplier * (extension.vtszFactor or 1)
		end
		return regularMultiplier, newMultiplier
	end

	-- Field info "expected yield": PF multiplies its seed rate factor into the result. Fold ours in the same way.
	-- Must replace the instance function before PF's collectFieldInfos stores it (HUD init, after script load).
	local originalYieldChange = nitrogenMap.getFieldInfoYieldChange
	local fieldFactors = {} -- reused every call: the same keys are overwritten, nothing else is stored in it
	nitrogenMap.getFieldInfoYieldChange = function(map, fieldInfo)
		local factor, proportion, yieldPotential, yieldPotentialToHa, yieldPotentialFactor, yieldPotentialFactorBest = originalYieldChange(map, fieldInfo)
		for _, vtszMap in ipairs(VtszNutrients.maps) do
			fieldFactors[vtszMap.nutrientId] = vtszMap.fieldYieldFactor or 1
		end
		local vtszFactor = VtszNutrients.combineFactors(fieldFactors)
		if yieldPotential ~= nil then
			yieldPotentialFactor = (yieldPotentialFactor or 1) * vtszFactor
		end
		return factor, proportion, yieldPotential, yieldPotentialToHa, yieldPotentialFactor, yieldPotentialFactorBest
	end
	if VtszProfiler ~= nil then -- PF stores this function by reference, so it is probed here (counts only while vtszPerf runs)
		nitrogenMap.getFieldInfoYieldChange = VtszProfiler.probe("Perf4 field info yield hook", nitrogenMap.getFieldInfoYieldChange)
	end
end

----------------------------------------------------------------------------------------------------
-- Catch crops: OM when a catch crop is destroyed (ploughed in) or mulched. Uses PF's pre/post destroy calls
-- and a wrap of FSDensityMapUtil.updateMulcherArea (PF does not wrap the mulcher).
----------------------------------------------------------------------------------------------------

function VtszNutrients:getCatchCropFruitTypes()
	if self.catchCropFruitTypes == nil then
		self.catchCropFruitTypes = {}
		local names = VtszConfig.catchCropNames
		if VtszConfig.mapCoverCropNames ~= nil and #VtszConfig.mapCoverCropNames > 0 then
			names = VtszConfig.mapCoverCropNames
		end
		for _, name in ipairs(names) do
			local fruitType = g_fruitTypeManager:getFruitTypeByName(name)
			if fruitType ~= nil and fruitType.terrainDataPlaneId ~= nil then
				table.insert(self.catchCropFruitTypes, fruitType)
			else
				Logging.devInfo("[VTSZ-NUT] catch crop fruit type '%s' does not exist on this map, ignored", tostring(name))
			end
		end
	end
	return self.catchCropFruitTypes
end

-- Gain differs per catch crop, so each fruit type has its own 2 bit mask: 1 = present before, 2 = still present after.
function VtszNutrients:getDestroyData()
	local data = self.destroyData
	if data == nil then
		data = { masks = {}, activeFruitTypes = {} }
		self.destroyData = data
	end
	return data
end

function VtszNutrients:getDestroyMask(fruitType)
	local data = self:getDestroyData()
	local mask = data.masks[fruitType.index]
	if mask == nil then
		local size = self:getMapSize()
		local maskMap = createBitVectorMap("vtszDestroyMask" .. fruitType.name)
		loadBitVectorMapNew(maskMap, size, size, 2, false)
		mask = {}
		mask.bitVectorMap = maskMap
		mask.modifier = DensityMapModifier.new(maskMap, 0, 2, g_terrainNode)
		mask.modifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)
		mask.fruitFilter = DensityMapFilter.new(mask.modifier)
		-- residue already mulched is not a living catch crop: it never counts again (mulcher passes, later plough)
		mask.notMulchedFilter = DensityMapFilter.new(fruitType.terrainDataPlaneId, fruitType.startStateChannel, fruitType.numStateChannels)
		mask.notMulchedFilter:setValueCompareParams(DensityValueCompareType.NOTEQUAL, fruitType.mulchedState or 0)
		mask.equalOne = DensityMapFilter.new(maskMap, 0, 2)
		mask.equalOne:setValueCompareParams(DensityValueCompareType.EQUAL, 1)
		data.masks[fruitType.index] = mask
	end
	return mask
end

-- fruit types of the catch crop list that give any map a gain when destroyed
function VtszNutrients:getGainCatchCrops()
	if self.gainCatchCrops == nil then
		self.gainCatchCrops = {}
		for _, fruitType in ipairs(self:getCatchCropFruitTypes()) do
			for _, map in ipairs(self.maps) do
				if map:getDestroyGain(fruitType.index) > 0 then
					table.insert(self.gainCatchCrops, fruitType)
					break
				end
			end
		end
	end
	return self.gainCatchCrops
end

function VtszNutrients:preDestroy(sx, sz, wx, wz, hx, hz)
	local data = self:getDestroyData()
	data.activeFruitTypes = {}
	for _, fruitType in ipairs(self:getGainCatchCrops()) do
		local mask = self:getDestroyMask(fruitType)
		mask.modifier:setParallelogramWorldCoords(sx, sz, wx, wz, hx, hz, DensityCoordType.POINT_POINT_POINT)
		mask.modifier:executeSet(0)
		mask.fruitFilter:resetDensityMapAndChannels(fruitType.terrainDataPlaneId, fruitType.startStateChannel, fruitType.numStateChannels)
		mask.fruitFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 2, fruitType.numGrowthStates)
		-- only living catch crop counts: pixels already in the mulched state are NOT in the before mask, otherwise every mulcher frame
		-- (the work area is crossed many times per pass) would count them again as "destroyed"
		local _, numPixels = mask.modifier:executeSetWithStats(1, mask.fruitFilter, mask.notMulchedFilter)
		if numPixels ~= nil and numPixels > 0 then
			table.insert(data.activeFruitTypes, fruitType)
		end
	end
end

function VtszNutrients:postDestroy(sx, sz, wx, wz, hx, hz)
	local data = self.destroyData
	if data == nil or #data.activeFruitTypes == 0 then
		return
	end
	for _, fruitType in ipairs(data.activeFruitTypes) do
		local mask = self:getDestroyMask(fruitType)
		mask.modifier:setParallelogramWorldCoords(sx, sz, wx, wz, hx, hz, DensityCoordType.POINT_POINT_POINT)
		mask.fruitFilter:resetDensityMapAndChannels(fruitType.terrainDataPlaneId, fruitType.startStateChannel, fruitType.numStateChannels)
		mask.fruitFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 2, fruitType.numGrowthStates)
		mask.modifier:executeSet(2, mask.fruitFilter, mask.notMulchedFilter)
		-- mask == 1: had living catch crop before, none after (removed, or turned into the mulched state) = destroyed
		for _, map in ipairs(self.maps) do
			local gain = map:getDestroyGain(fruitType.index)
			if gain > 0 then
				map:addUnitsFromMask(sx, sz, wx, wz, hx, hz, gain * VtszConfig.inputScale, mask.equalOne)
			end
		end
	end
	data.activeFruitTypes = {}
end

function VtszNutrients:installDestroyHooks()
	local nitrogenMap = pf.nitrogenMap
	if nitrogenMap == nil then
		return
	end
	local originalPre = nitrogenMap.updateDestroyCommonArea
	nitrogenMap.updateDestroyCommonArea = function(map, sx, sz, wx, wz, hx, hz)
		local ok, err = pcall(VtszNutrients.preDestroy, VtszNutrients, sx, sz, wx, wz, hx, hz)
		if not ok and not VtszNutrients.destroyErrorLogged then
			VtszNutrients.destroyErrorLogged = true
			logError("preDestroy failed: %s", tostring(err))
		end
		return originalPre(map, sx, sz, wx, wz, hx, hz)
	end
	local originalPost = nitrogenMap.postUpdateDestroyCommonArea
	nitrogenMap.postUpdateDestroyCommonArea = function(map, sx, sz, wx, wz, hx, hz)
		local result = originalPost(map, sx, sz, wx, wz, hx, hz)
		local ok, err = pcall(VtszNutrients.postDestroy, VtszNutrients, sx, sz, wx, wz, hx, hz)
		if not ok and not VtszNutrients.destroyErrorLogged then
			VtszNutrients.destroyErrorLogged = true
			logError("postDestroy failed: %s", tostring(err))
		end
		return result
	end
	VtszNutrients:installMulcherHook()
end

-- The mulcher never calls updateDestroyCommonArea: it sets the crop to desc.mulchedState (0 = removed).
-- Same pre/post mask code; pixels already in the mulched state are excluded from the mask, so repeated passes
-- and a later plough add nothing. Server only (clients also run updateMulcherArea near the vehicle).
function VtszNutrients:installMulcherHook()
	if g_server == nil or FSDensityMapUtil == nil or FSDensityMapUtil.updateMulcherArea == nil then
		return
	end
	local original = FSDensityMapUtil.updateMulcherArea
	FSDensityMapUtil.updateMulcherArea = function(sx, sz, wx, wz, hx, hz)
		local ok, err = pcall(VtszNutrients.preDestroy, VtszNutrients, sx, sz, wx, wz, hx, hz)
		if not ok and not VtszNutrients.destroyErrorLogged then
			VtszNutrients.destroyErrorLogged = true
			logError("preDestroy (mulcher) failed: %s", tostring(err))
		end
		local changeArea, changeTotalArea = original(sx, sz, wx, wz, hx, hz)
		ok, err = pcall(VtszNutrients.postDestroy, VtszNutrients, sx, sz, wx, wz, hx, hz)
		if not ok and not VtszNutrients.destroyErrorLogged then
			VtszNutrients.destroyErrorLogged = true
			logError("postDestroy (mulcher) failed: %s", tostring(err))
		end
		return changeArea, changeTotalArea
	end
	VtszNutrients.mulcherHookOriginal = original
end

----------------------------------------------------------------------------------------------------
-- Console + lifecycle
----------------------------------------------------------------------------------------------------

function VtszNutrients:consoleDebug(state)
	if state == "on" then
		self.debug = true
	elseif state == "off" then
		self.debug = false
	else
		self.debug = not self.debug
	end
	return "vtszNutrientDebug " .. (self.debug and "on" or "off")
end

-- vtszNutrientSet <fieldId> <P|K|OM> <distance to the soil type target: kg/ha for P and K (-120 = 120 below), %-points for OM (-0.5)>
function VtszNutrients:consoleSet(fieldId, nutrientId, value)
	value = tonumber(value)
	if fieldId == nil or nutrientId == nil or value == nil then
		return "Usage: vtszNutrientSet <fieldId> <P|K|OM> <distance to the target: kg/ha for P and K (-120 = 120 below), %-points for OM (-0.5 = 0.5 below)>"
	end
	nutrientId = nutrientId:upper()
	for _, map in ipairs(self.maps) do
		if map.nutrientId == nutrientId then
			local ok, level = map:setUnitsOnField(fieldId, value)
			if ok then
				return string.format("%s of field %s set to %s (level %d)", nutrientId, tostring(fieldId), map:formatUnits(map:levelToUnits(level)), level)
			end
			return "Field not found: " .. tostring(fieldId)
		end
	end
	return "Unknown nutrient: " .. nutrientId
end

-- Server: runs an admin command that a client sent (VtszAdminCommandEvent). The event already checked the admin.
function VtszNutrients:runAdminCommand(command, a1, a2, a3)
	if command == "set" then
		return self:consoleSet(a1, a2, a3)
	elseif command == "debug" then
		return self:consoleDebug(a1)
	end
	return "Unknown command: " .. tostring(command)
end

-- OM mineralisation: one step per game period (server only). Period 1 = March (northern hemisphere, Szalok).
function VtszNutrients:onPeriodChanged(period)
	if g_server == nil or period == nil then
		return
	end
	for _, map in ipairs(self.maps) do
		local okL, resultL = pcall(map.applyLeaching, map, period)
		if not okL then
			if not self.leachingErrorLogged then
				self.leachingErrorLogged = true
				logError("leaching %s failed: %s", map.nutrientId, tostring(resultL))
			end
		elseif resultL then
			logInfo("%s leaching period %d: %s", map.nutrientId, period, tostring(map.lastLeaching))
		end
		local ok, result = pcall(map.applyMineralisation, map, period)
		if not ok then
			if not self.mineralisationErrorLogged then
				self.mineralisationErrorLogged = true
				logError("mineralisation %s failed: %s", map.nutrientId, tostring(result))
			end
		elseif result then
			logInfo("%s mineralisation period %d: %s", map.nutrientId, period, tostring(map.lastMineralisation))
			local okN, resultN = pcall(map.applyNitrogenRelease, map, period)
			if not okN then
				if not self.nitrogenReleaseErrorLogged then
					self.nitrogenReleaseErrorLogged = true
					logError("nitrogen release %s failed: %s", map.nutrientId, tostring(resultN))
				end
			elseif resultN then
				logInfo("%s nitrogen release into the N map: %s", map.nutrientId, tostring(map.lastNitrogenRelease))
			end
		end
	end
end

function VtszNutrients:update(dt)
	if pf ~= nil and g_client ~= nil and VtszMinimap ~= nil then
		VtszMinimap:update(dt)
	end
end

-- Solid products: spreader hopper (fill volume) shows the base FERTILIZER fill plane layer.
local SOLID_PRODUCTS = {"PETISO27", "KARBAMID46", "MAP11_52", "TSP46", "SSP18", "KALISO60", "PATENTKALI", "NPK15_15_15", "NPK8_24_24"}

function VtszNutrients:shareFertilizerFillPlane()
	local base = g_fillTypeManager:getFillTypeByName("FERTILIZER")
	if base == nil or base.textureArrayIndex == nil then
		return
	end
	for _, name in ipairs(SOLID_PRODUCTS) do
		local fillType = g_fillTypeManager:getFillTypeByName(name)
		if fillType ~= nil then
			fillType.textureArrayIndex = base.textureArrayIndex
		end
	end
end

-- Fill layers are built before vehicles load their fill volumes, so alias right after construction.
FillTypeManager.constructTerrainFillLayers = Utils.appendedFunction(FillTypeManager.constructTerrainFillLayers, function()
	if g_modIsLoaded[modName] then
		VtszNutrients:shareFertilizerFillPlane()
	end
end)

function VtszNutrients:loadMap(filename)
	if not g_modIsLoaded[modName] or pf == nil then
		return
	end
	if VtszProfiler ~= nil then
		VtszProfiler:register()
	end
	if g_server ~= nil then
		addConsoleCommand("vtszNutrientDebug", "Logs spreading and harvest values of the P, K, OM maps", "consoleDebug", self, "[on|off]")
		addConsoleCommand("vtszNutrientSet", "Sets P, K (kg/ha) or OM (%-points) as distance to the soil target on a field", "consoleSet", self, "fieldId; P|K|OM; value")
		if VtszSelfTest ~= nil then
			local ok, err = pcall(VtszSelfTest.register, VtszSelfTest)
			if not ok then
				logError("self test command not registered: %s", tostring(err))
			end
		end
		g_messageCenter:subscribe(MessageType.PERIOD_CHANGED, self.onPeriodChanged, self)
	elseif g_client ~= nil then
		-- multiplayer client: admin commands go to the server
		self.clientCommands = true
		addConsoleCommand("vtszNutrientDebug", "Admin: logs spreading and harvest values of the P, K, OM maps (on the server)", "consoleSendDebug", self, "[on|off]")
		addConsoleCommand("vtszNutrientSet", "Admin: sets P, K (kg/ha) or OM (distance to the soil target in %-points) on a field", "consoleSendSet", self, "fieldId; P|K|OM; value")
	end
end

function VtszNutrients:consoleSendDebug(state)
	return VtszAdminCommandEvent.sendRequest("debug", state or "")
end

function VtszNutrients:consoleSendSet(fieldId, nutrientId, value)
	if fieldId == nil or nutrientId == nil or value == nil then
		return "Usage: vtszNutrientSet <fieldId> <P|K|OM> <distance to the target: kg/ha for P and K (-120 = 120 below), %-points for OM (-0.5 = 0.5 below)>"
	end
	return VtszAdminCommandEvent.sendRequest("set", fieldId, nutrientId, value)
end

function VtszNutrients:deleteMap()
	if VtszProfiler ~= nil then
		pcall(VtszProfiler.unregister, VtszProfiler)
	end
	if self.clientCommands then
		self.clientCommands = nil
		removeConsoleCommand("vtszNutrientDebug")
		removeConsoleCommand("vtszNutrientSet")
	end
	if g_server ~= nil then
		g_messageCenter:unsubscribe(MessageType.PERIOD_CHANGED, self)
		removeConsoleCommand("vtszNutrientDebug")
		removeConsoleCommand("vtszNutrientSet")
		if VtszSelfTest ~= nil then
			pcall(VtszSelfTest.unregister, VtszSelfTest)
		end
	end
	if self.lockData ~= nil then
		delete(self.lockData.bitVectorMap)
		delete(self.lockData.passMap)
		if self.lockData.ownsProductMap then
			delete(self.lockData.productMap)
		end
		self.lockData = nil
	end
	self.productMap = nil -- deleted by its owner map
	if self.destroyData ~= nil then
		for _, mask in pairs(self.destroyData.masks) do
			delete(mask.bitVectorMap)
		end
		self.destroyData = nil
	end
	self.catchCropFruitTypes = nil
	self.gainCatchCrops = nil
end

if pf ~= nil then
	VtszNutrients:installHarvestHooks()
	VtszNutrients:installDestroyHooks()
	VtszNutrients:installAutoRateHooks()
	addModEventListener(VtszNutrients)
end
