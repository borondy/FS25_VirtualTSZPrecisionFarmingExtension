-- Dev profiler (console only, optional file). Absent or broken: the mod runs the same.
-- Wraps the hot paths while a measurement runs and restores the originals on stop, so idle cost is zero.
--   vtszPerf start [label]   begin a measurement (wraps the targets)
--   vtszPerf stop            end it, restore originals, log the report
--   vtszPerf report          log the current numbers without stopping
--   vtszPerf reset           zero the counters, keep measuring
-- Numbers compare runs of the same scenario; the wrapper adds a small cost of its own.
-- "alloc" sums positive Lua memory growth per call (KB): approximate garbage, GC runs can hide some of it.

VtszProfiler = {}
VtszProfiler.running = false
VtszProfiler.label = ""

local clock = (os ~= nil and os.clock) or nil -- CPU seconds, fine resolution; fallback: engine clock
local function now()
	if clock ~= nil then
		return clock()
	end
	return getTimeSec()
end

local function logInfo(fmt, ...)
	Logging.info("[VTSZ-PERF] " .. fmt, ...)
end

-- Targets: name, function returning the owner table, key. Resolved when the measurement starts.
-- Methods called through the instance/metatable or looked up by name per call are found by replacing the field on the owner.
local TARGETS = {
	{ "Perf1 VtszMinimap:update", function() return VtszMinimap end, "update" },
	{ "Perf2 VtszSprayer:onUpdate (incl. vtszUpdateAutoRate)", function() return VtszSprayer end, "onUpdate" },
	{ "Perf2 VtszSprayer:onDraw (HUD)", function() return VtszSprayer end, "onDraw" },
	{ "Perf3 VtszSprayer.vtszApplyNutrients", function() return VtszSprayer end, "vtszApplyNutrients" },
	{ "Perf3 VtszNutrients:applySpray", function() return VtszNutrients end, "applySpray" },
	{ "Perf3 sub NutrientMap:addUnitsAtArea (inside applySpray)", function() return NutrientMap end, "addUnitsAtArea" },
	{ "Perf3 sub VtszNutrients:getLockData (inside applySpray)", function() return VtszNutrients end, "getLockData" },
	{ "Perf3 sub NutrientMap:getUnitsForFillType (inside applySpray)", function() return NutrientMap end, "getUnitsForFillType" },
	{ "Perf4 VtszNutrients:onHarvestUpdate", function() return VtszNutrients end, "onHarvestUpdate" },
	{ "Perf4 NutrientMap:harvestUpdate", function() return NutrientMap end, "harvestUpdate" },
	{ "Perf4 NutrientMap:getHarvestMultiModifier", function() return NutrientMap end, "getHarvestMultiModifier" },
	{ "Perf4 VtszNutrients.combineFactors", function() return VtszNutrients end, "combineFactors" },
	{ "Perf4 VtszNutrients:collectFactors", function() return VtszNutrients end, "collectFactors" },
	{ "Perf5 VtszNutrients:getAutoRateAt (inside vtszUpdateAutoRate)", function() return VtszNutrients end, "getAutoRateAt" },
	{ "Perf6 VtszNutrients:preDestroy (catch crop)", function() return VtszNutrients end, "preDestroy" },
	{ "Perf6 VtszNutrients:postDestroy (catch crop)", function() return VtszNutrients end, "postDestroy" },
	{ "Perf6 sub NutrientMap:addUnitsFromMask (inside postDestroy)", function() return NutrientMap end, "addUnitsFromMask" },
	{ "Perf6 FSDensityMapUtil.updateMulcherArea (mulcher hook, server)", function() return FSDensityMapUtil end, "updateMulcherArea" },
}
-- Not in the table, probed at their registration because the engine stores them by reference (count only while running):
--   "Perf2 VtszSprayer:vtszUpdateAutoRate" (VtszSprayer.lua, vehicle function table)
--   "Perf5 NutrientMap:updateFieldInfoDisplay" (NutrientMap:collectFieldInfos, PF field info row)

VtszProfiler.stats = {}
VtszProfiler.patched = {} -- { owner, key, original }
VtszProfiler.startTime = 0

