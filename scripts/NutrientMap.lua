-- NutrientMap: one Precision Farming ValueMap for P2O5, K2O or organic matter.
-- Modeled on PF's NitrogenMap / PHMap (sources: README). Registered into g_precisionFarming.valueMaps by VtszNutrients.lua.

local pfEnv = _G["FS25_precisionFarming"]

NutrientMap = {}
NutrientMap.MOD_NAME = g_currentModName
NutrientMap.MOD_DIR = g_currentModDirectory
NutrientMap.NUM_BANDS = 8 -- default of the numBands attribute (legend colour bands)
NutrientMap.NOISE_BITS = 2
NutrientMap.YIELD_SCALE_STEP = 0.1
local NutrientMap_mt = Class(NutrientMap, pfEnv.ValueMap)

local function logInfo(fmt, ...)
	Logging.info("[VTSZ-NUT] " .. fmt, ...)
end

local function logWarning(fmt, ...)
	Logging.warning("[VTSZ-NUT] " .. fmt, ...)
end

-- |levels| (float) -> whole levels, full noise bands (0..3, a band = 1/4 of the pixels) and the leftover chance (0..1) of one more band
local function splitLevelsParts(levels)
	local a = math.abs(levels)
	local whole = math.floor(a)
	local quarters = (a - whole) * 4
	local bands = math.floor(quarters)
	return whole, bands, quarters - bands
end

-- whole levels and noise bands for one application. The leftover below one band is rounded at random, so small changes
-- (e.g. 0.009 % = 0.045 level) average out correctly over many applications.
local function splitLevels(levels)
	local whole, bands, chance = splitLevelsParts(levels)
	if chance > 0 and math.random() < chance then
		bands = bands + 1
	end
	if bands >= 4 then
		whole = whole + 1
		bands = 0
	end
	return whole, bands
end

NutrientMap.splitLevels = splitLevels -- read by VtszSelfTest

-- noise value ranges covering `bands` of the 4 noise values starting at `offset` (0..3), wrapping around
local function buildNoiseRanges(offset, bands)
	local last = offset + bands - 1
	if last <= 3 then
		return { { offset, last } }
	end
	return { { offset, 3 }, { 0, last - 4 } }
end

-- precomputed once: NOISE_RANGES[offset][bands] (offset 0..3, bands 1..3). Shared tables, read-only: no garbage per call.
local NOISE_RANGES = {}
for offset = 0, 3 do
	NOISE_RANGES[offset] = {}
	for bands = 1, 3 do
		NOISE_RANGES[offset][bands] = buildNoiseRanges(offset, bands)
	end
end

local function getNoiseRanges(offset, bands)
	local byOffset = NOISE_RANGES[offset]
	return byOffset ~= nil and byOffset[bands] or buildNoiseRanges(offset, bands)
end

function NutrientMap.new(pfModule, nutrientId, mapName)
	local self = pfEnv.ValueMap.new(pfModule, NutrientMap_mt)
	self.nutrientId = nutrientId
	self.name = mapName
	self.id = "VTSZ_" .. nutrientId
	self.label = "vtsz_map_" .. nutrientId
	self.firstChannel = 0
	self.numChannels = 5
	self.maxValue = 31
	self.step = 1
	self.unitFormat = "%d"
	self.legendMax = 100
	self.legendMin = 0
	self.surplusColors = false
	self.surplusFrom = 0
	self.numBands = NutrientMap.NUM_BANDS
	self.strawChopperGain = 0 -- default for requirement.strawGain
	self.catchCropGain = 0 -- default for requirement.destroyGain
	self.initialValues = {}
	self.targets = {}
	self.yieldKeys = {}
	self.fruitRequirementsByName = {}
	self.fruitRequirements = {}
	self.fillTypeConfigs = {}
	self.fillTypeContents = {}
	self.lastFactor = nil
	self.lastActual = nil
	self.lastTarget = nil
	self.phEfficiencyKeys = {} -- { ph, value } sorted by ph: share of the map content that plants can use at this soil pH
	self.lastPhEfficiency = nil
	self.targetRemovalShare = 0 -- share of the crop's removal added to the soil type target (crop dependent sufficiency level), 0 = none
	self.yieldScaling = 1 -- how strongly the harvest change follows the yield (1 = fully, 0 = fixed per harvest)
	self.levelOffset = 0 -- > 0: the stored level is relative to the soil type target: units = (level - levelOffset) x step (OM, P, K)
	self.relative = false
	self.maxUnits = nil -- optional soft cap in map units (spreading never raises a pixel above it), nil = hard limit only
	self.timeScale = 1 -- multiplier of every change of the stock (spreading, harvest, catch crop, mineralisation): game years per modelled year
	self.nitrogenPerPercent = 0 -- kg N/ha per year released into PF's N map per 1 % of OM stock, 0 = none
	self.mineralisationRate = 0 -- fraction of the target lost per year, 0 = none
	self.mineralisationWeights = { 1 / 12, 1 / 12, 1 / 12, 1 / 12, 1 / 12, 1 / 12, 1 / 12, 1 / 12, 1 / 12, 1 / 12, 1 / 12, 1 / 12 }
	self.lastMineralisation = nil
	self.leachingRates = {} -- [soilTypeIndex] = map units lost per year above the soil type target, empty = none
	self.leachingWeights = { 0.16, 0.12, 0.08, 0.06, 0.03, 0.02, 0.03, 0.06, 0.10, 0.11, 0.11, 0.12 }
	self.lastLeaching = nil
	return self
end

function NutrientMap:initialize()
	NutrientMap:superClass().initialize(self)
	self.sprayData = nil
	self.harvestData = nil
	self.destroyData = nil
	self.mineralisationData = nil
	self.nitrogenReleaseData = nil
	self.leachingData = nil
end

function NutrientMap:delete()
	NutrientMap:superClass().delete(self)
end

----------------------------------------------------------------------------------------------------
-- Config
----------------------------------------------------------------------------------------------------

function NutrientMap:loadConfig(xmlFile, rootKey)
	if hasXMLProperty(xmlFile, rootKey .. ".balance") then
		VtszConfig.inputScale = getXMLFloat(xmlFile, rootKey .. ".balance#inputScale") or VtszConfig.inputScale
		VtszConfig.removalScale = getXMLFloat(xmlFile, rootKey .. ".balance#removalScale") or VtszConfig.removalScale
		VtszConfig.yieldReference = getXMLFloat(xmlFile, rootKey .. ".balance#yieldReference") or VtszConfig.yieldReference
	end
	if hasXMLProperty(xmlFile, rootKey .. ".autoRate") then
		VtszConfig.autoRate.maxLitersPerHa = getXMLFloat(xmlFile, rootKey .. ".autoRate#maxLitersPerHa") or VtszConfig.autoRate.maxLitersPerHa
	end
	if hasXMLProperty(xmlFile, rootKey .. ".baseFertilizer") then
		VtszConfig.baseFertilizer = Utils.getNoNil(getXMLBool(xmlFile, rootKey .. ".baseFertilizer#enabled"), VtszConfig.baseFertilizer)
	end
	local catchCrops = getXMLString(xmlFile, rootKey .. ".catchCrops#fruitTypes")
	if catchCrops ~= nil then
		VtszConfig.catchCropNames = catchCrops:split(" ")
	end
	local m = 0
	while true do
		local key = string.format("%s.minimap.product(%d)", rootKey, m)
		if not hasXMLProperty(xmlFile, key) then
			break
		end
		local name = getXMLString(xmlFile, key .. "#fillType")
		local mapId = getXMLString(xmlFile, key .. "#map")
		if name ~= nil and mapId ~= nil then
			VtszConfig.minimapMaps[name:upper()] = mapId:upper()
		end
		m = m + 1
	end
	local b = 0
	while true do
		local key = string.format("%s.autoBaseDefault.product(%d)", rootKey, b)
		if not hasXMLProperty(xmlFile, key) then
			break
		end
		local name = getXMLString(xmlFile, key .. "#fillType")
		local base = getXMLString(xmlFile, key .. "#base")
		if name ~= nil and base ~= nil then
			VtszConfig.autoBaseDefaults[name:upper()] = base:upper()
		end
		b = b + 1
	end
	local r = 0
	while true do
		local key = string.format("%s.rateControl.product(%d)", rootKey, r)
		if not hasXMLProperty(xmlFile, key) then
			break
		end
		local name = getXMLString(xmlFile, key .. "#fillType")
		if name ~= nil then
			VtszConfig.rates[name:upper()] = {
				default = getXMLInt(xmlFile, key .. "#default") or 100,
				step = getXMLInt(xmlFile, key .. "#step") or 10,
				min = getXMLInt(xmlFile, key .. "#min") or 10,
				max = getXMLInt(xmlFile, key .. "#max") or 1500,
			}
		end
		r = r + 1
	end
	local i = 0
	while true do
		local base = string.format("%s.nutrientMaps.nutrientMap(%d)", rootKey, i)
		if not hasXMLProperty(xmlFile, base) then
			break
		end
		if getXMLString(xmlFile, base .. "#id") == self.nutrientId then
			self:loadNutrientConfig(xmlFile, base)
		end
		i = i + 1
	end
