---@diagnostic disable: undefined-global, lowercase-global
-- Shared test harness: one set of WoW stubs, one loader, one Check.
--
-- Usage from a test file (run from the repo root, repo root as arg[1]):
--
--   local H = dofile((arg[1] or ".") .. "/tests/harness.lua")
--   H.player.level = 20                       -- world state the stubbed game functions read
--   local Addon = H.Load()                    -- loads the toc's files, fires ADDON_LOADED
--   H.Login()                                 -- PLAYER_LOGIN, then PLAYER_ENTERING_WORLD
--   H.Check("label", got, expected)
--   H.Done()
--
-- Every stub reads mutable state on H, so a test changes the world by assigning fields, not by
-- redefining globals. A test may still nil out a whole system before H.Load() to play a client
-- without it.
local H = {}

H.ROOT = arg[1] or "."
H.ADDON = "XPBarEnhanced"
H.failures = 0

local realType = type
-- The addon's print goes to H.chat; the harness's own report goes to the console.
local print_raw = print

--------------------------------------------------------------------------------
-- Secret values
--
-- A secret is a userdata proxy that raises on every operation the client forbids on a real one:
-- indexing, concatenation, arithmetic, ordering, length, calling, tostring. The overridden
-- global `type` reports the type the secret stands for, as the client's type() does, and
-- issecretvalue recognises it. So an addon path that compares, formats or stores a secret fails
-- the test instead of passing silently.
--------------------------------------------------------------------------------

H.secretKinds = setmetatable({}, { __mode = "k" })

local function Forbidden()
    error("operation on a secret value", 2)
end

function H.Secret(kind)
    local proxy = newproxy(true)
    local mt = getmetatable(proxy)
    for _, event in ipairs({ "__index", "__newindex", "__concat", "__add", "__sub", "__mul", "__div",
        "__mod", "__pow", "__unm", "__lt", "__le", "__len", "__call", "__tostring" }) do
        mt[event] = Forbidden
    end
    H.secretKinds[proxy] = kind or "number"
    return proxy
end

function type(value)
    local kind = H.secretKinds[value]
    if kind then return kind end
    return realType(value)
end

function issecretvalue(value)
    return H.secretKinds[value] ~= nil
end

--------------------------------------------------------------------------------
-- World state
--
-- H.player: what the unit and XP apis report. rested = nil means no rested XP (GetXPExhaustion
-- returns nil, as the game does).
-- H.interface: the client's interface version (select(4, GetBuildInfo())).
--------------------------------------------------------------------------------

H.player = { name = "Tester", realm = "Realm", level = 10, xp = 0, max = 10000, rested = nil,
    resting = false, maxLevel = 80 }
H.interface = 120105

--------------------------------------------------------------------------------
-- Time
--
-- H.epoch is time() (wall clock, whole seconds), H.clock is GetTime(). Neither moves unless a
-- test says so: H.Advance(seconds) moves both and runs every timer that falls due on the way,
-- in order.
--------------------------------------------------------------------------------

H.epoch = 1800000000
H.clock = 1000

function time(t)
    if t then return os.time(t) end
    return H.epoch
end
date = os.date
function GetTime() return H.clock end
function GetServerTime() return H.epoch end

H.timers = {}
local timerSeq = 0

local function Schedule(delay, fn, timer)
    timerSeq = timerSeq + 1
    timer = timer or {}
    timer.due, timer.fn, timer.seq = H.clock + math.max(0, delay or 0), fn, timerSeq
    table.insert(H.timers, timer)
    return timer
end

local function NextDue(limit)
    local best
    for _, t in ipairs(H.timers) do
        if not t.cancelled and t.due <= limit and (not best or t.due < best.due
            or (t.due == best.due and t.seq < best.seq)) then
            best = t
        end
    end
    return best
end

local function RunTimer(t)
    for i, other in ipairs(H.timers) do
        if other == t then table.remove(H.timers, i) break end
    end
    t.fn(t)
end

