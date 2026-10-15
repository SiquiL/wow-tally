local _, ns = ...
local L = ns.L

local quests

local module = {
	label = L["Quests"],
	defaults = { count = 0, xp = 0 },
	events = { "QUEST_TURNED_IN" },
	seed = { count = "quests" },
	milestones = {
		{ key = "count", thresholds = { 10, 50, 100, 250, 500, 1000, 2500, 5000 }, text = L["%s quests turned in"] },
	},
}

function module:OnLogin(section)
	quests = section
end

function module:OnEvent(_, _, xpReward)
	quests.count = quests.count + 1
	if type(xpReward) == "number" and not ns.isSecret(xpReward) then
		quests.xp = quests.xp + xpReward
	end
end

function module:Summary(charData)
	local section = charData.quests
	return {
		{ key = "count", label = L["Turned in"], value = section.count or 0, headerUnit = ns.UNIT_COUNT, total = true },
		{ key = "xp", label = L["Quest XP"], value = section.xp or 0, unit = "xp", headerUnit = L["XP"] },
	}
end

ns.RegisterModule("quests", module)
