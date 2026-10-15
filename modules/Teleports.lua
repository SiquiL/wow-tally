local _, ns = ...
local L = ns.L

local RECENT_UNLISTED = 5

local teleports
local hearthSpells = {}
local pendingItems = {}
local unlisted = {}

local module = {
	label = L["Teleports"],
	defaults = { hearth = 0, teleport = 0 },
	events = { "ITEM_DATA_LOAD_RESULT" },
	unitEvents = { UNIT_SPELLCAST_SUCCEEDED = "player" },
	seed = { hearth = "hearth" },
	milestones = {
		{ key = "total", thresholds = { 10, 50, 100, 500, 1000, 5000 }, text = L["%s teleports and hearthstone uses"] },
	},
}

-- A toy casts its own spell, which is only known once the item data is cached
local function ResolveItem(itemID, requested)
	local _, spellID = C_Item.GetItemSpell(itemID)
	if spellID then
		hearthSpells[spellID] = true
	elseif not requested then
		pendingItems[itemID] = true
		C_Item.RequestLoadItemDataByID(itemID)
		return
	end
	pendingItems[itemID] = nil
end

function module:OnLogin(section)
	teleports = section
	for spellID in pairs(ns.HEARTHSTONE_SPELLS) do
		hearthSpells[spellID] = true
	end
	for itemID in pairs(ns.HEARTHSTONE_ITEMS) do
		ResolveItem(itemID)
	end
end

function module:OnEvent(event, ...)
	if event == "ITEM_DATA_LOAD_RESULT" then
		local itemID = ...
		if pendingItems[itemID] then
			ResolveItem(itemID, true)
		end
		return
	end

	local spellID = select(3, ...)
	if ns.isSecret(spellID) then
		return
	end

	if hearthSpells[spellID] then
		teleports.hearth = teleports.hearth + 1
	elseif ns.TELEPORT_SPELLS[spellID] then
		teleports.teleport = teleports.teleport + 1
	else
		table.insert(unlisted, 1, spellID)
		unlisted[RECENT_UNLISTED + 1] = nil
	end
end

function module:Debug()
	local names = {}
	for _, spellID in ipairs(unlisted) do
		names[#names + 1] = ("%d %s"):format(spellID, C_Spell.GetSpellName(spellID) or "?")
	end
	print("    " .. L["recent unlisted spells"] .. ": " .. (#names > 0 and table.concat(names, ", ") or "–"))
end

function module:Summary(charData)
	local section = charData.teleports
	local hearth, teleport = section.hearth or 0, section.teleport or 0
	return {
		{ key = "hearth", label = L["Hearthstone"], value = hearth, headerUnit = ns.UNIT_COUNT },
		{ key = "teleport", label = L["Teleport spells"], value = teleport, headerUnit = ns.UNIT_COUNT },
		{ key = "total", label = L["Total"], value = hearth + teleport, headerUnit = ns.UNIT_COUNT, total = true },
	}
end

ns.RegisterModule("teleports", module)
