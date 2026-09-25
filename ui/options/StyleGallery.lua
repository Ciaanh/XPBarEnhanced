-- XP Bar Enhanced - Bar style gallery
--
-- Shows one miniature per bar style in the options panel, so a player can tell
-- Terminal from Orb without applying each style in turn.
--
-- The miniatures are premade: assets/style-previews.tga holds every style's
-- preview, rendered offline from the textures the styles draw by
-- assets/raw/build_style_previews.py. A swatch is at most three textures from
-- that sheet -- the art under the fill, the fill, and the art over it -- and
-- only the fill is tinted, so a preview still follows the configured XP color.
-- Re-run the script after changing a style's art.
--
-- The grid is derived from Config.optionDetails.barStyle.options: adding a style
-- to that list adds a swatch here, and only its preview cells have to follow.
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

-- The selection ring is the addon's own default xpBar purple rather than
-- Blizzard's selection blue, so a selected swatch reads as "XP Bar Enhanced".
local RING_COLOR = {r = 0.58, g = 0.0, b = 0.55}

-------------------------------------------------------------------
-- PREVIEW SHEET
-------------------------------------------------------------------

local PREVIEW_SHEET = "Interface\\AddOns\\XPBarEnhanced\\assets\\style-previews"
local SHEET_WIDTH, SHEET_HEIGHT = 2048, 256

-- One cell is the 112x52 swatch canvas at 2x, packed left to right.
local PREVIEW_CELL_WIDTH, PREVIEW_CELL_HEIGHT = 224, 104
local PREVIEW_COLUMNS = math.floor(SHEET_WIDTH / PREVIEW_CELL_WIDTH)

-- Cell index of each layer, as printed by build_style_previews.py.
local PREVIEW_CELLS = {
    none = {under = 0},
    classic = {under = 1, fill = 2, over = 3},
    flat = {under = 4, fill = 5},
    vertical = {under = 6, fill = 7},
    circular = {under = 8, fill = 9, over = 10},
    minimap_ring = {under = 11, fill = 12},
    terminal = {under = 13},
    orb = {under = 14, fill = 15, over = 16},
}

local PREVIEW_LAYERS = {
    {key = "under", drawLayer = "BACKGROUND"},
    {key = "fill", drawLayer = "ARTWORK"},
    {key = "over", drawLayer = "OVERLAY"},
}

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

---A texture covering the whole preview canvas, showing one sheet cell.
local function AddPreviewLayer(canvas, drawLayer, cellIndex)
    local column = cellIndex % PREVIEW_COLUMNS
    local row = math.floor(cellIndex / PREVIEW_COLUMNS)
    local left = column * PREVIEW_CELL_WIDTH
    local top = row * PREVIEW_CELL_HEIGHT

    local texture = canvas:CreateTexture(nil, drawLayer)
    texture:SetAllPoints(canvas)
    texture:SetTexture(PREVIEW_SHEET)
    texture:SetTexCoord(
        left / SHEET_WIDTH,
        (left + PREVIEW_CELL_WIDTH) / SHEET_WIDTH,
        top / SHEET_HEIGHT,
        (top + PREVIEW_CELL_HEIGHT) / SHEET_HEIGHT
    )
    return texture
end

-------------------------------------------------------------------
-- SWATCHES
-------------------------------------------------------------------

---Re-apply the configured colour to a swatch's fill.
local function RepaintSwatch(swatch)
    if not swatch.__fills then
        return
    end
    local r, g, b = FillColor()
    for _, element in ipairs(swatch.__fills) do
        element:SetVertexColor(r, g, b, 1)
    end
end

local function BuildPreview(swatch, styleValue)
    local cells = PREVIEW_CELLS[styleValue]
    if not cells or swatch.__built then
        return
    end
    swatch.__built = true
    swatch.__fills = {}
    for _, layer in ipairs(PREVIEW_LAYERS) do
        local cellIndex = cells[layer.key]
        if cellIndex then
            local texture = AddPreviewLayer(swatch.Preview, layer.drawLayer, cellIndex)
            if layer.key == "fill" then
                swatch.__fills[#swatch.__fills + 1] = texture
            end
        end
    end
    -- Paint immediately: the fill cell is untinted, and a swatch drawn white
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

    -- Size the grid AND the row from the swatch count. The template declares a
    -- fixed two-row height (ConfigStyleGalleryTemplate, y=198) and the options
    -- rows stack by layoutIndex from the ROW's height, so a grid that outgrows
    -- the template without the row growing too paints over the rows below it.
    local rows = math.ceil(#options / COLUMNS)
    local gridHeight = (rows * CELL_HEIGHT) + ((rows - 1) * CELL_GAP_Y)
    local headerBand = row:GetHeight() - row.Grid:GetHeight() -- label strip above the grid
    row.Grid:SetHeight(gridHeight)
    row:SetHeight(gridHeight + headerBand)

    local layoutParent = row:GetParent()
    if layoutParent and layoutParent.MarkDirty then
        layoutParent:MarkDirty()
    end
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
