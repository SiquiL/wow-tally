local _, ns = ...
local L = ns.L

local INTERVAL = 5

-- A module declares milestones = { { key, [field], thresholds, text, [fmt] } } where key names a
-- Summary entry, field is "value" (default) or "value2" and text contains one %s.
local function Check(module, silent)
	local entries = ns.GetEntries(module, ns.char)
	if not entries then
		return
	end

	local byKey = {}
	for _, entry in ipairs(entries) do
		byKey[entry.key] = entry
	end

	for _, milestone in ipairs(module.milestones) do
		local entry = byKey[milestone.key]
		local value = entry and entry[milestone.field or "value"]
		if value then
			local id = module.key .. "." .. milestone.key
			local last = ns.char.milestones[id] or 0

			-- Only the highest new threshold is announced, so existing data does not
			-- trigger one message per step that was already passed
			local highest
			for _, threshold in ipairs(milestone.thresholds) do
				if value >= threshold and threshold > last then
					highest = threshold
				end
			end

			if highest then
				ns.char.milestones[id] = highest
				if not silent then
					local formatted = milestone.fmt and milestone.fmt(highest) or ns.FormatCount(highest)
					ns.Say(L["Milestone"] .. " – " .. milestone.text:format(formatted))
				end
			end
		end
	end
end

-- Records reached thresholds without announcing them, e.g. after importing old values
function ns.SyncMilestones(module)
	if module.milestones then
		Check(module, true)
	end
end

local function CheckAll()
	if not TallyDB.settings.milestones then
		return
	end
	for _, module in ipairs(ns.moduleList) do
		if module.milestones then
			Check(module)
		end
	end
end

ns.loginHooks[#ns.loginHooks + 1] = function()
	ns.char.milestones = ns.char.milestones or {}
	C_Timer.NewTicker(INTERVAL, CheckAll)
end

ns.RegisterCommand("milestones", function(rest)
	if rest == "on" or rest == "off" then
		ns.SetSetting("milestones", rest == "on")
	end
	ns.Say(TallyDB.settings.milestones and L["Milestone announcements are on."] or L["Milestone announcements are off."])
end, L["/tally milestones [on|off] – announce reached milestones"])
