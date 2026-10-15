local _, ns = ...
local L = ns.L

local ZONE_INTERVAL = 5
local MODE_KEYS = {
	foot = "f",
	mount = "m",
	swim = "s",
	flight = "a",
	taxi = "t",
}

local zones
local currentMapID
local lastUpdate
local sinceZoneCheck = 0
local tracker = CreateFrame("Frame")

local function ZoneEntry(mapID)
	local entry = zones[mapID]
	if not entry then
		entry = {}
		zones[mapID] = entry
	end
	return entry
end

local function RecordKind(entry)
	local inInstance, instanceType = IsInInstance()
	entry.kind = inInstance and instanceType ~= "none" and instanceType or nil
end

local function AddElapsed(now)
	if currentMapID and lastUpdate then
		local entry = ZoneEntry(currentMapID)
		entry.time = (entry.time or 0) + math.max(now - lastUpdate, 0)
	end
end

local function RefreshZone()
	local now = GetTime()
	AddElapsed(now)

	local mapID = C_Map.GetBestMapForUnit("player")
	currentMapID = type(mapID) == "number" and mapID or nil
	lastUpdate = now
	if currentMapID then
		RecordKind(ZoneEntry(currentMapID))
	end
end

local function Tick(_, elapsed)
	sinceZoneCheck = sinceZoneCheck + elapsed
	if sinceZoneCheck >= ZONE_INTERVAL then
		sinceZoneCheck = 0
		RefreshZone()
	end
end

local function TotalYards(entry)
	local total = 0
	for _, key in pairs(MODE_KEYS) do
		total = total + (entry[key] or 0)
	end
	return total
end

local function FormatKm(km)
	return ("%.2f km"):format(km)
end

local function CellKm(km)
	return ("%.2f"):format(km)
end

local module = {
	label = L["Zones"],
	events = {
		"ZONE_CHANGED",
		"ZONE_CHANGED_INDOORS",
		"ZONE_CHANGED_NEW_AREA",
	},
}

function module:OnLogin(section)
	zones = section
	currentMapID = nil
	lastUpdate = nil
	sinceZoneCheck = 0
	RefreshZone()
	tracker:SetScript("OnUpdate", Tick)
end

function module:OnEvent()
	RefreshZone()
end

function module:OnLogout(section)
	RefreshZone()
	for _, entry in pairs(section) do
		entry.time = math.floor((entry.time or 0) + 0.5)
		for _, key in pairs(MODE_KEYS) do
			if entry[key] then
				entry[key] = math.floor(entry[key] * 100 + 0.5) / 100
			end
		end
	end
end

function module:Summary(charData)
	local visited, totalTime, totalYards = 0, 0, 0
	for _, entry in pairs(charData.zones) do
		local yards = TotalYards(entry)
		local elapsed = entry.time or 0
		if elapsed > 0 or yards > 0 then
			visited = visited + 1
		end
		totalTime = totalTime + elapsed
		totalYards = totalYards + yards
	end

	return {
		{ key = "visited", label = L["Zones visited"], value = visited, total = true },
		{
			key = "time",
			label = L["Time in zones"],
			value = totalTime,
			unit = "s",
			fmt = ns.FormatDuration,
			total = true,
		},
		{
			key = "distance",
			label = L["Distance in zones"],
			value = totalYards * ns.YARD_TO_METER / 1000,
			unit = "km",
			headerUnit = "km",
			fmt = FormatKm,
			cell = CellKm,
			total = true,
		},
	}
end

function ns.RecordZoneDistance(mode, yards)
	if not zones or not currentMapID then
		return
	end
	local key = MODE_KEYS[mode]
	if key then
		local entry = ZoneEntry(currentMapID)
		entry[key] = (entry[key] or 0) + yards
	end
end

ns.RegisterModule("zones", module)
