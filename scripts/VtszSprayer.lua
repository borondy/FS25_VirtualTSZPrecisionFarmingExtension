-- Sprayer / spreader specialization (added to every vehicle type with "sprayer", see VtszNutrients.lua; this includes
-- fertilizing cultivators and fertilizing sowing machines, whose spraying happens in their own work area function):
--  1. server: adds P2O5, K2O and OM of the sprayed fill type to the maps (inside Sprayer:processSprayerArea)
--  2. products Precision Farming does not manage (no nitrogen): application rate in l/ha with own keys
--     (VTSZ_RATE_INCREASE / VTSZ_RATE_DECREASE), and the usage that follows from it
--  3. HUD line with l/ha and N / P2O5 / K2O kg/ha for every product with nutrients

VtszSprayer = {}
VtszSprayer.SPEC_NAME = g_currentModName .. ".vtszSprayer"
VtszSprayer.SPEC_TABLE_NAME = "spec_" .. VtszSprayer.SPEC_NAME
VtszSprayer.shape = nil

source(g_currentModDirectory .. "scripts/VtszSprayerRateEvent.lua")
source(g_currentModDirectory .. "scripts/VtszSprayerAutoEvent.lua")

function VtszSprayer.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(Sprayer, specializations)
end

function VtszSprayer.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "vtszSetRate", VtszSprayer.vtszSetRate)
	SpecializationUtil.registerFunction(vehicleType, "vtszGetRate", VtszSprayer.vtszGetRate)
	SpecializationUtil.registerFunction(vehicleType, "vtszGetCurrentFillType", VtszSprayer.vtszGetCurrentFillType)
	SpecializationUtil.registerFunction(vehicleType, "vtszSetAuto", VtszSprayer.vtszSetAuto)
	SpecializationUtil.registerFunction(vehicleType, "vtszGetAutoBase", VtszSprayer.vtszGetAutoBase)
	SpecializationUtil.registerFunction(vehicleType, "vtszGetEffectiveRate", VtszSprayer.vtszGetEffectiveRate)
	SpecializationUtil.registerFunction(vehicleType, "vtszGetUsageWidth", VtszSprayer.vtszGetUsageWidth)
	SpecializationUtil.registerFunction(vehicleType, "vtszIsRateControlled", VtszSprayer.vtszIsRateControlled)
	local updateAutoRate = VtszSprayer.vtszUpdateAutoRate
	if VtszProfiler ~= nil then -- vehicle function tables keep the reference; counts only while vtszPerf runs
		updateAutoRate = VtszProfiler.probe("Perf2 VtszSprayer:vtszUpdateAutoRate", updateAutoRate)
	end
	SpecializationUtil.registerFunction(vehicleType, "vtszUpdateAutoRate", updateAutoRate)
	SpecializationUtil.registerFunction(vehicleType, "vtszGetPFSpec", VtszSprayer.vtszGetPFSpec)
	SpecializationUtil.registerFunction(vehicleType, "vtszGetHudRate", VtszSprayer.vtszGetHudRate)
	SpecializationUtil.registerFunction(vehicleType, "vtszGetPFIdleRate", VtszSprayer.vtszGetPFIdleRate)
end

function VtszSprayer.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "processSprayerArea", VtszSprayer.processSprayerArea)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getSprayerUsage", VtszSprayer.getSprayerUsage)
	-- fertilizing cultivators (e.g. Zunhammer Vibro) spray inside their cultivator work area and never call processSprayerArea
	if FertilizingCultivator ~= nil and SpecializationUtil.hasSpecialization(FertilizingCultivator, vehicleType.specializations) then
		SpecializationUtil.registerOverwrittenFunction(vehicleType, "processCultivatorArea", VtszSprayer.processCultivatorArea)
	end
	-- fertilizing sowing machines (seeders with a fertilizer tank) spray inside their sowing work area, same reason
	if FertilizingSowingMachine ~= nil and SpecializationUtil.hasSpecialization(FertilizingSowingMachine, vehicleType.specializations) then
		SpecializationUtil.registerOverwrittenFunction(vehicleType, "processSowingMachineArea", VtszSprayer.processSowingMachineArea)
	end
	-- PF's function (registered by its ExtendedSprayer): only wrapped where it exists
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateWorkAreaSubSectionData", VtszSprayer.updateWorkAreaSubSectionData)
end

function VtszSprayer.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", VtszSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", VtszSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", VtszSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", VtszSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", VtszSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", VtszSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onDraw", VtszSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onChangedFillType", VtszSprayer)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", VtszSprayer)
end

function VtszSprayer:onLoad(savegame)
	local spec = self[VtszSprayer.SPEC_TABLE_NAME]
	spec.actionEvents = {}
	spec.rateFillType = FillType.UNKNOWN
	spec.litersPerHa = 0
	spec.autoOn = false -- own automatic rate, only for products PF does not manage; PF's auto mode governs the others
	spec.autoBase = nil -- chosen base nutrient "N" / "P" / "K", nil = the one with the highest content
	spec.autoRate = nil -- l/ha of the current update, nil = no data (rate as set by hand)
	spec.autoRateValid = false -- implement off: autoRate is the last sample and is kept (see vtszUpdateAutoRate)
	VtszNutrients:aliasLiquidMaterials()
