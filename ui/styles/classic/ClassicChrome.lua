-- XP Bar Enhanced - Classic Chrome
-- Geometry, frame slicing and segment dividers shared by the Classic primary
-- bar and the Classic secondary bar, so the two stay dimensionally identical
-- while they are anchored to one another.
--
-- Modelled on Blizzard's camelot status bar (Blizzard_StatusTrackingBar):
-- there the container width and the segment count are plain constants, the
-- frame art is never scaled, and dividers are laid out at runtime from
-- `containerWidth / numSegments`. Doing the same here is what makes an
-- arbitrary bar width possible without the end caps smearing.
--
-- All art ships with the addon (assets/classic-bar*.tga, built by
-- assets/raw/build_classic_bar.py), so a client art change cannot alter or
-- blank the bar.

local Addon = XPBarEnhanced
Addon.UI = Addon.UI or {}

local Chrome = {}
Addon.UI.ClassicChrome = Chrome

-------------------------------------------------------------------
-- ART
-------------------------------------------------------------------

local SHEET_FILE = "Interface\\AddOns\\XPBarEnhanced\\assets\\classic-bar"
local SHEET_W, SHEET_H = 2048, 64

-- Regions of classic-bar.tga as {x, y, w, h} in sheet pixels. Must match
-- REGIONS in assets/raw/build_classic_bar.py.
local REGIONS = {
    frame = {0, 0, 2042, 28},
    background = {2, 34, 32, 16},
    divider = {48, 32, 10, 16},
    pip = {64, 32, 22, 28},
    pipHighlight = {96, 32, 26, 30},
}

local FRAME_SRC = REGIONS.frame

-- Width of each fixed end cap, in frame source pixels: the whole chamfer plus
-- its inner shadow, so only the uniform rim is ever stretched.
local FRAME_CAP_SRC = 16

-- How far the fill rectangle sits inside the frame, in frame source pixels.
-- Each corner of it lies under fully opaque rim, which is what lets a
-- square-ended fill sit inside the chamfered frame without a pixel showing past
-- it at any width.
local FILL_INSET_X_SRC = 7
local FILL_INSET_Y_SRC = 6

-------------------------------------------------------------------
-- GEOMETRY
-------------------------------------------------------------------

-- Blizzard's camelot bar height. Everything else is derived from it at the
-- art's own aspect ratio, so this is the one number to change.
Chrome.FRAME_HEIGHT = 17

local SCALE = Chrome.FRAME_HEIGHT / FRAME_SRC[4]
local CAP_WIDTH = FRAME_CAP_SRC * SCALE

Chrome.FILL_INSET_X = FILL_INSET_X_SRC * SCALE
Chrome.FILL_HEIGHT = Chrome.FRAME_HEIGHT - 2 * FILL_INSET_Y_SRC * SCALE

-- Blizzard draws its 28px-tall pip at 14px on a 17px bar.
local PIP_HEIGHT = Chrome.FRAME_HEIGHT * 14 / 17
local PIP_WIDTH = PIP_HEIGHT * REGIONS.pip[3] / REGIONS.pip[4]
local PIP_HIGHLIGHT_WIDTH = PIP_WIDTH * REGIONS.pipHighlight[3] / REGIONS.pip[3]
local PIP_HIGHLIGHT_HEIGHT = PIP_HEIGHT * REGIONS.pipHighlight[4] / REGIONS.pip[4]

local DIVIDER_WIDTH = REGIONS.divider[3] * SCALE
local DIVIDER_HEIGHT = REGIONS.divider[4] * SCALE

Chrome.DEFAULT_WIDTH = 566
Chrome.MIN_WIDTH = 200
Chrome.MAX_WIDTH = 1400
Chrome.MAX_SEGMENTS = 40

-- The XML text containers were authored slightly out of step with the bar
-- itself (571 and 565 against a 566 bar). Carrying those deltas forward keeps
-- on-bar text insets from shifting for players who never touch the width.
Chrome.OVERLAY_TEXT_INSET = 5
Chrome.BELOW_TEXT_INSET = -1

--- Point `texture` at one region of the sheet, optionally only the horizontal
--- span [x0, x1) of it (in region pixels).
local function SetRegion(texture, name, x0, x1)
    local region = REGIONS[name]
    local left = region[1] + (x0 or 0)
    local right = region[1] + (x1 or region[3])
    texture:SetTexture(SHEET_FILE)
    texture:SetTexCoord(left / SHEET_W, right / SHEET_W, region[2] / SHEET_H, (region[2] + region[4]) / SHEET_H)
end

-------------------------------------------------------------------
-- CONFIG READS
-------------------------------------------------------------------

local function ReadOption(key)
    if Addon.Config and Addon.Config.GetOptionValue then
        return Addon.Config:GetOptionValue(key)
    end
    local db = Addon.db
    return db and db[key]
end

local function ClampNumber(value, low, high)
    if value < low then
        return low
    end
    if value > high then
        return high
    end
    return value
end

--- Configured Classic bar width in pixels, clamped to a renderable range.
---@return number width
function Chrome.GetWidth()
    local width = tonumber(ReadOption("classicWidth")) or Chrome.DEFAULT_WIDTH
    return math.floor(ClampNumber(width, Chrome.MIN_WIDTH, Chrome.MAX_WIDTH))
end

--- Configured segment count. 0 or 1 means a single unbroken bar.
---@return number segments
function Chrome.GetSegmentCount()
    local segments = tonumber(ReadOption("classicSegments"))
    if not segments then
        segments = 10
    end
    return math.floor(ClampNumber(segments, 0, Chrome.MAX_SEGMENTS))