-- Run the timers due now (C_Timer.After(0, ...) and anything they queue for now).
function H.RunTimers()
    for _ = 1, 1000 do
        local t = NextDue(H.clock)
        if not t then return end
        RunTimer(t)
    end
    error("timers never settle")
end

-- Move time forward, running each timer at the moment it falls due.
function H.Advance(seconds)
    local target = H.clock + seconds
    for _ = 1, 100000 do
        local t = NextDue(target)
        if not t then break end
        local step = t.due - H.clock
        H.clock = t.due
        H.epoch = H.epoch + step
        RunTimer(t)
    end
    H.epoch = H.epoch + (target - H.clock)
    H.clock = target
end

C_Timer = {}
function C_Timer.After(delay, fn)
    Schedule(delay, function() fn() end)
end
function C_Timer.NewTimer(delay, fn)
    local timer = {}
    function timer:Cancel() self.cancelled = true end
    function timer:IsCancelled() return self.cancelled == true end
    Schedule(delay, function() fn(timer) end, timer)
    return timer
end
function C_Timer.NewTicker(delay, fn, iterations)
    local ticker = { remaining = iterations }
    function ticker:Cancel() self.cancelled = true end
    function ticker:IsCancelled() return self.cancelled == true end
    local function Tick()
        if ticker.cancelled then return end
        fn(ticker)
        if ticker.remaining then
            ticker.remaining = ticker.remaining - 1
            if ticker.remaining <= 0 then return end
        end
        Schedule(delay, Tick, ticker)
        ticker.cancelled = nil
    end
    Schedule(delay, Tick, ticker)
    return ticker
end

--------------------------------------------------------------------------------
-- Frames and events
--
-- A frame records its events, scripts, shown state and anchors. Any other method is accepted and
-- does nothing (Get* returns 0, Is* / Has* / Can* false): the bars' drawing is not under test
-- here, the services are. Textures and font strings are the same kind of object.
--------------------------------------------------------------------------------

H.frames = {}
H.unknownEvents = {}

local frameMethods = {}

-- Only names shaped like a widget method get the do-nothing fallback, so an unset field
-- (self._timer, self.Text) still reads as nil, as it would in game.
local METHOD_VERBS = { "Set", "Get", "Is", "Has", "Can", "Enable", "Disable", "Register", "Unregister",
    "Create", "Clear", "Start", "Stop", "Play", "Pause", "Finish", "Restart", "Lock", "Unlock", "Raise",
    "Lower", "Add", "Remove", "Adjust", "Scroll", "Release", "Acquire" }

