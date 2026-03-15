# Bonus: Segmented Bar Style

**Priority:** BONUS (implement after all other steps)
**Depends on:** Core architecture (Steps 1.1-1.3)
**Blocks:** None

---

## Concept

A new "Segmented" bar style that divides the XP bar into distinct segments (like progress milestones), where each segment represents a fraction of the level. This provides a more granular sense of progress than a single continuous bar.

### Visual Design

```
┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
│██████│██████│██████│██░░░░│░░░░░░│░░░░░░│░░░░░░│░░░░░░│░░░░░░│░░░░░░│
│  10% │  10% │  10% │  6%  │  0%  │  0%  │  0%  │  0%  │  0%  │  0%  │
└──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘
           Player is at 36% XP (segments 1-3 full, segment 4 partial)
```

Each segment:
- Has a thin border/gap between segments (1-2px)
- Fills from left to right within its segment
- Uses the same color scheme as the main bar (respecting user colors)
- Rested XP overlay extends across segments
- Quest XP overlay marks predicted completion segments

### Configuration

- **Number of segments:** 5, 10, 20 (default: 10)
- **Segment gap:** 1px or 2px
- **Segment style:** Square or rounded caps
- **Position mode:** DRAGGABLE (default)

---

## Implementation Steps

### Step 1: Create XML template

**New file:** `ui/styles/segmented/SegmentedBarTemplate.xml`

```xml
<Ui>
    <Frame name="SegmentedBarTemplate" virtual="true" inherits="XPBarBaseTemplate">
        <Size x="400" y="20"/>
        <Layers>
            <Layer level="BACKGROUND">
                <Texture parentKey="Background" setAllPoints="true">
                    <Color r="0" g="0" b="0" a="0.5"/>
                </Texture>
            </Layer>
        </Layers>
        <!-- Segments are created dynamically in Lua -->
    </Frame>
</Ui>
```

### Step 2: Create SegmentedBarStyle

**New file:** `ui/styles/segmented/SegmentedBarStyle.lua`

```lua
local Addon = XPBarEnhanced
local StyleBuilder = XPBarStyleBuilder

local SegmentedBarStyle = {}

SegmentedBarStyle.config = {
    style = {
        width = 400,
        height = 20,
    },
    position = {
        mode = "DRAGGABLE",
        positionKey = "XPBar_Segmented",
    },
}

--- Create segment frames dynamically
function SegmentedBarStyle:BuildSegments(numSegments)
    -- Reuse or create segment frames
    self.segments = self.segments or {}
    local gap = 2 -- pixels between segments
    local totalGaps = (numSegments - 1) * gap
    local barWidth = self:GetWidth()
    local segmentWidth = (barWidth - totalGaps) / numSegments
    local barHeight = self:GetHeight()

    for i = 1, numSegments do
        local segment = self.segments[i]
        if not segment then
            segment = CreateFrame("StatusBar", nil, self)
            segment.background = segment:CreateTexture(nil, "BACKGROUND")
            segment.background:SetAllPoints()
            segment.background:SetColorTexture(0.1, 0.1, 0.1, 0.8)
            self.segments[i] = segment
        end

        segment:SetSize(segmentWidth, barHeight)
        segment:ClearAllPoints()
        local xOffset = (i - 1) * (segmentWidth + gap)
        segment:SetPoint("LEFT", self, "LEFT", xOffset, 0)
        segment:SetMinMaxValues(0, 1)
        segment:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        segment:Show()
    end

    -- Hide extra segments if count decreased
    for i = numSegments + 1, #self.segments do
        self.segments[i]:Hide()
    end
end

--- RenderBar: distribute XP across segments
function SegmentedBarStyle:RenderBar(context)
    local numSegments = (Addon.db and Addon.db.segmentCount) or 10
    self:BuildSegments(numSegments)

    local ratio = 0
    if context.xpMax and context.xpMax > 0 then
        ratio = context.currentXP / context.xpMax
    end

    -- Calculate which segments are full, partial, and empty
    local segmentSize = 1.0 / numSegments

    for i, segment in ipairs(self.segments) do
        if not segment:IsShown() then break end

        local segStart = (i - 1) * segmentSize
        local segEnd = i * segmentSize

        if ratio >= segEnd then
            -- Fully filled segment
            segment:SetValue(1)
        elseif ratio > segStart then
            -- Partially filled segment
            local fillRatio = (ratio - segStart) / segmentSize
            segment:SetValue(fillRatio)
        else
            -- Empty segment
            segment:SetValue(0)
        end
    end

    -- Update segment colors
    self:UpdateSegmentColors(context)

    -- Update texts
    if self.UpdateTexts then
        self:UpdateTexts(context)
    end
end

--- Color segments based on state
function SegmentedBarStyle:UpdateSegmentColors(context)
    for _, segment in ipairs(self.segments or {}) do
        if segment:IsShown() then
            local color = XPBarColors:GetUserColor(
                context.hasRestedXP and Color.XpBarRested or Color.XpBar
            )
            if color then
                segment:SetStatusBarColor(color.r, color.g, color.b, 1)
            end
        end
    end
end

--- AnimateBarPosition: animate individual segments
function SegmentedBarStyle:AnimateBarPosition(iterationData, eventContext)
    local numSegments = #(self.segments or {})
    if numSegments == 0 then return end

    local currentRatio = iterationData.currentRatio or 0
    local segmentSize = 1.0 / numSegments

    for i, segment in ipairs(self.segments) do
        if not segment:IsShown() then break end
        local segStart = (i - 1) * segmentSize
        local segEnd = i * segmentSize

        if currentRatio >= segEnd then
            segment:SetValue(1)
        elseif currentRatio > segStart then
            segment:SetValue((currentRatio - segStart) / segmentSize)
        else
            segment:SetValue(0)
        end
    end
end

-- Register with StyleBuilder
StyleBuilder:RegisterStyle("segmented", SegmentedBarStyle)
```