end

-------------------------------------------------------------------
-- CHROME
-------------------------------------------------------------------

-- Re-point the frame texture as a left cap / stretched middle / right cap
-- trio. The original texture becomes the middle so its draw layer and sublevel
-- survive untouched; the caps are anchored to the holder's edges and the middle
-- spans between them, so the whole thing re-lays itself out on resize.
local function SliceFrame(holder, texture)
    local layer, sublevel = texture:GetDrawLayer()
    local srcWidth = FRAME_SRC[3]

    local left = holder:CreateTexture(nil, layer, nil, sublevel)
    SetRegion(left, "frame", 0, FRAME_CAP_SRC)
    left:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
    left:SetWidth(CAP_WIDTH)

    local right = holder:CreateTexture(nil, layer, nil, sublevel)
    SetRegion(right, "frame", srcWidth - FRAME_CAP_SRC, srcWidth)
    right:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(CAP_WIDTH)

    SetRegion(texture, "frame", FRAME_CAP_SRC, srcWidth - FRAME_CAP_SRC)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    texture:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
end

--- Texture the frame and background of a Classic bar. Idempotent.
--- The background covers exactly the fill rectangle, so it follows `bar`.
---@param frame table Frame carrying BackgroundFrame/BorderFrame
---@param bar table The StatusBar the fill is drawn in
---@param borderTextureKey string|nil parentKey of the border texture (default "Texture")
function Chrome.BuildChrome(frame, bar, borderTextureKey)
    if not frame or frame._xpbeChrome then
        return
    end
    frame._xpbeChrome = true

    local background = frame.BackgroundFrame and frame.BackgroundFrame.Background
    if background then
        SetRegion(background, "background")
        if bar then
            background:ClearAllPoints()
            background:SetAllPoints(bar)
        end
    end

    local border = frame.BorderFrame
    local texture = border and border[borderTextureKey or "Texture"]
    if texture then
        SliceFrame(border, texture)
    end
end

--- Size the frame to the configured width and inset `bar` inside it.
---@param frame table The Classic bar frame
---@param bar table|nil Its StatusBar
---@return number width The frame width applied
function Chrome.LayoutBar(frame, bar)
    local width = Chrome.GetWidth()
    frame:SetSize(width, Chrome.FRAME_HEIGHT)

    if bar and bar.SetSize then
        bar:ClearAllPoints()
        bar:SetPoint("CENTER", frame, "CENTER", 0, 0)
        bar:SetSize(width - 2 * Chrome.FILL_INSET_X, Chrome.FILL_HEIGHT)
    end

    Chrome.LayoutDividers(frame, bar, width)
    return width
end

--- Texture and size the rested pip. Blizzard's pip button is a fixed size, so
--- the highlight is centred on it at its own, slightly larger, footprint.
---@param tick table|nil The ExhaustionTick button
function Chrome.StylePip(tick)
    if not tick or tick._xpbeChrome then
        return
    end
    tick._xpbeChrome = true
    tick:SetSize(PIP_WIDTH, PIP_HEIGHT)

    local normal = tick.GetNormalTexture and tick:GetNormalTexture() or tick.Normal
    if normal then
        SetRegion(normal, "pip")
    end

    local highlight = tick.GetHighlightTexture and tick:GetHighlightTexture() or tick.Highlight
    if highlight then
        SetRegion(highlight, "pipHighlight")
        highlight:ClearAllPoints()
        highlight:SetPoint("CENTER", tick, "CENTER", 0, 0)
        highlight:SetSize(PIP_HIGHLIGHT_WIDTH, PIP_HIGHLIGHT_HEIGHT)
    end
end

-------------------------------------------------------------------
-- SEGMENT DIVIDERS
-------------------------------------------------------------------

--- Lay out `segments - 1` dividers evenly across the fill, following
--- StatusTrackingBarContainerMixin:UpdateDividers. Dividers keep a fixed pixel
--- size at any bar width, as Blizzard's divider frames do, and are measured
--- along the fill rather than the frame so each one marks a true fraction.
---@param frame table Frame carrying BorderFrame
---@param bar table|nil Its StatusBar
---@param width number|nil Frame width (default: configured width)
function Chrome.LayoutDividers(frame, bar, width)
    local holder = frame and frame.BorderFrame
    if not holder then
        return
    end

    local pool = frame._xpbeDividers
    if not pool then
        pool = {}
        frame._xpbeDividers = pool
    end

    local fillWidth = (width or Chrome.GetWidth()) - 2 * Chrome.FILL_INSET_X
    local segments = Chrome.GetSegmentCount()
    local needed = (segments > 1) and (segments - 1) or 0
    local anchor = bar or holder
    local originX = bar and 0 or Chrome.FILL_INSET_X

    for i = 1, needed do
        local divider = pool[i]
        if not divider then
            -- Under the frame art, which sits at sublevel 0 of the same layer,
            -- so the rim stays crisp where a divider meets it.
            divider = holder:CreateTexture(nil, "ARTWORK", nil, -1)
            SetRegion(divider, "divider")
            divider:SetSize(DIVIDER_WIDTH, DIVIDER_HEIGHT)
            pool[i] = divider
        end

        divider:ClearAllPoints()
        divider:SetPoint("CENTER", anchor, "LEFT", originX + fillWidth * i / segments, 0)
        divider:Show()
    end

    for i = needed + 1, #pool do
        pool[i]:Hide()
    end
end

return Chrome
