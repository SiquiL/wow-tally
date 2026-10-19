local _, ns = ...
local L = ns.L

local category
local layout
local registered = {}
local bugReport

local GITHUB_URL = "https://github.com/SiquiL/wow-tally"
local ISSUES_URL = GITHUB_URL .. "/issues/new"

function ns.ShowBugReport()
	if not bugReport then
		bugReport = ns.CreateWindow("TallyBugReport", 440, 190, L["Report a bug"])

		local text = bugReport:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:SetPoint("TOPLEFT", 18, -36)
		text:SetWidth(404)
		text:SetJustifyH("LEFT")
		text:SetText(L["Found a bug or have an idea? Please open an issue on GitHub and describe what happened."])
		ns.StyleText(text)

		-- Read-only: the game cannot open a browser, so the address is selected for Ctrl+C
		local link = CreateFrame("EditBox", nil, bugReport, "InputBoxTemplate")
		link:SetSize(396, 24)
		link:SetPoint("TOPLEFT", 24, -86)
		link:SetAutoFocus(false)
		link:SetFontObject("GameFontHighlightSmall")
		link:SetText(ISSUES_URL)
		link:SetCursorPosition(0)
		link:SetScript("OnEscapePressed", function()
			bugReport:Hide()
		end)
		link:SetScript("OnEnterPressed", link.ClearFocus)
		link:SetScript("OnEditFocusGained", function(editBox)
			editBox:HighlightText()
		end)
		link:SetScript("OnMouseUp", function(editBox)
			editBox:HighlightText()
		end)
		link:SetScript("OnTextChanged", function(editBox, userInput)
			if userInput then
				editBox:SetText(ISSUES_URL)
				editBox:HighlightText()
			end
		end)
		bugReport.link = link

		local hint = bugReport:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		hint:SetPoint("TOPLEFT", 18, -118)
		hint:SetWidth(404)
		hint:SetJustifyH("LEFT")
		hint:SetText(L["Click the address and press Ctrl+C to copy it."] .. " "
			.. L["The game cannot open a browser by itself."])
		ns.StyleText(hint)

		local close = CreateFrame("Button", nil, bugReport, "UIPanelButtonTemplate")
		close:SetSize(100, 24)
		close:SetPoint("BOTTOM", 0, 12)
		close:SetText(CLOSE or L["Close"])
		close:SetScript("OnClick", function()
			bugReport:Hide()
		end)
		bugReport:SetScript("OnHide", function()
			link:ClearFocus()
		end)
	end
	bugReport:Show()
	bugReport.link:SetFocus()
end

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
		box:SetPoint("LEFT", self, "CENTER", -175, 0)
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

		local function ShowLinkTooltip(owner)
			GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.data and self.data.title or "")
			GameTooltip:AddLine(L["Click the address and press Ctrl+C to copy it."], 1, 1, 1, true)
			-- Addons have no API to launch a browser, so copying is the only way out of the game
			GameTooltip:AddLine(L["The game cannot open a browser by itself."], 1, 0.82, 0, true)
			GameTooltip:Show()
		end

		box:SetScript("OnEnter", function(editBox)
			ShowLinkTooltip(editBox)
		end)
		box:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		local button = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
		button:SetSize(28, 28)
		button:SetPoint("RIGHT", box, "LEFT", -8, 0)
		button:SetFrameLevel(self:GetFrameLevel() + 10)
		button:EnableMouse(true)
		button:RegisterForClicks("LeftButtonUp")
		local selectLink = function()
			C_Timer.After(0, function()
				box:SetFocus()
				box:HighlightText()
			end)
		end
		button:SetScript("OnMouseDown", selectLink)
		button:SetScript("OnEnter", function(linkButton)
			ShowLinkTooltip(linkButton)
		end)
		button:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		local logo = button:CreateTexture(nil, "ARTWORK")
		logo:SetPoint("TOPLEFT", 5, -5)
		logo:SetPoint("BOTTOMRIGHT", -5, 5)
		logo:SetTexture("Interface\\AddOns\\Tally\\textures\\GitHubMark")
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
		{ name = "", title = name, url = url, tooltip = tooltip })
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

	if Settings.CreateDropdown and Settings.CreateControlTextContainer then
		local theme = Settings.RegisterAddOnSetting(category, "Tally_Theme", "theme",
			TallyDB.settings, "string", L["Theme"], "standard")
		theme:SetValueChangedCallback(function(_, value)
			ns.SetTheme(value)
		end)
		Settings.CreateDropdown(category, theme, function()
			local options = Settings.CreateControlTextContainer()
			for _, entry in ipairs(ns.THEMES) do
				options:Add(entry.id, L[entry.label])
			end
			return options:GetData()
		end, L["Changes Tally and its windows for all characters."])
		registered.theme = theme
	end

	local opacity
	if CreateSettingsButtonInitializer then
		layout:AddInitializer(CreateSettingsButtonInitializer(L["Background color"], L["Choose color"], function()
			ns.PickColor(ns.BackgroundColor(), function(color, alpha)
				TallyDB.settings.backgroundColor = color
				-- The slider applies the opacity, so an open panel shows the new value
				if opacity and alpha ~= ns.BackgroundOpacity() then
					opacity:SetValue(alpha)
				else
					ns.SetBackgroundOpacity(alpha)
				end
				ns.RefreshAppearance()
			end, ns.BackgroundOpacity())
		end, L["Used by the Custom color theme. Text contrast adjusts automatically. The opacity applies to every theme."], true))
	end

	if Settings.CreateSlider and Settings.CreateSliderOptions then
		opacity = Settings.RegisterAddOnSetting(category, "Tally_BackgroundOpacity", "backgroundOpacity",
			TallyDB.settings, "number", L["Background opacity"], 1)
		opacity:SetValueChangedCallback(function(_, value)
			ns.SetBackgroundOpacity(value)
		end)
		local options = Settings.CreateSliderOptions(0, 1, 0.05)
		if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
				return ("%d%%"):format(math.floor(value * 100 + 0.5))
			end)
		end
		Settings.CreateSlider(category, opacity, options,
			L["Transparency of the Tally windows in every theme. Text and borders stay opaque."])
		registered.backgroundOpacity = opacity
	end

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

		local reportLabel = L["Report a bug"]
		layout:AddInitializer(CreateSettingsButtonInitializer(
			reportLabel,
			reportLabel,
			ns.ShowBugReport,
			L["Found a bug or have an idea? Please open an issue on GitHub and describe what happened."],
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
