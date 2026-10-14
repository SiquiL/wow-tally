local _, ns = ...
local L = ns.L

local ROW_HEIGHT = 18
local TAB_HEIGHT, TAB_PADDING, TAB_GAP = 22, 24, 2
local TABLE_TOP = -(32 + TAB_HEIGHT + 8)
local MARGIN = 14
local COLUMN_GAP = 16

local window
local selected
local tabs = {}
local tabsWidth = 0
local strings = {}
local sinceRefresh = 0

function ns.CreateWindow(name, width, height, title)
	local created = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
	created:SetSize(width, height)
	created:SetPoint("CENTER")
	created:SetFrameStrata("DIALOG")
	created:SetClampedToScreen(true)
	created:SetMovable(true)
	created:EnableMouse(true)
	created:RegisterForDrag("LeftButton")
	created:SetScript("OnDragStart", created.StartMoving)
	created:SetScript("OnDragStop", created.StopMovingOrSizing)

	local heading = created:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	heading:SetPoint("TOP", 0, -5)
	heading:SetText(title)

	created:Hide()
	table.insert(UISpecialFrames, name)
	return created
end

-- Strings get no fixed width, so a long text widens its column instead of being cut off
local function Text(index, font)
	local fs = strings[index]
	if not fs then
		fs = window:CreateFontString(nil, "OVERLAY")
		fs:SetWordWrap(false)
		strings[index] = fs
	end
	-- A pooled string changes role when the tab changes, so the font is set every time
	fs:SetFontObject(font or "GameFontHighlightSmall")
	fs:ClearAllPoints()
	fs:Show()
	return fs
end

local function CellText(entry, column)
	if not entry then
		return "–"
	end
	local text, extra = ns.FormatEntry(entry)
	if column.total and extra then
		text = text .. " " .. extra
	end
	return text
end

local function Refresh()
	if not window or not selected then
		return
	end

	for _, fs in ipairs(strings) do
		fs:Hide()
	end

	local totals = ns.AccountEntries(selected)
	local columns = {}
	for _, entry in ipairs(totals) do
		if ns.IsVisible(entry) then
			columns[#columns + 1] = { key = entry.key, label = entry.label, total = entry.total, width = 0 }
		end
	end

	local used, nameWidth, rows = 0, 0, {}

	-- Rows are filled first and placed once every column knows its widest text
	local function Row(name, cells, nameFont, cellFont)
		used = used + 1
		local row = { name = Text(used, nameFont), cells = {} }
		row.name:SetText(name)
		nameWidth = math.max(nameWidth, row.name:GetStringWidth())
		for index, column in ipairs(columns) do
			used = used + 1
			local cell = Text(used, cellFont)
			cell:SetText(cells[index])
			column.width = math.max(column.width, cell:GetStringWidth())
			row.cells[index] = cell
		end
		rows[#rows + 1] = row
	end

	local function EntryCells(entries)
		local byKey = {}
		for _, entry in ipairs(entries) do
			byKey[entry.key] = entry
		end
		local cells = {}
		for index, column in ipairs(columns) do
			cells[index] = CellText(byKey[column.key], column)
		end
		return cells
	end

	local headers = {}
	for index, column in ipairs(columns) do
		headers[index] = column.label
	end
	Row(L["Character"], headers, "GameFontNormalSmall", "GameFontNormalSmall")
	ns.ForEachChar(function(key, data)
		local entries = ns.GetEntries(selected, data)
		if entries then
			Row(ns.CharLabel(key, data), EntryCells(entries))
		end
	end)
	Row(L["Account total"], EntryCells(totals), "GameFontNormalSmall")

	local right = MARGIN + nameWidth
	for _, column in ipairs(columns) do
		right = right + COLUMN_GAP + column.width
		column.right = right
	end
	for index, row in ipairs(rows) do
		local y = TABLE_TOP - (index - 1) * ROW_HEIGHT
		row.name:SetPoint("TOPLEFT", window, "TOPLEFT", MARGIN, y)
		for columnIndex, cell in ipairs(row.cells) do
			cell:SetPoint("TOPRIGHT", window, "TOPLEFT", columns[columnIndex].right, y)
		end
	end

	window:SetSize(math.max(tabsWidth, right + MARGIN), -TABLE_TOP + #rows * ROW_HEIGHT + 14)
end

local function Select(module)
	selected = module
	for index, tab in ipairs(tabs) do
		if ns.moduleList[index] == module then
			tab:Disable()
		else
			tab:Enable()
		end
	end
	Refresh()
end

local function Build()
	window = ns.CreateWindow("TallyWindow", 600, 300, "Tally")
	window:SetScript("OnShow", Refresh)
	window:SetScript("OnUpdate", function(_, elapsed)
		sinceRefresh = sinceRefresh + elapsed
		if sinceRefresh >= 1 then
			sinceRefresh = 0
			Refresh()
		end
	end)

	local x = 12
	for index, module in ipairs(ns.moduleList) do
		local tab = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
		tab:SetText(module.label)
		tab:SetSize(tab:GetTextWidth() + TAB_PADDING, TAB_HEIGHT)
		tab:SetPoint("TOPLEFT", x, -30)
		tab:SetScript("OnClick", function()
			Select(module)
		end)
		x = x + tab:GetWidth() + TAB_GAP
		tabs[index] = tab
	end
	tabsWidth = x - TAB_GAP + 12
end

ns.RegisterCommand("window", function(rest)
	local module = ns.modules[rest]
	if rest ~= "" and not module then
		ns.UnknownModule(rest)
		return
	end

	if not window then
		local ok, err = pcall(Build)
		if not ok then
			window = nil
			ns.Say(L["The window could not be created – %s"]:format(tostring(err)))
			return
		end
	end

	if module then
		Select(module)
		window:Show()
	elseif window:IsShown() then
		window:Hide()
	else
		Select(selected or ns.moduleList[1])
		window:Show()
	end
end, L["/tally window [module] – table of every character"])
