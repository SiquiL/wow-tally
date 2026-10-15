local addonName, ns = ...
local L = ns.L

local DB_VERSION = 1
local SEED_DELAY = 3
local PREFIX = "|cff33ff99Tally|r: "
local INVALID = "|cffff5555" .. L["invalid"] .. "|r"

-- issecretvalue only exists from patch 12.0.0 onwards
ns.isSecret = issecretvalue or function() return false end

-- Units shown in the column headers of the window
ns.UNIT_COUNT = L["count"]
ns.UNIT_DURATION = "d / h / m / s"
ns.UNIT_MONEY = "g / s / c"

ns.modules = {}
ns.moduleList = {}
ns.commands = {}
ns.commandHelp = {}
ns.loginHooks = {}
ns.char = nil
ns.charKey = nil

local events = CreateFrame("Frame")
local eventModules = {}
local failed = {}

-- Utilities ------------------------------------------------------------------

function ns.Say(message)
	print(PREFIX .. message)
end

function ns.Line(label, text, extra)
	print(("  %s: |cffffd100%s|r%s"):format(label, text, extra and (" " .. extra) or ""))
end

function ns.FormatCount(value)
	local rounded = math.floor(value + 0.5)
	if BreakUpLargeNumbers then
		return BreakUpLargeNumbers(rounded)
	end
	return tostring(rounded)
end

function ns.FormatDuration(seconds)
	seconds = math.floor(seconds + 0.5)
	local days = math.floor(seconds / 86400)
	local hours = math.floor(seconds % 86400 / 3600)
	local minutes = math.floor(seconds % 3600 / 60)
	if days > 0 then
		return ("%dd %dh %dm"):format(days, hours, minutes)
	elseif hours > 0 then
		return ("%dh %dm"):format(hours, minutes)
	elseif minutes > 0 then
		return ("%dm %ds"):format(minutes, seconds % 60)
	end
	return seconds .. "s"
end

function ns.CopyTable(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in pairs(value) do
		copy[key] = ns.CopyTable(inner)
	end
	return copy
end

function ns.ForEachChar(fn)
	local keys = {}
	for key in pairs(TallyDB.chars) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		fn(key, TallyDB.chars[key])
	end
end

function ns.CharLabel(key, data)
	local color = data.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[data.class]
	local label = color and color.colorStr and ("|c%s%s|r"):format(color.colorStr, key) or key
	if data.level then
		label = label .. " (" .. data.level .. ")"
	end
	return label
end

StaticPopupDialogs["TALLY_CONFIRM"] = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, onAccept)
		onAccept()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

function ns.Confirm(text, onAccept)
	StaticPopup_Show("TALLY_CONFIRM", text, nil, onAccept)
end

-- Module calls ---------------------------------------------------------------

local function Finish(module, method, ok, ...)
	if ok then
		return ...
	end

	-- One message per failing hook, otherwise a broken event floods the chat
	local id = module.key .. "." .. method
	if not failed[id] then
		failed[id] = true
		ns.Say(("|cffff5555%s|r – %s"):format(L["%s.%s failed"]:format(module.label, method), tostring((...))))
	end
end

-- Runs an optional module hook; an error in one module must not stop the others
function ns.Call(module, method, ...)
	local fn = module[method]
	if not fn then
		return
	end
	return Finish(module, method, pcall(fn, module, ...))
end

-- Summary entries ------------------------------------------------------------
-- A module's Summary(charData) returns an ordered list of entries:
--   key, label, value, [value2], [unit], [unit2], [fmt(value, value2) -> text, extra],
--   [cell(value, value2) -> text] for the window table (default: the text of fmt),
--   [headerUnit] appended to the column header of the window, e.g. "km",
--   [total] marks the headline entry, [optional] hides the entry while it is zero.

function ns.GetEntries(module, data)
	if not data[module.key] then
		return nil
	end
	return ns.Call(module, "Summary", data)
end