end

function NutrientMap:loadNutrientConfig(xmlFile, base)
	self.numChannels = getXMLInt(xmlFile, base .. "#numChannels") or self.numChannels
	self.step = getXMLFloat(xmlFile, base .. "#step") or self.step
	self.levelOffset = math.max(getXMLInt(xmlFile, base .. "#levelOffset") or self.levelOffset, 0)
	self.relative = self.levelOffset > 0
	self.maxUnits = getXMLFloat(xmlFile, base .. "#maxUnits") or self.maxUnits
	self.unitFormat = getXMLString(xmlFile, base .. "#unitFormat") or self.unitFormat
	self.legendMax = getXMLFloat(xmlFile, base .. "#legendMax") or self.legendMax
	self.legendMin = getXMLFloat(xmlFile, base .. "#legendMin") or self.legendMin
	self.surplusColors = Utils.getNoNil(getXMLBool(xmlFile, base .. "#surplusColors"), self.surplusColors)
	self.surplusFrom = getXMLFloat(xmlFile, base .. "#surplusFrom") or self.surplusFrom
	self.numBands = math.max(2, math.floor(getXMLInt(xmlFile, base .. "#numBands") or self.numBands))
	self.strawChopperGain = getXMLFloat(xmlFile, base .. "#strawChopperGain") or self.strawChopperGain
	self.catchCropGain = getXMLFloat(xmlFile, base .. "#catchCropGain") or self.catchCropGain
	self.yieldScaling = getXMLFloat(xmlFile, base .. "#yieldScaling") or self.yieldScaling
	self.timeScale = math.max(getXMLFloat(xmlFile, base .. "#timeScale") or self.timeScale, 0)
	self.targetRemovalShare = math.max(getXMLFloat(xmlFile, base .. "#targetRemovalShare") or self.targetRemovalShare, 0)

	-- availability of the nutrient by soil pH (P: acid soil binds it to Al/Fe, calcareous soil to Ca)
	if hasXMLProperty(xmlFile, base .. ".phEfficiency") then
		self.phEfficiencyKeys = {}
		local k = 0
		while true do
			local key = string.format("%s.phEfficiency.key(%d)", base, k)
			if not hasXMLProperty(xmlFile, key) then
				break
			end
			local ph = getXMLFloat(xmlFile, key .. "#ph")
			local value = getXMLFloat(xmlFile, key .. "#value")
			if ph ~= nil and value ~= nil then
				table.insert(self.phEfficiencyKeys, { ph = ph, value = math.clamp(value, 0.3, 1) })
			end
			k = k + 1
		end
		table.sort(self.phEfficiencyKeys, function(a, b)
			return a.ph < b.ph
		end)
	end

	-- yearly loss of the map content (OM: mineralisation) as a fraction of the target, spread over the 12 game periods
	-- by `weights` (period 1 = March). Weights are normalised to sum 1.
	local mineralisationKey = base .. ".mineralisation"
	if hasXMLProperty(xmlFile, mineralisationKey) then
		self.mineralisationRate = getXMLFloat(xmlFile, mineralisationKey .. "#rate") or self.mineralisationRate
		self.nitrogenPerPercent = getXMLFloat(xmlFile, mineralisationKey .. "#nPerPercent") or self.nitrogenPerPercent
		local weights = string.getVector(getXMLString(xmlFile, mineralisationKey .. "#weights"))
		if weights ~= nil and #weights == 12 then
			self.mineralisationWeights = weights
		end
	end

	-- leaching: yearly loss in map units per soil type, only of the content at or above the soil type target, spread over the
	-- 12 game periods by `weights` (period 1 = March, wet months lose more). Weights are normalised to sum 1.
	local leachingKey = base .. ".leaching"
	if hasXMLProperty(xmlFile, leachingKey) then
		local weights = string.getVector(getXMLString(xmlFile, leachingKey .. "#weights"))
		if weights ~= nil and #weights == 12 then
			self.leachingWeights = weights
		end
		local l = 0
		while true do
			local key = string.format("%s.rate(%d)", leachingKey, l)
			if not hasXMLProperty(xmlFile, key) then
				break
			end
			local soilTypeIndex = getXMLInt(xmlFile, key .. "#soilTypeIndex")
			if soilTypeIndex ~= nil then
				self.leachingRates[soilTypeIndex] = math.max(getXMLFloat(xmlFile, key .. "#value") or 0, 0)
			end
			l = l + 1
		end
	end

	local i = 0
	while true do
		local key = string.format("%s.initialValues.initialValue(%d)", base, i)
		if not hasXMLProperty(xmlFile, key) then
			break
		end
		local soilTypeIndex = getXMLInt(xmlFile, key .. "#soilTypeIndex") or 1
		local levels = string.getVector(getXMLString(xmlFile, key .. "#levels"))
		-- relative map: `deltas` in map units (%-points from the soil type target) instead of stored levels
		local deltas = string.getVector(getXMLString(xmlFile, key .. "#deltas"))
		if deltas ~= nil and #deltas > 0 then
			levels = {}
			for j, delta in ipairs(deltas) do
				levels[j] = math.floor(delta / self.step + 0.5) + self.levelOffset
			end
		end
		if levels ~= nil and #levels > 0 then
			self.initialValues[soilTypeIndex] = levels
		end
		i = i + 1
	end

	i = 0
	while true do
		local key = string.format("%s.targets.target(%d)", base, i)
		if not hasXMLProperty(xmlFile, key) then
			break
		end
		local soilTypeIndex = getXMLInt(xmlFile, key .. "#soilTypeIndex") or 1
		self.targets[soilTypeIndex] = getXMLFloat(xmlFile, key .. "#value") or 0
		i = i + 1
	end

	if hasXMLProperty(xmlFile, base .. ".yieldMappings") then
		self.yieldKeys = {}
		i = 0
		while true do
			local key = string.format("%s.yieldMappings.yieldMapping(%d)", base, i)
			if not hasXMLProperty(xmlFile, key) then
				break
			end
			table.insert(self.yieldKeys, { difference = getXMLFloat(xmlFile, key .. "#difference") or 0, factor = getXMLFloat(xmlFile, key .. "#yieldFactor") or 1 })
			i = i + 1
		end
		table.sort(self.yieldKeys, function(a, b)
			return a.difference < b.difference
		end)
	end

	i = 0
	while true do
		local key = string.format("%s.fruitRequirements.fruitRequirement(%d)", base, i)
		if not hasXMLProperty(xmlFile, key) then
			break
		end
		local name = getXMLString(xmlFile, key .. "#fruitTypeName")
		if name ~= nil then
			name = name:upper()
			local requirement = self.fruitRequirementsByName[name] or { targetScale = 1, removal = 0, removalStraw = 0 }
			requirement.targetScale = getXMLFloat(xmlFile, key .. "#targetScale") or requirement.targetScale
			requirement.targetRemovalShare = getXMLFloat(xmlFile, key .. "#targetRemovalShare") or requirement.targetRemovalShare
			requirement.removal = getXMLFloat(xmlFile, key .. "#removal") or requirement.removal
			requirement.removalStraw = getXMLFloat(xmlFile, key .. "#removalStraw") or requirement.removalStraw
			-- forage harvest (forage harvester header or mower): crop and straw both leave the field. nil = same as a grain harvest.
			requirement.forageRemoval = getXMLFloat(xmlFile, key .. "#forageRemoval") or requirement.forageRemoval
			-- gains in map units per harvest (gain, plus strawGain with the straw chopper) and per destroy (destroyGain).
			-- nil = map default (strawChopperGain, catchCropGain)
			requirement.gain = getXMLFloat(xmlFile, key .. "#gain") or requirement.gain
			requirement.strawGain = getXMLFloat(xmlFile, key .. "#strawGain") or requirement.strawGain
			requirement.destroyGain = getXMLFloat(xmlFile, key .. "#destroyGain") or requirement.destroyGain
			self.fruitRequirementsByName[name] = requirement
		end
		i = i + 1
	end

	i = 0
	while true do
		local key = string.format("%s.fillTypes.fillType(%d)", base, i)
		if not hasXMLProperty(xmlFile, key) then
			break
		end
		local name = getXMLString(xmlFile, key .. "#name")
		if name ~= nil then
			self.fillTypeConfigs[name:upper()] = { value = getXMLFloat(xmlFile, key .. "#value") or 0 }
		end
		i = i + 1
	end
