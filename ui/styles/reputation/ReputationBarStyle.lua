-- XP Bar Enhanced - Reputation Bar Style
-- Displays tracked faction reputation progress
-- Follows the FlatBar pattern (minimal overrides, relies on BaseMixin)

-------------------------------------------------------------------
-- DEPENDENCIES
-------------------------------------------------------------------

if not XPBarStyleBuilder or not XPBarMixinBase then
	error("ReputationBarStyle: core (StyleBuilder/BaseMixin) not loaded. Ensure ui/xpbars core files are earlier in the .toc.")
end

local Addon = XPBarEnhanced

-------------------------------------------------------------------
-- STYLE TEMPLATE
-------------------------------------------------------------------

local ReputationBarStyleTemplate = {}

--- Override OnLoad to register reputation-specific events
function ReputationBarStyleTemplate:OnLoad()
	-- Initialize reputation service if not already done
	if Addon.ReputationService and Addon.ReputationService.Initialize then
		Addon.ReputationService:Initialize()
	end

	-- Call parent OnLoad (BaseMixin)
	if XPBarMixinBase and XPBarMixinBase.OnLoad then
		XPBarMixinBase.OnLoad(self)
	end

	-- Register reputation events on this frame
	self:RegisterEvent("UPDATE_FACTION")
	self:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")

	print("|cFF00FF00[XPBarEnhanced]|r ReputationBar style loaded")
end

--- Override OnEvent to handle reputation-specific events
function ReputationBarStyleTemplate:OnEvent(event, ...)
	if event == "UPDATE_FACTION" or event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
		-- Re-poll reputation and refresh
		if Addon.ReputationService and Addon.ReputationService.PollWatchedFaction then
			Addon.ReputationService:PollWatchedFaction()
		end
		self:RenderReputationBar()
		return
	end

	-- Delegate other events to BaseMixin
	if XPBarMixinBase and XPBarMixinBase.OnEvent then
		XPBarMixinBase.OnEvent(self, event, ...)
	end
end

--- Override Refresh to use reputation data instead of XP
function ReputationBarStyleTemplate:Refresh()
	self:RenderReputationBar()
end

--- Override FullUpdate to use reputation data
function ReputationBarStyleTemplate:FullUpdate(context)
	if self._isUpdating then
		return
	end
	self._isUpdating = true
	self:RenderReputationBar()
	self._isUpdating = nil
end

--- Override TriggerBarRefresh to use reputation rendering
function ReputationBarStyleTemplate:TriggerBarRefresh(context)
	self:RenderReputationBar()
end

--- Core reputation rendering method
function ReputationBarStyleTemplate:RenderReputationBar()
	local repService = Addon.ReputationService
	if not repService then
		return
	end

	local repData = repService:GetRepData()
	if not repData then
		-- No watched faction - show empty bar
		if self.StatusBar then
			self.StatusBar:SetValue(0)
		end
		if self.LevelText then
			self.LevelText:SetText("No faction")
			self.LevelText:Show()
		end
		if self.XPText then
			self.XPText:SetText("")
		end
		if self.PercentText then
			self.PercentText:SetText("")
		end
		return
	end

	-- Update StatusBar
	if self.StatusBar then
		self.StatusBar:SetMinMaxValues(0, 1)
		self.StatusBar:SetValue(repData.ratio)

		-- Apply standing color to the bar
		local color = repData.color
		if color then
			self.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
		end
	end

	-- Update texts
	local db = Addon.db or {}

	-- Level text -> standing name
	if self.LevelText then
		local showLevel = db.showLevelText ~= false
		if showLevel then
			self.LevelText:SetText(repData.standingName)
			self.LevelText:Show()
		else
			self.LevelText:Hide()
		end
	end

	-- XP text -> reputation amounts
	if self.XPText then
		local showXP = db.showXPText ~= false
		if showXP then
			local currentText, maxText
			if db.abbreviateNumbers and Addon.TextFormatter and Addon.TextFormatter.AbbreviateNumber then
				currentText = Addon.TextFormatter.AbbreviateNumber(repData.currentRep)
				maxText = Addon.TextFormatter.AbbreviateNumber(repData.maxRep)
			else
				currentText = tostring(repData.currentRep)
				maxText = tostring(repData.maxRep)
			end
			self.XPText:SetText(currentText .. " / " .. maxText)
			self.XPText:Show()
		else
			self.XPText:Hide()
		end
	end

	-- Percent text -> reputation percentage
	if self.PercentText then
		local showPct = db.showPercentage ~= false
		if showPct then
			self.PercentText:SetText(string.format("%.1f%%", repData.ratio * 100))
			self.PercentText:Show()
		else
			self.PercentText:Hide()
		end
	end

	-- Hide below-bar texts that don't apply to reputation
	if self.RateText then
		self.RateText:SetText(repData.factionName or "")
		self.RateText:Show()
	end
	if self.SessionText then
		self.SessionText:Hide()
	end
	if self.QuestSummaryText then
		self.QuestSummaryText:Hide()
	end

	-- Hide quest/rested overlays (not applicable)
	if self.StatusBar then
		if self.StatusBar.RestedOverlay then
			self.StatusBar.RestedOverlay:Hide()
		end
		if self.StatusBar.QuestOverlayComplete then
			self.StatusBar.QuestOverlayComplete:Hide()
		end
		if self.StatusBar.QuestOverlayIncomplete then
			self.StatusBar.QuestOverlayIncomplete:Hide()
		end
	end
	if self.RestedOverlay then
		self.RestedOverlay:Hide()
	end
	if self.QuestOverlayComplete then
		self.QuestOverlayComplete:Hide()
	end
	if self.QuestOverlayIncomplete then
		self.QuestOverlayIncomplete:Hide()
	end
end

--- Override RenderBar (called by BaseMixin) to redirect to reputation
function ReputationBarStyleTemplate:RenderBar(context)
	self:RenderReputationBar()
end

--- Override RegisterCommonEvents to skip XP events but keep position/tooltip
function ReputationBarStyleTemplate:RegisterCommonEvents()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("UPDATE_FACTION")
	self:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
end

--- Override CalculateTargetRatio to use reputation ratio
function ReputationBarStyleTemplate:CalculateTargetRatio(context)
	local repService = Addon.ReputationService
	if repService and repService.GetRatio then
		return repService:GetRatio()
	end
	return 0
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
	position = {mode = "DRAGGABLE", positionKey = "ReputationBar"},
	style = {}
}

-------------------------------------------------------------------
-- STYLE CREATION
-------------------------------------------------------------------

-- Create composed mixin (Base + Behaviors + Style)
ReputationBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase, ReputationBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("reputation", ReputationBarXPBarMixin)
