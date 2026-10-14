local _, ns = ...
local L = ns.L

local REQUEST_DELAY = 5
local UNMUTE_DELAY = 10
local DAY = 86400

local played
local sessionStart
local muted = {}

local function FormatDays(seconds)
	return L["%d days"]:format(seconds / DAY)
end

local module = {
	label = L["Playtime"],
	-- synced is a default so that a reset makes the next import silent again
	defaults = { total = 0, synced = false },
	events = { "TIME_PLAYED_MSG" },
	milestones = {
		{ key = "total", thresholds = { 7 * DAY, 30 * DAY, 100 * DAY, 365 * DAY, 1000 * DAY }, text = L["%s played"], fmt = FormatDays },
	},
}

-- The answer to RequestTimePlayed is printed like /played unless the chat frames skip it
local function MuteChat()
	for _, name in pairs(CHAT_FRAMES or {}) do
		local frame = _G[name]
		if frame and frame:IsEventRegistered("TIME_PLAYED_MSG") then
			frame:UnregisterEvent("TIME_PLAYED_MSG")
			muted[#muted + 1] = frame
		end
	end
end

local function UnmuteChat()
	for _, frame in ipairs(muted) do
		frame:RegisterEvent("TIME_PLAYED_MSG")
	end
	muted = {}
end

local function Request()
	if not RequestTimePlayed or InCombatLockdown() then
		return
	end
	MuteChat()
	RequestTimePlayed()
	C_Timer.After(UNMUTE_DELAY, UnmuteChat)
end

function module:OnLogin(section)
	played = section
	sessionStart = GetTime()
	C_Timer.After(REQUEST_DELAY, Request)
end

-- Also fires when the player types /played
function module:OnEvent(_, total)
	if ns.isSecret(total) then
		return
	end
	-- The server value already contains this session
	played.total = total
	sessionStart = GetTime()
	if not played.synced then
		played.synced = true
		ns.SyncMilestones(self)
	end
	C_Timer.After(0, UnmuteChat)
end

function module:OnLogout(section)
	section.total = math.floor(section.total + GetTime() - sessionStart + 0.5)
end

function module:Summary(charData)
	local total = charData.played.total or 0
	-- Only the logged-in character is still counting
	if charData == ns.char and sessionStart then
		total = total + GetTime() - sessionStart
	end
	return {
		{ key = "total", label = L["Total"], value = total, unit = "s", fmt = ns.FormatDuration, total = true },
	}
end

ns.RegisterModule("played", module)
