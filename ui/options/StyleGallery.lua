-- XP Bar Enhanced - Bar style gallery
--
-- Draws one miniature per bar style for the options panel, from the same texture
-- files the real bars use, so a player can tell Terminal from Orb without
-- applying each style in turn.
--
-- The grid is derived from Config.optionDetails.barStyle.options: adding a style
-- to that list adds a swatch here, and only a preview builder has to follow.
-- barStyle itself is unchanged — the swatches write the same saved values the
-- dropdown wrote, so /xpbe style <name> is unaffected.

local Addon = XPBarEnhanced
Addon.StyleGallery = Addon.StyleGallery or {}
local StyleGallery = Addon.StyleGallery

-------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------

-- Grid geometry. 4 columns x 2 rows fills the 520px options container:
-- 4 * 120 + 3 * 4 = 492, inside the 16px row indent.
local COLUMNS = 4
local CELL_WIDTH = 120
local CELL_HEIGHT = 78
local CELL_GAP_X = 4
local CELL_GAP_Y = 6

-- Every miniature shows the same progress so shape, not value, is what differs.
local FILL_RATIO = 0.65

-- Texture paths, all of them already drawn by the styles they preview.
local TEX_SOLID = "Interface\\Buttons\\WHITE8X8"
local TEX_XP_BAR = "Interface\\AddOns\\XPBarEnhanced\\assets\\xp-bar"
local TEX_LEGACY_BG = "Interface\\AddOns\\XPBarEnhanced\\assets\\legacy-background"
local TEX_LEGACY_BORDER = "Interface\\AddOns\\XPBarEnhanced\\assets\\legacy-border"
local TEX_RING_BORDER = "Interface\\AddOns\\XPBarEnhanced\\assets\\border"
local TEX_RING_CENTER = "Interface\\AddOns\\XPBarEnhanced\\assets\\center"
local TEX_ORB_RING = "Interface\\AddOns\\XPBarEnhanced\\assets\\orb_ring"
local TEX_ORB_GLASS = "Interface\\AddOns\\XPBarEnhanced\\assets\\orb_glass"
local TEX_CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local TEX_MINIMAP_BG = "Interface\\Minimap\\UI-Minimap-Background"

-- Terminal draws text, not textures, so its preview needs the same font and the
-- same block characters as ui/styles/terminal/TerminalBarStyle.lua.
local TERMINAL_FONT = "Interface\\AddOns\\XPBarEnhanced\\fonts\\DejaVuSansMono.ttf"
local CH_FULL = "\226\150\136" -- U+2588 FULL BLOCK
local CH_EMPTY = "\226\150\145" -- U+2591 LIGHT SHADE
local TERMINAL_CELLS = 13

-- The selection ring is the addon's own default xpBar purple rather than
-- Blizzard's selection blue, so a selected swatch reads as "XP Bar Enhanced".
local RING_COLOR = {r = 0.58, g = 0.0, b = 0.55}

local TRACK_COLOR = {r = 0.10, g = 0.10, b = 0.11, a = 0.9}
local EMPTY_SEGMENT_COLOR = {r = 0.28, g = 0.28, b = 0.30, a = 0.7}
local OUTLINE_COLOR = {r = 0.42, g = 0.42, b = 0.45, a = 0.8}

-------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------

---The xpBar colour as configured, falling back to the shipped default.
---@return number r, number g, number b
local function FillColor()
    local colors = Addon.Colors
    local color = colors and colors.Get and colors:Get(colors.Key.XpBar)
    if color and color.r then
        return color.r, color.g, color.b
    end
    return RING_COLOR.r, RING_COLOR.g, RING_COLOR.b
end

local function Paint(texture, color)
    texture:SetVertexColor(color.r, color.g, color.b, color.a or 1)
end

---A texture on the canvas, already sized and textured.
local function Add(canvas, layer, file, width, height)
    local texture = canvas:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture(file or TEX_SOLID)
    texture:SetSize(width, height)
    return texture
end

---One edge of a hollow rectangle, used for the "no bar" outline.
local function AddEdge(canvas, width, height, point, x, y)
    local edge = Add(canvas, "ARTWORK", TEX_SOLID, width, height)
    edge:SetPoint(point, canvas, "CENTER", x, y)
    Paint(edge, OUTLINE_COLOR)
    return edge
end

