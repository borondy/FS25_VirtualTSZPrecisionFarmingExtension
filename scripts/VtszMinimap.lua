-- Minimap layer while spreading (client).
-- Default: the layer of the nutrient with the largest content per 1000 l of the product (N, P2O5, K2O; organic fertilizers
-- show N, config <minimap>). VtszMinimap:cycle() (key VTSZ_MINIMAP_LAYER) pages through AUTO > N > P > K > OM.
-- Uses PF's own mechanism: the value map that has requireMinimapDisplay is drawn on the minimap by InGameMapExtension.

VtszMinimap = {}
VtszMinimap.ORDER = { "AUTO", "N", "P", "K", "OM" }
VtszMinimap.index = 1
VtszMinimap.lastFillType = nil
VtszMinimap.lastVehicle = nil
VtszMinimap.messageTimer = 0

local DEFAULT_TEXTS = {
	AUTO = "Auto",
	N = "Nitrogen",
	P = "Phosphorus",
	K = "Potassium",
	OM = "Organic matter",
}

local function getControlledVehicle()
	local vehicle = nil
	if g_localPlayer ~= nil and g_localPlayer.getCurrentVehicle ~= nil then
		vehicle = g_localPlayer:getCurrentVehicle()
	end
	if vehicle == nil and g_currentMission ~= nil then
		vehicle = g_currentMission.controlledVehicle
	end
	return vehicle
end

-- first sprayer / spreader of the controlled vehicle chain with product, on a field
local function findActiveSprayer()
	local controlled = getControlledVehicle()
	if controlled == nil or controlled.getChildVehicles == nil then
		return nil, nil
	end
	for _, vehicle in ipairs(controlled:getChildVehicles()) do
		if vehicle.spec_sprayer ~= nil and vehicle.getSprayerFillUnitIndex ~= nil then
			local source, fillUnitIndex = VtszSprayer.resolveFillSource(vehicle)
			if source ~= nil and fillUnitIndex ~= nil and source:getFillUnitFillLevel(fillUnitIndex) > 0 then
				local fillType = source:getFillUnitFillType(fillUnitIndex)
				if fillType ~= nil and fillType ~= FillType.UNKNOWN then
					local isOnField = true
					if vehicle.getPFStatisticInfo ~= nil then
						local ok, _, _, _, onField = pcall(vehicle.getPFStatisticInfo, vehicle)
						if ok then
							isOnField = onField == true
						end
					end
					if isOnField then
						return vehicle, fillType
					end
				end
			end
		end
	end
	return nil, nil
end

function VtszMinimap.getMapById(layerId)
	if layerId == "N" then
		return VtszNutrients.pf.nitrogenMap
	end
	for _, map in ipairs(VtszNutrients.maps) do
		if map.nutrientId == layerId then
			return map
		end
	end
	return nil
end

-- layer by the largest nutrient content per 1000 l; N wins ties (NPK 15-15-15), P wins over K (NPK 8-24-24)
function VtszMinimap.getAutoLayer(fillTypeIndex)
	local name = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)
	local forced = name ~= nil and VtszConfig.minimapMaps[name] or nil
	if forced ~= nil then
		return forced
	end
	local nitrogen, phosphorus, potassium = VtszNutrients:getNutrientsPerHa(fillTypeIndex, 1000)
	if nitrogen <= 0 and phosphorus <= 0 and potassium <= 0 then
		return nil
	end
	local best, value = "N", nitrogen
	if phosphorus > value then
		best, value = "P", phosphorus
	end
	if potassium > value then
		best = "K"
	end
	return best
end

function VtszMinimap:getLayerText(layerId)
	return VtszNutrients:getText("vtsz_minimap_" .. layerId, DEFAULT_TEXTS[layerId] or layerId)
end

function VtszMinimap:cycle()
	self.index = self.index % #self.ORDER + 1
	self.messageTimer = 3000
end

-- PF's ExtendedSprayer asks for N / pH every frame and our update turns it off again, so the layers flickered.
-- While one of our layers (or explicit non-N) is wanted, ignore PF's "show" requests for N and pH.
function VtszMinimap.installGuard(pf)
	if VtszMinimap.guardInstalled then
		return
	end
	for _, map in ipairs({ pf.nitrogenMap, pf.pHMap }) do
		local original = map.setRequireMinimapDisplay
		map.setRequireMinimapDisplay = function(self, state, sourceObject, isSelected)
			if state and VtszMinimap.blockPFLayers then
				return
			end
			return original(self, state, sourceObject, isSelected)
		end
	end
	VtszMinimap.guardInstalled = true
end

function VtszMinimap:update(dt)
	local pf = VtszNutrients.pf
	if pf == nil then
		return
	end
	if pf.nitrogenMap ~= nil and pf.pHMap ~= nil then
		VtszMinimap.installGuard(pf)
	end
	local vehicle, fillType = findActiveSprayer()

	local layerId, explicit = nil, false
	if vehicle ~= nil then
		if fillType ~= self.lastFillType then
			self.index = 1
			self.lastFillType = fillType
		end
		local choice = self.ORDER[self.index]
		explicit = choice ~= "AUTO"
		layerId = explicit and choice or VtszMinimap.getAutoLayer(fillType)
	else
		self.lastFillType = nil
	end

	VtszMinimap.blockPFLayers = vehicle ~= nil and layerId ~= nil and layerId ~= "N"

	-- our layers: on for the wanted one, off for the others (only what we switched on, source = vehicle)
	for _, map in ipairs(VtszNutrients.maps) do
		if vehicle ~= nil and layerId == map.nutrientId then
			map:setRequireMinimapDisplay(true, vehicle, vehicle:getIsSelected())
		elseif self.lastVehicle ~= nil then
			map:setRequireMinimapDisplay(false, self.lastVehicle)
		end
	end

	if vehicle ~= nil and layerId ~= nil then
		if layerId == "N" then
			-- PF shows N for fertilizing sprayers by itself; ask for it when the player paged to N
			if explicit and pf.nitrogenMap ~= nil then
				pf.nitrogenMap:setRequireMinimapDisplay(true, vehicle, vehicle:getIsSelected())
			end
		else
			-- one of ours: take N and pH off the minimap (PF asks for them from its own sprayer events)
			if pf.nitrogenMap ~= nil then
				pf.nitrogenMap:setRequireMinimapDisplay(false, vehicle)
			end
			if pf.pHMap ~= nil then
				pf.pHMap:setRequireMinimapDisplay(false, vehicle)
			end
		end
	end
	self.lastVehicle = vehicle

	if self.messageTimer > 0 then
		self.messageTimer = self.messageTimer - dt
		if vehicle ~= nil then
			local shown = layerId ~= nil and self:getLayerText(layerId) or self:getLayerText("AUTO")
			local prefix = VtszNutrients:getText("vtsz_minimap_layer", "Minimap layer")
			local suffix = self.ORDER[self.index] == "AUTO" and (" (" .. self:getLayerText("AUTO") .. ")") or ""
			g_currentMission:addExtraPrintText(string.format("%s: %s%s", prefix, shown, suffix))
		end
	end
end
