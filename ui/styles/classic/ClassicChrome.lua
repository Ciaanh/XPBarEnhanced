-- XP Bar Enhanced - Classic Chrome
-- Width, border slicing and segment dividers shared by the Classic primary bar
-- and the Classic secondary bar, so the two stay dimensionally identical while
-- they are anchored to one another.
--
-- Modelled on Blizzard's camelot status bar (Blizzard_StatusTrackingBar):
-- there the container width and the segment count are plain constants, the
-- frame art is never scaled, and dividers are laid out at runtime from
-- `containerWidth / numSegments`. Doing the same here is what makes an
-- arbitrary bar width possible without the end caps smearing.

local Addon = XPBarEnhanced
Addon.UI = Addon.UI or {}

local Chrome = {}
Addon.UI.ClassicChrome = Chrome

-------------------------------------------------------------------
-- ART GEOMETRY
-------------------------------------------------------------------

local BORDER_FILE = "Interface\\AddOns\\XPBarEnhanced\\assets\\legacy-border"
local BACKGROUND_FILE = "Interface\\AddOns\\XPBarEnhanced\\assets\\legacy-background"

-- Both legacy strips are 1024x32.
local SRC_W = 1024

-- The width the templates were authored at. Every derived pixel size below is
-- expressed as a fraction of the source strip times this width, so leaving the
-- new width option at its default reproduces the previous bar exactly.
local DEFAULT_WIDTH = 566
local SRC_SCALE = DEFAULT_WIDTH / SRC_W

Chrome.DEFAULT_WIDTH = DEFAULT_WIDTH
Chrome.MIN_WIDTH = 200
Chrome.MAX_WIDTH = 1400
Chrome.MAX_SEGMENTS = 40

-- legacy-border.tga is not a uniform strip: it carries 10px end caps and nine
-- 8px tick marks spaced 103px apart, which is to say the art has always been a
-- ten-segment bar with its dividers painted in. Slicing it apart lets the caps
-- hold a fixed pixel size at any width and lets the dividers be redrawn at a
-- configurable count instead of the baked nine.
local BORDER_SLICE = {
    file = BORDER_FILE,
    cap = 10,
    -- A tick-free span, so the stretched middle comes out clean.
    midLeft = 110,
    midRight = 195,
}

-- legacy-background.tga is flat translucent black between its ~12px edge fades.
local BACKGROUND_SLICE = {
    file = BACKGROUND_FILE,
    cap = 12,
    midLeft = 40,
    midRight = 900,
}

-- Source span of one baked tick, reused for the generated dividers.
local DIVIDER_SRC_LEFT, DIVIDER_SRC_RIGHT = 97, 105
local DIVIDER_WIDTH = (DIVIDER_SRC_RIGHT - DIVIDER_SRC_LEFT) * SRC_SCALE

-- The XML text containers were authored slightly out of step with the bar
-- itself (571 and 565 against a 566 bar). Carrying those deltas forward keeps
-- on-bar text insets from shifting for players who never touch the width.
Chrome.OVERLAY_TEXT_INSET = 5
Chrome.BELOW_TEXT_INSET = -1

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
    local width = tonumber(ReadOption("classicWidth")) or DEFAULT_WIDTH
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

--- First atlas in `candidates` this client actually has, or nil.
--- Atlas names move between builds, and SetAtlas on a name the client does not
--- know silently blanks the texture rather than erroring, so GetAtlasInfo is
--- the only way to tell a live name from a dead one. Callers pass every name
--- the art has gone by, newest first.
---@param candidates string[]
---@return string|nil atlasName
function Chrome.ResolveAtlas(candidates)
    if type(candidates) ~= "table" then
        return nil
    end
    if not (C_Texture and C_Texture.GetAtlasInfo) then
        return nil
    end
    for _, name in ipairs(candidates) do
        if C_Texture.GetAtlasInfo(name) then
            return name
        end
    end
    return nil
