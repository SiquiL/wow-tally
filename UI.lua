local _, ns = ...
local L = ns.L

local ROW_HEIGHT = 18
local HEADER_HEIGHT = 20
local MAX_VISIBLE_ROWS = 15
local FILTER_ROW_HEIGHT = 24
local MAX_FILTER_ROWS = 12
local FILTER_GAP = 6
local TAB_HEIGHT, TAB_PADDING, TAB_GAP = 22, 24, 2
local TABLE_TOP = -(32 + TAB_HEIGHT + 8)
local MARGIN = 14
local COLUMN_GAP = 16
local SCROLL_WIDTH = 20
local ICON_SIZE = 26
local ICON_INSET = 5
local TOOLBAR_GAP = 12
local FILTER_ICON = "Interface\\Icons\\INV_Misc_GroupNeedMore"
local EXPORT_ICON = "Interface\\Icons\\INV_Scroll_03"
local OPTIONS_ICON = "Interface\\Icons\\Trade_Engineering"
local VALID_POINTS = {
	TOPLEFT = true,
	TOP = true,
	TOPRIGHT = true,
	LEFT = true,
	CENTER = true,
	RIGHT = true,
	BOTTOMLEFT = true,
	BOTTOM = true,
	BOTTOMRIGHT = true,
}

local window
local scroll
local measure
local headerBackground
local selected
local optionsButton
local filterWindow
local filterScroll
local filterRows = {}
local filterCharacters = {}
local tabs = {}
local tabsWidth = 0
local headerButtons = {}
local rowFrames = {}
local sinceRefresh = 0
local moduleViewsRegistered = false
local sortStates = {}
local failedViews = {}

ns.views = {}
ns.viewList = {}

