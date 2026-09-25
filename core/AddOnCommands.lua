-- AddOnCommands.lua
-- Slash commands and CLI functions extracted from XPBarEnhanced.lua

local Addon = XPBarEnhanced
local L = Addon.L

local function printUnknown(command)
    print("|cFFFF0000" .. L["MSG_UNKNOWN_COMMAND"] .. "|r " .. (command or ""))
    print("|cff33ff99XP Bar Enhanced|r - Use /xpbe help for commands")
end

--- The selectable bar styles, in the order the options panel offers them.
---
--- Read from the barStyle option's own definition -- the same table the style
--- gallery builds its swatches from -- rather than spelled out again here. The
--- list used to be hand-written in three places (the help line, the usage line
--- and the validator) and they had already drifted apart: a style present in
--- the gallery was rejected by the command that claimed to accept it.
---@return string[]
local function StyleKeys()
    local detail = Addon.Config and Addon.Config.GetOptionDetail
        and Addon.Config:GetOptionDetail("barStyle")
    local keys = {}
    for _, option in ipairs(detail and detail.options or {}) do
        keys[#keys + 1] = option.value
    end
    return keys
end

---@param separator string
---@return string styles Joined list, or a usable placeholder if metadata is absent
local function StyleList(separator)
    local keys = StyleKeys()
    if #keys == 0 then
        return "style"
    end
    return table.concat(keys, separator)
end

--- Accept exactly what the bar can actually put on screen.
---
--- Deferring to BarManager rather than to the list above means the command can
--- never accept a style that would then fail to render, nor reject one that
--- would have worked: ResolveStyleKey returns its argument unchanged precisely
--- when the style has both a template and a registered mixin.
---@param style string
---@return boolean
local function IsValidStyle(style)
    local manager = Addon.BarManager
    if not (manager and manager.ResolveStyleKey) then
        return false
    end
    return manager:ResolveStyleKey(style) == style
end

local function showHelp()
    print("|cff33ff99XP Bar Enhanced|r Commands:")
    print("  /xpbe |cFFFFFFFFoptions|r - Open options panel")
    print("  /xpbe |cFFFFFFFFstats|r - Toggle statistics window")
    print("  /xpbe |cFFFFFFFFchangelog|r - Show the update changelog")
    print("  /xpbe |cFFFFFFFFstyle <" .. StyleList("|") .. ">|r - Change bar style")
    print("  /xpbe |cFFFFFFFFprofile|r - Show current profile and available profiles")
    print("  /xpbe |cFFFFFFFFprofile global|r - Use global shared settings")
    print("  /xpbe |cFFFFFFFFprofile use <name>|r - Switch to a named profile")
    print("  /xpbe |cFFFFFFFFprofile new <name>|r - Create and select a new profile")
    print("  /xpbe |cFFFFFFFFprofile rename <new name>|r - Rename the active profile")
    print("  /xpbe |cFFFFFFFFprofile delete [name]|r - Delete a profile")
    print("  /xpbe |cFFFFFFFFreset|r - Reset the active profile to its defaults")
    print("  /xpbe |cFFFFFFFFresetstats|r - Reset statistics")
    print("  /xpbe |cFFFFFFFFresetcolors|r - Reset colors to defaults")
    print("  /xpbe |cFFFFFFFFhelp|r - Show this help")
end

local function handleStats()
    local stats = Addon.Stats
    if stats and stats.Toggle then
        stats:Toggle()
    else
        print("|cFFFF0000XP Bar Enhanced:|r " .. L["MSG_STATS_UNAVAILABLE"])
    end
end

local function handleOptions()
    if Addon and Addon.Options and Addon.Options.Open then
        Addon.Options:Open()
        return
    end
    local category = (Addon and Addon.Options and Addon.Options.category) or Addon.OptionsCategory
    local id = category and ((category.GetID and category:GetID()) or category.ID or category)
    if id and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(id)
    else
        print("|cFFFF0000XP Bar Enhanced:|r " .. L["MSG_OPTIONS_UNAVAILABLE"])
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
    local config = Addon.Config
    if not (config and config.ResetActiveProfile) then
        print("|cFFFF0000XP Bar Enhanced:|r " .. L["MSG_RESET_UNAVAILABLE"])
        return
    end
    local profileName = config:GetActiveProfileName() or L["OPT_PROFILE_GLOBAL"]
    config:ResetActiveProfile()
    print("|cFF00FF00XP Bar Enhanced:|r " .. string.format(L["MSG_SETTINGS_RESET"], profileName))
end

local function handleResetStats()
    if Addon.Config and Addon.Config.ResetStats then
        Addon.Config:ResetStats()
    else
        print("|cFFFF0000XP Bar Enhanced:|r " .. L["MSG_RESET_STATS_UNAVAILABLE"])
    end
end

local function handleResetColors()
    if Addon.Colors and Addon.Colors.ResetAll then
        Addon.Colors:ResetAll()
        print("|cFF00FF00XP Bar Enhanced:|r Colors reset to defaults")
    else
        print("|cFFFF0000XP Bar Enhanced:|r Could not find default colors")
    end
end

local function handleStyle(style)
    style = string.lower(style or "")
    if style == "" then
        local currentStyle = "classic"
        if Addon.Config and Addon.Config.GetOptionValue then
            currentStyle = Addon.Config:GetOptionValue("barStyle") or "classic"
        elseif Addon.db then
            currentStyle = Addon.db.barStyle or "classic"
        end
        print("|cFF00FF00XP Bar Enhanced:|r Current bar style: " .. currentStyle)
        print("Usage: /xpbe style <" .. StyleList("|") .. ">")
        return
    end
    if IsValidStyle(style) then
        if Addon.Config and Addon.Config.SetOptionKey then
            Addon.Config:SetOptionKey("barStyle", style)
            print("|cFF00FF00XP Bar Enhanced:|r Bar style set to: " .. style)
        else
            print("|cFFFF0000XP Bar Enhanced:|r Config module not available")
        end
    else
        print("|cFFFF0000XP Bar Enhanced:|r Invalid style. Use: " .. StyleList(", "))
    end
end

local function handleProfile(arg)
    local config = Addon.Config
    if not config then
        print("|cFFFF0000XP Bar Enhanced:|r Profile support is unavailable")
        return
    end

    local action, rest = string.match(arg or "", "^(%S*)%s*(.-)$")
    action = string.lower(action or "")
    rest = rest or ""

    if action == "" then
        local active = config:GetActiveProfileName()
        local names = config:GetProfileNames()
        print("|cFF00FF00XP Bar Enhanced:|r Active settings source: " .. (active or "Global"))
        if #names > 0 then
            print("|cFF00FF00XP Bar Enhanced:|r Profiles: " .. table.concat(names, ", "))
        else
            print("|cFF00FF00XP Bar Enhanced:|r No saved profiles")
        end
        return
    end

    if action == "global" or action == "clear" then
        local success, err = config:SelectProfile(nil)
        if success then
            print("|cFF00FF00XP Bar Enhanced:|r " .. L["MSG_PROFILE_GLOBAL"])
        else
            print("|cFFFF0000XP Bar Enhanced:|r " .. tostring(err))
        end
        return
    end

    if action == "use" or action == "select" then
        if rest == "" then
            print("|cFFFF0000XP Bar Enhanced:|r Usage: /xpbe profile use <name>")
            return
        end
        -- Sanitize input to prevent control characters
        local sanitized = rest:gsub("[%c]", "")  -- Remove control characters
        if sanitized == "" then
            print("|cFFFF0000XP Bar Enhanced:|r Profile name cannot be empty or contain only control characters")
            return
        end
        local success, err = config:SelectProfile(sanitized)
        if success then
            print("|cFF00FF00XP Bar Enhanced:|r " .. string.format(L["MSG_PROFILE_SELECTED"], sanitized))
        else
            print("|cFFFF0000XP Bar Enhanced:|r " .. tostring(err))
        end
        return
    end

    if action == "new" or action == "create" then
        if rest == "" then
            print("|cFFFF0000XP Bar Enhanced:|r Usage: /xpbe profile new <name>")
            return
        end
        -- Sanitize input to prevent control characters
        local sanitized = rest:gsub("[%c]", "")  -- Remove control characters
        if sanitized == "" then
            print("|cFFFF0000XP Bar Enhanced:|r Profile name cannot be empty or contain only control characters")
            return
        end
        local success, err = config:CreateProfile(sanitized, true)
        if success then
            print("|cFF00FF00XP Bar Enhanced:|r " .. string.format(L["MSG_PROFILE_CREATED"], sanitized))
        else
            print("|cFFFF0000XP Bar Enhanced:|r " .. tostring(err))
        end
        return
    end

    if action == "rename" then
        local active = config:GetActiveProfileName()
        if not active then
            print("|cFFFF0000XP Bar Enhanced:|r " .. L["ERR_PROFILE_GLOBAL_RENAME"])
            return
        end
        if rest == "" then
            print("|cFFFF0000XP Bar Enhanced:|r Usage: /xpbe profile rename <new name>")
            return
        end
        -- Sanitize input to prevent control characters
        local sanitized = rest:gsub("[%c]", "")  -- Remove control characters
        if sanitized == "" then
            print("|cFFFF0000XP Bar Enhanced:|r Profile name cannot be empty or contain only control characters")
            return
        end
        local success, err = config:RenameProfile(active, sanitized)
        if success then
            print("|cFF00FF00XP Bar Enhanced:|r " .. string.format(L["MSG_PROFILE_RENAMED"], sanitized))
        else
            print("|cFFFF0000XP Bar Enhanced:|r " .. tostring(err))
        end
        return
    end

    if action == "delete" or action == "remove" then
        local targetName = rest ~= "" and rest or config:GetActiveProfileName()
        if not targetName then
            print("|cFFFF0000XP Bar Enhanced:|r " .. L["ERR_PROFILE_GLOBAL_DELETE"])
            return
        end
        local success, err = config:DeleteProfile(targetName)
        if success then
            print("|cFF00FF00XP Bar Enhanced:|r " .. string.format(L["MSG_PROFILE_DELETED"], targetName))
        else
            print("|cFFFF0000XP Bar Enhanced:|r " .. tostring(err))
        end
        return
    end

    print("|cFFFF0000XP Bar Enhanced:|r Unknown profile command")
    print("Usage: /xpbe profile [global|use <name>|new <name>|rename <new name>|delete [name]]")
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
    elseif command == "profile" or command == "profiles" then
        handleProfile(arg)
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
