-- XP Bar Enhanced - Blizzard status bars
-- Keeps Blizzard's own XP and reputation bars out of the way while the addon
-- draws them.
--
-- Every supported client builds those bars from StatusTrackingBarManager: two
-- containers, each showing whichever bar currently has the higher priority.
-- Which container holds the XP bar moves -- a tracked house outranks XP on
-- Retail, and at the level cap reputation is promoted into the main container
-- -- so a container is judged by the bar it holds, not by its slot.
--
-- Blizzard re-shows a container through UpdateShownState on every fade, bar
-- change and Edit Mode exit. A post-hook there hides it again the moment
-- Blizzard shows it; hiding once, as the managers used to, lost the container
-- to the next fade. A container the addon hid is handed back to
-- UpdateShownState, never force-shown, so Blizzard still decides whether it
-- has anything to show.

local Addon = XPBarEnhanced
Addon.BlizzardBars = Addon.BlizzardBars or {}
local BlizzardBars = Addon.BlizzardBars

local CONTAINERS = {"MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer"}

-- Frames from older layouts some clients still ship, by what they stand for.
local LEGACY_XP_FRAMES = {"MainMenuExpBar", "MainMenuBarMaxLevelBar"}
local LEGACY_SECONDARY_FRAMES = {"ReputationWatchBar"}

local roles = {}          -- frame -> "container" | "xp" | "secondary"
local hiddenByAddon = {}  -- frames this module hid and must hand back
local deferFrame

-------------------------------------------------------------------
-- WHAT THE ADDON IS DRAWING
-------------------------------------------------------------------

local function PrimaryActive()
    local manager = Addon.BarManager
    return (manager and manager.IsCustomStyle and manager:IsCustomStyle(manager.currentStyle)) and true or false
end

-- At the level cap the primary bar can be repurposed to show the secondary
-- source, and the standalone secondary bar is then off.
local function SecondarySourceDrawn()
    local secondary = Addon.SecondaryBarManager
    if secondary and secondary.IsActive and secondary:IsActive() then
        return true
    end
    local manager = Addon.BarManager
    return PrimaryActive() and manager.ShouldRepurposePrimaryAtMaxLevel
        and manager:ShouldRepurposePrimaryAtMaxLevel() and true or false
end

local function ShouldHide(frame)
    local role = roles[frame]
    if role == "xp" then
        return PrimaryActive()
    elseif role == "secondary" then
        return SecondarySourceDrawn()
    end

    -- Edit Mode shows every system, empty or not, so it can be placed.
    if frame.isInEditMode then
        return false
    end
    local info = rawget(_G, "StatusTrackingBarInfo")
    local bars = info and info.BarsEnum
    local shown = frame.shownBarIndex
    if not bars or shown == nil or shown == bars.None then
        return false
    end
    if shown == bars.Experience then
        return PrimaryActive()
    end
    return SecondarySourceDrawn()
end

-------------------------------------------------------------------
-- APPLYING
-------------------------------------------------------------------

-- The containers may be protected on some clients, so visibility only changes
-- out of combat; a change wanted during combat is applied when it ends.
local function DeferUntilCombatEnds()
    if not deferFrame then
        deferFrame = CreateFrame("Frame")
        deferFrame:SetScript("OnEvent", function(frame)
            frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
            BlizzardBars:Refresh()
        end)
    end
    deferFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local function Apply(frame)
    if ShouldHide(frame) then
        hiddenByAddon[frame] = true
        if frame:IsShown() then
            if InCombatLockdown() then
                DeferUntilCombatEnds()
            else
                frame:Hide()
            end
        end
    elseif hiddenByAddon[frame] then
        if InCombatLockdown() then
            DeferUntilCombatEnds()
            return
        end
        hiddenByAddon[frame] = nil
        if frame.UpdateShownState then
            frame:UpdateShownState()
        else
            frame:Show()
        end
    end
end

local function Track(frame, role)
    if not frame or roles[frame] then
        return
    end
    roles[frame] = role

    local function recheck()
        Apply(frame)
    end
    if type(frame.UpdateShownState) == "function" then
        hooksecurefunc(frame, "UpdateShownState", recheck)
    end
    -- Backstop for any other path that shows the frame.
    if frame.HookScript then
        frame:HookScript("OnShow", recheck)
    end
end

--- Re-evaluate every Blizzard status bar against what the addon draws now.
--- Call whenever the primary or secondary bar style changes.
function BlizzardBars:Refresh()
    for _, name in ipairs(CONTAINERS) do
        Track(rawget(_G, name), "container")
    end
    for _, name in ipairs(LEGACY_XP_FRAMES) do
        Track(rawget(_G, name), "xp")
    end
    for _, name in ipairs(LEGACY_SECONDARY_FRAMES) do
        Track(rawget(_G, name), "secondary")
    end

    for frame in pairs(roles) do
        Apply(frame)
    end
end

return BlizzardBars