end

-- names -> engine indices, after all configs are read
function NutrientMap:resolveConfig()
	self.maxValue = 2 ^ self.numChannels - 1
	local weightSum = 0
	for _, weight in ipairs(self.mineralisationWeights) do
		weightSum = weightSum + math.max(weight, 0)
	end
	if weightSum > 0 then
		for i, weight in ipairs(self.mineralisationWeights) do
			self.mineralisationWeights[i] = math.max(weight, 0) / weightSum
		end
	end
	local leachingSum = 0
	for _, weight in ipairs(self.leachingWeights) do
		leachingSum = leachingSum + math.max(weight, 0)
	end
	if leachingSum > 0 then
		for i, weight in ipairs(self.leachingWeights) do
			self.leachingWeights[i] = math.max(weight, 0) / leachingSum
		end
	end
	self.soilTypeIndices = {}
	for soilTypeIndex, _ in pairs(self.targets) do
		table.insert(self.soilTypeIndices, soilTypeIndex)
	end
	table.sort(self.soilTypeIndices)

	self.defaultRequirement = self.fruitRequirementsByName["DEFAULT"] or { targetScale = 1, removal = 0, removalStraw = 0 }
	self.fruitRequirements = {}
	for name, requirement in pairs(self.fruitRequirementsByName) do
		if name ~= "DEFAULT" then
			local fruitType = g_fruitTypeManager:getFruitTypeByName(name)
			if fruitType ~= nil then
				self.fruitRequirements[fruitType.index] = requirement
			else
				Logging.devInfo("[VTSZ-NUT] %s: unknown fruit type '%s' in fruitRequirements, ignored", self.nutrientId, name)
			end
		end
	end

	self.fillTypeContents = {}
	for name, config in pairs(self.fillTypeConfigs) do
		local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(name)
		if name == "FERTILIZER" and not VtszConfig.baseFertilizer then
			-- base-game FERTILIZER is N only unless <baseFertilizer enabled="true"/>
		elseif fillTypeIndex ~= nil and fillTypeIndex ~= FillType.UNKNOWN then
			self.fillTypeContents[fillTypeIndex] = config
		else
			Logging.devInfo("[VTSZ-NUT] %s: fill type '%s' does not exist on this map, ignored", self.nutrientId, name)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Load / init
----------------------------------------------------------------------------------------------------

function NutrientMap:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
	self.coverMap = self.pfModule.coverMap
	self.soilMap = self.pfModule.soilMap

	local cfgFile = loadXMLFile("VtszNutrientCfg", NutrientMap.MOD_DIR .. "config/NutrientMaps.xml")
	if cfgFile ~= nil and cfgFile ~= 0 then
		self:loadConfig(cfgFile, "vtszNutrients")
		delete(cfgFile)
	else
		logWarning("%s: could not load config/NutrientMaps.xml", self.nutrientId)
	end

	local missionInfo = g_currentMission.missionInfo
	local mapXMLFilename = Utils.getFilename(missionInfo.mapXMLFilename, g_currentMission.baseDirectory)
	local mapXML = loadXMLFile("VtszMapXML", mapXMLFilename)
	if mapXML ~= nil and mapXML ~= 0 then
		if hasXMLProperty(mapXML, "map.vtszNutrients") then
			self:loadConfig(mapXML, "map.vtszNutrients")
		end
		if self.nutrientId == "P" then
			VtszConfig.mapCoverCropNames = {}
			local i = 0
			while true do
				local fruitKey = string.format("map.precisionFarming.subsidies.coverCropBonus.fruitType(%d)", i)
				if not hasXMLProperty(mapXML, fruitKey) then
					break
				end
				local name = getXMLString(mapXML, fruitKey .. "#name")
				if name ~= nil then
					table.insert(VtszConfig.mapCoverCropNames, name)
				end
				i = i + 1
			end
		end
		delete(mapXML)
	end
	self:resolveConfig()

	-- size follows PF's soil map (2048 with FS25_0_TRPFConfigurator)
	local size = self.soilMap.sizeX
	if size == nil and self.soilMap.bitVectorMap ~= nil then
		size = getBitVectorMapSize(self.soilMap.bitVectorMap)
	end
	size = size or 1024
	if size ~= 2048 then
		logWarning("%s: soil map size is %d (expected 2048 with FS25_0_TRPFConfigurator), using %d", self.nutrientId, size, size)
	end
	self.sizeX = size
	self.sizeY = size

	-- a different bit depth gets its own file, so an older save with another depth is ignored (map starts from initial values)
	local fileName = string.format("vtsz_%sMap%s.grle", self.nutrientId:lower(), self.numChannels == 5 and "" or tostring(self.numChannels))
	local mapName = "vtsz" .. self.nutrientId .. "Map"
	self.bitVectorMap, self.isNewMap = self:loadSavedBitVectorMap(mapName, fileName, self.numChannels, size)
	local loadedSize = getBitVectorMapSize(self.bitVectorMap)
	if loadedSize ~= size then
		logWarning("%s: saved map is %s x %s, expected %d, rebuilding from initial values", self.nutrientId, tostring(loadedSize), tostring(loadedSize), size)
		delete(self.bitVectorMap)
		self.bitVectorMap = createBitVectorMap(mapName)
		loadBitVectorMapNew(self.bitVectorMap, size, size, self.numChannels, false)
		self.isNewMap = true
	end
	self:addBitVectorMapToSync(self.bitVectorMap)
	self:addBitVectorMapToSave(self.bitVectorMap, fileName)
	self:addBitVectorMapToDelete(self.bitVectorMap)
	if VtszNutrients.maps[1] == self then
		VtszNutrients:loadProductMap(self, size)
	end

	self.bitVectorMapNoise = createBitVectorMap(mapName .. "Noise")
	loadBitVectorMapNew(self.bitVectorMapNoise, size, size, NutrientMap.NOISE_BITS, false)
	self:addBitVectorMapToDelete(self.bitVectorMapNoise)
	self:generateNoise()

	-- minimap legend (PF draws label + gradient bar for the map that is shown on the minimap)
	self.minimapGradientSliceId = "precisionFarming.gradient_red_green"
	self.minimapGradientColorBlindSliceId = "precisionFarming.gradient_color_blind"
	self.minimapLabelName = self:getOverviewLabel()
	self.minimapGradientLabelName = string.format("%s - %s", self:formatUnits(self.legendMin), self:formatUnits(self.legendMax))

	logInfo("%s map %d x %d, %d bit, step %s, %s", self.nutrientId, size, size, self.numChannels, tostring(self.step), self.isNewMap and "new" or "loaded from savegame")
	return true
end

function NutrientMap:generateNoise()
	local startTime = getTimeSec()
	local modifier = DensityMapModifier.new(self.bitVectorMapNoise, 0, NutrientMap.NOISE_BITS)
	local filter = PerlinNoiseFilter.new(self.bitVectorMapNoise, 5.5, 1, 0.5, 4242 + string.byte(self.nutrientId))
	for i = 1, 4 do
		filter:setValueCompareParams(DensityValueCompareType.BETWEEN, (i - 1) / 4 * 10000, i / 4 * 10000)
		modifier:executeSet(i - 1, filter)
	end
	Logging.devInfo("[VTSZ-NUT] %s noise map generated in %d ms", self.nutrientId, (getTimeSec() - startTime) * 1000)
