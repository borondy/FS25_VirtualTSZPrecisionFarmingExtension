-- Admin console commands in multiplayer. A client registers the command, the master user (admin) sends it
-- to the server, the server checks the sender, runs it and answers with a result line.
-- Request (client -> server): command name + up to 3 string arguments. Reply (server -> client): text only.
VtszAdminCommandEvent = {}
local VtszAdminCommandEvent_mt = Class(VtszAdminCommandEvent, Event)
InitEventClass(VtszAdminCommandEvent, "VtszAdminCommandEvent")

function VtszAdminCommandEvent.emptyNew()
	return Event.new(VtszAdminCommandEvent_mt)
end

function VtszAdminCommandEvent.new(command, args, replyText)
	local self = VtszAdminCommandEvent.emptyNew()
	self.command = command -- "set" | "debug", nil in a reply
	self.args = args or {}
	self.replyText = replyText -- set in a reply
	return self
end

function VtszAdminCommandEvent:readStream(streamId, connection)
	if streamReadBool(streamId) then
		self.replyText = streamReadString(streamId)
	else
		self.command = streamReadString(streamId)
		self.args = {}
		for i = 1, streamReadUIntN(streamId, 2) do
			self.args[i] = streamReadString(streamId)
		end
	end
	self:run(connection)
end

function VtszAdminCommandEvent:writeStream(streamId, connection)
	local isReply = self.replyText ~= nil
	streamWriteBool(streamId, isReply)
	if isReply then
		streamWriteString(streamId, self.replyText)
	else
		streamWriteString(streamId, self.command)
		local count = math.min(#self.args, 3)
		streamWriteUIntN(streamId, count, 2)
		for i = 1, count do
			streamWriteString(streamId, tostring(self.args[i]))
		end
	end
end

function VtszAdminCommandEvent:run(connection)
	if self.replyText ~= nil then
		-- server -> client
		if connection:getIsServer() then
			print(self.replyText)
		end
		return
	end
	if connection:getIsServer() then
		return -- a request never goes server -> client
	end
	-- client -> server: only the local host or a logged-in admin may run it
	local isAdmin = connection:getIsLocal() or g_currentMission.userManager:getIsConnectionMasterUser(connection)
	local text
	if not isAdmin then
		text = "vtsz: admin login required"
	else
		text = VtszNutrients:runAdminCommand(self.command, self.args[1], self.args[2], self.args[3])
	end
	connection:sendEvent(VtszAdminCommandEvent.new(nil, nil, text))
end

-- client side entry: returns the line for the console
function VtszAdminCommandEvent.sendRequest(command, ...)
	if not g_currentMission.isMasterUser then
		return "Admin login required (open the game menu, Settings, Admin login)"
	end
	g_client:getServerConnection():sendEvent(VtszAdminCommandEvent.new(command, {...}))
	return "Sent to the server, the result follows"
end