---A ring of small segments, the shape both circular styles draw.
---Mirrors the placement in CircularBarStyle:RepositionSegments — start at
---6 o'clock and run clockwise — so the miniature fills the same way as the bar.
---@return table filled Segments that carry the xpBar colour
local function AddSegmentRing(canvas, count, radius, segWidth, segHeight)
    local filled = {}
    local filledCount = math.floor(count * FILL_RATIO + 0.5)
    local startAngle = math.pi / 2
    local clockwise = -1

    for i = 1, count do
        local angle = startAngle + ((i - 1) / count) * (2 * math.pi)
        local segment = Add(canvas, "ARTWORK", TEX_XP_BAR, segWidth, segHeight)
        segment:SetPoint(
            "CENTER",
            canvas,
            "CENTER",
            math.cos(angle) * radius,
            math.sin(angle) * radius * clockwise
        )
        if segment.SetRotation then
            segment:SetRotation((clockwise * angle) + startAngle)
        end
        if i <= filledCount then
            filled[#filled + 1] = segment
        else
            Paint(segment, EMPTY_SEGMENT_COLOR)
        end
    end

    return filled
end

-------------------------------------------------------------------
-- PREVIEW BUILDERS
-------------------------------------------------------------------
-- Each builder draws one style onto a 112x52 canvas and returns the textures
-- that carry the xpBar colour, so Repaint can follow a colour change without
-- rebuilding the art.

local Builders = {}

--- No bar: an empty outline where the bar would be.
function Builders.none(canvas)
    local width, height = 88, 16
    AddEdge(canvas, width, 1, "TOP", 0, height / 2)
    AddEdge(canvas, width, 1, "BOTTOM", 0, -height / 2)
    AddEdge(canvas, 1, height, "LEFT", -width / 2, 0)
    AddEdge(canvas, 1, height, "RIGHT", width / 2, 0)

    local dash = canvas:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    dash:SetPoint("CENTER")
    dash:SetText("\226\128\148") -- em dash
    return {}
end

--- Flat: a solid track with a solid fill, exactly what FlatBarTemplate draws.
function Builders.flat(canvas)
    local width, height = 88, 12
    local track = Add(canvas, "BACKGROUND", TEX_SOLID, width, height)
    track:SetPoint("CENTER")
    Paint(track, TRACK_COLOR)

    local fill = Add(canvas, "ARTWORK", TEX_SOLID, width * FILL_RATIO, height)
    fill:SetPoint("LEFT", track, "LEFT")
    return {fill}
end

--- Classic: legacy background, gradient xp-bar fill, legacy border on top.
function Builders.classic(canvas)
    local width, height = 92, 18
    local background = Add(canvas, "BACKGROUND", TEX_LEGACY_BG, width, height)
    background:SetPoint("CENTER")

    local inner = width - 8
    local fill = Add(canvas, "ARTWORK", TEX_XP_BAR, inner * FILL_RATIO, 10)
    fill:SetPoint("LEFT", background, "LEFT", 4, 0)

    local border = Add(canvas, "OVERLAY", TEX_LEGACY_BORDER, width, height)
    border:SetPoint("CENTER")
    return {fill}
end

--- Vertical: the same solid track stood on its end, filling upward.
function Builders.vertical(canvas)
    local width, height = 14, 42
    local track = Add(canvas, "BACKGROUND", TEX_SOLID, width, height)
    track:SetPoint("CENTER")
    Paint(track, TRACK_COLOR)

    local fill = Add(canvas, "ARTWORK", TEX_SOLID, width, height * FILL_RATIO)
    fill:SetPoint("BOTTOM", track, "BOTTOM")
    return {fill}
end

--- Circular: segment ring with the addon's own centre disc and border ring.
function Builders.circular(canvas)
    local center = Add(canvas, "BACKGROUND", TEX_RING_CENTER, 20, 20)
    center:SetPoint("CENTER")

    local filled = AddSegmentRing(canvas, 16, 17, 4, 7)

    local ring = Add(canvas, "OVERLAY", TEX_RING_BORDER, 46, 46)
    ring:SetPoint("CENTER")
    return filled
end

--- Minimap ring: the same segment ring, but hugging the minimap itself.
function Builders.minimap_ring(canvas)
    local minimap = Add(canvas, "BACKGROUND", TEX_MINIMAP_BG, 30, 30)
    minimap:SetPoint("CENTER")
    minimap:SetVertexColor(0.55, 0.55, 0.55, 1)

    return AddSegmentRing(canvas, 18, 19, 4, 5)
end

--- Terminal: real mono font, real block characters, phosphor green.
function Builders.terminal(canvas)
    local background = Add(canvas, "BACKGROUND", TEX_SOLID, 104, 34)
    background:SetPoint("CENTER")
    background:SetVertexColor(0.02, 0.02, 0.02, 0.95)

    local filled = math.floor(TERMINAL_CELLS * FILL_RATIO + 0.5)
    local blocks = string.rep(CH_FULL, filled) .. string.rep(CH_EMPTY, TERMINAL_CELLS - filled)

    local line = canvas:CreateFontString(nil, "OVERLAY")
    if not line:SetFont(TERMINAL_FONT, 10, "MONOCHROME") then
        -- The bundled font is the whole point of this preview, but a swatch with
        -- no text at all would read as a broken style rather than a missing file.
        line:SetFontObject("GameFontHighlightSmall")
    end
    line:SetPoint("CENTER", canvas, "CENTER", 0, 5)
    line:SetText("|cFF00A600[|r|cFF00FF00" .. blocks .. "|r|cFF00A600]|r")

    local stats = canvas:CreateFontString(nil, "OVERLAY")
    if not stats:SetFont(TERMINAL_FONT, 9, "MONOCHROME") then
        stats:SetFontObject("GameFontHighlightSmall")
    end
    stats:SetPoint("CENTER", canvas, "CENTER", 0, -7)
    stats:SetText("|cFF007A0065.0%  Lv.23|r")
    return {}
end

--- Orb: a solid fill clipped to a circle, under the orb's own ring and glass.
function Builders.orb(canvas)
    local size = 38

    local shell = Add(canvas, "BACKGROUND", TEX_SOLID, size, size)
    shell:SetPoint("CENTER")
    shell:SetVertexColor(0.08, 0.08, 0.10, 0.9)

    local fill = Add(canvas, "ARTWORK", TEX_SOLID, size, size * FILL_RATIO)
    fill:SetPoint("BOTTOM", shell, "BOTTOM")

    -- One mask over the orb's full square clips both the shell and the partial
    -- fill to the same circle, which is how OrbBarTemplate gets its shape.
    local mask = canvas:CreateMaskTexture()
    mask:SetTexture(TEX_CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetSize(size, size)
    mask:SetPoint("CENTER")
    shell:AddMaskTexture(mask)
    fill:AddMaskTexture(mask)

    local glass = Add(canvas, "ARTWORK", TEX_ORB_GLASS, size, size)
    glass:SetPoint("CENTER")
    glass:SetDrawLayer("ARTWORK", 2)

    local ring = Add(canvas, "OVERLAY", TEX_ORB_RING, size + 6, size + 6)
    ring:SetPoint("CENTER")
    return {fill}
end

-------------------------------------------------------------------
-- SWATCHES
-------------------------------------------------------------------

---Draw a style's miniature once and remember what to recolour later.
local function RepaintSwatch(swatch)
    if not swatch.__fills then
        return
    end
    local r, g, b = FillColor()
    for _, texture in ipairs(swatch.__fills) do
        texture:SetVertexColor(r, g, b, 1)
    end
end

local function BuildPreview(swatch, styleValue)
    local builder = Builders[styleValue]
    if not builder or swatch.__built then
        return
    end
    swatch.__built = true
    swatch.__fills = builder(swatch.Preview) or {}
    -- Paint immediately: builders leave fills untinted, and a swatch drawn white
    -- for one frame before the first Refresh is a visible flash.
    RepaintSwatch(swatch)
end

local function SetSwatchSelected(swatch, selected)
    for _, edge in ipairs({swatch.RingTop, swatch.RingBottom, swatch.RingLeft, swatch.RingRight}) do
        edge:SetVertexColor(RING_COLOR.r, RING_COLOR.g, RING_COLOR.b, 1)
        edge:SetShown(selected)
    end
    swatch.Caption:SetFontObject(selected and "GameFontNormalSmall" or "GameFontHighlightSmall")
end

-------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------

---Create the swatch grid once. Safe to call again; it rebuilds nothing.
---@param row table The ConfigStyleGalleryTemplate frame
---@param onSelect fun(styleValue: string) Called when a swatch is clicked
function StyleGallery:Build(row, onSelect)
    if not row or not row.Grid or row.__swatches then
        return
    end

    local Config = Addon.Config
    local detail = Config and Config.optionDetails and Config.optionDetails.barStyle
    local options = detail and detail.options
    if not options then
        return
    end

    local swatches = {}
    for index, option in ipairs(options) do
        local column = (index - 1) % COLUMNS
        local rowIndex = math.floor((index - 1) / COLUMNS)

        local swatch = CreateFrame("Button", nil, row.Grid, "ConfigStyleSwatchTemplate")
        swatch:SetPoint(
            "TOPLEFT",
            row.Grid,
            "TOPLEFT",
            column * (CELL_WIDTH + CELL_GAP_X),
            -rowIndex * (CELL_HEIGHT + CELL_GAP_Y)
        )
        swatch.Caption:SetText(option.shortLabel or option.label)
        swatch.styleValue = option.value
        swatch:SetScript("OnClick", function()
            if onSelect then
                onSelect(option.value)
            end
        end)

        BuildPreview(swatch, option.value)
        swatches[#swatches + 1] = swatch
    end

    row.__swatches = swatches

    -- Grow the grid if a ninth style ever appears, so the row does not clip it.
    local rows = math.ceil(#options / COLUMNS)
    row.Grid:SetHeight((rows * CELL_HEIGHT) + ((rows - 1) * CELL_GAP_Y))
end

---Mark the active style and re-apply the configured bar colour.
---@param row table The ConfigStyleGalleryTemplate frame
---@param selectedValue string|nil
function StyleGallery:Refresh(row, selectedValue)
    if not row or not row.__swatches then
        return
    end
    for _, swatch in ipairs(row.__swatches) do
        SetSwatchSelected(swatch, swatch.styleValue == selectedValue)
        RepaintSwatch(swatch)
    end
end
