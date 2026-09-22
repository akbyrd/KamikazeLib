local ADDON = ...
local Kami = select(2, ...)
local Perf = {}
Kami.Perf = Perf

local Config = Kami.Config
local Util   = Kami.Util

-- NOTE: Throwaway measurement harness for two questions: what a config read costs, and how often
-- one actually happens. Nothing in production calls into this file. It counts events on a frame of
-- its own so CDM's handlers stay untouched. Run from a macro:
--   /run Kami.Perf.Lookup()     price a flat read against a metatable chain read
--   /run Kami.Perf.Baseline()   what the addon costs against all addons and the whole application
--   /run Kami.Perf.Rates()      event rates, and the config reads per second they imply
--   /run Kami.Perf.ResetRates() restart the rate window

local READS      = 100000 -- table reads per sample
local SAMPLES    = 7      -- samples per arm; the minimum is reported
local DECOY_KEYS = 8      -- filler keys so no node is measured with an empty hash part

local function Print(fmt, ...)
	print("|cff7373f2KL Perf|r " .. fmt:format(...))
end

----------------------------------------------------------------------------------------------------
-- Lookup cost

-- NOTE: sink is accumulated and stored so the read cannot be discarded, and the accumulate costs
-- the same in every arm including the control. The control reads a parameter instead of a table, so
-- subtracting it leaves the lookup alone.
local benchmark = {}

function benchmark:OnStart(iterationCount) end
function benchmark:OnFinish(iterationCount, benchmarkResults) end

function benchmark:OnIterationStart(iteration, iterationCount)
	collectgarbage("collect")
	collectgarbage("stop")
end

function benchmark:OnIterationFinish(iteration, iterationCount, iterationResults)
	collectgarbage("restart")
end

function benchmark:RunIteration(tbl, key)
	local sink = 0
	for i = 1, READS do
		local value = tbl[key]
		if value then sink = sink + 1 end
	end
	self.sink = sink
end

local control = Util.TableShallowCopy(benchmark)

function control:RunIteration(tbl, key)
	local sink = 0
	for i = 1, READS do
		local value = key
		if value then sink = sink + 1 end
	end
	self.sink = sink
end

local function MeasureNanoseconds(bench, tbl, key)
	local results = BenchmarkUtil.RunBenchmark(bench, SAMPLES, tbl, key)
	local summary = BenchmarkUtil.SummarizeResults(results)

	local ticksPerSecond = C_AddOnProfiler.GetTicksPerSecond()
	local nanoseconds    = summary.elapsedTicks.min / ticksPerSecond * 1e9 / READS
	return nanoseconds, summary.allocatedBytes.min
end

local function BuildDecoys(tbl)
	for i = 1, DECOY_KEYS do
		tbl["decoy" .. i] = i
	end
	return tbl
end

-- depth 0 puts the key on the node itself. Each level above adds one __index hop, matching the way
-- Config chains its override nodes.
local function BuildChain(depth, key)
	local node = BuildDecoys({ [key] = "value" })
	for i = 1, depth do
		node = setmetatable(BuildDecoys({}), { __index = node })
	end
	return node
end

local function ChainDepth(node, key)
	local depth = 0
	while node do
		if rawget(node, key) ~= nil then return depth end
		local meta = getmetatable(node)
		node = meta and meta.__index
		depth = depth + 1
	end
	return nil
end

function Perf.Lookup()
	local key = "usableColor"

	local controlNs = MeasureNanoseconds(control, BuildDecoys({ [key] = "value" }), key)
	Print("loop control %.1f ns/iteration, subtracted from every figure below", controlNs)

	for depth = 0, 3 do
		local ns, bytes = MeasureNanoseconds(benchmark, BuildChain(depth, key), key)
		Print("synthetic depth %d: %5.1f ns/read, %.0f bytes allocated", depth, ns - controlNs, bytes)
	end

	-- The real tree, for a reality check on the synthetic figures. branchToTip is Config's own
	-- field; reaching into it is fine here and nowhere else.
	local CDM = Kami.CDM.Cooldowns
	if not (CDM and CDM.cfgTree) then
		Print("CDM has no config tree yet, skipping the real-tree arm")
		return
	end

	local flat  = Config.GetBranch(CDM.cfgTree, "Essential")
	local chain = CDM.cfgTree.branchToTip["Essential"]
	local depth = ChainDepth(chain, key)

	local flatNs  = MeasureNanoseconds(benchmark, flat, key)
	local chainNs = MeasureNanoseconds(benchmark, chain, key)

	Print("Essential.%s sits at chain depth %s", key, tostring(depth))
	Print("derived table  %5.1f ns/read", flatNs - controlNs)
	Print("chain          %5.1f ns/read, %+.1f ns against the derived table",
		chainNs - controlNs, chainNs - flatNs)

	local nodes, keys = 0, 0
	for node, derived in pairs(CDM.cfgTree.nodeToDerived) do
		nodes = nodes + 1
		for derivedKey in pairs(derived) do keys = keys + 1 end
	end
	Print("derived tables hold %d values across %d nodes", keys, nodes)
end

----------------------------------------------------------------------------------------------------
-- Baseline

local timeMetrics = {
	{ "SessionAverageTime",   Enum.AddOnProfilerMetric.SessionAverageTime   },
	{ "RecentAverageTime",    Enum.AddOnProfilerMetric.RecentAverageTime    },
	{ "EncounterAverageTime", Enum.AddOnProfilerMetric.EncounterAverageTime },
	{ "LastTime",             Enum.AddOnProfilerMetric.LastTime             },
	{ "PeakTime",             Enum.AddOnProfilerMetric.PeakTime             },
}

