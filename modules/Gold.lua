local _, ns = ...
local L = ns.L

-- PLAYER_MONEY and ACCOUNT_MONEY of one warband bank transfer arrive as separate events
local FLUSH_DELAY = 0.5

local hasWarbandBank = C_Bank and C_Bank.FetchDepositedMoney and Enum.BankType and Enum.BankType.Account and true or false

local gold
local lastMoney, lastAccount
local flushPending = false

local function FormatMoney(copper)
	copper = math.floor(copper + 0.5)
	if GetCoinTextureString then
		return GetCoinTextureString(copper)
	end
	return ("%dg %ds %dc"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

local module = {
	label = L["Gold"],
	defaults = { earned = 0, spent = 0, current = 0 },
	-- The balance on hand is a reading, not a counter
	keepOnReset = { current = true },
	events = { "PLAYER_ENTERING_WORLD", "PLAYER_MONEY", hasWarbandBank and "ACCOUNT_MONEY" or nil },
	milestones = {
		{ key = "earned", thresholds = { 100000, 1000000, 10000000, 100000000, 1000000000, 10000000000 }, text = L["%s earned"], fmt = FormatMoney },
	},
}

local function AccountMoney()
	return C_Bank.FetchDepositedMoney(Enum.BankType.Account)
end

-- GetMoney is only reliable from PLAYER_ENTERING_WORLD on, so nothing is counted before that
local function SetBaseline()
	local money = GetMoney()
	if ns.isSecret(money) then
		return
	end
	lastMoney = money
	gold.current = money
	if hasWarbandBank then
		lastAccount = AccountMoney()
	end
end

local function Flush()
	flushPending = false
	local money = GetMoney()
	if not lastMoney or ns.isSecret(money) then
		return
	end

	-- Mail, trades and the auction house count like any other income or expense, but a
	-- warband bank transfer moves both balances in opposite directions and is left out
	local delta = money - lastMoney
	if hasWarbandBank then
		local account = AccountMoney()
		local accountDelta = account - (lastAccount or account)
		if delta < 0 and accountDelta > 0 then
			delta = math.min(delta + accountDelta, 0)
		elseif delta > 0 and accountDelta < 0 then
			delta = math.max(delta + accountDelta, 0)
		end
		lastAccount = account
	end

	if delta > 0 then
		gold.earned = gold.earned + delta
	elseif delta < 0 then
		gold.spent = gold.spent - delta
	end
	lastMoney = money
	gold.current = money
end

function module:OnLogin(section)
	gold = section
	lastMoney, lastAccount = nil, nil
end

function module:OnEvent(event)
	if event == "PLAYER_ENTERING_WORLD" then
		if not lastMoney then
			SetBaseline()
		end
	elseif lastMoney and not flushPending then
		flushPending = true
		C_Timer.After(FLUSH_DELAY, Flush)
	end
end

function module:OnLogout()
	Flush()
end

function module:Summary(charData)
	local section = charData.gold
	return {
		{ key = "earned", label = L["Earned"], value = section.earned or 0, unit = "copper", fmt = FormatMoney, total = true },
		{ key = "spent", label = L["Spent"], value = section.spent or 0, unit = "copper", fmt = FormatMoney, total = true },
		{ key = "current", label = L["On hand"], value = section.current or 0, unit = "copper", fmt = FormatMoney, total = true },
	}
end

ns.RegisterModule("gold", module)