end

function NutrientMap:postLoad(xmlFile, key, baseDirectory, configFileName, mapFilename)
	if self.isNewMap then
		self:setInitialState()
	end
	return true
end

function NutrientMap:setInitialState()
	local soilMap = self.soilMap
	if soilMap == nil or soilMap.bitVectorMap == nil then
		return
	end
	local modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
	local soilFilter = DensityMapFilter.new(soilMap.bitVectorMap, soilMap.typeFirstChannel, soilMap.typeNumChannels)
	local noiseFilter = DensityMapFilter.new(self.bitVectorMapNoise, 0, NutrientMap.NOISE_BITS)
	for soilTypeIndex, levels in pairs(self.initialValues) do
		soilFilter:setValueCompareParams(DensityValueCompareType.EQUAL, soilTypeIndex - 1)
		for j = 1, 4 do
			local level = levels[j] or levels[#levels]
			noiseFilter:setValueCompareParams(DensityValueCompareType.EQUAL, j - 1)
			modifier:executeSet(math.clamp(level, 0, self.maxValue), soilFilter, noiseFilter)
		end
	end
	logInfo("%s initial state set", self.nutrientId)
end

----------------------------------------------------------------------------------------------------
-- Queries
----------------------------------------------------------------------------------------------------

function NutrientMap:getRequirement(fruitTypeIndex)
	return self.fruitRequirements[fruitTypeIndex] or self.defaultRequirement
end

-- map units added when a catch crop of this fruit type is destroyed (ploughed in)
function NutrientMap:getDestroyGain(fruitTypeIndex)
	local requirement = self.fruitRequirements[fruitTypeIndex]
	return ((requirement ~= nil and requirement.destroyGain) or self.catchCropGain) * self.timeScale
end

-- stored level <-> map units. Absolute maps: level x step. Relative map (OM): (level - levelOffset) x step = distance to the soil type target.
-- Hard limits are the stored range 0 .. maxValue, for OM -levelOffset x step .. +(maxValue - levelOffset) x step around the target.
function NutrientMap:levelToUnits(level)
	return (level - self.levelOffset) * self.step
end

function NutrientMap:unitsToLevel(units)
	return math.clamp(math.floor(units / self.step + 0.5) + self.levelOffset, 0, self:getCapLevel())
end

-- highest level that spreading and vtszNutrientSet can reach: the soft cap `maxUnits` when set, else the stored maximum
function NutrientMap:getCapLevel()
	if self.maxUnits == nil then
		return self.maxValue
	end
	return math.min(math.floor(self.maxUnits / self.step + 0.5) + self.levelOffset, self.maxValue)
end

-- target in map units: the soil type baseline (sufficiency level of "good supply"), scaled per crop, plus a share of the crop's
-- main-product removal (crops that take more need a higher soil level; K differs a lot between crops, P hardly).
-- Straw removal and the yield scale are not part of it (known only at harvest / circular with PF's multiplier).
-- No fruit type (nil): the baseline.
function NutrientMap:getTargetUnits(soilTypeIndex, fruitTypeIndex)
	local target = self.targets[soilTypeIndex]
	if target == nil then
		return nil
	end
	if fruitTypeIndex == nil then
		return self.relative and 0 or target
	end
	local requirement = self:getRequirement(fruitTypeIndex)
	local share = requirement.targetRemovalShare or self.targetRemovalShare
	local scale = requirement.targetScale or 1
	local extra = share * (requirement.removal or 0) * VtszConfig.removalScale
	if self.relative then
		-- the map stores the distance to the soil type target (self.targets still drives pH shift, leaching, mineralisation):
		-- the target of a crop is its surplus over that baseline
		return target * (scale - 1) + extra
	end
	return target * scale + extra
end

-- true when the target depends on the crop or the pH (pH keys, a removal share, or a per-crop targetScale / share): only such maps
-- show a "need" in the field info. OM has none, so its row stays the plain distance. Cached; the config is fixed after load.
function NutrientMap:getHasCropNeed()
	if self.hasCropNeed == nil then
		local need = self.targetRemovalShare > 0
		if not need then
			for _, requirement in pairs(self.fruitRequirementsByName) do
				if (requirement.targetScale or 1) ~= 1 or (requirement.targetRemovalShare or 0) > 0 then
					need = true
					break
				end
			end
		end
		self.hasCropNeed = need
	end
	return self.hasCropNeed
end

-- the crop target as an absolute content (soil type baseline included), for texts. Absolute maps: same as getTargetUnits.
function NutrientMap:getAbsoluteTargetUnits(soilTypeIndex, fruitTypeIndex)
	local target = self:getTargetUnits(soilTypeIndex, fruitTypeIndex)
	if target == nil or not self.relative then
		return target
	end
	return self.targets[soilTypeIndex] + target
end

-- yield factor in 0..1 for actual and target in map units. Never above 1 (PF stays the ceiling).
-- Keys with a positive difference make an oversupply penalty; beyond the last key the last factor holds.
function NutrientMap:getYieldFactor(actualUnits, targetUnits)
	local difference = actualUnits - targetUnits
	local keys = self.yieldKeys
	if #keys == 0 then
		return 1
	end
	if difference <= keys[1].difference then
		return keys[1].factor
	end
	for i = 2, #keys do
		local upper = keys[i]
		if difference <= upper.difference then
			local lower = keys[i - 1]
			local t = (difference - lower.difference) / math.max(upper.difference - lower.difference, 0.000001)
			return math.min(lower.factor + (upper.factor - lower.factor) * t, 1)
		end
	end
	return math.min(keys[#keys].factor, 1)
end

-- Map units per ha an automatic application should bring: exactly the gap the field info shows (crop target, NOT pH adjusted:
-- low pH is a liming problem, more P does not fix it; the field info warns about it). No build-up years, no harvest removal.
-- At or above the target the need is 0.
function NutrientMap:getAutoRateUnits(actualUnits, soilTypeIndex, fruitTypeIndex)
	local target = self:getTargetUnits(soilTypeIndex, fruitTypeIndex)
	if target == nil then
		return 0
	end
	return math.max(0, target - actualUnits)
end

-- Target at a pH efficiency: target / efficiency, capped at the map maximum minus one step so a fully fertilised field can always
-- reach factor 1. The cap never lowers the unadjusted target.
-- Relative maps: `target` is the surplus over the soil type baseline; the pH share applies to baseline + surplus and the result is
-- again a surplus. The cap is the soft cap (maxUnits) when set, else the stored maximum (loam P at pH 5.0 needs +257, cap +300).
function NutrientMap:getPhAdjustedTarget(target, phEfficiency, soilTypeIndex)
	if phEfficiency >= 1 then
		return target
	end
	if self.relative then
		local baseline = self.targets[soilTypeIndex] or 0
		local capUnits = (self:getCapLevel() - self.levelOffset) * self.step
		local cap = math.max(target, capUnits - self.step)
		return math.min((baseline + target) / phEfficiency - baseline, cap)
	end
	local cap = math.max(target, (self.maxValue - 1) * self.step)
	return math.min(target / phEfficiency, cap)
end

-- share (0.3..1) of the map content that is usable at soil pH `ph`; 1 without keys or without a pH value
function NutrientMap:getPhEfficiency(ph)
	local keys = self.phEfficiencyKeys
	if #keys == 0 or ph == nil or ph <= 0 then
		return 1
	end
	if ph <= keys[1].ph then
		return keys[1].value
	end
	for i = 2, #keys do
		if ph <= keys[i].ph then
			local lower, upper = keys[i - 1], keys[i]
			local t = (ph - lower.ph) / math.max(upper.ph - lower.ph, 0.000001)
			return lower.value + (upper.value - lower.value) * t
		end
	end
	return keys[#keys].value
end

function NutrientMap:getLevelAtWorldPos(x, z)
	local coverMap = self.coverMap
	if coverMap == nil or not coverMap:getIsUncoveredAtPos(x, z, true) then
		return nil
	end
	local terrainSize = g_currentMission.terrainSize
	local lx = MathUtil.round((x + terrainSize * 0.5) / terrainSize * self.sizeX + 0.5) - 1
	local lz = MathUtil.round((z + terrainSize * 0.5) / terrainSize * self.sizeY + 0.5) - 1
	return getBitVectorMapPoint(self.bitVectorMap, lx, lz, self.firstChannel, self.numChannels)
end

function NutrientMap:formatUnits(units)
	if self.unitFormat:find("%%[%+%- ]?%d*d") ~= nil then
		-- %d errors on a float with a fraction
		units = math.floor(units + 0.5)
	end
	return string.format(self.unitFormat, units)
end

----------------------------------------------------------------------------------------------------
-- Spreading
----------------------------------------------------------------------------------------------------

function NutrientMap:getSprayData()
	local data = self.sprayData
	if data == nil then
		data = {}
		data.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels, g_terrainNode)
		-- default rounding, same pixel set as the lock in VtszNutrients:getLockData (see there)
		data.noiseFilter = DensityMapFilter.new(self.bitVectorMapNoise, 0, NutrientMap.NOISE_BITS)
		self.sprayData = data
	end
	return data
end

-- units = map units per ha that this pass should add (>= 0). lockFilter: pixels allowed to change this pass.
function NutrientMap:addUnitsAtArea(shape, units, lockFilter)
	local levels = units / self.step
	local whole, bands = splitLevels(levels)
	if whole == 0 and bands == 0 then
		return
	end
	local data = self:getSprayData()
	shape:applyToModifier(data.modifier)
	if whole > 0 then
		data.modifier:executeAdd(whole, lockFilter)
	end
	if bands > 0 then
		for _, range in ipairs(getNoiseRanges(math.random(0, 3), bands)) do
			data.noiseFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, range[1], range[2])
			data.modifier:executeAdd(1, lockFilter, data.noiseFilter)
		end
	end
	if self.maxUnits ~= nil then
		-- soft cap: more than this is wasted (P). Pixels above the cap are set back; the polygon is still the spray area.
		if data.capFilter == nil then
			data.capFilter = DensityMapFilter.new(self.bitVectorMap, self.firstChannel, self.numChannels)
		end
		local capLevel = self:getCapLevel()
		data.capFilter:setValueCompareParams(DensityValueCompareType.GREATER, capLevel)
		data.modifier:executeSet(capLevel, data.capFilter)
	end
	self:setMinimapRequiresUpdate(true)
end

-- map units added per ha for the given fill type amount per ha, nil if the fill type carries none of this nutrient
function NutrientMap:getUnitsForFillType(fillTypeIndex, litersPerHa)
	local content = self.fillTypeContents[fillTypeIndex]
	if content == nil then
		return nil
	end
	if content.value <= 0 then
		return nil
	end
	-- value is per 1000 liters of the fill type
	return content.value * (litersPerHa / 1000) * VtszConfig.inputScale * self.timeScale
end

----------------------------------------------------------------------------------------------------
-- Harvest (called from the wrapped NitrogenMap:harvestUpdate, with PF's own filter of the harvested pixels)
----------------------------------------------------------------------------------------------------

function NutrientMap:getHarvestData()
	local data = self.harvestData
	if data == nil then
		data = {}
		data.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels, g_terrainNode)
		data.soilFilter = DensityMapFilter.new(self.soilMap.bitVectorMap, self.soilMap.typeFirstChannel, self.soilMap.typeNumChannels)
		data.noiseFilter = DensityMapFilter.new(self.bitVectorMapNoise, 0, NutrientMap.NOISE_BITS)
		data.multiModifiers = {}
		data.accumulators = {}
		data.numChangedPixels = {}
		data.totalNumPixels = {}
		self.harvestData = data
	end
	return data
end

local function addOp(multi, isSet, value, modifier, f1, f2, f3)
	local fn = isSet and multi.addExecuteSet or multi.addExecuteAdd
	if f3 ~= nil then
		fn(multi, value, modifier, f1, f2, f3)
	else
		fn(multi, value, modifier, f1, f2)
	end
end

-- signed change of `whole` levels plus `bands` noise bands (starting at noise value `offset`) on pixels matching filter
function NutrientMap:addSignedChange(multi, sign, whole, bands, offset, data, filter)
	if whole > 0 then
		addOp(multi, false, sign * whole, data.modifier, filter)
	end
	if bands > 0 then
		for _, range in ipairs(getNoiseRanges(offset, bands)) do
			data.noiseFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, range[1], range[2])
			addOp(multi, false, sign, data.modifier, filter, data.noiseFilter)
		end
	end
end

-- net change in map units of one harvest of this fruit type. yieldScale (nil = 1) is the yield of this harvest step relative
-- to the typical yield the config values are for; the change follows it by `yieldScaling` (P, K: 1, OM: weaker).
-- forageHarvest: forage harvester header or mower. A fruit type with `forageRemoval` then loses crop and straw and gains nothing
-- (no stalks stay); other fruit types behave as for a grain harvest with the straw taken (removal + removalStraw, no straw gain;
-- PF sets strawChopperActive on a forage harvester too, so it is ignored here; maize silage already has its removal, grass its net gain).
function NutrientMap:getHarvestChange(fruitTypeIndex, strawChopperActive, yieldScale, forageHarvest)
	local requirement = self:getRequirement(fruitTypeIndex)
	local removal = requirement.removal
	local gain = requirement.gain or 0
	if forageHarvest and requirement.forageRemoval ~= nil then
		removal = math.max(removal, requirement.forageRemoval) + requirement.removalStraw
		gain = 0
	elseif strawChopperActive and not forageHarvest then
		gain = gain + (requirement.strawGain or self.strawChopperGain)
	else
		removal = removal + requirement.removalStraw
	end
	local scale = 1 + ((yieldScale or 1) - 1) * self.yieldScaling
	return (gain * VtszConfig.inputScale - removal * VtszConfig.removalScale) * scale * self.timeScale
end

-- A multi modifier is built once per (fruit, chopper, yield scale step, noise offset, extra band) and reused. The leftover
-- below one noise band (small OM changes) is rounded at random per call by picking the variant with or without the extra band.
-- yieldScale is quantised to YIELD_SCALE_STEP by the caller, so the number of variants stays small.
function NutrientMap:getHarvestMultiModifier(filter, fruitTypeIndex, strawChopperActive, yieldScale, forageHarvest)
	local data = self:getHarvestData()
	local byFruit = data.multiModifiers[fruitTypeIndex]
	if byFruit == nil then
		byFruit = {}
		data.multiModifiers[fruitTypeIndex] = byFruit
	end
	local entryKey = (forageHarvest and "f" or (strawChopperActive and "c" or "s")) .. tostring(math.floor((yieldScale or 1) / NutrientMap.YIELD_SCALE_STEP + 0.5))
	local entry = byFruit[entryKey]
	if entry == nil then
		local levels = self:getHarvestChange(fruitTypeIndex, strawChopperActive, yieldScale, forageHarvest) / self.step
		local whole, bands, chance = splitLevelsParts(levels)
		entry = { sign = levels < 0 and -1 or 1, whole = whole, bands = bands, chance = chance, variants = {} }
		byFruit[entryKey] = entry
	end
	local extra = (entry.chance > 0 and math.random() < entry.chance) and 1 or 0
	local offset = math.random(0, 3)
	local variantKey = offset * 2 + extra
	local multi = entry.variants[variantKey]
	if multi == nil then
		multi = DensityMapMultiModifier.new()
		local whole, bands = entry.whole, entry.bands + extra
		if bands >= 4 then
			whole = whole + 1
			bands = 0
		end
		-- stats first (per soil type), then one change pass: the change does not depend on soil type, and
		-- chaining harvest filter + soil filter + noise filter in one op is "Filter setup is too complex"
		for _, soilTypeIndex in ipairs(self.soilTypeIndices) do
			data.soilFilter:setValueCompareParams(DensityValueCompareType.EQUAL, soilTypeIndex - 1)
			multi:addExecuteGet(tostring(soilTypeIndex), data.modifier, filter, data.soilFilter)
		end
		self:addSignedChange(multi, entry.sign, whole, bands, offset, data, filter)
		entry.variants[variantKey] = multi
	end
	return multi
end

-- forageHarvest: PF's useMinForageState (forage header) or a mower step, decided by VtszNutrients:onHarvestUpdate
function NutrientMap:harvestUpdate(filter, fruitTypeIndex, densityMapShape, forageHarvest, strawChopperActive, yieldScale, ph)
	if self.bitVectorMap == nil or self.soilMap == nil or self.soilMap.bitVectorMap == nil or filter == nil then
		return false
	end
	strawChopperActive = strawChopperActive == true
	forageHarvest = forageHarvest == true
	local data = self:getHarvestData()
	local multi = self:getHarvestMultiModifier(filter, fruitTypeIndex, strawChopperActive, yieldScale, forageHarvest)
	densityMapShape:applyToModifier(multi)
	for k in pairs(data.accumulators) do
		data.accumulators[k] = nil
	end
	for k in pairs(data.numChangedPixels) do
		data.numChangedPixels[k] = nil
	end
	multi:resetStats()
	multi:execute(data.accumulators, data.numChangedPixels, data.totalNumPixels)

	local sumFactor, sumPixels, sumActual, sumTarget = 0, 0, 0, 0
	local phEfficiency = self:getPhEfficiency(ph)
	for key, accumulator in pairs(data.accumulators) do
		local numPixels = data.numChangedPixels[key]
		local soilTypeIndex = tonumber(key)
		if numPixels ~= nil and numPixels > 0 and soilTypeIndex ~= nil then
			local actualUnits = self:levelToUnits(accumulator / numPixels)
			local targetUnits = self:getTargetUnits(soilTypeIndex, fruitTypeIndex)
			if targetUnits ~= nil then
				-- less of the stock is usable at this pH: it takes a larger stock for the same yield
				targetUnits = self:getPhAdjustedTarget(targetUnits, phEfficiency, soilTypeIndex)
				sumFactor = sumFactor + numPixels * self:getYieldFactor(actualUnits, targetUnits)
				sumActual = sumActual + numPixels * actualUnits
				sumTarget = sumTarget + numPixels * targetUnits
				sumPixels = sumPixels + numPixels
			end
		end
	end
	if sumPixels > 0 then
		self.lastFactor = sumFactor / sumPixels
		self.lastActual = sumActual / sumPixels
		self.lastTarget = sumTarget / sumPixels
		self.lastPhEfficiency = phEfficiency
		self:setMinimapRequiresUpdate(true)
		return true
	end
	return false
end

-- returns the factor of the last harvest step once, then clears it
function NutrientMap:popLastFactor()
	local factor = self.lastFactor
	local actual, target = self.lastActual, self.lastTarget
	self.lastFactor = nil
	self.lastActual = nil
	self.lastTarget = nil
	return factor, actual, target
end

----------------------------------------------------------------------------------------------------
-- Mineralisation (OM decay) - called by VtszNutrients once per game period, server only
----------------------------------------------------------------------------------------------------

-- map units lost on soil type `soilTypeIndex` in game period `period` (1..12, period 1 = March), >= 0
function NutrientMap:getMineralisationUnits(soilTypeIndex, period)
	local target = self.targets[soilTypeIndex]
	local weight = self.mineralisationWeights[period]
	if self.mineralisationRate <= 0 or target == nil or weight == nil then
		return 0
	end
	return self.mineralisationRate * target * weight * VtszConfig.removalScale * self.timeScale
end

-- Removes the period's share of the yearly loss on every pixel. The loss per period is far below one map level, so the
-- fraction is rounded at random per application (noise bands, as for harvest and spreading) and the field average stays exact.
function NutrientMap:applyMineralisation(period)
	if self.mineralisationRate <= 0 or self.bitVectorMap == nil or self.soilMap == nil or self.soilMap.bitVectorMap == nil then
		return false
	end
	local data = self.mineralisationData
	if data == nil then
		data = {}
		data.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
		data.soilFilter = DensityMapFilter.new(self.soilMap.bitVectorMap, self.soilMap.typeFirstChannel, self.soilMap.typeNumChannels)
		data.noiseFilter = DensityMapFilter.new(self.bitVectorMapNoise, 0, NutrientMap.NOISE_BITS)
		self.mineralisationData = data
	end
	local summary = {}
	for _, soilTypeIndex in ipairs(self.soilTypeIndices) do
		local units = self:getMineralisationUnits(soilTypeIndex, period)
		local whole, bands = splitLevels(units / self.step)
		if whole > 0 or bands > 0 then
			data.soilFilter:setValueCompareParams(DensityValueCompareType.EQUAL, soilTypeIndex - 1)
			if whole > 0 then
				data.modifier:executeAdd(-whole, data.soilFilter)
			end
			if bands > 0 then
				for _, range in ipairs(getNoiseRanges(math.random(0, 3), bands)) do
					data.noiseFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, range[1], range[2])
					data.modifier:executeAdd(-1, data.soilFilter, data.noiseFilter)
				end
			end
		end
		table.insert(summary, string.format("soil%d=%.4f", soilTypeIndex, units))
	end
	self.lastMineralisation = table.concat(summary, " ")
	self:setMinimapRequiresUpdate(true)
	return true
end

----------------------------------------------------------------------------------------------------
-- Leaching (K loss on light soils) - called by VtszNutrients once per game period, server only
----------------------------------------------------------------------------------------------------

-- map units lost on soil type `soilTypeIndex` in game period `period` (1..12), >= 0
function NutrientMap:getLeachingUnits(soilTypeIndex, period)
	local rate = self.leachingRates[soilTypeIndex]
	local weight = self.leachingWeights[period]
	if rate == nil or rate <= 0 or weight == nil then
		return 0
	end
	return rate * weight * VtszConfig.removalScale
end

-- Same random rounding as the mineralisation. Only pixels at or above the soil type target leach (no loss at low content).
function NutrientMap:applyLeaching(period)
	if next(self.leachingRates) == nil or self.bitVectorMap == nil or self.soilMap == nil or self.soilMap.bitVectorMap == nil then
		return false
	end
	local data = self.leachingData
	if data == nil then
		data = {}
		data.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
		data.soilFilter = DensityMapFilter.new(self.soilMap.bitVectorMap, self.soilMap.typeFirstChannel, self.soilMap.typeNumChannels)
		data.noiseFilter = DensityMapFilter.new(self.bitVectorMapNoise, 0, NutrientMap.NOISE_BITS)
		data.levelFilter = DensityMapFilter.new(self.bitVectorMap, self.firstChannel, self.numChannels)
		self.leachingData = data
	end
	local summary = {}
	for _, soilTypeIndex in ipairs(self.soilTypeIndices) do
		local units = self:getLeachingUnits(soilTypeIndex, period)
		local whole, bands = splitLevels(units / self.step)
		if whole > 0 or bands > 0 then
			data.soilFilter:setValueCompareParams(DensityValueCompareType.EQUAL, soilTypeIndex - 1)
			if self.relative then
				data.levelFilter:setValueCompareParams(DensityValueCompareType.GREATER, self.levelOffset - 1) -- at or above the target
			else
				data.levelFilter:setValueCompareParams(DensityValueCompareType.GREATER, math.ceil(self.targets[soilTypeIndex] / self.step - 1e-6) - 1)
			end
			if whole > 0 then
				data.modifier:executeAdd(-whole, data.soilFilter, data.levelFilter)
			end
			if bands > 0 then
				for _, range in ipairs(getNoiseRanges(math.random(0, 3), bands)) do
					data.noiseFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, range[1], range[2])
					data.modifier:executeAdd(-1, data.soilFilter, data.levelFilter, data.noiseFilter)
				end
			end
		end
		table.insert(summary, string.format("soil%d=%.2f", soilTypeIndex, units))
	end
	self.lastLeaching = table.concat(summary, " ")
	self:setMinimapRequiresUpdate(true)
	return true
