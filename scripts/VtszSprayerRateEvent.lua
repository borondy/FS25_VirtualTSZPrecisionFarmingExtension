-- Syncs the application rate (l/ha) of a sprayer / spreader for products Precision Farming does not manage.
VtszSprayerRateEvent = {}
local VtszSprayerRateEvent_mt = Class(VtszSprayerRateEvent, Event)
InitEventClass(VtszSprayerRateEvent, "VtszSprayerRateEvent")

function VtszSprayerRateEvent.emptyNew()
	return Event.new(VtszSprayerRateEvent_mt)
end

function VtszSprayerRateEvent.new(vehicle, fillTypeIndex, litersPerHa)
	local self = VtszSprayerRateEvent.emptyNew()
	self.vehicle = vehicle
	self.fillTypeIndex = fillTypeIndex
	self.litersPerHa = litersPerHa
	return self
end

function VtszSprayerRateEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.fillTypeIndex = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)
	self.litersPerHa = streamReadUIntN(streamId, 12)
	self:run(connection)
end

function VtszSprayerRateEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteUIntN(streamId, self.fillTypeIndex, FillTypeManager.SEND_NUM_BITS)
	streamWriteUIntN(streamId, self.litersPerHa, 12)
end

function VtszSprayerRateEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.vehicle)
	end
	if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
		self.vehicle:vtszSetRate(self.fillTypeIndex, self.litersPerHa, true)
	end
end

function VtszSprayerRateEvent.sendEvent(vehicle, fillTypeIndex, litersPerHa, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(VtszSprayerRateEvent.new(vehicle, fillTypeIndex, litersPerHa), nil, nil, vehicle)
			return
		end
		g_client:getServerConnection():sendEvent(VtszSprayerRateEvent.new(vehicle, fillTypeIndex, litersPerHa))
	end
end
