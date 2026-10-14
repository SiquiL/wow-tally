local _, ns = ...
local L = ns.L

ns.YARD_TO_METER = 0.9144
ns.DEFAULT_STEP_LENGTH = 0.75

local FEMALE_FACTOR = 0.96

-- Meters per step; keys are the locale-independent raceFile from UnitRace("player")
ns.STEP_LENGTH = {
	Tauren = 0.95,
	HighmountainTauren = 0.95,
	KulTiran = 0.95,

	Draenei = 0.90,
	LightforgedDraenei = 0.90,
	ZandalariTroll = 0.90,
	Worgen = 0.90,
	Dracthyr = 0.90,

	NightElf = 0.85,
	Nightborne = 0.85,
	VoidElf = 0.85,
	Orc = 0.85,
	MagharOrc = 0.85,
	Troll = 0.85,
	Harronir = 0.85,

	Human = 0.78,
	ThinHuman = 0.78,
	BloodElf = 0.78,
	Scourge = 0.78,
	Pandaren = 0.78,

	Dwarf = 0.68,
	DarkIronDwarf = 0.68,
	EarthenDwarf = 0.68,

	Gnome = 0.55,
	Mechagnome = 0.55,
	Goblin = 0.55,
	Vulpera = 0.55,
}

function ns.GetStepLength(raceFile, sex)
	local length = ns.STEP_LENGTH[raceFile or ""] or ns.DEFAULT_STEP_LENGTH

	-- UnitSex: 1 = unknown, 2 = male, 3 = female
	if sex == 3 then
		length = length * FEMALE_FACTOR
	end

	return length
end

-- Spell IDs that UNIT_SPELLCAST_SUCCEEDED reports for the player, with the English name that
-- /tally ids prints next to the client's own. `/tally debug teleports` lists recent unlisted spells.
ns.HEARTHSTONE_SPELLS = {
	[8690] = "Hearthstone",
}

-- Toys and items that work like a hearthstone; their spell IDs are looked up in game
ns.HEARTHSTONE_ITEMS = {
	[6948] = "Hearthstone",
	[28585] = "Ruby Slippers",
	[54452] = "Ethereal Portal",
	[64488] = "The Innkeeper's Daughter",
	[93672] = "Dark Portal",
	[110560] = "Garrison Hearthstone",
	[140192] = "Dalaran Hearthstone",
	[142298] = "Astonishingly Scarlet Slippers",
	[142542] = "Tome of Town Portal",
	[162973] = "Greatfather Winter's Hearthstone",
	[163045] = "Headless Horseman's Hearthstone",
	[165669] = "Lunar Elder's Hearthstone",
	[165670] = "Peddlefeet's Lovely Hearthstone",
	[165802] = "Noble Gardener's Hearthstone",
	[166746] = "Fire Eater's Hearthstone",
	[166747] = "Brewfest Reveler's Hearthstone",
	[168907] = "Holographic Digitalization Hearthstone",
	[172179] = "Eternal Traveler's Hearthstone",
	[180290] = "Night Fae Hearthstone",
	[182773] = "Necrolord Hearthstone",
	[183716] = "Venthyr Sinstone",
	[184353] = "Kyrian Hearthstone",
	[188952] = "Dominated Hearthstone",
	[190196] = "Enlightened Hearthstone",
	[190237] = "Broker Translocation Matrix",
	[193588] = "Timewalker's Hearthstone",
	[200630] = "Ohn'ir Windsage's Hearthstone",
	[206195] = "Path of the Naaru",
	[208704] = "Deepdweller's Earthen Hearthstone",
	[209035] = "Hearthstone of the Flame",
	[210455] = "Draenic Hologem",
	[228940] = "Notorious Thread's Hearthstone",
	[235016] = "Redeployment Module",
	[236687] = "Explosive Hearthstone",
	[245970] = "P.O.S.T. Master's Express Hearthstone",
	[246565] = "Cosmic Hearthstone",
	[263489] = "Naaru's Enfold",
	[263933] = "Preyseeker's Hearthstone",
	[265100] = "Corewarden's Hearthstone",
}

ns.TELEPORT_SPELLS = {
	-- Mage
	[3561] = "Teleport: Stormwind",
	[3562] = "Teleport: Ironforge",
	[3563] = "Teleport: Undercity",
	[3565] = "Teleport: Darnassus",
	[3566] = "Teleport: Thunder Bluff",
	[3567] = "Teleport: Orgrimmar",
	[32271] = "Teleport: Exodar",
	[32272] = "Teleport: Silvermoon",
	[33690] = "Teleport: Shattrath (Alliance)",
	[35715] = "Teleport: Shattrath (Horde)",
	[49358] = "Teleport: Stonard",
	[49359] = "Teleport: Theramore",
	[53140] = "Teleport: Dalaran - Northrend",
	[88342] = "Teleport: Tol Barad (Alliance)",
	[88344] = "Teleport: Tol Barad (Horde)",
	[120145] = "Ancient Teleport: Dalaran",
	[132621] = "Teleport: Vale of Eternal Blossoms (Alliance)",
	[132627] = "Teleport: Vale of Eternal Blossoms (Horde)",
	[176242] = "Teleport: Warspear",
	[176248] = "Teleport: Stormshield",
	[193759] = "Teleport: Hall of the Guardian",
	[224869] = "Teleport: Dalaran - Broken Isles",
	[281403] = "Teleport: Boralus",
	[281404] = "Teleport: Dazar'alor",
	[344587] = "Teleport: Oribos",
	[395277] = "Teleport: Valdrakken",
	[446540] = "Teleport: Dornogal",
	[1259190] = "Teleport: Silvermoon City",

	-- Other classes
	[556] = "Astral Recall",
	[18960] = "Teleport: Moonglade",
	[50977] = "Death Gate",
	[126892] = "Zen Pilgrimage",
	[193753] = "Dreamwalk",
}

-- Achievement IDs of game statistics that raise a counter once; check them with /tally ids
ns.STATISTICS = {
	deaths = { id = 60, name = "Total deaths" },
	quests = { id = 98, name = "Quests completed" },
	fish = { id = 1456, name = "Fish and other things caught" },
	hearth = { id = 353, name = "Number of times hearthed" },
}

-- Real-world reference distances for the Steps fun fact, ascending
ns.DISTANCE_FACTS = {
	{ km = 42.195, text = L["a marathon"] },
	{ km = 780, text = L["the Camino de Santiago"] },
	{ km = 3940, text = L["Route 66"] },
	{ km = 21196, text = L["the Great Wall of China"] },
	{ km = 40075, text = L["the Earth's circumference"] },
}
