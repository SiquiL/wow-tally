local _, ns = ...
local L = ns.L

local category
local layout
local registered = {}

local GITHUB_URL = "https://github.com/SiquiL/wow-tally"

-- The settings list builds its rows from a mixin on the template, and that mixin is only
-- looked up once the panel is opened, so it can be assembled after the client is ready
local function PrepareLinkTemplate()
	if TallySettingsLinkMixin or not SettingsListElementMixin then
		return
	end

	local mixin = CreateFromMixins(SettingsListElementMixin)

	function mixin:OnLoad()
		SettingsListElementMixin.OnLoad(self)

		local box = CreateFrame("EditBox", nil, self, "InputBoxTemplate")
		box:SetSize(300, 22)
		box:SetPoint("LEFT", self, "CENTER", -75, 0)
		box:SetAutoFocus(false)
		box:SetFontObject("GameFontHighlightSmall")
		box:SetScript("OnEscapePressed", box.ClearFocus)
		box:SetScript("OnEnterPressed", box.ClearFocus)
		box:SetScript("OnEditFocusGained", function(editBox)
			editBox:HighlightText()
		end)
		-- A click places the cursor, so the address is selected again afterwards.
		-- OnMouseUp passes the button name, which HighlightText would read as an index.
		box:SetScript("OnMouseUp", function(editBox)
			editBox:HighlightText()
		end)
		-- The box exists to be copied, so any edit restores the address
		box:SetScript("OnTextChanged", function(editBox, userInput)
			if userInput then
				editBox:SetText(self.url or "")
				editBox:HighlightText()
			end
		end)
		box:SetScript("OnEnter", function(editBox)
			GameTooltip:SetOwner(editBox, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.data and self.data.name or "")
			GameTooltip:AddLine(L["Click the address and press Ctrl+C to copy it."], 1, 1, 1, true)
			-- Addons have no API to launch a browser, so copying is the only way out of the game
			GameTooltip:AddLine(L["The game cannot open a browser by itself."], 1, 0.82, 0, true)
			GameTooltip:Show()
		end)
		box:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		local logo = self:CreateTexture(nil, "ARTWORK")
		logo:SetSize(18, 18)
		logo:SetPoint("RIGHT", box, "LEFT", -6, 0)
		logo:SetTexture("Interface\\AddOns\\Tally\\assets\\settings\\github-mark")
		self.Link = box
	end

	function mixin:Init(initializer)
		SettingsListElementMixin.Init(self, initializer)
		self.url = self.data.url or ""
		self.Link:SetText(self.url)
		self.Link:SetCursorPosition(0)
	end

	TallySettingsLinkMixin = mixin
end

local function AddLink(name, url, tooltip)
	if not (TallySettingsLinkMixin and Settings.CreateElementInitializer) then
		return
	end

	local initializer = Settings.CreateElementInitializer("TallySettingsLinkTemplate",
		{ name = name, url = url, tooltip = tooltip })
	initializer:AddSearchTags(name)
	layout:AddInitializer(initializer)
end

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

	if CreateSettingsButtonInitializer then
		local resetLabel = L["Reset window position"]
		layout:AddInitializer(CreateSettingsButtonInitializer(
			resetLabel,
			resetLabel,
			ns.ResetWindowPosition,
			L["Move the Tally window back to the center of the screen."],
			true
		))
	end

	if CreateSettingsListSectionHeaderInitializer then
		PrepareLinkTemplate()
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Links"]))
		AddLink("GitHub", GITHUB_URL, L["Click the address and press Ctrl+C to copy it."])
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
