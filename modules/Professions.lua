local _, ns = ...
local L = ns.L

-- Subclasses of Enum.ItemClass.Tradegoods; the game has no enum for them (see the wiki page ItemType)
local MATERIALS = {
	[6] = "leather",
	[7] = "ore",
	[9] = "herbs",
}

local professions
-- Materials in the open loot window by slot; they count once the slot has been looted
local pending = {}

local module = {
	label = L["Professions"],
	defaults = { fish = 0, herbs = 0, ore = 0, leather = 0, crafted = 0, skillups = 0, skills = {} },
	events = {
		"LOOT_READY",
		"LOOT_OPENED",
		"LOOT_SLOT_CLEARED",
		"LOOT_CLOSED",
		"SKILL_LINES_CHANGED",
		"TRADE_SKILL_ITEM_CRAFTED_RESULT",
	},
	seed = { fish = "fish" },
	milestones = {
		{ key = "fish", thresholds = { 10, 100, 500, 1000, 5000, 10000 }, text = L["%s fish caught"] },
		{ key = "herbs", thresholds = { 100, 500, 1000, 5000, 10000 }, text = L["%s herbs gathered"] },
		{ key = "ore", thresholds = { 100, 500, 1000, 5000, 10000 }, text = L["%s ore and stone gathered"] },
		{ key = "leather", thresholds = { 100, 500, 1000, 5000, 10000 }, text = L["%s leather gathered"] },
		{ key = "crafted", thresholds = { 10, 100, 500, 1000, 5000, 10000 }, text = L["%s items crafted"] },
	},
}

local function Material(slot)
	local link = GetLootSlotLink(slot)
	if not link or ns.isSecret(link) then
		return nil
	end
	local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(link)
	if classID == Enum.ItemClass.Tradegoods then
		return MATERIALS[subclassID]
	end
end

-- Runs on LOOT_READY and again on LOOT_OPENED, because fast-loot addons empty slots in between
local function ScanLoot()
	pending = {}
	local count = GetNumLootItems()
	if ns.isSecret(count) then
		return
	end
	for slot = 1, count do
		local kind = Material(slot)
		local _, _, quantity = GetLootSlotInfo(slot)
		if kind and quantity and not ns.isSecret(quantity) and quantity > 0 then
			pending[slot] = { kind = kind, quantity = quantity }
		end
	end
end

-- The first level seen for a skill line is only the baseline
local function UpdateSkills()
	for _, index in pairs({ GetProfessions() }) do
		local _, _, rank, _, _, _, skillLine = GetProfessionInfo(index)
		if skillLine and rank and not ns.isSecret(skillLine) and not ns.isSecret(rank) then
			local last = professions.skills[skillLine]
			if last and rank > last then
				professions.skillups = professions.skillups + rank - last
			end
			professions.skills[skillLine] = rank
		end
	end
end

local function CraftedQuantity(result)
	local quantity = type(result) == "table" and result.quantity
	if not quantity or ns.isSecret(quantity) or quantity < 1 then
		return 1
	end
	return quantity
end

function module:OnLogin(section)
	professions = section
	UpdateSkills()
end

function module:OnEvent(event, ...)
	if event == "LOOT_READY" then
		ScanLoot()
	elseif event == "LOOT_OPENED" then
		ScanLoot()
		if IsFishingLoot and IsFishingLoot() then
			professions.fish = professions.fish + 1
		end
	elseif event == "LOOT_SLOT_CLEARED" then
		local slot = ...
		local item = pending[slot]
		if item then
			pending[slot] = nil
			professions[item.kind] = professions[item.kind] + item.quantity
		end
	elseif event == "LOOT_CLOSED" then
		pending = {}
	elseif event == "SKILL_LINES_CHANGED" then
		UpdateSkills()
	elseif event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
		professions.crafted = professions.crafted + CraftedQuantity(...)
	end
end

function module:Debug(section)
	local levels = {}
	for skillLine, rank in pairs(section.skills) do
		levels[#levels + 1] = skillLine .. "=" .. rank
	end
	table.sort(levels)
	print("    " .. L["skill levels"] .. ": " .. (#levels > 0 and table.concat(levels, ", ") or "–"))
end

function module:Summary(charData)
	local section = charData.professions
	return {
		{ key = "fish", label = L["Fish caught"], value = section.fish or 0, total = true },
		{ key = "herbs", label = L["Herbs"], value = section.herbs or 0, optional = true },
		{ key = "ore", label = L["Ore and stone"], value = section.ore or 0, optional = true },
		{ key = "leather", label = L["Leather"], value = section.leather or 0, optional = true },
		{ key = "crafted", label = L["Items crafted"], value = section.crafted or 0, optional = true },
		{ key = "skillups", label = L["Skill-ups"], value = section.skillups or 0, optional = true },
	}
end

ns.RegisterModule("professions", module)
