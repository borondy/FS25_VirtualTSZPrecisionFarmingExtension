-- Syncs the automatic rate state (on/off and base nutrient) of a sprayer / spreader: see VtszSprayer.
VtszSprayerAutoEvent = {}
local VtszSprayerAutoEvent_mt = Class(VtszSprayerAutoEvent, Event)
InitEventClass(VtszSprayerAutoEvent, "VtszSprayerAutoEvent")

function VtszSprayerAutoEvent.emptyNew()
	return Event.new(VtszSprayerAutoEvent_mt)
end

function VtszSprayerAutoEvent.new(vehicle, autoOn, baseId)
	local self = VtszSprayerAutoEvent.emptyNew()
	self.vehicle = vehicle
	self.autoOn = autoOn
	self.baseId = baseId
	return self
end

-- base nutrient on the wire: 0 = default (highest content), 1 = N, 2 = P, 3 = K
function VtszSprayerAutoEvent.baseToIndex(baseId)
	for i, id in ipairs(VtszNutrients.AUTO_BASES) do
		if id == baseId then
			return i
		end
	end
	return 0
end

function VtszSprayerAutoEvent.indexToBase(index)
	return VtszNutrients.AUTO_BASES[index]
end

function VtszSprayerAutoEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.autoOn = streamReadBool(streamId)
	self.baseId = VtszSprayerAutoEvent.indexToBase(streamReadUIntN(streamId, 2))
	self:run(connection)
end

function VtszSprayerAutoEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteBool(streamId, self.autoOn)
	streamWriteUIntN(streamId, VtszSprayerAutoEvent.baseToIndex(self.baseId), 2)
end

function VtszSprayerAutoEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.vehicle)
	end
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		self.vehicle:vtszSetAuto(self.autoOn, self.baseId, true)
	end
end

function VtszSprayerAutoEvent.sendEvent(vehicle, autoOn, baseId, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(VtszSprayerAutoEvent.new(vehicle, autoOn, baseId), nil, nil, vehicle)
			return
		end
		g_client:getServerConnection():sendEvent(VtszSprayerAutoEvent.new(vehicle, autoOn, baseId))
	end
end