end

-- Mineralised OM releases plant-available nitrogen. kg N/ha in game period `period` on soil type `soilTypeIndex`: the OM stock
-- (the soil type target, as for the loss) x nitrogenPerPercent x the period's share of the year x balance removalScale
-- (it scales the OM loss, so it scales the N that loss releases; timeScale stays out, N is per game year). >= 0
function NutrientMap:getNitrogenReleaseKg(soilTypeIndex, period)
	local target = self.targets[soilTypeIndex]
	local weight = self.mineralisationWeights[period]
	if self.nitrogenPerPercent <= 0 or self.mineralisationRate <= 0 or target == nil or weight == nil then
		return 0
	end
	return self.nitrogenPerPercent * target * weight * VtszConfig.removalScale
end

-- Adds that nitrogen to PF's N map (pixel data only, PF's code is not touched). Same random rounding as the OM loss, soil type
-- by soil type; pixels above PF's visible maximum are cut back the way PF does after its own additions.
function NutrientMap:applyNitrogenRelease(period)
	local nitrogenMap = VtszNutrients.pf.nitrogenMap
	if self.nitrogenPerPercent <= 0 or self.mineralisationRate <= 0 or nitrogenMap == nil or nitrogenMap.bitVectorMap == nil
		or self.soilMap == nil or self.soilMap.bitVectorMap == nil or nitrogenMap.maxVisibleValue == nil or not (nitrogenMap.amountPerState > 0) then
		return false
	end
	if nitrogenMap.sizeX ~= self.sizeX or nitrogenMap.sizeY ~= self.sizeY then
		if not self.nitrogenSizeWarned then
			self.nitrogenSizeWarned = true
			logWarning("N map %dx%d differs from the OM map %dx%d, nitrogen release skipped", nitrogenMap.sizeX, nitrogenMap.sizeY, self.sizeX, self.sizeY)
		end
		return false
	end
	local data = self.nitrogenReleaseData
	if data == nil then
		data = {}
		data.modifier = DensityMapModifier.new(nitrogenMap.bitVectorMap, nitrogenMap.firstChannel, nitrogenMap.numChannels)
		data.soilFilter = DensityMapFilter.new(self.soilMap.bitVectorMap, self.soilMap.typeFirstChannel, self.soilMap.typeNumChannels)
		data.noiseFilter = DensityMapFilter.new(self.bitVectorMapNoise, 0, NutrientMap.NOISE_BITS)
		data.maxFilter = DensityMapFilter.new(nitrogenMap.bitVectorMap, nitrogenMap.firstChannel, nitrogenMap.numChannels)
		data.maxFilter:setValueCompareParams(DensityValueCompareType.GREATER, nitrogenMap.maxVisibleValue)
		self.nitrogenReleaseData = data
	end
	local summary = {}
	for _, soilTypeIndex in ipairs(self.soilTypeIndices) do
		local kg = self:getNitrogenReleaseKg(soilTypeIndex, period)
		local whole, bands = splitLevels(kg / nitrogenMap.amountPerState)
		if whole > 0 or bands > 0 then
			data.soilFilter:setValueCompareParams(DensityValueCompareType.EQUAL, soilTypeIndex - 1)
			if whole > 0 then
				data.modifier:executeAdd(whole, data.soilFilter)
			end
			if bands > 0 then
				for _, range in ipairs(getNoiseRanges(math.random(0, 3), bands)) do
					data.noiseFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, range[1], range[2])
					data.modifier:executeAdd(1, data.soilFilter, data.noiseFilter)
				end
			end
		end
		table.insert(summary, string.format("soil%d=%.2f kg N", soilTypeIndex, kg))
	end
	data.modifier:executeSet(nitrogenMap.maxVisibleValue, data.maxFilter)
	self.lastNitrogenRelease = table.concat(summary, " ")
	nitrogenMap:setMinimapRequiresUpdate(true)
	return true
