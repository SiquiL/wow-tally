# API reference

Tally only uses the in-game Lua API of World of Warcraft. The Battle.net Web APIs (Game Data
and Profile APIs) are REST services that need OAuth and HTTP – addons cannot call them. They
are only useful to cross-check data such as spell IDs outside the game.

Sources, checked on 2026-10-15 against Midnight 12.1.0 (live), 12.1.5 (PTR) and
World of Warcraft: Forever 1.60.1 (beta):

- [warcraft.wiki.gg – World of Warcraft API](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)
- Blizzard's generated API documentation, mirrored in
  [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source) (`Blizzard_APIDocumentationGenerated`),
  in game via `/api`
- [wago.tools](https://wago.tools/db2) for client database tables such as `Achievement`

## Clients and TOC

| Client                     | Interface | TOC                                                         |
| -------------------------- | --------- | ----------------------------------------------------------- |
| Midnight 12.1.0 (live)     | 120100    | `Tally.toc` (`_Standard` is only recognized from 12.1.5)    |
| Midnight 12.1.5 (PTR)      | 120105    | `Tally.toc`                                                 |
| World of Warcraft: Forever | 16001     | `Tally.toc` (`_Camelot`, alias `_Forever`, would also work) |

- `## Interface` accepts comma-separated values; the wiki recommends that over per-client TOC files.
- The family suffix `_Mainline` covers standard, forever, camelot, plunderstorm and wowhack.
- Forever 1.60.1 includes all modern API changes up to 12.1.5, so it shares the mainline API.
- Addon compartment directives (`AddonCompartmentFunc`, `...OnEnter`, `...OnLeave`, `IconTexture`)
  are mainline only. Click handlers receive `(addonName, buttonName)`, enter/leave handlers
  `(addonName, menuButtonFrame)`.
- Current numbers: `/dump select(4, GetBuildInfo())` or [TOC format](https://warcraft.wiki.gg/wiki/TOC_format).

## Functions

"Secret" lists the secret predicate from Blizzard's documentation. A predicate only applies
while the matching addon restriction is active.

| API                                                                                                                                                                                                                                                              | Returns / notes                                                                                                                                                                    | Secret                                              | Used in                 |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- | ----------------------- |
| [GetUnitSpeed](https://warcraft.wiki.gg/wiki/API_GetUnitSpeed)(unit)                                                                                                                                                                                             | currentSpeed, runSpeed, flightSpeed, swimSpeed in yards/s                                                                                                                          | SecretWhenUnitStatsRestricted                       | Steps                   |
| [C_PlayerInfo.GetGlidingInfo](https://warcraft.wiki.gg/wiki/API_C_PlayerInfo.GetGlidingInfo)()                                                                                                                                                                   | isGliding, canGlide, forwardSpeed (yards/s); the only source for skyriding speed                                                                                                   | –                                                   | Steps                   |
| [UnitOnTaxi](https://warcraft.wiki.gg/wiki/API_UnitOnTaxi)(unit), [IsSwimming](https://warcraft.wiki.gg/wiki/API_IsSwimming)([unit]), [IsFlying](https://warcraft.wiki.gg/wiki/API_IsFlying)([unit]), [IsMounted](https://warcraft.wiki.gg/wiki/API_IsMounted)() | boolean                                                                                                                                                                            | –                                                   | Steps, Jumps            |
| [C_Map.GetBestMapForUnit](https://warcraft.wiki.gg/wiki/API_C_Map.GetBestMapForUnit)(unit)                                                                                                                                                                       | best matching uiMapID, or nil during loading screens                                                                                                                               | –                                                   | Zones                   |
| [C_Map.GetMapInfo](https://warcraft.wiki.gg/wiki/API_C_Map.GetMapInfo)(uiMapID)                                                                                                                                                                                  | map information table including the localized name, or nil                                                                                                                         | –                                                   | Zones                   |
| [IsInInstance](https://warcraft.wiki.gg/wiki/API_IsInInstance)()                                                                                                                                                                                                 | isInInstance, instanceType (`party`, `raid`, `pvp`, `arena`, `scenario` or `none`)                                                                                                 | –                                                   | Zones                   |
| [UnitRace](https://warcraft.wiki.gg/wiki/API_UnitRace)(unit)                                                                                                                                                                                                     | localizedName, raceFile, raceID                                                                                                                                                    | SecretWhenUnitIdentityRestricted (not for `player`) | Core                    |
| [UnitSex](https://warcraft.wiki.gg/wiki/API_UnitSex)(unit)                                                                                                                                                                                                       | 1 unknown, 2 male, 3 female                                                                                                                                                        | SecretWhenUnitIdentityRestricted                    | Core, Data              |
| UnitClass(unit), UnitLevel(unit), UnitName(unit)                                                                                                                                                                                                                 | the class file is the 2nd return of UnitClass                                                                                                                                      | conditional, not for `player`                       | Core                    |
| [GetNormalizedRealmName](https://warcraft.wiki.gg/wiki/API_GetNormalizedRealmName)()                                                                                                                                                                             | realm without spaces, hyphens and periods; nil before PLAYER_LOGIN and during loading screens                                                                                      | –                                                   | Core                    |
| [GetMoney](https://warcraft.wiki.gg/wiki/API_GetMoney)()                                                                                                                                                                                                         | copper; reliable from PLAYER_ENTERING_WORLD on                                                                                                                                     | –                                                   | Gold                    |
| [C_Bank.FetchDepositedMoney](https://warcraft.wiki.gg/wiki/API_C_Bank.FetchDepositedMoney)(Enum.BankType.Account)                                                                                                                                                | warband bank balance in copper (`Enum.BankType`: 0 Character, 1 Guild, 2 Account)                                                                                                  | –                                                   | Gold                    |
| GetCoinTextureString(copper[, fontHeight])                                                                                                                                                                                                                       | money with coin icons (FrameXML)                                                                                                                                                   | –                                                   | Gold                    |
| [UnitIsDeadOrGhost](https://warcraft.wiki.gg/wiki/API_UnitIsDeadOrGhost)(unit)                                                                                                                                                                                   | false during Spirit of Redemption                                                                                                                                                  | –                                                   | Deaths                  |
| [IsFishingLoot](https://warcraft.wiki.gg/wiki/API_IsFishingLoot)()                                                                                                                                                                                               | true if the loot window comes from fishing                                                                                                                                         | –                                                   | Professions             |
| [GetNumLootItems](https://warcraft.wiki.gg/wiki/API_GetNumLootItems)(), [GetLootSlotInfo](https://warcraft.wiki.gg/wiki/API_GetLootSlotInfo)(slot), [GetLootSlotLink](https://warcraft.wiki.gg/wiki/API_GetLootSlotLink)(slot)                                   | number of slots; the quantity is the 3rd return of GetLootSlotInfo, money has no link                                                                                              | –                                                   | Professions             |
| [C_Item.GetItemInfoInstant](https://warcraft.wiki.gg/wiki/API_C_Item.GetItemInfoInstant)(item)                                                                                                                                                                   | itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID; no item cache needed                                                                                       | –                                                   | Professions             |
| [GetProfessions](https://warcraft.wiki.gg/wiki/API_GetProfessions)(), [GetProfessionInfo](https://warcraft.wiki.gg/wiki/API_GetProfessionInfo)(index)                                                                                                            | indices of prof1, prof2, archaeology, fishing, cooking; rank is the 3rd and skillLine the 7th return                                                                               | –                                                   | Professions             |
| [JumpOrAscendStart](https://warcraft.wiki.gg/wiki/API_JumpOrAscendStart)()                                                                                                                                                                                       | protected, called on jump key down; only hooked with `hooksecurefunc`                                                                                                              | –                                                   | Jumps                   |
| [C_Item.GetItemSpell](https://warcraft.wiki.gg/wiki/API_C_Item.GetItemSpell)(item)                                                                                                                                                                               | spellName, spellID; nothing until the item is cached                                                                                                                               | –                                                   | Teleports, `/tally ids` |
| [C_Item.RequestLoadItemDataByID](https://warcraft.wiki.gg/wiki/API_C_Item.RequestLoadItemDataByID)(item)                                                                                                                                                         | fires ITEM_DATA_LOAD_RESULT                                                                                                                                                        | –                                                   | Teleports, `/tally ids` |
| [C_Spell.GetSpellName](https://warcraft.wiki.gg/wiki/API_C_Spell.GetSpellName)(spell)                                                                                                                                                                            | name or nil                                                                                                                                                                        | –                                                   | Teleports, `/tally ids` |
| [GetStatistic](https://warcraft.wiki.gg/wiki/API_GetStatistic)(id[, index])                                                                                                                                                                                      | display **text** (e.g. "1,234" or "--"), skip, id                                                                                                                                  | –                                                   | Core (lifetime values)  |
| [GetAchievementInfo](https://warcraft.wiki.gg/wiki/API_GetAchievementInfo)(id) or (category, index)                                                                                                                                                              | id, name, ..., isStatistic (15th return)                                                                                                                                           | –                                                   | `/tally ids`            |
| GetStatisticsCategoryList(), GetCategoryNumAchievements(category)                                                                                                                                                                                                | statistic categories and their size                                                                                                                                                | –                                                   | `/tally ids <text>`     |
| [issecretvalue](https://warcraft.wiki.gg/wiki/API_issecretvalue)(value)                                                                                                                                                                                          | true for secret values (12.0.0+, missing before)                                                                                                                                   | –                                                   | Core                    |
| C_AddOns.GetAddOnMetadata(addon, field)                                                                                                                                                                                                                          | TOC metadata, e.g. Version                                                                                                                                                         | –                                                   | `/tally debug`          |
| [StaticPopup_Show](https://warcraft.wiki.gg/wiki/API_StaticPopup_Show)(which, text1, text2, data)                                                                                                                                                                | `OnAccept(self, data, data2)` receives `data`                                                                                                                                      | –                                                   | Core                    |
| [Settings API](https://warcraft.wiki.gg/wiki/Settings_API)                                                                                                                                                                                                       | RegisterVerticalLayoutCategory, RegisterAddOnSetting, CreateCheckbox, CreateSettingsButtonInitializer, RegisterAddOnCategory, OpenToCategory                                      | –                                                   | Settings                |
| MenuUtil.ShowTooltip(owner, fn), MenuUtil.HideTooltip(owner)                                                                                                                                                                                                     | compartment tooltip                                                                                                                                                                | –                                                   | Settings                |
| [RequestTimePlayed](https://warcraft.wiki.gg/wiki/API_RequestTimePlayed)()                                                                                                                                                                                       | nothing; the answer arrives as TIME_PLAYED_MSG, which every chat frame prints like `/played`                                                                                       | –                                                   | Played                  |
| [GetTime](https://warcraft.wiki.gg/wiki/API_GetTime)()                                                                                                                                                                                                           | system uptime in seconds with milliseconds, updated once per frame                                                                                                                 | –                                                   | Played, Zones           |
| CHAT_FRAMES, frame:IsEventRegistered(event), frame:UnregisterEvent(event), frame:RegisterEvent(event)                                                                                                                                                            | names of all chat frames; they print TIME_PLAYED_MSG through their SYSTEM message group (`ChatFrameUtil.DisplayTimePlayed`)                                                        | –                                                   | Played                  |
| C_Timer.After, C_Timer.NewTicker, CreateFrame, hooksecurefunc, InCombatLockdown, GetLocale, BreakUpLargeNumbers, RAID_CLASS_COLORS[class].colorStr, UISpecialFrames                                                                                              | –                                                                                                                                                                                  | –                                                   | several                 |
| PlayerModel:SetUnit(unit), PlayerModel:SetPortraitZoom(zoom), CLASS_ICON_TCOORDS                                                                                                                                                                            | Displays the current player model and selects the class icon texture coordinates                                                                                                   | –                                                   | UI                      |

Templates: `BasicFrameTemplateWithInset`, `UIPanelButtonTemplate`, `UICheckButtonTemplate`,
`FauxScrollFrameTemplate`, `InputScrollFrameTemplate`
(its `maxLetters` defaults to 0, i.e. unlimited, so the export is not truncated).

`Enum.ItemClass.Tradegoods` (7) has no enum for its subclasses; the IDs 6 Leather, 7 Metal & Stone
and 9 Herb come from [ItemType](https://warcraft.wiki.gg/wiki/ItemType).

## Events

| Event                           | Payload                                  | Notes                                                                       | Used in     |
| ------------------------------- | ---------------------------------------- | --------------------------------------------------------------------------- | ----------- |
| ADDON_LOADED                    | addonName                                |                                                                             | Core        |
| PLAYER_LOGIN, PLAYER_LOGOUT     | –                                        |                                                                             | Core        |
| ZONE_CHANGED                    | –                                        | subzone changed                                                             | Zones       |
| ZONE_CHANGED_INDOORS            | –                                        | indoor subzone changed                                                      | Zones       |
| ZONE_CHANGED_NEW_AREA           | –                                        | major zone or instance changed                                              | Zones       |
| PLAYER_ENTERING_WORLD           | isInitialLogin, isReloadingUi            | baseline for GetMoney                                                       | Gold        |
| PLAYER_DEAD                     | –                                        |                                                                             | Deaths      |
| PLAYER_ALIVE                    | –                                        | release to a graveyard, or a resurrection accepted before releasing         | Deaths      |
| PLAYER_UNGHOST                  | –                                        | alive after being a ghost, also when zoning into an instance as a ghost     | Deaths      |
| PLAYER_MONEY                    | –                                        |                                                                             | Gold        |
| ACCOUNT_MONEY                   | –                                        | warband bank balance changed                                                | Gold        |
| QUEST_TURNED_IN                 | questID, xpReward, moneyReward           | also world quests and bonus objectives; xpReward is 0 at max level          | Quests      |
| UNIT_SPELLCAST_SUCCEEDED        | unitTarget, castGUID, spellID, castBarID | castBarID since 12.0.0; secret only for units other than the player and pet | Teleports   |
| ITEM_DATA_LOAD_RESULT           | itemID, success                          |                                                                             | Teleports   |
| LOOT_READY                      | autoloot                                 | before LOOT_OPENED; fast-loot addons already empty slots here               | Professions |
| LOOT_OPENED                     | autoLoot, isFromItem                     | after LOOT_READY                                                            | Professions |
| LOOT_SLOT_CLEARED               | lootSlot                                 | the slot was looted                                                         | Professions |
| LOOT_CLOSED                     | –                                        |                                                                             | Professions |
| SKILL_LINES_CHANGED             | –                                        | also during login; the levels come from GetProfessionInfo                   | Professions |
| TRADE_SKILL_ITEM_CRAFTED_RESULT | resultData                               | CraftingItemResultData: itemID, quantity, multicraft, isCrit, ...           | Professions |
| TIME_PLAYED_MSG                 | totalTimePlayed, timePlayedThisLevel     | seconds, the answer to RequestTimePlayed                                    | Played      |

## Secret values (12.0.0+)

While combat, encounter, Mythic+, PvP match or map restrictions are active, flagged APIs may
return secret values. For addon code these operations raise an immediate Lua error:
arithmetic, comparison, boolean tests on secret booleans, the length operator, using a secret
as a table key and indexing a secret. Storing, passing on, concatenating and `type()` are
allowed. See [Secret Values](https://warcraft.wiki.gg/wiki/Secret_Values).

Restrictions can be simulated with these console variables (`/console <name> 1`, reset with
`0`, not saved across restarts): `addonCombatRestrictionsForced`,
`addonEncounterRestrictionsForced`, `addonChallengeModeRestrictionsForced`,
`addonPvPMatchRestrictionsForced`, `addonMapRestrictionsForced`, `addonChatRestrictionsForced`.

## Data in Data.lua

| Data                 | Source                                                                                                                                                        | Check in game                     |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| Race file names      | Blizzard's `RacialCooldowns` table in `Blizzard_CooldownBroadcaster/TrackedCooldowns.lua`, indexed by `select(2, UnitRace("player"))`; Haranir is `Harronir`  | `/dump UnitRace("player")`        |
| Teleport spell IDs   | "External links" of each spell page on warcraft.wiki.gg                                                                                                       | `/tally ids`                      |
| Hearthstone item IDs | "External links" of each item page on warcraft.wiki.gg; the spells of toys are looked up in game                                                              | `/tally ids`                      |
| Statistic IDs        | `Achievement` table on wago.tools (build 12.1.5.70077): 60 Total deaths, 98 Quests completed, 1456 Fish and other things caught, 353 Number of times hearthed | `/tally ids`, `/tally ids <text>` |

Playable race files: Human, Orc, Dwarf, NightElf, Scourge, Tauren, Gnome, Troll, Goblin,
BloodElf, Draenei, Worgen, Pandaren, Dracthyr, Nightborne, HighmountainTauren, VoidElf,
LightforgedDraenei, ZandalariTroll, KulTiran, DarkIronDwarf, Vulpera, MagharOrc, Mechagnome,
EarthenDwarf, Harronir. `ThinHuman` also exists but is not a character race.

Useful commands in game:

- `/tally ids` – every configured spell, item and statistic ID with the name the client reports
- `/tally ids <text>` – statistics whose name contains the text, with ID and value
- `/tally debug teleports` – the last spells that matched neither list
- `/dump C_Spell.GetSpellName(3561)`, `/dump C_Item.GetItemSpell(6948)`

## Battle.net Web APIs (offline only)

The documentation at
[community.developer.battle.net](https://community.developer.battle.net/documentation/world-of-warcraft/game-data-apis)
is a JavaScript application; the endpoints below should be confirmed there before use.

- Host `https://{us|eu|kr|tw}.api.blizzard.com`, OAuth client credentials via
  `POST https://oauth.battle.net/token`, then `Authorization: Bearer <token>`.
- Namespace as `Battlenet-Namespace` header or `?namespace=`: `static-eu`, `dynamic-eu`,
  `profile-eu` (Classic: `static-classic-eu`, `static-classic1x-eu`), plus `locale=de_DE`.

| Purpose                            | Endpoint                                                                             |
| ---------------------------------- | ------------------------------------------------------------------------------------ |
| Spell names for IDs                | `/data/wow/spell/{spellId}`, `/data/wow/search/spell`                                |
| Playable races                     | `/data/wow/playable-race/index`, `/data/wow/playable-race/{id}` (no race file names) |
| Playable classes                   | `/data/wow/playable-class/index`, `/data/wow/playable-class/{id}`                    |
| Professions                        | `/data/wow/profession/index`, `/data/wow/profession/{id}`                            |
| Toys and their items               | `/data/wow/toy/index`, `/data/wow/toy/{id}`, `/data/wow/item/{itemId}`               |
| Character statistics (Profile API) | `/profile/wow/character/{realmSlug}/{name}/achievements/statistics`                  |
