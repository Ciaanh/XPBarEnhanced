-- Changelog.lua
-- Shows a one-time changelog splash when the addon version changes.

local Addon = XPBarEnhanced
Addon.Changelog = Addon.Changelog or {}

local Changelog = Addon.Changelog

Changelog.entries = {
    {
        version = "1.3.0",
        notes = {
            "New Sigil bar style: a class ring that advances through four tiers as you approach the level cap, from a plain band to a crowned frame. The frame's metalwork is themed to your class family, the crest is a round medallion carrying your class's iconic motif, and a companion ring tracks the secondary bar. XP fills as a clockwise arc set into the frame itself, between its outer band and inner rim, emerging at the crest's left edge and completing at its right.",
            "Five Sigil options under Visual: skin, size, tier mode, pinned tier, and class-colour tint.",
            "Time to level on the Circular and Vertical styles now updates while you stand still, instead of freezing until your next XP gain.",
            "The Circular ring now repaints only the segments that actually changed, cutting a large amount of per-frame work at high segment counts.",
            "Fixed XP being mis-credited to your session: two independent trackers computed the gain and could disagree on the same event. There is now one.",
            "Fixed a whole level of XP going missing when crossing between two levels that share the same XP requirement.",
            "Fixed XP/hour reading in the millions during a session's first seconds.",
            "New /xpbe sigil debug and /xpbe test tier commands.",
        },
    },
    {
        version = "1.2.0",
        notes = {
            "New readout presets: Minimal, Standard and Leveller set every text and overlay toggle in one click. The individual toggles moved under a collapsed Advanced section.",
            "Bar styles are now picked from a gallery of labelled previews instead of a text dropdown.",
            "Options rows no longer vanish when you switch bar style: rows the style ignores stay put, disabled, with the reason beside them.",
            "Level-up celebration now works on the Circular, Minimap Ring and Terminal styles, where it was previously invisible.",
            "The Colors tab now leads with the secondary-source colour actually in use; the other three fold away but stay editable.",
            "Stats window rebuilt: XP/hour and time to level are now large hero numbers, the bookkeeping rows collapse into a Details section, and the window is half its old height.",
            "The minimap tooltip keeps the same shape at the start of a session and formats its XP number like the rest of the UI.",
            "Fixed the Circular style's ring border and centre disc, which never rendered because the art was requested with the wrong file extension.",
            "Fixed the XP gain flash using the rested overlay colour instead of the bar's rested fill colour.",
            "Removed the duplicate session XP row in the Stats window.",
        },
    },
    {
        version = "1.1.8",
        notes = {
            "Level progress notifications now appear as a compact toast with the addon icon instead of plain text at the top of the screen.",
            "The Orb style is now listed in the /xpbe help style list.",
        },
    },
    {
        version = "1.1.7",
        notes = {
            "New Orb bar style: a Diablo-style filling sphere with glass and rim art, plus a companion orb for the secondary bar.",
            "New secondary bar sources: Honor (PvP) and Profession skill, with a selector for which profession to track.",
            "New option to show the selected secondary source on the main bar at max level, with matching color, text, and tooltip.",
            "Level-up celebration: a golden glow when you ding.",
            "Session XP charts in the Stats window: XP/hour histogram and quest-vs-other split.",
            "Level progress notifications at 25/50/75% with estimated time to ding.",
            "LibDataBroker feed (XP/h and time-to-level) for Titan Panel, Bazooka, and ElvUI datatexts.",
            "Fixed session XP missing the level-crossing amount on level-ups, multi-level jumps, and levels sharing the same XP requirement.",
            "Fixed reputation gains lost when crossing a renown level or paragon cycle, and housing favor lost on house level-ups.",
            "Fixed Lua error when mouse-wheeling over the minimap ring (removed zoom API).",
            "Profile overrides now apply everywhere (session resets, text toggles, quest overlays, color resets).",
            "Session data is now stored per character, so alts no longer inherit played time; housing session resets on login.",
            "Fixed options panel scrolling cutting off tall tabs.",
            "Fixed bar teleporting to the screen corner when enabling draggable positioning.",
            "Fixed XP bar flash briefly showing a stale fill on small XP gains.",
            "Fixed chat filter that could suppress system messages after requesting played time.",
            "Stats window now honors number abbreviation, refreshes only while open, and keeps its position across UI-scale changes.",
            "Many stability fixes: frame leaks in combat, event bus subscription leaks, tooltip ownership, rested XP tooltip.",
        },
    },
    {
        version = "1.1.6",
        notes = {
            "Fixed housing favor secondary bar not refreshing after gaining housing XP.",
        },
    },
    {
        version = "1.1.5",
        notes = {
            "Added secondary source selection with Reputation and Housing Favor modes.",
            "Added tracked house favor support as a secondary progress source.",
            "Improved secondary bar refresh flow so source changes update the live bar immediately.",
        },
    },
    {
        version = "1.1.4",
        notes = {
            "Added size presets (Small/Default/Large/Huge) for the Flat and Vertical bars.",
            "Flat style now scales below-bar text with bar size presets.",
            "Fixed quest and rested overlay height and width on scaled bars.",
            "Fixed milestone tick positions and toggle response on scaled Flat bars.",
            "Fixed terminal custom color resolution to respect active profile settings.",
        },
    },
    {
        version = "1.1.3",
        notes = {
            "New Profile System with profile selection, creation, rename, and delete.",
            "Blizzard-style Profiles dropdown with radio selection, inline row actions, and an in-menu New Profile action.",
            "Profile-aware option lookups through a centralized shared helper.",
        },
    },
    {
        version = "1.1.2",
        notes = {
            "Fixed the XP bar being hidden after every level-up (UIFrameFlash showWhenDone bug).",
            "Fixed Blizzard bar taint on combat start/end; Hide() calls are now deferred out of lockdown.",
            "Suppressed TIME_PLAYED_MSG chat noise from internal time-played requests.",
        },
    },
    {
        version = "1.1.1",
        notes = {
            "Added this in-game 'What's New' popup, shown once when you update to a new version.",
            "Polished the startup flow so update notes appear automatically after login or reload.",
        },
    },
    {
        version = "1.1.0",
        notes = {
            "Added secondary reputation bars with style-aware layouts across supported bar styles.",
            "Integrated tracked-faction session stats, including Delve companion support.",
            "Expanded the options panel and improved recent XP-per-hour responsiveness.",
        },
    },
    {
        version = "1.0.6",
        notes = {
            "Fixed missing circular center text and added an option to scale that text with ring size.",
            "Improved circular bar usability for larger layouts and stream-friendly setups.",
        },
    },
    {
        version = "1.0.5",
        notes = {
            "Added the Terminal and Minimap Ring bar styles.",
            "Reworked the shared bar template and animation pipeline for smoother XP updates.",
            "Improved Blizzard bar visibility handling and fixed several animation and settings issues.",
        },
    },
    {
        version = "1.0.4",
        notes = {
            "Added circular ring size presets from Small to Huge.",
            "Improved scaling so ring elements grow cleanly without distorting the center art.",
        },
    },
    {
        version = "1.0.3",
        notes = {
            "Improved time-to-level and XP-per-hour estimates when level time includes long idle periods.",
        },
    },
    {
        version = "1.0.1",
        notes = {
            "Fixed max-level bar visibility so the addon swaps cleanly back to Blizzard behavior when capped.",
            "Fixed classic bar dragging and improved level-up handling accuracy.",
        },
    },
    {
        version = "1.0.0",
        notes = {
            "Initial release of XP Bar Enhanced.",
            "Included multiple XP bar styles, quest XP overlays, session tracking, stats, minimap access, and color customization.",
        },
    },
}