local function MethodVerb(key)
    if realType(key) ~= "string" then return nil end
    for _, verb in ipairs(METHOD_VERBS) do
        if key == verb or (key:sub(1, #verb) == verb and key:sub(#verb + 1, #verb + 1):match("%u")) then
            return verb
        end
    end
    return nil
end

local frameMeta = {
    __index = function(self, key)
        local method = frameMethods[key]
        if method then return method end
        local verb = MethodVerb(key)
        if verb == "Is" or verb == "Has" or verb == "Can" then
            return function() return false end
        elseif verb == "Get" then
            return function() return 0 end
        elseif verb then
            return function() return nil end
        end
        return nil
    end,
}

local function NewObject(objectType, name, parent)
    local f = setmetatable({ objectType = objectType, name = name, parent = parent, registered = {},
        scripts = {}, shown = true, points = {}, width = 0, height = 0, alpha = 1, scale = 1 }, frameMeta)
    return f
end

function frameMethods:GetObjectType() return self.objectType end
function frameMethods:GetName() return self.name end
function frameMethods:GetParent() return self.parent end
function frameMethods:SetParent(parent) self.parent = parent end
function frameMethods:Show() self.shown = true end
function frameMethods:Hide() self.shown = false end
function frameMethods:SetShown(shown) self.shown = shown and true or false end
function frameMethods:IsShown() return self.shown end
function frameMethods:IsVisible() return self.shown end
function frameMethods:ClearAllPoints() self.points = {} end
function frameMethods:SetPoint(...) table.insert(self.points, { ... }) end
function frameMethods:GetNumPoints() return #self.points end
function frameMethods:SetSize(w, h) self.width, self.height = w, h end
function frameMethods:SetWidth(w) self.width = w end
function frameMethods:SetHeight(h) self.height = h end
function frameMethods:GetWidth() return self.width end
function frameMethods:GetHeight() return self.height end
function frameMethods:GetSize() return self.width, self.height end
function frameMethods:SetAlpha(a) self.alpha = a end
function frameMethods:GetAlpha() return self.alpha end
function frameMethods:SetScale(s) self.scale = s end
function frameMethods:GetScale() return self.scale end
function frameMethods:GetEffectiveScale() return self.scale end
function frameMethods:SetText(text) self.text = text end
function frameMethods:GetText() return self.text end
function frameMethods:SetFormattedText(fmt, ...) self.text = string.format(fmt, ...) end
function frameMethods:GetStringWidth() return 6 * #tostring(self.text or "") end
function frameMethods:SetScript(which, fn) self.scripts[which] = fn end
function frameMethods:GetScript(which) return self.scripts[which] end
function frameMethods:HookScript(which, fn)
    local old = self.scripts[which]
    self.scripts[which] = function(...)
        if old then old(...) end
        return fn(...)
    end
end
function frameMethods:RegisterEvent(event)
    if H.unknownEvents[event] then error("unknown event " .. event) end
    self.registered[event] = true
end
function frameMethods:RegisterUnitEvent(event) self:RegisterEvent(event) end
function frameMethods:UnregisterEvent(event) self.registered[event] = nil end
function frameMethods:UnregisterAllEvents() self.registered = {} end
function frameMethods:IsEventRegistered(event) return self.registered[event] == true end
function frameMethods:CreateTexture(name) return NewObject("Texture", name, self) end
function frameMethods:CreateMaskTexture(name) return NewObject("MaskTexture", name, self) end
function frameMethods:CreateFontString(name) return NewObject("FontString", name, self) end
function frameMethods:CreateAnimationGroup(name) return NewObject("AnimationGroup", name, self) end
function frameMethods:CreateAnimation(objectType, name) return NewObject(objectType or "Animation", name, self) end
function frameMethods:GetChildren() return end
function frameMethods:GetRegions() return end

function CreateFrame(objectType, name, parent, template)
    local f = NewObject(objectType or "Frame", name, parent)
    f.template = template
    if name then _G[name] = f end
    table.insert(H.frames, f)
    return f
end

-- Deliver an event to every frame registered for it, as the client would.
function H.Fire(event, ...)
    local snapshot = {}
    for i, f in ipairs(H.frames) do snapshot[i] = f end
    for _, f in ipairs(snapshot) do
        if f.registered[event] and f.scripts.OnEvent then
            f.scripts.OnEvent(f, event, ...)
        end
    end
end

UIParent = CreateFrame("Frame", "UIParent")
Minimap = CreateFrame("Frame", "Minimap")
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
UISpecialFrames = {}

--------------------------------------------------------------------------------
-- Chat
--
-- ChatFrame1..NUM_CHAT_WINDOWS listen for TIME_PLAYED_MSG as Blizzard's do and print it: a reply
-- that reaches one is in H.chatPlayedLines. H.chatEventChanges records every RegisterEvent /
-- UnregisterEvent of TIME_PLAYED_MSG on them.
--------------------------------------------------------------------------------

H.chat = {}
H.chatPlayedLines = 0
H.chatEventChanges = {}

DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) table.insert(H.chat, tostring(msg)) end }
NUM_CHAT_WINDOWS = 3
for i = 1, NUM_CHAT_WINDOWS do
    local frame = CreateFrame("ScrollingMessageFrame", "ChatFrame" .. i, UIParent)
    local register, unregister = frame.RegisterEvent, frame.UnregisterEvent
    function frame:RegisterEvent(event)
        if event == "TIME_PLAYED_MSG" then table.insert(H.chatEventChanges, "register " .. self.name) end
        register(self, event)
    end
    function frame:UnregisterEvent(event)
        if event == "TIME_PLAYED_MSG" then table.insert(H.chatEventChanges, "unregister " .. self.name) end
        unregister(self, event)
    end
    frame.registered.TIME_PLAYED_MSG = true
    frame:SetScript("OnEvent", function(_, event)
        if event == "TIME_PLAYED_MSG" then H.chatPlayedLines = H.chatPlayedLines + 1 end
    end)
