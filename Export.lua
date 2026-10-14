local _, ns = ...
local L = ns.L

local window
local scroll

local function Number(value)
	if value == math.floor(value) then
		return ("%.0f"):format(value)
	end
	return ("%.2f"):format(value)
end

-- One row per character, module and entry; the account total uses "ACCOUNT"
local function CollectRows()
	local rows = {}

	local function Add(character, module, entry)
		rows[#rows + 1] = {
			character = character,
			module = module.key,
			metric = entry.key,
			value = entry.value,
			unit = entry.unit or "",
			value2 = entry.value2,
			unit2 = entry.unit2 or "",
		}
	end

	for _, module in ipairs(ns.moduleList) do
		ns.ForEachChar(function(key, data)
			for _, entry in ipairs(ns.GetEntries(module, data) or {}) do
				Add(key, module, entry)
			end
		end)
		for _, entry in ipairs((ns.AccountEntries(module))) do
			Add("ACCOUNT", module, entry)
		end
	end

	return rows
end

local function ToCSV(rows)
	local lines = { "character,module,metric,value,unit,value2,unit2" }
	for _, row in ipairs(rows) do
		lines[#lines + 1] = table.concat({
			row.character,
			row.module,
			row.metric,
			Number(row.value),
			row.unit,
			row.value2 and Number(row.value2) or "",
			row.unit2,
		}, ",")
	end
	return table.concat(lines, "\n")
end

local function Quote(text)
	return '"' .. tostring(text):gsub("[\\\"]", "\\%0") .. '"'
end

local function ToJSON(rows)
	local objects = {}
	for _, row in ipairs(rows) do
		local fields = {
			'"character":' .. Quote(row.character),
			'"module":' .. Quote(row.module),
			'"metric":' .. Quote(row.metric),
			'"value":' .. Number(row.value),
			'"unit":' .. Quote(row.unit),
		}
		if row.value2 then
			fields[#fields + 1] = '"value2":' .. Number(row.value2)
			fields[#fields + 1] = '"unit2":' .. Quote(row.unit2)
		end
		objects[#objects + 1] = "  {" .. table.concat(fields, ",") .. "}"
	end
	return "[\n" .. table.concat(objects, ",\n") .. "\n]"
end

local function Build()
	window = ns.CreateWindow("TallyExportWindow", 560, 420, L["Tally export"])

	scroll = CreateFrame("ScrollFrame", nil, window, "InputScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 14, -34)
	scroll:SetPoint("BOTTOMRIGHT", -14, 14)
	if scroll.CharCount then
		scroll.CharCount:Hide()
	end

	local edit = scroll.EditBox
	edit:SetFontObject("ChatFontNormal")
	edit:SetWidth(520)
	edit:SetScript("OnEscapePressed", function()
		window:Hide()
	end)
	-- The text is only meant to be copied, so typing is undone
	edit:SetScript("OnTextChanged", function(self, userInput)
		if userInput and window.text then
			self:SetText(window.text)
			self:HighlightText()
		end
	end)
end

ns.RegisterCommand("export", function(rest)
	local format = rest == "json" and "json" or "csv"
	if rest ~= "" and rest ~= "csv" and rest ~= "json" then
		ns.Say(L["Usage: /tally export [csv|json]"])
		return
	end

	if not window then
		local ok, err = pcall(Build)
		if not ok then
			window = nil
			ns.Say(L["The export window could not be created – %s"]:format(tostring(err)))
			return
		end
	end

	local rows = CollectRows()
	window.text = format == "json" and ToJSON(rows) or ToCSV(rows)
	window:Show()
	scroll.EditBox:SetText(window.text)
	scroll.EditBox:HighlightText()
	scroll.EditBox:SetFocus()
end, L["/tally export [csv|json] – copyable export of all values"])
