local _, ns = ...

if GetLocale() ~= "deDE" then
	return
end

local L = ns.L

-- Core
L["invalid"] = "ungültig"
L["%s.%s failed"] = "%s.%s fehlgeschlagen"
L["Account total"] = "Account gesamt"
L["Stored characters"] = "Gespeicherte Charaktere"
L["never"] = "nie"
L["%s – %s, last logout %s"] = "%s – %s, letzter Logout %s"
L["Usage: /tally remove <Name-Realm>"] = "Verwendung: /tally remove <Name-Realm>"
L["No stored character %s"] = "Kein gespeicherter Charakter %s"
L["The active character cannot be removed."] = "Der aktive Charakter kann nicht entfernt werden."
L["Remove all Tally data of %s?"] = "Alle Tally-Daten von %s entfernen?"
L["%s has been removed."] = "%s wurde entfernt."
L["Unknown module %s. Available: %s"] = "Unbekanntes Modul %s. Verfügbar: %s"
L["addon version"] = "Addon-Version"
L["database schema"] = "Datenbank-Schema"
L["character key"] = "Charakter-Schlüssel"
L["stored characters"] = "gespeicherte Charaktere"
L["last logout"] = "letzter Logout"
L["Commands:"] = "Befehle:"
L["/tally – report for every module"] = "/tally – Bericht für jedes Modul"
L["Reset %s for every stored character?"] = "%s für jeden gespeicherten Charakter zurücksetzen?"
L["%s: all characters have been reset."] = "%s: Alle Charaktere wurden zurückgesetzt."
L["%s: counter for %s has been reset."] = "%s: Zähler für %s wurde zurückgesetzt."
L["Usage: /tally %s reset [all]"] = "Verwendung: /tally %s reset [all]"
L["/tally help – list all commands"] = "/tally help – alle Befehle auflisten"
L["/tally all – every character, per module"] = "/tally all – jeder Charakter, pro Modul"
L["/tally chars – list stored characters"] = "/tally chars – gespeicherte Charaktere auflisten"
L["/tally remove <Name-Realm> – delete a stored character"] = "/tally remove <Name-Realm> – gespeicherten Charakter löschen"
L["/tally debug [module] – show stored state"] = "/tally debug [Modul] – gespeicherten Zustand anzeigen"
L["ID check"] = "ID-Prüfung"
L["Hearthstone spells"] = "Ruhestein-Zauber"
L["Teleport spells"] = "Teleportzauber"
L["Hearthstone items"] = "Ruhestein-Gegenstände"
L["not loaded"] = "nicht geladen"
L["Statistics"] = "Statistiken"
L["not a statistic"] = "keine Statistik"
L["Some items are not loaded yet – run /tally ids again in a moment."] = "Einige Gegenstände sind noch nicht geladen – /tally ids gleich noch einmal ausführen."
L["Statistics matching \"%s\""] = "Statistiken mit \"%s\""
L["/tally ids [text] – check the configured IDs or search the game statistics"] = "/tally ids [Text] – konfigurierte IDs prüfen oder die Spielstatistiken durchsuchen"
L["Lifetime values imported from the game statistics: %s"] = "Gesamtwerte aus den Spielstatistiken übernommen: %s"

-- Distance facts are inserted as "die Strecke <fact>", so they are in the genitive
L["a marathon"] = "eines Marathons"
L["the Camino de Santiago"] = "des Jakobswegs"
L["Route 66"] = "der Route 66"
L["the Great Wall of China"] = "der Chinesischen Mauer"
L["the Earth's circumference"] = "des Erdumfangs"

-- Milestones
L["Milestone"] = "Meilenstein"
L["Milestone announcements are on."] = "Meilenstein-Meldungen sind an."
L["Milestone announcements are off."] = "Meilenstein-Meldungen sind aus."
L["/tally milestones [on|off] – announce reached milestones"] = "/tally milestones [on|off] – erreichte Meilensteine melden"

-- Window and export
L["Overview"] = "Übersicht"
L["Statistic"] = "Statistik"
L["Ranking"] = "Rangliste"
L["Rank"] = "Rang"
L["Character"] = "Charakter"
L["Character filter"] = "Charakterfilter"
L["The character filter could not be created – %s"] = "Der Charakterfilter konnte nicht erstellt werden – %s"
L["All"] = "Alle"
L["Only current"] = "Nur aktueller"
L["The active character is always included."] = "Der aktive Charakter ist immer enthalten."
L["Include this character in totals, reports and exports."] = "Diesen Charakter in Summen, Berichten und Exporten berücksichtigen."
L["Remove character"] = "Charakter entfernen"
L["Export"] = "Export"
L["Options"] = "Einstellungen"
L["Click to sort this column."] = "Klicken, um nach dieser Spalte zu sortieren."
L["Click to rank characters by level."] = "Klicken, um die Charaktere nach Level zu ordnen."
L["The window could not be created – %s"] = "Das Fenster konnte nicht erstellt werden – %s"
L["/tally window [module] – table of every character"] = "/tally window [Modul] – Tabelle aller Charaktere"
L["Tally export"] = "Tally-Export"
L["Usage: /tally export [csv|json]"] = "Verwendung: /tally export [csv|json]"
L["The export window could not be created – %s"] = "Das Exportfenster konnte nicht erstellt werden – %s"
L["/tally export [csv|json] – copyable export of all values"] = "/tally export [csv|json] – kopierbarer Export aller Werte"