local countMetrics = {
	{ "CountTimeOver1Ms",  Enum.AddOnProfilerMetric.CountTimeOver1Ms  },
	{ "CountTimeOver5Ms",  Enum.AddOnProfilerMetric.CountTimeOver5Ms  },
	{ "CountTimeOver10Ms", Enum.AddOnProfilerMetric.CountTimeOver10Ms },
}

function Perf.Baseline()
	if not C_AddOnProfiler.IsEnabled() then
		Print("the addon profiler is disabled, so there is nothing to read")
		return
	end

	Print("%-38s %10s %10s %10s", "milliseconds per tick", ADDON, "all addons", "application")
	for i, metric in ipairs(timeMetrics) do
		local name, value = metric[1], metric[2]
		Print("%-38s %10.4f %10.4f %10.4f", name,
			C_AddOnProfiler.GetAddOnMetric(ADDON, value),
			C_AddOnProfiler.GetOverallMetric(value),
			C_AddOnProfiler.GetApplicationMetric(value))
	end

	Print("%-38s %10s %10s %10s", "tick counts since login", ADDON, "all addons", "application")
	for i, metric in ipairs(countMetrics) do
		local name, value = metric[1], metric[2]
		Print("%-38s %10.0f %10.0f %10.0f", name,
			C_AddOnProfiler.GetAddOnMetric(ADDON, value),
			C_AddOnProfiler.GetOverallMetric(value),
			C_AddOnProfiler.GetApplicationMetric(value))
	end

	Print("heaviest addons by recent average time:")
	local top = C_AddOnProfiler.GetTopKAddOnsForMetric(Enum.AddOnProfilerMetric.RecentAverageTime, 5)
	for i, result in ipairs(top) do
		Print("  %d. %-30s %8.4f ms", i, result.addOnName, result.metricValue)
	end

	UpdateAddOnMemoryUsage()
	Print("%s memory: %.0f KiB", ADDON, GetAddOnMemoryUsage(ADDON))
end

----------------------------------------------------------------------------------------------------
-- Event rates

-- NOTE: These are the events CDM refreshes on. RefreshAllUsable runs directly off
-- SPELL_UPDATE_USABLE and reads one color per cooldown frame. Cooldown work is dirty-gated through
-- OnUpdate, so its reads are capped by frame rate no matter how often the event fires.
local events = {
	"SPELL_UPDATE_USABLE",
	"SPELL_UPDATE_COOLDOWN",
	"SPELL_RANGE_CHECK_UPDATE",
	"SPELL_UPDATE_ICON",
	"SPELL_UPDATE_USES",
	"CURRENT_SPELL_CAST_CHANGED",
}

Perf.counts       = {}
Perf.combatCounts = {}

local function CombatSeconds()
	local seconds = Perf.combatTime
	if Perf.combatStart then
		seconds = seconds + GetTimePreciseSec() - Perf.combatStart
	end
	return seconds
end

function Perf.ResetRates()
	wipe(Perf.counts)
	wipe(Perf.combatCounts)
	Perf.startTime  = GetTimePreciseSec()
	Perf.combatTime = 0
	Perf.combatStart = InCombatLockdown() and Perf.startTime or nil
	Print("rate window restarted")
end

function Perf.OnEvent(frame, event)
	if event == "PLAYER_REGEN_DISABLED" then
		Perf.combatStart = GetTimePreciseSec()
	elseif event == "PLAYER_REGEN_ENABLED" then
		Perf.combatTime  = CombatSeconds()
		Perf.combatStart = nil
	else
		Perf.counts[event] = (Perf.counts[event] or 0) + 1
		if Perf.combatStart then
			Perf.combatCounts[event] = (Perf.combatCounts[event] or 0) + 1
		end
	end
end

function Perf.Rates()
	local elapsed = GetTimePreciseSec() - Perf.startTime
	local combat  = CombatSeconds()

	local frames = 0
	local CDM = Kami.CDM.Cooldowns
	if CDM and CDM.viewers then
		for category, vState in pairs(CDM.viewers) do
			frames = frames + #vState.cdFrames
		end
	end

	Print("window %.0f s, of which %.0f s in combat; %d cooldown frames", elapsed, combat, frames)
	Print("%-28s %8s %8s %8s %8s", "event", "total", "per s", "combat", "per s")
	for i, event in ipairs(events) do
		local all      = Perf.counts[event] or 0
		local inCombat = Perf.combatCounts[event] or 0
		Print("%-28s %8d %8.2f %8d %8.2f", event,
			all, elapsed > 0 and all / elapsed or 0,
			inCombat, combat > 0 and inCombat / combat or 0)
	end

	if combat > 0 and frames > 0 then
		local usableRate = (Perf.combatCounts.SPELL_UPDATE_USABLE or 0) / combat
		Print("config reads/s in combat from RefreshAllUsable: %.0f  (%.2f events/s x %d frames)",
			usableRate * frames, usableRate, frames)
	else
		Print("no combat sampled yet, so the read rate is unknown")
	end
end

----------------------------------------------------------------------------------------------------
-- File Load

Perf.eventFrame = CreateFrame("Frame")
Perf.eventFrame:SetParentKey("Kami.Perf.Event")
Perf.eventFrame:SetScript("OnEvent", Perf.OnEvent)
Perf.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
Perf.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
for i, event in ipairs(events) do
	Perf.eventFrame:RegisterEvent(event)
end

Perf.startTime   = GetTimePreciseSec()
Perf.combatTime  = 0
Perf.combatStart = nil