end

----------------------------------------------------------------------------------------------------
-- Catch crops (OM) - called by VtszNutrients with its own destroy mask
----------------------------------------------------------------------------------------------------

function NutrientMap:addUnitsFromMask(startX, startZ, widthX, widthZ, heightX, heightZ, units, maskFilter)
	local levels = units / self.step
	local whole, bands = splitLevels(levels)
	if whole == 0 and bands == 0 then
		return
	end
	local data = self.destroyData
	if data == nil then
		data = {}
		data.modifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels, g_terrainNode)
		data.modifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)
		data.noiseFilter = DensityMapFilter.new(self.bitVectorMapNoise, 0, NutrientMap.NOISE_BITS)
		self.destroyData = data
	end
	data.modifier:setParallelogramWorldCoords(startX, startZ, widthX, widthZ, heightX, heightZ, DensityCoordType.POINT_POINT_POINT)
	if whole > 0 then
		data.modifier:executeAdd(whole, maskFilter)
	end
	if bands > 0 then
		for _, range in ipairs(getNoiseRanges(math.random(0, 3), bands)) do
			data.noiseFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, range[1], range[2])
			data.modifier:executeAdd(1, maskFilter, data.noiseFilter)
		end
	end
	self:setMinimapRequiresUpdate(true)
end

