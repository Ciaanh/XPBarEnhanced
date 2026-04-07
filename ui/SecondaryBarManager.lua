-- XP Bar Enhanced - Secondary Bar Manager
-- Manages the reputation and companion secondary progress bars independently.
-- Each bar is enabled/disabled via a boolean flag; style is derived from the primary barStyle.

local Addon = XPBarEnhanced
Addon.SecondaryBarManager = Addon.SecondaryBarManager or {}
local Manager = Addon.SecondaryBarManager

local function DebugSecondary(message, ...)
    local db = Addon and Addon.db
    if db and db.debugSecondaryBars == false then
        return
    end

    local text = tostring(message or "")
    if select("#", ...) > 0 then
        text = string.format(text, ...)
    end
    print("|cff66ccffXPBE Secondary|r " .. text)
end

local SHOW_CONFIG_KEY = {
    reputation = "showReputationBar",
    companion  = "showCompanionBar",
}

-- Derive the style string from boolean show flag and primary barStyle.
-- Returns "flat" when the bar is enabled and a primary style is active, else "none".
local function _DeriveSecondaryStyle(key)
    local db = Addon.db or {}
    local showKey = SHOW_CONFIG_KEY[key]
    if not showKey or not db[showKey] then
        DebugSecondary("DeriveStyle %s -> none (show disabled)", tostring(key))
        return "none"
    end
    local primaryStyle = db.barStyle or "none"
    if primaryStyle == "none" then
        DebugSecondary("DeriveStyle %s -> none (primary style none)", tostring(key))
        return "none"
    end
    DebugSecondary("DeriveStyle %s -> flat (primary style %s)", tostring(key), tostring(primaryStyle))
    return "flat"
end

local TEMPLATE_MAP = {
    reputation = { flat = "FlatReputationBarTemplate" },
    companion  = { flat = "FlatCompanionBarTemplate" },
}

local function IsCustomStyle(styleMap, style)
    return style and styleMap and styleMap[style] ~= nil
end

-------------------------------------------------------------------
-- INTERNAL
-------------------------------------------------------------------

local function SafeCallErrorHandler(err)
    if CallErrorHandler then
        CallErrorHandler(err)
    else
        print(tostring(err))
    end
end

function Manager:_GetOrCreateFrame(key, style)
    self._frames = self._frames or {}
    self._frames[key] = self._frames[key] or {}

    local frame = self._frames[key][style]
    if not frame then
        local templates = TEMPLATE_MAP[key]
        local templateName = templates and templates[style]
        if not templateName then
            return nil
        end

        frame = CreateFrame("Frame", nil, UIParent, templateName)
        if not frame then
            error("SecondaryBarManager: failed to create frame from template: " .. templateName)
        end
        self._frames[key][style] = frame
    end
    return frame
end

function Manager:_SetStyle(key, style)
    self._currentStyles = self._currentStyles or {}
    self._frames = self._frames or {}

    if self._currentStyles[key] == style then
        DebugSecondary("SetStyle %s unchanged (%s)", tostring(key), tostring(style))
        return
    end

    -- Hide all existing frames for this key
    for _, frame in pairs(self._frames[key] or {}) do
        if frame and frame.SetShown then
            frame:SetShown(false)
        end
    end

    self._currentStyles[key] = style
    DebugSecondary("SetStyle %s -> %s", tostring(key), tostring(style))

    if style == "none" then
        return
    end

    local frame = self:_GetOrCreateFrame(key, style)
    if frame and frame.SetShown then
        frame:SetShown(true)
    end
end

-------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------

function Manager:Initialize()
    local db = Addon.db or {}

    self:InstallBlizzardBarHooks()

    self:SetReputationStyle(_DeriveSecondaryStyle("reputation"))
    self:SetCompanionStyle(_DeriveSecondaryStyle("companion"))
    self:ApplyDefaultReputationBarVisibility()
    self:ReapplyAttachedPositions()

    Addon.EventBus:Register(
        Addon.EventNames.CONFIG_UPDATED,
        "SecondaryBarManager_ConfigUpdated",
        function(_ctx)
            self:SetReputationStyle(_DeriveSecondaryStyle("reputation"))
            self:SetCompanionStyle(_DeriveSecondaryStyle("companion"))
            self:ApplyDefaultReputationBarVisibility()
            self:ReapplyAttachedPositions()
        end
    )
end