end

-- Sprayer sprayTypes (effects, sounds, object changes) can be limited to listed fill types, e.g. fillTypes="LIQUIDFERTILIZER HERBICIDE".
-- Our liquids are not in those lists, so the spray effect never started: add them wherever LIQUIDFERTILIZER is listed.
function VtszSprayer:onPostLoad(savegame)
	local specSprayer = self.spec_sprayer
	for _, sprayType in ipairs(specSprayer.sprayTypes or {}) do
		local fillTypes = sprayType.fillTypes
		if fillTypes ~= nil then
			local hasLiquid = false
			local present = {}
			for _, name in ipairs(fillTypes) do
				present[name] = true
				hasLiquid = hasLiquid or name == "LIQUIDFERTILIZER"
			end
			if hasLiquid then
				for _, name in ipairs(VtszNutrients.LIQUID_FILL_TYPES) do
					if not present[name] then
						table.insert(fillTypes, name)
					end
				end
			end
		end
	end
end

function VtszSprayer:onDelete()
	local spec = self[VtszSprayer.SPEC_TABLE_NAME]
	if spec ~= nil and spec.actionEvents ~= nil then
		self:clearActionEventsTable(spec.actionEvents)
	end
end

function VtszSprayer:onWriteStream(streamId, connection)
	local spec = self[VtszSprayer.SPEC_TABLE_NAME]
	streamWriteUIntN(streamId, spec.rateFillType, FillTypeManager.SEND_NUM_BITS)
	streamWriteUIntN(streamId, spec.litersPerHa, 12)
	streamWriteBool(streamId, spec.autoOn)
	streamWriteUIntN(streamId, VtszSprayerAutoEvent.baseToIndex(spec.autoBase), 2)
end

function VtszSprayer:onReadStream(streamId, connection)
	local fillTypeIndex = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)
	local litersPerHa = streamReadUIntN(streamId, 12)
	local autoOn = streamReadBool(streamId)
	local autoBase = VtszSprayerAutoEvent.indexToBase(streamReadUIntN(streamId, 2))
	if fillTypeIndex ~= FillType.UNKNOWN then
		self:vtszSetRate(fillTypeIndex, litersPerHa, true)
	end
	self:vtszSetAuto(autoOn, autoBase, true)
end

----------------------------------------------------------------------------------------------------
-- Rate (only for products PF does not manage)
----------------------------------------------------------------------------------------------------

-- Vehicle and fill unit that hold the product. A tool fed from a tank (trailing shoe on a slurry tank, injector) has an own,
-- empty sprayer fill unit; Precision Farming resolves the source vehicle for this (ExtendedSprayer.getFillTypeSourceVehicle),
-- so do the same. Returns the tool itself and its own fill unit when there is no other source. Cached per frame.
function VtszSprayer.resolveFillSource(vehicle)
	local spec = vehicle[VtszSprayer.SPEC_TABLE_NAME]
	local ownIndex = vehicle:getSprayerFillUnitIndex()
	if ownIndex == nil then
		return nil, nil
	end
	if spec ~= nil and spec.sourceTime == g_time and spec.sourceOwnIndex == ownIndex then
		return spec.sourceVehicle, spec.sourceFillUnitIndex
	end
	local sourceVehicle, sourceIndex = vehicle, ownIndex
	if vehicle:getFillUnitFillLevel(ownIndex) <= 0 then
		local pfEnv = _G["FS25_precisionFarming"]
		local resolve = pfEnv ~= nil and pfEnv.ExtendedSprayer ~= nil and pfEnv.ExtendedSprayer.getFillTypeSourceVehicle or nil
		if resolve ~= nil then
			local ok, source, index = pcall(resolve, vehicle)
			if ok and source ~= nil and index ~= nil and source:getFillUnitFillType(index) ~= FillType.UNKNOWN then
				sourceVehicle, sourceIndex = source, index
			end
		end
	end
	if spec ~= nil then
		spec.sourceTime = g_time
		spec.sourceOwnIndex = ownIndex
		spec.sourceVehicle = sourceVehicle
		spec.sourceFillUnitIndex = sourceIndex
	end
	return sourceVehicle, sourceIndex
end

function VtszSprayer:vtszGetCurrentFillType()
	local source, fillUnitIndex = VtszSprayer.resolveFillSource(self)
	if source == nil then
		return FillType.UNKNOWN
	end
	return source:getFillUnitFillType(fillUnitIndex)
end

-- current rate in l/ha for the fill type, the product default when none was set yet
function VtszSprayer:vtszGetRate(fillTypeIndex)
	local spec = self[VtszSprayer.SPEC_TABLE_NAME]
	if spec.rateFillType == fillTypeIndex and spec.litersPerHa > 0 then
		return spec.litersPerHa
	end
	local config = VtszNutrients:getRateConfig(fillTypeIndex)
	return config.default