local function GetCurrentVersion()
    local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("XPBarEnhanced", "Version")
    return version or "0.0.0"
end

local function ParseVersion(version)
    local major, minor, patch = tostring(version or ""):match("^(%d+)%.(%d+)%.?(%d*)")
    return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
end

-- True when version a is at or below version b
local function IsVersionAtOrBelow(a, b)
    local aMajor, aMinor, aPatch = ParseVersion(a)
    local bMajor, bMinor, bPatch = ParseVersion(b)
    if aMajor ~= bMajor then return aMajor < bMajor end
    if aMinor ~= bMinor then return aMinor < bMinor end
    return aPatch <= bPatch
end

local function CollectEntriesThrough(boundaryVersion)
    local entries = {}
    for _, entry in ipairs(Changelog.entries or {}) do
        -- Stop at the first entry the user has already seen. Numeric
        -- comparison, not equality: the boundary version may have no entry
        -- of its own (skipped versions must not surface the whole history).
        if boundaryVersion and IsVersionAtOrBelow(entry.version, boundaryVersion) then
            break
        end
        entries[#entries + 1] = entry
    end
    return entries
end

function Changelog:Show(boundaryVersion)
    local entries = CollectEntriesThrough(boundaryVersion)
    if #entries == 0 then
        return
    end

    if self.frame then
        self:RefreshContent(entries)
        self.frame:Show()
        return
    end

    local L = Addon.L or {}
    local frame = CreateFrame("Frame", "XPBarEnhancedChangelogFrame", UIParent, "BackdropTemplate")
    frame:SetSize(500, 420)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = {left = 3, right = 3, top = 3, bottom = 3},
    })
    frame:SetBackdropColor(0.06, 0.06, 0.08, 0.96)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -12)
    title:SetText(L["CHANGELOG_TITLE"] or "What's New in XP Bar Enhanced")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -44)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 14)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(440, 1)
    scrollFrame:SetScrollChild(content)

    self.frame = frame
    self.scrollFrame = scrollFrame
    self.content = content

    tinsert(UISpecialFrames, "XPBarEnhancedChangelogFrame")

    self:RefreshContent(entries)
    frame:Show()