### Step 3: Register in BarManager

**File:** `ui/BarManager.lua`

```lua
local StyleTemplateNameMap = {
    classic = "ClassicBarTemplate",
    flat = "FlatBarTemplate",
    vertical = "VerticalBarTemplate",
    circular = "CircularBarTemplate",
    segmented = "SegmentedBarTemplate",  -- NEW
}
```

### Step 4: Add configuration options

**File:** `core/config/defaults.lua`

```lua
-- In defaults:
segmentCount = 10,  -- Number of segments (5, 10, 20)
```

**File:** `ui/options/OptionMetadata.lua`

Add segment count to the options panel as a dropdown or slider.

### Step 5: Add to TOC and locale

**File:** `XPBarEnhanced.toc`

```
ui\styles\segmented\SegmentedBarStyle.lua
ui\styles\segmented\SegmentedBarTemplate.xml
```

**File:** `locales/enUS.lua`

```lua
L["STYLE_SEGMENTED"] = "Segmented"
L["OPT_SEGMENT_COUNT"] = "Segment Count"
L["OPT_SEGMENT_COUNT_TIP"] = "Number of segments to divide the bar into."
```

---

## Advanced Features (optional)

1. **Milestone markers:** Highlight specific segments (e.g., 25%, 50%, 75%) with a different shade
2. **Segment completion animation:** Brief pulse/glow when a segment fills completely
3. **Rested XP overlay:** Show rested XP extent with a semi-transparent blue overlay across segments
4. **Quest XP prediction:** Tint segments that would be filled by available quest XP
5. **Tooltip per segment:** Hovering a segment shows its XP range

---

## Manual Testing Checklist

1. **Basic display:**
   - [ ] Select "Segmented" bar style in options
   - [ ] Verify bar appears with correct number of segments
   - [ ] Verify segments fill based on current XP percentage
   - [ ] Verify segment gap is visible between segments

2. **Segment count:**
   - [ ] Change segment count to 5
   - [ ] Verify bar shows 5 equal-width segments
   - [ ] Change to 20
   - [ ] Verify bar shows 20 segments
   - [ ] Verify partial fill works correctly at all counts

3. **Animation:**
   - [ ] Gain XP and verify animation fills segments smoothly
   - [ ] Verify flash effect works across segments
   - [ ] Level up and verify two-phase animation works

4. **Colors:**
   - [ ] Change XP bar color in options
   - [ ] Verify segments update to new color
   - [ ] Enter rest area
   - [ ] Verify segments use rested color

5. **Positioning:**
   - [ ] Verify bar is draggable (DRAGGABLE mode)
   - [ ] Drag to new position
   - [ ] Reload and verify position persists

6. **Resize:**
   - [ ] Verify segments redistribute when bar is resized
   - [ ] No visual artifacts at any size

---

## Validation Gate

**Must pass ALL:**

- [ ] Segmented style appears as an option in the style dropdown
- [ ] Segments divide evenly across the bar width
- [ ] Partial segment fill is smooth and accurate
- [ ] Animation system works correctly with segments
- [ ] Color customization affects all segments
- [ ] Position persistence works
- [ ] No Lua errors