-- Stack active secondary bars above the primary XP bar when attached mode is on.
-- When attached mode is off, restores each bar to its saved/fallback position.
function Manager:ReapplyAttachedPositions()
    local db = Addon.db or {}

    if not db.secondaryBarsAttached then
        DebugSecondary("ReapplyAttachedPositions: detached mode")
        -- Restore each active frame to its independently saved/fallback position.
        for key, styleFrames in pairs(self._frames or {}) do
            local style = self._currentStyles and self._currentStyles[key]
            if style and style ~= "none" then
                local frame = styleFrames[style]
                if frame and frame.ApplyInitialPosition then
                    frame:ApplyInitialPosition()
                end
            end
        end
        return
    end

    local primaryFrame = Addon.BarManager and Addon.BarManager:GetCurrentFrame()
    if not primaryFrame then
        DebugSecondary("ReapplyAttachedPositions: no primary frame available")
        return
    end

    DebugSecondary("ReapplyAttachedPositions: attached mode, primary frame found")

    -- Stack bars bottom-to-top: XP bar → reputation → companion (2px gap).
    local barOrder = { "reputation", "companion" }
    local anchorFrame = primaryFrame
    for _, key in ipairs(barOrder) do
        local style = self._currentStyles and self._currentStyles[key]
        if style and style ~= "none" then
            local frame = self._frames and self._frames[key] and self._frames[key][style]
            if frame then
                frame:ClearAllPoints()
                frame:SetPoint("BOTTOM", anchorFrame, "TOP", 0, 2)
                DebugSecondary("Attached %s bar above %s", tostring(key), tostring(anchorFrame))
                anchorFrame = frame
            end
        end
    end
end

function Manager:ApplyDefaultReputationBarVisibility()
    local style = self._currentStyles and self._currentStyles["reputation"]
    local hasCustomReputationStyle = IsCustomStyle(TEMPLATE_MAP.reputation, style)

    if hasCustomReputationStyle then
        if _G.SecondaryStatusTrackingBarContainer then
            _G.SecondaryStatusTrackingBarContainer:Hide()
        end
    else
        if _G.SecondaryStatusTrackingBarContainer then
            _G.SecondaryStatusTrackingBarContainer:Show()
        end
    end
end

function Manager:InstallBlizzardBarHooks()
    if self._blizzardHooksInstalled then
        return
    end

    local container = _G.SecondaryStatusTrackingBarContainer
    if container and container.Show then
        hooksecurefunc(container, "Show", function()
            local style = self._currentStyles and self._currentStyles["reputation"]
            if IsCustomStyle(TEMPLATE_MAP.reputation, style) then
                container:Hide()
            end
        end)
    end
    if container and container.SetShown then
        hooksecurefunc(container, "SetShown", function(_, shown)
            local style = self._currentStyles and self._currentStyles["reputation"]
            if shown and IsCustomStyle(TEMPLATE_MAP.reputation, style) then
                container:Hide()
            end
        end)
    end

    self._blizzardHooksInstalled = true
end

function Manager:SetReputationStyle(style)
    xpcall(self._SetStyle, SafeCallErrorHandler, self, "reputation", style)
    self:ApplyDefaultReputationBarVisibility()
end

function Manager:SetCompanionStyle(style)
    xpcall(self._SetStyle, SafeCallErrorHandler, self, "companion", style)
end

function Manager:ResetBarPositions()
    local defaults = Addon.defaults or {}
    local db = Addon.db or {}
    local posMap = {
        reputation = {configKey = "reputationBarPosition", defaultPos = defaults.reputationBarPosition},
        companion  = {configKey = "companionBarPosition", defaultPos = defaults.companionBarPosition},
    }
    
    for key, posInfo in pairs(posMap) do
        -- Clear SavedVariables
        if db[posInfo.configKey] then
            db[posInfo.configKey] = nil
        end
        
        -- Reset frame position
        local style = self._currentStyles and self._currentStyles[key]
        if style and style ~= "none" then
            local frame = self._frames and self._frames[key] and self._frames[key][style]
            if frame and frame.ResetPosition then
                frame:ResetPosition()
            elseif frame and frame.ClearAllPoints and posInfo.defaultPos then
                frame:ClearAllPoints()
                frame:SetPoint(
                    posInfo.defaultPos.point,
                    posInfo.defaultPos.relativeTo or "UIParent",
                    posInfo.defaultPos.relativePoint,
                    posInfo.defaultPos.x or 0,
                    posInfo.defaultPos.y or 0
                )
            end
        end
    end
end

return Manager