-- Options
L["The options panel is not available in this client."] = "Das Optionsfenster ist in diesem Client nicht verfügbar."
L["The options cannot be opened in combat."] = "Die Optionen können im Kampf nicht geöffnet werden."
L["Announce milestones"] = "Meilensteine melden"
L["Print a chat message when a counter reaches a milestone."] = "Eine Chatnachricht ausgeben, wenn ein Zähler einen Meilenstein erreicht."
L["Hide empty columns"] = "Leere Spalten ausblenden"
L["Hide table columns that contain no recorded values."] = "Tabellenspalten ausblenden, die keine erfassten Werte enthalten."
L["Reset window position"] = "Fensterposition zurücksetzen"
L["Move the Tally window back to the center of the screen."] = "Das Tally-Fenster wieder in die Bildschirmmitte verschieben."
L["The window position has been reset."] = "Die Fensterposition wurde zurückgesetzt."
L["/tally options – open the options panel"] = "/tally options – Optionsfenster öffnen"
L["Left-click: toggle the window"] = "Linksklick: Fenster ein-/ausblenden"
L["Right-click: open the options"] = "Rechtsklick: Optionen öffnen"

-- Steps
L["Steps"] = "Schritte"
L["On foot"] = "Zu Fuß"
L["Mounted"] = "Reittier"
L["Swimming"] = "Schwimmend"
L["Flying"] = "Fliegend"
L["Flight path"] = "Flugroute"
L["Total"] = "Gesamt"
L["Total distance"] = "Gesamtstrecke"
L["steps / km"] = "Schritte / km"
L["Not measurable (restricted)"] = "Nicht messbar (eingeschränkt)"
L["steps (%.2f km)"] = "Schritte (%.2f km)"
L["step length %.2f m"] = "Schrittlänge %.2f m"
L["%s km travelled"] = "%s km zurückgelegt"
L["Fun fact: the account has covered %.1f× %s."] = "Fun Fact: Der Account hat %.1f× die Strecke %s zurückgelegt."
L["Fun fact: the account has covered %d%% of %s."] = "Fun Fact: Der Account hat %d %% der Strecke %s zurückgelegt."

-- Deaths
L["Deaths"] = "Tode"
L["Deaths: %s"] = "Tode: %s"
L["currently dead"] = "gerade tot"

-- Gold
L["Gold"] = "Gold"
L["Earned"] = "Verdient"
L["Spent"] = "Ausgegeben"
L["On hand"] = "Vorhanden"
L["%s earned"] = "%s verdient"

-- Quests
L["Quests"] = "Quests"
L["Turned in"] = "Abgegeben"
L["Quest XP"] = "Quest-EP"
L["%s quests turned in"] = "%s Quests abgegeben"

-- Jumps
L["Jumps"] = "Sprünge"
L["%s jumps"] = "%s Sprünge"

-- Teleports
L["Teleports"] = "Teleports"
L["Hearthstone"] = "Ruhestein"
L["recent unlisted spells"] = "zuletzt nicht gelistete Zauber"
L["%s teleports and hearthstone uses"] = "%s Teleports und Ruhestein-Nutzungen"

-- Professions
L["Professions"] = "Berufe"
L["Fish caught"] = "Fische gefangen"
L["%s fish caught"] = "%s Fische gefangen"
L["Herbs"] = "Kräuter"
L["Ore and stone"] = "Erz und Stein"
L["Leather"] = "Leder"
L["Items crafted"] = "Hergestellt"
L["Skill-ups"] = "Fertigkeitspunkte"
L["%s herbs gathered"] = "%s Kräuter gesammelt"
L["%s ore and stone gathered"] = "%s Erz und Stein abgebaut"
L["%s leather gathered"] = "%s Leder gesammelt"
L["%s items crafted"] = "%s Gegenstände hergestellt"
L["skill levels"] = "Berufsstufen"

-- Playtime
L["Playtime"] = "Spielzeit"
L["%s played"] = "%s gespielt"
L["%d days"] = "%d Tage"