end

function VtszSprayer:vtszSetRate(fillTypeIndex, litersPerHa, noEventSend)
	local spec = self[VtszSprayer.SPEC_TABLE_NAME]
	local config = VtszNutrients:getRateConfig(fillTypeIndex)
	litersPerHa = math.clamp(math.floor(litersPerHa / config.step + 0.5) * config.step, config.min, config.max)
	spec.rateFillType = fillTypeIndex
	spec.litersPerHa = litersPerHa
	VtszSprayerRateEvent.sendEvent(self, fillTypeIndex, litersPerHa, noEventSend)
end

-- product changed (own fill unit event, or the product of the source vehicle seen in onUpdate)
function VtszSprayer.syncFillType(vehicle, fillTypeIndex)
	local spec = vehicle[VtszSprayer.SPEC_TABLE_NAME]
	if fillTypeIndex ~= spec.rateFillType then
		spec.rateFillType = fillTypeIndex
		spec.litersPerHa = 0 -- back to the product default
		spec.autoRateValid = false
		spec.autoBase = nil -- back to the default base nutrient of the product
		spec.autoRate = nil
		VtszSprayer.updateActionEventState(vehicle)
	end
end

function VtszSprayer:onChangedFillType(fillUnitIndex, fillTypeIndex, oldFillTypeIndex)
	-- the event comes from the tool's own fill unit; the product may live in a source vehicle
	VtszSprayer.syncFillType(self, self:vtszGetCurrentFillType())
	VtszSprayer.updateActionEventState(self)
end

----------------------------------------------------------------------------------------------------
-- Automatic rate with a base nutrient
--  * products with nitrogen: PF's auto mode (its key). Base N = PF as before; base P / K = the liters the nutrient needs,
--    handed to PF as an N-equivalent (VtszNutrients:getAutoNitrogenStates), so PF's N accounting stays right
--  * products without nitrogen (TSP, SSP, Kalisalz, Patentkali): own auto switch (VTSZ_AUTO_TOGGLE)
--  VTSZ_AUTO_BASE chooses the base nutrient among the ones the product contains; default = the highest content
----------------------------------------------------------------------------------------------------

function VtszSprayer:vtszSetAuto(autoOn, baseId, noEventSend)
	local spec = self[VtszSprayer.SPEC_TABLE_NAME]
	spec.autoOn = autoOn == true
	spec.autoBase = baseId
	spec.autoRate = nil
	spec.autoRateValid = false
	VtszSprayerAutoEvent.sendEvent(self, spec.autoOn, baseId, noEventSend)
	VtszSprayer.updateActionEventState(self)
end

-- effective base nutrient for the fill type: the chosen one if the product contains it, else the highest content
function VtszSprayer:vtszGetAutoBase(fillTypeIndex)
	local spec = self[VtszSprayer.SPEC_TABLE_NAME]
	if spec.autoBase ~= nil then
		for _, id in ipairs(VtszNutrients:getAutoBases(fillTypeIndex)) do
			if id == spec.autoBase then
				return id
			end
		end
	end
	return VtszNutrients:getDefaultAutoBase(fillTypeIndex)
end

-- rate in use: the automatic one when it has data, else the one set by hand
function VtszSprayer:vtszGetEffectiveRate(fillTypeIndex)
	local spec = self[VtszSprayer.SPEC_TABLE_NAME]
	if spec.autoOn and spec.autoRate ~= nil then
		return spec.autoRate
	end
	return self:vtszGetRate(fillTypeIndex)
end

function VtszSprayer:vtszGetPFSpec()
	local pfSpecName = VtszNutrients:getPFSprayerSpecTableName()
	return pfSpecName ~= nil and self[pfSpecName] or nil
end