end

-- FontStrings can never be destroyed, so pool and reuse them across refreshes
function Changelog:AcquireLine(index, fontTemplate)
    self.lines = self.lines or {}
    local line = self.lines[index]
    if not line then
        line = self.content:CreateFontString(nil, "OVERLAY", fontTemplate)
        self.lines[index] = line
    end
    line:SetFontObject(fontTemplate)
    line:ClearAllPoints()
    line:Show()
    return line
end

function Changelog:RefreshContent(entries)
    if not self.content then
        return
    end

    local lineCount = 0
    local y = -4
    for _, entry in ipairs(entries) do
        lineCount = lineCount + 1
        local versionLabel = self:AcquireLine(lineCount, "GameFontNormal")
        versionLabel:SetPoint("TOPLEFT", self.content, "TOPLEFT", 6, y)
        versionLabel:SetText(string.format("v%s", entry.version))
        versionLabel:SetTextColor(0.35, 0.75, 1.0, 1.0)

        y = y - versionLabel:GetStringHeight() - 6

        local noteText = ""
        for idx, note in ipairs(entry.notes or {}) do
            noteText = noteText .. "- " .. tostring(note)
            if idx < #(entry.notes or {}) then
                noteText = noteText .. "\n\n"
            end
        end

        lineCount = lineCount + 1
        local notes = self:AcquireLine(lineCount, "GameFontHighlightSmall")
        notes:SetPoint("TOPLEFT", self.content, "TOPLEFT", 10, y)
        notes:SetPoint("RIGHT", self.content, "RIGHT", -8, 0)
        notes:SetJustifyH("LEFT")
        notes:SetJustifyV("TOP")
        notes:SetSpacing(2)
        notes:SetTextColor(0.90, 0.90, 0.90, 1)
        notes:SetText(noteText)

        y = y - notes:GetStringHeight() - 16
    end

    -- Hide surplus pooled lines from a previous, longer refresh
    if self.lines then
        for i = lineCount + 1, #self.lines do
            self.lines[i]:Hide()
        end
    end

    self.content:SetHeight(math.max(1, -y + 8))
end

function Changelog:CheckForUpdates()
    local db = Addon.db
    if type(db) ~= "table" then
        return
    end

    local currentVersion = GetCurrentVersion()
    local lastSeenVersion = db.lastSeenVersion

    if lastSeenVersion ~= currentVersion then
        db.lastSeenVersion = currentVersion
        self:Show(lastSeenVersion)
    end
end

return Changelog
