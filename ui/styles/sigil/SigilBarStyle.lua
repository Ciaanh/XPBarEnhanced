-- XP Bar Enhanced - Sigil Style
-- A tiered class ring. Progress is a clockwise ARC: paused Cooldown frames
-- sweep an annulus channel from the crest's left edge around to its right,
-- the crest plate covering the seam (Amendment A -- the League reference fills
-- radially, and the first release's orb-style liquid fill misread it). The
-- StatusBar survives as an alpha-0 data carrier so animation, flash, colours,
-- tooltips and the max-level repurpose still arrive from the mixins unchanged;
-- the terminal style ships the same trick. The overlay arcs reuse the orb's
-- cumulative-extent layering -- each band is a full sweep from zero, drawn
-- underneath the layers above it, so only its sliver shows.
-- What Sigil adds on top is three repaintable skin layers driven by SigilSkins.

-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

if not XPBarStyleBuilder or not XPBarMixinBase then
    error(
        "SigilBarStyle: core (StyleBuilder/BaseMixin) not loaded. Ensure ui/xpbars core files are earlier in the .toc."
    )
end

local Addon = XPBarEnhanced

local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- Procedural halo art, all of it already shipped and already tinted at runtime
-- by other styles. The halo therefore costs zero new files.
local TEX_RING = "Interface\\AddOns\\XPBarEnhanced\\assets\\border"
local TEX_MARK = "Interface\\AddOns\\XPBarEnhanced\\assets\\xp-bar"
local TEX_BLOOM = "Interface\\AddOns\\XPBarEnhanced\\assets\\glow"

-- Ring diameter at the medium preset. The frame is this plus CREST_OVERHANG
-- tall, because the crest hangs below the circle and the mouse hit area has to
-- reach it.
local BASE_RING_SIZE = 128
local CREST_OVERHANG = 24
local CREST_SIZE = 44

-- Modelled on circular's CIRCULAR_SIZE_SCALES, not on the orb: the orb has no
-- size preset at all, just a file-local constant. These land on the design's
-- 96 / 128 / 176 / 224 ring diameters.
local SIGIL_SIZE_SCALES = {
    small = 0.75,
    medium = 1.0,
    large = 1.375,
    huge = 1.75,
}

-- Text row offsets from the RING centre at scale 1.0.
local TEXT_ROWS = {
    {key = "LevelText", y = 15},
    {key = "PercentText", y = -4},
    {key = "RateText", y = -22},
}

-- The XP arc. sigil-fill is the annulus the swipe reveals; the recessed track
-- under it is declared in XML. ARC_ROTATION puts the sweep origin at 6 o'clock
-- (the crest), and the crest plate covers the start/end seam, so no arc-span
-- math is needed. Direction note: the reversed swipe is expected to grow
-- clockwise, matching every native cooldown wipe -- if in-game validation shows
-- otherwise, this constant and the layering are the only things to revisit.
local TEX_ARC_FILL = "Interface\\AddOns\\XPBarEnhanced\\assets\\sigil-fill"
local ARC_ROTATION = math.pi
local ARC_DURATION = 100 -- arbitrary; the paused fraction is what displays

-- Bottom-up draw order. Each arc sweeps its CUMULATIVE fraction from zero and
-- the layers above cover the shared prefix, so only each band's sliver shows.
local ARC_LAYERS = {"ArcRested", "ArcQuestIncomplete", "ArcQuestComplete", "ArcFill"}

-- Halo geometry, as fractions of the ring diameter.
local HALO_ARC_RADII = {0.43, 0.37, 0.31}
local HALO_ARC_ALPHAS = {0.95, 0.55, 0.35}
local HALO_TICK_RADIUS = 0.47
local HALO_TICK_WIDTH = 2.5
local HALO_TICK_HEIGHT = 7
local HALO_MAX_ARCS = #HALO_ARC_RADII
local HALO_MAX_TICKS = 24

-------------------------------------------------------------------
-- STYLE TEMPLATE
-------------------------------------------------------------------

local SigilBarStyleTemplate = {}

local function GetSkins()
    return Addon.SigilSkins
end

local function GetOption(key, default)
    local Config = Addon.Config
    if Config and Config.GetOptionValue then
        local value = Config:GetOptionValue(key)
        if value ~= nil then
            return value
        end
    end
    return default
end

-------------------------------------------------------------------
-- GEOMETRY
-------------------------------------------------------------------

--- Configured scale factor for the ring.
function SigilBarStyleTemplate:GetSigilScale()
    local size = GetOption("sigilSize", "medium")
    if type(size) ~= "string" or not SIGIL_SIZE_SCALES[size] then
        size = "medium"
    end
    return SIGIL_SIZE_SCALES[size], size
end

--- Current ring diameter in pixels. Every circular element is sized from this,
--- never from the frame height -- the frame is taller than the ring.
function SigilBarStyleTemplate:GetRingSize()
    return self._ringSize or BASE_RING_SIZE
end

--- Resize the frame and re-anchor every element that must track the ring.
--- Idempotent: safe to call from OnLoad and from an options live-apply.
function SigilBarStyleTemplate:ApplySizePreset()
    -- Never resize a frame the player currently has hold of: SetSize during a
    -- drag fights StartMoving and the frame jumps out from under the cursor.
    -- The deferred flag is picked up by the next call, and OnMouseUp's
    -- SavePosition path is followed by a Refresh, so nothing is lost.
    if self.__isDragging then
        self._sizePresetDeferred = true
        return
    end
    self._sizePresetDeferred = nil

    local scale, sizeKey = self:GetSigilScale()
    local ring = BASE_RING_SIZE * scale
    local overhang = CREST_OVERHANG * scale

    self._ringSize = ring
    self._sigilScale = scale
    self._sigilSizeKey = sizeKey

    self:SetSize(ring, ring + overhang)

    -- The ring square sits at the TOP of the frame, so its centre is overhang/2
    -- above the frame centre. Everything optically "in the ring" uses this.
    self._ringCenterOffset = overhang / 2

    local function sizeToRing(texture)
        if texture then
            texture:SetSize(ring, ring)
            texture:ClearAllPoints()
            texture:SetPoint("TOP", self, "TOP", 0, 0)
        end
    end

    sizeToRing(self.Cavity)
    sizeToRing(self.CircleMask)
    sizeToRing(self.ArcTrack)
    sizeToRing(self.GainFlash)

    if self.StatusBar then
        self.StatusBar:SetSize(ring, ring)
        self.StatusBar:ClearAllPoints()
        self.StatusBar:SetPoint("TOP", self, "TOP", 0, 0)
    end

    -- The arc Cooldowns track the ring square exactly like the textures do.
    self:EnsureArcFrames()
    for _, key in ipairs(ARC_LAYERS) do
        local arc = self[key]
        if arc then
            arc:SetSize(ring, ring)
            arc:ClearAllPoints()
            arc:SetPoint("TOP", self, "TOP", 0, 0)
        end
    end

    sizeToRing(self.SkinFrame)

    if self.Crest then
        local crest = CREST_SIZE * scale
        self.Crest:SetSize(crest, crest)
        self.Crest:ClearAllPoints()
        self.Crest:SetPoint("BOTTOM", self, "BOTTOM", 0, 0)
    end

    self:LayoutHaloPool()
    self:UpdateCenterTextScale()

    -- Geometry changed: the next paint must not short-circuit on an unchanged
    -- tier, or the halo would keep the old radii.
    self._skinGeometryToken = nil
end

--- Scale the centre readout with the ring and keep it centred on the RING,
--- not on the taller frame. Modelled on CircularBarStyle:UpdateCenterTextScale.
function SigilBarStyleTemplate:UpdateCenterTextScale()
    local scale = self._sigilScale or 1.0
    local ringOffset = self._ringCenterOffset or 0

    for _, row in ipairs(TEXT_ROWS) do
        local element = self[row.key]
        if element then
            if not element._baseFontFile then
                local fontFile, fontSize, fontFlags = element:GetFont()
                element._baseFontFile = fontFile
                element._baseFontSize = fontSize
                element._baseFontFlags = fontFlags or ""
            end
            if element._baseFontFile then
                element:SetFont(element._baseFontFile, element._baseFontSize * scale, element._baseFontFlags)
            end
            element:ClearAllPoints()
            element:SetPoint("CENTER", self, "CENTER", 0, ringOffset + (row.y * scale))
        end
    end
end

-------------------------------------------------------------------
-- ARC FRAMES
-- One paused Cooldown per band. Created once, configured once; per-frame work
-- while animating is a single SetCooldown+Pause on the fill arc.
-------------------------------------------------------------------

--- Create (once) the four arc Cooldown frames, bottom-up so frame levels give
--- the cumulative-extent layering its draw order. Idempotent.
function SigilBarStyleTemplate:EnsureArcFrames()
    if self.ArcFill then
        return
    end

    local baseLevel = (self.StatusBar and self.StatusBar:GetFrameLevel() or self:GetFrameLevel()) + 1

    for index, key in ipairs(ARC_LAYERS) do
        local arc = CreateFrame("Cooldown", nil, self, "CooldownFrameTemplate")
        arc:SetFrameLevel(baseLevel + index)
        arc:EnableMouse(false)
        arc:SetReverse(true)
        arc:SetSwipeTexture(TEX_ARC_FILL)
        arc:SetDrawEdge(false)
        arc:SetDrawBling(false)
        arc:SetHideCountdownNumbers(true)
        -- Sweep origin at 6 o'clock -- the crest -- so the arc emerges at its
        -- left edge and completes at its right, the plate covering the seam.
        if arc.SetRotation then
            arc:SetRotation(ARC_ROTATION)
        end
        self[key] = arc
    end
end

--- Freeze an arc at a fraction of the full sweep. The standard paused-cooldown
--- idiom: elapsed/duration is the displayed fraction, and Pause holds it.
---@param arc table|nil The Cooldown frame
---@param fraction number Progress in [0, 1]
function SigilBarStyleTemplate:SetArcProgress(arc, fraction)
    if not arc then
        return
    end

    fraction = math.min(math.max(fraction or 0, 0), 1)
    if fraction <= 0.0001 then
        arc:Clear()
        arc:Hide()
        return
    end

    arc:Show()
    arc:SetCooldown(GetTime() - fraction * ARC_DURATION, ARC_DURATION)
    arc:Pause()
end

-------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------

function SigilBarStyleTemplate:OnLoad()
    -- Text FontStrings and skin textures live on the overlay container; alias
    -- them onto the bar frame, where TextMixin and the paint methods expect them.
    local container = self.OverlayFrameTextContainer
    if container then
        self.LevelText = self.LevelText or container.LevelText
        self.PercentText = self.PercentText or container.PercentText
        self.RateText = self.RateText or container.RateText
        self.SkinFrame = self.SkinFrame or container.SkinFrame
        self.Crest = self.Crest or container.Crest
    end

    self:ApplySizePreset()

    -- The StatusBar is a data carrier only: the mixins keep reading and writing
    -- its value, but the arc frames render the visual. Hide it at FRAME level,
    -- exactly as the terminal style does -- texture-level SetAlpha(0) does not
    -- survive, because SetStatusBarColor writes the fill texture's vertex alpha
    -- back to 1 on every recolour (this shipped as a visible bug: the old
    -- liquid fill resurrected as an unmasked square behind the ring).
    if self.StatusBar then
        self.StatusBar:SetAlpha(0)

        local fillMask = self.StatusBar:CreateMaskTexture()
        fillMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        fillMask:SetAllPoints(self.StatusBar)
        -- Kept for the celebration glow (GetCelebrationMask) and the ascend
        -- flash, both of which are runtime-created and still need round clipping.
        self._fillMask = fillMask
    end

    self:ApplySkin()

    if XPBarMixinBase and XPBarMixinBase.OnLoad then
        XPBarMixinBase.OnLoad(self)
    end
end

--- Clip runtime-created effect textures (the celebration glow) to the ring.
--- Without this the glow AnimationManager creates pulses as a rectangle.
function SigilBarStyleTemplate:GetCelebrationMask()
    return self._fillMask
end

-------------------------------------------------------------------
-- HALO POOL (procedural skin)
-- Frames are cached per style and never destroyed, so these pools are created
-- once for the addon's lifetime -- never per skin and never per tier.
-------------------------------------------------------------------

function SigilBarStyleTemplate:EnsureHaloPool()
    if self._haloArcs then
        return
    end

    local container = self.OverlayFrameTextContainer or self

    self._haloArcs = {}
    for i = 1, HALO_MAX_ARCS do
        local arc = container:CreateTexture(nil, "BACKGROUND", nil, 1)
        arc:SetTexture(TEX_RING)
        arc:Hide()
        self._haloArcs[i] = arc
    end

    self._haloTicks = {}
    for i = 1, HALO_MAX_TICKS do
        local tick = container:CreateTexture(nil, "BACKGROUND", nil, 2)
        tick:SetTexture(TEX_MARK)
        tick:Hide()
        self._haloTicks[i] = tick
    end

    local bloom = container:CreateTexture(nil, "BACKGROUND", nil, 0)
    bloom:SetTexture(TEX_BLOOM)
    bloom:Hide()
    self._haloBloom = bloom

    self:LayoutHaloPool()
end

--- Place the pooled halo textures for the current ring size. Positions only --
--- visibility and colour are the paint step's business.
function SigilBarStyleTemplate:LayoutHaloPool()
    if not self._haloArcs then
        return
    end

    local ring = self:GetRingSize()
    local scale = self._sigilScale or 1.0
    local top = self

    for i, arc in ipairs(self._haloArcs) do
        local diameter = ring * HALO_ARC_RADII[i] * 2
        arc:SetSize(diameter, diameter)
        arc:ClearAllPoints()
        arc:SetPoint("TOP", top, "TOP", 0, -(ring - diameter) / 2)
    end

    -- Ticks run clockwise from 6 o'clock, the same placement circular uses, so
    -- the two round styles read as the same family.
    local radius = ring * HALO_TICK_RADIUS
    local startAngle = math.pi / 2
    local clockwise = -1
    local ringCenterY = self._ringCenterOffset or 0

    for i, tick in ipairs(self._haloTicks) do
        local angle = startAngle + ((i - 1) / HALO_MAX_TICKS) * (2 * math.pi)
        tick:SetSize(HALO_TICK_WIDTH * scale, HALO_TICK_HEIGHT * scale)
        tick:ClearAllPoints()
        tick:SetPoint(
            "CENTER",
            top,
            "CENTER",
            math.cos(angle) * radius,
            ringCenterY + math.sin(angle) * radius * clockwise
        )
        if tick.SetRotation then
            tick:SetRotation((clockwise * angle) + startAngle)
        end
    end

    if self._haloBloom then
        local diameter = ring * 1.35
        self._haloBloom:SetSize(diameter, diameter)
        self._haloBloom:ClearAllPoints()
        self._haloBloom:SetPoint("CENTER", top, "CENTER", 0, ringCenterY)
    end
end

function SigilBarStyleTemplate:HideHalo()
    if not self._haloArcs then
        return
    end
    for _, arc in ipairs(self._haloArcs) do
        arc:Hide()
    end
    for _, tick in ipairs(self._haloTicks) do
        tick:Hide()
    end
    if self._haloBloom then
        self._haloBloom:Hide()
    end
end

-------------------------------------------------------------------
-- PAINT
-------------------------------------------------------------------

--- Procedural band for the HALO skin only: concentric arcs, outer ticks, and a
--- bloom, all driven by the layer table. The flagship paints no band at all --
--- the per-class rune band was removed 2026-08-16 (two rings of repeated marks
--- read as noise, and the reference carries tier escalation on the frame
--- itself), so on the flagship this only retires whatever the halo left behind.
function SigilBarStyleTemplate:PaintBand(skin, layer, accent)
    if not skin or not layer or not skin.procedural then
        self:HideHalo()
        return
    end

    self:EnsureHaloPool()

    local arcs = layer.arcs or 0
    for i, arc in ipairs(self._haloArcs) do
        if i <= arcs then
            arc:SetVertexColor(accent.r, accent.g, accent.b, HALO_ARC_ALPHAS[i] or 0.4)
            arc:Show()
        else
            arc:Hide()
        end
    end

    local ticks = layer.ticks or 0
    for i, tick in ipairs(self._haloTicks) do
        if i <= ticks then
            tick:SetVertexColor(accent.r, accent.g, accent.b, 0.85)
            tick:Show()
        else
            tick:Hide()
        end
    end

    if self._haloBloom then
        local bloom = layer.bloom
        if bloom and bloom > 0 then
            self._haloBloom:SetVertexColor(accent.r, accent.g, accent.b, bloom)
            self._haloBloom:Show()
        else
            self._haloBloom:Hide()
        end
    end
end

--- The casing. Procedural skins have none: their arcs are the frame.
function SigilBarStyleTemplate:PaintFrame(skin, layer, accent, tier, classToken)
    if not self.SkinFrame then
        return
    end

    if not skin or skin.procedural or not layer or not layer.texture then
        self.SkinFrame:Hide()
        return
    end

    -- Family-themed casing when the class resolves to one (2026-08-16); the
    -- neutral casing the layer carries is the fallback, so an unknown class
    -- token still draws a frame.
    local Skins = GetSkins()
    local themed = Skins and Skins.GetCasingTexture
        and Skins:GetCasingTexture(skin, tier, classToken)
    self.SkinFrame:SetTexture(themed or layer.texture)
    self.SkinFrame:SetVertexColor(accent.r, accent.g, accent.b, 1)
    self.SkinFrame:Show()
end

--- The class mark. Hidden when the skin declares none, or when the class token
--- is unknown -- the casing is class-agnostic, so the ring still reads.
function SigilBarStyleTemplate:PaintCrest(skin, accent)
    if not self.Crest then
        return
    end

    local Skins = GetSkins()
    local _, classToken = UnitClass("player")
    local path = Skins and Skins:GetCrestTexture(skin, classToken)
    if not path then
        self.Crest:Hide()
        return
    end

    self.Crest:SetTexture(path)
    self.Crest:SetVertexColor(accent.r, accent.g, accent.b, 1)
    self.Crest:Show()
end

--- Is the bar tracking XP right now?
---
--- `context._secondaryMode` is the authoritative per-render signal and is
--- preferred whenever a context is in hand. `ShouldRepurposePrimaryAtMaxLevel`
--- is a five-condition predicate answering a differently-shaped question, so
--- re-deriving the decision from it is how the two drift apart; it is only used
--- where no context exists yet (OnLoad, an options live-apply).
---@param context table|nil
---@return boolean isXPMode
function SigilBarStyleTemplate:IsXPMode(context)
    if context ~= nil then
        return not context._secondaryMode
    end
    local manager = Addon.BarManager
    if manager and manager.ShouldRepurposePrimaryAtMaxLevel then
        return not manager:ShouldRepurposePrimaryAtMaxLevel()
    end
    return true
end

--- Repaint SkinFrame / Crest (and the halo pool) for the current (class, tier, skin).
--- Cheap and idempotent: safe from OnLoad, from an options live-apply, and from
--- the render path.
---@param context table|nil
function SigilBarStyleTemplate:ApplySkin(context)
    local Skins = GetSkins()
    if not Skins or not Skins.Resolve then
        return
    end

    local _, classToken = UnitClass("player")
    local tier, skin, layer, accent = Skins:Resolve(
        self:GetEffectiveLevel(),
        GetMaxPlayerLevel and GetMaxPlayerLevel() or 0,
        GetOption("sigilSkin", "sigil"),
        classToken,
        self:IsXPMode(context)
    )

    self._tier = tier
    self._skinId = skin and skin.id
    self._skinMode = self:IsXPMode(context) and "xp" or "halo"
    self._accent = accent

    self:PaintBand(skin, layer, accent)
    self:PaintFrame(skin, layer, accent, tier, classToken)
    self:PaintCrest(skin, accent)
end

--- The level the tier is resolved from. `sigilTierMode = pinned` lets a capped
--- player keep an earlier frame; arithmetic stays on LEVEL, never on XP, because
--- UnitXP results are secret values in 12.0 and cannot be compared or divided.
function SigilBarStyleTemplate:GetEffectiveLevel()
    if GetOption("sigilTierMode", "auto") == "pinned" then
        local Skins = GetSkins()
        local maxTier = (Skins and Skins.MAX_TIER) or 4
        local pinned = tonumber(GetOption("sigilPinnedTier", 1)) or 1
        pinned = math.max(1, math.min(maxTier, math.floor(pinned)))

        -- Express the pinned tier as a level the resolver will bucket the same
        -- way, so pinning needs no second code path in SigilSkins.
        local cap = tonumber(GetMaxPlayerLevel and GetMaxPlayerLevel()) or 0
        if cap > 0 and Skins and Skins.TIER_FRACTIONS then
            local frac = Skins.TIER_FRACTIONS[pinned] or 0
            -- +1 keeps the result inside the pinned band rather than on the
            -- boundary below it after flooring.
            return math.min(cap, math.floor(cap * frac) + 1)
        end
        return 1
    end

    return UnitLevel("player") or 1
end

-------------------------------------------------------------------
-- RENDER
-------------------------------------------------------------------

--- Detect a mode or tier change on the render path, where a context exists.
---
--- This is where the skin decision has to live. OnLoad, the options live-apply
--- and the level-up hook all call ApplySkin() bare, so a context-only branch
--- would be unreachable from them -- and nothing in BarManager re-applies the
--- skin when the repurpose state flips mid-session (RefreshMaxLevelRepurpose
--- re-drives SetStyle to a broadcast, which lands here). A watched faction whose
--- data loads seconds after login flips _secondaryMode on a later broadcast, and
--- this check is what catches it.
-------------------------------------------------------------------
-- FILL DRIVER
-- UpdateGainedBar is the single per-frame fill path -- DisplayMixin's static
-- render and AnimationBase:AnimateBarPosition both come through here -- so
-- driving the arc from it covers events and animation ticks alike.
-------------------------------------------------------------------

function SigilBarStyleTemplate:UpdateGainedBar(currentRatio, context)
    if self.StatusBar and currentRatio then
        -- Data carrier only; the texture is alpha-0.
        self.StatusBar:SetValue(currentRatio)
    end
    if self.SetCurrentRatio then
        self:SetCurrentRatio(currentRatio)
    end

    self:SetArcProgress(self.ArcFill, currentRatio)

    if self.UpdateBarColors then
        self:UpdateBarColors(context)
    end
end

--- Tint the fill arc with the same colour selection PaintMixin applies to a
--- visible StatusBar: the max-level secondary colour when repurposed, else the
--- rested-aware XP colour. Deliberately does NOT call the PaintMixin base --
--- the carrier bar is hidden at frame level and needs no tint, and terminal
--- stubs its UpdateBarColors for the same reason.
function SigilBarStyleTemplate:UpdateBarColors(context)
    if not self.ArcFill then
        return
    end

    local color = context and context._secondaryColor
    if not color then
        local hasRestedXP = context and (context.hasRestedXP or (context.restedXP and context.restedXP > 0))
        local colorKey = hasRestedXP and Addon.Colors.Key.XpBarRested or Addon.Colors.Key.XpBar
        color = Addon.Colors:Get(colorKey)
    end
    if color then
        self.ArcFill:SetSwipeColor(color.r, color.g, color.b, color.a or 1)
    end
end

function SigilBarStyleTemplate:RenderBar(context)
    if not context then
        error("RenderBar requires an explicit immutable context")
    end

    -- A size change deferred during a drag lands here, at the first render after
    -- the player let go.
    if self._sizePresetDeferred then
        self:ApplySizePreset()
    end

    local mode = context._secondaryMode and "halo" or "xp"
    local Skins = GetSkins()
    local tier = Skins and Skins.ResolveTier
        and Skins:ResolveTier(self:GetEffectiveLevel(), GetMaxPlayerLevel and GetMaxPlayerLevel() or 0)
        or self._tier
    local skinId = GetOption("sigilSkin", "sigil")

    if mode ~= self._skinMode
        or tier ~= self._resolvedFromTier
        or skinId ~= self._configuredSkinId
        or self._skinGeometryToken == nil then
        self._resolvedFromTier = tier
        self._configuredSkinId = skinId
        self._skinGeometryToken = true
        self:ApplySkin(context)
    end

    XPBarDisplayMixin.RenderBar(self, context)
end

-------------------------------------------------------------------
-- TIER ASCEND
-- The tier SWAP and the tier ASCEND ANIMATION are two different things with two
-- different triggers, and the swap must not be gated on the celebration path:
-- BarManager:TriggerStyleCelebration returns early when enableAnimations is off,
-- so a swap living only in OnLevelUpCelebration would strand an animations-off
-- player on stale tier art until a /reload. The swap therefore rides RenderBar
-- above -- PLAYER_LEVEL_UP reaches the bar as a broadcast, RenderBar sees the
-- new tier, ApplySkin repaints -- and only the animation lives here.
-------------------------------------------------------------------

-- Ascend timings, in the order they play.
local ASCEND_SEQUENCE = {
    {phase = "fadeOut", duration = 0.25},
    {phase = "scaleIn", duration = 0.35},
    {phase = "pulse", duration = 0.30},
    {phase = "settle", duration = 0.20},
}

--- Build (once) the pooled texture and AnimationGroup the ascend plays on.
--- A native AnimationGroup, no OnUpdate, and one allocation per bar for the
--- addon's lifetime -- the same construction PlayLevelUpCelebration uses.
function SigilBarStyleTemplate:EnsureAscendAnimation()
    if self._ascendGroup then
        return self._ascendGroup
    end

    local container = self.OverlayFrameTextContainer or self
    local flash = container:CreateTexture(nil, "OVERLAY", nil, 6)
    flash:SetTexture(TEX_BLOOM)
    flash:SetBlendMode("ADD")
    flash:SetAlpha(0)
    if self._fillMask and flash.AddMaskTexture then
        -- Clipped like the celebration glow, or the accent flash reads as a
        -- square over a round bar.
        flash:AddMaskTexture(self._fillMask)
    end
    self._ascendFlash = flash

    local group = flash:CreateAnimationGroup()
    local order = 0

    for _, step in ipairs(ASCEND_SEQUENCE) do
        order = order + 1
        local anim = group:CreateAnimation("Alpha")
        anim:SetOrder(order)
        anim:SetDuration(step.duration)
        if step.phase == "fadeOut" then
            anim:SetFromAlpha(0)
            anim:SetToAlpha(0.15)
        elseif step.phase == "scaleIn" then
            anim:SetFromAlpha(0.15)
            anim:SetToAlpha(0.85)
        elseif step.phase == "pulse" then
            anim:SetFromAlpha(0.85)
            anim:SetToAlpha(0.45)
        else
            anim:SetFromAlpha(0.45)
            anim:SetToAlpha(0)
        end
    end

    -- The casing scales in from 1.15x during the scaleIn phase. Order 2 and the
    -- same duration as that phase's Alpha on purpose: animations sharing an order
    -- run in parallel and the group only advances once the LONGEST of them
    -- finishes, so a longer Scale here would stall the phases after it and
    -- stretch the whole sequence.
    local scaleIn = group:CreateAnimation("Scale")
    scaleIn:SetOrder(2)
    scaleIn:SetDuration(ASCEND_SEQUENCE[2].duration)
    if scaleIn.SetScaleFrom then
        scaleIn:SetScaleFrom(1.15, 1.15)
        scaleIn:SetScaleTo(1.0, 1.0)
    end

    group:SetScript("OnFinished", function()
        flash:SetAlpha(0)
        flash:Hide()
    end)

    self._ascendGroup = group
    return group
end

--- Play the tier-ascend flourish. Animation only: the art has already been
--- swapped by the time this runs.
function SigilBarStyleTemplate:PlayTierAscend()
    local group = self:EnsureAscendAnimation()
    if not group or not self._ascendFlash then
        return
    end

    local ring = self:GetRingSize()
    local accent = self._accent or {r = 1, g = 0.82, b = 0.1}

    self._ascendFlash:SetSize(ring, ring)
    self._ascendFlash:ClearAllPoints()
    self._ascendFlash:SetPoint("TOP", self, "TOP", 0, 0)
    self._ascendFlash:SetVertexColor(accent.r, accent.g, accent.b, 1)
    self._ascendFlash:Show()

    group:Stop()
    group:Play()
end

--- The only ANIMATION trigger. The swap itself rides RenderBar, so this compares
--- the tier now against the tier at the previous celebration and delegates to
--- the shared celebration when nothing changed. No poller anywhere.
function SigilBarStyleTemplate:OnLevelUpCelebration()
    local previousTier = self._celebratedTier
    self:ApplySkin()
    self._celebratedTier = self._tier

    -- Nothing to flourish over on the first celebration of a session either:
    -- previousTier is nil, and treating that as a change would fire an ascend
    -- for a tier the player did not just cross.
    if previousTier and self._tier ~= previousTier and self:IsShown() then
        self:PlayTierAscend()
        return
    end

    if XPBarMixinBase and XPBarMixinBase.OnLevelUpCelebration then
        XPBarMixinBase.OnLevelUpCelebration(self)
    end
end

--- Preview the ascend without levelling. Preview-only: it must not touch the
--- persisted tier state, so _tier and _celebratedTier are left exactly as found.
function SigilBarStyleTemplate:PreviewTierAscend()
    if not self:IsShown() then
        return false
    end
    self:PlayTierAscend()
    return true
end

-------------------------------------------------------------------
-- TEXT OVERRIDES (centred inside the ring)
-------------------------------------------------------------------

function SigilBarStyleTemplate:UpdateLevelText(context)
    if not self.LevelText then
        return
    end
    if context and context.showLevelText == false then
        self.LevelText:Hide()
        return
    end

    -- Max-level repurpose: the ring is too small for a full standing label
    -- ("Honor Level 29"), so show the bare numeric level when the source has
    -- one. The tooltip carries the full context.
    if context and context.levelTextOverride and context.levelTextOverride ~= "" then
        local numericLevel = tonumber(context.level)
        if numericLevel and numericLevel > 0 then
            self.LevelText:SetText(tostring(numericLevel))
        else
            self.LevelText:SetText(context.levelTextOverride)
        end
        return
    end

    local level = (context and context.level) or UnitLevel("player")
    self.LevelText:SetText(tostring(level))
end

function SigilBarStyleTemplate:UpdatePercentText(context)
    if not self.PercentText then
        return
    end

    local currentXP = (context and context.currentXP) or 0
    local maxXP = (context and context.xpMax) or 1
    local decimals = (context and context.percentDecimals) or GetOption("percentDecimals", 1)

    local percent = (maxXP > 0) and (currentXP / maxXP * 100) or 0
    local text = string.format("%." .. decimals .. "f%%", percent)
    if text ~= self._lastPercentText then
        self._lastPercentText = text
        self.PercentText:SetText(text)
    end
end

function SigilBarStyleTemplate:UpdateRateText(context)
    if not self.RateText or not Addon.TextFormatter then
        return
    end

    if not Addon.ConfigHelper.GetShowTimeToLevelText(context) then
        self.RateText:SetText("")
        return
    end

    -- Same source order as circular: the context value, then the Session
    -- service, so a text-refresh tick with a lightweight context still resolves.
    local timeToLevel =
        (context and context.timeToLevel) or
        (Addon.Session and Addon.Session.GetTimeToLevel and Addon.Session:GetTimeToLevel()) or
        0

    if timeToLevel > 0 then
        self.RateText:SetText(Addon.TextFormatter:GetTimeToLevelText(timeToLevel))
    else
        self.RateText:SetText("")
    end
end

--- Centre text is the ring's primary display, so it is not gated by Blizzard's
--- xpBarText CVar.
---
--- At the SMALL preset the channel assembly (whose inner rim reaches radius
--- 0.23 of the ring) eats the radius the readout needs and the level and
--- percentage will not both fit, so the percentage row is suppressed there.
function SigilBarStyleTemplate:UpdateTextVisibility(context)
    local isSmall = (self._sigilSizeKey == "small")

    if self.LevelText then
        self.LevelText:SetShown(Addon.ConfigHelper.GetShowLevelText(context))
    end
    if self.PercentText then
        self.PercentText:SetShown(not isSmall and Addon.ConfigHelper.GetShowPercentage(context))
    end
    if self.RateText then
        self.RateText:SetShown(not isSmall and Addon.ConfigHelper.GetShowTimeToLevelText(context))
    end
end

-------------------------------------------------------------------
-- OVERLAY LAYOUTS (cumulative arcs)
-- The orb's totalRatio layering transplanted radially: every band is a full
-- sweep from zero, drawn UNDER the layers above it (ARC_LAYERS order), so only
-- the band's own sliver shows. The predicates -- which flags gate which band,
-- the clamps against remaining XP, the 0.01 floor -- are byte-for-byte the
-- vertical implementation's; only the geometry changed. Overlay arcs are set
-- per render, not per animation frame, so during a gain the fill sweeps to
-- meet them -- the same behaviour the vertical bands had.
--
-- Colours are applied here rather than through PaintMixin's texture-based
-- Update*BarColor methods, which no-op now that the overlay textures are gone.
-------------------------------------------------------------------

function SigilBarStyleTemplate:UpdateQuestCompleteBarLayout(context)
    local arc = self.ArcQuestComplete
    if not arc then
        return
    end

    local completeXP = context.completeQuestXP or 0
    local fraction = 0

    if context.showQuestXP and context.showCompleteQuestOverlay and completeXP > 0 then
        local currentXP = context.currentXP or 0
        local maxXP = context.xpMax or 1
        local remainingXP = math.max(0, maxXP - currentXP)
        local ratio = math.min(completeXP, remainingXP) / maxXP

        if ratio >= 0.01 then
            fraction = math.min((currentXP / maxXP) + ratio, 1.0)
        end
    end

    local color = Addon.Colors:Get(Addon.Colors.Key.QuestComplete)
    arc:SetSwipeColor(color.r, color.g, color.b, color.a or 1)
    self:SetArcProgress(arc, fraction)
end

function SigilBarStyleTemplate:UpdateQuestIncompleteBarLayout(context)
    local arc = self.ArcQuestIncomplete
    if not arc then
        return
    end

    local completeQuestXP = context.completeQuestXP or 0
    local incompleteQuestXP = context.incompleteQuestXP or 0
    local showComplete = context.showCompleteQuestOverlay
    local fraction = 0

    if context.showQuestXP and context.showIncompleteQuestOverlay and incompleteQuestXP > 0 then
        local currentXP = context.currentXP or 0
        local maxXP = context.xpMax or 1
        local remainingXP = math.max(0, maxXP - currentXP)

        local startXP = currentXP
        if showComplete and completeQuestXP > 0 then
            startXP = startXP + math.min(completeQuestXP, remainingXP)
            remainingXP = math.max(0, remainingXP - completeQuestXP)
        end

        local ratio = math.min(incompleteQuestXP, remainingXP) / maxXP

        if ratio >= 0.01 then
            fraction = math.min((startXP / maxXP) + ratio, 1.0)
        end
    end

    local color = Addon.Colors:Get(Addon.Colors.Key.QuestIncomplete)
    arc:SetSwipeColor(color.r, color.g, color.b, color.a or 1)
    self:SetArcProgress(arc, fraction)
end

function SigilBarStyleTemplate:UpdateRestedBarLayout(context)
    local arc = self.ArcRested
    if not arc then
        return
    end

    local restedXP = context.restedXP or 0
    local fraction = 0

    if Addon.ConfigHelper.GetShowRestedOverlay(context) and restedXP > 0 then
        local currentXP = context.currentXP or 0
        local maxXP = context.xpMax or 1
        local remainingXP = math.max(0, maxXP - currentXP)
        local restedXPClamped = math.min(restedXP, remainingXP)

        -- Quest overlays sit between the fill and the rested extent
        local questOffset = 0
        local completeQuestXP = context.completeQuestXP or 0
        local incompleteQuestXP = context.incompleteQuestXP or 0
        if context.showQuestXP and context.showCompleteQuestOverlay and completeQuestXP > 0 then
            questOffset = questOffset + math.min(completeQuestXP, remainingXP)
        end
        if context.showQuestXP and context.showIncompleteQuestOverlay and incompleteQuestXP > 0 then
            local remainingAfterComplete = math.max(0, remainingXP - questOffset)
            questOffset = questOffset + math.min(incompleteQuestXP, remainingAfterComplete)
        end

        local totalRatio = math.min((currentXP + questOffset + restedXPClamped) / maxXP, 1.0)

        if totalRatio >= 0.01 then
            fraction = totalRatio
        end
    end

    local color = Addon.Colors:Get(Addon.Colors.Key.Rested)
    arc:SetSwipeColor(color.r, color.g, color.b, color.a or 1)
    self:SetArcProgress(arc, fraction)
end

-------------------------------------------------------------------
-- DEFAULT CONFIG
-------------------------------------------------------------------

local DefaultConfig = {
    interaction = {enabled = true},
    tooltip = {enabled = true},
    animation = {
        enableAnimations = true,
        flashOnGain = true
    },
    position = {mode = "DRAGGABLE", positionKey = "SigilBar"},
    style = {},
    capabilities = {
        -- The StatusBar is an alpha-0 data carrier (the terminal declaration);
        -- the visible fill is the arc, driven by this style's UpdateGainedBar.
        statusBar = false,
        exhaustionTick = false,
        textBelowBar = false,
        -- The centre ETA is a time-derived readout on the bar, so it needs the
        -- periodic refresh. The key exists because Phase 0 added it.
        timeReadout = true,
    }
}

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

SigilBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase, SigilBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("sigil", SigilBarXPBarMixin)
