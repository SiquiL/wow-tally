local _, ns = ...
local L = ns.L

local jumps

local module = {
	label = L["Jumps"],
	defaults = { count = 0 },
	milestones = {
		{ key = "count", thresholds = { 100, 1000, 10000, 50000, 100000, 500000 }, text = L["%s jumps"] },
	},
}

function module:OnLogin(section)
	jumps = section
end

function module:Summary(charData)
	return {
		{ key = "count", label = L["Jumps"], value = charData.jumps.count or 0, total = true },
	}
end

-- The same function also starts ascending, which is why swimming and flying are skipped
hooksecurefunc("JumpOrAscendStart", function()
	if jumps and not IsSwimming() and not IsFlying() then
		jumps.count = jumps.count + 1
	end
end)

ns.RegisterModule("jumps", module)
