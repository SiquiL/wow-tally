local _, ns = ...
local L = ns.L

local frames, texts = {}, {}
local DEFAULT_BACKGROUND = { 0.08, 0.08, 0.08 }
local palettes = {
	standard = { body = { 1, 1, 1 }, heading = { 1, 0.82, 0 }, muted = { 0.6, 0.6, 0.6 } },
	light = { body = { 0.16, 0.1, 0.05 }, heading = { 0.34, 0.16, 0.04 }, muted = { 0.4, 0.32, 0.23 } },
}

ns.THEMES = {
	{ id = "standard", label = "Standard" },
	{ id = "custom", label = "Custom color" },
}
local themeById = {}
for _, theme in ipairs(ns.THEMES) do
	themeById[theme.id] = theme
end

function ns.IsTheme(id)
	return themeById[id] ~= nil
end

function ns.ValidColor(color)
	if type(color) ~= "table" then
		return false
	end
	for i = 1, 3 do
		if type(color[i]) ~= "number" or color[i] ~= color[i] or color[i] < 0 or color[i] > 1 then
			return false
		end
	end
	return true
end

function ns.ValidOpacity(alpha)
	return type(alpha) == "number" and alpha == alpha and alpha >= 0 and alpha <= 1
end

local function Custom()
	return TallyDB.settings.theme == "custom"
end

function ns.BackgroundColor()
	local color = TallyDB.settings.backgroundColor
	return ns.ValidColor(color) and color or DEFAULT_BACKGROUND
end

-- Applies to every theme; only backgrounds fade, text and borders stay opaque
function ns.BackgroundOpacity()
	local alpha = TallyDB.settings.backgroundOpacity
	return ns.ValidOpacity(alpha) and alpha or 1
end

function ns.SetBackgroundOpacity(alpha)
	if not ns.ValidOpacity(alpha) then
		return
	end
	TallyDB.settings.backgroundOpacity = alpha
	ns.RefreshAppearance()
end

local function Light()
	local color = ns.BackgroundColor()
	-- A mostly transparent background shows the game world, so the text stays light
	return Custom() and ns.BackgroundOpacity() >= 0.5
		and color[1] * 0.2126 + color[2] * 0.7152 + color[3] * 0.0722 > 0.55
end

function ns.ThemeColor(role)
	local palette = Light() and palettes.light or palettes.standard
	return unpack(palette[role] or palette.body)
end

local function ApplyFrame(entry)
	local alpha = ns.BackgroundOpacity()
	local custom = Custom()
	if custom then
		local r, g, b = unpack(ns.BackgroundColor())
		entry.texture:SetColorTexture(r, g, b, alpha)
		entry.texture:Show()
	else
		entry.texture:Hide()
	end
	-- The template's own backgrounds would otherwise cover the custom color
	for _, background in ipairs(entry.backgrounds) do
		background:SetAlpha(custom and 0 or alpha)
	end
end

-- Every background texture of the frame template (Bg, InsetBg, Inset.Bg, ...), whatever the client names them
local function TemplateBackgrounds(frame)
	-- The title bar stays opaque
	local list, seen = {}, {}
	for _, key in ipairs({ "TitleBg", "TopTileStreaks" }) do
		if frame[key] then
			seen[frame[key]] = true
		end
	end
	local function Add(region)
		if region and not seen[region] and region.SetAlpha then
			seen[region] = true
			list[#list + 1] = region
		end
	end
	local function Scan(owner)
		if not (owner and owner.GetRegions) then
			return
		end
		for _, region in ipairs({ owner:GetRegions() }) do
			if region.GetObjectType and region:GetObjectType() == "Texture"
				and region.GetDrawLayer and region:GetDrawLayer() == "BACKGROUND" then
				Add(region)
			end
		end
	end
	Scan(frame)
	Scan(frame.Inset)
	Add(frame.Bg)
	Add(frame.InsetBg)
	Add(frame.Inset and frame.Inset.Bg)
	return list
end

function ns.StyleFrame(frame)
	local backgrounds = TemplateBackgrounds(frame)
	local texture = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
	texture:SetPoint("TOPLEFT", 5, -24)
	texture:SetPoint("BOTTOMRIGHT", -5, 5)
	local entry = { texture = texture, backgrounds = backgrounds }
	frames[#frames + 1] = entry
	ApplyFrame(entry)
end

function ns.StyleText(text, role)
	texts[#texts + 1] = { text = text, role = role or "body" }
	text:SetTextColor(ns.ThemeColor(role))
end

function ns.RefreshAppearance()
	for _, entry in ipairs(frames) do
		ApplyFrame(entry)
	end
	for _, entry in ipairs(texts) do
		entry.text:SetTextColor(ns.ThemeColor(entry.role))
	end
	if ns.RefreshWindow then
		ns.RefreshWindow()
	end
end

function ns.SetTheme(theme)
	if not ns.IsTheme(theme) then
		ns.Say(L["Unknown theme."])
		return
	end
	TallyDB.settings.theme = theme
	ns.RefreshAppearance()
end

-- Passing an opacity adds the picker's opacity slider; onChange then also receives the alpha
function ns.PickColor(color, onChange, opacity)
	if not (ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow) then
		ns.Say(L["The color picker is not available in this client."])
		return
	end
	local original = { unpack(color) }
	local hasOpacity = opacity ~= nil and ColorPickerFrame.GetColorAlpha ~= nil
	local function Changed()
		local r, g, b = ColorPickerFrame:GetColorRGB()
		onChange({ r, g, b }, hasOpacity and ColorPickerFrame:GetColorAlpha() or opacity)
	end
	ColorPickerFrame:SetupColorPickerAndShow({
		r = color[1],
		g = color[2],
		b = color[3],
		hasOpacity = hasOpacity,
		opacity = opacity,
		swatchFunc = Changed,
		opacityFunc = hasOpacity and Changed or nil,
		cancelFunc = function()
			onChange(original, opacity)
		end,
	})
end