-- Own auto rate for a P / K base, once per update: mean of the need under the active work areas; with none active (implement
-- off, headland) the mean under all sprayer work areas, so the rate is known before spraying starts.
--  * products without nitrogen: when the own auto switch is on (this rate is also the usage)
--  * PF products: only for the HUD while the implement is off (turned on, PF's lastLitersPerHectar is the real rate)
-- Implement off: the rate is sampled once and kept (spec.autoRateValid) until the cache is invalidated: fill type, auto
-- on/off or base (vtszSetAuto, onChangedFillType resets autoRateValid), PF auto mode left, implement turned on (then it
-- samples every update, and the last value stays when turned off again), or the vehicle moved more than
-- VtszSprayer.IDLE_RESAMPLE_DISTANCE m since the last sample.
VtszSprayer.IDLE_RESAMPLE_DISTANCE = 5

function VtszSprayer:vtszUpdateAutoRate()
	local spec = self[VtszSprayer.SPEC_TABLE_NAME]
	local fillTypeIndex = self:vtszGetCurrentFillType()
	local turnedOn = self:getIsTurnedOn()
	local rateControlled = VtszNutrients:isRateControlled(fillTypeIndex)
	local active = fillTypeIndex ~= nil and fillTypeIndex ~= FillType.UNKNOWN
	if active then
		if rateControlled then
			active = spec.autoOn
		else
			local pfSpec = self:vtszGetPFSpec()
			-- turned on, PF's lastLitersPerHectar is the real rate
			active = not turnedOn and pfSpec ~= nil and pfSpec.sprayAmountAutoMode and pfSpec.isFertilizing == true
		end
	end
	if not active then
		spec.autoRate = nil
		spec.autoRateValid = false
		return
	end
	local posX, _, posZ = getWorldTranslation(self.rootNode)
	if not turnedOn and spec.autoRateValid and spec.autoRateFillType == fillTypeIndex then
		local dx, dz = posX - spec.autoRateX, posZ - spec.autoRateZ
		if dx * dx + dz * dz <= VtszSprayer.IDLE_RESAMPLE_DISTANCE * VtszSprayer.IDLE_RESAMPLE_DISTANCE then
			return -- keep the last rate
		end
	end
	spec.autoRate = nil
	spec.autoRateValid = true
	spec.autoRateFillType = fillTypeIndex
	spec.autoRateX = posX
	spec.autoRateZ = posZ
	local baseId = self:vtszGetAutoBase(fillTypeIndex)
	if baseId ~= "P" and baseId ~= "K" then
		return
	end
	local sum, count, sumAll, countAll = 0, 0, 0, 0
	-- a seeder sows the seed it carries: the ground there holds no crop of it yet
	local fruitHint = nil
	local specSowing = self.spec_sowingMachine
	if specSowing ~= nil and specSowing.seeds ~= nil then
		fruitHint = specSowing.seeds[specSowing.currentSeed]
	end
	local workAreas = self.spec_workArea ~= nil and self.spec_workArea.workAreas or {}
	for _, area in ipairs(workAreas) do
		if VtszSprayer.isSprayWorkAreaType(area.type) then
			local x, z = VtszNutrients.getWorkAreaSamplePoint(self, area)
			local rate = VtszNutrients:getAutoRateAt(fillTypeIndex, baseId, x, z, fruitHint)
			if rate ~= nil and rateControlled then
				rate = math.min(rate, VtszNutrients:getRateConfig(fillTypeIndex).max) -- the product's own limit holds for the automatic rate too
			end
			if rate ~= nil and not rateControlled then
				-- PF product: the N it carries along must not exceed what PF's auto mode wants here
				local nLimit = VtszNutrients:getNitrogenNeedLiters(fillTypeIndex, x, z)
				if nLimit ~= nil then
					rate = math.min(rate, nLimit)
				end
			end
			if rate ~= nil then
				sumAll = sumAll + rate
				countAll = countAll + 1
				if turnedOn and self:getIsWorkAreaActive(area) then
					sum = sum + rate
					count = count + 1
				end
			end
		end
	end
	if count > 0 then
		spec.autoRate = sum / count
	elseif countAll > 0 then
		spec.autoRate = sumAll / countAll
	end
	if VtszNutrients.debug and turnedOn and (g_time or 0) - (spec.vtszDebugTime or 0) > 1000 then
		spec.vtszDebugTime = g_time or 0
		Logging.info("%s", string.format("[VTSZ-NUT] autoRate fill=%s base=%s rateControlled=%s rate=%s l/ha areas=%d/%d speed=%.1f", tostring(g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)), tostring(baseId), tostring(rateControlled), tostring(spec.autoRate), count, countAll, self:getLastSpeed()))
	end
end

-- context for the wrapped PF nitrogen application rate (see VtszNutrients:installAutoRateHooks)
function VtszSprayer:updateWorkAreaSubSectionData(superFunc, workArea)
	VtszNutrients.autoContext = { vehicle = self, workArea = workArea }
	local ok, a, b = pcall(superFunc, self, workArea)
	VtszNutrients.autoContext = nil
	if not ok then
		error(a, 0)
	end
	return a, b
end

VtszSprayer.RATE_ACTIONS = {
	{ name = "VTSZ_RATE_INCREASE", direction = 1 },
	{ name = "VTSZ_RATE_DECREASE", direction = -1 },
}