local function newStat(name)
	return { name = name, calls = 0, total = 0, max = 0, alloc = 0 }
end

local function finish(stat, t0, m0, ...)
	local dt = now() - t0
	local dm = collectgarbage("count") - m0
	stat.calls = stat.calls + 1
	stat.total = stat.total + dt
	if dt > stat.max then
		stat.max = dt
	end
	if dm > 0 then
		stat.alloc = stat.alloc + dm
	end
	return ...
end

local function makeWrapper(stat, fn)
	return function(...)
		return finish(stat, now(), collectgarbage("count"), fn(...))
	end
end

-- Hook for instance functions that other code stores by reference (cannot be swapped later): always wrapped, counts only while running.
function VtszProfiler.probe(name, fn)
	return function(...)
		if not VtszProfiler.running then
			return fn(...)
		end
		-- looked up per call: start() replaces the stats table
		return finish(VtszProfiler.getStat(name), now(), collectgarbage("count"), fn(...))
	end
end

function VtszProfiler.getStat(name)
	local stat = VtszProfiler.stats[name]
	if stat == nil then
		stat = newStat(name)
		VtszProfiler.stats[name] = stat
	end
	return stat
end

function VtszProfiler:reset()
	for _, stat in pairs(self.stats) do
		stat.calls, stat.total, stat.max, stat.alloc = 0, 0, 0, 0
	end
	self.startTime = now()
end

function VtszProfiler:start(label)
	if self.running then
		return "Already running (label '" .. self.label .. "'). Use vtszPerf stop first."
	end
	self.label = label or ""
	self.stats = {}
	self.patched = {}
	local missing = {}
	for _, target in ipairs(TARGETS) do
		local name, ownerFn, key = target[1], target[2], target[3]
		local owner = ownerFn()
		if owner ~= nil and type(owner[key]) == "function" then
			local original = owner[key]
			owner[key] = makeWrapper(self.getStat(name), original)
			table.insert(self.patched, { owner = owner, key = key, original = original })
		else
			table.insert(missing, name)
		end
	end
	self.running = true
	self.startTime = now()
	local text = string.format("Profiling started, label '%s', %d targets wrapped", self.label, #self.patched)
	if #missing > 0 then
		text = text .. ". Not found: " .. table.concat(missing, "; ")
	end
	return text
end

function VtszProfiler:report()
	local elapsed = now() - self.startTime
	if elapsed <= 0 then
		elapsed = 1e-9
	end
	local names = {}
	for name in pairs(self.stats) do
		table.insert(names, name)
	end
	table.sort(names)
	logInfo("---- label '%s', %.1f s ----", self.label, elapsed)
	logInfo("function | calls | calls/s | avg ms | max ms | total ms/s | alloc KB/s")
	for _, name in ipairs(names) do
		local s = self.stats[name]
		local avg = s.calls > 0 and (s.total / s.calls) * 1000 or 0
		logInfo("%s | %d | %.1f | %.4f | %.3f | %.3f | %.2f", name, s.calls, s.calls / elapsed, avg, s.max * 1000, s.total * 1000 / elapsed, s.alloc / elapsed)
	end
	return "Report written to log.txt ([VTSZ-PERF])"
end

function VtszProfiler:stop()
	if not self.running then
		return "Not running."
	end
	for i = #self.patched, 1, -1 do
		local p = self.patched[i]
		p.owner[p.key] = p.original
	end
	self.patched = {}
	local result = self:report()
	self.running = false
	return result
end

function VtszProfiler:consoleRun(command, label)
	command = command and command:lower() or ""
	if command == "start" then
		return self:start(label)
	elseif command == "stop" then
		return self:stop()
	elseif command == "report" then
		return self:report()
	elseif command == "reset" then
		self:reset()
		return "Counters reset."
	end
	return "Usage: vtszPerf start [label] | stop | report | reset"
end

function VtszProfiler:register()
	addConsoleCommand("vtszPerf", "Profiles the hot paths of the mod, result in log.txt", "consoleRun", self, "start [label]|stop|report|reset")
end

function VtszProfiler:unregister()
	if self.running then
		self:stop()
	end
	removeConsoleCommand("vtszPerf")
end