function ns.AccountEntries(module)
	local sums, order, count = {}, {}, 0

	ns.ForEachChar(function(_, data)
		local entries = ns.GetEntries(module, data)
		if not entries then
			return
		end
		count = count + 1

		for _, entry in ipairs(entries) do
			local sum = sums[entry.key]
			if not sum then
				sum = {}
				for field, value in pairs(entry) do
					sum[field] = value
				end
				sum.value, sum.value2 = 0, entry.value2 and 0 or nil
				sums[entry.key] = sum
				order[#order + 1] = sum
			end
			sum.value = sum.value + entry.value
			if entry.value2 then
				sum.value2 = (sum.value2 or 0) + entry.value2
			end
		end
	end)

	return order, count
end

function ns.FormatEntry(entry)
	if entry.fmt then
		return entry.fmt(entry.value, entry.value2)
	end
	return ns.FormatCount(entry.value)
end

function ns.FormatCell(entry)
	if entry.cell then
		return entry.cell(entry.value, entry.value2)
	end
	return (ns.FormatEntry(entry))
end

local function IsVisible(entry)
	return not entry.optional or entry.value ~= 0 or (entry.value2 or 0) ~= 0
end
ns.IsVisible = IsVisible

-- Headline entries when the module flags any, otherwise all of them
local function Headline(entries)
	local picked = {}
	for _, entry in ipairs(entries) do
		if entry.total then
			picked[#picked + 1] = entry
		end
	end
	if #picked == 0 then
		return entries, false
	end
	return picked, true
end

local function JoinEntries(entries)
	local parts = {}
	for _, entry in ipairs(entries) do
		if IsVisible(entry) then
			local text, extra = ns.FormatEntry(entry)
			parts[#parts + 1] = extra and (text .. " " .. extra) or text
		end
	end
	return table.concat(parts, ", ")
end

-- Reports --------------------------------------------------------------------

local function ReportModule(module)
	if not ns.char then
		return
	end

	local entries = ns.GetEntries(module, ns.char)
	if not entries then
		return
	end

	local subtitle = ns.Call(module, "Subtitle", ns.char)
	ns.Say(("%s – %s%s"):format(module.label, ns.charKey, subtitle and (", " .. subtitle) or ""))
	for _, entry in ipairs(entries) do
		if IsVisible(entry) then
			ns.Line(entry.label, ns.FormatEntry(entry))
		end
	end

	local totals = ns.AccountEntries(module)
	local picked, flagged = Headline(totals)
	for _, entry in ipairs(picked) do
		if IsVisible(entry) then
			local label = L["Account total"]
			if #picked > 1 or not flagged then
				label = label .. " – " .. entry.label
			end
			ns.Line(label, ns.FormatEntry(entry))
		end
	end

	ns.Call(module, "ReportExtra")
end

local function ReportAll()
	for _, module in ipairs(ns.moduleList) do
		ns.Say(module.label)

		ns.ForEachChar(function(key, data)
			local entries = ns.GetEntries(module, data)
			if entries then
				print(("  %s: |cffffd100%s|r"):format(ns.CharLabel(key, data), JoinEntries((Headline(entries)))))
			end
		end)

		local totals, count = ns.AccountEntries(module)
		if count > 0 then
			print(("  %s (%d): |cffffd100%s|r"):format(L["Account total"], count, JoinEntries((Headline(totals)))))
		end
	end
end

local function PrintChars()
	ns.Say(L["Stored characters"])
	ns.ForEachChar(function(key, data)
		local seen = data.lastSeen and date("%Y-%m-%d %H:%M", data.lastSeen) or L["never"]
		print("  " .. L["%s – %s, last logout %s"]:format(ns.CharLabel(key, data), data.race or "?", seen))
	end)
end

local function RemoveCharacter(name)
	if name == "" then
		ns.Say(L["Usage: /tally remove <Name-Realm>"])
		return
	end

	local found
	for key in pairs(TallyDB.chars) do
		if key:lower() == name then
			found = key
			break
		end
	end

	if not found then
		ns.Say(L["No stored character %s"]:format(name))
	elseif found == ns.charKey then
		ns.Say(L["The active character cannot be removed."])
	else
		ns.Confirm(L["Remove all Tally data of %s?"]:format(found), function()
			TallyDB.chars[found] = nil
			ns.Say(L["%s has been removed."]:format(found))
		end)
	end
end

function ns.UnknownModule(name)
	local keys = {}
	for _, module in ipairs(ns.moduleList) do
		keys[#keys + 1] = module.key
	end
	ns.Say(L["Unknown module %s. Available: %s"]:format(name, table.concat(keys, ", ")))
end

local function PrintDebug(moduleKey)
	if moduleKey and not ns.modules[moduleKey] then
		ns.UnknownModule(moduleKey)
		return
	end

	ns.Say("debug")
	print("  " .. L["addon version"] .. ": " .. tostring(C_AddOns.GetAddOnMetadata(addonName, "Version")))
	print("  " .. L["database schema"] .. ": " .. tostring(TallyDB and TallyDB.version))
	print("  " .. L["character key"] .. ": " .. tostring(ns.charKey))

	local stored = 0
	for _ in pairs(TallyDB and TallyDB.chars or {}) do
		stored = stored + 1
	end
	print("  " .. L["stored characters"] .. ": " .. stored)

	if not ns.char then
		return
	end

	local seen = ns.char.lastSeen and date("%Y-%m-%d %H:%M", ns.char.lastSeen) or L["never"]
	print("  " .. L["last logout"] .. ": " .. seen)

	for _, module in ipairs(ns.moduleList) do
		if not moduleKey or moduleKey == module.key then
			local section = ns.char[module.key]
			print("  [" .. module.key .. "]")

			local fields = {}
			for field, value in pairs(section) do
				if type(value) ~= "table" then
					fields[#fields + 1] = field
				end
			end
			table.sort(fields)
			for _, field in ipairs(fields) do
				print(("    %s = %s"):format(field, tostring(section[field])))
			end

			ns.Call(module, "Debug", section)
		end
	end
end

local function PrintHelp()
	ns.Say(L["Commands:"])
	print("  " .. L["/tally – report for every module"])
	for _, line in ipairs(ns.commandHelp) do
		print("  " .. line)
	end
	for _, module in ipairs(ns.moduleList) do
		print(("  /tally %s [reset [all] | debug] – %s"):format(module.key, module.label))
	end
end

-- Modules and commands -------------------------------------------------------

local function ResetSection(module, section)
	local keep = module.keepOnReset or {}
	for field, value in pairs(module.defaults or {}) do
		if not keep[field] then
			section[field] = ns.CopyTable(value)
		end
	end
end

-- Without this, thresholds passed before the reset would never be announced again
local function ClearMilestones(module, data)
	local prefix = module.key .. "."
	for id in pairs(data.milestones or {}) do
		if id:sub(1, #prefix) == prefix then
			data.milestones[id] = nil
		end
	end
end

local function ResetModule(module, all)
	if all then
		ns.Confirm(L["Reset %s for every stored character?"]:format(module.label), function()
			ns.ForEachChar(function(_, data)
				if data[module.key] then
					ResetSection(module, data[module.key])
					ClearMilestones(module, data)
				end
			end)
			ns.Say(L["%s: all characters have been reset."]:format(module.label))
		end)
	elseif ns.char then
		ResetSection(module, ns.char[module.key])
		ClearMilestones(module, ns.char)
		ns.Say(L["%s: counter for %s has been reset."]:format(module.label, ns.charKey))
	end
end

local function RunModuleCommand(module, args)
	local command, rest = args:match("^(%S*)%s*(.-)$")

	if command == "" then
		ReportModule(module)
	elseif command == "reset" and (rest == "" or rest == "all") then
		ResetModule(module, rest == "all")
	elseif command == "reset" then
		ns.Say(L["Usage: /tally %s reset [all]"]:format(module.key))
	elseif command == "debug" then
		PrintDebug(module.key)
	else
		PrintHelp()
	end
end

function ns.RegisterCommand(name, handler, help)
	assert(not ns.modules[name], "Tally: command clashes with module " .. name)
	ns.commands[name] = handler
	if help then
		ns.commandHelp[#ns.commandHelp + 1] = help
	end
end

function ns.RegisterModule(key, module)
	assert(not ns.commands[key], "Tally: module key clashes with command " .. key)
	module.key = key
	module.label = module.label or key
	ns.modules[key] = module
	ns.moduleList[#ns.moduleList + 1] = module

	for _, event in ipairs(module.events or {}) do
		if not eventModules[event] then
			eventModules[event] = {}
			events:RegisterEvent(event)
		end
		table.insert(eventModules[event], module)
	end

	-- Unit events get their own frame so they are not delivered for every unit
	if module.unitEvents then
		local frame = CreateFrame("Frame")
		for event, unit in pairs(module.unitEvents) do
			frame:RegisterUnitEvent(event, unit)
		end
		frame:SetScript("OnEvent", function(_, event, ...)
			if ns.char then
				ns.Call(module, "OnEvent", event, ...)
			end
		end)
	end
end

ns.RegisterCommand("help", PrintHelp, L["/tally help – list all commands"])
ns.RegisterCommand("all", ReportAll, L["/tally all – every character, per module"])
ns.RegisterCommand("chars", PrintChars, L["/tally chars – list stored characters"])
ns.RegisterCommand("remove", RemoveCharacter, L["/tally remove <Name-Realm> – delete a stored character"])
ns.RegisterCommand("debug", function(rest)
	PrintDebug(rest ~= "" and rest or nil)
end, L["/tally debug [module] – show stored state"])

-- ID check -------------------------------------------------------------------

local function SortedKeys(set)
	local keys = {}
	for key in pairs(set) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

local function PrintSpellList(title, spells)
	print("  " .. title)
	for _, spellID in ipairs(SortedKeys(spells)) do
		print(("    %d – %s |cff888888(%s)|r"):format(spellID, C_Spell.GetSpellName(spellID) or INVALID, spells[spellID]))
	end
end

-- Lists every ID from Data.lua with the name the client reports for it
local function CheckIds()
	ns.Say(L["ID check"])
	PrintSpellList(L["Hearthstone spells"], ns.HEARTHSTONE_SPELLS)
	PrintSpellList(L["Teleport spells"], ns.TELEPORT_SPELLS)

	local pending = false
	print("  " .. L["Hearthstone items"])
	for _, itemID in ipairs(SortedKeys(ns.HEARTHSTONE_ITEMS)) do
		local spellName, spellID = C_Item.GetItemSpell(itemID)
		if not spellID then
			pending = true
			C_Item.RequestLoadItemDataByID(itemID)
		end
		local spell = spellID and ("%d %s"):format(spellID, spellName) or L["not loaded"]
		print(("    %d – %s |cff888888(%s)|r"):format(itemID, spell, ns.HEARTHSTONE_ITEMS[itemID]))
	end

	print("  " .. L["Statistics"])
	for _, key in ipairs(SortedKeys(ns.STATISTICS)) do
		local stat = ns.STATISTICS[key]
		local _, name = GetAchievementInfo(stat.id)
		local label = name or INVALID
		if name and not select(15, GetAchievementInfo(stat.id)) then
			label = label .. " |cffff5555(" .. L["not a statistic"] .. ")|r"
		end
		print(("    %s %d – %s: %s |cff888888(%s)|r"):format(key, stat.id, label, tostring(GetStatistic(stat.id)), stat.name))
	end

	if pending then
		ns.Say(L["Some items are not loaded yet – run /tally ids again in a moment."])
	end
end

local function FindStatistics(text)
	ns.Say(L["Statistics matching \"%s\""]:format(text))
	for _, category in ipairs(GetStatisticsCategoryList()) do
		for index = 1, GetCategoryNumAchievements(category) do
			local id, name = GetAchievementInfo(category, index)
			if id and name and name:lower():find(text, 1, true) then
				print(("  %d – %s: %s"):format(id, name, tostring(GetStatistic(id))))
			end
		end
	end
end

ns.RegisterCommand("ids", function(rest)
	if rest == "" then
		CheckIds()
	else
		FindStatistics(rest)
	end
end, L["/tally ids [text] – check the configured IDs or search the game statistics"])

-- Database -------------------------------------------------------------------

local function InitDB()
	TallyDB = TallyDB or {}
	TallyDB.chars = TallyDB.chars or {}
	TallyDB.settings = TallyDB.settings or {}

	if TallyDB.settings.milestones == nil then
		TallyDB.settings.milestones = true
	end

	-- Builds before 1.0.0 kept the step counters directly on the character record
	for _, data in pairs(TallyDB.chars) do
		if data.foot or data.mount or data.swim then
			data.steps = data.steps or { foot = data.foot or 0, mount = data.mount or 0, swim = data.swim or 0 }
			data.foot, data.mount, data.swim = nil, nil, nil
		end
	end

	TallyDB.version = DB_VERSION
end

-- Returns the keys of modules whose section did not exist before this login
local function InitCharacter()
	-- The fallback is normalized the same way, so the key does not change between sessions
	local realm = GetNormalizedRealmName() or ((GetRealmName() or "?"):gsub("[%s%-%.]", ""))
	local key = UnitName("player") .. "-" .. realm
	local data = TallyDB.chars[key] or {}

	-- Refreshed on every login because race, sex and level can change. A secret value
	-- would make the whole table unserializable, so it is never stored.
	local _, raceFile = UnitRace("player")
	if not ns.isSecret(raceFile) then
		data.race = raceFile
	end

	local sex = UnitSex("player")
	if not ns.isSecret(sex) then
		data.sex = sex
	end

	local _, classFile = UnitClass("player")
	if not ns.isSecret(classFile) then
		data.class = classFile
	end

	local level = UnitLevel("player")
	if not ns.isSecret(level) then
		data.level = level
	end

	local fresh = {}
	for _, module in ipairs(ns.moduleList) do
		local section = data[module.key]
		if not section then
			section = {}
			fresh[module.key] = true
		end
		for field, value in pairs(module.defaults or {}) do
			if section[field] == nil then
				section[field] = ns.CopyTable(value)
			end
		end
		data[module.key] = section
	end

	TallyDB.chars[key] = data
	ns.charKey = key
	ns.char = data
	return fresh
end

-- Lifetime statistics --------------------------------------------------------

local function StatisticValue(id)
	local text = GetStatistic(id)
	-- Display text such as "1,234" or "--"
	return text and tonumber((tostring(text):gsub("%D", "")))
end

-- Raises counters once per character and module to the game's own statistics,
-- which also cover the time before Tally was installed
local function SeedFromStatistics()
	local imported = {}
	for _, module in ipairs(ns.moduleList) do
		local section = ns.char[module.key]
		if module.seed and not section.seeded then
			local configured, resolved = 0, 0
			for field, statKey in pairs(module.seed) do
				local stat = ns.STATISTICS[statKey]
				if stat then
					configured = configured + 1
					local value = StatisticValue(stat.id)
					if value then
						resolved = resolved + 1
						section[field] = math.max(section[field] or 0, value)
					end
				end
			end

			-- Not marked as done while a statistic is still unavailable, so the next login retries
			if configured > 0 and resolved == configured then
				section.seeded = true
				ns.SyncMilestones(module)
				imported[#imported + 1] = module.label
			end
		end
	end

	if #imported > 0 then
		ns.Say(L["Lifetime values imported from the game statistics: %s"]:format(table.concat(imported, ", ")))
	end
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		if (...) == addonName then
			InitDB()
			self:UnregisterEvent("ADDON_LOADED")
		end
	elseif event == "PLAYER_LOGIN" then
		local fresh = InitCharacter()
		for _, module in ipairs(ns.moduleList) do
			local section = ns.char[module.key]
			if fresh[module.key] then
				ns.Call(module, "OnNew", section)
			end
			ns.Call(module, "OnLogin", section)
		end
		for _, hook in ipairs(ns.loginHooks) do
			local ok, err = pcall(hook)
			if not ok then
				ns.Say("|cffff5555" .. tostring(err) .. "|r")
			end
		end
		C_Timer.After(SEED_DELAY, SeedFromStatistics)
		self:UnregisterEvent("PLAYER_LOGIN")
	elseif event == "PLAYER_LOGOUT" then
		if ns.char then
			for _, module in ipairs(ns.moduleList) do
				ns.Call(module, "OnLogout", ns.char[module.key])
			end
			local level = UnitLevel("player")
			if not ns.isSecret(level) then
				ns.char.level = level
			end
			ns.char.lastSeen = time()
		end
	elseif ns.char then
		for _, module in ipairs(eventModules[event] or {}) do
			ns.Call(module, "OnEvent", event, ...)
		end
	end
end)

-- Slash command --------------------------------------------------------------

SLASH_TALLY1 = "/tally"

SlashCmdList["TALLY"] = function(msg)
	local first, rest = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")

	if first == "" then
		for _, module in ipairs(ns.moduleList) do
			ReportModule(module)
		end
	elseif ns.commands[first] then
		ns.commands[first](rest)
	elseif ns.modules[first] then
		RunModuleCommand(ns.modules[first], rest)
	else
		PrintHelp()
	end
end
