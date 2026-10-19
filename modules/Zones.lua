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
local VIEW_MODES = {
	{ key = "f", label = L["On foot"] },
	{ key = "m", label = L["Mounted"] },
	{ key = "s", label = L["Swimming"] },
	{ key = "a", label = L["Flying"] },
	{ key = "t", label = L["Flight path"] },
}
local INSTANCE_LABELS = {
	party = L["Dungeon"],
	raid = L["Raid"],
	pvp = L["Battleground"],
	arena = L["Arena"],
	scenario = L["Scenario"],
}
-- Continent and world overviews are hidden by map type, because their IDs differ between
-- clients (Kalimdor is 12 in retail and 1414 in classic)
local CONTINENT_MAP_TYPE = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2

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

-- Instances are keyed by their negated instance ID, so they never collide with a uiMapID.
-- Classic dungeons have no map at all, and multi-floor instances would otherwise be split.
local function CurrentZone()
	local inInstance, instanceType = IsInInstance()
	local kind = inInstance and instanceType ~= "none" and instanceType or nil
	if kind then
		local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
		if type(instanceID) == "number" and instanceID > 0 then
			return -instanceID, kind, name
		end
	end

	local mapID = C_Map.GetBestMapForUnit("player")
	if type(mapID) == "number" then
		return mapID, kind
	end
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

	local key, kind, name = CurrentZone()
	currentMapID = key
	lastUpdate = now
	if key then
		local entry = ZoneEntry(key)
		entry.kind = kind
		if type(name) == "string" and name ~= "" then
			entry.name = name
		end
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

local function Kilometers(yards)
	return (yards or 0) * ns.YARD_TO_METER / 1000
end

local function IsHiddenMap(mapID)
	if mapID < 0 then
		return false
	end
	local info = C_Map.GetMapInfo(mapID)
	return info and type(info.mapType) == "number" and info.mapType <= CONTINENT_MAP_TYPE or false
end

local function ZoneName(mapID, kind, storedName)
	local info = mapID > 0 and C_Map.GetMapInfo(mapID)
	local name = storedName or info and info.name or L["Unknown zone (%d)"]:format(math.abs(mapID))
	if kind then
		name = ("%s (%s)"):format(name, INSTANCE_LABELS[kind] or kind)
	end
	return name
end

local module = {
	label = L["Zones"],
	events = {
		"ZONE_CHANGED",
		"ZONE_CHANGED_INDOORS",
		"ZONE_CHANGED_NEW_AREA",
		"PLAYER_ENTERING_WORLD",
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
			label = L["Total distance in zones"],
			value = Kilometers(totalYards),
			unit = "km",
			headerUnit = "km",
			fmt = FormatKm,
			cell = CellKm,
			total = true,
		},
	}
end

function module:BuildView()
	local combined = {}
	local populated = {}

	ns.ForEachChar(function(_, data)
		for mapID, source in pairs(data.zones or {}) do
			if type(mapID) == "number" and type(source) == "table" then
				local target = combined[mapID]
				if not target then
					target = { time = 0 }
					combined[mapID] = target
				end
				target.time = target.time + (source.time or 0)
				target.kind = target.kind or source.kind
				target.name = target.name or source.name
				for _, mode in ipairs(VIEW_MODES) do
					local yards = source[mode.key] or 0
					target[mode.key] = (target[mode.key] or 0) + yards
					if yards > 0 then
						populated[mode.key] = true
					end
				end
			end
		end
	end)

	local columns = {
		{ key = "zone", label = L["Zone"], align = "LEFT", sortType = "text", minWidth = 120 },
		{ key = "time", label = L["Playtime"], align = "RIGHT", sortType = "number" },
	}
	local visibleModes = {}
	for _, mode in ipairs(VIEW_MODES) do
		if not TallyDB.settings.hideEmpty or populated[mode.key] then
			visibleModes[#visibleModes + 1] = mode
			columns[#columns + 1] = {
				key = mode.key,
				label = ("%s (km)"):format(mode.label),
				align = "RIGHT",
				sortType = "number",
			}
		end
	end
	columns[#columns + 1] = {
		key = "total",
		label = L["Total distance"] .. " (km)",
		align = "RIGHT",
		sortType = "number",
	}

	local rows = {}
	for mapID, entry in pairs(combined) do
		local totalYards = TotalYards(entry)
		if not IsHiddenMap(mapID) and (entry.time > 0 or totalYards > 0) then
			local name = ZoneName(mapID, entry.kind, entry.name)
			local cells = {
				{ text = name, sort = name:lower() },
				{ text = ns.FormatDuration(entry.time), sort = entry.time },
			}
			for _, mode in ipairs(visibleModes) do
				local km = Kilometers(entry[mode.key])
				cells[#cells + 1] = { text = CellKm(km), sort = km }
			end
			local totalKm = Kilometers(totalYards)
			cells[#cells + 1] = { text = CellKm(totalKm), sort = totalKm }
			rows[#rows + 1] = { key = tostring(mapID), cells = cells }
		end
	end

	return {
		columns = columns,
		rows = rows,
		defaultSort = { key = "time", direction = "desc" },
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