----------------------------------------------------------------------------------------------------
-- UI (PF map overview, legend, field info)
----------------------------------------------------------------------------------------------------

function NutrientMap:getBandIndex(levelUnits)
	local bandSize = (self.legendMax - self.legendMin) / self.numBands
	return math.clamp(math.floor((levelUnits - self.legendMin) / bandSize) + 1, 1, self.numBands)
end

-- colour at position t (0..1) of the legend window: red -> yellow -> green, colour blind mode orange -> white -> blue
function NutrientMap:getColorAt(t, isColorBlindMode)
	t = math.clamp(t, 0, 1)
	if isColorBlindMode then
		if t < 0.5 then
			local u = t / 0.5
			return { 0.95 + (1 - 0.95) * u, 0.5 + (1 - 0.5) * u, 0.1 + (1 - 0.1) * u }
		end
		local u = (t - 0.5) / 0.5
		return { 1 - 0.75 * u, 1 - 0.5 * u, 1 - 0.1 * u }
	end
	if t < 0.5 then
		local u = t / 0.5
		return { 0.85 + (0.95 - 0.85) * u, 0.1 + (0.85 - 0.1) * u, 0.1 + (0.2 - 0.1) * u }
	end
	local u = (t - 0.5) / 0.5
	return { 0.95 - 0.85 * u, 0.85 - 0.2 * u, 0.2 }
end

-- surplusColors maps (like the PF pH map, which shows over-liming): red -> yellow -> green from legendMin up to the target 0,
-- green up to surplusFrom (default 0; K: the start of the oversupply penalty), then green -> blue (colour blind: white -> dark blue)
-- up to legendMax. Above legendMax the colour stays at the end.
function NutrientMap:getUnitsColor(units, isColorBlindMode)
	if self.surplusColors and self.legendMin < 0 and self.legendMax > self.surplusFrom then
		if units <= 0 then
			return self:getColorAt((units - self.legendMin) / -self.legendMin, isColorBlindMode)
		end
		local u = math.clamp((units - self.surplusFrom) / (self.legendMax - self.surplusFrom), 0, 1)
		if isColorBlindMode then
			return { 0.25 - 0.15 * u, 0.5 - 0.35 * u, 0.9 - 0.4 * u }
		end
		return { 0.1 + 0.05 * u, 0.65 - 0.3 * u, 0.2 + 0.7 * u }
	end
	return self:getColorAt((units - self.legendMin) / (self.legendMax - self.legendMin), isColorBlindMode)
end

-- legend swatch: the colour at the middle of the band
function NutrientMap:getBandColor(band, isColorBlindMode)
	local bandSize = (self.legendMax - self.legendMin) / self.numBands
	return self:getUnitsColor(self.legendMin + (band - 0.5) * bandSize, isColorBlindMode)
end

-- map colour of one level: a continuous gradient over the legend window, so a change of a single level (small for OM) shows
function NutrientMap:getLevelColor(levelUnits, isColorBlindMode)
	return self:getUnitsColor(levelUnits, isColorBlindMode)
end

function NutrientMap:getOverviewLabel()
	return g_i18n:getText(self.label, NutrientMap.MOD_NAME)
end

function NutrientMap:getAllowCoverage()
	return true
end

function NutrientMap:getHelpLinePage()
	return 0
end

