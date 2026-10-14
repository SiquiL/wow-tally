local _, ns = ...
local L = ns.L

local deaths
local isDead = false

local module = {
	label = L["Deaths"],
	defaults = { count = 0 },
	events = { "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" },
	seed = { count = "deaths" },
	milestones = {
		{ key = "deaths", thresholds = { 1, 10, 25, 50, 100, 250, 500, 1000 }, text = L["Deaths: %s"] },
	},
}

function module:OnLogin(section)
	deaths = section
	-- Logging in or reloading while dead must not count the same death twice
	isDead = UnitIsDeadOrGhost("player") and true or false
end

function module:OnEvent(event)
	if event == "PLAYER_DEAD" then
		if not isDead then
			isDead = true
			deaths.count = deaths.count + 1
		end
	elseif not UnitIsDeadOrGhost("player") then
		-- PLAYER_ALIVE also fires when releasing the spirit, while still a ghost
		isDead = false
	end
end

function module:Debug()
	print("    " .. L["currently dead"] .. ": " .. tostring(isDead))
end

function module:Summary(charData)
	return {
		{ key = "deaths", label = L["Deaths"], value = charData.deaths.count or 0, total = true },
	}
end

ns.RegisterModule("deaths", module)
