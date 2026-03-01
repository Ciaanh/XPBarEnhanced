-- XP Bar Enhanced - Reputation Service
-- Provides reputation data for the reputation bar style
-- Mirrors the Session/QuestXP service pattern

local Addon = XPBarEnhanced
Addon.ReputationService = Addon.ReputationService or {}
local ReputationService = Addon.ReputationService

-------------------------------------------------------------------
-- REPUTATION STANDING NAMES & COLORS
-------------------------------------------------------------------

local STANDING_COLORS = {
	[1] = {r = 0.80, g = 0.13, b = 0.13, a = 1.0}, -- Hated (red)
	[2] = {r = 0.80, g = 0.26, b = 0.13, a = 1.0}, -- Hostile (dark orange)
	[3] = {r = 0.80, g = 0.40, b = 0.13, a = 1.0}, -- Unfriendly (orange)
	[4] = {r = 0.76, g = 0.70, b = 0.30, a = 1.0}, -- Neutral (yellow)
	[5] = {r = 0.13, g = 0.70, b = 0.13, a = 1.0}, -- Friendly (green)
	[6] = {r = 0.13, g = 0.55, b = 0.80, a = 1.0}, -- Honored (blue)
	[7] = {r = 0.50, g = 0.30, b = 0.80, a = 1.0}, -- Revered (purple)
	[8] = {r = 0.90, g = 0.70, b = 0.20, a = 1.0}, -- Exalted (gold)
}

local STANDING_NAMES = {
	[1] = "Hated",
	[2] = "Hostile",
	[3] = "Unfriendly",
	[4] = "Neutral",
	[5] = "Friendly",
	[6] = "Honored",
	[7] = "Revered",
	[8] = "Exalted",
}

-------------------------------------------------------------------
-- INTERNAL STATE
-------------------------------------------------------------------

local state = {
	factionName = nil,
	standing = 0,
	currentRep = 0,
	maxRep = 0,
	factionID = nil,
	hasWatchedFaction = false,
	lastStanding = nil,
}

-------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------

--- Initialize the reputation service
function ReputationService:Initialize()
	-- Event frame for reputation events
	if not self.eventFrame then
		self.eventFrame = CreateFrame("Frame")
		self.eventFrame:RegisterEvent("UPDATE_FACTION")
		self.eventFrame:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
		self.eventFrame:SetScript("OnEvent", function(frame, event, ...)
			self:OnEvent(event, ...)
		end)
	end

	-- Initial poll
	self:PollWatchedFaction()
	print("|cFF00FF00[XPBarEnhanced]|r ReputationService initialized")
end

--- Poll the currently watched (tracked) faction
--- @return table|nil repData Reputation data table or nil if no faction watched
function ReputationService:PollWatchedFaction()
	local name, standing, barMin, barMax, barValue, factionID

	-- Retail API: C_Reputation.GetWatchedFactionData (11.0+)
	if C_Reputation and C_Reputation.GetWatchedFactionData then
		local data = C_Reputation.GetWatchedFactionData()
		if data then
			name = data.name
			standing = data.reaction
			barMin = data.currentReactionThreshold or 0
			barMax = data.nextReactionThreshold or 1
			barValue = data.currentStanding or 0
			factionID = data.factionID
		end
	else
		-- Fallback: classic GetWatchedFactionInfo()
		if GetWatchedFactionInfo then
			name, standing, barMin, barMax, barValue, factionID = GetWatchedFactionInfo()
		end
	end

	if not name or not barMax then
		state.hasWatchedFaction = false
		state.factionName = nil
		return nil
	end

	-- Normalize to 0-based range
	local currentRep = barValue - barMin
	local maxRep = barMax - barMin

	-- Detect standing change (faction level-up)
	local standingChanged = false
	if state.lastStanding and state.lastStanding ~= standing then
		standingChanged = true
		print("|cFF00FF00[XPBarEnhanced]|r Reputation standing changed:",
			STANDING_NAMES[state.lastStanding] or "?", "->", STANDING_NAMES[standing] or "?")
	end

	state.factionName = name
	state.standing = standing or 0
	state.currentRep = currentRep
	state.maxRep = maxRep > 0 and maxRep or 1
	state.factionID = factionID
	state.hasWatchedFaction = true
	state.lastStanding = standing
	state.standingChanged = standingChanged

	return self:GetRepData()
end

--- Get current reputation data
--- @return table repData
function ReputationService:GetRepData()
	if not state.hasWatchedFaction then
		return nil
	end

	return {
		factionName = state.factionName,
		standing = state.standing,
		standingName = STANDING_NAMES[state.standing] or "Unknown",
		currentRep = state.currentRep,
		maxRep = state.maxRep,
		ratio = state.maxRep > 0 and (state.currentRep / state.maxRep) or 0,
		factionID = state.factionID,
		hasWatchedFaction = state.hasWatchedFaction,
		standingChanged = state.standingChanged or false,
		color = STANDING_COLORS[state.standing] or STANDING_COLORS[4],
	}
end

--- Check if a faction is currently being watched
--- @return boolean
function ReputationService:HasWatchedFaction()
	return state.hasWatchedFaction
end

--- Get reputation progress ratio (0.0-1.0)
--- @return number ratio
function ReputationService:GetRatio()
	if not state.hasWatchedFaction or state.maxRep <= 0 then
		return 0
	end
	return state.currentRep / state.maxRep
end

--- Get standing color for current watched faction
--- @return table color {r, g, b, a}
function ReputationService:GetStandingColor()
	return STANDING_COLORS[state.standing] or STANDING_COLORS[4]
end

--- Get all standing colors table
--- @return table colors
function ReputationService:GetStandingColors()
	return STANDING_COLORS
end

--- Get standing names table
--- @return table names
function ReputationService:GetStandingNames()
	return STANDING_NAMES
end

-------------------------------------------------------------------
-- EVENT HANDLING
-------------------------------------------------------------------

function ReputationService:OnEvent(event, ...)
	if event == "UPDATE_FACTION" or event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
		self:PollWatchedFaction()

		-- Notify EventBus if available
		if Addon.EventBus and Addon.EventBus.Emit then
			Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE)
		end
	end
end

return ReputationService