-- Yield change in percent (<= 0) at the middle of a legend band. The maps are relative (units = distance from the soil type
-- target), so target is 0. Approximate: no crop, no pH adjustment. The field info row has the exact value.
function NutrientMap:getBandYieldPercent(band)
	local bandSize = (self.legendMax - self.legendMin) / self.numBands
	local mid = self.legendMin + (band - 0.5) * bandSize
	return math.floor((self:getYieldFactor(mid, 0) - 1) * 100 + 0.5)
end

function NutrientMap:getDisplayValues()
	if self.valuesToDisplay == nil then
		self.valuesToDisplay = {}
		local bandSize = (self.legendMax - self.legendMin) / self.numBands
		for band = 1, self.numBands do
			local value = {}
			value.colors = {}
			value.colors[true] = { self:getBandColor(band, true) }
			value.colors[false] = { self:getBandColor(band, false) }
			local from = self.legendMin + (band - 1) * bandSize
			-- a band is labelled by its maximum; the outer bands are open ended (below the first / above the last maximum)
			if band == 1 then
				value.description = string.format("<= %s", self:formatUnits(from + bandSize))
			elseif band == self.numBands then
				value.description = string.format("> %s", self:formatUnits(from))
			else
				value.description = self:formatUnits(from + bandSize)
			end
			value.description = string.format("%s  %+d %%", value.description, self:getBandYieldPercent(band))
			table.insert(self.valuesToDisplay, value)
		end
	end
	return self.valuesToDisplay
end

function NutrientMap:getValueFilter()
	if self.valueFilter == nil or self.valueFilterEnabled == nil then
		self.valueFilter = {}
		self.valueFilterEnabled = {}
		for _ = 1, self.numBands do
			table.insert(self.valueFilter, true)
			table.insert(self.valueFilterEnabled, true)
		end
	end
	return self.valueFilter, self.valueFilterEnabled
end

function NutrientMap:buildOverlay(overlay, filter, isColorBlindMode, isMinimap)
	resetDensityMapVisualizationOverlay(overlay)
	setOverlayColor(overlay, 1, 1, 1, 1)
	local coverMap = self.coverMap
	if coverMap == nil then
		return
	end
	local coverMask = bit32.lshift(2 ^ (coverMap.numChannels - 1) - 1, 1)
	for level = 0, self.maxValue do
		local band = self:getBandIndex(self:levelToUnits(level))
		if filter[band] then
			local color = self:getLevelColor(self:levelToUnits(level), isColorBlindMode)
			setDensityMapVisualizationOverlayStateColor(overlay, self.bitVectorMap, coverMap.bitVectorMap, coverMask, self.firstChannel, self.numChannels, level, color[1], color[2], color[3])
		end
	end
end

function NutrientMap:collectFieldInfos(fieldInfoDisplayExtension)
	local name = g_i18n:getText("vtsz_fieldInfo_" .. self.nutrientId, NutrientMap.MOD_NAME)
	-- no yieldChangeFunc on purpose: PF's yield box uses fieldInfo.nFactor / yieldPotential, which are N only.
	-- Our factor reaches the expected yield through fieldYieldFactor, see VtszNutrients:installHarvestHooks.
	local updateFunc = self.updateFieldInfoDisplay
	if VtszProfiler ~= nil then -- PF stores the function by reference; counts only while vtszPerf runs
		updateFunc = VtszProfiler.probe("Perf5 NutrientMap:updateFieldInfoDisplay", updateFunc)
	end
	fieldInfoDisplayExtension:addFieldInfo(name, self, updateFunc, 4, nil)
end

-- Shared colours of the field info rows (never modified; PF only reads them). Index: isColorBlindMode and 2 or 1.
local FIELD_INFO_OK = { { 0.3, 0.8, 0.3, 1 }, { 0.2, 0.5, 1, 1 } }
local FIELD_INFO_LOW = { { 1, 0.8, 0.2, 1 }, { 1, 0.8, 0.2, 1 } }
local FIELD_INFO_VERY_LOW = { { 1, 0.2, 0.2, 1 }, { 1, 0.5, 0, 1 } }

function NutrientMap:updateFieldInfoDisplay(fieldInfo, x, z, isColorBlindMode)
	-- runs every frame while a field is in view, so it allocates nothing in the steady state: shared lookups and colour tables,
	-- and the formatted text is kept while its inputs (units, pH note) stay the same
	-- read by the wrapped NitrogenMap:getFieldInfoYieldChange (VtszNutrients:installHarvestHooks)
	self.fieldYieldFactor = 1
	local level = self:getLevelAtWorldPos(x, z)
	if level == nil then
		return nil
	end
	local actualUnits = self:levelToUnits(level)
	local soilTypeIndex, fruitTypeIndex, ph = VtszNutrients:getFieldLookups(self.soilMap, x, z)
	local targetUnits = nil
	if soilTypeIndex ~= nil and soilTypeIndex > 0 and fruitTypeIndex ~= nil then
		targetUnits = self:getTargetUnits(soilTypeIndex, fruitTypeIndex)
	end
	if targetUnits == nil then
		if self.fiPlainUnits ~= actualUnits then
			self.fiPlainUnits = actualUnits
			self.fiPlainText = self:formatUnits(actualUnits)
		end
		return self.fiPlainText
	end
	local phEfficiency = self:getPhEfficiency(ph)
	local cropTargetUnits = targetUnits -- without the pH effect: what the shown distance and the auto rate use
	targetUnits = self:getPhAdjustedTarget(targetUnits, phEfficiency, soilTypeIndex)
	local factor = self:getYieldFactor(actualUnits, targetUnits)
	self.fieldYieldFactor = factor
	local colorIndex = isColorBlindMode and 2 or 1
	local color, additionalText, showWarning
	-- the soil holds enough (at or above the crop target) but pH keeps the plants from using it: the cause is the pH, not the stock
	local phLimited = factor < 0.99 and phEfficiency < 0.99 and actualUnits >= cropTargetUnits
	if factor >= 0.99 then
		color = FIELD_INFO_OK[colorIndex]
	elseif phLimited then
		color = factor >= 0.9 and FIELD_INFO_LOW[colorIndex] or FIELD_INFO_VERY_LOW[colorIndex]
		additionalText = self.fiTextPh
		if additionalText == nil then
			additionalText = g_i18n:getText("vtsz_level_ph", NutrientMap.MOD_NAME)
			self.fiTextPh = additionalText
		end
		showWarning = factor < 0.9
	elseif factor >= 0.9 then
		color = FIELD_INFO_LOW[colorIndex]
		additionalText = self.fiTextLow
		if additionalText == nil then
			additionalText = g_i18n:getText("vtsz_level_low", NutrientMap.MOD_NAME)
			self.fiTextLow = additionalText
		end
	else
		color = FIELD_INFO_VERY_LOW[colorIndex]
		additionalText = self.fiTextVeryLow
		if additionalText == nil then
			additionalText = g_i18n:getText("vtsz_level_veryLow", NutrientMap.MOD_NAME)
			self.fiTextVeryLow = additionalText
		end
		showWarning = true
	end
	-- one signed value. Empty field: distance to the soil type target. With a crop and a crop dependent target: distance to the
	-- crop target (the auto rate gap, pH not included). Otherwise the plain distance to the soil type target.
	local shown = actualUnits
	if fruitTypeIndex ~= nil and fruitTypeIndex > 0 and self:getHasCropNeed() then
		shown = actualUnits - cropTargetUnits
	end
	if self.fiShown ~= shown then
		self.fiShown = shown
		self.fiText = self:formatUnits(shown)
	end
	return self.fiText, color, additionalText, showWarning
end

----------------------------------------------------------------------------------------------------
-- Debug
----------------------------------------------------------------------------------------------------

function NutrientMap:setUnitsOnField(fieldId, units)
	local field = g_fieldManager:getFieldById(tonumber(fieldId))
	if field == nil or field.getDensityMapPolygon == nil then
		return false
	end
	local level = self:unitsToLevel(units)
	local data = self:getSprayData()
	field:getDensityMapPolygon():applyToModifier(data.modifier)
	data.modifier:executeSet(level)
	self:setMinimapRequiresUpdate(true)
	return true, level
end
