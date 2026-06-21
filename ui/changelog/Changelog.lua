-- Changelog.lua
-- Shows a one-time changelog splash when the addon version changes.

local Addon = XPBarEnhanced
Addon.Changelog = Addon.Changelog or {}

local Changelog = Addon.Changelog

Changelog.entries = {
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

local function CollectEntriesThrough(boundaryVersion)
    local entries = {}
    for _, entry in ipairs(Changelog.entries or {}) do
        entries[#entries + 1] = entry
        -- Include the boundary version entry, then stop.
        if boundaryVersion and entry.version == boundaryVersion then
            break
        end
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

function Changelog:RefreshContent(entries)
    if not self.content then
        return
    end

    if self.lines then
        for _, line in ipairs(self.lines) do
            line:Hide()
        end
    end
    self.lines = {}

    local y = -4
    for _, entry in ipairs(entries) do
        local versionLabel = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        versionLabel:SetPoint("TOPLEFT", self.content, "TOPLEFT", 6, y)
        versionLabel:SetText(string.format("v%s", entry.version))
        versionLabel:SetTextColor(0.35, 0.75, 1.0, 1.0)
        self.lines[#self.lines + 1] = versionLabel

        y = y - versionLabel:GetStringHeight() - 6

        local noteText = ""
        for idx, note in ipairs(entry.notes or {}) do
            noteText = noteText .. "- " .. tostring(note)
            if idx < #(entry.notes or {}) then
                noteText = noteText .. "\n\n"
            end
        end

        local notes = self.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        notes:SetPoint("TOPLEFT", self.content, "TOPLEFT", 10, y)
        notes:SetPoint("RIGHT", self.content, "RIGHT", -8, 0)
        notes:SetJustifyH("LEFT")
        notes:SetJustifyV("TOP")
        notes:SetSpacing(2)
        notes:SetTextColor(0.90, 0.90, 0.90, 1)
        notes:SetText(noteText)
        self.lines[#self.lines + 1] = notes

        y = y - notes:GetStringHeight() - 16
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