-- own actions (PF's PRECISIONFARMING_SPRAY_AMOUNT cannot be shared: InputBinding:registerActionEvent rejects a second
-- event with the same action and trigger, and PF's ExtendedSprayer registers it first)
function VtszSprayer:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self[VtszSprayer.SPEC_TABLE_NAME]
		self:clearActionEventsTable(spec.actionEvents)
		if isActiveForInputIgnoreSelection then
			for _, def in ipairs(VtszSprayer.RATE_ACTIONS) do
				local action = InputAction[def.name]
				if action ~= nil then
					local _, actionEventId = self:addActionEvent(spec.actionEvents, action, self, VtszSprayer.actionEventChangeRate, false, true, false, false, def.direction)
					if actionEventId ~= nil then
						g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_HIGH)
						g_inputBinding:setActionEventText(actionEventId, VtszNutrients:getText("vtsz_action_rate", "Application rate +/-"))
					end
				end
			end
			for _, def in ipairs(VtszSprayer.AUTO_ACTIONS) do
				local action = InputAction[def.name]
				if action ~= nil then
					local _, actionEventId = self:addActionEvent(spec.actionEvents, action, self, def.callback, false, true, false, true, nil)
					if actionEventId ~= nil then
						g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_HIGH)
						g_inputBinding:setActionEventText(actionEventId, VtszNutrients:getText("input_" .. def.name, def.name))
					end
				end
			end
			-- minimap layer paging (VtszMinimap); a second sprayer in the chain is rejected by the engine, which is fine
			local layerAction = InputAction.VTSZ_MINIMAP_LAYER
			if layerAction ~= nil then
				local _, layerEventId = self:addActionEvent(spec.actionEvents, layerAction, self, VtszSprayer.actionEventMinimapLayer, false, true, false, true, nil)
				if layerEventId ~= nil then
					g_inputBinding:setActionEventTextPriority(layerEventId, GS_PRIO_NORMAL)
					g_inputBinding:setActionEventText(layerEventId, VtszNutrients:getText("input_VTSZ_MINIMAP_LAYER", "Minimap layer"))
				end
			end
			VtszSprayer.updateActionEventState(self)
		end
	end
end

-- own auto switch (products PF does not manage) and base nutrient choice
function VtszSprayer:actionEventAutoToggle(actionName, inputValue, callbackState, isAnalog)
	local spec = self[VtszSprayer.SPEC_TABLE_NAME]
	if VtszNutrients:isRateControlled(self:vtszGetCurrentFillType()) then
		self:vtszSetAuto(not spec.autoOn, spec.autoBase)
	end
end

function VtszSprayer:actionEventAutoBase(actionName, inputValue, callbackState, isAnalog)
	local spec = self[VtszSprayer.SPEC_TABLE_NAME]
	local fillTypeIndex = self:vtszGetCurrentFillType()
	local bases = VtszNutrients:getAutoBases(fillTypeIndex)
	if #bases < 2 then
		return
	end
	local current = self:vtszGetAutoBase(fillTypeIndex)
	local nextIndex = 1
	for i, id in ipairs(bases) do
		if id == current then
			nextIndex = i % #bases + 1
		end
	end
	self:vtszSetAuto(spec.autoOn, bases[nextIndex])
end

VtszSprayer.AUTO_ACTIONS = {
	{ name = "VTSZ_AUTO_TOGGLE", callback = VtszSprayer.actionEventAutoToggle },
	{ name = "VTSZ_AUTO_BASE", callback = VtszSprayer.actionEventAutoBase },
}

function VtszSprayer:actionEventMinimapLayer(actionName, inputValue, callbackState, isAnalog)
	if VtszMinimap ~= nil then
		VtszMinimap:cycle()
	end
end

function VtszSprayer:updateActionEventState()
	local spec = self[VtszSprayer.SPEC_TABLE_NAME]
	if spec.actionEvents == nil then
		return
	end
	local fillTypeIndex = self:vtszGetCurrentFillType()
	local controlled = VtszNutrients:isRateControlled(fillTypeIndex)
	local numBases = #VtszNutrients:getAutoBases(fillTypeIndex)
	local toggleEvent = spec.actionEvents[InputAction.VTSZ_AUTO_TOGGLE]
	if toggleEvent ~= nil then
		g_inputBinding:setActionEventActive(toggleEvent.actionEventId, controlled)
		local textKey = spec.autoOn and "vtsz_action_auto_off" or "vtsz_action_auto_on"
		g_inputBinding:setActionEventText(toggleEvent.actionEventId, VtszNutrients:getText(textKey, spec.autoOn and "Automatic rate: off" or "Automatic rate: on"))
	end
	local baseEvent = spec.actionEvents[InputAction.VTSZ_AUTO_BASE]
	if baseEvent ~= nil then
		g_inputBinding:setActionEventActive(baseEvent.actionEventId, numBases >= 2 and fillTypeIndex ~= FillType.UNKNOWN)
		local baseId = numBases >= 2 and self:vtszGetAutoBase(fillTypeIndex) or "-"
		g_inputBinding:setActionEventText(baseEvent.actionEventId, string.format(VtszNutrients:getText("vtsz_action_auto_base", "Automatic rate base: %s"), baseId))
	end
	local active = controlled
	for _, def in ipairs(VtszSprayer.RATE_ACTIONS) do
		local action = InputAction[def.name]
		local actionEvent = action ~= nil and spec.actionEvents[action] or nil
		if actionEvent ~= nil then
			g_inputBinding:setActionEventActive(actionEvent.actionEventId, active)
		end
	end
end