end

function print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    table.insert(H.chat, table.concat(parts, " "))
end

--------------------------------------------------------------------------------
-- Played time
--
-- RequestTimePlayed counts in H.playedRequests and answers nothing on its own: a test answers
-- with H.AnswerPlayed(total, thisLevel), which fires TIME_PLAYED_MSG to every listener, the chat
-- frames included, as the server's reply does whoever asked.
--------------------------------------------------------------------------------

H.playedRequests = 0
function RequestTimePlayed() H.playedRequests = H.playedRequests + 1 end
function H.AnswerPlayed(total, thisLevel) H.Fire("TIME_PLAYED_MSG", total, thisLevel) end

--------------------------------------------------------------------------------
-- Globals
--------------------------------------------------------------------------------

function GetBuildInfo() return "12.1.5", "70575", "Oct 1 2026", H.interface end
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC = 1, 1, 2

function UnitName() return H.player.name end
function UnitFullName() return H.player.name, H.player.realm end
function GetRealmName() return H.player.realm end
function UnitLevel() return H.player.level end
function UnitXP() return H.player.xp end
function UnitXPMax() return H.player.max end
function UnitGUID() return "Player-1-0000001" end
function UnitClass() return "Warrior", "WARRIOR", 1 end
function UnitFactionGroup() return "Alliance", "Alliance" end
function GetXPExhaustion() return H.player.rested end
function IsResting() return H.player.resting end
function GetRestState() return 1, "Rested", 2 end
function IsXPUserDisabled() return false end
function GetMaxPlayerLevel() return H.player.maxLevel end
function GetMaxLevelForPlayerExpansion() return H.player.maxLevel end
function IsPlayerAtEffectiveMaxLevel() return H.player.level >= H.player.maxLevel end
function InCombatLockdown() return false end
function GetLocale() return "enUS" end
function GetCVar() return nil end
function GetCVarBool() return false end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
function PlaySound() end
function hooksecurefunc() end
-- WoW's xpcall passes its extra arguments to the function; Lua 5.1's does not.
local luaXpcall = xpcall
function xpcall(fn, handler, ...)
    local args, n = { ... }, select("#", ...)
    return luaXpcall(function() return fn(unpack(args, 1, n)) end, handler)
end
function securecallfunction(fn, ...) return fn(...) end
function geterrorhandler() return function(err) table.insert(H.errors, tostring(err)) end end
function CallErrorHandler(err) table.insert(H.errors, tostring(err)) end
H.errors = {}

function GetAddOnMetadata(_, field)
    if field == "Version" then return "test" end
end
C_AddOns = { GetAddOnMetadata = GetAddOnMetadata, IsAddOnLoaded = function() return false end }

function GetNumQuestLogEntries() return 0 end
C_QuestLog = {
    GetNumQuestLogEntries = function() return 0 end,
    GetInfo = function() return nil end,
    IsComplete = function() return false end,
    ReadyForTurnIn = function() return false end,
}
function GetQuestLogRewardXP() return 0 end

function Mixin(object, ...)
    for i = 1, select("#", ...) do
        for k, v in pairs((select(i, ...))) do object[k] = v end
    end
    return object
end
function CreateFromMixins(...) return Mixin({}, ...) end
function CreateColor(r, g, b, a)
    return { r = r, g = g, b = b, a = a, GetRGB = function(c) return c.r, c.g, c.b end,
        GetRGBA = function(c) return c.r, c.g, c.b, c.a end }
