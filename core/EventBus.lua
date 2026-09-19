-- XP Bar Enhanced - Event Bus
-- Central event bus with a simple register/emit/unregister API

---@class XPBarEventContext
---@field event string The event that triggered this context
---@field timestamp number Unix timestamp when context was built
---@field source? string Source identifier for the event
---@field currentXP number Current player XP
---@field xpMax number Maximum XP for current level
---@field remainingXP? number XP remaining to next level
---@field level number Current player level
---@field restedXP number Amount of rested XP available
---@field isResting boolean Whether player is in a resting area
---@field hasRestedXP boolean Whether player has any rested XP
---@field isFullyRested boolean Whether player has max rested XP
---@field completeQuestXP? number XP from completed quests ready to turn in
---@field incompleteQuestXP? number XP from incomplete quests
---@field sessionStart? number Session start timestamp
---@field sessionXP? number Total XP gained this session
---@field levelSeconds? number Time played at current level
---@field xpGained? number XP gained in this event
---@field didLevelUp? boolean Whether player leveled up
---@field Get fun(self: XPBarEventContext, key: string, default?: any): any Safe getter with default value

---@alias XPBarEventBusHandler fun(context: XPBarEventContext): nil

---@class EventBusHandle
---@field Unregister fun() Unregister this subscription

local Addon = XPBarEnhanced
Addon.EventBus = Addon.EventBus or {}
local EventBus = Addon.EventBus
local Utils = Addon.Utils

EventBus.listeners = EventBus.listeners or {}

---Register a handler for an event
---@param eventName string The event name to listen for
---@param idOrHandler string|XPBarEventBusHandler Subscription ID (string) or handler function
---@param handler? XPBarEventBusHandler Handler function (required if idOrHandler is a string)
---@return string id The subscription ID for later unregistration
function EventBus:Register(eventName, idOrHandler, handler)
    if not eventName then
        error("EventBus:Register requires an eventName")
    end
    local id
    local fn
    if type(idOrHandler) == "string" then
        id = idOrHandler
        fn = handler
    else
        fn = idOrHandler
    end
    if type(fn) ~= "function" then
        error("EventBus:Register requires a function handler")
    end
    id = id or tostring(fn)
    -- Registering during a dispatch of the same event is safe: Emit iterates a
    -- snapshot taken before any handler runs, so mutating the live table here
    -- cannot invalidate that iteration. The new handler runs from the next emit.
    EventBus.listeners[eventName] = EventBus.listeners[eventName] or {}
    EventBus.listeners[eventName][id] = fn
    return id
end

---Register a handler and return a handle that can unregister it
---@param eventName string The event name to listen for
---@param idOrHandler string|XPBarEventBusHandler Subscription ID or handler function
---@param handler? XPBarEventBusHandler Handler function
---@return EventBusHandle handle Object with Unregister() method
function EventBus:RegisterWithHandle(eventName, idOrHandler, handler)
    local id = self:Register(eventName, idOrHandler, handler)
    local registeredHandler = self.listeners[eventName] and self.listeners[eventName][id]
    return {
        Unregister = function()
            if EventBus.listeners[eventName] and EventBus.listeners[eventName][id] == registeredHandler then
                EventBus:Unregister(eventName, id)
            end
        end
    }
end

---Unregister a handler by id or function for an event
---@param eventName string The event name to unregister from
---@param idOrHandler string|XPBarEventBusHandler The subscription ID or handler function to remove
function EventBus:Unregister(eventName, idOrHandler)
    if not eventName or not EventBus.listeners[eventName] then
        return
    end
    if type(idOrHandler) == "string" then
        EventBus.listeners[eventName][idOrHandler] = nil
        return
    end
    for id, fn in pairs(EventBus.listeners[eventName]) do
        if fn == idOrHandler then
            EventBus.listeners[eventName][id] = nil
        end
    end
end

---Emit an event to all listeners
---@param eventName string The event name to emit
---@param context table Mandatory pre-built context supplied by the emitting domain service
---@return XPBarEventContext|table|nil context The context object passed to all handlers, or nil if no listeners
function EventBus:Emit(eventName, context)
    -- Skip expensive context build when no listeners are registered for this event
    local listenersForEvent = self.listeners and self.listeners[eventName]
    if not listenersForEvent or not next(listenersForEvent) then
        return nil
    end

    if context == nil then
        error("EventBus:Emit called without context for event: " .. tostring(eventName))
    end

    -- Iterate over a stable snapshot so handlers can safely register/unregister
    -- during emit without mutating the table being iterated.
    local dispatch = {}
    for id, handler in pairs(listenersForEvent) do
        dispatch[#dispatch + 1] = id
        dispatch[#dispatch + 1] = handler
    end

    for i = 1, #dispatch, 2 do
        local id = dispatch[i]
        local handler = dispatch[i + 1]
        -- Skip handlers unregistered by an earlier handler in this dispatch —
        -- they may belong to frames that were just torn down.
        if listenersForEvent[id] == handler then
            xpcall(handler, Utils.ReportError, context)
        end
    end

    return context
end

return EventBus
