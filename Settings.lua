local _, ns = ...
local L = ns.L

local category
local layout
local registered = {}

-- Goes through the registered setting so an open options panel reflects the change
function ns.SetSetting(key, value)
	if registered[key] then
		registered[key]:SetValue(value)
	else
		TallyDB.settings[key] = value
	end
end

local function OpenOptions()
	if not category then
		ns.Say(L["The options panel is not available in this client."])
	elseif InCombatLockdown() then
		ns.Say(L["The options cannot be opened in combat."])
	else
		Settings.OpenToCategory(category:GetID())
	end
end

ns.loginHooks[#ns.loginHooks + 1] = function()
	if not (Settings and Settings.RegisterVerticalLayoutCategory) then
		return
	end

	category, layout = Settings.RegisterVerticalLayoutCategory("Tally")
	local milestones = Settings.RegisterAddOnSetting(category, "Tally_Milestones", "milestones",
		TallyDB.settings, "boolean", L["Announce milestones"], true)
	Settings.CreateCheckbox(category, milestones, L["Print a chat message when a counter reaches a milestone."])
	registered.milestones = milestones

	local hideEmpty = Settings.RegisterAddOnSetting(category, "Tally_HideEmpty", "hideEmpty",
		TallyDB.settings, "boolean", L["Hide empty columns"], true)
	Settings.CreateCheckbox(category, hideEmpty, L["Hide table columns that contain no recorded values."])
	registered.hideEmpty = hideEmpty

	if Settings.CreateButton then
		layout:AddInitializer(Settings.CreateButton(
			L["Reset window position"],
			L["Move the Tally window back to the center of the screen."],
			ns.ResetWindowPosition
		))
	end
	Settings.RegisterAddOnCategory(category)
end

ns.RegisterCommand("options", OpenOptions, L["/tally options – open the options panel"])

-- Named in the TOC, so the client calls them from the addon compartment
function Tally_OnAddonCompartmentClick(_, buttonName)
	if buttonName == "RightButton" then
		OpenOptions()
	else
		ns.commands.window("")
	end
end

function Tally_OnAddonCompartmentEnter(_, menuButtonFrame)
	MenuUtil.ShowTooltip(menuButtonFrame, function(tooltip)
		tooltip:SetText("Tally")
		tooltip:AddLine(L["Left-click: toggle the window"], 1, 1, 1)
		tooltip:AddLine(L["Right-click: open the options"], 1, 1, 1)
	end)
end

function Tally_OnAddonCompartmentLeave(_, menuButtonFrame)
	MenuUtil.HideTooltip(menuButtonFrame)
end