end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
table.wipe = wipe
strtrim = function(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
strsplit = function(sep, s)
    local out = {}
    for piece in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = piece end
    return unpack(out)
end
format = string.format
strmatch, strfind, strsub, strlen, strlower, strupper, strrep, strbyte, strchar =
    string.match, string.find, string.sub, string.len, string.lower, string.upper, string.rep, string.byte,
    string.char
gsub, gmatch = string.gsub, string.gmatch
tinsert, tremove, tconcat, sort = table.insert, table.remove, table.concat, table.sort
floor, ceil, abs, min, max = math.floor, math.ceil, math.abs, math.min, math.max
SlashCmdList = {}
StaticPopupDialogs = {}

--------------------------------------------------------------------------------
-- Loading and checking
--------------------------------------------------------------------------------

-- Load the addon as the client would: the toc's files in its order (XML files are skipped: the
-- harness has no template system), then ADDON_LOADED. `db` plays XPBarEnhancedDB as read from
-- disk.
function H.Load(db)
    XPBarEnhancedDB = db
    local ns = {}
    for line in io.lines(H.ROOT .. "/" .. H.ADDON .. ".toc") do
        line = line:gsub("%s+$", "")
        if line ~= "" and not line:match("^#") and line:match("%.lua$") then
            local path = H.ROOT .. "/" .. line:gsub("\\", "/")
            local chunk = assert(loadfile(path))
            chunk(H.ADDON, ns)
        end
    end
    H.ns = ns
    H.Fire("ADDON_LOADED", H.ADDON)
    return ns
end

-- A first login: PLAYER_LOGIN, then PLAYER_ENTERING_WORLD(true, false), then the timers due now.
function H.Login()
    H.Fire("PLAYER_LOGIN")
    H.Fire("PLAYER_ENTERING_WORLD", true, false)
    H.RunTimers()
end

-- A /reload: PLAYER_LOGOUT, the SavedVariables written and read back, the addon loaded again,
-- then PLAYER_ENTERING_WORLD(false, true). Returns the new namespace.
function H.Reload()
    return H.Restart(false)
end

-- Logging out and back in `offlineSeconds` later (a /reload with `reload`). The SavedVariables
-- survive through a deep copy; every frame and timer of the old UI is dropped.
function H.Restart(login, offlineSeconds)
    H.Fire("PLAYER_LOGOUT")
    local saved = H.Copy(XPBarEnhancedDB)
    H.frames, H.timers = {}, {}
    UIParent = CreateFrame("Frame", "UIParent")
    for i = 1, NUM_CHAT_WINDOWS do table.insert(H.frames, _G["ChatFrame" .. i]) end
    if offlineSeconds then H.epoch = H.epoch + offlineSeconds end
    local ns = H.Load(saved)
    H.Fire("PLAYER_LOGIN")
    if login then
        H.Fire("PLAYER_ENTERING_WORLD", true, false)
    else
        H.Fire("PLAYER_ENTERING_WORLD", false, true)
    end
    H.RunTimers()
    return ns
end

function H.Copy(value)
    if realType(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[H.Copy(k)] = H.Copy(v) end
    return out
end

function H.Check(label, got, expected)
    local ok = (got == expected)
    if not ok then
        H.failures = H.failures + 1
    end
    print_raw(string.format("  %-60s %-18s %s", label, tostring(got),
        ok and "OK" or ("<<< FAIL, wanted " .. tostring(expected))))
end

-- Close enough for a rate worked out in floating point.
function H.CheckNear(label, got, expected, tolerance)
    local ok = realType(got) == "number" and math.abs(got - expected) <= (tolerance or 0.5)
    if not ok then
        H.failures = H.failures + 1
    end
    print_raw(string.format("  %-60s %-18s %s", label, tostring(got),
        ok and "OK" or ("<<< FAIL, wanted " .. tostring(expected))))
end

-- No error reported through the addon's error handler since the last call.
function H.CheckNoErrors(label)
    H.Check(label, #H.errors, 0)
    for _, err in ipairs(H.errors) do print_raw("      " .. err) end
    H.errors = {}
end

function H.Section(title)
    print_raw(title .. ":")
end

function H.Done()
    print_raw("")
    if H.failures > 0 then
        print_raw(H.failures .. " FAILED")
        os.exit(1)
    end
    print_raw("all passed")
end

return H