function VtszSprayer:actionEventChangeRate(actionName, inputValue, direction, isAnalog)
	local fillTypeIndex = self:vtszGetCurrentFillType()
	if not VtszNutrients:isRateControlled(fillTypeIndex) then
		return
	end
	local config = VtszNutrients:getRateConfig(fillTypeIndex)
	self:vtszSetRate(fillTypeIndex, self:vtszGetRate(fillTypeIndex) + (direction or 1) * config.step)
end

-- the nominal working width the usage of the sprayer is based on (the same one PF's usage formula takes). The width of the
-- spray work area itself is not usable: spreaders change it with the speed (13 .. 22 m in the log), which inflated the dose.
function VtszSprayer:vtszGetUsageWidth()
	local specSpray = self.spec_sprayer
	if specSpray == nil then
		return nil
	end
	local usageScale = specSpray.usageScale
	local activeSprayType = self:getActiveSprayType()
	if activeSprayType ~= nil then
		usageScale = activeSprayType.usageScale
	end
	if usageScale == nil then
		return nil
	end
	if usageScale.workAreaIndex ~= nil then
		return self:getWorkAreaWidth(usageScale.workAreaIndex)
	end
	return usageScale.workingWidth
end

-- true when this mod computes the usage of the fill type from its own rate (getSprayerUsage below, no PF nozzle alpha).
-- Optional hook for other mods (e.g. Manual Section Control) that scale usage themselves; they check it with ~= nil.
function VtszSprayer:vtszIsRateControlled(fillType)
	return VtszNutrients:isRateControlled(fillType)
end

-- usage that follows from the rate: same formula as PF (l/ha x area per update)
function VtszSprayer:getSprayerUsage(superFunc, fillType, dt)
	local usage = superFunc(self, fillType, dt)
	if fillType ~= FillType.UNKNOWN and self:getIsTurnedOn() and VtszNutrients:isRateControlled(fillType) then
		local workWidth = self:vtszGetUsageWidth()
		if workWidth ~= nil then
			local lastSpeed = math.max(self:getLastSpeed(), 1)
			usage = self:vtszGetEffectiveRate(fillType) * (lastSpeed / 3600) / (10000 / workWidth) * dt
		end
	end
	return usage
end

----------------------------------------------------------------------------------------------------
-- HUD, two lines: l/ha, then N / P2O5 / K2O kg/ha. Shown whenever the sprayer is attached to the controlled vehicle (or is
-- the controlled vehicle), also with the implement off.
----------------------------------------------------------------------------------------------------

-- rate for the HUD: l/ha (nil = no HUD), the auto base nutrient (nil = manual rate), true when auto is on but has no data
-- and the manual rate is shown instead
function VtszSprayer:vtszGetHudRate(fillTypeIndex)
	local spec = self[VtszSprayer.SPEC_TABLE_NAME]
	if VtszNutrients:isRateControlled(fillTypeIndex) then
		local baseId = spec.autoOn and self:vtszGetAutoBase(fillTypeIndex) or nil
		return self:vtszGetEffectiveRate(fillTypeIndex), baseId, baseId ~= nil and spec.autoRate == nil
	end
	-- PF managed product
	local pfSpec = self:vtszGetPFSpec()
	if pfSpec == nil or not pfSpec.isFertilizing then
		return nil
	end
	local baseId = pfSpec.sprayAmountAutoMode and self:vtszGetAutoBase(fillTypeIndex) or nil
	if self:getIsTurnedOn() and pfSpec.lastLitersPerHectar > 0 then
		return pfSpec.lastLitersPerHectar, baseId, false
	end
	if baseId == "P" or baseId == "K" then
		if spec.autoRate ~= nil then
			return spec.autoRate, baseId, false
		end
		return self:vtszGetPFIdleRate(pfSpec, fillTypeIndex), baseId, true
	end
	return self:vtszGetPFIdleRate(pfSpec, fillTypeIndex), baseId, false
end

-- VtszNutrients:getPFIdleLitersPerHa, recomputed only when one of its inputs changed
function VtszSprayer:vtszGetPFIdleRate(pfSpec, fillTypeIndex)
	local spec = self[VtszSprayer.SPEC_TABLE_NAME]
	if spec.idleFillType ~= fillTypeIndex or spec.idleAuto ~= pfSpec.sprayAmountAutoMode or spec.idleManual ~= pfSpec.sprayAmountManual
		or spec.idleActual ~= pfSpec.nActualValue or spec.idleTarget ~= pfSpec.nTargetValue then
		spec.idleFillType = fillTypeIndex
		spec.idleAuto = pfSpec.sprayAmountAutoMode
		spec.idleManual = pfSpec.sprayAmountManual
		spec.idleActual = pfSpec.nActualValue
		spec.idleTarget = pfSpec.nTargetValue
		spec.idleLiters = VtszNutrients:getPFIdleLitersPerHa(pfSpec, fillTypeIndex)
	end
	return spec.idleLiters
end

-- work areas that spray: sprayer, fertilizing cultivator, fertilizing sowing machine
function VtszSprayer.isSprayWorkAreaType(areaType)
	return areaType == WorkAreaType.SPRAYER or areaType == WorkAreaType.CULTIVATOR or areaType == WorkAreaType.SOWINGMACHINE
end

function VtszSprayer.hasSprayerWorkArea(vehicle)
	local workAreas = vehicle.spec_workArea ~= nil and vehicle.spec_workArea.workAreas or {}
	for _, area in ipairs(workAreas) do
		if VtszSprayer.isSprayWorkAreaType(area.type) then
			return true
		end
	end
	return false
end

function VtszSprayer:onUpdate(dt,isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	-- a product change in a source vehicle (tank) raises no event on the tool
	VtszSprayer.syncFillType(self, self:vtszGetCurrentFillType())
	self:vtszUpdateAutoRate()
	self.vtszHudLines = nil
	if not self.isClient or not isActiveForInputIgnoreSelection then
		return
	end
	-- a tank without own spray work areas (slurry tanker that feeds a distributor) shows nothing: the tool carries the rate
	if not VtszSprayer.hasSprayerWorkArea(self) then
		return
	end
	local fillTypeIndex = self:vtszGetCurrentFillType()
	if fillTypeIndex == nil or fillTypeIndex == FillType.UNKNOWN then
		return
	end
	local litersPerHa, baseId, noData = self:vtszGetHudRate(fillTypeIndex)
	if litersPerHa == nil then
		return
	end
	local nitrogen, phosphorus, potassium = VtszNutrients:getNutrientsPerHa(fillTypeIndex, litersPerHa)
	if nitrogen + phosphorus + potassium <= 0 and litersPerHa > 0 then
		return -- product without nutrients
	end
	local autoNote = ""
	if baseId ~= nil then
		local key = noData and "vtsz_hud_auto_nodata" or "vtsz_hud_auto"
		autoNote = string.format(VtszNutrients:getText(key, " (auto %s)"), baseId)
	end
	local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
	self.vtszHudLines = {
		string.format(VtszNutrients:getText("vtsz_hud_rate", "%s: %d l/ha"), fillType.title, litersPerHa) .. autoNote,
		string.format(VtszNutrients:getText("vtsz_hud_npk", "N %d | P2O5 %d | K2O %d kg/ha"), nitrogen, phosphorus, potassium)
	}
	local inputHelp = g_currentMission.hud.inputHelp
	if inputHelp:getVisible() then
		-- help menu open: lines go into its extra text area
		for _, line in ipairs(self.vtszHudLines) do
			g_currentMission:addExtraPrintText(line)
		end
	elseif VtszSprayer.isPFHelpDrawActive() then
		-- collapsed: join PF's help extension list (PF draws it and clears it every frame), lowest priority = below PF's box
		VtszSprayer.hudExtension.lines = self.vtszHudLines
		for _, extension in ipairs(inputHelp.helpExtensions) do
			if extension == VtszSprayer.hudExtension then
				return
			end
		end
		table.insert(inputHelp.helpExtensions, VtszSprayer.hudExtension)
	end
end

-- PF replaces InputHelpDisplay.draw when its own setting is on; only then the extension list is drawn while collapsed
function VtszSprayer.isPFHelpDrawActive()
	local pfEnv = _G["FS25_precisionFarming"]
	local pf = pfEnv ~= nil and pfEnv.g_precisionFarming or nil
	return pf ~= nil and pf.inputHelpDisplayExtension ~= nil and pf.inputHelpDisplayExtension.isEnabled == true
end

VtszSprayer.hudExtension = {
	priority = GS_PRIO_VERY_LOW,
	lines = nil,
	getHeight = function(self)
		local inputHelp = g_currentMission.hud.inputHelp
		local count = self.lines ~= nil and #self.lines or 0
		return count * (inputHelp.lineBg.height + inputHelp.lineOffsetY)
	end,
	draw = function(self, inputHelp, posX, posY)
		for _, line in ipairs(self.lines or {}) do
			posY = inputHelp:drawExtraText(posX, posY, line) - inputHelp.lineOffsetY
		end
		return posY + inputHelp.lineOffsetY
	end
}

-- PF HUD setting off: no extension list while collapsed, draw directly below the vehicle schema bar
function VtszSprayer:onDraw(isActiveForInput, isActiveForInputIgnoreSelection)
	local lines = self.vtszHudLines
	local inputHelp = g_currentMission ~= nil and g_currentMission.hud ~= nil and g_currentMission.hud.inputHelp or nil
	if lines == nil or inputHelp == nil or inputHelp:getVisible() or VtszSprayer.isPFHelpDrawActive() then
		return
	end
	local posX, posY = inputHelp:getPosition()
	if inputHelp.vehicle ~= nil and inputHelp.vehicle.schemaOverlay ~= nil then
		posY = posY - inputHelp.lineBg.height - inputHelp.lineOffsetY
	end
	for _, line in ipairs(lines) do
		posY = inputHelp:drawExtraText(posX, posY, line) - inputHelp.lineOffsetY
	end
end

----------------------------------------------------------------------------------------------------
-- Spreading: P2O5, K2O, OM into the maps (server)
----------------------------------------------------------------------------------------------------

local function getWidth(workArea)
	local sx, _, sz = getWorldTranslation(workArea.start)
	local wx, _, wz = getWorldTranslation(workArea.width)
	return MathUtil.vector2Length(wx - sx, wz - sz)
end

function VtszSprayer:vtszApplyNutrients(workArea, dt)
	local params = self.spec_sprayer.workAreaParameters
	if params.sprayFillLevel == nil or params.sprayFillLevel <= 0 then
		return
	end
	local fillTypeIndex = params.sprayFillType
	if fillTypeIndex == nil or fillTypeIndex == FillType.UNKNOWN or not VtszNutrients:isNutrientFillType(fillTypeIndex) then
		return
	end
	local usage = params.usage
	local speed = self:getLastSpeed()
	if usage == nil or usage <= 0 or speed == nil or speed < 0.5 or dt <= 0 then
		return
	end

	-- the nominal working width of the usage formula, so the dose per ha equals the application rate (not the momentary
	-- width of the work area, which a spreader changes with its speed)
	local totalWidth = self:vtszGetUsageWidth()
	if totalWidth == nil or totalWidth <= 0 then
		totalWidth = getWidth(workArea)
	end
	if totalWidth <= 0 then
		return
	end

	-- Manual Section Control (optional mod): params.usage already carries its active-width fraction, so scale the
	-- width the same way and the dose per ha stays equal to the application rate. No-op without that mod.
	if self.getManualSectionActiveFraction ~= nil then
		totalWidth = totalWidth * math.max(self:getManualSectionActiveFraction(), 0.0001)
	end

	-- application rate: liters this frame / area covered this frame
	local litersPerSecond = usage / (dt * 0.001)
	local hectarePerSecond = totalWidth * (speed / 3.6) / 10000
	local litersPerHa = litersPerSecond / hectarePerSecond
	VtszNutrients.debugWidth = totalWidth

	local sx, _, sz = getWorldTranslation(workArea.start)
	local wx, _, wz = getWorldTranslation(workArea.width)
	local hx, _, hz = getWorldTranslation(workArea.height)
	if VtszSprayer.shape == nil then
		VtszSprayer.shape = DensityMapParallelogram.new()
	end
	VtszSprayer.shape:updateFromWorldPositions(sx, sz, wx, wz, hx, hz)
	-- a fertilizing cultivator / sowing machine writes SprayType.FERTILIZER to the ground whatever it sprays
	local groundSprayType = (workArea.type == WorkAreaType.CULTIVATOR or workArea.type == WorkAreaType.SOWINGMACHINE) and SprayType ~= nil and SprayType.FERTILIZER or nil
	-- a pass ends when this sprayer has not dosed for a while; a pixel is dosed once per pass (see VtszNutrients:applySpray)
	local spec = self[VtszSprayer.SPEC_TABLE_NAME]
	local now = g_time or 0
	if spec.passId == nil or now - (spec.passLastTime or 0) > VtszNutrients.PASS_GAP_MS then
		spec.passId = VtszNutrients.nextPassId()
	end
	spec.passLastTime = now
	VtszNutrients:applySpray(VtszSprayer.shape, params.sprayType, fillTypeIndex, litersPerHa, groundSprayType, spec.passId)
end

function VtszSprayer:processSprayerArea(superFunc, workArea, dt)
	VtszSprayer.applyNutrientsSafe(self, workArea, dt)
	return superFunc(self, workArea, dt)
end

function VtszSprayer:processCultivatorArea(superFunc, workArea, dt)
	local spec = self.spec_fertilizingCultivator
	-- same gate as FertilizingCultivator: spraying only when turned on (if the vehicle requires it)
	if spec ~= nil and not (spec.needsSetIsTurnedOn and not self:getIsTurnedOn()) then
		VtszSprayer.applyNutrientsSafe(self, workArea, dt)
	end
	return superFunc(self, workArea, dt)
end

function VtszSprayer:processSowingMachineArea(superFunc, workArea, dt)
	local spec = self.spec_fertilizingSowingMachine
	local sowingParams = self.spec_sowingMachine.workAreaParameters
	-- same gate as FertilizingSowingMachine: sprays only while sowing, and when turned on (if the vehicle requires it)
	if spec ~= nil and sowingParams.isActive and sowingParams.canFruitBePlanted and not (spec.needsSetIsTurnedOn and not self:getIsTurnedOn()) then
		VtszSprayer.applyNutrientsSafe(self, workArea, dt)
	end
	return superFunc(self, workArea, dt)
end

function VtszSprayer.applyNutrientsSafe(vehicle, workArea, dt)
	if vehicle.isServer then
		local ok, err = pcall(VtszSprayer.vtszApplyNutrients, vehicle, workArea, dt)
		if not ok and not VtszSprayer.errorLogged then
			VtszSprayer.errorLogged = true
			Logging.error("[VTSZ-NUT] spreading failed: %s", tostring(err))
		end
	end
end