function ns.RegisterView(key, view)
	assert(not ns.views[key], "Tally: duplicate view " .. key)
	view.key = key
	ns.views[key] = view
	ns.viewList[#ns.viewList + 1] = view
end

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

local function IconButton(icon, tooltip, disabledTooltip, onClick)
	local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
	button:SetSize(ICON_SIZE, ICON_SIZE)

	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetPoint("TOPLEFT", ICON_INSET, -ICON_INSET)
	button.icon:SetPoint("BOTTOMRIGHT", -ICON_INSET, ICON_INSET)
	button.icon:SetTexture(icon)
	button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	button:SetScript("OnClick", onClick)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(tooltip)
		if disabledTooltip and not self:IsEnabled() then
			GameTooltip:AddLine(disabledTooltip, 1, 0.3, 0.3, true)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	return button
end

local function SetIconEnabled(button, enabled)
	button:SetEnabled(enabled)
	button.icon:SetDesaturated(not enabled)
	button.icon:SetAlpha(enabled and 1 or 0.35)
end

local function SaveWindowState()
	if not window then
		return
	end

	local point, _, relativePoint, x, y = window:GetPoint(1)
	local state = TallyDB.settings.window or {}
	state.point = VALID_POINTS[point] and point or "CENTER"
	state.relativePoint = VALID_POINTS[relativePoint] and relativePoint or "CENTER"
	state.x = x or 0
	state.y = y or 0
	state.width = nil
	state.height = nil
	TallyDB.settings.window = state
end

local function RestoreWindowState()
	local state = TallyDB.settings.window or {}
	local point = VALID_POINTS[state.point] and state.point or "CENTER"
	local relativePoint = VALID_POINTS[state.relativePoint] and state.relativePoint or point

	window:ClearAllPoints()
	window:SetPoint(point, UIParent, relativePoint, tonumber(state.x) or 0, tonumber(state.y) or 0)
end

function ns.ResetWindowPosition()
	local state = TallyDB.settings.window or {}
	state.point = "CENTER"
	state.relativePoint = "CENTER"
	state.x = 0
	state.y = 0
	state.width = nil
	state.height = nil
	TallyDB.settings.window = state

	if window then
		window:ClearAllPoints()
		window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	ns.Say(L["The window position has been reset."])
end

local function HeaderText(entry)
	if entry.headerUnit then
		return ("%s (%s)"):format(entry.label, entry.headerUnit)
	end
	return entry.label
end

local function EntryCell(entry, role)
	if not entry then
		return { text = "–" }
	end
	return { text = ns.FormatCell(entry), sort = entry.value, role = role }
end

local function EntryCells(entries, columns)
	local byKey = {}
	for _, entry in ipairs(entries or {}) do
		byKey[entry.key] = entry
	end

	local cells = {}
	for index = 2, #columns do
		cells[index] = EntryCell(byKey[columns[index].key])
	end
	return cells
end

local function BuildModuleTable(module)
	local totals = ns.AccountEntries(module)
	local characters = {}
	local populated = {}

	ns.ForEachChar(function(key, data)
		local entries = ns.GetEntries(module, data)
		if entries then
			characters[#characters + 1] = { key = key, data = data, entries = entries }
			for _, entry in ipairs(entries) do
				if entry.value ~= 0 or (entry.value2 or 0) ~= 0 then
					populated[entry.key] = true
				end
			end
		end
	end)

	local columns = {
		{ key = "character", label = L["Character"], align = "LEFT", sortType = "text" },
	}

	for _, entry in ipairs(totals) do
		local hasValues = populated[entry.key]
		if (not entry.optional or hasValues) and (not TallyDB.settings.hideEmpty or hasValues) then
			columns[#columns + 1] = {
				key = entry.key,
				label = HeaderText(entry),
				align = "RIGHT",
				sortType = "number",
			}
		end
	end

	local rows = {}
	for _, character in ipairs(characters) do
		local cells = EntryCells(character.entries, columns)
		cells[1] = { text = ns.CharLabel(character.key, character.data), sort = character.key:lower() }
		rows[#rows + 1] = { key = character.key, cells = cells }
	end

	local cells = EntryCells(totals, columns)
	cells[1] = { text = L["Account total"], sort = "" }
	rows[#rows + 1] = { key = "ACCOUNT", role = "total", cells = cells }

	return { columns = columns, rows = rows }
end

local function OverviewLabel(module, entry)
	if entry.label == module.label or entry.label == L["Total"] then
		return module.label
	end
	return ("%s – %s"):format(module.label, entry.label)
end

local function RankingLabel(module, entry)
	local label = OverviewLabel(module, entry)
	if entry.headerUnit then
		return ("%s (%s)"):format(label, entry.headerUnit)
	end
	return label
end

local function BuildOverview()
	local columns = {
		{ key = "statistic", label = L["Statistic"], align = "LEFT", sortType = "text" },
		{ key = "character", label = ns.CharLabel(ns.charKey, ns.char), align = "RIGHT", sortType = "number" },
		{ key = "account", label = L["Account total"], align = "RIGHT", sortType = "number" },
	}
	local rows = {}

	for _, module in ipairs(ns.moduleList) do
		local characterEntries = ns.GetEntries(module, ns.char)
		local accountEntries = ns.AccountEntries(module)
		local accountByKey = {}
		for _, entry in ipairs(accountEntries) do
			accountByKey[entry.key] = entry
		end

		for _, entry in ipairs(characterEntries or {}) do
			if entry.total then
				local label = OverviewLabel(module, entry)
				rows[#rows + 1] = {
					key = module.key .. "." .. entry.key,
					cells = {
						{ text = label, sort = label:lower() },
						EntryCell(entry),
						EntryCell(accountByKey[entry.key], "total"),
					},
				}
			end
		end
	end

	return { columns = columns, rows = rows }
end

local function BuildRanking()
	local columns = {
		{ key = "rank", label = L["Rank"], align = "RIGHT", sortable = false, minWidth = 32 },
		{
			key = "character",
			label = L["Character"],
			align = "LEFT",
			sortType = "number",
			sortDirection = "desc",
			sortTooltip = L["Click to rank characters by level."],
			minWidth = 80,
		},
	}
	local metrics = {}

	for _, module in ipairs(ns.moduleList) do
		for _, entry in ipairs(ns.AccountEntries(module)) do
			if entry.total then
				local key = module.key .. "." .. entry.key
				metrics[#metrics + 1] = { columnKey = key }
				columns[#columns + 1] = {
					key = key,
					label = RankingLabel(module, entry),
					align = "RIGHT",
					sortType = "number",
					sortDirection = "desc",
				}
			end
		end
	end

	local rows = {}
	ns.ForEachChar(function(key, data)
		local entriesByMetric = {}
		for _, module in ipairs(ns.moduleList) do
			for _, entry in ipairs(ns.GetEntries(module, data) or {}) do
				entriesByMetric[module.key .. "." .. entry.key] = entry
			end
		end

		local cells = {
			{ text = "" },
			{ text = ns.CharLabel(key, data), sort = tonumber(data.level) or 0 },
		}
		for index, metric in ipairs(metrics) do
			cells[index + 2] = EntryCell(entriesByMetric[metric.columnKey])
		end
		rows[#rows + 1] = { key = key, cells = cells }
	end)

	local defaultSort = metrics[1]
		and { key = metrics[1].columnKey, direction = "desc" }
		or { key = "character", direction = "asc" }
	return {
		columns = columns,
		rows = rows,
		rankColumn = 1,
		defaultSort = defaultSort,
	}
end

local function EnsureModuleViews()
	if moduleViewsRegistered then
		return
	end
	moduleViewsRegistered = true

	ns.RegisterView("overview", {
		label = L["Overview"],
		Build = BuildOverview,
	})

	ns.RegisterView("ranking", {
		label = L["Ranking"],
		Build = BuildRanking,
	})

	for _, module in ipairs(ns.moduleList) do
		local current = module
		ns.RegisterView(current.key, {
			label = current.label,
			Build = function()
				return BuildModuleTable(current)
			end,
		})
	end
end

local function SortRows(model)
	local state = sortStates[selected.key]
	if not state then
		state = model.defaultSort or { key = model.columns[1].key, direction = "asc" }
		sortStates[selected.key] = state
	end

	local columnIndex
	for index, column in ipairs(model.columns) do
		if column.key == state.key then
			columnIndex = index
			break
		end
	end
	if not columnIndex then
		columnIndex = 1
		state.key, state.direction = model.columns[1].key, "asc"
	end

	local sortable, fixed = {}, {}
	for _, row in ipairs(model.rows) do
		if row.role == "total" then
			fixed[#fixed + 1] = row
		else
			sortable[#sortable + 1] = row
		end
	end

	table.sort(sortable, function(left, right)
		local leftValue = left.cells[columnIndex] and left.cells[columnIndex].sort
		local rightValue = right.cells[columnIndex] and right.cells[columnIndex].sort
		if leftValue == rightValue then
			return left.key < right.key
		elseif leftValue == nil then
			return false
		elseif rightValue == nil then
			return true
		elseif state.direction == "desc" then
			return leftValue > rightValue
		end
		return leftValue < rightValue
	end)

	model.rows = sortable
	for _, row in ipairs(fixed) do
		model.rows[#model.rows + 1] = row
	end
	if model.rankColumn then
		for rank, row in ipairs(sortable) do
			row.cells[model.rankColumn] = { text = tostring(rank), sort = rank }
		end
	end
end

local function SortLabel(column)
	return column.label
end

local function Measure(font, text)
	measure:SetFontObject(font)
	measure:SetText(text or "")
	return measure:GetStringWidth()
end

local function LayoutColumns(model)
	local left = 0
	for index, column in ipairs(model.columns) do
		local minWidth = column.minWidth or (index == 1 and 80 or 32)
		column.width = math.max(Measure("GameFontNormalSmall", SortLabel(column)), minWidth)
		for _, row in ipairs(model.rows) do
			local cell = row.cells[index]
			local font = (row.role == "total" or cell and cell.role == "total")
				and "GameFontNormalSmall" or "GameFontHighlightSmall"
			column.width = math.max(column.width, Measure(font, cell and cell.text or "–"))
		end
		column.left = left
		left = left + column.width + COLUMN_GAP
	end
	return left - COLUMN_GAP
end

local function HeaderButton(index)
	local button = headerButtons[index]
	if button then
		return button
	end

	button = CreateFrame("Button", nil, window)
	button:SetHeight(HEADER_HEIGHT)
	local label = button:CreateFontString(nil, "OVERLAY")
	button:SetFontString(label)
	button:SetNormalFontObject("GameFontNormalSmall")
	button:SetHighlightFontObject("GameFontHighlightSmall")
	label:SetWordWrap(false)
	button:SetScript("OnEnter", function(self)
		if self.column.sortable == false then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(self.column.label)
		GameTooltip:AddLine(self.column.sortTooltip or L["Click to sort this column."], 1, 1, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	headerButtons[index] = button
	return button
end

local function RowFrame(index)
	local frame = rowFrames[index]
	if frame then
		return frame
	end

	frame = CreateFrame("Frame", nil, window)
	frame.cells = {}
	frame.background = frame:CreateTexture(nil, "BACKGROUND")
	frame.background:SetAllPoints()
	frame.background:SetColorTexture(1, 0.82, 0, 0.08)
	frame.separator = frame:CreateTexture(nil, "ARTWORK")
	frame.separator:SetPoint("TOPLEFT")
	frame.separator:SetPoint("TOPRIGHT")
	frame.separator:SetHeight(1)
	frame.separator:SetColorTexture(1, 0.82, 0, 0.45)
	rowFrames[index] = frame
	return frame
end

local function RowCell(frame, index)
	local cell = frame.cells[index]
	if not cell then
		cell = frame:CreateFontString(nil, "OVERLAY")
		cell:SetWordWrap(false)
		frame.cells[index] = cell
	end
	return cell
end

local currentModel
local tableWidth = 0

local function RenderRows()
	if not currentModel then
		return
	end

	local offset = FauxScrollFrame_GetOffset(scroll)
	for slot = 1, MAX_VISIBLE_ROWS do
		local frame = RowFrame(slot)
		local row = currentModel.rows[offset + slot]
		if row then
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", window, "TOPLEFT", MARGIN, TABLE_TOP - HEADER_HEIGHT - (slot - 1) * ROW_HEIGHT)
			frame:SetSize(tableWidth, ROW_HEIGHT)
			if row.role == "total" then
				frame.background:Show()
				frame.separator:Show()
			else
				frame.background:Hide()
				frame.separator:Hide()
			end
			frame:Show()

			for index, column in ipairs(currentModel.columns) do
				local cell = RowCell(frame, index)
				local data = row.cells[index]
				cell:SetFontObject(
					(row.role == "total" or data and data.role == "total")
						and "GameFontNormalSmall" or "GameFontHighlightSmall"
				)
				cell:ClearAllPoints()
				cell:SetPoint("TOPLEFT", frame, "TOPLEFT", column.left, 0)
				cell:SetSize(column.width, ROW_HEIGHT)
				cell:SetJustifyH(column.align)
				cell:SetText(data and data.text or "–")
				cell:Show()
			end
			for index = #currentModel.columns + 1, #frame.cells do
				frame.cells[index]:Hide()
			end
		else
			frame:Hide()
		end
	end
end

local function SetSort(column)
	if column.sortable == false then
		return
	end
	local state = sortStates[selected.key]
	if column.sortDirection then
		sortStates[selected.key] = {
			key = column.key,
			direction = column.sortDirection,
		}
	elseif state and state.key == column.key then
		state.direction = state.direction == "asc" and "desc" or "asc"
	else
		sortStates[selected.key] = {
			key = column.key,
			direction = column.sortType == "number" and "desc" or "asc",
		}
	end
end

local function Refresh()
	if not window or not selected then
		return
	end

	if optionsButton then
		SetIconEnabled(optionsButton, not InCombatLockdown())
	end

	local ok, model = pcall(selected.Build, selected)
	if not ok then
		if not failedViews[selected.key] then
			failedViews[selected.key] = true
			ns.Say(("|cffff5555%s|r – %s"):format(
				L["%s.%s failed"]:format(selected.label, "Build"),
				tostring(model)
			))
		end
		return
	end
	if not model or not model.columns or not model.rows then
		return
	end
	SortRows(model)
	currentModel = model
	tableWidth = LayoutColumns(model)

	headerBackground:ClearAllPoints()
	headerBackground:SetPoint("TOPLEFT", window, "TOPLEFT", MARGIN, TABLE_TOP)
	headerBackground:SetSize(tableWidth, HEADER_HEIGHT)

	for index, column in ipairs(model.columns) do
		local current = column
		local button = HeaderButton(index)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", window, "TOPLEFT", MARGIN + current.left, TABLE_TOP)
		button:SetSize(current.width, HEADER_HEIGHT)
		button:GetFontString():SetJustifyH(current.align)
		button.column = current
		button:SetText(SortLabel(current))
		button:EnableMouse(current.sortable ~= false)
		local sortState = sortStates[selected.key]
		if sortState and sortState.key == current.key then
			button:GetFontString():SetTextColor(1, 0.82, 0)
		else
			button:GetFontString():SetTextColor(1, 1, 1)
		end
		button:SetScript("OnClick", function()
			if current.sortable ~= false then
				SetSort(current)
				Refresh()
			end
		end)
		button:Show()
	end
	for index = #model.columns + 1, #headerButtons do
		headerButtons[index]:Hide()
	end

	local visibleRows = math.min(math.max(#model.rows, 1), MAX_VISIBLE_ROWS)
	scroll:ClearAllPoints()
	scroll:SetPoint("TOPLEFT", window, "TOPLEFT", MARGIN, TABLE_TOP - HEADER_HEIGHT)
	scroll:SetSize(tableWidth + SCROLL_WIDTH, visibleRows * ROW_HEIGHT)
	FauxScrollFrame_Update(scroll, #model.rows, visibleRows, ROW_HEIGHT)
	RenderRows()

	window:SetSize(
		math.max(tabsWidth, tableWidth + MARGIN * 2 + (#model.rows > visibleRows and SCROLL_WIDTH or 0)),
		-TABLE_TOP + HEADER_HEIGHT + visibleRows * ROW_HEIGHT + MARGIN
	)
end

local function Select(view)
	selected = view
	TallyDB.settings.view = view.key
	for index, tab in ipairs(tabs) do
		if ns.viewList[index] == view then
			tab:Disable()
		else
			tab:Enable()
		end
	end
	if scroll then
		FauxScrollFrame_SetOffset(scroll, 0)
	end
	Refresh()
end

local RefreshCharacterFilter

local function RenderCharacterFilter()
	local offset = FauxScrollFrame_GetOffset(filterScroll)
	for slot = 1, MAX_FILTER_ROWS do
		local row = filterRows[slot]
		local character = filterCharacters[offset + slot]
		if character then
			row.key = character.key
			row.label:SetText(ns.CharLabel(character.key, character.data))
			row.checkbox:SetChecked(ns.IsCharacterVisible(character.key))
			row.checkbox:SetEnabled(character.key ~= ns.charKey)
			row.remove:SetEnabled(character.key ~= ns.charKey)
			row:Show()
		else
			row:Hide()
		end
	end
end

local function CharacterFilterRow(slot)
	local row = CreateFrame("Frame", nil, filterWindow)
	row:SetSize(340, FILTER_ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 14, -62 - (slot - 1) * FILTER_ROW_HEIGHT)

	row.checkbox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	row.checkbox:SetSize(FILTER_ROW_HEIGHT, FILTER_ROW_HEIGHT)
	row.checkbox:SetPoint("LEFT")
	row.checkbox:SetScript("OnClick", function(self)
		if row.key == ns.charKey then
			self:SetChecked(true)
			return
		end
		TallyDB.settings.hidden[row.key] = self:GetChecked() and nil or true
		Refresh()
	end)
	row.checkbox:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(
			row.key == ns.charKey
				and L["The active character is always included."]
				or L["Include this character in totals, reports and exports."]
		)
		GameTooltip:Show()
	end)
	row.checkbox:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.label:SetPoint("LEFT", row.checkbox, "RIGHT", 4, 0)
	row.label:SetPoint("RIGHT", row, "RIGHT", -32, 0)
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)

	row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	row.remove:SetSize(24, 20)
	row.remove:SetPoint("RIGHT")
	row.remove:SetText("X")
	row.remove:SetScript("OnClick", function()
		ns.RemoveCharacter(row.key, function()
			RefreshCharacterFilter()
			Refresh()
			if ns.RefreshExport then
				ns.RefreshExport()
			end
		end)
	end)
	row.remove:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(
			row.key == ns.charKey and L["The active character cannot be removed."] or L["Remove character"]
		)
		GameTooltip:Show()
	end)
	row.remove:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	filterRows[slot] = row
end

RefreshCharacterFilter = function()
	filterCharacters = {}
	ns.ForEachStoredChar(function(key, data)
		filterCharacters[#filterCharacters + 1] = { key = key, data = data }
	end)

	local visibleRows = math.min(math.max(#filterCharacters, 1), MAX_FILTER_ROWS)
	local maxOffset = math.max(0, #filterCharacters - visibleRows)
	if FauxScrollFrame_GetOffset(filterScroll) > maxOffset then
		FauxScrollFrame_SetOffset(filterScroll, maxOffset)
	end
	filterWindow:SetSize(390, 62 + visibleRows * FILTER_ROW_HEIGHT + MARGIN)
	filterScroll:SetSize(360, visibleRows * FILTER_ROW_HEIGHT)
	FauxScrollFrame_Update(filterScroll, #filterCharacters, visibleRows, FILTER_ROW_HEIGHT)
	RenderCharacterFilter()
end

-- Docked to the main window so the two frames never cover each other
function ns.DockWindowBeside(frame)
	frame:ClearAllPoints()
	if not window then
		frame:SetPoint("CENTER")
		return
	end

	local gap = FILTER_GAP
	local spaceRight = UIParent:GetRight() - window:GetRight()
	if spaceRight >= frame:GetWidth() + gap then
		frame:SetPoint("TOPLEFT", window, "TOPRIGHT", gap, 0)
	else
		frame:SetPoint("TOPRIGHT", window, "TOPLEFT", -gap, 0)
	end
end

local function AnchorCharacterFilter()
	ns.DockWindowBeside(filterWindow)
end

local function SetCharacterFilter(mode)
	if mode == "all" then
		TallyDB.settings.hidden = {}
	else
		ns.ForEachStoredChar(function(key)
			TallyDB.settings.hidden[key] = key ~= ns.charKey and true or nil
		end)
	end
	RefreshCharacterFilter()
	Refresh()
	if ns.RefreshExport then
		ns.RefreshExport()
	end
end

local function BuildCharacterFilter()
	filterWindow = ns.CreateWindow("TallyCharacterFilterWindow", 390, 200, L["Character filter"])

	local x = 14
	for _, action in ipairs({
		{ label = L["All"], mode = "all" },
		{ label = L["Only current"], mode = "current" },
	}) do
		local current = action
		local button = CreateFrame("Button", nil, filterWindow, "UIPanelButtonTemplate")
		button:SetText(current.label)
		button:SetSize(button:GetTextWidth() + TAB_PADDING, TAB_HEIGHT)
		button:SetPoint("TOPLEFT", x, -30)
		button:SetScript("OnClick", function()
			SetCharacterFilter(current.mode)
		end)
		x = x + button:GetWidth() + TAB_GAP
	end

	filterScroll = CreateFrame("ScrollFrame", "TallyCharacterFilterScrollFrame", filterWindow, "FauxScrollFrameTemplate")
	filterScroll:SetPoint("TOPLEFT", 14, -62)
	filterScroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, FILTER_ROW_HEIGHT, RenderCharacterFilter)
	end)

	for slot = 1, MAX_FILTER_ROWS do
		CharacterFilterRow(slot)
	end
	filterWindow:SetScript("OnShow", function()
		RefreshCharacterFilter()
		AnchorCharacterFilter()
	end)
end

local function ToggleCharacterFilter()
	if not filterWindow then
		local ok, err = pcall(BuildCharacterFilter)
		if not ok then
			filterWindow = nil
			ns.Say(L["The character filter could not be created – %s"]:format(tostring(err)))
			return
		end
	end

	if filterWindow:IsShown() then
		filterWindow:Hide()
	else
		filterWindow:Show()
	end
end

local function Build()
	EnsureModuleViews()
	window = ns.CreateWindow("TallyWindow", 600, 300, "Tally")
	RestoreWindowState()
	window:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	window:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SaveWindowState()
	end)
	window:SetScript("OnHide", function()
		SaveWindowState()
		if filterWindow then
			filterWindow:Hide()
		end
	end)

	measure = window:CreateFontString(nil, "OVERLAY")
	measure:SetPoint("TOPLEFT", window, "BOTTOMLEFT", -1000, -1000)
	measure:SetAlpha(0)

	headerBackground = window:CreateTexture(nil, "BACKGROUND")
	headerBackground:SetColorTexture(0, 0, 0, 0.3)

	scroll = CreateFrame("ScrollFrame", "TallyTableScrollFrame", window, "FauxScrollFrameTemplate")
	scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, RenderRows)
	end)

	window:SetScript("OnShow", Refresh)
	window:SetScript("OnUpdate", function(_, elapsed)
		sinceRefresh = sinceRefresh + elapsed
		if sinceRefresh >= 1 then
			sinceRefresh = 0
			Refresh()
		end
	end)

	local x = 12
	for index, view in ipairs(ns.viewList) do
		local current = view
		local tab = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
		tab:SetText(current.label)
		tab:SetSize(tab:GetTextWidth() + TAB_PADDING, TAB_HEIGHT)
		tab:SetPoint("TOPLEFT", x, -30)
		tab:SetScript("OnClick", function()
			Select(current)
		end)
		x = x + tab:GetWidth() + TAB_GAP
		tabs[index] = tab
	end

	local exportButton = IconButton(EXPORT_ICON, L["Export"], nil, function()
		ns.commands.export("")
	end)

	local filterButton = IconButton(FILTER_ICON, L["Character filter"], nil, ToggleCharacterFilter)

	optionsButton = IconButton(OPTIONS_ICON, L["Options"], L["The options cannot be opened in combat."], function()
		ns.commands.options("")
	end)
	optionsButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", -MARGIN, -28)
	exportButton:SetPoint("RIGHT", optionsButton, "LEFT", -TAB_GAP, 0)
	filterButton:SetPoint("RIGHT", exportButton, "LEFT", -TAB_GAP, 0)

	tabsWidth = x + TOOLBAR_GAP + ICON_SIZE * 3 + TAB_GAP * 2 + MARGIN
	selected = ns.views[TallyDB.settings.view] or ns.viewList[1]
end

ns.RegisterCommand("window", function(rest)
	EnsureModuleViews()
	local view = ns.views[rest]
	if rest ~= "" and not view then
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

	if view then
		Select(view)
		window:Show()
	elseif window:IsShown() then
		window:Hide()
	else
		Select(selected or ns.viewList[1])
		window:Show()
	end
end, L["/tally window [module] – table of every character"])