end

-------------------------------------------------------------------
-- THREE-SLICE CHROME
-------------------------------------------------------------------

-- Re-point one stretched texture as a left cap / stretched middle / right cap
-- trio. The original texture becomes the middle so its draw layer, sublevel and
-- vertex color survive untouched; the caps are anchored to the holder's edges
-- and the middle spans between them, so the whole thing re-lays itself out on
-- resize with no further work.
local function SliceTexture(holder, texture, spec)
    if not holder or not texture or not texture.SetTexCoord then
        return false
    end

    local layer, sublevel = texture:GetDrawLayer()
    local capPixels = spec.cap * SRC_SCALE

    local left = holder:CreateTexture(nil, layer, nil, sublevel)
    left:SetTexture(spec.file)
    left:SetTexCoord(0, spec.cap / SRC_W, 0, 1)
    left:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
    left:SetWidth(capPixels)

    local right = holder:CreateTexture(nil, layer, nil, sublevel)
    right:SetTexture(spec.file)
    right:SetTexCoord((SRC_W - spec.cap) / SRC_W, 1, 0, 1)
    right:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(capPixels)

    texture:SetTexCoord(spec.midLeft / SRC_W, spec.midRight / SRC_W, 0, 1)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    texture:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)

    return true
end

--- Convert a frame's background and border art to three-slice. Idempotent.
---@param frame table Frame carrying BackgroundFrame/BorderFrame
---@param borderTextureKey string|nil parentKey of the border texture (default "Texture")
function Chrome.BuildSlicedChrome(frame, borderTextureKey)
    if not frame or frame._xpbeSliced then
        return
    end
    frame._xpbeSliced = true

    local background = frame.BackgroundFrame
    if background and background.Background then
        SliceTexture(background, background.Background, BACKGROUND_SLICE)
    end

    local border = frame.BorderFrame
    if border then
        local texture = border[borderTextureKey or "Texture"]
        if texture then
            SliceTexture(border, texture, BORDER_SLICE)
        end
    end
end

-------------------------------------------------------------------
-- SEGMENT DIVIDERS
-------------------------------------------------------------------

--- Lay out `segments - 1` dividers evenly across the bar, following
--- StatusTrackingBarContainerMixin:UpdateDividers. Dividers keep a fixed pixel
--- width at any bar width, as Blizzard's 3px divider frames do.
---@param frame table Frame carrying BorderFrame
function Chrome.LayoutDividers(frame)
    local holder = frame and frame.BorderFrame
    if not holder then
        return
    end

    local pool = frame._xpbeDividers
    if not pool then
        pool = {}
        frame._xpbeDividers = pool
    end

    local width = frame:GetWidth()
    if not width or width <= 0 then
        width = Chrome.GetWidth()
    end

    local segments = Chrome.GetSegmentCount()
    local needed = (segments > 1) and (segments - 1) or 0
    local segmentWidth = (needed > 0) and (width / segments) or 0

    for i = 1, needed do
        local divider = pool[i]
        if not divider then
            -- Same layer as the border art it replaces, one sublevel up so it
            -- sits on the frame rather than under it.
            divider = holder:CreateTexture(nil, "ARTWORK", nil, 1)
            divider:SetTexture(BORDER_FILE)
            divider:SetTexCoord(DIVIDER_SRC_LEFT / SRC_W, DIVIDER_SRC_RIGHT / SRC_W, 0, 1)
            pool[i] = divider
        end

        local x = segmentWidth * i
        divider:ClearAllPoints()
        divider:SetPoint("TOP", holder, "TOPLEFT", x, 0)
        divider:SetPoint("BOTTOM", holder, "BOTTOMLEFT", x, 0)
        divider:SetWidth(DIVIDER_WIDTH)
        divider:Show()
    end

    for i = needed + 1, #pool do
        pool[i]:Hide()
    end
end

return Chrome
