local _, ns = ...

-- The English text is the key, so a missing translation falls back to English
ns.L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
