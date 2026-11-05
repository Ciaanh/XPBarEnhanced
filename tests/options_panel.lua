-- The options panel's fold state: decided at login, after a profile switch and after a reset,
-- and otherwise left to the player. Changing a setting refreshes the panel, and that refresh
-- used to fold Advanced away again. The panel's XML is not loaded, so a stand-in panel records
-- the calls the Options module makes on it.
local H = dofile((arg[1] or ".") .. "/tests/harness.lua")

local Addon = H.Load(nil)
-- Options.lua is listed in OptionsPanel.xml, which the harness skips.
assert(loadfile(H.ROOT .. "/ui/options/Options.lua"))(H.ADDON, Addon)

local panel = { controls = {}, defaultsApplied = 0, refreshes = 0 }
function panel:ApplyDisclosureDefaults() self.defaultsApplied = self.defaultsApplied + 1 end
function panel:Refresh() self.refreshes = self.refreshes + 1 end
XPBarEnhancedOptionsPanel = panel

H.Login()
H.Check("fold defaults applied at login", panel.defaultsApplied, 1)

Addon.Options:OnOptionChanged("xpRateWindow")
Addon.Options:OnOptionChanged("showKillsToLevelText")
H.Check("a setting change refreshes the panel", panel.refreshes, 2)
H.Check("but leaves the fold state alone", panel.defaultsApplied, 1)

Addon.Options:Open()
H.Check("opening the panel again leaves it alone too", panel.defaultsApplied, 1)

-- Another readout comes with another profile or a reset: fold again, as a login would.
XPBarEnhancedOptionsMixin.OnProfileChanged(panel)
H.Check("a profile switch folds again", panel.defaultsApplied, 2)
Addon.Options.frame = panel
Addon.Options:AcceptResetSettingsDialog()
H.Check("so does resetting the settings", panel.defaultsApplied, 3)

--------------------------------------------------------------------------------
H.Section("Each style's options fold under its own section")
--------------------------------------------------------------------------------
-- In the XML: every Visual-tab row of a section sits after its header; rows shared by
-- several styles (the gradient fill) stay outside every section.
local panelFile = assert(io.open(H.ROOT .. "/ui/options/OptionsPanel.xml"))
local panelXML = panelFile:read("*a")
panelFile:close()
local headers, grouped, misplaced = {}, {}, {}
for block in panelXML:gmatch("<Frame parentKey=.-</Frame>") do
    if block:find('key="optionTab" value="visual"', 1, true) then
        local index = tonumber(block:match('key="layoutIndex" value="([%d%.]+)"'))
        local toggle = block:match('key="disclosureToggle" value="([%w_]+)"')
        local group = block:match('key="disclosureGroup" value="([%w_]+)"')
        if toggle then headers[toggle] = index end
        if group then grouped[#grouped + 1] = { group = group, index = index } end
    end
end
for _, row in ipairs(grouped) do
    if not (headers[row.group] and headers[row.group] < row.index) then misplaced[#misplaced + 1] = row.group end
end
local sections = {}
for style in pairs(headers) do sections[#sections + 1] = style end
table.sort(sections)
H.Check("a section per style with options", table.concat(sections, ","),
    "circular,classic,flat,minimap_ring,ring,terminal,vertical")
H.Check("their rows", #grouped, 2 + 2 + 1 + 5 + 6 + 15 + 1)
H.Check("each row after its section's header", #misplaced, 0)
H.Check("the gradient fill, shared by three styles, in none",
    panelXML:match('<Frame parentKey="Row_fillGradient".-</Frame>'):find("disclosureGroup", 1, true), nil)
for style in pairs(headers) do
    H.Check("a name for the " .. style .. " section", Addon.L["OPT_SECTION_" .. style:upper()] ~= nil, true)
end

-- At login only the section of the style on screen is open; a change of style opens the new
-- one and folds the one it replaced; between changes the folds are the player's.
-- The style files are not loaded here, so every style would resolve to a fallback: resolve
-- each to itself, as a client that draws them all does.
local realResolve = Addon.BarManager.ResolveStyleKey
Addon.BarManager.ResolveStyleKey = function(_, style) return style end
local realSetStyle = Addon.BarManager.SetStyle
Addon.BarManager.SetStyle = function() end
local folds = setmetatable({ _disclosureExpanded = {} }, { __index = XPBarEnhancedOptionsMixin })
local function Open()
    local open = {}
    for style in pairs(headers) do
        if folds:IsDisclosureExpanded(style) then open[#open + 1] = style end
    end
    table.sort(open)
    return table.concat(open, ",")
end
Addon.Config:SetOptionKey("barStyle", "flat")
folds:ApplyDisclosureDefaults()
H.Check("at login: the style on screen's section only", Open(), "flat")
folds:FollowStyleSections("flat")
folds:SetDisclosureExpanded("classic", true)
folds:FollowStyleSections("flat")
H.Check("a section the player opened stays open", Open(), "classic,flat")
folds:FollowStyleSections("circular")
H.Check("another style: its section opens, the old one folds", Open(), "circular,classic")
folds:FollowStyleSections("orb")
H.Check("a style without options folds the old one", Open(), "classic")
folds:FollowStyleSections("minimap_ring")
H.Check("and the next style opens its own", Open(), "classic,minimap_ring")

-- Use texture belongs to Circular and Minimap Ring: it joins the section on screen.
local useTexture = {}
local placer = setmetatable({ ContentFrame = { OptionsContainer = { Row_circularUseTexture = useTexture } } },
    { __index = XPBarEnhancedOptionsMixin })
Addon.Config:SetOptionKey("barStyle", "minimap_ring")
placer:PlaceSharedSectionRows()
H.Check("Use texture under Minimap Ring", useTexture.disclosureGroup .. " " .. useTexture.layoutIndex, "minimap_ring 16.2")
Addon.Config:SetOptionKey("barStyle", "circular")
placer:PlaceSharedSectionRows()
H.Check("Use texture under Circular", useTexture.disclosureGroup .. " " .. useTexture.layoutIndex, "circular 10")
Addon.Config:SetOptionKey("barStyle", "flat")
placer:PlaceSharedSectionRows()
H.Check("under another style: in Circular's section", useTexture.disclosureGroup, "circular")
Addon.BarManager.SetStyle = realSetStyle
Addon.BarManager.ResolveStyleKey = realResolve

H.CheckNoErrors("no errors")
H.Done()
