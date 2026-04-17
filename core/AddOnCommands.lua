-- AddOnCommands.lua
-- Slash commands and CLI functions extracted from XPBarEnhanced.lua

local Addon = XPBarEnhanced
local L = Addon.L

local function printUnknown(command)
    print("|cFFFF0000Unknown command:|r " .. (command or ""))
    print("|cff33ff99XP Bar Enhanced|r - Use /xpbe help for commands")
end

local function showHelp()
    print("|cff33ff99XP Bar Enhanced|r Commands:")
    print("  /xpbe |cFFFFFFFFoptions|r - Open options panel")
    print("  /xpbe |cFFFFFFFFstats|r - Toggle statistics window")
    print("  /xpbe |cFFFFFFFFchangelog|r - Show the update changelog")
    print("  /xpbe |cFFFFFFFFstyle <none|classic|flat|vertical|circular|minimap_ring|terminal>|r - Change bar style")
    print("  /xpbe |cFFFFFFFFreps|r - Export all faction IDs")
    print("  /xpbe |cFFFFFFFFreset|r - Reset all settings")
    print("  /xpbe |cFFFFFFFFresetstats|r - Reset statistics")
    print("  /xpbe |cFFFFFFFFresetcolors|r - Reset colors to defaults")
    print("  /xpbe |cFFFFFFFFhelp|r - Show this help")
end

local function handleStats()
    local stats = Addon.Stats
    if stats and stats.Toggle then
        stats:Toggle()
    else
        print("|cFFFF0000XP Bar Enhanced:|r Stats feature not available")
    end
end

local function handleOptions()
    if Addon and Addon.Options and Addon.Options.Open then
		Addon.Options:Open()
	elseif Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(Addon.OptionsCategory)
	end
end

local function handleChangelog()
    if Addon and Addon.Changelog and Addon.Changelog.Show then
        Addon.Changelog:Show()
    else
        print("|cFFFF0000XP Bar Enhanced:|r Changelog viewer is unavailable")
    end
end

local function handleReset()
    if Addon.Config and Addon.Config.Reset then
        Addon.Config:Reset()
    else
        print("|cFFFF0000XP Bar Enhanced:|r Reset function not available")
    end
end

local function handleResetStats()
    if Addon.Config and Addon.Config.ResetStats then
        Addon.Config:ResetStats()
    else
        print("|cFFFF0000XP Bar Enhanced:|r Reset stats function not available")
    end
end

local function handleResetColors()
    if Addon.defaults and Addon.defaults.colors then
        Addon.db.colors = {}
        for colorKey, colorValue in pairs(Addon.defaults.colors) do
            Addon.db.colors[colorKey] = {
                r = colorValue.r,
                g = colorValue.g,
                b = colorValue.b,
                a = colorValue.a
            }
        end
        print("|cFF00FF00XP Bar Enhanced:|r Colors reset to defaults. Please /reload")
    else
        print("|cFFFF0000XP Bar Enhanced:|r Could not find default colors")
    end
end

local function handleStyle(style)
    style = string.lower(style or "")
    if style == "" then
        local currentStyle = Addon.db.barStyle or "classic"
        print("|cFF00FF00XP Bar Enhanced:|r Current bar style: " .. currentStyle)
        print("Usage: /xpbe style <none|classic|flat|vertical|circular|minimap_ring|terminal>")
        return
    end
    if style == "none" or style == "classic" or style == "flat" or style == "vertical" or style == "circular" or style == "minimap_ring" or style == "terminal" then
        if Addon.Config and Addon.Config.SetOptionKey then
            Addon.Config:SetOptionKey("barStyle", style)
            print("|cFF00FF00XP Bar Enhanced:|r Bar style set to: " .. style)
        else
            print("|cFFFF0000XP Bar Enhanced:|r Config module not available")
        end
    else
        print("|cFFFF0000XP Bar Enhanced:|r Invalid style. Use: none, classic, flat, vertical, circular, minimap_ring, terminal")
    end
end

local function handleReps()
    if Addon.ReputationSession and Addon.ReputationSession.ListAllFactions then
        Addon.ReputationSession:ListAllFactions()
    else
        print("|cFFFF0000XP Bar Enhanced:|r Reputation module not available")
    end
end

local function handleSlashCommand(message)
    local command, arg = string.match(message or "", "^(%S*)%s*(.-)$")
    command = string.lower(command or "")

    if command == "" or command == "help" then
        showHelp()
    elseif command == "stats" then
        handleStats()
    elseif command == "changelog" or command == "changes" or command == "news" then
        handleChangelog()
    elseif command == "options" or command == "config" or command == "settings" then
        handleOptions()
    elseif command == "reset" then
        handleReset()
    elseif command == "resetstats" or command == "clearstats" then
        handleResetStats()
    elseif command == "resetcolors" then
        handleResetColors()
    elseif command == "style" or command == "barstyle" or command == "mode" then
        handleStyle(arg)
    elseif command == "reps" then
        handleReps()
    else
        printUnknown(command)
    end
end

-- Register slash commands
SLASH_XPBARENHANCED1 = "/xpbe"
SLASH_XPBARENHANCED2 = "/xpbarenhanced"
SLASH_XPBARENHANCED3 = "/xpbar"
SlashCmdList["XPBARENHANCED"] = handleSlashCommand

return true
