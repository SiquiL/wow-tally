local _, ns = ...
local L = ns.L

local MODE_INTERVAL = 0.1

-- steps = false: the distance counts, but a flight path or flying mount is not walking
local MODES = {
	{ key = "foot", label = L["On foot"], steps = true },
	{ key = "mount", label = L["Mounted"], steps = true },
	{ key = "swim", label = L["Swimming"], steps = true },
	{ key = "flight", label = L["Flying"], steps = false },
	{ key = "taxi", label = L["Flight path"], steps = false },
}

local GetGlidingInfo = C_PlayerInfo and C_PlayerInfo.GetGlidingInfo

local steps
local tracker = CreateFrame("Frame")
local currentMode = "foot"
local sinceModeCheck = MODE_INTERVAL

local function StepsAndKm(yards, stepLength)
	local meters = (yards or 0) * ns.YARD_TO_METER
	return meters / stepLength, meters / 1000
end

local function FormatStepsKm(count, km)
	return ns.FormatCount(count), L["steps (%.2f km)"]:format(km)
end

local function FormatKm(_, km)
	return ("%.2f km"):format(km)
end

-- The total also contains flying, which adds distance but no steps
local function FormatKmSteps(count, km)
	return FormatKm(count, km), L["(%s steps)"]:format(ns.FormatCount(count))
end

local function CurrentMode()
	if UnitOnTaxi("player") then
		return "taxi"
	elseif IsSwimming() then
		return "swim"
	elseif IsFlying() then
		return "flight"
	elseif IsMounted() then
		return "mount"
	end
	return "foot"
end

-- While skyriding, GetUnitSpeed does not report the actual speed; the gliding info does
local function Speed()
	if GetGlidingInfo then
		local isGliding, _, forwardSpeed = GetGlidingInfo()
		if isGliding then
			return forwardSpeed, true
		end
	end
	return GetUnitSpeed("player"), false
end

local function Tick(_, elapsed)
	sinceModeCheck = sinceModeCheck + elapsed
	if sinceModeCheck >= MODE_INTERVAL then
		sinceModeCheck = 0
		currentMode = CurrentMode()
	end

	-- Under combat/encounter restrictions the speed may be a secret value;
	-- doing any arithmetic on one would raise an immediate Lua error.
	local speed, gliding = Speed()
	if ns.isSecret(speed) then
		steps.blind = steps.blind + elapsed
	elseif speed and speed > 0 then
		local mode = gliding and "flight" or currentMode
		steps[mode] = steps[mode] + speed * elapsed
	end
end

local module = {
	label = L["Steps"],
	defaults = { foot = 0, mount = 0, swim = 0, flight = 0, taxi = 0, blind = 0 },
	milestones = {
		{ key = "total", field = "value2", thresholds = { 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000 }, text = L["%s km travelled"] },
	},
}

function module:OnLogin(section)
	steps = section
	tracker:SetScript("OnUpdate", Tick)
end

-- Rounding keeps the saved numbers readable
function module:OnLogout(section)
	for field in pairs(self.defaults) do
		section[field] = math.floor(section[field] * 100 + 0.5) / 100
	end
end

function module:Subtitle(charData)
	return L["step length %.2f m"]:format(ns.GetStepLength(charData.race, charData.sex))
end

function module:ReportExtra()
	local km = 0
	for _, entry in ipairs((ns.AccountEntries(self))) do
		if entry.key == "total" then
			km = entry.value2
		end
	end
	if km <= 0 then
		return
	end

	local fact = ns.DISTANCE_FACTS[1]
	for _, candidate in ipairs(ns.DISTANCE_FACTS) do
		if km >= candidate.km then
			fact = candidate
		end
	end

	local ratio = km / fact.km
	if ratio >= 1 then
		print("  " .. L["Fun fact: the account has covered %.1f× %s."]:format(ratio, fact.text))
	else
		print("  " .. L["Fun fact: the account has covered %d%% of %s."]:format(math.floor(ratio * 100), fact.text))
	end
end

function module:Summary(charData)
	local section = charData.steps
	local stepLength = ns.GetStepLength(charData.race, charData.sex)
	local entries = {}
	local totalSteps, totalKm = 0, 0

	for _, mode in ipairs(MODES) do
		local count, km = StepsAndKm(section[mode.key], stepLength)
		if mode.steps then
			totalSteps = totalSteps + count
		else
			count = 0
		end
		totalKm = totalKm + km

		entries[#entries + 1] = {
			key = mode.key,
			label = mode.label,
			value = count,
			value2 = km,
			unit = "steps",
			unit2 = "km",
			fmt = mode.steps and FormatStepsKm or FormatKm,
			optional = not mode.steps,
		}
	end

	entries[#entries + 1] = {
		key = "total",
		label = L["Total distance"],
		value = totalSteps,
		value2 = totalKm,
		unit = "steps",
		unit2 = "km",
		fmt = FormatKmSteps,
		total = true,
	}

	entries[#entries + 1] = {
		key = "blind",
		label = L["Not measurable (restricted)"],
		value = section.blind or 0,
		unit = "s",
		fmt = ns.FormatDuration,
		optional = true,
	}

	return entries
end

ns.RegisterModule("steps", module)
